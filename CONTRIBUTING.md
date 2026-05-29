# Contributing to Family Fire

感谢你对 Family Fire 项目的关注！我们欢迎任何形式的贡献。

## 如何贡献

### 报告 Bug

1. 在 [Issues](https://github.com/your-repo/family-fire/issues) 中搜索是否已有相同问题
2. 如果没有，使用 **Bug Report** 模板创建新 Issue
3. 请提供：复现步骤、期望行为、实际行为、环境信息

### 提交功能请求

1. 使用 **Feature Request** 模板创建 Issue
2. 描述你的需求和使用场景
3. 等待维护者反馈后再开始开发

### 提交代码

1. Fork 本仓库
2. 创建功能分支：`git checkout -b feat/your-feature`
3. 提交代码：`git commit -m "feat: description"`
4. 推送分支：`git push origin feat/your-feature`
5. 创建 Pull Request

## 开发规范

### 分支命名

- `feat/xxx` — 新功能
- `fix/xxx` — Bug 修复
- `docs/xxx` — 文档更新
- `refactor/xxx` — 代码重构
- `test/xxx` — 测试相关

### Commit 规范

使用 [Conventional Commits](https://www.conventionalcommits.org/) 格式：

```
feat: 新增资产搜索功能
fix: 修复登录Token过期问题
docs: 更新API文档
test: 添加资产CRUD测试
```

### 代码风格

**后端 (Python)**
- 使用 `ruff` 进行代码检查和格式化
- 运行 `uv run ruff check app/` 检查代码
- 运行 `uv run ruff format app/` 格式化代码
- 所有函数需要类型注解
- 中文注释和错误消息

**前端 (Flutter/Dart)**
- 使用 `dart format` 格式化代码
- 运行 `flutter analyze` 检查代码
- 遵循 Flutter 官方风格指南

### 测试要求

- 新功能必须包含测试
- Bug 修复必须包含复现测试
- 运行 `uv run pytest tests/ -v` 确保所有测试通过
- 运行 `cd mobile && flutter test` 确保 Flutter 测试通过

### Pull Request 规范

- 标题清晰描述变更内容
- 说明变更的原因和背景
- 关联相关的 Issue
- 确保 CI 通过
- 至少一个维护者审查

## 本地开发

```bash
# 1. 克隆仓库
git clone https://github.com/your-repo/family-fire.git
cd family-fire

# 2. 启动基础设施
docker-compose up -d postgres redis minio

# 3. 安装后端依赖
cd backend
uv sync --all-extras

# 4. 配置环境变量
cp ../.env.example .env

# 5. 运行测试
uv run pytest -v

# 6. 启动后端
uv run uvicorn app.main:app --reload

# 7. 启动 Flutter
cd ../mobile
flutter pub get
flutter run
```

## 行为准则

请阅读并遵守我们的 [Code of Conduct](CODE_OF_CONDUCT.md)。

## 问题？

如有疑问，请在 [Discussions](https://github.com/your-repo/family-fire/discussions) 中提问。

感谢你的贡献！
