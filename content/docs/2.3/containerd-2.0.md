# containerd 2.0 {#containerd-20}

请试用 <https://github.com/containerd/containerd/releases> 提供的发布版本二进制文件，并把任何问题反馈到 <https://github.com/containerd/containerd/issues>。

## 新增内容 {#whats-new}

### Transfer service 现已稳定 {#transfer-service-is-now-stable}

在 [#7592](https://github.com/containerd/containerd/issues/7592) 中提出的 transfer service 现已稳定。transfer service 提供了一个简单的接口，用于在任意源与目标之间传输 artifact 对象。它受 libchan 项目提出的核心理念启发，把二进制流和数据通道作为一等公民纳入 API，从而在无需频繁更新协议和 API 的前提下提供更健壮的 API。

transfer service 已与 containerd 的 [`client.Transfer`](https://pkg.go.dev/github.com/containerd/containerd/v2@v2.0.0-rc.5/client#Client.Transfer) 以及调试工具 `ctr` 集成，可用于向 containerd 拉取、推送、导入和导出 image。更多细节参见 ["Transfer Service"](./transfer.md) 文档。

### Sandbox service 现已稳定 {#sandbox-service-is-now-stable}

在 [#4131](https://github.com/containerd/containerd/issues/4131) 中提出的 sandbox service 现已稳定。sandbox service 扩展了对 containerd shim 的管理，为 pod、虚拟机这类多容器环境提供了更多灵活性和功能。

### 沙箱化的 CRI 现已默认启用 {#sandboxed-cri-is-now-enabled-by-default}

containerd 的 CRI 插件已从使用旧版 CRI server 转为使用 sandbox controller 实现来支持 podsandbox。如前所述，sandbox service 已被标记为稳定。

### Sandbox 属性现在可变 {#sandbox-attributes-are-now-mutable}

sandbox controller 新增了 `Update` API（`/containerd.services.sandbox.v1.Controller/Update`），用于修改已有 sandbox 的属性，即 sandbox 规格、运行时、扩展和标签。

### NRI 现已默认启用 {#nri-is-now-enabled-by-default}

NRI（Node Resource Interface）是一个框架，用于把领域相关或厂商特定的逻辑插入到兼容 OCI 的容器运行时中。它允许用户修改容器、执行额外操作并改进资源管理。NRI 插件被视为容器运行时的一部分，对 NRI 的访问通过限制对系统级 NRI socket 的访问来控制。更多细节参见 ["NRI"](NRI.md) 文档。

### CDI 现已默认启用 {#cdi-is-now-enabled-by-default}

CDI（Container Device Interface）为设备厂商提供了一种标准机制，用于描述访问 GPU 之类特定资源所需的条件，而不仅仅是一个简单的设备名。
CDI 现在已是 Kubernetes Device Plugin 框架的一部分。
参见 [Kubernetes Enhancement Proposal 4009](https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/4009-add-cdi-devices-to-device-plugin-api)。

### Daemon 配置 version 3 {#daemon-configuration-version-3}

本版本新增了对 containerd daemon 配置 `version = 3` 的支持。daemon 配置在启动时会自动迁移到最新版本。这确保了旧配置在未来的 daemon 上仍然可用；不过仍建议迁移到最新版本，以避免迁移开销并优化 daemon 启动时间。更多细节参见发布文档中的 ["Daemon configuration"](../RELEASES.md#daemon-configuration)。

### Introspection API 新增插件信息 {#plugin-info-has-been-added-to-the-introspection-api}

本版本为 introspection 服务新增了 `PluginInfo` API 定义。（`/containerd.services.introspection.v1.Introspection/PluginInfo`）

例如，新的 `PluginInfo()` 调用可用于查看运行时插件的版本、特性和注解。

```bash
$ ctr plugins inspect-runtime --runtime=io.containerd.runc.v2 --runc-binary=runc
{
    "Name": "io.containerd.runc.v2",
    "Version": {
        "Version": "v2.0.0-rc.X-XX-gXXXXXXXXX.m",
        "Revision": "v2.0.0-rc.X-XX-gXXXXXXXXX.m"
    },
    "Options": {
        "binary_name": "runc"
    },
    "Features": {
        "ociVersionMin": "1.0.0",
        "ociVersionMax": "1.2.0",
        ...,
    },
    "Annotations": null
}
```

### containerd 内置 tracing 插件支持通过 OTEL 环境变量配置 {#otel-environment-variable-configuration-support-for-containerds-built-in-tracing-plugin}

本版本让 containerd 内置的 tracing 插件支持 OpenTelemetry [规范](https://opentelemetry.io/docs/specs/otel/configuration/sdk-environment-variables/)中定义的标准环境变量。

实现说明：必须在 containerd 环境中同时设置 `OTEL_SDK_DISABLED` 以及 `OTEL_EXPORTER_OTLP_ENDPOINT` 或 `OTEL_EXPORTER_OTLP_TRACES_ENDPOINT` 之一，tracing 插件才会启用。如果没有配置 endpoint，containerd 的 tracing OLTP 插件会被禁用。

### 支持 Intel ISA-L 的 igzip {#intel-isa-ls-igzip-support}

containerd 客户端新增了对 Intel ISA-L igzip 的支持。若能找到 igzip，containerd 客户端就会用它做 gzip 解压，例如在拉取容器 image 时。基准测试表明 igzip 的性能优于 Go 内置的 gzip 和外部的 pigz 实现。

### Image 校验插件 {#image-verifier-plugins}

transfer service 现在支持用于校验 image 是否允许被拉取的插件。这类插件可以实现策略控制，比如强制要求容器 image 必须已签名，或者 image 必须具有特定名称。插件是独立的程序，通过命令行参数和标准 I/O 通信。更多细节参见 [image 校验插件文档](image-verification.md)。

### CRI 支持 user namespace {#cri-support-for-user-namespaces}

CRI 插件现在支持以 [user namespace](https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/) 运行 pod，从而把 pod 中的用户 ID 映射为宿主机上不同的用户 ID。
这实现了对容器内 root 用户的隔离，比单靠 seccomp 和 capabilities 更进一步地限制了在宿主机上可用的权限。

该特性需要 [runc](https://github.com/opencontainers/runc) v1.2.0 或更高版本。

### CRI 支持递归只读 mount {#cri-support-for-recursive-read-only-mounts}

CRI 插件现在支持[递归只读 mount](https://kubernetes.io/docs/concepts/storage/volumes/#read-only-mounts)，以防止意外出现可写的子挂载。

### CRI 默认启用非特权端口和 ICMP {#unprivileged-ports-and-icmp-by-default-for-cri}

对于不使用宿主机网络 namespace 或 user namespace 的容器，CRI 插件现在默认启用 `net.ipv4.ip_unprivileged-port-start=0` 和 `net.ipv4.ping_group_range=0 2147483647`。这使得容器无需 `CAP_NET_BIND_SERVICE` 即可绑定 1024 以下的端口，无需 `CAP_NET_RAW` 即可运行 `ping`。这一默认行为变更可以通过在 CRI 插件配置中把 `enable_unprivileged_ports` 和 `enable_unprivileged_icmp` 选项设为 `false` 来还原。

### 弃用警告现在可通过 Introspection API 发现 {#deprecation-warnings-can-now-be-discovered-via-the-introspection-api}

弃用警告已被加入 introspection 服务的 `ServerResponse`（`/containerd.services.introspection.v1.Introspection/Server`），并通过 `ctr deprecation list` 加入到 `ctr` 工具中。

为了让迁移到 containerd 2.0 更平滑，社区已把该特性 backport 到 containerd 1.6 和 1.7 发布分支，为用户提供又一个工具来识别升级 containerd 版本时的阻碍点。

工作负载运行在 containerd >= 1.6.27、>= 1.7.12 版本上的管理员，可以查询自己的 containerd server，获取那些已标记为弃用且处于关键路径上的特性的警告。使用 `ctr` 客户端时，用户可以运行 `ctr deprecations list`（还可以加上 `--format json` 以输出机器可读的格式）。

## 破坏性变更 {#whats-breaking}

### Docker Schema 1 image 支持默认禁用 {#docker-schema-1-image-support-is-disabled-by-default}

拉取 Docker Schema 1（`application/vnd.docker.distribution.manifest.v1+prettyjws`）image 默认已禁用。用户应使用最新的 Docker 或 nerdctl+Buildkit 工具链重新构建并推送，以迁移自己的容器 image。可以通过为 `containerd`（针对 Kubernetes、`crictl` 这类 CRI 客户端）和 `ctr`（`ctr` 用户还必须指定 `--local`）设置环境变量 `CONTAINERD_ENABLE_DEPRECATED_PULL_SCHEMA_1_IMAGE=1` 来重新启用之前的行为；不过**强烈建议**用户迁移到 Docker Schema 2 或 OCI image。对 Docker Schema 1 image 的支持将在未来某个版本中被彻底移除。

从 containerd 1.7.8 和 1.6.25 起，schema 1 image 在拉取时会被打上 `io.containerd.image/converted-docker-schema1` 标签。要查找从 schema 1 转换而来的 image，可以使用类似这样的命令：`ctr namespaces list --quiet | xargs -I{} -- ctr --namespace={} image list 'labels."io.containerd.image/converted-docker-schema1"'`。

### `io_uring_*` 系统调用默认被禁止 {#io_uring_-syscalls-are-disallowed-by-default}

以下系统调用（`io_uring_enter`、`io_uring_register` 和 `io_uring_setup`）已从默认 Seccomp 配置的允许列表中移除。已报告的大量 Linux 内核漏洞利用都与 `io_uring` 有关，以至于无法再推荐把它放进默认允许列表。

补充资料：

- <https://security.googleblog.com/2023/06/learnings-from-kctf-vrps-42-linux.html>

### `LimitNOFILE` 配置已移除 {#limitnofile-configuration-has-been-removed}

参考 `containerd.service` systemd 服务文件中对 `LimitNOFILE` 的显式配置已被移除。移除这一显式配置的决定源自社区讨论 [#8924](https://github.com/containerd/containerd/pull/8924)。

containerd 的 rlimits 会被容器继承，因此 daemon 的 `LimitNOFILE` 会影响容器内的 `RLIMIT_NOFILE`。建议使用 systemd 默认的 `LimitNOFILE` 配置。

> [!WARNING]
> 在 systemd 版本低于 240 的平台上，管理员应显式配置 `LimitNOFILE=1024:524288`，否则可能回退到内核默认值 `4096`。

### `io.containerd.runtime.v1.linux` 和 `io.containerd.runc.v1` 已移除 {#iocontainerdruntimev1linux-and-iocontainerdruncv1-have-been-removed}

在 containerd v1.4 中被弃用的 Runtime V1（`io.containerd.runtime.v1.linux`）和 Runc V1（`io.containerd.runc.v1`）shim 支持已被移除。用户应迁移到 `io.containerd.runc.v2` containerd shim。

### `containerd.io/restart.logpath` 容器标签已移除 {#containerdiorestartlogpath-container-label-has-been-removed}

在 containerd v1.5 中被弃用的 `containerd.io/restart.logpath` 容器标签支持已被移除。用户应迁移到 `containerd.io/restart.loguri` 容器标签。

### CRI v1alpha2 API 已移除 {#cri-v1alpha2-api-has-been-removed}

在 containerd v1.7 中被弃用的 CRI v1alpha2 API 支持已被移除。用户应迁移到 CRI v1。k8s 用户可以参考 containerd 的 ["Kubernetes support"](../RELEASES.md#kubernetes-support) 矩阵，确认自己的 Kubernetes 版本是否受支持。

### AUFS snapshotter 已移除 {#aufs-snapshotter-has-been-removed}

在 containerd v1.5 中被弃用的内置 `aufs` snapshotter 已被移除。作为替代，建议使用 `overlayfs` snapshotter。更多细节参见 ["Snapshotters"](snapshotters/README.md) 文档。

### `cri-containerd-(cni-)-VERSION-OS-ARCH.tar.gz` 发布包已移除 {#cri-containerd-cni--version-os-archtargz-release-bundles-have-been-removed}

在 containerd v1.7 中被弃用的 `cri-containerd-(cni-)-VERSION-OS-ARCH.tar.gz` 发布包已从
<https://github.com/containerd/containerd/releases> 移除。

请改为分别安装以下组件，可以从二进制文件安装，也可以从源码安装：
* [containerd（`containerd-VERSION-OS-ARCH.tar.gz`）](https://github.com/containerd/containerd/releases)
* [runc](https://github.com/opencontainers/runc/releases)
* [CNI plugins](https://github.com/containernetworking/plugins/releases)

自 containerd 1.1 起，CRI 插件已包含在 containerd 中。

另请参见 ["Getting started"](./getting-started.md) 文档。

## 行为调整 {#whats-changing}

### containerd 客户端已迁移到独立的包 {#containerd-client-has-moved-to-its-own-package}

containerd 客户端 Go 库已迁移到独立的包（[`github.com/containerd/containerd/v2/client`](https://pkg.go.dev/github.com/containerd/containerd/v2/client)）。

参见快速上手指南中的 ["Implementing your own containerd client"](./getting-started.md#implementing-your-own-containerd-client)，其中给出了基于 containerd 客户端进行开发的可运行示例。

### CRI registry 相关属性已弃用 {#cri-registry-properties-are-deprecated}

`[plugins.\"io.containerd.grpc.v1.cri\".registry]` 的以下属性已弃用，并将在未来某个版本中移除。

- CRIRegistryMirrors（`mirrors`）属性。用户应迁移到使用 [`config_path`](./hosts.md)。
- CRIRegistryAuths（`auths`）属性。用户应迁移到使用 [`ImagePullSecrets`](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/)。
- CRIRegistryConfigs（`configs`）属性。用户应迁移到使用 [`config_path`](./hosts.md)。

### 以 Go-plugin 库作为 containerd 运行时插件的支持已弃用 {#support-for-go-plugin-libraries-as-containerd-runtime-plugins-is-deprecated}

以 Go-plugin 库（`*.so`）作为 containerd 运行时插件（有时称为动态插件）的支持已弃用，并将在未来某个版本中移除。

受影响的配置在其 containerd 配置的根层级带有 `plugin_dir`。

建议迁移到使用 proxy 插件或 binary 外部插件。更多细节参见 ["containerd Plugins"](./PLUGINS.md) 文档。

### 使用 events envelope 封装 containerd 事件的支持已弃用 {#support-for-events-envelope-to-package-containerd-events-is-deprecated}

对 [`service.events.Envelope`](https://pkg.go.dev/github.com/containerd/containerd/api@v1.7.19/services/events/v1#Envelope) 和 [`ttrpc.events.Envelope`](https://pkg.go.dev/github.com/containerd/containerd/api@v1.7.19/services/ttrpc/events/v1#Envelope) 的支持已弃用，并将在未来某个版本中移除。建议用户迁移到 [`types.Envelope`](https://pkg.go.dev/github.com/containerd/containerd/api/types#Envelope)。

### CRI 中 CNI 配置模板的配置支持被延长 {#support-for-cri-configuration-of-cni-configuration-templates-is-extended}

此前在 containerd v1.7.0 中被标记为弃用的 CRI 对 CNI 配置模板（`[plugins.\"io.containerd.grpc.v1.cri\".cni.conf_template]`）的配置支持被延长。
