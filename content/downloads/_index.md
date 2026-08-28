---
title: containerd 下载
---

containerd [发布版本](#releases)可以通过以下任一方式下载：

* 包含全部 containerd 二进制文件（`containerd`、`ctr` 等）的 tarball
* 包含源代码的 zip 文件
* 包含源代码的 tarball

{{< info >}}
关于安装和运行 containerd 的更完整指南，请参阅 [Getting started](https://github.com/containerd/containerd/blob/main/docs/getting-started.md) 指南。
{{< /info >}}

## 安装二进制文件 {#installing-binaries}

要安装 containerd **{{< latest >}}**（最新版本）的二进制文件，请在下方[发布版本](#releases)表格中点击该版本对应的<strong>二进制包（.tar.gz）</strong>按钮。这会把 tarball 的 URL 复制到你的剪贴板。使用 [`wget`](https://www.gnu.org/software/wget/) 下载该 tarball 并解压。

```shell
wget https://github.com/containerd/containerd/releases/download/v{{< latest >}}/containerd-{{< latest >}}-linux-amd64.tar.gz
tar xvf containerd-{{< latest >}}-linux-amd64.tar.gz
```

## 发布版本 {#releases}

下表列出了 containerd 最近的发布版本。

{{< success >}}
点击中间<strong>复制链接</strong>列中的按钮，会把 ZIP 文件或 tarball 的 URL 复制到你的剪贴板。点击右侧<strong>直接下载</strong>列中的按钮，会直接开始下载 ZIP 文件或 tarball。
{{< /success >}}

{{< releases >}}
