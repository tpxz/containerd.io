# CRI 插件架构 {#architecture-of-the-cri-plugin}
本文档描述 `containerd` 的 `cri` 插件架构。

该插件是 Kubernetes [container runtime interface (CRI)](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/cri-api/pkg/apis/runtime/v1/api.proto) 的一个实现。containerd 与 [Kubelet](https://kubernetes.io/docs/reference/command-line-tools-reference/kubelet/) 运行在同一节点上。containerd 内部的 `cri` 插件处理来自 kubelet 的所有 CRI 服务请求，并使用 containerd 内部能力来管理容器和容器 image。

`cri` 插件使用 containerd 管理完整的容器生命周期以及全部容器 image。如下图所示，`cri` 还通过 [CNI](https://github.com/containernetworking/cni)（另一个 CNCF 项目）管理 pod 网络。

![architecture](./architecture.png)

下面用一个例子来演示 kubelet 创建单容器 pod 时 `cri` 插件的工作过程：
* kubelet 通过 CRI runtime service API 调用 `cri` 插件来创建 pod；
* `cri` 创建 pod 的网络 namespace，然后使用 CNI 对其进行配置；
* `cri` 使用 containerd 内部能力创建并启动一个特殊的 [pause container](https://www.ianlewis.org/en/almighty-pause-container)（即 sandbox 容器），并把该容器放入 pod 的 cgroup 和 namespace 中（为简洁起见省略了部分步骤）；
* kubelet 随后通过 CRI image service API 调用 `cri` 插件，拉取应用容器的 image；
* 如果该 image 在节点上不存在，`cri` 会进一步使用 containerd 拉取它；
* 接着 kubelet 通过 CRI runtime service API 调用 `cri`，使用拉取到的容器 image 在 pod 内创建并启动应用容器；
* `cri` 最终使用 containerd 内部能力创建该应用容器，将其放入 pod 的 cgroup 和 namespace 中，然后启动这个 pod 的新应用容器。
经过这些步骤，一个 pod 及其对应的应用容器就创建完成并运行起来了。
