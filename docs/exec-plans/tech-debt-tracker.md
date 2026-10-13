# 技术债追踪

| ID | 内容 | 风险 | 计划 |
|---|---|---|---|
| TD-1 | PBKDF2 为手写实现（Models.swift）而非系统 CommonCrypto 的 CCKeyDerivationPBKDF | 自研密码学代码在维护中出错的风险；当前实现经审计确认正确 | 冻结不动；如需改动必须用户确认并替换为系统库 |
| TD-2 | 本地开发环境为 Linux，无法运行 swift build/test | 验证完全依赖 CI | CI 已有 build；测试 job 在步骤 7 加入 |
| TD-3 | 导出服务临时目录（DOCX/EPUB）不清理 | /tmp 残留 | 恢复导出功能时顺手修复（try? 清理） |
| TD-4 | 原版同步逻辑（CloudSyncService.swift）被排除 | 无 | 用户明确排除；数据层已解耦，未来可选 |
