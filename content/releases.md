---
title: 版本管理与发布
---

本文档详细说明 containerd 的版本管理与发布计划。稳定性是本项目的首要目标，我们
希望本文档及其涉及的流程有助于实现这一目标。文档涵盖发布流程、版本号规则、
backport、API 稳定性以及支持周期。

如果你依赖 containerd，值得花些时间了解 API 中哪些部分受支持、哪些不受支持，
以及它们将来会如何影响你的项目。

本文档是一份持续更新的文档。支持时间线、backport 目标和 API 稳定性保证都会随着
变化在此更新。

如果有你需要但本文档未涵盖的内容，请通过[提交 issue](https://github.com/containerd/containerd/issues)
与我们联系。

## 发布版本 {#releases}

containerd 的发布版本使用三段点分号，类似于[语义化版本](http://semver.org/)。
在本文档中，我们将这三段分别称为 `<major>.<minor>.<patch>`。版本号可能带有额外
信息，例如 alpha、beta 和 release candidate 标识。这类发布被视为「预发布版本」。

### 主版本与次版本发布 {#major-and-minor-releases}

containerd 的主版本（major）和次版本（minor）发布从 main 分支进行。containerd 的
发布版本会打上 GPG 签名的 tag，并在
https://github.com/containerd/containerd/releases 公布。tag 格式为
`v<major>.<minor>.<patch>`，应使用命令 `git tag -s v<major>.<minor>.<patch>`
创建。

次版本发布之后，会从该次版本 tag 创建一个格式为 `release/<major>.<minor>` 的
分支。后续所有补丁版本都从该分支发布。例如，一旦发布 `v1.0.0`，就会从该 tag
创建分支 `release/1.0`。将来所有补丁版本都基于该分支发布。

### 发布节奏 {#release-cadence}

自 2026 年 4 月的 containerd v2.3 起，次版本按时间节奏发布，周期为 4 个月。新的
次版本计划在每年的 4 月、8 月和 12 月发布。该节奏与 Kubernetes 的发布计划保持
同步，以确保 containerd 中的新特性能够被新的 Kubernetes 版本顺利采用。

维护者会为每个发布版本维护路线图和里程碑，不过特性可能会为了配合发布时间线而被
推迟。如果你的 issue 或特性不在路线图中，请提交 GitHub issue 或留言请求将其加入
某个里程碑。

作为与 Kubernetes 发布计划同步的一部分，containerd 会切出与 Kubernetes 发布周期
对齐的 beta 和 release candidate 版本。这样可以在两个项目正式发布之前，用兼容的
containerd 版本对 Kubernetes 新特性做端到端测试。

### 补丁版本发布 {#patch-releases}

补丁版本直接从发布分支发布，由发布分支的负责人按需进行。

### 预发布版本 {#pre-releases}

alpha、beta 和 release candidate 等预发布版本从各自的源分支发布。对于主版本和
次版本，这些预发布从 main 分支进行。对于补丁版本，预发布并不常见，但发布分支
负责人可以自行决定是否发布 rc。

### 支持周期 {#support-horizon}

支持周期按发布分支定义，以 `<major>.<minor>` 标识。发布分支会处于以下几种状态
之一：

- <strong><em>Future</em></strong>：即将到来的计划发布版本。
- <strong><em>Alpha</em></strong>：main 分支上正在积极开发的下一个计划发布版本。
- <strong><em>Beta</em></strong>：main 分支上正在测试的下一个计划发布版本。从正式发布前 8-10 周开始。
- <strong><em>RC</em></strong>：main 分支上正在进行最终测试和稳定化的下一个计划发布版本。从正式发布前 2-4 周开始。对于源分支为 main 的新发布版本，main 分支在此阶段会进入特性冻结。
- <strong><em>Active</em></strong>：该发布版本是当前受支持、接受补丁的稳定分支。
- <strong><em>Extended</em></strong>：该发布分支只接受安全补丁。
- <strong><em>LTS</em></strong>：该发布版本是当前受支持、接受补丁的长期稳定分支。
- <strong><em>End of Life</em></strong>：该发布分支不再受支持，不会再接受新的补丁。

常规（非 LTS）发布版本在 _minor_ 版本发布后支持 8 个月。这意味着在生命周期结束
日期之前，我们会接受针对这些发布分支的缺陷报告和 backport。此外，发布版本在
active 期结束后还可能有一段延长的安全支持期，用于接受安全 backport。这一时间范围
由维护者在 active 状态结束前决定。

每年会有一个发布版本被指定为长期稳定版（_LTS_）。LTS 版本在其首个 _minor_
（x.y.0）发布之后至少支持两年。_LTS_ 分支的维护者可以承诺更长的期限，或按需延长
支持期。这些分支在生命周期结束日期之前接受缺陷报告和 backport。相比非 _LTS_
发布版本，它们还可能接受范围更广的补丁，以支持分支的长期可维护性，包括库依赖、
工具链（含 Go）以及其他为确保每个发布版本都由完全受支持的依赖构建而必需的版本
更新。特性 backport 由拥有该分支的维护者自行决定，但默认应予以拒绝。

常规发布与 LTS 发布的组合，让用户可以在更快采用新特性和优先考虑稳定性与更长支持
周期之间做出选择。

### 发布负责人 {#release-owners}

每个发布版本在进入 beta 阶段时都应指定负责人。最初的发布负责人负责创建发布版本并
确保发布按时完成。一旦发布进入 rc 阶段，发布负责人应参与任何有关合并高影响或高
风险改动的讨论。每个发布版本应至少有两名负责人，他们都是活跃的维护者，且其中至少
一人曾在此前至少两个发布版本中担任过发布负责人。

正式发布之后，发布分支转为 active 状态，所有权将移交回全体 committer。active 状态
的发布版本由全体 committer 维护，直到该发布到达生命周期结束或分支转为 _LTS_。

每个 _LTS_ 发布版本都需要至少两名维护者自愿担任负责人。_LTS_ 发布的负责人如果无法
继续支持该发布版本，可以随时卸任或由其他维护者接替。如果在维护者卸任后没有维护者
自愿担任该 _LTS_ 发布的负责人，该分支将在 6 个月的延长支持后结束生命周期，所有权
移交回全体 committer。

### containerd 发布版本的当前状态 {#current-state-of-containerd-releases}

| 发布版本                                                              | 状态           | 起始时间                        | 生命周期结束                    | 负责人                 |
| -------------------------------------------------------------------- | -------------- | ------------------------------ | ------------------------------ | ---------------------- |
| [0.0](https://github.com/containerd/containerd/releases/tag/0.0.5)   | End of Life    | Dec 4, 2015                    | -                              |                        |
| [0.1](https://github.com/containerd/containerd/releases/tag/v0.1.0)  | End of Life    | Mar 21, 2016                   | -                              |                        |
| [0.2](https://github.com/containerd/containerd/tree/v0.2.x)          | End of Life    | Apr 21, 2016                   | December 5, 2017               |                        |
| [1.0](https://github.com/containerd/containerd/releases/tag/v1.0.3)  | End of Life    | December 5, 2017               | December 5, 2018               |                        |
| [1.1](https://github.com/containerd/containerd/releases/tag/v1.1.8)  | End of Life    | April 23, 2018                 | October 23, 2019               |                        |
| [1.2](https://github.com/containerd/containerd/releases/tag/v1.2.13) | End of Life    | October 24, 2018               | October 15, 2020               |                        |
| [1.3](https://github.com/containerd/containerd/releases/tag/v1.3.10) | End of Life    | September 26, 2019             | March 4, 2021                  |                        |
| [1.4](https://github.com/containerd/containerd/releases/tag/v1.4.13) | End of Life    | August 17, 2020                | March 3, 2022                  |                        |
| [1.5](https://github.com/containerd/containerd/releases/tag/v1.5.18) | End of Life    | May 3, 2021                    | February 28, 2023              |                        |
| [1.6](https://github.com/containerd/containerd/releases/tag/v1.6.39) | End of Life    | February 15, 2022              | August 23, 2025                |                        |
| [1.7](https://github.com/containerd/containerd/releases/tag/v1.7.33) | LTS            | March 10, 2023                 | September 2026*                | [@samuelkarp](https://github.com/samuelkarp), [@chrishenzie](https://github.com/chrishenzie) |
| [2.0](https://github.com/containerd/containerd/releases/tag/v2.0.10) | LTS            | November 5, 2024               | March, 2027**                  | [@samuelkarp](https://github.com/samuelkarp), [@chrishenzie](https://github.com/chrishenzie) |
| [2.1](https://github.com/containerd/containerd/releases/tag/v2.1.9)  | End of Life    | May 7, 2025                    | July 3, 2026                   |                        |
| [2.2](https://github.com/containerd/containerd/releases/tag/v2.2.5)  | Active         | November 5, 2025               | November 6, 2026               | @containerd/committers |
| [2.3](https://github.com/containerd/containerd/releases/tag/v2.3.2)  | LTS            | April 30, 2026                 | April 30, 2028                 | @containerd/committers |
| [2.4](https://github.com/containerd/containerd/milestone/51)         | _Future_       | August 26, 2026 (_tentative_)  | April 26, 2027 (_tentative_)   | @containerd/committers |

\* 1.7 发布分支的支持由 @containerd/committers 提供，直到 March 10, 2026。延长至 September 2026 的支持由 [@samuelkarp](https://github.com/samuelkarp) 和 [@chrishenzie](https://github.com/chrishenzie) 提供。该延长支持聚焦于通过 [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine) 与 Kubernetes 1.32、1.31 和 1.30 配合使用的场景。如果改动对该场景并非必需，可能不会被接受。

\*\* 2.0 发布分支的支持由 @containerd/committers 提供，直到 November 7, 2025。延长至 March 2027 的支持由 [@samuelkarp](https://github.com/samuelkarp) 和 [@chrishenzie](https://github.com/chrishenzie) 提供。该延长支持聚焦于通过 [Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine) 与 Kuberentes 1.33 配合使用的场景。如果改动对该场景并非必需，可能不会被接受。

### Kubernetes 支持 {#kubernetes-support}

Kubernetes 版本矩阵列出了针对某个 Kubernetes 发布版本推荐使用的 containerd 版本。
任何处于活跃支持状态的 containerd 版本都可能收到补丁，以修复在任意 Kubernetes
版本中遇到的缺陷，不过我们的推荐依据是哪些版本经过了最充分的测试。活跃测试版本
列表见 [Kubernetes test grid](https://testgrid.k8s.io/sig-node-containerd)。
Kubernetes 只支持 n-3 个次版本，containerd 会确保每个受支持的 Kubernetes 版本
始终有一个受支持的 containerd 版本可用。

| Kubernetes 版本    | containerd 版本                  | CRI 版本        |
|--------------------|----------------------------------|-----------------|
| 1.32               | 2.1.0+, 2.0.1+, 1.7.24+, 1.6.36+ | v1              |
| 1.33               | 2.1.0+, 2.0.4+, 1.7.24+, 1.6.36+ | v1              |
| 1.34               | 2.1.3+, 2.0.6+, 1.7.28+, 1.6.39+ | v1              |
| 1.35               | 2.2.0+, 2.1.5+, 1.7.28+          | v1              |
| 1.36               | 2.3.0+, 2.2.0+                   | v1              |

已弃用的 containerd 与 kubernetes 版本

| Containerd 版本          | Kubernetes 版本    | CRI 版本                             |
|--------------------------|--------------------|--------------------------------------|
| v1.0 (w/ cri-containerd) | 1.7, 1.8, 1.9      | v1alpha1                             |
| v1.1                     | 1.10+              | v1alpha2                             |
| v1.2                     | 1.10+              | v1alpha2                             |
| v1.3                     | 1.12+              | v1alpha2                             |
| v1.4                     | 1.19+              | v1alpha2                             |
| v1.5                     | 1.20+              | v1 (1.23+), v1alpha2 (until 1.25) ** |
| v1.6.15+, v1.7.0+        | 1.26+              | v1                                   |

** 注意：containerd v1.6.* 和 v1.7.* 在整个生命周期内都支持 CRI v1 和 v1alpha2，因为这些发布版本会继续支持较老的 k8s 版本、云厂商以及其他使用 CRI v1alpha2 的客户端。CRI v1alpha2 在 v1.7 中已弃用，在 containerd v2.0 中不再存在。

### 平台支持 {#platform-support}

containerd 可以运行在多种操作系统和 CPU 架构上，但我们能提供的支持级别因平台而
异。支持程度受限于我们能够构建、测试和维护的范围。能够在 CI 中完整测试的平台，
其支持力度会强于只能编译通过的平台。

为了明确这些差异，平台被划分为若干层级（tier）。层级描述了项目对某个平台所做的
承诺。层级是面向未来的，适用于开发中和将来的发布版本。如果项目不再能够承诺某个
层级的支持，平台可能会被[降级或移除](#demotion-and-removal)。

平台由其 `GOOS/GOARCH` 组合标识，可选带有变体（例如 `linux/amd64`、
`windows/amd64` 或 `linux/arm/v7`）。对于 Linux 这类操作系统，我们不指定具体发行版
为受支持对象，不过自动化测试主要覆盖 Ubuntu、Fedora 和 AlmaLinux。

#### 层级 {#tiers}

<strong><em>Tier 1：受支持。</em></strong>该平台在每次改动时都会在 CI 中构建、
发布，并由自动化测试（集成测试和/或 CRI 测试）验证。Tier 1 平台上的测试失败通常会
阻塞合并和发布。这些是我们推荐用于生产环境的平台。每次发布都会提供发布产物，并会
产出每夜构建。

<strong><em>Tier 2：已发布，尽力而为。</em></strong>该平台会被构建并发布产物，但
我们不为其运行任何自动化测试。虽然产出二进制文件时预期它们可以正常工作，但项目
无法独立验证其运行时行为。Tier 2 平台特有的缺陷按尽力而为的方式处理，可能依赖
报告者或相关方来诊断、修复和验证。会产出每夜构建。

<strong><em>Tier 3：构建验证。</em></strong>该平台会在 CI 中编译，以确保我们不会
在不知情的情况下破坏它，但不发布任何发布产物，也不进行任何测试。该层级的存在主要
是为了支持 containerd 在那些我们没有资源提供更强支持的平台上被采用。

<strong><em>不受支持。</em></strong>下文未列出的任何平台。containerd 可能仍然可以
在这些平台上构建和运行，但项目不做任何承诺，也不做任何验证。用户可以自行从源码
构建供自己使用。

#### 当前平台 {#current-platforms}

| 平台            | 层级 | 发布产物          | 每夜构建       | CI 功能测试           | 构建/编译检查         |
|-----------------|:----:|:-----------------:|:--------------:|:---------------------:|:---------------------:|
| linux/amd64     |  1   | ✅                | ✅             | ✅                    | ✅                    |
| linux/arm64     |  1   | ✅                | ✅             | ✅                    | ✅                    |
| windows/amd64   |  1   | ✅                | ✅             | ✅                    | ✅                    |
| linux/ppc64le   |  2   | ✅                | ✅             | ❌                    | ✅                    |
| linux/riscv64   |  2   | ✅                | ✅             | ❌                    | ✅                    |
| linux/s390x     |  2   | ✅                | ✅             | ❌                    | ✅                    |
| linux/arm/v7    |  3   | ❌                | ❌             | ❌                    | ✅                    |
| linux/arm/v5    |  3   | ❌                | ❌             | ❌                    | ✅                    |
| linux/loong64   |  3   | ❌                | ❌             | ❌                    | ✅                    |
| darwin/arm64    |  3   | ❌                | ❌             | ❌                    | ✅                    |
| freebsd/amd64   |  3   | ❌                | ❌             | ❌                    | ✅                    |
| freebsd/arm64   |  3   | ❌                | ❌             | ❌                    | ✅                    |
| windows/arm64   |  3   | ❌                | ❌             | ❌                    | ✅                    |

containerd 的构建、测试和发布基础设施主要定义在
[GitHub Actions](./.github/workflows) 中。发布产物及其平台定义在 `release.yml`
中，每夜构建定义在 `nightly.yml` 中，功能测试定义在 `ci.yml` 中，Tier 3 的编译
覆盖定义在 `ci.yml` 的 `binaries` 和 `crossbuild` job 中。如果这些 workflow 发生
变化，本表格也应随之更新。

#### 申请新增平台或变更层级 {#requesting-a-new-platform-or-a-tier-change}

新平台从维护者能够可持续承诺的最低层级进入，大多数从 Tier 3 开始。要提议新增平台
或变更层级，请[提交 issue](https://github.com/containerd/containerd/issues)，
说明该平台、它的 `GOOS/GOARCH`、所申请的支持级别，以及你能为此贡献什么。

达到各层级需要满足的条件：

- <strong>Tier 3（构建验证）：</strong>Go 必须以移植版的形式支持该平台，且该平台
  必须能够构建（至少 `make build` 和 `make binaries`）。由于成本和风险都很低，
  只要不会明显增加构建复杂度或拖慢 CI，维护者通常会接受一个新的构建验证平台。
  这是新架构推荐的切入点。
- <strong>Tier 2（已发布，尽力而为）：</strong>在 Tier 3 的基础上，该平台必须能够
  通过现有的发布工具产出可用的发布产物。是否为某个平台发布产物由维护者自行决定，
  他们会权衡已展现出的需求、发布无法测试的二进制文件的风险，以及持续的维护负担。
  并不要求有承诺分诊平台特有问题的厂商或社区赞助方，但强烈鼓励，这会让晋级更有
  可能。
- <strong>Tier 1（受支持）：</strong>在 Tier 2 的基础上，该平台必须被 CI 中的
  自动化功能测试覆盖，且这些测试足够可靠，可以用来卡住合并。这通常要求该平台有
  托管 runner，或者有赞助方提供并<em>维护</em>合适的 CI 基础设施（例如自托管
  runner 或硬件）。过慢或过于不稳定、无法可靠地卡住改动的测试或基础设施是不够的。

#### 降级与移除 {#demotion-and-removal}

层级反映的是项目能够承担的支持程度，因此平台既可能上升，也可能下降。维护者可能在
以下情况（举例）降级或移除某个平台：

- 该平台的自动化测试变得过于不稳定或过慢，无法卡住改动；
- 某个层级所依赖的基础设施或赞助不再可用；
- 支持该平台明显阻碍了 containerd 的开发；或者
- 该平台不再被实际使用。

在可行的情况下，维护者会在降低某个平台的层级或将其移除之前发出通知，并倾向于在
次版本发布的边界上做这类变更。移除某个平台不会追溯影响已经为此前发布版本发布的
产物。

### Backport {#backporting}

containerd 的 backport 由社区驱动。作为维护者，我们会尽力确保合理的缺陷修复能够
进入 _active_ 状态的发布版本，但我们的主要精力放在下一个 _minor_ 或 _major_
发布版本的特性上。在大多数情况下，这个流程都很直接，我们也会尽力让它尽可能顺畅。
「主要只 backport 缺陷修复」这一总体策略的一个例外是新增的弃用警告。为了确保用户
有充足的时间应对即将到来的破坏性变更，新的弃用警告可以被 backport 到任何受支持的
发布版本，包括 LTS 版本。

如果有重要的修复需要 backport，请通过以下三种方式之一告知我们：

1. 提交一个 issue。
2. 提交一个从 main cherry-pick 改动的 PR。
3. 提交一个移植后的修复 PR。

__如果你要报告安全问题：__

请按照 [containerd/project](https://github.com/containerd/project/blob/main/SECURITY.md#reporting-a-vulnerability)
中的说明操作

请记住，backport 的 PR 必须遵循本文档中的版本管理规范。

任何处于 “active” 状态的发布版本都可以接受 backport。提交 backport PR 相当直接。
具体步骤取决于你是从 main 拉取修复，还是需要为某个特定分支起草新的提交。

要从 main cherry-pick 一个直接的提交，直接使用 cherry-pick 流程即可：

1. 选择你想 backport 到的分支，通常格式为 `release/<major>.<minor>`。下面的命令会
   创建一个可用于提交 PR 的分支：

	```console
	$ git checkout -b my-backport-branch release/<major>.<minor>.
	```

2. 找到你想 backport 的提交。
3. 将它应用到发布分支：

	```console
	$ git cherry-pick -xsS <commit>
	```

   如果需要某个 PR 或一组 PR 的全部工作，请 cherry-pick 各个独立的提交，而不是
   merge commit。以 #8624 为例，应优先选择 82ec62b 而不是 9e834e7。

   （可选）如果 main 分支上还有与被 cherry-pick 的提交相关的其他提交，例如对
   主 PR 的修复，建议也把这些提交 cherry-pick 到同一个 `my-backport-branch`。
4. 推送该分支，并针对<em>发布分支</em>提交 PR：

	```
	$ git push -u stevvooe my-backport-branch
	```

   请把 `stevvooe` 替换成你用来提交 PR 的 fork。提交 PR 时，务必把 `main` 换成你
   要修复的目标发布分支。确保 PR 标题带有 `[<release branch>]` 前缀。例如：

   ```
   [release/1.4] Fix foo in bar
   ```

如果 main 中还没有相应的修复，你应当先在 main 中修复该缺陷，或者通过 issue 请求
维护者或贡献者来做。等那个 PR 完成后，再按上述流程提交 PR。

只有当该缺陷在 main 中不存在、必须针对特定发布分支修复时，才应该提交包含新代码的
PR。

### 升级路径 {#upgrade-path}

支持相邻次版本之间的升级。例如，从 2.0 升级到 2.1 是受支持的，但从 2.0 升级到
2.2 不受支持。补丁版本始终与其所属次版本向后兼容。

除了相邻次版本升级之外，相邻 LTS（长期稳定）版本之间的直接升级也受支持。例如，
从 1.7（LTS）直接升级到 2.3（LTS）会经过测试并受支持，但 1.7（LTS）到
2.6（LTS，暂定）则不受支持。这让倾向于停留在 LTS 版本上的用户有一条清晰且安全的
升级路径。

升级到 _major_ 版本没有兼容性保证。对于 2.0，我们加入了迁移机制，以确保从 1.6 或
1.7 升级到 2.0 比较容易。1.6 和 1.7 的最新发布版本会在使用了与 2.0 不兼容的配置时
给出弃用警告。如果出现弃用警告，可以在升级到 2.0 之前先在 1.6 或 1.7 中安全地迁移
配置。一旦不再出现弃用警告，升级到 2.0 应该会很顺利。请始终查看 release note，
破坏性变更都列在那里，并在升级前测试你的配置。

特性只能在紧随某个 LTS 发布之后的发布版本中移除。升级之前，尤其是跨多个次版本或
升级到新的 LTS 发布时，用户应确保已经处理完当前版本的所有弃用警告。这样做能让
过渡更平滑，并避免遇到特性被移除的问题。

## 公共 API 稳定性 {#public-api-stability}

下表概述了 containerd 版本所涵盖的各个组件：


| 组件             | 状态     | 稳定化版本         | 链接          |
|------------------|----------|--------------------|---------------|
| GRPC API         | 稳定     | 1.0                | [gRPC API](#grpc-api) |
| Metrics API      | 稳定     | 1.0                | - |
| Runtime Shim API | 稳定     | 1.2                | - |
| Daemon Config    | 稳定     | 1.0                | - |
| CRI GRPC API     | 稳定     | 1.6 (_CRI v1_)     | [cri-api](https://github.com/kubernetes/cri-api/tree/master/pkg/apis/runtime/v1) |
| Go client API    | 稳定     | 2.0                | [godoc](https://pkg.go.dev/github.com/containerd/containerd/v2/client) |
| `ctr` 工具       | 不稳定   | 不在范围内         | - |

从上表所述的版本开始，相应组件必须遵守发布版本中所要求的稳定性约束。

除非此处另有明确说明，被标注为不稳定或未被涵盖的组件可能在将来的次版本中发生
变化。对「不稳定」组件的破坏性变更会尽量避免出现在补丁版本中。

Go 客户端 API 的稳定性涵盖 `client`、`defaults` 和 `version` 包，以及 `pkg`、
`core`、`api` 和 `protobuf` 下的所有包。`cmd`、`contrib`、`integration` 和
`internal` 下的所有包都不属于稳定客户端 API 的一部分。

### GRPC API {#grpc}

containerd 的主要产物是 GRPC API。从 1.0.0 发布版本起，GRPC API 不会在没有
_major_ 版本跃迁的情况下发生向后不兼容的变更。

为了保证兼容性，我们把整个 GRPC API 的符号集收集到了单个文件中。在 containerd 的
每个 _minor_ 发布中，我们会把当前的 `next.pb.txt` 文件移动到以该次版本命名的
文件中，例如 `1.0.pb.txt`，列举其中支持的服务和消息。

注意，新服务可能在 _minor_ 发布中被加入。新的服务方法和消息上的新字段如果是可选
的，也可能被加入。

`*.pb.txt` 文件在每次 API 发布时生成。它们通过提供可供 CI 运行 diff 的对象来防止
对 API 的意外改动。这些文件并不打算被客户端使用或消费。

从 containerd 2.0 起，API 版本与 containerd 主版本不再一致。虽然 containerd 2.0
对 containerd 而言是一次 _major_ 版本跃迁，但 API 会保持在 1.x，以便与此前的
发布版本和现有客户端保持向后兼容。2.0 发布把 API 放到了一个独立的 Go module 中，
它仍然可以作为 `github.com/containerd/containerd/api` 这个 Go 包存在，并与
containerd 的其余部分分开导入。

API 的次版本号会继续在 containerd 的每个主版本和次版本发布时递增。不过，API 是
直接从 main 分支打 tag 的，次版本号在下一个发布周期的较早阶段递增，而不是在周期
结束时递增。这意味着在 containerd 2.0 发布之后，下一次 API 变更会在任何
containerd 2.1 发布之前被打上 `api/v1.9.0` 的 tag。最新的 API 版本应当被 backport
到所有受支持的版本，并且应尽可能避免为此前的 API 版本发布补丁版本。


| Containerd 版本    | 发布时的 API 版本      |
|--------------------|------------------------|
| v1.0               | 1.0                    |
| v1.1               | 1.1                    |
| v1.2               | 1.2                    |
| v1.3               | 1.3                    |
| v1.4               | 1.4                    |
| v1.5               | 1.5                    |
| v1.6               | 1.6                    |
| v1.7               | 1.7                    |
| v2.0               | 1.8                    |
| v2.1               | 1.9                    |
| v2.2               | 1.10                   |
| v2.3               | 1.11                   |
| _v2.4_             | _1.12_                 |


### Metrics API {#metrics-api}

输出 prometheus 风格指标的 metrics API 独立进行版本管理，以 API 版本作为前缀，
例如 `/v1/metrics`、`/v2/metrics`。

当 prometheus 输出发生破坏性变更时，metrics API 版本会递增。新指标可以以向后兼容
的方式加入输出，而无需提升 API 版本。

### Plugins API {#plugins-api}

containerd 基于模块化设计，核心功能由各个 plugin 实现。除非明确声明为非稳定，
in-tree 实现的 plugin 由 containerd 社区提供支持。out-of-tree 的 plugin 不受
containerd 维护者支持。

目前，Windows 的 runtime 和 snapshot plugin 尚不稳定，也不受支持。关于将来发布版本
中的 Windows 支持，请参考 GitHub 里程碑。

#### 错误码 {#error-codes}

错误码不会在补丁版本中改变，除非缺少某个错误码导致了阻塞性缺陷。类型为 “unknown”
的错误码将来可能变为更具体的类型。任何当前由某个服务返回的非 “unknown” 错误码，
都不会在没有 _major_ 发布或新版本服务的情况下改变。

如果你发现你的应用所需要的某个错误码在 protobuf 服务描述中没有充分文档化，也没有
被显式测试，请提交 issue，我们会予以澄清。

#### 不透明字段 {#opaque-fields}

除非另有明确说明，某些字段的格式可能不在本保证的涵盖范围内，应当以不透明的方式
对待。例如，不要依赖某个 URL 字段的格式细节，除非我们明确说明该字段会遵循那种
格式。

### Go 客户端 API {#go-client-api}

从 containerd 2.0 起，[godoc](https://godoc.org/github.com/containerd/containerd/v2/client)
中记录的 Go 客户端 API 是稳定的。注意，由于 Go 客户端与 GRPC API 交互，基于 Go
客户端构建的客户端应当与将来实现同一 GRPC API 主版本系列的服务端发布版本保持
兼容。为了向后兼容，作为一般经验法则，处理 containerd daemon 返回的
「未实现」错误是客户端的责任。

对 Go 客户端 API 的任何改动都应当在编译期可被发现，因此升级只需修复编译错误并
在此基础上继续即可。

### CRI GRPC API {#cri-grpc-api}

CRI（Container Runtime Interface）GRPC API 由 Kubernetes kubelet 用来与容器运行时
通信。该接口用于管理容器生命周期和容器 image。目前该 API 仍在开发中，在不同
Kubernetes 发布版本之间并不稳定。每个 Kubernetes 发布版本只支持一个 CRI 版本，
CRI plugin 也只实现一个 CRI 版本。

每个 _minor_ 发布会支持一个 CRI 版本和至少一个 Kubernetes 版本。一旦该 API 稳定，
某个 _minor_ 版本将与任何支持该 CRI 版本的 Kubernetes 版本兼容。

### `ctr` 工具 {#ctr-tool}

`ctr` 工具提供了内省和理解 containerd API 的能力。它不被视为本项目的主要交付物，
在这个意义上不受支持。虽然我们理解它作为调试工具的价值，但它可能在 _minor_
发布中被彻底重构或发生破坏性变更。

把 `ctr` 作为增加特性的目标，反映出对 containerd 架构的误解。特性增加应当聚焦于
客户端 Go API，对 `ctr` 的增补是否被接受由维护者自行决定。

我们会尽最大努力不在 _patch_ 发布中破坏该工具的兼容性。

### Daemon 配置 {#daemon-configuration}

daemon 的配置文件通常位于 `/etc/containerd/config.toml`，它带有版本且向后兼容。
配置文件中的 `version` 字段指定配置的版本。如果配置文件中没有指定版本号，则假定
它是版本 `1` 的配置并按此解析。最新版本是 `version = 4`。配置会在每次启动时自动
迁移到最新版本，而配置文件本身保持不变。为了避免迁移并优化 daemon 启动时间，可以
使用 `containerd config migrate` 输出最新版本的配置。所有此前的版本都通过迁移得到
支持。

把配置迁移到最新版本会限制该配置可用于哪些此前的 containerd 版本。建议在你确信
不需要快速回滚 containerd 版本之前，先不要迁移配置文件。可以使用配置版本与
containerd 发布版本的对照表，了解每个配置版本所需的最低 containerd 版本。

| 配置版本              | 最低 containerd 版本       |
|-----------------------|----------------------------|
| 1                     | v1.0.0                     |
| 2                     | v1.3.0                     |
| 3                     | v2.0.0                     |
| 4                     | v2.3.0                     |

### 未涵盖的内容 {#not-covered}

作为一般规则，本文档未提及的任何内容都不受稳定性准则涵盖，可能在任何发布版本中
发生变化。明确来说，这适用于以下这份并不详尽的组件清单：

- 文件系统布局
- 存储格式
- Snapshot 格式

在相邻 _minor_ 版本升级之间，我们可能会迁移这些格式。任何依赖这些文件系统布局
细节的外部进程都可能在此过程中失效。容器的 root 文件系统会在升级过程中得到保留。

### 例外 {#exceptions}

出于<strong>安全补丁</strong>的考虑，我们可能会做出例外。如果必须引入破坏性变更，
我们会清楚地进行沟通，并结合总体影响来权衡解决方案。

## 已弃用的特性 {#deprecated-features}

已弃用的特性如下表所示：

| 组件                                                                             | 弃用版本            | 计划移除版本                          | 建议                                     |
|----------------------------------------------------------------------------------|---------------------|---------------------------------------|------------------------------------------------------------------------------------------------|
| Runtime V1 API 及其实现（`io.containerd.runtime.v1.linux`）                      | containerd v1.4     | containerd v2.0 ✅                    | 使用 `io.containerd.runc.v2`                                                                    |
| Runtime V2 的 Runc V1 实现（`io.containerd.runc.v1`）                            | containerd v1.4     | containerd v2.0 ✅                    | 使用 `io.containerd.runc.v2`                                                                    |
| 内置的 `aufs` snapshotter                                                        | containerd v1.5     | containerd v2.0 ✅                    | 使用 `overlayfs` snapshotter                                                                    |
| 容器标签 `containerd.io/restart.logpath`                                         | containerd v1.5     | containerd v2.0 ✅                    | 使用 `containerd.io/restart.loguri` 标签                                                       |
| `cri-containerd-*.tar.gz` 发布包                                                 | containerd v1.6     | containerd v2.0 ✅                    | 使用 `containerd-*.tar.gz` 包                                                              |
| 拉取 Schema 1 image（`application/vnd.docker.distribution.manifest.v1+prettyjws`） | containerd v1.7     | containerd v2.1（v2.0 中已禁用）✅ | 使用 Schema 2 或 OCI image                                                                |
| CRI `v1alpha2`                                                                   | containerd v1.7     | containerd v2.0 ✅                    | 使用 CRI `v1`                                                                                   |
| 旧版 CRI 的 podsandbox 支持实现                                                  | containerd v2.0     | containerd v2.0 ✅                    |                                                                                                |
| 作为 containerd runtime plugin 的 Go-Plugin 库（`*.so`）                         | containerd v2.0     | containerd v2.1 ✅                    | 使用外部 plugin（proxy 或 binary）                                                         |
| NRI v0.1.0 plugin 支持                                                           | containerd v2.2     | containerd v2.3                       | 使用 v010-adapter NRI plugin，或将 v0.1.0 plugin 更新为使用当前的 NRI API           |
| cgroup v1 支持                                                                   | containerd v2.2     | (May 2029)                            | 使用 cgroup v2                                                                                  |
| 在 CRI `CreateContainer` 期间恢复 checkpoint 数据                                | containerd v2.3     | containerd v2.4 ✅                    | 关注 [KEP-5823](https://github.com/kubernetes/enhancements/issues/5823) 以了解替代的 `RestorePod` API |

- 拉取 Schema 1 image 在 containerd v2.0 中已被禁用，但在 containerd v2.1 之前仍可通过设置环境变量 `CONTAINERD_ENABLE_DEPRECATED_PULL_SCHEMA_1_IMAGE=1` 启用。
  `ctr` 用户还需要指定 `--local`（例如 `ctr images pull --local`）。CRI 客户端（例如 Kubernetes 和 `crictl`）的用户需要在 containerd daemon 上设置该环境变量（通常在 systemd unit 中）。
- 2029 年 5 月的最新发布版本不一定支持 cgroup v1，但至少会有一个仍在维护的分支支持 cgroup v1。

### 已弃用的配置属性 {#deprecated-config-properties}
[`config.toml`](https://github.com/containerd/containerd/blob/main/docs/cri/config.md) 中已弃用的属性如下表所示：

| 属性组                                                               | 属性                         | 弃用版本            | 计划移除版本               | 建议                                            |
|----------------------------------------------------------------------|------------------------------|---------------------|----------------------------|------------------------------------------------------|
|`[plugins."io.containerd.grpc.v1.cri"]`                               | `systemd_cgroup`             | containerd v1.3     | containerd v2.0 ✅         | 在 runc options 中使用 `SystemdCgroup`（见下文）      |
|`[plugins."io.containerd.grpc.v1.cri".containerd]`                    | `untrusted_workload_runtime` | containerd v1.2     | containerd v2.0 ✅         | 在 `runtimes` 中创建 `untrusted` runtime             |
|`[plugins."io.containerd.grpc.v1.cri".containerd]`                    | `default_runtime`            | containerd v1.3     | containerd v2.0 ✅         | 使用 `default_runtime_name`                           |
|`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.*]`         | `runtime_engine`             | containerd v1.3     | containerd v2.0 ✅         | 使用 runtime v2                                       |
|`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.*]`         | `runtime_root`               | containerd v1.3     | containerd v2.0 ✅         | 使用 `options.Root`                                   |
|`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.*]`         | `disable_cgroup`             | -                   | containerd v2.0 ✅         | 使用 [cgroup v2 委派](https://rootlesscontaine.rs/getting-started/common/cgroup2/) |
|`[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.*.options]` | `CriuPath`                   | containerd v1.7     | containerd v2.0 ✅         | 将 `$PATH` 指向 `criu` 二进制文件                     |
|`[plugins."io.containerd.grpc.v1.cri".registry]`                      | `auths`                      | containerd v1.3     | containerd v2.4            | 使用 [`ImagePullSecrets`](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)。另见 [#8228](https://github.com/containerd/containerd/issues/8228)。 |
|`[plugins."io.containerd.grpc.v1.cri".registry]`                      | `configs`                    | containerd v1.5     | containerd v2.4            | 使用 [`config_path`](https://github.com/containerd/containerd/blob/main/docs/hosts.md)                 |
|`[plugins."io.containerd.grpc.v1.cri".registry]`                      | `mirrors`                    | containerd v1.5     | containerd v2.4            | 使用 [`config_path`](https://github.com/containerd/containerd/blob/main/docs/hosts.md)                 |
|`[plugins."io.containerd.tracing.processor.v1.otlp"]`                 | `endpoint`, `protocol`, `insecure` | containerd v1.6.29 | containerd v2.4       | 使用 [OTLP 环境变量](https://opentelemetry.io/docs/specs/otel/protocol/exporter/)，例如 OTEL_EXPORTER_OTLP_TRACES_ENDPOINT、OTEL_EXPORTER_OTLP_PROTOCOL、OTEL_SDK_DISABLED    |
|`[plugins."io.containerd.cri.v1.runtime".cni]`                        | `bin_dir`                    | containerd v2.1     | containerd v2.4            | 使用 `bin_dirs`，它支持目录列表 |
|`[plugins."io.containerd.internal.v1.tracing"]`                       | `service_name`, `sampling_ratio`   | containerd v1.6.29 | containerd v2.4       | 改用 [OTel 环境变量](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)，例如 OTEL_SERVICE_NAME、OTEL_TRACES_SAMPLER*  |
|`[plugins."io.containerd.cri.v1.runtime"]`                            | `enable_cdi`                 | containerd v2.2     | containerd v2.4            | CDI 支持将始终启用                   |


> **注意**
>
> CNI 配置模板（`plugins."io.containerd.grpc.v1.cri".cni.conf_template`）曾在 v1.7.0 中被弃用，
> 但该弃用在 v1.7.3 中被取消。

<details><summary>示例：runc 选项 <code>SystemdCgroup</code></summary><p>

```toml
version = 2

# OLD
# [plugins."io.containerd.grpc.v1.cri"]
#   systemd_cgroup = true

# NEW
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

</p></details>

<details><summary>示例：runc 选项 <code>Root</code></summary><p>

```toml
version = 2

# OLD
# [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
#   runtime_root = "/path/to/runc/root"

# NEW
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  Root = "/path/to/runc/root"
```

</p></details>

## 实验性特性 {#experimental-features}

实验性特性是加入 containerd 的新特性，它们不具备与 containerd 其余部分相同的稳定性
保证。我们会努力避免在版本之间破坏接口，但实验性特性在完全受支持之前发生变化是有
可能的。用户仍然可以期待实验性特性具有较高质量，并鼓励使用新特性来帮助它们更快
稳定下来。

| 组件                                                                                   | 首次发布版本    | 计划受支持的版本         |
|----------------------------------------------------------------------------------------|-----------------|--------------------------|
| [Sandbox Service](https://github.com/containerd/containerd/pull/6703)                  | containerd v1.7 | containerd v2.0          |
| [Sandbox CRI Server](https://github.com/containerd/containerd/pull/7228)               | containerd v1.7 | containerd v2.0          |
| [Transfer Service](https://github.com/containerd/containerd/pull/7320)                 | containerd v1.7 | containerd v2.0          |
| [NRI in CRI Support](https://github.com/containerd/containerd/pull/6019)               | containerd v1.7 | containerd v2.0          |
| [gRPC Shim](https://github.com/containerd/containerd/pull/8052)                        | containerd v1.7 | containerd v2.0          |
| [CRI Runtime Specific Snapshotter](https://github.com/containerd/containerd/pull/6899) | containerd v1.7 | containerd v2.0          |
| [CRI Support for User Namespaces](https://github.com/containerd/containerd/blob/main/docs/user-namespaces/README.md)                    | containerd v1.7 | containerd v2.0          |
