# Agent Cluster System

基于文章《OpenClaw + Claude Code 超强教程：一个人就能搭建完整的开发团队！》实现的双层Agent集群架构。

## 架构

### 编排层（OpenClaw/Zoe）
- 持有所有业务上下文
- 任务分配和代理选择
- 监控代理进度
- 失败重试和prompt优化

### 执行层（Agents）
- **Codex** (gpt-5.3-codex) - 主力，后端逻辑、复杂bug、多文件重构
- **Claude Code** (opus-4.5) - 速度型，前端工作、git操作
- **Gemini** - 设计师，UI设计和规范

## 完整工作流（8步）

1. **客户需求 → OpenClaw理解拆解**
   - 自动读取会议记录（Obsidian同步）
   - 理解业务上下文
   - 拆解任务

2. **启动代理**
   - 创建独立git worktree
   - 启动tmux会话
   - 记录任务到JSON

3. **自动监控**
   - cron每10分钟检查状态
   - 检查tmux会话、PR、CI状态
   - 失败自动重试（最多3次）

4. **Agent创建PR**
   - 代码完成后提交推送
   - 使用gh pr create --fill
   - 等待审查

5. **自动化Code Review**
   - 3个AI reviewer审查
   - Codex reviewer（最靠谱）
   - Gemini reviewer（免费好用）
   - Claude Code reviewer（过度谨慎）

6. **自动化测试**
   - Lint和TypeScript检查
   - 单元测试
   - E2E测试
   - UI改动必须包含截图

7. **人工Review**
   - 收到Telegram通知
   - 快速review（5-10分钟）
   - 批准合并

8. **合并**
   - PR合并到main
   - cron清理worktree和任务记录

## 三个核心机制

### 1. 改进版Ralph Loop
- 失败后分析原因
- 动态调整prompt（不是重复执行）
- 学习成功模式
- 主动发现任务

### 2. Agent选择策略
- **Codex**: 90%的任务，后端逻辑、复杂bug
- **Claude Code**: 前端工作、速度优先
- **Gemini**: UI设计（先设计规范，再交给Claude Code实现）

### 3. 资源管理
- 每个Agent需要独立worktree + node_modules
- 内存是瓶颈（不是token成本）
- 16GB RAM最多4-5个并行Agent

## 目录结构

```
agent-cluster/
├── README.md                    # 本文件
├── config/
│   ├── agent-profiles.json     # Agent配置（Codex/Claude/Gemini）
│   └── task-rules.json         # 任务分配规则
├── scripts/
│   ├── start-agent.sh          # 启动Agent（创建worktree + tmux）
│   ├── monitor-agents.sh       # 监控脚本（cron调用）
│   ├── cleanup-worktrees.sh    # 清理孤立worktree
│   └── agent-selector.js       # Agent选择逻辑
├── tasks/
│   ├── active-tasks.json       # 活跃任务跟踪
│   └── completed-tasks.json    # 已完成任务历史
└── prompts/
    ├── codex-template.md       # Codex prompt模板
    ├── claude-template.md      # Claude Code prompt模板
    └── gemini-template.md      # Gemini prompt模板
```

## 快速开始

### 前置条件
- OpenClaw已安装
- 已配置Codex/Claude Code/Gemini API
- Git仓库（支持worktree）
- tmux安装
- gh CLI（GitHub CLI）

### 安装步骤

1. **配置Agent profiles**
```bash
# 编辑 config/agent-profiles.json
# 填入你的API keys和model配置
```

2. **创建cron监控任务**
```bash
# 在OpenClaw中创建cron job
# 每10分钟运行 scripts/monitor-agents.sh
```

3. **测试启动一个Agent**
```bash
./scripts/start-agent.sh <task-name> <agent-type> <description>
# 例如：
./scripts/start-agent.sh feat-user-auth codex "实现用户认证系统"
```

## 成本估算

- **新手起步**: $20/月
  - Codex基础用量
  - 1-2个并行Agent

- **重度使用**: $190/月
  - Codex $100
  - Claude Code $90
  - 4-5个并行Agent

## 性能指标

- 单日最高: 94次提交
- 30分钟: 7个PR
- 平均每天: 50次提交
- Review时间: 5-10分钟/PR

## 参考资料

- 原文: https://mp.weixin.qq.com/s/gtxM1f3JmfXqDuxGIa3-ng
- X帖子: https://x.com/elvissun/status/2025920521871716562

## 下一步

1. 根据你的项目调整配置
2. 设置Obsidian同步（可选，用于会议记录）
3. 配置生产数据库只读访问（可选）
4. 设置Telegram通知
5. 开始第一个任务！
