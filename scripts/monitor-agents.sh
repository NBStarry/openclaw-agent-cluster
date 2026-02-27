#!/bin/bash
# monitor-agents.sh - 监控所有活跃的Agent任务
#
# 这个脚本会被cron任务每10分钟调用一次
# 检查所有活跃任务的状态，不依赖AI查询，完全确定性

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TASK_FILE="$SCRIPT_DIR/../tasks/active-tasks.json"
COMPLETED_FILE="$SCRIPT_DIR/../tasks/completed-tasks.json"

# 检查任务文件是否存在
if [ ! -f "$TASK_FILE" ]; then
    echo "没有活跃任务"
    exit 0
fi

# 检查是否安装了必要的工具
if ! command -v jq &> /dev/null; then
    echo "错误: 需要安装jq"
    exit 1
fi

if ! command -v tmux &> /dev/null; then
    echo "错误: 需要安装tmux"
    exit 1
fi

if ! command -v gh &> /dev/null; then
    echo "警告: 未安装gh CLI，无法检查PR状态"
fi

echo "======================================"
echo "Agent监控 - $(date '+%Y-%m-%d %H:%M:%S')"
echo "======================================"

# 读取所有活跃任务
TASKS=$(jq -r '.tasks[] | @base64' "$TASK_FILE" 2>/dev/null || echo "")

if [ -z "$TASKS" ]; then
    echo "没有活跃任务"
    exit 0
fi

UPDATED_TASKS='{"tasks":[]}'
NEED_NOTIFICATION=()

