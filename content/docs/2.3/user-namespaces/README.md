# user namespace 支持 {#support-for-user-namespaces}

Kubernetes 从 v1.25 开始支持以 user namespace 运行 pod。本文说明 containerd 对该特性的支持情况。

## 什么是 user namespace？ {#what-are-user-namespaces}

user namespace 将容器内运行的用户与宿主机上的用户隔离开来。

一个在容器内以 root 身份运行的进程，在宿主机上可以是另一个（非 root）用户；换句话说，该进程在 user
namespace 内部的操作拥有完全的权限，但对 namespace 外部的操作则没有特权。

你可以利用这个特性，降低被攻破的容器对宿主机或同一节点上其他 pod 造成的破坏。已有若干评级为 HIGH 或
CRITICAL 的安全漏洞，在启用 user namespace 后无法被利用。预计 user namespace 也能缓解未来的一些漏洞。

关于 user namespace 的概要介绍，参见 [Kubernetes 文档][kube-intro]。

[kube-intro]: https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/#introduction

## 软件栈要求 {#stack-requirements}

Kubernetes 的实现在 1.27 中重新设计过，因此 Kubernetes 1.27 之前和之后的版本要求不同。

请注意，如果你在 containerd 1.6 或更早的版本上使用 user namespace，pod.spec 中的 `hostUsers:
false` 设置会被<strong>静默忽略</strong>。

### Kubernetes 1.25 和 1.26 {#kubernetes-125-and-126}

 * Containerd 1.7
 * OCI 运行时可以用 runc 或 crun：
   * runc 1.1 或更高版本
   * crun 1.4.3 或更高版本

