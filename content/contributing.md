---
title: 参与贡献
---

贡献应当通过 pull request 提交。Pull request 会由一位或多位 maintainer 评审，
在可接受时被合并。

本项目尚处于早期阶段，因此贡献带来的影响远大于其他阶段。就这一点而言，评估任何
改动或新增内容时，考虑其未来的影响比考虑其当下的影响更为重要。

## 让改动被接受 {#successful-changes}

在贡献之前，请先花些精力与项目的 maintainer 协调，然后再提交大型或影响面较广的
PR。这样可以避免你做了额外的工作却最终无法被合并。

没有任何事先沟通就直接提交的 PR，很可能会被直接关闭。

虽然 pull request 是提交代码变更的方式，但如果改动同时伴随额外的工程工作，被接受
的可能性会大得多。我们没有对此作出明确定义，不过这些目标大多是通过沟通设计目标以
及后续的解决方案来达成的。很多时候，先陈述问题、再给出解决方案会更有帮助。

通常，达成这一点的最佳方式是提交一个 issue 来陈述问题。这个 issue 可以包含问题
描述和一份带有需求的清单。如果提出了多种解决方案，应当把备选方案列出来并逐一排除。
即使排除某个方案的理由很微不足道，也请写出来。

较大的改动通常配合设计文档效果最好，类似 `design/` 目录中的那些文档。这些文档聚焦
于提供功能构思时的设计背景，并可以为未来的文档贡献提供参考。

请确保为 bug 添加新的测试以捕获回归，并为新功能添加测试以验证新增的功能。

## 提交信息 {#commit-messages}

有些场合适合写一行的提交信息，但这里不是。提交信息应当遵循最佳实践，包括解释问题
的背景以及是如何解决的，也包括其中的注意事项或所需的后续改动。提交信息应当讲述这
次改动的来龙去脉，让读者理解是什么导致了这次改动。

如果你完全不明白这是什么意思，可以先看看
[How to Write a Git Commit Message](http://chris.beams.io/posts/git-commit/)。

在实践中，维护一份好的提交信息的最佳方式是借助 `git add -p` 和
`git commit --amend` 来打磨出一个扎实的变更集。这样可以随着信息逐渐明朗，一点一点
地拼出一次改动。

如果你把一系列提交 squash 成了一个，不要就这么直接提交。请重写提交信息，就好像这
一系列提交本来就是一气呵成的杰作。

话虽如此，一个 PR 并不要求只有一个提交，只要每个提交都讲述了自己的故事即可。例如，
如果某个功能需要一个新的 package，那么把这个 package 放在一个单独的提交里，再用后
续的提交来使用它，往往是合理的。

记住，你是在用提交信息讲述故事的一部分。别让你负责的这一章变得奇怪。

## 为新文件添加许可证头 {#applying-license-header-to-new-files}

如果你提交的贡献新增了文件，请添加许可证头。你可以手动添加，也可以使用 `ltag`
工具：


```console
$ go get github.com/kunalkushwaha/ltag
$ ltag -t ./script/validate/template
```

上述命令会为 Go 语言源文件、Makefile、Dockerfile 和 shell 脚本添加合适的许可证头。
如果新增了其他类型的文件，则需要添加新的模板。请参阅
https://github.com/kunalkushwaha/ltag 上的文档。

## 签署你的工作 {#sign-your-work}

签署（sign-off）就是在补丁说明末尾添加简单的一行。你的签名证明这个补丁是你自己编写
的，或者你有权将其作为开源补丁传递出去。规则很简单：只要你能够证明以下内容（来自
[developercertificate.org](http://developercertificate.org/)）：

```
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.
660 York Street, Suite 102,
San Francisco, CA 94110 USA

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

那么你只需在每条 git 提交信息中加上一行：

    Signed-off-by: Joe Smith <joe.smith@email.com>

请使用你的真实姓名（抱歉，不接受化名或匿名贡献）。

如果你设置了 git 的 `user.name` 和 `user.email` 配置，就可以用 `git commit -s`
自动签署提交。
