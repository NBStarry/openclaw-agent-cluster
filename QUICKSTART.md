# Agent集群系统 - 快速上手指南

## 10分钟搭建完整的AI开发团队

这个系统让你能像管理一个开发团队一样管理多个AI Agent，每个Agent专注于不同类型的任务。

## 架构概览

```
你（产品经理）
    ↓
OpenClaw（技术总监/Zoe）
    ├→ Codex（后端工程师） - 90%的任务
    ├→ Claude Code（前端工程师） - 8%的任务  
    └→ Gemini（UI设计师） - 2%的任务
```

## 第一步：运行安装脚本

```bash
cd /Users/longxiabei/.openclaw/workspace/agent-cluster
./setup-openclaw-cluster.sh
```

这个脚本会：
- 检查必要工具（git/tmux/gh/jq）
- 配置代码仓库路径
- 创建监控cron任务
- 生成配置摘要

## 第二步：创建监控任务

安装脚本会生成一个cron job配置文件。使用OpenClaw创建监控任务：

### 方法A：使用OpenClaw命令（推荐）

```bash
# 查看生成的配置
cat /tmp/openclaw-monitor-job.json

# 创建cron任务（如果有openclaw CLI）
openclaw cron add --job-file /tmp/openclaw-monitor-job.json
```

### 方法B：手动创建（如果没有openclaw CLI）

在OpenClaw聊天中直接说：

```
创建一个cron监控任务：
- 名称: agent-cluster-monitor
- 间隔: 每10分钟
- 任务: 运行 /Users/longxiabei/.openclaw/workspace/agent-cluster/scripts/monitor-agents.sh，检查所有Agent状态
- 使用opus模型
- 完成后通过Feishu通知
```

## 第三步：启动你的第一个Agent

### 示例1：后端功能开发（使用Codex）

```bash
./scripts/start-agent.sh feat-user-login codex "实现用户登录功能：邮箱密码登录 + JWT认证"
```

### 示例2：前端UI修复（使用Claude Code）

```bash
./scripts/start-agent.sh fix-button-style claude "修复首页按钮样式问题：按钮应该是圆角，背景色#4CAF50"
```

### 示例3：UI设计（使用Gemini）

```bash
./scripts/start-agent.sh design-dashboard gemini "设计一个数据分析仪表板：包含图表、指标卡片、过滤器"
```

## 第四步：监控Agent进度

### 查看tmux会话

```bash
# 查看所有运行中的Agent
tmux ls

# 进入某个Agent的会话
tmux attach -t feat-user-login

# 退出会话（不关闭）：按 Ctrl+B，然后按 D
```

### 查看任务状态

```bash
# 查看活跃任务
cat tasks/active-tasks.json | jq '.tasks'

# 手动运行监控（不等待cron）
./scripts/monitor-agents.sh
```

### 向Agent发送指令

如果Agent走偏了，你可以实时纠正：

```bash
# 发送指令
tmux send-keys -t feat-user-login "停一下。先做API层，别管UI。" Enter

# 提供更多上下文
tmux send-keys -t feat-user-login "类型定义在 src/types/user.ts，用那个。" Enter
```

## 第五步：等待PR就绪

监控系统会自动检查：
- ✅ tmux会话是否运行
- ✅ PR是否创建
- ✅ CI是否通过（lint/test/typecheck）
- ✅ AI Code Review是否通过

全部通过后，你会收到Feishu通知：

```
PR #123 准备好review: 实现用户登录功能
```

## 工作流完整示例

假设你要实现一个"导出数据"功能：

### 1. 与OpenClaw讨论需求（可选）

在Feishu中告诉你的OpenClaw（Zoe）：

```
客户希望能导出用户数据为CSV，包含姓名、邮箱、注册时间。
只有管理员能导出，需要权限检查。
```

Zoe可能会：
- 从会议记录中提取客户原话
- 从数据库中查看用户表结构（只读）
- 为你生成更精确的任务描述

### 2. 启动Agent

```bash
./scripts/start-agent.sh feat-export-users codex "
实现用户数据导出功能：
- 路由: GET /api/admin/users/export
- 格式: CSV（姓名、邮箱、注册时间）
- 权限: 需要admin角色
- 使用现有的User model
"
```

### 3. Agent自动工作

Agent会：
1. 创建git worktree和分支
2. 读取现有代码（User model, auth middleware）
3. 实现API路由
4. 添加权限检查
5. 写单元测试
6. 运行测试和lint
7. 提交代码
8. 创建PR

### 4. 监控自动运行

每10分钟，监控脚本会检查：
- Agent是否还在运行
- 是否创建了PR
- CI状态如何

### 5. 收到通知

