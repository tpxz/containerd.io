# containerd.io 中文站（非官方）

这是 [containerd.io](https://containerd.io) 官方站点仓库的一个中文翻译分支，
构建产物部署在 <https://docs.foyoux.dpdns.org:44443/containerd.io/>。

翻译由机器生成，**非官方、无保证，内容以英文原文为准**。

## 与上游的差异

| | 上游 containerd/containerd.io | 本仓库 |
| --- | --- | --- |
| `baseURL` | `https://containerd.io` | `https://docs.foyoux.dpdns.org:44443/containerd.io/`（子路径部署） |
| 发布方式 | Netlify 自动构建 | `make deploy`，经 ssh 推送静态文件 |
| `content/docs/` | 由 `make refresh-docs` 在每次构建前重新生成，不入库 | **纳入版本管理**，因为翻译就在这里 |
| 语言 | 英文 | 站点界面 + 2.3 文档为简体中文，其余版本仍是英文原文 |

已翻译的范围由 `config.toml` 的 `params.versions.translated` 声明，目前只有 `2.3`。
未翻译的版本页面顶部会显示提示条。

## 翻译约定

见 [`tools/translation-guide.md`](tools/translation-guide.md)。最关键的一条：
**每个被翻译的标题都要用 `{#原英文锚点}` 保留原来的锚点 id**，否则站内、站外
所有指向 `#getting-started` 这类锚点的链接都会失效。

用下面的命令核对——它会把每个译文的锚点集合与 `containerd-2.3/docs/` 里的英文
原文逐一对比，报告丢失的锚点和失效的页内链接：

```bash
python tools/check-anchors.py 2.3
```

## 本地运行

需要 Hugo extended（本仓库在 0.165 上验证过；上游 `netlify.toml` 固定的
0.116 已不适用，主题里的 `getJSON`、`.Site.IsServer` 等写法已按新版改过）。

```bash
npm install .
```

```bash
make serve
```

浏览器打开 <http://localhost:1313/containerd.io/>。注意站点带 `/containerd.io/`
子路径，直接访问 <http://localhost:1313/> 会 404。

## 构建与部署

```bash
make deploy
```

等价于 `make clean production-build` 后执行
[`tools/deploy.sh`](tools/deploy.sh)：把 `public/` 打包经 ssh 传到
`mycaddy:/srv/docs/containerd.io`，在远端解包到临时目录后再原子替换线上目录，
上一版保留在 `/srv/docs/containerd.io.previous`。

目标主机和路径可以覆盖：

```bash
make deploy DEPLOY_HOST=myhost DEPLOY_PATH=/srv/docs/containerd.io
```

只想构建不部署：

```bash
make production-build
```

## 同步上游文档

上游文档在 [containerd/containerd 的 docs 目录](https://github.com/containerd/containerd/tree/main/docs)，
通过 git submodule 引入。**重新导入会覆盖掉译文**，所以它不是构建步骤，需要
手动执行：

```bash
make materialize-docs
```

`materialize-docs` 只从已检出的 submodule 复制，不联网、不需要 rsync，Windows
的 Git Bash 下也能跑。要连带更新 submodule 到上游最新，用上游原版的
`make refresh-docs`（需要 rsync）。

导入之后 `content/docs/2.3/` 会退回英文，需要按翻译约定重新翻译，再用
`check-anchors.py` 核对。

## Admonition 块

文档里可用五种提示块：`info`（蓝）、`success`（绿）、`warning`（黄）、
`danger`（红）、`requirement`（紫）。

```
这里是正文。

{{< success >}}
这里是一个绿色的 success 块
{{< /success >}}
```

## 检查链接

```bash
make check-links
```

删除 `public/`、构建生产版本，然后用 htmltest 检查输出中的 404 等问题。

## 上游文档的写法

本仓库不接受直接新增文档——文档的唯一来源是 containerd/containerd 仓库的
`docs/` 目录。页面 front matter 支持 `title`、`weight`、`description`、
`draft`、`short` 等参数，详见
[上游 README](https://github.com/containerd/containerd.io/blob/main/README.md)。
