# 留白 LiuBai

一款为小说写作而生的极简原生 macOS 文字记录工具。

留白把编辑器做成一张安静的“纸”：没有常驻工具栏，没有多余按钮，写作时只保留文字与呼吸感；清单标签像夹在纸背后的便签，从窗口右侧伸出，需要时才展开。

## 特性

- 原生 macOS：SwiftUI + AppKit + WidgetKit
- 舒适的无干扰长文编辑体验，适合小说、随笔与灵感记录
- 自动保存与历史版本浏览
- 原生毛玻璃窗口，可调整透明度与色调
- 右侧纸背式清单标签，名称完整显示并随内容自适应宽度
- 多组 Todo 清单，每组支持鲜亮的马卡龙色
- macOS 桌面小组件，可按标签展示不同清单并直接勾选
- 本地优先，无账号、无广告、无分析 SDK、无云端依赖

## 系统要求

- macOS 14 或更高版本
- Xcode 26 或更新版本（推荐使用当前稳定版）
- 用于本机签名的免费或付费 Apple Developer Team

macOS 26 上会使用新的系统玻璃效果；较早系统自动使用原生材质作为兼容方案。

## 构建

1. 克隆仓库：

   ```bash
   git clone https://github.com/yanlin21/LiuBai.git
   cd LiuBai
   ```

2. 用 Xcode 打开 `LiuBai.xcodeproj`。
3. 分别选择 `LiuBai` 与 `LiuBaiWidget` target，在 **Signing & Capabilities** 中选择你自己的 Team。
4. 运行 `LiuBai` scheme。

项目会根据 Team ID 自动生成彼此匹配的标识：

```text
App:       com.liubai.<TEAM_ID>
Widget:    com.liubai.<TEAM_ID>.widget
App Group: <TEAM_ID>.liubai.shared
```

也可以在终端打包 Release 版：

```bash
LIUBAI_TEAM_ID=你的TeamID ./build-app.sh
```

生成的应用位于 `outputs/留白.app`。

## 添加桌面小组件

先至少运行一次留白并建立一个清单，然后在 macOS 桌面右键，选择“编辑小组件”，搜索“留白清单”。每个小组件都可以单独选择一个标签。

## 数据位置

正文、历史版本与清单统一保存在 App Group 容器的 `LibraryData/library.json`。首次升级时，应用会自动尝试迁移旧位置 `~/Library/Application Support/LiuBai/library.json` 的数据。

仓库不包含开发证书、描述文件、个人 Team ID 或任何用户文稿。

## 隐私与许可

详见 [隐私说明](PRIVACY.md)。代码以 [MIT License](LICENSE) 开源。

---

如果你也喜欢“写作时什么都不打扰”的工具，欢迎 Star、提 Issue 或贡献改进。