# 遍历每个任务
echo "$TASKS" | while IFS= read -r task_base64; do
    # 解码任务
    TASK=$(echo "$task_base64" | base64 --decode)
    
    TASK_ID=$(echo "$TASK" | jq -r '.id')
    TMUX_SESSION=$(echo "$TASK" | jq -r '.tmuxSession')
    BRANCH=$(echo "$TASK" | jq -r '.branch')
    STATUS=$(echo "$TASK" | jq -r '.status')
    RETRIES=$(echo "$TASK" | jq -r '.retries // 0')
    
    echo ""
    echo "检查任务: $TASK_ID"
    echo "  tmux会话: $TMUX_SESSION"
    echo "  分支: $BRANCH"
    echo "  当前状态: $STATUS"
    
    # 1. 检查tmux会话是否还活着
    if tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        echo "  ✅ tmux会话运行中"
        SESSION_ALIVE=true
    else
        echo "  ❌ tmux会话已结束"
        SESSION_ALIVE=false
    fi
    
    # 2. 检查是否创建了PR
    HAS_PR=false
    PR_NUMBER=""
    if command -v gh &> /dev/null; then
        PR_INFO=$(gh pr list --head "$BRANCH" --json number,title,state 2>/dev/null || echo "[]")
        if [ "$(echo "$PR_INFO" | jq 'length')" -gt 0 ]; then
            HAS_PR=true
            PR_NUMBER=$(echo "$PR_INFO" | jq -r '.[0].number')
            PR_STATE=$(echo "$PR_INFO" | jq -r '.[0].state')
            echo "  ✅ PR已创建: #$PR_NUMBER ($PR_STATE)"
        else
            echo "  ⏳ 未创建PR"
        fi
    fi
    
    # 3. 如果有PR，检查CI状态
    if [ "$HAS_PR" = true ] && command -v gh &> /dev/null; then
        CI_STATUS=$(gh pr checks "$PR_NUMBER" --json state -q '.[] | select(.state != "SUCCESS") | .state' 2>/dev/null || echo "")
        
        if [ -z "$CI_STATUS" ]; then
            echo "  ✅ CI全部通过"
            CI_PASSED=true
        else
            echo "  ⏳ CI检查中或失败"
            CI_PASSED=false
        fi
    else
        CI_PASSED=false
    fi
    
    # 决策逻辑
    NEW_STATUS="$STATUS"
    
    if [ "$HAS_PR" = true ] && [ "$CI_PASSED" = true ]; then
        # 任务完成：PR创建且CI通过
        NEW_STATUS="completed"
        echo "  🎉 任务完成！"
        NEED_NOTIFICATION+=("$TASK_ID:$PR_NUMBER")
        
    elif [ "$SESSION_ALIVE" = false ] && [ "$HAS_PR" = false ]; then
        # tmux结束但没有PR = 失败
        if [ "$RETRIES" -lt 3 ]; then
            NEW_STATUS="retry_pending"
            echo "  🔄 任务失败，准备重试（第$(($RETRIES + 1))次）"
        else
            NEW_STATUS="failed"
            echo "  ❌ 任务失败（已重试3次）"
            NEED_NOTIFICATION+=("$TASK_ID:failed")
        fi
        
    elif [ "$SESSION_ALIVE" = true ]; then
        # 检查是否卡住（超过2小时无新commit）
        WORKTREE_PATH="${WORKTREE_BASE:-$PWD/../worktrees}/$TASK_ID"
        if [ -d "$WORKTREE_PATH/.git" ]; then
            LAST_COMMIT_TIME=$(cd "$WORKTREE_PATH" && git log -1 --format=%ct 2>/dev/null || echo 0)
            CURRENT_TIME=$(date +%s)
            TIME_DIFF=$(($CURRENT_TIME - $LAST_COMMIT_TIME))
            
            if [ "$TIME_DIFF" -gt 7200 ]; then  # 2小时 = 7200秒
                echo "  ⚠️ 警告: Agent可能卡住（超过2小时无commit）"
                NEW_STATUS="stuck"
            fi
        fi
    fi
    
    # 更新任务状态
    UPDATED_TASK=$(echo "$TASK" | jq --arg status "$NEW_STATUS" '.status = $status')
    
    # 如果需要重试，增加重试次数
    if [ "$NEW_STATUS" = "retry_pending" ]; then
        UPDATED_TASK=$(echo "$UPDATED_TASK" | jq '.retries = ((.retries // 0) + 1)')
    fi
    
    # 添加到更新列表（如果未完成）
    if [ "$NEW_STATUS" != "completed" ]; then
        UPDATED_TASKS=$(echo "$UPDATED_TASKS" | jq --argjson task "$UPDATED_TASK" '.tasks += [$task]')
    else
        # 移到completed-tasks.json
        if [ -f "$COMPLETED_FILE" ]; then
            COMPLETED_TASKS=$(cat "$COMPLETED_FILE")
        else
            COMPLETED_TASKS='{"tasks":[]}'
        fi
        
        COMPLETED_TASKS=$(echo "$COMPLETED_TASKS" | jq --argjson task "$UPDATED_TASK" '.tasks += [$task]')
        echo "$COMPLETED_TASKS" > "$COMPLETED_FILE"
    fi
done

# 写回更新后的任务列表
echo "$UPDATED_TASKS" > "$TASK_FILE"

echo ""
echo "======================================"
echo "监控完成"
echo "======================================"

# 通知（如果有需要通知的任务）
if [ ${#NEED_NOTIFICATION[@]} -gt 0 ]; then
    echo ""
    echo "需要通知的任务:"
    for item in "${NEED_NOTIFICATION[@]}"; do
        TASK_ID="${item%:*}"
        PR_OR_STATUS="${item#*:}"
        
        if [ "$PR_OR_STATUS" = "failed" ]; then
            echo "  ❌ $TASK_ID - 任务失败"
            # 这里可以调用OpenClaw的message工具发送通知
            # openclaw message --channel feishu --text "任务失败: $TASK_ID"
        else
            echo "  ✅ $TASK_ID - PR #$PR_OR_STATUS 准备好review"
            # openclaw message --channel feishu --text "PR #$PR_OR_STATUS 准备好review"
        fi
    done
fi

echo ""
echo "下次检查: 10分钟后"
