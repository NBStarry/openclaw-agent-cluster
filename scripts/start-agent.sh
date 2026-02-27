#!/bin/bash
# start-agent.sh - 启动一个Agent处理任务
#
# 用法: ./start-agent.sh <task-name> <agent-type> <description>
#
# 示例:
#   ./start-agent.sh feat-user-auth codex "实现用户认证系统"
#   ./start-agent.sh fix-login-bug codex "修复登录页面bug"
#   ./start-agent.sh ui-dashboard gemini "设计新的仪表板UI"

set -e

# 参数检查
if [ "$#" -lt 3 ]; then
    echo "用法: $0 <task-name> <agent-type> <description>"
    echo ""
    echo "示例:"
    echo "  $0 feat-user-auth codex \"实现用户认证系统\""
    echo ""
    echo "可用的agent类型: codex, claude, gemini"
    exit 1
fi

TASK_NAME="$1"
AGENT_TYPE="$2"
DESCRIPTION="$3"

# 配置
REPO_ROOT="${REPO_ROOT:-$PWD}"
WORKTREE_BASE="${WORKTREE_BASE:-$REPO_ROOT/../worktrees}"
BRANCH_NAME="${BRANCH_PREFIX:-feat}/$TASK_NAME"
TMUX_SESSION="${TASK_NAME}"

# Agent命令配置
case "$AGENT_TYPE" in
    codex)
        AGENT_CMD="codex"  # 或你的Codex CLI命令
        MODEL="gpt-5.3-codex"
        ;;
    claude)
        AGENT_CMD="claude-code"  # 或你的Claude Code CLI命令
        MODEL="claude-opus-4-5"
        ;;
    gemini)
        AGENT_CMD="gemini-agent"  # 或你的Gemini CLI命令
        MODEL="gemini-2.0-flash-exp"
        ;;
    *)
        echo "错误: 未知的agent类型: $AGENT_TYPE"
        echo "可用: codex, claude, gemini"
        exit 1
        ;;
esac

echo "============================================"
echo "启动Agent任务"
echo "============================================"
echo "任务名称: $TASK_NAME"
echo "Agent类型: $AGENT_TYPE ($MODEL)"
echo "描述: $DESCRIPTION"
echo "分支: $BRANCH_NAME"
echo "Worktree: $WORKTREE_BASE/$TASK_NAME"
echo "tmux会话: $TMUX_SESSION"
echo "============================================"

# 1. 创建worktree
echo "📦 创建git worktree..."
mkdir -p "$WORKTREE_BASE"
cd "$REPO_ROOT"

git worktree add "$WORKTREE_BASE/$TASK_NAME" -b "$BRANCH_NAME" origin/main || {
    echo "❌ worktree创建失败"
    exit 1
}

# 2. 安装依赖（如果需要）
echo "📥 安装依赖..."
cd "$WORKTREE_BASE/$TASK_NAME"
if [ -f "package.json" ]; then
    pnpm install --frozen-lockfile || npm install
fi

# 3. 生成prompt（从业务上下文）
echo "✍️ 生成Agent prompt..."
PROMPT_FILE="/tmp/agent-prompt-$TASK_NAME.txt"

cat > "$PROMPT_FILE" << EOF
任务: $DESCRIPTION

分支: $BRANCH_NAME
工作目录: $WORKTREE_BASE/$TASK_NAME

要求:
1. 仔细阅读现有代码和类型定义
2. 遵循项目的编码规范
3. 包含必要的测试
4. 提交前运行测试和lint
5. 完成后使用: gh pr create --fill

注意:
- 如果遇到类型错误，检查 src/types/ 目录
- 测试文件放在 __tests__/ 目录
- 遵循现有的文件组织结构

开始吧！
EOF

# 4. 启动tmux会话
echo "🚀 启动tmux会话: $TMUX_SESSION"

tmux new-session -d -s "$TMUX_SESSION" \
    -c "$WORKTREE_BASE/$TASK_NAME" \
    "$AGENT_CMD --model $MODEL --prompt-file $PROMPT_FILE"

# 5. 记录任务到JSON
echo "📝 记录任务..."
TASK_FILE="$(dirname "$0")/../tasks/active-tasks.json"
TIMESTAMP=$(date +%s000)

# 创建任务记录（如果文件不存在则初始化）
if [ ! -f "$TASK_FILE" ]; then
    echo '{"tasks": []}' > "$TASK_FILE"
fi

# 添加任务（使用jq，如果没有则回退到手动编辑）
if command -v jq &> /dev/null; then
    TEMP_FILE=$(mktemp)
    jq --arg id "$TASK_NAME" \
       --arg tmux "$TMUX_SESSION" \
       --arg agent "$AGENT_TYPE" \
       --arg desc "$DESCRIPTION" \
       --arg repo "$(basename $REPO_ROOT)" \
       --arg worktree "$TASK_NAME" \
       --arg branch "$BRANCH_NAME" \
       --arg started "$TIMESTAMP" \
       '.tasks += [{
         id: $id,
         tmuxSession: $tmux,
         agent: $agent,
         description: $desc,
         repo: $repo,
         worktree: $worktree,
         branch: $branch,
         startedAt: ($started | tonumber),
         status: "running",
         retries: 0,
         notifyOnComplete: true
       }]' "$TASK_FILE" > "$TEMP_FILE"
    
    mv "$TEMP_FILE" "$TASK_FILE"
else
    echo "⚠️ 警告: 未安装jq，跳过JSON记录"
fi

echo ""
echo "✅ Agent已启动"
echo ""
echo "查看进度:"
echo "  tmux attach -t $TMUX_SESSION"
echo ""
echo "发送指令给Agent:"
echo "  tmux send-keys -t $TMUX_SESSION \"你的指令\" Enter"
echo ""
echo "停止Agent:"
echo "  tmux kill-session -t $TMUX_SESSION"
echo ""
echo "监控将在10分钟后开始检查进度。"
echo "============================================"
