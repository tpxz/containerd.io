# 内容流转 {#content-flow}

containerd 的一个主要目标是构建一个可以利用内容来执行容器的系统。
为了实现这一流程，containerd 需要获取内容并对其进行管理。

本文档描述内容如何流入 containerd、如何被管理，以及在流程的每个阶段它存在于何处。我们以一个已知 image
[docker.io/library/redis:5.0.9](https://hub.docker.com/layers/library/redis/5.0.9/images/sha256-9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b) 为例来探究内容的
流转过程。

## 内容所在区域 {#content-areas}

在 containerd 的生命周期中，内容存在于以下几个区域：

* OCI registry，例如 [hub.docker.com](https://hub.docker.com) 或 [quay.io](https://quay.io)
* containerd content store，位于 containerd 的本地存储空间下，例如在标准 Linux 安装中位于 `/var/lib/containerd/io.containerd.content.v1.content`
* snapshot，位于 containerd 的本地存储空间下，例如在标准 Linux 安装中位于 `/var/lib/containerd/io.containerd.snapshotter.v1.<type>`。对于 overlayfs snapshotter，路径为 `/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs`

容器运行需要一个可挂载、且通常可写的文件系统。这个文件系统由 content store 中的内容创建而来。
要创建一个容器，必须完成以下步骤：

1. image 及其全部内容必须被加载到本地 content store 中。这通常通过从 OCI registry 下载完成，但你也可以直接把内容导入进来。这些内容的格式与 registry 中的完全相同。
1. 必须读取 image 中的各个 layer 并应用到一个文件系统上，从而创建出所谓的“committed snapshot”。按顺序对每个 layer 重复此过程。这一过程称为“unpacking”。
1. 必须在 image 最后一个 layer 的内容之上，创建一个最终的可写、可挂载文件系统，即“active snapshot”。

至此就可以创建容器了，其 root 文件系统就是这个 active snapshot。

本文档的其余部分将详细考察每个区域中的内容，以及它们之间的关系。

### Image 格式 {#image-format}

registry 中的 image 通常以下述格式存储。一个“image”由一个称为 descriptor 的 JSON 文档构成。
descriptor 中总是包含一个元素 `mediaType`，用于说明它属于哪种类型。它是以下两种之一：

* “manifest”，其中列出了以容器方式运行该 image 所需的配置文件的哈希，以及构成该 image 文件系统的二进制数据 layer
* “index”，其中列出了各个 manifest 的哈希，每个平台一个；平台是架构（如 amd64 或 arm64）与操作系统（如 linux）的组合

index 的作用是让我们能够挑选出与目标平台匹配的 manifest。

要把诸如 `redis:5.0.9` 这样的 image 引用从 registry 转换为实际的磁盘存储，我们需要：

1. 获取该 image 的 descriptor（JSON 文档）
1. 根据 `mediaType` 判断该 descriptor 是 manifest 还是 index：
   * 如果 descriptor 是 index，则在其中查找代表我们想要运行容器的平台（架构 + os）的条目，用该哈希获取对应的 manifest
   * 如果 descriptor 本身就是 manifest，则继续
1. 对 manifest 中的每个元素——config 以及一个或多个 layer——使用列出的哈希获取这些组件并保存下来

我们用示例 image `redis:5.0.9` 来说明这一过程。

当我们首次解析 `redis:5.0.9` 时，得到如下 JSON 文档：

```json
{
    "manifests": [
        {
            "digest": "sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "amd64",
                "os": "linux"
            },
            "size": 1572
        },
        {
            "digest": "sha256:aeb53f8db8c94d2cd63ca860d635af4307967aa11a2fdead98ae0ab3a329f470",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "arm",
                "os": "linux",
                "variant": "v5"
            },
            "size": 1573
        },
        {
            "digest": "sha256:17dc42e40d4af0a9e84c738313109f3a95e598081beef6c18a05abb57337aa5d",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "arm",
                "os": "linux",
                "variant": "v7"
            },
            "size": 1573
        },
        {
            "digest": "sha256:613f4797d2b6653634291a990f3e32378c7cfe3cdd439567b26ca340b8946013",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "arm64",
                "os": "linux",
                "variant": "v8"
            },
            "size": 1573
        },
        {
            "digest": "sha256:ee0e1f8d8d338c9506b0e487ce6c2c41f931d1e130acd60dc7794c3a246eb59e",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "386",
                "os": "linux"
            },
            "size": 1572
        },
        {
            "digest": "sha256:1072145f8eea186dcedb6b377b9969d121a00e65ae6c20e9cd631483178ea7ed",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "mips64le",
                "os": "linux"
            },
            "size": 1572
        },
        {
            "digest": "sha256:4b7860fcaea5b9bbd6249c10a3dc02a5b9fb339e8aef17a542d6126a6af84d96",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "ppc64le",
                "os": "linux"
            },
            "size": 1573
        },
        {
            "digest": "sha256:d66dfc869b619cd6da5b5ae9d7b1cbab44c134b31d458de07f7d580a84b63f69",
            "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
            "platform": {
                "architecture": "s390x",
                "os": "linux"
            },
            "size": 1573
        }
    ],
    "mediaType": "application/vnd.docker.distribution.manifest.list.v2+json",
    "schemaVersion": 2
}
```

上面的 descriptor 在末尾处显示 `mediaType` 是 “manifest.list”，用 OCI 的术语来说就是 index。
它有一个名为 `manifests` 的数组字段，其中每个元素列出一个平台以及该平台对应 manifest 的哈希。
“platform” 是 “architecture” 与 “os” 的组合。由于我们要运行在常见的
linux/amd64 上，我们在 `manifests` 中查找 `platform` 条目如下的元素：

```json
"platform": {
  "architecture": "amd64",
  "os": "linux"
}
```

它是列表中的第一个，其哈希为 `sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b`。

然后我们获取该哈希对应的条目，即 `docker.io/library/redis@sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b`。
这给出了该 image 在 linux/amd64 上的 manifest：

```json
{
    "schemaVersion": 2,
    "mediaType": "application/vnd.docker.distribution.manifest.v2+json",
    "config": {
        "mediaType": "application/vnd.docker.container.image.v1+json",
        "size": 7648,
        "digest": "sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a"
    },
    "layers": [
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 27092228,
            "digest": "sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90"
        },
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 1732,
            "digest": "sha256:1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94"
        },
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 1417672,
            "digest": "sha256:5999b99cee8f2875d391d64df20b6296b63f23951a7d41749f028375e887cd05"
        },
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 7348264,
            "digest": "sha256:bfee6cb5fdad6b60ec46297f44542ee9d8ac8f01c072313a51cd7822df3b576f"
        },
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 98,
            "digest": "sha256:fd36a1ebc6728807cbb1aa7ef24a1861343c6dc174657721c496613c7b53bd07"
        },
        {
            "mediaType": "application/vnd.docker.image.rootfs.diff.tar.gzip",
            "size": 409,
            "digest": "sha256:97481c7992ebf6f22636f87e4d7b79e962f928cdbe6f2337670fa6c9a9636f04"
        }
    ]
}
```

`mediaType` 告诉我们这是一个 “manifest”，并且它符合正确的格式：

* 一个 `config`，其哈希为 `sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a`
* 一个或多个 `layers`；在本例中共有 6 个 layer

这些元素——index、manifest、config 文件以及每个 layer——都在 registry 中单独存储，
并且各自独立下载。

### Content Store {#content-store}

内容被加载到 containerd 的 content store 时，其存储方式与 registry 非常相似。
每个组件都存储在一个以其哈希命名的文件中。

继续 redis 的例子，如果我们执行 `client.Pull()` 或 `ctr pull`，content store 中会得到
以下内容：

* `sha256:2a9865e55c37293b71df051922022898d8e4ec0f579c9b53a0caee1b170bc81c` - index
* `sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b` - `linux/amd64` 的 manifest
* `sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a` - config
* `sha256:97481c7992ebf6f22636f87e4d7b79e962f928cdbe6f2337670fa6c9a9636f04` - layer 0
* `sha256:5999b99cee8f2875d391d64df20b6296b63f23951a7d41749f028375e887cd05` - layer 1
* `sha256:bfee6cb5fdad6b60ec46297f44542ee9d8ac8f01c072313a51cd7822df3b576f` - layer 2
* `sha256:fd36a1ebc6728807cbb1aa7ef24a1861343c6dc174657721c496613c7b53bd07` - layer 3
* `sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90` - layer 4
* `sha256:1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94` - layer 5

查看我们的 content store，看到的正是这些（为便于阅读，做了过滤和排序）：

```console
$ tree /var/lib/containerd/io.containerd.content.v1.content/blobs
/var/lib/containerd/io.containerd.content.v1.content/blobs
└── sha256
    ├── 2a9865e55c37293b71df051922022898d8e4ec0f579c9b53a0caee1b170bc81c
    ├── 9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b
    ├── 987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a
    ├── 97481c7992ebf6f22636f87e4d7b79e962f928cdbe6f2337670fa6c9a9636f04
    ├── 5999b99cee8f2875d391d64df20b6296b63f23951a7d41749f028375e887cd05
    ├── bfee6cb5fdad6b60ec46297f44542ee9d8ac8f01c072313a51cd7822df3b576f
    ├── fd36a1ebc6728807cbb1aa7ef24a1861343c6dc174657721c496613c7b53bd07
    ├── bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90
    └── 1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94
```

使用 containerd 的接口也能看到同样的内容。同样，我们对结果做了排序以便查看。

```console
$ ctr content ls
DIGEST                                                                  SIZE    AGE             LABELS
sha256:2a9865e55c37293b71df051922022898d8e4ec0f579c9b53a0caee1b170bc81c 1.862kB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/gc.ref.content.m.0=sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b,containerd.io/gc.ref.content.m.1=sha256:aeb53f8db8c94d2cd63ca860d635af4307967aa11a2fdead98ae0ab3a329f470,containerd.io/gc.ref.content.m.2=sha256:17dc42e40d4af0a9e84c738313109f3a95e598081beef6c18a05abb57337aa5d,containerd.io/gc.ref.content.m.3=sha256:613f4797d2b6653634291a990f3e32378c7cfe3cdd439567b26ca340b8946013,containerd.io/gc.ref.content.m.4=sha256:ee0e1f8d8d338c9506b0e487ce6c2c41f931d1e130acd60dc7794c3a246eb59e,containerd.io/gc.ref.content.m.5=sha256:1072145f8eea186dcedb6b377b9969d121a00e65ae6c20e9cd631483178ea7ed,containerd.io/gc.ref.content.m.6=sha256:4b7860fcaea5b9bbd6249c10a3dc02a5b9fb339e8aef17a542d6126a6af84d96,containerd.io/gc.ref.content.m.7=sha256:d66dfc869b619cd6da5b5ae9d7b1cbab44c134b31d458de07f7d580a84b63f69
sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b 1.572kB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/gc.ref.content.config=sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a,containerd.io/gc.ref.content.l.0=sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90,containerd.io/gc.ref.content.l.1=sha256:1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94,containerd.io/gc.ref.content.l.2=sha256:5999b99cee8f2875d391d64df20b6296b63f23951a7d41749f028375e887cd05,containerd.io/gc.ref.content.l.3=sha256:bfee6cb5fdad6b60ec46297f44542ee9d8ac8f01c072313a51cd7822df3b576f,containerd.io/gc.ref.content.l.4=sha256:fd36a1ebc6728807cbb1aa7ef24a1861343c6dc174657721c496613c7b53bd07,containerd.io/gc.ref.content.l.5=sha256:97481c7992ebf6f22636f87e4d7b79e962f928cdbe6f2337670fa6c9a9636f04
sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a 7.648kB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/gc.ref.snapshot.overlayfs=sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd
sha256:97481c7992ebf6f22636f87e4d7b79e962f928cdbe6f2337670fa6c9a9636f04 409B    20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:d442ae63d423b4b1922875c14c3fa4e801c66c689b69bfd853758fde996feffb
sha256:5999b99cee8f2875d391d64df20b6296b63f23951a7d41749f028375e887cd05 1.418MB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:223b15010c47044b6bab9611c7a322e8da7660a8268949e18edde9c6e3ea3700
sha256:bfee6cb5fdad6b60ec46297f44542ee9d8ac8f01c072313a51cd7822df3b576f 7.348MB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:b96fedf8ee00e59bf69cf5bc8ed19e92e66ee8cf83f0174e33127402b650331d
sha256:fd36a1ebc6728807cbb1aa7ef24a1861343c6dc174657721c496613c7b53bd07 98B     20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:aff00695be0cebb8a114f8c5187fd6dd3d806273004797a00ad934ec9cd98212
sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90 27.09MB 19 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c
sha256:1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94 1.732kB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:832f21763c8e6b070314e619ebb9ba62f815580da6d0eaec8a1b080bd01575f7
```

#### 标签 {#labels}

注意每个内容 blob 上都有若干标签。本小节介绍这些标签。
这里并不打算对标签做全面介绍。

#### 通用标签 {#common-labels}
对于从远端拉取的 image，其每个 blob 上都会加上 `containerd.io.distribution.source.<registry>=[<repo/1>,<repo/2>]`
标签，用于标明来源。
```
containerd.io/distribution.source.docker.io=library/redis
```

如果该 blob 被同一 registry 中的不同 repo 共享，则会追加 repo 名称：
```
containerd.io/distribution.source.docker.io=library/redis,myrepo/redis
```

##### Layer 标签 {#layer-labels}

先从 layer 本身说起。它们只有一个标签：`containerd.io/uncompressed`。这些文件是
gzip 压缩的 tar 文件；该标签的值给出它们解压后的哈希。你可以通过下面的方式得到相同的值：

```console
$ cat <file> | gunzip - | sha256sum -
```

例如：

```console
$ cat /var/lib/containerd/io.containerd.content.v1.content/blobs/sha256/1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94 | gunzip - | sha256sum -
832f21763c8e6b070314e619ebb9ba62f815580da6d0eaec8a1b080bd01575f7
```

这与最后一个 layer 完全吻合：

```
sha256:1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94 1.732kB 20 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:832f21763c8e6b070314e619ebb9ba62f815580da6d0eaec8a1b080bd01575f7
```

##### Config 标签 {#config-labels}

我们只有一个 config layer，即 `sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a`。它带有一个以 `containerd.io/gc.ref.` 为前缀的标签，
表明这是一个影响垃圾回收的标签。

在这个例子中，该标签是 `containerd.io/gc.ref.snapshot.overlayfs`，值为 `sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd`。

它用于把这个 config 与一个 snapshot 关联起来。我们稍后讨论 snapshot 时会看到这一点。

##### Manifest 标签 {#manifest-labels}

manifest 上的标签同样以 `containerd.io/gc.ref` 开头，表明它们用于控制
垃圾回收。一个 manifest 有若干“子项”，通常就是 config 和各个 layer。我们希望
确保只要 image（即 manifest）还在，其子项就不会被垃圾回收。
因此，我们用标签引用每个子项：
* `containerd.io/gc.ref.content.config` 引用 config
* `containerd.io/gc.ref.content.l.<index>` 引用各个 layer

在我们的例子中，manifest 是 `sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b`，标签如下。

```
containerd.io/gc.ref.content.config=sha256:df57482065789980ee9445b1dd79ab1b7b3d1dc26b6867d94470af969a64c8e6
containerd.io/gc.ref.content.l.0=sha256:97481c7992ebf6f22636f87e4d7b79e962f928cdbe6f2337670fa6c9a9636f04
containerd.io/gc.ref.content.l.1=sha256:5999b99cee8f2875d391d64df20b6296b63f23951a7d41749f028375e887cd05
containerd.io/gc.ref.content.l.2=sha256:bfee6cb5fdad6b60ec46297f44542ee9d8ac8f01c072313a51cd7822df3b576f
containerd.io/gc.ref.content.l.3=sha256:fd36a1ebc6728807cbb1aa7ef24a1861343c6dc174657721c496613c7b53bd07
containerd.io/gc.ref.content.l.4=sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90
containerd.io/gc.ref.content.l.5=sha256:1ed3521a5dcbd05214eb7f35b952ecf018d5a6610c32ba4e315028c556f45e94
```

这些正是 manifest 的那些子项——config 和各个 layer——它们都存储在我们的 content store 中。

##### Index 标签 {#index-labels}

index 上的标签同样以 `containerd.io/gc.ref` 开头，表明它们用于控制
垃圾回收。如上文所述，一个 index 有若干“子项”，即各个 manifest，每个平台一个。
我们希望确保只要 index 还在，其子项就不会被垃圾回收。
因此，我们用标签引用每个子项，即 `containerd.io/gc.ref.content.m.<index>`。

在我们的例子中，index 是 `sha256:2a9865e55c37293b71df051922022898d8e4ec0f579c9b53a0caee1b170bc81c`，标签如下：

```
containerd.io/gc.ref.content.m.0=sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b
containerd.io/gc.ref.content.m.1=sha256:aeb53f8db8c94d2cd63ca860d635af4307967aa11a2fdead98ae0ab3a329f470
containerd.io/gc.ref.content.m.2=sha256:17dc42e40d4af0a9e84c738313109f3a95e598081beef6c18a05abb57337aa5d
containerd.io/gc.ref.content.m.3=sha256:613f4797d2b6653634291a990f3e32378c7cfe3cdd439567b26ca340b8946013
containerd.io/gc.ref.content.m.4=sha256:ee0e1f8d8d338c9506b0e487ce6c2c41f931d1e130acd60dc7794c3a246eb59e
containerd.io/gc.ref.content.m.5=sha256:1072145f8eea186dcedb6b377b9969d121a00e65ae6c20e9cd631483178ea7ed
containerd.io/gc.ref.content.m.6=sha256:4b7860fcaea5b9bbd6249c10a3dc02a5b9fb339e8aef17a542d6126a6af84d96
containerd.io/gc.ref.content.m.7=sha256:d66dfc869b619cd6da5b5ae9d7b1cbab44c134b31d458de07f7d580a84b63f69
```

注意这个 index 有 8 个子项，但除了我们的平台 `linux/amd64` 之外，其余都是其他平台的，
因此其中只有一个，即 `sha256:9bb13890319dc01e5f8a4d3d0c4c72685654d682d568350fd38a02b1d70aee6b`，实际存在于
我们的 content store 中。这没有影响；只是意味着其他那些也不会被垃圾回收。既然
它们本来就不在，也就不会被删除。

### Snapshot {#snapshots}

content store 中的内容无法被容器直接使用。

首先，它是不可变的，这使得容器难以将其用作容器文件系统。
其次，其格式本身往往也无法直接使用。例如，
大多数容器 layer 采用 tar-gzip 格式，每个 tar-gzip 文件代表一个要叠加到前面各 layer 之上的 layer。
你无法直接 mount 一个 tar-gzip 文件。即便可以，也还需要把每个 layer 的变更叠加到前一个之上。
第三，某些内容 layer 的 media-type（例如标准容器 layer）不仅包含普通的文件新增和修改，
还包含删除操作。这些都无法被容器直接使用，因为容器需要的是普通的文件系统 mount。

为了使用 image 的内容，我们要为这些内容创建 snapshot。

过程如下：

1. snapshotter 基于父级创建一个 snapshot。对于第一个 layer，父级为空。此时它是一个 “active” snapshot。
1. diff applier 了解 layer blob 的内部格式，它把 layer blob 应用到这个 active snapshot 上。
1. diff 应用完成后，snapshotter 提交该 snapshot。此时它成为一个 “committed” snapshot。
1. 这个 committed snapshot 作为下一个 layer 的父级。

containerd 内置了多个 snapshotter，默认是 `overlayfs`。你可以在每次 unpack image 和创建容器时
选择不同的 snapshotter。参见 [snapshotters](./snapshotters/README.md) 和 [PLUGINS](./PLUGINS.md)。

回到我们的例子，每个 layer 都会有一个对应的不可变 snapshot layer。回想一下
我们的例子有 6 个 layer，因此预期会看到 6 个 committed snapshot。输出经过排序以便
查看；它与 content store 以及 manifest 本身中的 layer 相对应。

```console
$ ctr snapshot ls
KEY                                                                     PARENT                                                                  KIND
sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd sha256:bc8b010e53c5f20023bd549d082c74ef8bfc237dc9bbccea2e0552e52bc5fcb1 Committed
sha256:bc8b010e53c5f20023bd549d082c74ef8bfc237dc9bbccea2e0552e52bc5fcb1 sha256:aa4b58e6ece416031ce00869c5bf4b11da800a397e250de47ae398aea2782294 Committed
sha256:aa4b58e6ece416031ce00869c5bf4b11da800a397e250de47ae398aea2782294 sha256:a8f09c4919857128b1466cc26381de0f9d39a94171534f63859a662d50c396ca Committed
sha256:a8f09c4919857128b1466cc26381de0f9d39a94171534f63859a662d50c396ca sha256:2ae5fa95c0fce5ef33fbb87a7e2f49f2a56064566a37a83b97d3f668c10b43d6 Committed
sha256:2ae5fa95c0fce5ef33fbb87a7e2f49f2a56064566a37a83b97d3f668c10b43d6 sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c Committed
sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c                                                                         Committed
```

如果查看 snapshot 目录（该目录因 snapshotter 而异），就能看到这些 snapshot 本身。

```bash
# cd /var/lib/containerd
# ls io.containerd.snapshotter.v1.overlayfs/snapshots/
1  2  3  4  5  6
```

共有 6 个 snapshot，分别对应上面 `ctr snapshot ls` 列出的每一项。这些目录里存放着实际内容：

```bash
# ls io.containerd.snapshotter.v1.overlayfs/snapshots/1/fs
bin  boot  dev  etc  home  lib  lib64  media  mnt  opt  proc  root  run  sbin  srv  sys  tmp  usr  var
# ls io.containerd.snapshotter.v1.overlayfs/snapshots/2/fs
etc  var
```

这些就是第一个和第二个 layer 解包并应用后的内容。

#### 父级 {#parents}

除根之外，每个 snapshot 都有一个父级。它是一棵树，或者说一个层层叠起的蛋糕，从第一个 layer 开始。
这与 layer 逐层构建的方式一致。

#### 名称 {#name}

snapshot 的 key（或称名称）与 content store 中的哈希并不一致。这是因为 content store 中的哈希
是<em>原始</em>内容的哈希，在本例中是 tar-gzip 压缩后的内容。snapshot 把它展开到
文件系统上以便使用。它也不等于未压缩内容的哈希，即去掉 gzip 的 tar 文件的哈希，也就是
`containerd.io/uncompressed` 标签给出的值。

实际上，这个名称是把该 layer 应用到前一个 layer 之上再做哈希的结果。按此逻辑，整棵树的最底层，
也就是第一个 layer，其哈希和名称应当与第一个 layer blob 未压缩后的值相同。
事实确实如此。根 layer 是 `sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90 `，
它解压后的值是 `sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c`，
这正是 snapshot 中的第一个 layer，也是 content store 中该 layer 上的标签值：

```
sha256:bb79b6b2107fea8e8a47133a660b78e3a546998fcf0427be39ac9a0af4a97e90 27.09MB 19 minutes      containerd.io/distribution.source.docker.io=library/redis,containerd.io/uncompressed=sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c
```

#### 最终 layer {#final-layer}

最终的（或者说最顶层的）layer，正是你要在其上创建 active snapshot 以启动容器的位置。
因此我们需要追踪它。这正是打在 config 上的那个标签的作用。在我们的例子中，
config 是 `sha256:987b553c835f01f46eb1859bc32f564119d5833801a27b25a0ca5c6b8b6e111a`，其标签为
`containerd.io/gc.ref.snapshot.overlayfs=sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd`。

查看我们的 snapshot，栈中最终 layer 的值确实就是它：

```
sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd sha256:bc8b010e53c5f20023bd549d082c74ef8bfc237dc9bbccea2e0552e52bc5fcb1 Committed
```

另外注意，content store 中 config 上的这个标签以 `containerd.io/gc.ref` 开头。这是
一个垃圾回收标签。正是这个标签阻止垃圾回收器移除该 snapshot。
由于 config 引用了它，顶层 layer 被“保护”起来不会被垃圾回收。而这个 layer
又依赖下一层，于是下一层也受到保护，如此层层向下直到根 layer（基础 layer）。

### 容器 {#container}

有了上述这些，我们就知道如何创建一个可供容器使用的 active snapshot 了。只需
[Prepare()](https://godoc.org/github.com/containerd/containerd/v2/snapshots#Snapshotter) 该 active snapshot，
向它传入一个 ID 和父级，在这里父级就是 committed snapshot 的顶层。

我们可以通过从同一个 image 创建两个容器来看到这一点。两者都会在顶层 committed snapshot 之上创建
active snapshot。不过，我们预期只会看到 2 个新的 snapshot，都是 active 的。committed snapshot 保持不变，因为它们被复用了。

```console
# ctr container create docker.io/library/redis:5.0.6 redis1
# ctr container create docker.io/library/redis:5.0.6 redis2
ctr snapshot ls
KEY                                                                     PARENT                                                                  KIND
redis1                                                                  sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd Active
redis2                                                                  sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd Active
sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd sha256:bc8b010e53c5f20023bd549d082c74ef8bfc237dc9bbccea2e0552e52bc5fcb1 Committed
sha256:bc8b010e53c5f20023bd549d082c74ef8bfc237dc9bbccea2e0552e52bc5fcb1 sha256:aa4b58e6ece416031ce00869c5bf4b11da800a397e250de47ae398aea2782294 Committed
sha256:aa4b58e6ece416031ce00869c5bf4b11da800a397e250de47ae398aea2782294 sha256:a8f09c4919857128b1466cc26381de0f9d39a94171534f63859a662d50c396ca Committed
sha256:a8f09c4919857128b1466cc26381de0f9d39a94171534f63859a662d50c396ca sha256:2ae5fa95c0fce5ef33fbb87a7e2f49f2a56064566a37a83b97d3f668c10b43d6 Committed
sha256:2ae5fa95c0fce5ef33fbb87a7e2f49f2a56064566a37a83b97d3f668c10b43d6 sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c Committed
sha256:d0fe97fa8b8cefdffcef1d62b65aba51a6c87b6679628a2b50fc6a7a579f764c                                                                         Committed
```

同样的 6 个 committed layer 依然存在，但只新建了 2 个 active snapshot，每个容器一个。两者的父级都是顶层 committed snapshot，
即 `sha256:33bd296ab7f37bdacff0cb4a5eb671bcb3a141887553ec4157b1e64d6641c1cd`。

因此，步骤如下：

1. 把内容放入 content store，可以通过 [Pull()](https://godoc.org/github.com/containerd/containerd/v2/client#Client.Pull)，也可以通过 [content.Store API](https://godoc.org/github.com/containerd/containerd/v2/content#Store) 导入
1. unpack 该 image，为每个 layer 创建 committed snapshot，使用 [image.Unpack()](https://godoc.org/github.com/containerd/containerd/v2/client#Image)。或者，如果你使用 [Pull()](https://godoc.org/github.com/containerd/containerd/v2/client#Client.Pull)，可以通过 [WithPullUnpack()](https://godoc.org/github.com/containerd/containerd/v2/client#WithPullUnpack) 选项让它在拉取时就 unpack。
1. 使用 [Prepare()](https://godoc.org/github.com/containerd/containerd/v2/snapshots#Snapshotter) 创建一个 active snapshot。如果你打算创建容器，可以跳过这一步，因为可以把它作为选项传给下一步。
1. 使用 [NewContainer()](https://godoc.org/github.com/containerd/containerd/v2/client#Client.NewContainer) 创建容器，可选地通过 [WithNewSnapshot()](https://godoc.org/github.com/containerd/containerd/v2/client#WithNewSnapshot) 让它创建 snapshot
