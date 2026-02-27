#!/bin/bash
# setup-openclaw-cluster.sh - 在OpenClaw中配置Agent集群系统
#
# 这个脚本会:
# 1. 创建cron监控任务
# 2. 配置agent profiles
# 3. 设置通知
# 4. 初始化任务跟踪

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "======================================"
echo "OpenClaw Agent集群系统 - 配置向导"
echo "======================================"
echo ""

# 1. 检查OpenClaw是否可用
echo "检查OpenClaw..."
if ! command -v openclaw &> /dev/null; then
    echo "❌ 未找到openclaw命令"
    echo "请确保OpenClaw已正确安装并添加到PATH"
    exit 1
fi
echo "✅ OpenClaw已安装"
echo ""

# 2. 检查必要工具
echo "检查必要工具..."
MISSING_TOOLS=()

if ! command -v git &> /dev/null; then
    MISSING_TOOLS+=("git")
fi

if ! command -v tmux &> /dev/null; then
    MISSING_TOOLS+=("tmux")
fi

if ! command -v gh &> /dev/null; then
    echo "⚠️ 警告: 未安装gh CLI（GitHub CLI）"
    echo "   部分功能（PR创建、CI状态检查）将不可用"
fi

if ! command -v jq &> /dev/null; then
    MISSING_TOOLS+=("jq")
fi

if [ ${#MISSING_TOOLS[@]} -gt 0 ]; then
    echo "❌ 缺少必要工具: ${MISSING_TOOLS[*]}"
    echo ""
    echo "请安装:"
    echo "  macOS: brew install ${MISSING_TOOLS[*]}"
    echo "  Ubuntu: sudo apt install ${MISSING_TOOLS[*]}"
    exit 1
fi

echo "✅ 所有必要工具已安装"
echo ""

# 3. 配置代码仓库路径
echo "配置代码仓库..."
echo -n "请输入你的代码仓库路径 (默认: $PWD): "
read -r REPO_PATH
REPO_PATH="${REPO_PATH:-$PWD}"

if [ ! -d "$REPO_PATH/.git" ]; then
    echo "❌ 路径不是一个git仓库: $REPO_PATH"
    exit 1
fi

echo "✅ 仓库路径: $REPO_PATH"
echo ""

# 4. 配置worktree存放路径
WORKTREE_BASE="$REPO_PATH/../agent-worktrees"
echo "Worktree将存放在: $WORKTREE_BASE"
mkdir -p "$WORKTREE_BASE"
echo ""

# 5. 创建监控cron任务
echo "创建监控cron任务..."

# 生成OpenClaw cron job配置
cat > /tmp/openclaw-monitor-job.json << EOF
{
  "name": "agent-cluster-monitor",
  "schedule": {
    "kind": "every",
    "everyMs": 600000
  },
  "payload": {
    "kind": "agentTurn",
    "message": "执行Agent集群监控任务:\n1. 运行 $SCRIPT_DIR/scripts/monitor-agents.sh\n2. 检查所有活跃Agent的状态\n3. 更新任务记录\n4. 如果有任务完成或失败，通过Feishu通知",
    "model": "anthropic/claude-opus-4-6",
    "timeoutSeconds": 120
  },
  "sessionTarget": "isolated",
  "delivery": {
    "mode": "announce",
    "bestEffort": true
  },
  "enabled": true
}
EOF

echo "Cron job配置已生成: /tmp/openclaw-monitor-job.json"
echo ""
echo "请运行以下命令创建cron任务:"
echo ""
echo "  openclaw cron add --job-file /tmp/openclaw-monitor-job.json"
echo ""
echo "或者手动使用cron工具:"
echo "  cron action=add job=<paste-json-here>"
echo ""

# 6. 创建配置摘要
cat > "$SCRIPT_DIR/SETUP_SUMMARY.md" << EOF
# Agent集群系统配置摘要

配置时间: $(date '+%Y-%m-%d %H:%M:%S')

## 配置信息

- **代码仓库**: $REPO_PATH
- **Worktree路径**: $WORKTREE_BASE
- **监控间隔**: 每10分钟
- **监控脚本**: $SCRIPT_DIR/scripts/monitor-agents.sh

## 已创建的文件

- README.md - 系统文档
- config/agent-profiles.json - Agent配置
- config/task-rules.json - 任务规则
- scripts/start-agent.sh - 启动脚本
- scripts/monitor-agents.sh - 监控脚本
- tasks/active-tasks.json - 任务跟踪
- prompts/codex-template.md - Prompt模板

## 下一步

### 1. 创建监控cron任务

在OpenClaw中运行:
\`\`\`bash
openclaw cron add --job-file /tmp/openclaw-monitor-job.json
\`\`\`

或使用cron工具（参考上面的JSON配置）

### 2. 配置你的Agent CLI

确保已安装并配置:
- Codex CLI (或OpenClaw + Codex)
- Claude Code CLI
- Gemini CLI（可选）

### 3. 启动第一个任务

\`\`\`bash
cd $SCRIPT_DIR
chmod +x scripts/*.sh
./scripts/start-agent.sh my-first-task codex "测试任务：创建一个hello world功能"
\`\`\`

### 4. 查看监控

等待10分钟后，监控任务会自动运行并检查进度。

或手动运行:
\`\`\`bash
./scripts/monitor-agents.sh
\`\`\`

### 5. 查看Agent进度

\`\`\`bash
# 进入tmux会话
tmux attach -t my-first-task

# 查看所有活跃会话
tmux ls

# 发送指令给Agent
tmux send-keys -t my-first-task "你的指令" Enter
\`\`\`

## 成本估算

基于文章中的数据:
- 新手起步: \$20/月 (1-2个并行Agent)
- 重度使用: \$190/月 (Codex \$100 + Claude \$90, 4-5个并行Agent)

## 性能指标目标

根据文章案例:
- 单日提交: 50-94次
- PR完成速度: 7个PR/30分钟
- Review时间: 5-10分钟/PR

## 参考资料

- 原文: https://mp.weixin.qq.com/s/gtxM1f3JmfXqDuxGIa3-ng
- 系统文档: $SCRIPT_DIR/README.md
EOF

echo "======================================"
echo "✅ 配置完成！"
echo "======================================"
echo ""
echo "配置摘要已保存到: $SCRIPT_DIR/SETUP_SUMMARY.md"
echo ""
echo "请查看该文件了解下一步操作。"
echo ""
echo "快速开始:"
echo "  1. 创建监控cron任务（见上面的输出）"
echo "  2. 运行: cd $SCRIPT_DIR && ./scripts/start-agent.sh test-task codex \"测试任务\""
echo ""
