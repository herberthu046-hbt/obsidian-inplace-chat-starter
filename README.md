# In-place Chat 空白库

这是给同学复制使用的空白 Obsidian 库。只有插件、安装脚本和这份说明，没有讲义、账号、聊天记录或个人设置。

## 第一次打开

1. 将整个文件夹解压到准备长期使用的位置。在 Obsidian 中“打开本地仓库”，选择此文件夹，允许社区插件。
2. 安装 Codex 并登录自己的账户，先确认能独立提问。常用 CLI 安装方式：安装 Node.js 22.13+ 后运行 `npm install -g @openai/codex`，再运行 `codex login`。
3. 在本文件夹打开 PowerShell，运行：

   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\setup-codex-home.ps1 -Vault .
   ```

   需要时确认一次 UAC。脚本只创建两个指向你自己 Codex 登录文件的链接；不会携带别人的账号或修改系统执行策略。它根据库路径建立独立会话目录，因此移动本库后需要再次运行。
4. 在设置 → In-place Chat 检查 Codex 路径与模型。模型留空跟随你本机的默认模型；也可填写账户可用模型名。
5. 将自己的 Markdown / PDF 放进库。PDF 全文阅读建议另装 Python 与 `python -m pip install PyMuPDF`。

## 开始问答

- Markdown：选中文字，`Alt+C` 添加评论，写 `@chat 你的问题`，保存。
- PDF：点顶部 **Annotate**，选中文字，保存含 `@chat` 的评论。保持 PDF 批注模式打开。
- `Alt+S` 发送当前文档待答。仅写批注不会自动消耗模型用量。
- PDF 单击高亮标为已读，双击打开聊天详情。重叠批注先选择讨论。
- 详情页底部直接追加提问：Enter 发送，Shift+Enter 换行。
- 点击底部 chat 状态可查看全库待答、未读与失败记录。回答 15 分钟超时后先恢复/检查记录，避免重复发送。

## 使用前了解

本版本主要支持 Windows 桌面；不支持手机端。运行 Codex 时使用完整本机权限、无逐次审批，可读写文件并使用你配置的联网与工具能力。材料和工具结果会交给你的模型服务处理，用量由你的账户承担。

插件会话与 Codex 桌面会话分开，登录仍共用你的当前登录。不要公开使用后的整个库：批注、聊天、`.inplace-chat/` 和插件 `data.json` 可能包含个人内容。此压缩包本身没有这些数据。

内含 In-place Chat、Document Comments 0.1.15、PDF Annotator 0.3.4。许可见 `LICENSE`、`THIRD-PARTY-NOTICES.md` 和 `licenses/`。不包含 Obsidian、Codex、Python 或模型订阅。

完整文档与更新：https://github.com/herberthu046-hbt/obsidian-inplace-chat

升级时只替换 `.obsidian/plugins/inplace-chat/` 下三个发布文件，保留自己的数据。GitHub 的 Source code 是开发源码；新同学应下载 Releases 中的 empty-vault 包。
