# 第三方组件

空白库发布包包含以下独立插件的上游发布文件：

- Document Comments 0.1.15，Kyle McDonald，MIT。[源码与发布](https://github.com/kylemcd/obsidian-document-comments/releases/tag/0.1.15)，许可全文见 `licenses/document-comments.txt`。
- PDF Annotator 0.3.4，Alexander，MIT。[源码与发布](https://github.com/AlexanderT142/Alex-annotator/releases/tag/0.3.4)，许可全文见 `licenses/local-pdf-annotator.txt`。上游 bundle 内的第三方声明原样保留。

In-place Chat 是独立开发的增强插件，采用仓库根目录的 MIT 许可证，不是以上项目的官方组成部分。第三方插件代码未作修改，版本和哈希固定在 dependencies.json。

Obsidian、Codex、Python、PyMuPDF、Zotero 均不在这个压缩包内，使用时需另外安装，并遵循各自条款或许可。此包不含任何账户、学校访问凭据或登录状态。

发布文件的版本、来源和 SHA-256 列于 `release-manifest.json`。安装到用户库后，Obsidian 可能追加无功能的 `nosourcemap` 注释，从而改变本地字节哈希；不能仅凭运行中安装文件的哈希变化断言功能代码被修改。
