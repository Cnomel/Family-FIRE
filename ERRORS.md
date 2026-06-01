# Family Fire — 错误追踪与经验教训

> 记录开发过程中遇到的错误和经验，避免重复犯错。

## 格式规范
每条记录包含：日期、模块、错误描述、根因、修复方案、预防措施

---

## 后端错误

### BE-001: `datetime.utcnow()` 已弃用
- **日期**: 2026-05-29
- **模块**: 全局
- **错误**: 使用 `datetime.utcnow()` 产生无时区时间，与 PostgreSQL 的 `TIMESTAMP WITHOUT TIME ZONE` 不兼容
- **根因**: Python 3.12 弃用 `utcnow()`，且 asyncpg 要求时区感知的 datetime
- **修复**: 全部替换为 `datetime.now(UTC)`
- **预防**: ruff 规则已启用 UP034 检查

### BE-002: SQLite 测试与 PostgreSQL 生产的差异
- **日期**: 2026-05-29
- **模块**: 测试
- **错误**: 测试使用 SQLite 内存库，某些 SQL 语法（如 `JSONB`、`ARRAY`）在 SQLite 不支持
- **根因**: 测试和生产使用不同数据库引擎
- **修复**: 测试中使用兼容的 JSON 字段类型，避免 PostgreSQL 特有语法
- **预防**: 新增模型时检查 SQLite 兼容性

### BE-003: Alembic 迁移需要 `render_as_batch`
- **日期**: 2026-05-29
- **模块**: 数据库迁移
- **错误**: SQLite 不支持 `ALTER TABLE` 的某些操作
- **根因**: SQLite 对 DDL 操作限制较多
- **修复**: `env.py` 中设置 `render_as_batch=True`
- **预防**: 生成迁移时始终检查 SQLite 兼容性

---

## Flutter 错误

### FE-001: `BuildContext` 跨 async gap 使用
- **日期**: 2026-05-29
- **模块**: 多个页面
- **错误**: 在 `async` 方法中使用 `context` 但未检查 `mounted`
- **根因**: 异步操作后 widget 可能已销毁
- **修复**: 使用 `if (!mounted) return;` 守卫
- **预防**: `analysis_options.yaml` 已启用 `use_build_context_synchronously` lint

### FE-002: 废弃 API `TextFormField.value`
- **日期**: 2026-05-29
- **模块**: 表单页面
- **错误**: 使用 `TextFormField(value: ...)` 已废弃
- **根因**: Flutter 3.33.0 废弃了 `value` 参数
- **修复**: 替换为 `initialValue`
- **预防**: 运行 `flutter analyze` 检查废弃警告

### FE-003: 未使用的导入和字段
- **日期**: 2026-05-29
- **模块**: 多个文件
- **错误**: 存在未使用的 import 和未使用的字段变量
- **根因**: 重构后遗留
- **修复**: 删除未使用的导入和字段
- **预防**: CI 中启用 `flutter analyze --fatal-infos`

### FE-004: 硬编码中文字符串未走国际化
- **日期**: 2026-05-29
- **模块**: 多个页面
- **错误**: 页面中直接写中文字符串，未使用 `AppLocalizations`
- **根因**: 开发时为快速迭代跳过了国际化
- **修复**: 逐步替换为 `context.l10n.xxx`
- **预防**: PR 模板中检查国际化

### FE-005: Map<String, dynamic> 类型不安全
- **日期**: 2026-05-29
- **模块**: 数据层
- **错误**: API 响应直接用 `Map` 处理，无类型检查
- **根因**: 未建立独立的 models 层
- **修复**: 引入 json_serializable 模型类
- **预防**: 新增 API 对应的 model 类

### FE-006: 扫码功能为模拟实现
- **日期**: 2026-05-29
- **模块**: ScanPage
- **错误**: 扫码结果硬编码为 `6901234567890`
- **根因**: 未集成真实扫码库
- **修复**: 集成 `mobile_scanner` 库
- **预防**: 标记为 TODO 并跟踪

### FE-007: PDF 预览未完成
- **日期**: 2026-05-29
- **模块**: PdfViewerPage
- **错误**: 页面仅显示占位文本
- **根因**: pdfx 库集成未完成
- **修复**: 完成 pdfx 集成
- **预防**: 功能页面必须有基本可用实现

---

## 架构经验

### ARCH-001: 测试先行
- **教训**: 每个功能模块应在实现前先写测试骨架
- **实践**: 后端 182 测试全部通过，Flutter 测试几乎为零
- **行动**: Flutter 需要补充 widget 测试和集成测试

### ARCH-002: 国内化需从设计开始
- **教训**: 颜色（红涨绿跌）、货币（万/亿）、日期格式需要在组件层统一
- **实践**: 后端分类做得好，Flutter 的 `shared/` 工具类也已到位
- **行动**: 确保所有金额显示使用 `AmountText` 和 `currency.dart`

### ARCH-003: 离线能力需要同步机制
- **教训**: 简单的内存缓存不足以支持离线场景
- **实践**: Drift 数据库和 SyncService 均为 TODO
- **行动**: 需要设计冲突解决策略

### ARCH-004: API 错误处理需统一
- **教训**: 前端需要统一的错误映射和用户友好提示
- **实践**: `ApiException` 已实现，但部分页面未正确处理
- **行动**: 检查所有 API 调用的错误处理

---

## 待修复清单

| ID | 优先级 | 模块 | 描述 | 状态 |
|----|--------|------|------|------|
| FE-001 | P1 | Flutter | BuildContext 跨 async gap | 待修复 |
| FE-002 | P2 | Flutter | 废弃 API 使用 | 待修复 |
| FE-003 | P2 | Flutter | 未使用的导入和字段 | 待修复 |
| FE-004 | P3 | Flutter | 硬编码中文字符串 | 待修复 |
| FE-005 | P2 | Flutter | 无类型安全的 Map 操作 | 待修复 |
| FE-006 | P3 | Flutter | 扫码功能模拟 | 待修复 |
| FE-007 | P3 | Flutter | PDF 预览未完成 | 待修复 |

---

*最后更新: 2026-06-01*