约30-60分钟后（取决于任务复杂度），你收到通知：

```
PR #456 准备好review: 实现用户数据导出功能
- ✅ CI全部通过
- ✅ Codex reviewer批准
- ✅ Gemini reviewer批准
```

### 6. 快速Review

打开PR，你会看到：
- 3个AI reviewer的评论
- CI全部绿色
- 代码diff很清晰
- 测试覆盖率报告

5-10分钟review后，点击"Merge"。

## 高级技巧

### 1. 并行运行多个Agent

```bash
# 同时启动3个Agent处理不同任务
./scripts/start-agent.sh feat-export codex "导出功能"
./scripts/start-agent.sh fix-ui claude "修复UI bug"  
./scripts/start-agent.sh design-landing gemini "设计落地页"

# 查看所有活跃Agent
tmux ls
```

**注意**：每个Agent需要约2-4GB RAM。16GB Mac建议最多4-5个并行。

### 2. 失败后手动重试

如果Agent失败了，监控系统会自动重试（最多3次）。

手动重试：

```bash
# 杀掉失败的会话
tmux kill-session -t feat-export

# 重新启动（会使用调整后的prompt）
./scripts/start-agent.sh feat-export codex "导出功能（第2次尝试：专注API层，不做UI）"
```

### 3. 查看Agent的实时输出

```bash
# 进入tmux会话观察
tmux attach -t feat-export

# 看到Agent的思考过程、代码编辑、测试运行
# 按 Ctrl+B D 退出观察（不关闭会话）
```

### 4. 清理已完成的任务

```bash
# 手动清理（或等待每日自动清理）
./scripts/cleanup-worktrees.sh
```

## Agent选择策略

系统会根据任务描述自动选择Agent：

| 关键词 | Agent | 原因 |
|--------|-------|------|
| backend, api, database, auth | Codex | 后端逻辑需要深度推理 |
| bug, error, crash, exception | Codex | 复杂bug是Codex强项 |
| frontend, ui, component, react | Claude Code | 前端工作Claude更快 |
| design, dashboard, landing | Gemini | UI设计先由Gemini生成规范 |
| refactor, migrate, architecture | Codex | 大规模重构需要跨文件推理 |
| docs, changelog, readme | Claude Code | 文档工作Claude处理更快 |

手动指定Agent类型时，使用第二个参数：

```bash
./scripts/start-agent.sh <任务名> <agent类型> "<描述>"
#                                    ↑
#                              codex | claude | gemini
```

## 成本控制

### 起步阶段（$20/月）
- 1-2个并行Agent
- 主要用Codex（最可靠）
- 每天10-20个PR

### 重度使用（$190/月）
- 4-5个并行Agent
- Codex + Claude Code + Gemini
- 每天50-94个PR

### 省钱技巧
- Gemini是免费的，多用于UI设计
- Claude Code比Codex便宜，用于简单任务
- 失败重试会增加成本，优化prompt减少失败

## 故障排除

### Agent创建worktree失败

```bash
# 检查分支是否已存在
git branch -a | grep feat-export

# 删除已存在的分支
git branch -D feat/feat-export
```

### tmux会话连接失败

```bash
# 查看所有会话
tmux ls

# 杀掉僵尸会话
tmux kill-session -t <session-name>
```

### CI一直不通过

进入tmux会话查看Agent在干什么：

```bash
tmux attach -t <task-name>

# 如果卡住了，发送指令
tmux send-keys -t <task-name> "运行 pnpm test 看看哪个测试失败了" Enter
```

### 监控任务不运行

```bash
# 检查cron任务
# 在OpenClaw中运行：
cron action=list

# 查看任务状态
cron action=runs jobId=<your-job-id>
```

## 下一步

1. **集成你的业务上下文**
   - 将会议记录同步到Obsidian
   - 配置生产数据库只读访问
   - 添加客户配置API

2. **优化prompt模板**
   - 编辑 `prompts/codex-template.md`
   - 添加项目特定的规范
   - 记录成功的模式

3. **扩展Agent类型**
   - 添加更多专用Agent（测试Agent、文档Agent）
   - 配置不同的模型（Sonnet/Haiku）

4. **自动化更多环节**
   - 自动从Sentry抓取错误并创建任务
   - 自动从会议记录提取需求
   - 自动更新changelog

## 参考资料

- 完整文档: [README.md](README.md)
- 原文: https://mp.weixin.qq.com/s/gtxM1f3JmfXqDuxGIa3-ng
- Agent配置: [config/agent-profiles.json](config/agent-profiles.json)
- 任务规则: [config/task-rules.json](config/task-rules.json)

---

**祝你一天94次提交！🚀**
