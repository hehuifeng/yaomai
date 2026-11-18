# 2026-11-17 开发版安装包仍显示上游品牌（旧图标 + 「SayAll Dev/无线麦 SayAll」）

## 现场与证据

- 已安装的 `~/Applications/SayAllDev.app`（build 5，2026-11-16 20:49 打包）显示官方图标与名称 `SayAll Dev`。
- 图标证据：旧包 `Contents/Resources/AppIcon.icns` 为 2,143,989 字节（SHA-256 `faeaede5…`），与换图标提交 `401fdd90` 之前的 `Resources/AppIcon.icns` 一致；新图标应为 2,509,106 字节（`29d2fa40…`）。
- 名称证据：旧包 `Info.plist` 为 `CFBundleDisplayName = SayAll Dev`，且未应用后续提交把默认显示名改为「遥麦」的变更。

## 根因

两个独立原因，均已用产物内容核对确认：

1. **打包时间早于换品牌提交**：旧包构建于 11-16 20:49，`401fdd90`（换图标 + 默认名改「遥麦 Dev」）提交于 22:55，旧包自然不含两者。
2. **本地化表覆盖 Info.plist 显示名**：`Resources/zh-Hans.lproj/InfoPlist.strings` 把 `CFBundleDisplayName`/`CFBundleName` 写死为「无线麦 SayAll」（英文表为 `SayAll`），`Localizable.strings` 的 `app.name`、`menu.about` 及 71 处正文同样写死。macOS 本地化优先于 Info.plist，`package-dev-app.sh` 只改 `Info.plist` 不够，Finder/Dock/关于面板/菜单仍显示上游名。此为脚本缺口，不是缓存问题。

## 修复

- 新增 `scripts/apply-dev-branding.py`：在**构建产物内**（不动仓库源码资源）重写各 `*.lproj/InfoPlist.strings` 的显示名与 `Localizable.strings` 的 `app.name`/`menu.about`，中文表整体替换「无线麦 SayAll」，英文表仅替换名称键与权限说明，保留指虚拟麦克风设备的 `SayAll` 技术描述。
- `scripts/package-dev-app.sh` 在构建后调用该脚本；后续按用户决定把默认显示名定为「遥麦」、安装路径改为 `~/Applications/遥麦.app`。

## 验证

- 重打包（build 6→8）：装好的包内中文表 `CFBundleDisplayName = 遥麦`、`app.name = 遥麦`、`menu.about = 关于遥麦`，官方全名残留 0 处；`AppIcon.icns` SHA-256 `29d2fa40…` 与仓库新图标一致；`codesign --verify --deep --strict` 通过。
- 运行验证：`NSWorkspace.runningApplications` 报告 `localizedName = 遥麦 Dev`（当时名），bundle URL 为 `~/Applications` 下的开发版；`NSWorkspace.icon(forFile:)` 渲染结果为新自绘图标。
- 边界：英文正文句子里的 `SayAll`（设备名/技术描述）未替换，属预期；未做真机遥控器回归（本问题仅涉及打包期文案替换，不改运行时代码路径）。
