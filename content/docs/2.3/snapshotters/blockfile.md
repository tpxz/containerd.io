# Blockfile Snapshotter {#blockfile-snapshotter}

blockfile snapshotter 为每个 snapshot 使用一个裸块文件。块文件从父块文件或空的基础块文件复制而来。
挂载时需要虚拟机或对 loopback mount 的支持。

## 使用场景 {#use-case}

snapshotter 的作用是从 OCI image 存储中提取 image，并创建一个可供容器使用的 snapshot。它负责搭建底层
基础设施，例如准备目录或做其他文件系统层面的设置、应用各个 layer 以创建单个可挂载的目录作为容器的基础，
以及在启动时挂载到容器中。

最常用的 snapshotter 是 overlayfs snapshotter，它也是 containerd 的默认选项。overlayfs snapshotter 在
宿主机文件系统上提供一个目录，随后以 bind-mount 方式挂载进容器。

blockfile snapshotter 面向的场景是容器运行在 VM 内部。具体来说，OCI image 仍然是容器的文件系统，与普通
容器一样，但容器本身运行在 VM 内。由于 VM 无法从宿主机 bind-mount 目录，blockfile snapshotter 会为
snapshot 创建一个块设备，该块设备可以作为块设备挂接到 VM 上，从而把内容送入 guest。

## 替代方案 {#alternatives}

除 blockfile snapshotter 外，还有其他把目录挂载进 VM 的方案。其中之一是
[virtiofs](https://virtio-fs.gitlab.io) 驱动，前提是你的 VMM 支持它。类似地，你也可以用
[9p](https://www.kernel.org/doc/Documentation/filesystems/9p.txt) 把本地目录挂载进 VM，同样前提是你的
VMM 支持。

此外，[devicemapper snapshotter](./devmapper.md) 可以在 devicemapper thin-pool 中的文件系统 image 上
创建 snapshot。

## 用法 {#usage}

### 检查 blockfile snapshotter 是否可用 {#checking-if-the-blockfile-snapshotter-is-available}

要检查 blockfile snapshotter 是否可用，运行以下命令：

```bash
$ ctr plugins ls | grep blockfile
```

### 配置 {#configuration}

要配置该 snapshotter，可以在 containerd 的 `config.toml` 中使用下列配置项。修改配置后别忘了重启
containerd。

```toml
  [plugins.'io.containerd.snapshotter.v1.blockfile']
    scratch_file = "/opt/containerd/blockfile"
    root_path = "/somewhere/on/disk"
    fs_type = 'ext4'
    mount_options = []
    recreate_scratch = true
```

- `root_path`：存放块文件的目录。该目录必须对 containerd 进程可写。
- `scratch_file`：作为块文件基础的空文件路径。首次使用该 snapshotter 之前，该文件应当已经存在。
- `fs_type`：块文件所使用的文件系统类型。目前支持 `ext4` 和 `xfs`。
- `mount_options`：挂载块文件时使用的额外 mount 选项。
- `recreate_scratch`：若设为 `true`，当 scratch 文件缺失时 snapshotter 会重新创建它。若设为 `false`，scratch 文件缺失时 snapshotter 会失败。

### 创建 scratch 文件 {#creating-the-scratch-file}

可以按如下方式创建 scratch 文件。本例使用一个 500MB 的 scratch 文件。

```bash
$ # make a 500M file
$ dd if=/dev/zero of=/opt/containerd/blockfile bs=1M count=500
500+0 records in
500+0 records out
524288000 bytes (524 MB, 500 MiB) copied, 1.76253 s, 297 MB/s

$ # format the file with ext4
$ sudo mkfs.ext4 /opt/containerd/blockfile
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done
Creating filesystem with 512000 1k blocks and 128016 inodes
Filesystem UUID: d9947ecc-722d-4627-9cf9-fa2a3b622106
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729, 204801, 221185, 401409

Allocating group tables: done
Writing inode tables: done
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done
```

### 运行容器 {#running-a-container}

要使用 blockfile snapshotter 运行容器，需要指定 snapshotter：

```bash
$ # ensure that the image we are using exists; it is a regular OCI image
$ ctr image pull docker.io/library/busybox:latest
$ # run the container with the provides snapshotter
$ ctr run -rm -t --snapshotter blockfile docker.io/library/busybox:latest hello sh
```

通过 go 客户端 API 使用时，与使用其他任何 snapshotter 完全一致：

```go
import (
    "context"
    "github.com/containerd/containerd"
    "github.com/containerd/containerd/snapshots"
)

// create a new client
client, err := containerd.New("/run/containerd/containerd.sock")
snapshotter := "blockfile"
cOpts := []containerd.NewContainerOpts{
				containerd.WithImage(image),
				containerd.WithImageConfigLabels(image),
				containerd.WithAdditionalContainerLabels(labels),
				containerd.WithSnapshotter(snapshotter)
}
container, err := client.NewContainer(ctx, containerID, cOpts...)
```

## 工作原理 {#how-it-works}

blockfile snapshotter 的运作方式与其他 snapshotter 类似。它逐个解包容器 image 中的 layer，每个 layer
的解包都建立在其父 layer 的内容之上。

blockfile snapshotter 的独特之处有两点：

1. 它在磁盘 image 文件内部应用 layer，而不是在宿主机文件系统上。
1. 它为每个 layer 创建一个块 image 文件，并把上一个 layer 叠加其上。

blockfile snapshotter 流程的产物不是一个包含内容的目录，而是单个文件，其中是完整文件系统 image 的内容。
该 image 文件可以做 loopback mount，也可以挂接到虚拟机上。

对每一个 layer，snapshotter 都会创建一个新的块文件，起点是上一个 layer 块文件的副本。如果没有上一个
layer（即第一个 layer），则复制 scratch 文件。

例如，对于一个有 3 个 layer 的 image——记为 A、B、C——流程如下：

1. Layer A：
   1. 把 scratch 文件复制为 layer A 的新块文件。
    1. 对 layer A 的块文件做 loopback mount。
    1. 把 layer A 应用到该挂载点。
    1. 卸载 layer A 的块文件。
1. Layer B：
    1. 把 layer A 的块文件复制为 layer B 的新块文件。
    1. 对 layer B 的块文件做 loopback mount。
    1. 把 layer B 应用到该挂载点。
    1. 卸载 layer B 的块文件。
1. Layer C：
    1. 把 layer B 的块文件复制为 layer C 的新块文件。
    1. 对 layer C 的块文件做 loopback mount。
    1. 把 layer C 应用到该挂载点。
    1. 卸载 layer C 的块文件。

每个 layer 的解包都会把前面各 layer 的内容累积到一个新的块文件中。整个过程结束时，最终的块文件包含完整的
文件系统 image。

作为该流程的结果，系统中每个 layer 都对应一个块文件：

1. layer A 块文件：layer A 的内容
1. layer B 块文件：layer A + layer B 的内容
1. layer C 块文件：layer A + layer B + layer C 的内容

如果底层文件系统和宿主机操作系统支持，该流程会尽可能使用稀疏文件。这意味着块文件只占用实际内容所需的空间。

例如，如果 scratch image 是 500MB，每个 layer 增加 25MB，那么文件大小将是：

1. layer A 块文件：来自 layer A 的 25MB
1. layer B 块文件：来自 layer A 和 B 的 50MB
1. layer C 块文件：来自 layer A、B 和 C 的 75MB

因此总空间占用是 25+50+75=150MB。相比每个 layer 的块文件都占满 500MB（即总共 1500MB），这只是很小的一部分。
