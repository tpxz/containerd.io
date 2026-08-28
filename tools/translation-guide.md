# containerd.io 中文翻译规范

本仓库是 containerd.io 的非官方简体中文翻译站。所有 Markdown 就地覆盖翻译
（不新增 `.zh.md` 之类的并行文件）。翻译时严格遵守以下规则。

## 1. 标题必须保留原英文锚点

站内和站外都有大量指向英文锚点的链接（`#getting-started`、
`[见下文](#configuration)`、外部博客的深链等）。翻译标题会改变 Hugo 生成的
锚点 id，因此**每个被翻译的标题都必须显式带上原英文锚点**：

```markdown
## Getting started          ->  ## 快速开始 {#getting-started}
### Option 2: From `apt-get` or `dnf`  ->  ### 方式二：使用 `apt-get` 或 `dnf` {#option-2-from-apt-get-or-dnf}
```

锚点按 GitHub 规则从**原英文标题**生成：转小写 → 去掉除 `-` `_` 以外的标点
（含反引号、括号、冒号、点号）→ 空格换成 `-`。同一文件内出现重复锚点时，
第二个及以后追加 `-1`、`-2`，与原文档的行为保持一致。

`config.toml` 里已开启 `markup.goldmark.parser.attribute.title`，`{#...}` 生效。

## 2. 不翻译的内容

- **代码块**（``` 围栏内的一切）：命令、配置、输出、Go/JSON/TOML/YAML/shell
  代码全部原样保留，块内的英文注释也保留原样。
- **行内代码** `` `like this` ``：命令名、字段名、路径、标志、类型名不译。
- **链接 URL**、图片路径：一个字符都不改（包括 `../foo.png` 这种相对路径）。
- **front matter**（文件开头 `---` 之间的部分）：整块原样保留。`nav_title` 是
  查表用的键，翻译会破坏侧边栏。
- Hugo shortcode 的标签本身（`{{< info >}}`、`{{< latest >}}`、`{{< /info >}}`），
  但 shortcode 之间的正文要翻译。
- HTML 标签、属性、`<!-- -->` 注释里的指令。

## 3. 术语

保留英文原词（不加括号注释、不音译）：

containerd、runc、shim、snapshotter、plugin、namespace、CRI、CNI、OCI、
Kubernetes、kubelet、pod、sandbox、rootfs、mount、image、manifest、digest、
registry、daemon、socket、cgroup、seccomp、AppArmor、SELinux、systemd、
overlayfs、devmapper、erofs、NRI、gRPC、TTRPC、GC、CAS、blob、layer、tarball。

常用译法：

| 英文 | 中文 |
| --- | --- |
| container runtime | 容器运行时 |
| garbage collection | 垃圾回收 |
| content store | 内容存储 |
| lease | 租约 |
| reference | 引用 |
| label | 标签 |
| backend | 后端 |
| deprecated | 已弃用 |
| release | 发布版本 / 版本 |
| upstream | 上游 |
| best effort | 尽力而为 |
| out of scope | 不在范围内 |

## 4. 文字风格

- 简体中文，技术文档口吻，陈述句，不用“我们建议您”这类客套。
- 中文与英文/数字之间加一个空格：`使用 containerd 2.3 时`。
- 标点用全角：`，。：；（）“”`。代码和 URL 内的标点不动。
- 强调（加粗/斜体）的边界若紧挨中文标点且外侧直接接汉字，改用 HTML 标签
  `<strong>` / `<em>`（CommonMark 的 flanking 规则此时会让 `**` 失效）；
  其余情况一律用标准 Markdown `**` / `*`。
- 表格：保留列结构和对齐行，表头与说明文字翻译，字段名/取值不译。
- 列表、缩进、空行等结构原样保留。

## 5. 不要做的事

- 不增删内容，不改写结构，不合并或拆分段落。
- 不添加“译者注”。
- 不修正原文的事实错误或失效链接（保持与上游一致，便于后续同步）。
- 不在没有 front matter 的文件里新增 front matter。