你也可以使用 containerd 2.0 及以上版本，但除 Linux 内核外，同样适用 [Kubernetes 1.27 及更高版本的
要求](#Kubernetes-127-and-greater)。请注意那里的所有要求都适用，包括文件系统需支持 idmap mount。可用的
Linux 版本：

 * Linux 5.15：你会遇到 [containerd 1.7 的存储和延迟限制](#Limitations)，因为它不支持 overlayfs 的
   idmap mount。
 * Linux 5.19 或更高版本（推荐）：不会遇到任何 containerd 1.7 的限制，因为从该内核版本开始 overlayfs
   支持了 idmap mount。

### Kubernetes 1.27 及更高版本 {#kubernetes-127-and-greater}

 * Linux 6.3 或更高版本
 * Containerd 2.0 或更高版本
 * OCI 运行时可以用 runc 或 crun：
   * runc 1.2 或更高版本
   * crun 1.9 或更高版本

此外，pod 中各个卷所使用的所有文件系统都需要内核支持 idmap mount。在 Linux 6.3 中支持 idmap mount 的
一些常见文件系统有：`btrfs`、`ext4`、`xfs`、`fat`、`tmpfs`、`overlayfs`。

kubelet 负责向容器写入一些文件（如 configmap、secret 等）。这些路径所使用的文件系统同样需要支持 idmap
mount。更多相关信息参见 [Kubernetes 文档][kube-req]。


[kube-req]: https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/#before-you-begin

## 创建带 user namespace 的 Kubernetes pod {#creating-a-kubernetes-pod-with-user-namespaces}

首先确认你的 containerd、Linux 和 Kubernetes 版本。如果都满足要求，containerd 上无需任何特殊配置。按
[Kubernetes 网站][kube-example]上的步骤操作即可。

[kube-example]: https://kubernetes.io/docs/tasks/configure-pod-container/user-namespaces/

# 限制 {#limitations}

Kubernetes 的限制可以在[这里][kube-limitations]查看。注意不同 Kubernetes 版本的限制不同，请务必查看你
所使用的 Kubernetes 版本对应的页面。

不同 containerd 版本的限制也不同，本节会重点说明。

[kube-limitations]: https://kubernetes.io/docs/concepts/workloads/pods/user-namespaces/#limitations

### containerd 1.7 {#containerd-17}

containerd 1.7 存在的一个限制是：在 Pod 启动期间，它需要修改容器 image 内每个文件和目录的属主。这意味着
存在存储开销，因为<strong>每创建一个 pod，容器 image 的大小就会翻一倍</strong>，同时也会显著影响容器启动
延迟，因为完成这样一次拷贝同样需要时间。

你可以把 `/sys/module/overlay/parameters/metacopy` 切换为 `Y` 来缓解这个限制。这会显著降低存储和性能
开销，因为只有容器 image 中每个文件的 inode 会被复制，文件内容不会。也就是说占用的存储更少、速度更快。
不过，这并非万能药。

如果你修改了 metacopy 参数，务必确保修改在重启后依然生效。你还应当意识到，该设置会作用于所有容器，而不
只是启用了 user namespace 的容器。它会影响你手动创建的所有 snapshot（如果你有这样做的话）。在这种情况下，
请确保创建和恢复 snapshot 时使用相同的 `/sys/module/overlay/parameters/metacopy` 取值。

### containerd 2.0 及以上版本 {#containerd-20-and-above}

如果你使用 overlay snapshotter（默认即是），containerd 1.7 的存储和延迟限制在 container 2.0 及以上版本
中不再存在。它完全不会占用更多存储，也没有启动延迟。

这是通过对容器 rootfs（即容器 image）使用内核的 idmap mount 特性实现的。它让 overlay 文件系统能够以不同的
UID/GID 暴露 image，既不复制文件也不复制 inode，只用一个 bind-mount。

如果 snapshotter 是 overlayfs 且运行的内核不支持 overlayfs 的 idmap mount，containerd 默认会拒绝创建带
user namespace 的容器。这是为了确保在回退到昂贵的 chown（在存储和 pod 启动延迟方面）之前，你已经理解其中
的影响并主动选择启用。相关说明请阅读上面 containerd 1.7 的限制。

如果你的内核不支持 overlayfs snapshotter 的 idmap mount，你会看到类似这样的错误：

```
failed to create containerd container: snapshotter "overlayfs" doesn't support idmap mounts on this host, configure `slow_chown` to allow a slower and expensive fallback
```

Linux 从 5.19 版本开始支持 overlayfs 上的 idmap mount。

你可以在配置的 overlayfs snapshotter 小节中加入 `slow_chown` 字段来选择启用慢速 chown，像这样：

```
  [plugins."io.containerd.snapshotter.v1.overlayfs"]
    slow_chown = true
```

注意只有 overlayfs 的用户需要主动选择启用慢速 chown，因为它是唯一一个 containerd 提供了更优方案的
snapshotter（containerd 中只有 overlayfs snapshotter 支持 idmap mount）。如果你使用其他 snapshotter，
会直接回退到昂贵的 chown，无需主动选择启用。

话虽如此，你可以自行确认容器是否对容器 image 使用了 idmap mount：创建一个带 user namespace 的 pod，
exec 进去并运行：

```
mount | grep overlay
```

你应该能在 `lowerdir` 参数中看到 idmap mount 的痕迹，本例中可以看到其中出现了 `idmapped`：

```
overlay on / type overlay (rw,relatime,lowerdir=/tmp/ovl-idmapped823885363/0,upperdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/1018/fs,workdir=/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs/snapshots/1018/work)
```

## 用 `ctr` 创建带 user namespace 的容器 {#creating-a-container-with-user-namespaces-with-ctr}

你也可以用 `ctr` 创建带 user namespace 的容器。这种方式更底层，请注意。

创建一个用于操作的目录：

```sh
mkdir -p /tmp/userns-test
cd /tmp/userns-test
```

请注意，rootfs 路径上的所有组成部分（如 `/tmp` 和 `/tmp/rootfs`）都需要 +x 权限。因此建议在 `/tmp`
内部操作，它的权限是合适的。

创建一个 OCI bundle：
```sh
# create the rootfs directory
mkdir rootfs

# export busybox via Docker into the rootfs directory
docker export $(docker create busybox) | tar -C rootfs -xvf -

# adjust the permissions
sudo chown -R 65536:65536 rootfs/
```

把[这个 config.json](./config.json) 复制到 `/tmp/userns-test`。请注意 config.json 中的 process.root.path
字段指向的是我们刚刚创建的 rootfs。它<strong>必须是绝对路径</strong>。

然后用下面的命令创建并启动容器：

```
sudo ctr c create --config config.json userns-test
sudo ctr t start userns-test
```

这会在容器内打开一个 shell。你可以运行下面的命令，验证自己确实处于 user namespace 内：

```
root@runc:/# cat /proc/self/uid_map
         0      65536      65536
```

输出应当完全一致。
