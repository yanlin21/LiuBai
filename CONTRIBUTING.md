# 参与贡献

欢迎提交 Issue 和 Pull Request。

1. Fork 仓库并从 `main` 创建分支。
2. 保持界面极简，优先使用 SwiftUI、AppKit 和 WidgetKit 原生能力。
3. 不要提交证书、描述文件、个人 Team ID、用户文稿或构建产物。
4. 提交前运行一次无签名构建：

```bash
xcodebuild \
  -project LiuBai.xcodeproj \
  -scheme LiuBai \
  -configuration Debug \
  -derivedDataPath .build/ci \
  CODE_SIGNING_ALLOWED=NO \
  DEVELOPMENT_TEAM=CI00000000 \
  ENABLE_USER_SCRIPT_SANDBOXING=NO \
  OTHER_SWIFT_FLAGS=-disable-sandbox \
  build
```
