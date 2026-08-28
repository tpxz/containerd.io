CRICTL 用户指南 {#crictl-user-guide}
=================
本文假定你已经安装并运行了带有 `cri` 插件的 `containerd`。

本文面向希望调试、检查和管理自己的 pod、容器以及容器 image 的开发者。

在针对本文、`containerd`、`containerd/cri` 或 `crictl` 提交 issue 之前，请先确认该
issue 尚未被提交过。

## 安装 crictl {#install-crictl}
如果你还没有安装 crictl，请安装与你所使用的 `cri` 插件相兼容的版本。如果你是使用者，
你的部署过程应该已经为你安装了 crictl。如果没有，可以从发布版本的 tarball 中获取。
如果你是开发者，crictl 的当前版本在[这里](/script/setup/critools-version)指定。
仓库中提供了一个辅助命令，用于安装正确版本的依赖：
```console
$ make install-deps
```
* 注意：名为 `/etc/crictl.yaml` 的文件用于配置 crictl，
这样你就不必反复指定 crictl 连接容器运行时所用的 runtime sock：
```console
$ cat /etc/crictl.yaml
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: true
```

## 下载并检查容器 image {#download-and-inspect-a-container-image}
pull 命令让容器运行时从容器 registry 下载一个容器 image。
```console
$ crictl pull busybox
  ...
$ crictl inspecti busybox
  ... displays information about the image.
```

***注意：*** 如果你在运行某个 `crictl` 命令时遇到类似下面的错误
（并且你的 containerd 实例已经在运行）：
```console
crictl info
FATA[0000] getting status of runtime failed: rpc error: code = Unimplemented desc = unknown service runtime.v1alpha2.RuntimeService
```
这可能是因为你使用了不正确的 containerd 配置（也许来自某次 Docker 安装）。
你需要把 containerd 配置更新为你正在运行的那个 containerd 实例所对应的配置。
其中一种做法如下：
```console
$ mv /etc/containerd/config.toml /etc/containerd/config.bak
$ containerd config default > /etc/containerd/config.toml
```

## 直接加载容器 image {#directly-load-a-container-image}
另一种把 image 加载到容器运行时的方式是使用 load 命令。使用 load 命令可以把一个
容器 image 从文件注入到容器运行时中。首先你需要创建一个容器 image tarball。
例如，使用 Docker 为 pause 容器创建 image tarball：
```console
$ docker pull registry.k8s.io/pause:3.10.2
  3.10.2: Pulling from pause
  81ede36234b0: Pull complete
  Digest: sha256:f548e0e8e3dc1896ca956272154dde3314e8cc4fde0a57577ee9fa1c63f5baf4
  Status: Downloaded newer image for registry.k8s.io/pause:3.10.2
  registry.k8s.io/pause:3.10.2
$ docker save registry.k8s.io/pause:3.10.2 -o pause.tar
```
然后使用 `ctr` 把该容器 image 加载到容器运行时中：
```console
# The cri plugin uses the "k8s.io" containerd namespace.
$ sudo ctr -n=k8s.io images import pause.tar
  Loaded image: registry.k8s.io/pause:3.10.2
```
列出 image 并检查 pause image：
```console
$ sudo crictl images
IMAGE                       TAG                 IMAGE ID            SIZE
docker.io/library/busybox   latest              f6e427c148a76       728kB
registry.k8s.io/pause       3.10.2              4a83b15d3ecfe       736kB
$ sudo crictl inspecti 4a83b15d3ecfe
  ... displays information about the pause image.
$ sudo crictl inspecti registry.k8s.io/pause:3.10.2
  ... displays information about the pause image.
```

## 运行一个 pod sandbox（使用配置文件） {#run-a-pod-sandbox-using-a-config-file}
```console
$ cat sandbox-config.json
{
    "metadata": {
        "name": "nginx-sandbox",
        "namespace": "default",
        "attempt": 1,
        "uid": "hdishd83djaidwnduwk28bcsb"
    },
    "linux": {
    }
}

$ crictl runp sandbox-config.json
e1c83b0b8d481d4af8ba98d5f7812577fc175a37b10dc824335951f52addbb4e
$ crictl pods
PODSANDBOX ID       CREATED             STATE               NAME               NAMESPACE          ATTEMPT
e1c83b0b8d481       2 hours ago         SANDBOX_READY       nginx-sandbox      default            1
$ crictl inspectp e1c8
  ... displays information about the pod and the pod sandbox pause container.
```
* 注意：如上所示，只要 ID 唯一，你就可以使用截断后的 ID。
* 管理 pod 的其他命令包括：`stops ID` 用于停止一个正在运行的 pod，
`rmp ID` 用于删除一个 pod sandbox。

## 在 pod sandbox 中创建并运行容器（使用配置文件） {#create-and-run-a-container-in-the-pod-sandbox-using-a-config-file}
```console
$ cat container-config.json
{
  "metadata": {
      "name": "busybox"
  },
  "image":{
      "image": "busybox"
  },
  "command": [
      "top"
  ],
  "linux": {
  }
}

$ crictl create e1c83 container-config.json sandbox-config.json
0a2c761303163f2acaaeaee07d2ba143ee4cea7e3bde3d32190e2a36525c8a05
$ crictl ps -a
CONTAINER ID        IMAGE               CREATED             STATE               NAME                ATTEMPT
0a2c761303163       docker.io/busybox   2 hours ago         CONTAINER_CREATED   busybox             0
$ crictl start 0a2c
0a2c761303163f2acaaeaee07d2ba143ee4cea7e3bde3d32190e2a36525c8a05
$ crictl ps
CONTAINER ID        IMAGE               CREATED             STATE               NAME                ATTEMPT
0a2c761303163       docker.io/busybox   2 hours ago         CONTAINER_RUNNING   busybox             0
$ crictl inspect 0a2c7
  ... show detailed information about the container
```
## 在容器中执行命令 {#exec-a-command-in-the-container}
```console
$ crictl exec -i -t 0a2c ls
bin   dev   etc   home  proc  root  sys   tmp   usr   var
```
## 显示容器的统计信息 {#display-stats-for-the-container}
```console
$ crictl stats
CONTAINER           CPU %               MEM                 DISK              INODES
0a2c761303163f      0.00                983kB             16.38kB             6
```
* 管理容器的其他命令包括：`stop ID` 用于停止一个正在运行的容器，
`rm ID` 用于删除一个容器。
## 显示版本信息 {#display-version-information}
```console
$ crictl version
Version:  0.1.0
RuntimeName:  containerd
RuntimeVersion:  v1.7.0
RuntimeApiVersion:  v1
```
## 显示 containerd 与 CRI 插件的状态和配置信息 {#display-status--configuration-information-about-containerd--the-cri-plugin}
<details>
<p>

```console
$ crictl info
{
  "status": {
    "conditions": [
      {
        "type": "RuntimeReady",
        "status": true,
        "reason": "",
        "message": ""
      },
      {
        "type": "NetworkReady",
        "status": true,
        "reason": "",
        "message": ""
      }
    ]
  },
  "cniconfig": {
    "PluginDirs": [
      "/opt/cni/bin"
    ],
    "PluginConfDir": "/etc/cni/net.d",
    "PluginMaxConfNum": 1,
    "Prefix": "eth",
    "Networks": []
  },
  "config": {
    "containerd": {
      "snapshotter": "overlayfs",
      "defaultRuntimeName": "runc",
      "defaultRuntime": {
        "runtimeType": "",
        "runtimePath": "",
        "runtimeEngine": "",
        "PodAnnotations": [],
        "ContainerAnnotations": [],
        "runtimeRoot": "",
        "options": {},
        "privileged_without_host_devices": false,
        "privileged_without_host_devices_all_devices_allowed": false,
        "baseRuntimeSpec": "",
        "cniConfDir": "",
        "cniMaxConfNum": 0,
        "snapshotter": "",
        "sandboxMode": ""
      },
      "untrustedWorkloadRuntime": {
        "runtimeType": "",
        "runtimePath": "",
        "runtimeEngine": "",
        "PodAnnotations": [],
        "ContainerAnnotations": [],
        "runtimeRoot": "",
        "options": {},
        "privileged_without_host_devices": false,
        "privileged_without_host_devices_all_devices_allowed": false,
        "baseRuntimeSpec": "",
        "cniConfDir": "",
        "cniMaxConfNum": 0,
        "snapshotter": "",
        "sandboxMode": ""
      },
      "runtimes": {
        "runc": {
          "runtimeType": "io.containerd.runc.v2",
          "runtimePath": "",
          "runtimeEngine": "",
          "PodAnnotations": [],
          "ContainerAnnotations": [],
          "runtimeRoot": "",
          "options": {
            "BinaryName": "",
            "CriuImagePath": "",
            "CriuPath": "",
            "CriuWorkPath": "",
            "IoGid": 0,
            "IoUid": 0,
            "NoNewKeyring": false,
            "NoPivotRoot": false,
            "Root": "",
            "ShimCgroup": "",
            "SystemdCgroup": false
          },
          "privileged_without_host_devices": false,
          "privileged_without_host_devices_all_devices_allowed": false,
          "baseRuntimeSpec": "",
          "cniConfDir": "",
          "cniMaxConfNum": 0,
          "snapshotter": "",
          "sandboxMode": "podsandbox"
        }
      },
      "noPivot": false,
      "disableSnapshotAnnotations": true,
      "discardUnpackedLayers": false,
      "ignoreBlockIONotEnabledErrors": false,
      "ignoreRdtNotEnabledErrors": false
    },
    "cni": {
      "binDir": "/opt/cni/bin",
      "confDir": "/etc/cni/net.d",
      "maxConfNum": 1,
      "setupSerially": false,
      "confTemplate": "",
      "ipPref": ""
    },
    "registry": {
      "configPath": "",
      "mirrors": {},
      "configs": {},
      "auths": {},
      "headers": {}
    },
    "imageDecryption": {
      "keyModel": "node"
    },
    "disableTCPService": true,
    "streamServerAddress": "127.0.0.1",
    "streamServerPort": "0",
    "streamIdleTimeout": "4h0m0s",
    "enableSelinux": false,
    "selinuxCategoryRange": 1024,
    "sandboxImage": "registry.k8s.io/pause:3.10.2",
    "statsCollectPeriod": 10,
    "systemdCgroup": false,
    "enableTLSStreaming": false,
    "x509KeyPairStreaming": {
      "tlsCertFile": "",
      "tlsKeyFile": ""
    },
    "maxContainerLogSize": 16384,
    "disableCgroup": false,
    "disableApparmor": false,
    "restrictOOMScoreAdj": false,
    "maxConcurrentDownloads": 3,
    "disableProcMount": false,
    "unsetSeccompProfile": "",
    "tolerateMissingHugetlbController": true,
    "disableHugetlbController": true,
    "device_ownership_from_security_context": false,
    "ignoreImageDefinedVolumes": false,
    "netnsMountsUnderStateDir": false,
    "enableUnprivilegedPorts": false,
    "enableUnprivilegedICMP": false,
    "enableCDI": false,
    "cdiSpecDirs": [
      "/etc/cdi",
      "/var/run/cdi"
    ],
    "imagePullProgressTimeout": "1m0s",
    "drainExecSyncIOTimeout": "0s",
    "containerdRootDir": "/var/lib/containerd",
    "containerdEndpoint": "/run/containerd/containerd.sock",
    "rootDir": "/var/lib/containerd/io.containerd.grpc.v1.cri",
    "stateDir": "/run/containerd/io.containerd.grpc.v1.cri"
  },
  "golang": "go1.20.3",
  "lastCNILoadStatus": "OK",
  "lastCNILoadStatus.default": "OK"
}
```

</p>
</details>

## 更多信息 {#more-information}
关于 crictl 的更多信息见[这里](https://github.com/kubernetes-sigs/cri-tools/blob/master/docs/crictl.md)。
