# containerd 对 runc 版本的要求 {#runc-version-requirements-for-containerd}

containerd 构建时带有 OCI 支持，并支持由 [runc 容器运行时](https://github.com/opencontainers/runc)
提供的高级特性。

containerd 的开发版（`-dev`）和预发布版可能依赖 `runc` 中尚未发布的特性，
因而可能需要特定的 runc 构建。CI 中所测试的 runc 版本记录在
[`script/setup/runc-version`](../script/setup/runc-version) 文件中，
它可能指向 runc 仓库中的某个 git commit（用于预发布版）或某个 tag。

对于 containerd 的正式（非预）发布版本，我们会尽量使用 runc 已发布的（打了 tag 的）版本。
建议使用不低于 [`script/setup/runc-version`](../script/setup/runc-version)
中所述 runc 版本的 runc。

如果遇到任何运行时错误，请确认你的 runc 与该文件中给出的 commit 或 tag 保持一致。

如果没有安装正确版本的 `runc`，可以参考
[runc 文档中的 "building" 一节](https://github.com/opencontainers/runc#building)
了解如何从源码构建 `runc`。

runc 的构建默认启用了 [SELinux](https://en.wikipedia.org/wiki/Security-Enhanced_Linux)、
[AppArmor](https://en.wikipedia.org/wiki/AppArmor) 和 [seccomp](https://en.wikipedia.org/wiki/seccomp)
支持。

注意，通过传入空的 `BUILDTAGS` make 变量可以禁用 "seccomp"，但强烈建议保持启用。

使用 `runc --version` 的输出来确认你的 runc 版本是否启用了 seccomp。例如：

```sh
$ runc --version
runc version 1.0.1
commit: v1.0.1-0-g4144b638
spec: 1.0.2-dev
go: go1.16.6
libseccomp: 2.4.4
```
