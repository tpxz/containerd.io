# 以非 root 用户运行 containerd {#running-containerd-as-a-non-root-user}

非 root 用户可以借助 [`user_namespaces(7)`](http://man7.org/linux/man-pages/man7/user_namespaces.7.html) 来运行 containerd。

例如可以用 [RootlessKit](https://github.com/rootless-containers/rootlesskit) 建立一个 user namespace（同时还有 mount namespace，以及可选的 network namespace）。更多信息请参考 RootlessKit 文档。

另见 https://rootlesscontaine.rs/ 。

## “简单方式” {#easy-way}

最简单的方式是使用 [containerd/nerdctl](https://github.com/containerd/nerdctl) 中包含的 `containerd-rootless-setuptool.sh`。

```console
$ containerd-rootless-setuptool.sh install
$ nerdctl run -d --restart=always --name nginx -p 8080:80 nginx:alpine
```

更多信息见 [nerdctl/docs/rootless.md](https://github.com/containerd/nerdctl/blob/main/docs/rootless.md)。

## “复杂方式” {#hard-way}

<details>
<summary>点击查看“复杂方式”</summary>

<p>

### Daemon {#daemon}

```console
$ rootlesskit --net=slirp4netns --copy-up=/etc --copy-up=/run \
  --state-dir=/run/user/1001/rootlesskit-containerd \
  sh -c "rm -f /run/containerd; exec containerd -c config.toml"
```

* `--net=slirp4netns --copy-up=/etc` 只在需要 unshare network namespace 时才必需。
  关于网络驱动的更多信息见 [RootlessKit 文档](https://github.com/rootless-containers/rootlesskit/blob/v0.14.1/docs/network.md)。
* `--copy-up=/DIR` 会在 `/DIR` 上挂载一个可写的 tmpfs，其中包含指向父 namespace 中 `/DIR` 下文件的符号链接，
  这样用户就可以在 mount namespace 里向 `/DIR` 添加或删除文件。
  典型配置下需要 `--copy-up=/etc` 和 `--copy-up=/run`。
  取决于 containerd 的插件配置，可能还需要添加更多 `--copy-up` 选项。
* `rm -f /run/containerd` 会删除指向父 namespace 中 `/run/containerd` 的「copy-up」符号链接（如果存在），非 root 用户无法访问它。
  宿主机上真正的 `/run/containerd` 目录不受影响。
* 未设置 `--state-dir` 时，它会被设为 `/tmp` 下的一个随机目录。RootlessKit 会把 PID 写入该目录下名为 `child_pid` 的文件。
* 需要提供带有自定义路径配置的 `config.toml`，例如：
```toml
version = 2
root = "/home/penguin/.local/share/containerd"
state = "/run/user/1001/containerd"

[grpc]
  address = "/run/user/1001/containerd/containerd.sock"
```

### Client {#client}

诸如 `ctr` 之类的客户端程序也需要在 daemon 所在的 namespace 内执行。
```console
$ nsenter -U --preserve-credentials -m -n -t $(cat /run/user/1001/rootlesskit-containerd/child_pid)
$ export CONTAINERD_ADDRESS=/run/user/1001/containerd/containerd.sock
$ export CONTAINERD_SNAPSHOTTER=native
$ ctr images pull docker.io/library/ubuntu:latest
$ ctr run -t --rm --fifo-dir /tmp/foo-fifo --cgroup "" docker.io/library/ubuntu:latest foo
```

* 在 5.11 之前的内核上，`overlayfs` snapshotter 无法在 user namespace 中工作，Ubuntu 和 Debian 内核除外。
  不过，如果内核版本 >= 4.18，可以改用 [`fuse-overlayfs` snapshotter](https://github.com/containerd/fuse-overlayfs-snapshotter)。
* 启用 cgroup 需要 cgroup v2 和 systemd，例如 `ctr run --cgroup "user.slice:foo:bar" --runc-systemd-cgroup ...` 。
  另见 [runc 文档](https://github.com/opencontainers/runc/blob/v1.0.0-rc93/docs/cgroup-v2.md)。


</p>
</details>
