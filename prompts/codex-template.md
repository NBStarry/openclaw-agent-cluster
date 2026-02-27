# Codex Agent Prompt Template

## 任务
{description}

## 上下文

### 代码库信息
- 仓库: {repo}
- 分支: {branch}
- 工作目录: {worktree_path}

### 业务背景
{business_context}

### 客户信息（如果相关）
{customer_info}

### 相关会议记录
{meeting_notes}

## 技术要求

### 代码规范
- 遵循项目现有的编码风格
- TypeScript严格模式
- 所有公开API必须有类型注释
- 函数复杂度控制在15以内

### 测试要求
- 单元测试覆盖率 >= 80%
- 测试文件放在 `__tests__/` 目录
- 使用Jest/Vitest框架
- 关键路径必须有E2E测试

### 提交规范
- 遵循Conventional Commits规范
- 每个commit应该是一个逻辑单元
- commit message格式: `type(scope): description`
  - type: feat/fix/refactor/test/docs/chore
  - scope: 影响的模块
  - description: 简短描述（<50字符）

### 文件组织
- 类型定义: `src/types/`
- 工具函数: `src/utils/`
- API路由: `src/api/`
- 组件: `src/components/`
- 测试: `__tests__/`

## 完成标准

### 必须满足
- [ ] 代码编译无错误
- [ ] 所有测试通过
- [ ] Lint检查通过
- [ ] TypeScript类型检查通过
- [ ] 包含必要的单元测试
- [ ] 关键功能有E2E测试

### 提交要求
1. 完成代码后，运行完整测试: `pnpm test`
2. 运行lint检查: `pnpm lint`
3. 运行类型检查: `pnpm typecheck`
4. 提交所有更改
5. 推送到远程分支
6. 使用 `gh pr create --fill` 创建PR

## 注意事项

### 常见陷阱
- ⚠️ 检查类型定义是否在 `src/types/` 中已存在
- ⚠️ 不要直接修改 `node_modules/`
- ⚠️ 确保新的依赖已添加到 `package.json`
- ⚠️ 避免破坏现有的API契约

### 调试建议
- 使用 `console.log` 或 `debugger` 进行调试
- 查看 `package.json` 中的可用脚本
- 参考项目的 `README.md` 和 `CONTRIBUTING.md`

### 如果遇到问题
1. 先查看错误消息
2. 检查相关的类型定义文件
3. 参考类似的已有实现
4. 如果卡住超过30分钟，提交当前进度并在commit message中说明问题

## 开始

现在开始执行任务。记住：

1. **仔细阅读现有代码** - 理解项目结构和模式
2. **边写边测试** - 不要等到最后才运行测试
3. **小步提交** - 每完成一个逻辑单元就提交
4. **保持专注** - 只实现当前任务需要的功能，不要过度设计

祝你好运！🚀
