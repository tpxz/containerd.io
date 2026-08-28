---
title: "与 Kubernetes SIG-Node 的协作"
---

containerd 是一个广泛使用的容器运行时，常与
[Kubernetes](https://kubernetes.io) 搭配使用。containerd 实现了 Kubernetes 的
Container Runtime Interface（CRI），并参与 CRI 的设计与实现。

containerd 项目正在采用一套新的流程，以改进在
[KEP](https://github.com/kubernetes/enhancements) 以及 containerd 与 Kubernetes
之间其他集成工作上的协作。

## 作为 Kubernetes SIG-Node 成员、KEP 作者或贡献者，你需要了解什么？ {#what-you-need-to-know-as-a-kubernetes-sig-node-member-kep-author-or-contributor}

### 角色 {#roles}

containerd 项目为推进新的 KEP 实现设立了两个特定角色：

* SIG-Node 成员联络人 —— 由一位 containerd maintainer 担任，负责在 SIG-Node 与
  containerd 项目之间就 KEP 状态、目标 containerd 发布版本以及其他集成工作或痛点
  进行沟通。
* KEP shepherd —— 每个 KEP 至少由一位（最好两位）containerd maintainer 担任，负责
  协助该 KEP 在 containerd 中走完实现与发布流程。

### Issue 管理 {#issue-management}

* 尽早在
  [containerd/containerd 仓库](https://github.com/containerd/containerd)
  中创建 issue 来跟踪具体的 KEP
  * containerd 的 KEP 跟踪 issue 可以由某位 KEP owner、感兴趣的 maintainer，或
    SIG-Node 内负责管理 KEP 流程的小组创建
  * 每个 KEP 在其整个生命周期（Draft、Approved、alpha、beta 和 GA）中使用同一个
    issue 跟踪
  * 新 issue 的标题应同时包含 KEP 编号以及一个简短的标题或对该 KEP 目标的描述
* containerd maintainer 会对新 issue 进行分类，并指派一位 KEP shepherd
* containerd maintainer 会在分类时为该 issue 添加一个标签，对应
  containerd/containerd 仓库中相应的 Kubernetes 发布周期
* containerd maintainer 还会添加一个 milestone，标明该 KEP 目标的 containerd 次要
  版本（通常是我们
  [6 个月发布节奏]({{< ref "releases.md#release-cadence" >}})中的下一个次要版本）
* 使用该 issue 跟踪 KEP 的状态，并进行任何 containerd 相关的讨论

## 更多信息 {#more-information}
你可以在
[containerd 项目仓库](https://github.com/containerd/project/blob/main/SIG-NODE.md)
中找到关于角色与流程的完整说明。
