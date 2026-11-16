# 遥麦

**给「无线麦 SayAll」补上按 App 分键位的公开实现。**

官方版的「键位方案」可以按前台 App 自动切换，但那套能力在私有组件 `SayAllButtonProfiles` 里，公开构建拿不到——代码里直接返回 `nil`，所以你自己编译的版本无论怎么设置，都只有一套全局按键。

这个仓库用公开代码把这件事重新实现了一遍：**一个 App 一套键位，按前台 App 自动生效**，不依赖会员、不碰私有组件、不需要任何授权码。

## 先说清楚这不是什么

- **不是官方版本**。我不是 SayAll 的开发者，和 SayAll 官方没有任何关系，也没有得到官方背书。
- **不解锁任何东西**。仓库里没有破解、没有密钥、没有反编译产物，也没有私有包。它只是用 GPL 公开的源码，重新写了一份"按 App 选映射"的实现。
- **不包含付费组件**。`SayAllButtonProfiles`、组合动作库、会员权益都不在里面；这些能力的替代品不是本仓库的目标。

## 它做了什么

### 一个 App 一套键位

- 每个 App 一份稀疏键位：只记录你显式改过的「按键 + 触发方式」，没改的继续走全局，不用给每个 App 复制一整张表。
- 显式设成「禁用」的不会回落到全局——"在这个 App 里这个键什么都不做"是一种真实需求。
- **按下瞬间记录前台 App，整个手势沿用同一份映射**：单击、双击、长按、按住、重复、松开都算同一次手势，中途切 App 不会一半用 A 的配置、一半用 B 的。
- 解析顺序是 App 专属按键 > 私有方案覆盖（公开构建里为空）> 全局映射。按住执行、原生透传、交互模式判定都按同一顺序，不会"显示一个键、执行另一个键"。
- 设置页顶部栏是「全局按键」+「添加 App…」，选中某个 App 时只编辑那个 App 的按键。
- 导入配置时会校验这份映射（schema、动作合法性、引用的 App 是否存在），不合法整份拒绝，不会半套生效；完整配置备份也包含它。

### 开发版和官方版能装在同一台机器上

- `AppIdentity` 靠 Info.plist 里的 `SayAllDevelopmentEdition` 区分身份，决定用哪套 bundle id 和目录。
- 开发版有独立的单实例锁、Application Support 目录（`RemoteMicDev`）、日志目录（`Logs/RemoteMicDev`）、诊断目录（`SayAllDev`）。官方版继续用历史目录名 `RemoteMic`，已有数据不迁移、不受影响。
- 开发版打包时去掉 `SUFeedURL`、关掉 Sparkle 自动更新，不会被官方 appcast 换成正式版；没有 feed 时启动直接跳过更新器。
- `scripts/package-dev-app.sh` 一条命令走完：release 构建 → 改身份 → 校验 → 递增构建号 → 退出旧实例 → 装到 `~/Applications/SayAllDev.app` → 启动。

## 和官方付费版的区别

| | 官方「键位方案」 | 遥麦 |
|---|---|---|
| 按 App 切换 | 支持（自动模式） | 支持 |
| 方案库 / 多套方案 | 支持 | 不支持，只有「全局 + 每个 App」两层 |
| 依赖 | 私有组件 + 会员 | 无，纯公开代码 |
| 手动切换 | 支持 | 不支持（只看前台 App） |

如果哪天官方把这块能力开放到公开构建，请直接用官方的，我这个就退休。

## 自己构建

需要 macOS 和 Swift 6.2 工具链（Xcode 或 Command Line Tools）。

```bash
swift build --disable-keychain
```

只编译。自测：

```bash
scripts/test.sh
```

仓库自带的自测（`Tests/SelfTest`），不依赖 Xcode 的 Testing 框架，48 项全过才算好。

装成一个独立的开发版：

```bash
scripts/package-dev-app.sh
```

默认 bundle id `com.hehf.SayAllDev`、显示名 `遥麦 Dev`，装在 `~/Applications/SayAllDev.app`，装完自动启动；加 `SAYALL_DEV_DEFER_LAUNCH=1` 只装不启动，想换身份就设 `SAYALL_DEV_BUNDLE_IDENTIFIER` / `SAYALL_DEV_DISPLAY_NAME`。

`Tests/RemoteMicTests` 用的是 Swift Testing，需要完整 Xcode：`swift test --disable-keychain`。只装 Command Line Tools 会报 `no such module 'Testing'`，这是工具链限制。

## 跟上上游

这个仓库保留了完整的上游历史，`upstream` 远端指向官方：

```bash
git fetch upstream
git merge upstream/main
```

冲突热点集中在 `AppSettings.swift`、`SettingsView.swift`、`HIDRemoteMonitor.swift`、`BridgeAppModel.swift` 四个文件，合并后建议跑一遍 `scripts/test.sh` 再真机冒烟。

## 来源、许可与边界

- 上游项目：[HD838A/remote-mic-app](https://github.com/HD838A/remote-mic-app)，GPL-3.0-only。本仓库是它的衍生作品，同样以 `GPL-3.0-only` 发布，全文见 [LICENSE.md](LICENSE.md)；上游版权与第三方来源见 [COPYRIGHT.md](COPYRIGHT.md)、[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- **我改了什么**：从上游最新提交起有两个提交——一个加按 App 键位，一个加可共存的开发版身份；改动日期 2026-11。完整 diff 可以直接和 `upstream/main` 对比。
- **图标**：本仓库的 App 图标（`Resources/AppIcon.icns`、`AppIcon.png`、`AppIcons/*.png`）是我自己画的，不属于上游 [LOGO-LICENSE.md](LOGO-LICENSE.md) 的授权范围；仓库里不包含官方 Logo 文件。
- **名字**：`遥麦` 是这个修改版的名字，只表示"改造自 SayAll"，不代表官方，也不表示得到官方认可。文中出现的「无线麦 SayAll」仅用于说明兼容对象。
- 不保证可用、不提供支持、不承诺跟进上游更新。请勿用于商业分发。

## 致谢

蓝牙、音频、HID、按键手势、发布流程这些底座都是上游作者和贡献者做的，我只是在公开代码上补了一个自己需要的维度。

开发文档入口：[DOCUMENTATION.md](DOCUMENTATION.md)

---

hehf · 有问题请开 [Issue](https://github.com/hehuifeng/yaomai/issues)
