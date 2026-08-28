---
title: 安全与审计
---

containerd 项目高度关注容器运行时层的安全性，因为有大量其他软件系统依赖于这一层。
我们有一套清晰且文档完善的安全流程，并利用 GitHub 的安全功能及其 CVE 编号授权机构，
来妥善披露已识别并确认的漏洞。

### 报告安全问题 {#reporting-security-issues}

请遵循 `containerd/project` GitHub 仓库中 [SECURITY.md](https://github.com/containerd/project/blob/main/SECURITY.md) 所描述的项目报告流程。

### 安全审计 {#security-audits}

在 CNCF 或其他相关方的投入支持下，项目会不定期进行安全审计。当这些审计产出的公开报告
发布时，我们会将它们发布在下表中。

| 名称/链接 | 描述 | 日期 |
|---------------------------------------|-------------------------------------------------------------------|--------|
| Fuzzing 审计 - [ADA-fuzzing-audit-21-22.pdf](../img/ADA-fuzzing-audit-21-22.pdf) | 由 CNCF 出资的 fuzzing 审计，由 Ada Logics 执行 | 2023 年 3 月 |
| CNCF 毕业项目审计 - [SECURITY_AUDIT.pdf](../img/SECURITY_AUDIT.pdf) | 由 CNCF 出资的安全审计，由 Cure53 执行 | 2018 年 11 月 |
