# CRI 插件配置指南 {#cri-plugin-config-guide}
本文档说明 CRI 插件的配置项。
CRI 插件配置是 containerd 配置的一部分（默认路径：
`/etc/containerd/config.toml`）。

关于 containerd 配置的更多信息，参见
[这里](https://github.com/containerd/containerd/blob/main/docs/ops.md)。

注意，`[plugins."io.containerd.grpc.v1.cri"]` 一节是 CRI 专用的，
其他 containerd 客户端（如 `ctr`、`nerdctl` 以及 Docker/Moby）不会识别它。

## 配置版本 {#config-versions}
`/etc/containerd/config.toml` 的内容必须以版本头开始，例如：
```toml
version = 3
```

配置版本 3 是在 containerd v2.0 中引入的。
containerd 1.x 使用的配置版本 2 仍然受支持，并会自动转换为配置版本 3。

更多信息参见 [`../PLUGINS.md`](../PLUGINS.md)。

## 基本配置 {#basic-configuration}
### Cgroup 驱动 {#cgroup-driver}
虽然 containerd 和 Kubernetes 默认使用传统的 `cgroupfs` 驱动来管理 cgroup，
但在基于 systemd 的主机上推荐使用 `systemd` 驱动，以符合 cgroup 的
[“单一写者”规则](https://systemd.io/CGROUP_DELEGATION/)。

要让 containerd 使用 `systemd` 驱动，在 `/etc/containerd/config.toml` 中设置以下选项：
+ 在 containerd 2.x 中
```toml
version = 3
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true
```
+ 在 containerd 1.x 中
```toml
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
```

除 containerd 之外，还必须配置 `KubeletConfiguration` 使用 "systemd" cgroup 驱动。
`KubeletConfiguration` 通常位于 `/var/lib/kubelet/config.yaml`：
```yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
cgroupDriver: "systemd"
```

kubeadm 用户还应参阅 [kubeadm 文档](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/configure-cgroup-driver/)。

> 注意：Kubernetes v1.28 以 alpha 特性的形式支持自动检测 cgroup 驱动。启用
> `KubeletCgroupDriverFromCRI` kubelet 特性门控后，kubelet 会自动从 CRI
> 运行时检测 cgroup 驱动，上面的 `KubeletConfiguration` 配置步骤就不再
> 需要了。
>
> 在确定 cgroup 驱动时，containerd 会从默认的运行时类开始，使用基于 runc
> 的运行时类中的 `SystemdCgroup` 设置。如果没有配置任何基于 runc 的运行时类，
> containerd 会基于 systemd 是否在运行来自动检测。
> 注意，所有基于 runc 的运行时类都应配置相同的 `SystemdCgroup` 设置，
> 以避免出现非预期行为。
>
> kubelet 的自动 cgroup 驱动配置特性在 containerd v2.0 及更高版本中受支持。

### Snapshotter {#snapshotter}

默认的 snapshotter 为 `overlayfs`（类似于 Docker 的 `overlay2` 存储驱动）：
+ 在 containerd 2.x 中
```toml
version = 3
[plugins.'io.containerd.cri.v1.images']
  snapshotter = "overlayfs"
```
+ 在 containerd 1.x 中
```toml
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd]
  snapshotter = "overlayfs"
```

其他受支持的 snapshotter 参见[这里](https://github.com/containerd/containerd/blob/main/docs/snapshotters)。

### 运行时类 {#runtime-classes}

下面的示例将自定义运行时注册到 containerd 中：
+ 在 containerd 2.x 中
```toml
version = 3
[plugins."io.containerd.cri.v1.runtime".containerd]
  default_runtime_name = "crun"
  [plugins."io.containerd.cri.v1.runtime".containerd.runtimes]
    # crun: https://github.com/containers/crun
    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.crun]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.crun.options]
        BinaryName = "/usr/local/bin/crun"
    # gVisor: https://gvisor.dev/
    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.gvisor]
      runtime_type = "io.containerd.runsc.v1"
    # Kata Containers: https://katacontainers.io/
    [plugins."io.containerd.cri.v1.runtime".containerd.runtimes.kata]
      runtime_type = "io.containerd.kata.v2"
```
+ 在 containerd 1.x 中
```toml
version = 2
[plugins."io.containerd.grpc.v1.cri".containerd]
  default_runtime_name = "crun"
  [plugins."io.containerd.grpc.v1.cri".containerd.runtimes]
    # crun: https://github.com/containers/crun
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun]
      runtime_type = "io.containerd.runc.v2"
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.crun.options]
        BinaryName = "/usr/local/bin/crun"
    # gVisor: https://gvisor.dev/
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.gvisor]
      runtime_type = "io.containerd.runsc.v1"
    # Kata Containers: https://katacontainers.io/
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
      runtime_type = "io.containerd.kata.v2"
```

此外，还必须以 `cluster-admin` 角色将下列 `RuntimeClass` 资源安装到集群中：

```yaml
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: crun
handler: crun
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: gvisor
handler: gvisor
---
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: kata
handler: kata
```

要为 pod 应用某个运行时类，设置 `.spec.runtimeClassName`：

```yaml
apiVersion: v1
kind: Pod
spec:
  runtimeClassName: crun
```

另参见 [Kubernetes 文档](https://kubernetes.io/docs/concepts/containers/runtime-class/)。


## 镜像拉取配置（containerd v2.1 起） {#image-pull-configuration-since-containerd-v21}

### 用于镜像拉取的 Transfer Service {#transfer-service-for-image-pull}

从 containerd v2.1 开始，CRI 插件默认使用 containerd 的 Transfer Service 拉取镜像，而不再使用基于客户端的拉取方式。

要配置 Transfer Service，在 config.toml 中使用以下设置：

```toml
[plugins.'io.containerd.transfer.v1.local']
  # Transfer service specific configurations
  max_concurrent_downloads = 3
  unpack_config = { ... }
```

### 本地拉取模式 {#local-pull-mode}

如果更倾向于使用基于客户端的拉取方式而非 Transfer Service，可以在 CRI 镜像配置中设置 `use_local_image_pull = true`：

```toml
[plugins.'io.containerd.cri.v1.images']
  use_local_image_pull = true
```

### 配置差异以及自动回退到本地模式 {#configuration-differences-and-automatic-fallback-to-local-mode}

Transfer Service 与本地拉取模式在镜像拉取配置的指定方式上存在一些差异：

| CRI 镜像配置选项 | 本地拉取 | Transfer Service 拉取 |
|------------------------|------------|---------------------|
| Snapshotter | ✅ 支持 | ✅ 支持 |
| DisableSnapshotAnnotations | ✅ 支持 | ⚠️ 必须在 snapshotter 插件中配置：<br>`[proxy_plugins.stargz.exports]`<br>`enable_remote_snapshot_annotations = "true"` |
| ImagePullProgressTimeout | ✅ 支持 | ✅ 支持 |
| DiscardUnpackedLayers | ✅ 支持 | ❌ 不支持 |
| PinnedImages | ✅ 支持 | ✅ 支持 |
| Registry Settings | ✅ 全部支持 | ⚠️ 仅支持 ConfigPath 和 Headers<br>（Mirrors、Configs、Auths 不支持，且已弃用） |
| ImageDecryption | ❌ 禁用 | ❌ 禁用 |
| MaxConcurrentDownloads | ✅ 使用 CRI 镜像配置 | ⚠️ 必须在 transfer service 插件中配置：`plugins."io.containerd.transfer.v1.local"` |
| ImagePullWithSyncFs | ✅ 支持 | ❌ 不支持 |
| StatsCollectPeriod | ✅ 支持 | ✅ 支持 |

为确保兼容性，***containerd 2.1 会自动检测配置冲突，并在必要时回退到本地镜像拉取模式***。

如果 CRI 镜像配置中存在下列任意一项配置，containerd 会自动设置 `use_local_image_pull = true` 并记录一条警告：

- `DisableSnapshotAnnotations = false`
- `DiscardUnpackedLayers = true`
- 配置了 `Registry.Mirrors`
- 配置了 `Registry.Configs`
- 配置了 `Registry.Auths`
- `MaxConcurrentDownloads != 3`
- `ImagePullWithSyncFs = true`

警告信息会指出是哪个配置选项触发了回退，并给出在使用 Transfer Service 时如何正确配置该选项的指引。

## 完整配置 {#full-configuration}
每个配置项的说明和默认值如下：
+ 在 containerd 2.x 中
<details>

<p>

```toml
# containerd has several configuration versions:
# - Version 3 (Recommended for containerd 2.x): Introduced in containerd 2.0.
#   Several plugin IDs have changed in this version.
# - Version 2 (Recommended for containerd 1.x): Introduced in containerd 1.3.
#   Still supported in containerd v2.x.
#   Plugin IDs are changed to have prefixes like "io.containerd.".
# - Version 1 (Default): Introduced in containerd 1.0. Removed in containerd 2.0.
version = 3

[plugins]
  [plugins.'io.containerd.cri.v1.images']
    snapshotter = 'overlayfs'
    disable_snapshot_annotations = true
    discard_unpacked_layers = false
    max_concurrent_downloads = 3
    image_pull_progress_timeout = '5m0s'
    image_pull_with_sync_fs = false
    stats_collect_period = 10
    use_local_image_pull = false

    [plugins.'io.containerd.cri.v1.images'.pinned_images]
      sandbox = 'registry.k8s.io/pause:3.10.2'

    [plugins.'io.containerd.cri.v1.images'.registry]
      config_path = ''

    [plugins.'io.containerd.cri.v1.images'.image_decryption]
      key_model = 'node'

  [plugins.'io.containerd.cri.v1.runtime']
    enable_selinux = false
    selinux_category_range = 1024
    max_container_log_line_size = 16384
    disable_cgroup = false
    disable_apparmor = false
    restrict_oom_score_adj = false
    disable_proc_mount = false
    unset_seccomp_profile = ''
    tolerate_missing_hugetlb_controller = true
    disable_hugetlb_controller = true
    device_ownership_from_security_context = false
    ignore_image_defined_volumes = false
    netns_mounts_under_state_dir = false
    enable_unprivileged_ports = true
    enable_unprivileged_icmp = true
    enable_cdi = true
    cdi_spec_dirs = ['/etc/cdi', '/var/run/cdi']
    drain_exec_sync_io_timeout = '0s'
    ignore_deprecation_warnings = []
    stats_collect_period = '1s'
    stats_retention_period = '2m'
    enable_criu = true
    enable_experimental_restore_via_create = false

    [plugins.'io.containerd.cri.v1.runtime'.containerd]
      default_runtime_name = 'runc'
      ignore_blockio_not_enabled_errors = false
      ignore_rdt_not_enabled_errors = false

      [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes]
        [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc]
          runtime_type = 'io.containerd.runc.v2'
          runtime_path = ''
          pod_annotations = []
          container_annotations = []
          privileged_without_host_devices = false
          privileged_without_host_devices_all_devices_allowed = false
          cgroup_writable = false
          base_runtime_spec = ''
          cni_conf_dir = ''
          cni_max_conf_num = 0
          snapshotter = ''
          sandboxer = 'podsandbox'
          io_type = ''

          [plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
            BinaryName = ''
            CriuImagePath = ''
            CriuWorkPath = ''
            IoGid = 0
            IoUid = 0
            NoNewKeyring = false
            Root = ''
            ShimCgroup = ''

    [plugins.'io.containerd.cri.v1.runtime'.cni]
      # DEPRECATED, use `bin_dirs` instead (since containerd v2.1).
      bin_dir = ''
      bin_dirs = ['/opt/cni/bin']
      conf_dir = '/etc/cni/net.d'
      max_conf_num = 1
      setup_serially = false
      conf_template = ''
      ip_pref = ''
      use_internal_loopback = false

  [plugins.'io.containerd.grpc.v1.cri']
    disable_tcp_service = true
    stream_server_address = '127.0.0.1'
    stream_server_port = '0'
    stream_idle_timeout = '4h0m0s'
    enable_tls_streaming = false

    [plugins.'io.containerd.grpc.v1.cri'.x509_key_pair_streaming]
      tls_cert_file = ''
      tls_key_file = ''
```

</p>
</details>

+ 在 containerd 1.x 中
<details>

<p>

```toml
# containerd has several configuration versions:
# - Version 3 (Recommended for containerd 2.x): Introduced in containerd 2.0.
#   Several plugin IDs have changed in this version.
# - Version 2 (Recommended for containerd 1.x): Introduced in containerd 1.3.
#   Still supported in containerd v2.x.
#   Plugin IDs are changed to have prefixes like "io.containerd.".
# - Version 1 (Default): Introduced in containerd 1.0. Removed in containerd 2.0.
version = 2

# The 'plugins."io.containerd.grpc.v1.cri"' table contains all of the server options.
[plugins."io.containerd.grpc.v1.cri"]

  # disable_tcp_service disables serving CRI on the TCP server.
  # Note that a TCP server is enabled for containerd if TCPAddress is set in section [grpc].
  disable_tcp_service = true

  # stream_server_address is the ip address streaming server is listening on.
  stream_server_address = "127.0.0.1"

  # stream_server_port is the port streaming server is listening on.
  stream_server_port = "0"

  # stream_idle_timeout is the maximum time a streaming connection can be
  # idle before the connection is automatically closed.
  # The string is in the golang duration format, see:
  #   https://golang.org/pkg/time/#ParseDuration
  stream_idle_timeout = "4h"

  # enable_selinux indicates to enable the selinux support.
  enable_selinux = false

  # selinux_category_range allows the upper bound on the category range to be set.
  # if not specified or set to 0, defaults to 1024 from the selinux package.
  selinux_category_range = 1024

  # sandbox_image is the image used by sandbox container.
  sandbox_image = "registry.k8s.io/pause:3.10.2"

  # stats_collect_period is the period (in seconds) of snapshots stats collection.
  stats_collect_period = 10

  # enable_tls_streaming enables the TLS streaming support.
  # It generates a self-sign certificate unless the following x509_key_pair_streaming are both set.
  enable_tls_streaming = false

  # tolerate_missing_hugetlb_controller if set to false will error out on create/update
  # container requests with huge page limits if the cgroup controller for hugepages is not present.
  # This helps with supporting Kubernetes <=1.18 out of the box. (default is `true`)
  tolerate_missing_hugetlb_controller = true

  # ignore_image_defined_volumes ignores volumes defined by the image. Useful for better resource
  # isolation, security and early detection of issues in the mount configuration when using
  # ReadOnlyRootFilesystem since containers won't silently mount a temporary volume.
  ignore_image_defined_volumes = false

  # netns_mounts_under_state_dir places all mounts for network namespaces under StateDir/netns
  # instead of being placed under the hardcoded directory /var/run/netns. Changing this setting
  # requires that all containers are deleted.
  netns_mounts_under_state_dir = false

  # max_container_log_line_size is the maximum log line size in bytes for a container.
  # Log line longer than the limit will be split into multiple lines. -1 means no
  # limit.
  max_container_log_line_size = 16384

  # disable_cgroup indicates to disable the cgroup support.
  # This is useful when the daemon does not have permission to access cgroup.
  disable_cgroup = false

  # disable_apparmor indicates to disable the apparmor support.
  # This is useful when the daemon does not have permission to access apparmor.
  disable_apparmor = false

  # restrict_oom_score_adj indicates to limit the lower bound of OOMScoreAdj to
  # the containerd's current OOMScoreAdj.
  # This is useful when the containerd does not have permission to decrease OOMScoreAdj.
  restrict_oom_score_adj = false

  # max_concurrent_downloads restricts the number of concurrent downloads for each image.
  max_concurrent_downloads = 3

  # disable_proc_mount disables Kubernetes ProcMount support. This MUST be set to `true`
  # when using containerd with Kubernetes <=1.11.
  disable_proc_mount = false

  # unset_seccomp_profile is the seccomp profile containerd/cri will use if the seccomp
  # profile requested over CRI is unset (or nil) for a pod/container (otherwise if this field is not set the
  # default unset profile will map to `unconfined`)
    # Note: The default unset seccomp profile should not be confused with the seccomp profile
    # used in CRI when the runtime default seccomp profile is requested. In the later case, the
    # default is set by the following code (https://github.com/containerd/containerd/blob/main/contrib/seccomp/seccomp_default.go).
    # To summarize, there are two different seccomp defaults, the unset default used when the CRI request is
    # set to nil or `unconfined`, and the default used when the runtime default seccomp profile is requested.
  unset_seccomp_profile = ""

  # enable_unprivileged_ports configures net.ipv4.ip_unprivileged_port_start=0
  # for all containers which are not using host network
  # and if it is not overwritten by PodSandboxConfig
  # Note that before containerd v2.0, this value defaulted to false.
  #   [k8s discussion](https://github.com/kubernetes/kubernetes/issues/102612)
  enable_unprivileged_ports = true

  # enable_unprivileged_icmp configures net.ipv4.ping_group_range="0 2147483647"
  # for all containers which are not using host network, are not running in user namespace
  # and if it is not overwritten by PodSandboxConfig
  # Note that before containerd v2.0, this value defaulted to false.
  enable_unprivileged_icmp = true

  # enable_cdi enables support of the Container Device Interface (CDI)
  # For more details about CDI and the syntax of CDI Spec files please refer to
  # https://tags.cncf.io/container-device-interface.
  # TODO: Deprecate this option when either Dynamic Resource Allocation(DRA)
  # or CDI support for the Device Plugins are graduated to GA.
  # `Dynamic Resource Allocation` KEP:
  # https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/3063-dynamic-resource-allocation
  # `Add CDI devices to device plugin API` KEP:
  # https://github.com/kubernetes/enhancements/tree/master/keps/sig-node/4009-add-cdi-devices-to-device-plugin-api
  enable_cdi = true

  # cdi_spec_dirs is the list of directories to scan for CDI spec files
  # For more details about CDI configuration please refer to
  # https://tags.cncf.io/container-device-interface#containerd-configuration
  cdi_spec_dirs = ["/etc/cdi", "/var/run/cdi"]

  # drain_exec_sync_io_timeout is the maximum duration to wait for ExecSync API'
  # IO EOF event after exec init process exits. A zero value means there is no
  # timeout.
  #
  # The string is in the golang duration format, see:
  #    https://golang.org/pkg/time/#ParseDuration
  #
  # For example, the value can be '5h', '2h30m', '10s'.
  drain_exec_sync_io_timeout = "0s"

  # enable_criu enables CRIU (Checkpoint/Restore In Userspace) support.
  # When set to false, checkpoint/restore operations will be disabled.
  enable_criu = true

  # enable_experimental_restore_via_create enables experimental restore of
  # container checkpoints via CreateContainer.
  # When set to false, checkpoint restore via CreateContainer will be disabled.
  enable_experimental_restore_via_create = false

  # 'plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming' contains a x509 valid key pair to stream with tls.
  [plugins."io.containerd.grpc.v1.cri".x509_key_pair_streaming]
    # tls_cert_file is the filepath to the certificate paired with the "tls_key_file"
    tls_cert_file = ""

    # tls_key_file is the filepath to the private key paired with the "tls_cert_file"
    tls_key_file = ""

  # 'plugins."io.containerd.grpc.v1.cri".containerd' contains config related to containerd
  [plugins."io.containerd.grpc.v1.cri".containerd]

    # snapshotter is the default snapshotter used by containerd
    # for all runtimes, if not overridden by an experimental runtime's snapshotter config.
    snapshotter = "overlayfs"

    # no_pivot disables pivot-root (linux only), required when running a container in a RamDisk with runc.
    # This only works for runtime type "io.containerd.runtime.v1.linux".
    no_pivot = false

    # disable_snapshot_annotations disables to pass additional annotations (image
    # related information) to snapshotters. These annotations are required by
    # stargz snapshotter (https://github.com/containerd/stargz-snapshotter)
    # changed to default true with https://github.com/containerd/containerd/pull/4665 and subsequent service refreshes.
    disable_snapshot_annotations = true

    # discard_unpacked_layers allows GC to remove layers from the content store after
    # successfully unpacking these layers to the snapshotter.
    discard_unpacked_layers = false

    # default_runtime_name is the default runtime name to use.
    default_runtime_name = "runc"

    # ignore_blockio_not_enabled_errors disables blockio related
    # errors when blockio support has not been enabled. By default,
    # trying to set the blockio class of a container via annotations
    # produces an error if blockio hasn't been enabled.  This config
    # option practically enables a "soft" mode for blockio where these
    # errors are ignored and the container gets no blockio class.
    ignore_blockio_not_enabled_errors = false

    # ignore_rdt_not_enabled_errors disables RDT related errors when RDT
    # support has not been enabled. Intel RDT is a technology for cache and
    # memory bandwidth management. By default, trying to set the RDT class of
    # a container via annotations produces an error if RDT hasn't been enabled.
    # This config option practically enables a "soft" mode for RDT where these
    # errors are ignored and the container gets no RDT class.
    ignore_rdt_not_enabled_errors = false

    # 'plugins."io.containerd.grpc.v1.cri".containerd.default_runtime' is the runtime to use in containerd.
    # DEPRECATED: use `default_runtime_name` and `plugins."io.containerd.grpc.v1.cri".containerd.runtimes` instead.
    [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime]

    # 'plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime' is a runtime to run untrusted workloads on it.
    # DEPRECATED: use `untrusted` runtime in `plugins."io.containerd.grpc.v1.cri".containerd.runtimes` instead.
    [plugins."io.containerd.grpc.v1.cri".containerd.untrusted_workload_runtime]

    # 'plugins."io.containerd.grpc.v1.cri".containerd.runtimes' is a map from CRI RuntimeHandler strings, which specify types
    # of runtime configurations, to the matching configurations.
    # In this example, 'runc' is the RuntimeHandler string to match.
    [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
      # runtime_type is the runtime type to use in containerd.
      # The default value is "io.containerd.runc.v2" since containerd 1.4.
      # The default value was "io.containerd.runc.v1" in containerd 1.3, "io.containerd.runtime.v1.linux" in prior releases.
      runtime_type = "io.containerd.runc.v2"

      # runtime_path is an optional field that can be used to overwrite path to a shim runtime binary.
      # When specified, containerd will ignore runtime name field when resolving shim location.
      # Path must be abs.
      runtime_path = ""

      # pod_annotations is a list of pod annotations passed to both pod
      # sandbox as well as container OCI annotations. Pod_annotations also
      # supports golang path match pattern - https://golang.org/pkg/path/#Match.
      # e.g. ["runc.com.*"], ["*.runc.com"], ["runc.com/*"].
      #
      # For the naming convention of annotation keys, please reference:
      # * Kubernetes: https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set
      # * OCI: https://github.com/opencontainers/image-spec/blob/main/annotations.md
      pod_annotations = []

      # container_annotations is a list of container annotations passed through to the OCI config of the containers.
      # Container annotations in CRI are usually generated by other Kubernetes node components (i.e., not users).
      # Currently, only device plugins populate the annotations.
      container_annotations = []

      # privileged_without_host_devices allows overloading the default behaviour of passing host
      # devices through to privileged containers. This is useful when using a runtime where it does
      # not make sense to pass host devices to the container when privileged. Defaults to false -
      # i.e pass host devices through to privileged containers.
      privileged_without_host_devices = false

      # privileged_without_host_devices_all_devices_allowed allows the allowlisting of all devices when
      # privileged_without_host_devices is enabled.
      # In plain privileged mode all host device nodes are added to the container's spec and all devices
      # are put in the container's device allowlist. This flags is for the modification of the privileged_without_host_devices
      # option so that even when no host devices are implicitly added to the container, all devices allowlisting is still enabled.
      # Requires privileged_without_host_devices to be enabled. Defaults to false.
      privileged_without_host_devices_all_devices_allowed = false

      # cgroup_writable field enables the support for writable cgroups in unprivileged containers with cgroup v2 enabled. When disabled, the cgroup interface (/sys/fs/cgroup) is mounted as read-only, preventing containers from managing their own cgroup hierarchies.
      cgroup_writable = false

      # base_runtime_spec is a file path to a JSON file with the OCI spec that will be used as the base spec that all
      # container's are created from.
      # Use containerd's `ctr oci spec > /etc/containerd/cri-base.json` to output initial spec file.
      # Spec files are loaded at launch, so containerd daemon must be restarted on any changes to refresh default specs.
      # Still running containers and restarted containers will still be using the original spec from which that container was created.
      base_runtime_spec = ""

      # conf_dir is the directory in which the admin places a CNI conf.
      # this allows a different CNI conf for the network stack when a different runtime is being used.
      cni_conf_dir = "/etc/cni/net.d"

      # cni_max_conf_num specifies the maximum number of CNI plugin config files to
      # load from the CNI config directory. By default, only 1 CNI plugin config
      # file will be loaded. If you want to load multiple CNI plugin config files
      # set max_conf_num to the number desired. Setting cni_max_config_num to 0 is
      # interpreted as no limit is desired and will result in all CNI plugin
      # config files being loaded from the CNI config directory.
      cni_max_conf_num = 1

      # snapshotter overrides the global default snapshotter to a runtime specific value.
      # Please be aware that overriding the default snapshotter on a runtime basis is currently an experimental feature.
      # See https://github.com/containerd/containerd/issues/6657 for context.
      snapshotter = ""

      # sandboxer is the sandbox controller for the runtime.
      # The default sandbox controller is the podsandbox controller, which create a "pause" container as a sandbox.
      # We can create our own "shim" sandbox controller by implementing the sandbox api defined in runtime/sandbox/v1/sandbox.proto in our shim, and specifiy the sandboxer to "shim" here.
      # We can also run a grpc or ttrpc server to serve the sandbox controller API defined in services/sandbox/v1/sandbox.proto, and define a ProxyPlugin of "sandbox" type, and specify the name of the ProxyPlugin here.
      sandboxer = ""

      # io_type is the way containerd get stdin/stdout/stderr from container or the execed process.
      # The default value is "fifo", in which containerd will create a set of named pipes and transfer io by them.
      # Currently the value of "streaming" is supported, in this way, sandbox should serve streaming api defined in services/streaming/v1/streaming.proto, and containerd will connect to sandbox's endpoint and create a set of streams to it, as channels to transfer io of container or process.
      io_type = ""

      # 'plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options' is options specific to
      # "io.containerd.runc.v1" and "io.containerd.runc.v2". Its corresponding options type is:
      #   https://github.com/containerd/containerd/blob/v1.3.2/runtime/v2/runc/options/oci.pb.go#L26 .
      [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
        # NoPivotRoot disables pivot root when creating a container.
        NoPivotRoot = false

        # NoNewKeyring disables new keyring for the container.
        NoNewKeyring = false

        # ShimCgroup places the shim in a cgroup.
        ShimCgroup = ""

        # IoUid sets the I/O's pipes uid.
        IoUid = 0

        # IoGid sets the I/O's pipes gid.
        IoGid = 0

        # BinaryName is the binary name of the runc binary.
        BinaryName = ""

        # Root is the runc root directory.
        Root = ""

        # SystemdCgroup enables systemd cgroups.
        SystemdCgroup = false

        # CriuImagePath is the criu image path
        CriuImagePath = ""

        # CriuWorkPath is the criu work path.
        CriuWorkPath = ""

  # 'plugins."io.containerd.grpc.v1.cri".cni' contains config related to cni
  [plugins."io.containerd.grpc.v1.cri".cni]
    # bin_dir is the directory in which the binaries for the plugin is kept.
    bin_dir = "/opt/cni/bin"

    # conf_dir is the directory in which the admin places a CNI conf.
    conf_dir = "/etc/cni/net.d"

    # max_conf_num specifies the maximum number of CNI plugin config files to
    # load from the CNI config directory. By default, only 1 CNI plugin config
    # file will be loaded. If you want to load multiple CNI plugin config files
    # set max_conf_num to the number desired. Setting max_config_num to 0 is
    # interpreted as no limit is desired and will result in all CNI plugin
    # config files being loaded from the CNI config directory.
    max_conf_num = 1

    # conf_template is the file path of golang template used to generate
    # cni config.
    # If this is set, containerd will generate a cni config file from the
    # template. Otherwise, containerd will wait for the system admin or cni
    # daemon to drop the config file into the conf_dir.
    # See the "CNI Config Template" section for more details.
    conf_template = ""
    # ip_pref specifies the strategy to use when selecting the main IP address for a pod.
    # options include:
    # * ipv4, "" - (default) select the first ipv4 address
    # * ipv6 - select the first ipv6 address
    # * cni - use the order returned by the CNI plugins, returning the first IP address from the results
    ip_pref = "ipv4"
    # use_internal_loopback specifies if we use the CNI loopback plugin or internal mechanism to set lo to up
    use_internal_loopback = false

  # 'plugins."io.containerd.grpc.v1.cri".image_decryption' contains config related
  # to handling decryption of encrypted container images.
  [plugins."io.containerd.grpc.v1.cri".image_decryption]
    # key_model defines the name of the key model used for how the cri obtains
    # keys used for decryption of encrypted container images.
    # The [decryption document](https://github.com/containerd/containerd/blob/main/docs/cri/decryption.md)
    # contains additional information about the key models available.
    #
    # Set of available string options: {"", "node"}
    # Omission of this field defaults to the empty string "", which indicates no key model,
    # disabling image decryption.
    #
    # In order to use the decryption feature, additional configurations must be made.
    # The [decryption document](https://github.com/containerd/containerd/blob/main/docs/cri/decryption.md)
    # provides information of how to set up stream processors and the containerd imgcrypt decoder
    # with the appropriate key models.
    #
    # Additional information:
    # * Stream processors: https://github.com/containerd/containerd/blob/main/docs/stream_processors.md
    # * Containerd imgcrypt: https://github.com/containerd/imgcrypt
    key_model = "node"

  # 'plugins."io.containerd.grpc.v1.cri".registry' contains config related to
  # the registry
  [plugins."io.containerd.grpc.v1.cri".registry]
    # config_path specifies a directory to look for the registry hosts configuration.
    #
    # The cri plugin will look for and use config_path/host-namespace/hosts.toml
    #   configs if present OR load certificate files as laid out in the Docker/Moby
    #   specific layout https://docs.docker.com/engine/security/certificates/
    #
    # If config_path is not provided defaults are used.
    #
    # *** registry.configs and registry.mirrors that were a part of containerd 1.4
    # are now DEPRECATED and will only be used if the config_path is not specified.
    # It is an error to specify both config_path and the deprecated configs or mirrors
    config_path = "/etc/containerd/certs.d:/etc/docker/certs.d"
```

</p>
</details>

## Registry 配置 {#registry-configuration}

下面是一个默认 registry hosts 配置的简单示例。在 containerd 的 config.toml 中设置
`config_path = "/etc/containerd/certs.d"`。
在该配置路径下创建目录树，其中包含名为 `docker.io` 的目录，
代表要配置的 host namespace。然后在 `docker.io` 中添加一个 `hosts.toml` 文件
来配置该 host namespace。结果应该像这样：
```
$ tree /etc/containerd/certs.d
/etc/containerd/certs.d
└── docker.io
    └── hosts.toml

$ cat /etc/containerd/certs.d/docker.io/hosts.toml
server = "https://docker.io"

[host."https://registry-1.docker.io"]
  capabilities = ["pull", "resolve"]
```

要指定自定义证书：

```
$ cat /etc/containerd/certs.d/192.168.12.34:5000/hosts.toml
server = "https://192.168.12.34:5000"

[host."https://192.168.12.34:5000"]
  ca = "/path/to/ca.crt"
```

更多信息参见 [`docs/hosts.md`](https://github.com/containerd/containerd/blob/main/docs/hosts.md)。

## 不受信任的工作负载 {#untrusted-workload}

运行不受信任工作负载的推荐方式，是使用 Kubernetes 1.12 引入的
[`RuntimeClass`](https://kubernetes.io/docs/concepts/containers/runtime-class/) API，
选择在 `plugins."io.containerd.grpc.v1.cri".containerd.runtimes` 中配置好的、
用于运行不受信任工作负载的 RuntimeHandler。

不过，如果使用传统的 `io.kubernetes.cri.untrusted-workload` pod 注解
来请求以面向不受信任工作负载的运行时来运行 pod，则必须先定义 RuntimeHandler
`plugins."io.containerd.grpc.v1.cri"cri.containerd.runtimes.untrusted`。
当注解 `io.kubernetes.cri.untrusted-workload` 设置为 `true` 时，将使用 `untrusted`
运行时。示例参见
[使用 Kata Containers 创建不受信任的 pod](https://github.com/kata-containers/kata-containers/blob/main/docs/how-to/containerd-kata.md#kata-containers-as-the-runtime-for-untrusted-workload)。

## CNI 配置模板 {#cni-config-template}

理想情况下，cni 配置应由系统管理员或 calico、weaveworks 之类的 cni daemon 放置。
不过在没有 cni daemonset 来放置 cni 配置的场景下，该功能很有用。

cni 配置模板使用 [golang
template](https://golang.org/pkg/text/template/) 格式。当前支持的值有：
* `.PodCIDR` 是分配给该节点的第一个 CIDR 的字符串。
* `.PodCIDRRanges` 是分配给该节点的所有 CIDR 组成的字符串数组，通常用于
  [双栈](https://github.com/kubernetes/enhancements/tree/master/keps/sig-network/563-dual-stack)支持。
* `.Routes` 是所需全部路由组成的字符串数组，通常用于双栈支持，
  或者单栈但在运行时才决定使用 IPv4 还是 IPv6 的场景。

可以使用 [golang template actions](https://golang.org/pkg/text/template/#hdr-Actions)
来渲染 cni 配置。例如，可以用下面的模板在 CNI 配置中为双栈添加 CIDR 和路由：
```
"ipam": {
  "type": "host-local",
  "ranges": [{{range $i, $range := .PodCIDRRanges}}{{if $i}}, {{end}}[{"subnet": "{{$range}}"}]{{end}}],
  "routes": [{{range $i, $route := .Routes}}{{if $i}}, {{end}}{"dst": "{{$route}}"}{{end}}]
}
```

## 弃用 {#deprecation}
CRI 插件的配置选项遵循
[Kubernetes 关于“面向管理员的 CLI 组件”的弃用策略](https://kubernetes.io/docs/reference/using-api/deprecation-policy/#deprecating-a-flag-or-cli)。

概括来说，当某个配置选项被宣布弃用时：
* 它会继续保持可用 6 个月或 1 个发布版本（以较长者为准）；
* 使用它时会输出一条警告。
