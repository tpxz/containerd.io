# 配置镜像解密 {#configure-image-decryption}
本文档描述了如何为 `containerd` 配置加密容器镜像的解密，以配合 `cri` plugin 使用。

## 加密的容器镜像 {#encrypted-container-images}

加密的容器镜像是包含加密 blob 的 OCI 镜像。这些加密镜像可以通过 [containerd/imgcrypt 项目](https://github.com/containerd/imgcrypt) 创建。为了解密这些镜像，`containerd` 运行时会使用由 `cri` 传入的信息，例如密钥、选项和加密元数据。

## “node” 密钥模型 {#the-node-key-model}

加密基于密钥与实体的关联模型把信任绑定到某个实体上。我们把这称为密钥模型。其中一种用例是希望把密钥的信任绑定到集群中的某个节点。在这种情况下，我们称之为 “node”（或 “host”）密钥模型。未来的工作将包含更多密钥模型，以支持其他信任关联方式（例如多租户场景）。

### “node” 密钥模型的用例 {#node-key-model-usecase}

在该模型中，加密与工作节点绑定。这里的用例围绕这样一个理念：镜像应当只能在受信任的主机上被解密。使用该模型时，可以借助各种基于节点的技术来在工作节点中建立信任并执行安全的密钥分发（例如 TPM、主机远程证明、安全/度量启动）。在这种场景下，运行时能够获取所需的解密密钥。一个例子是使用 [imgcrypt 中的 `--decryption-keys-path` 标志](https://github.com/containerd/imgcrypt)。

### 为 “node” 密钥模型配置镜像解密 {#configuring-image-decryption-for-node-key-model}

自 containerd v1.5 起，这是默认模型。

对于 containerd v1.4，需要向 `/etc/containerd/config.toml` 添加以下配置，并手动重启 `containerd` 服务。
```toml
version = 2

[plugins."io.containerd.grpc.v1.cri".image_decryption]
  key_model = "node"

[stream_processors]
  [stream_processors."io.containerd.ocicrypt.decoder.v1.tar.gzip"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+gzip+encrypted"]
    returns = "application/vnd.oci.image.layer.v1.tar+gzip"
    path = "ctd-decoder"
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env= ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
  [stream_processors."io.containerd.ocicrypt.decoder.v1.tar"]
    accepts = ["application/vnd.oci.image.layer.v1.tar+encrypted"]
    returns = "application/vnd.oci.image.layer.v1.tar"
    path = "ctd-decoder"
    args = ["--decryption-keys-path", "/etc/containerd/ocicrypt/keys"]
    env= ["OCICRYPT_KEYPROVIDER_CONFIG=/etc/containerd/ocicrypt/ocicrypt_keyprovider.conf"]
```

在这个示例中，容器镜像解密被设置为使用 “node” 密钥模型。
此外，解密所用的 [`stream_processors`](https://github.com/containerd/containerd/blob/main/docs/stream_processors.md) 按照 [containerd/imgcrypt 项目](https://github.com/containerd/imgcrypt) 中的说明进行配置，并额外配置了 `--decryption-keys-path` 字段来指定解密密钥在节点本地的存放位置。

`$OCICRYPT_KEYPROVIDER_CONFIG` 环境变量用于 [ocicrypt keyprovider 协议](https://github.com/containers/ocicrypt/blob/main/docs/keyprovider.md)。
