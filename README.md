# 无线麦 SayAll · 我的个人修改版

这是我给自己用的一版无线麦 SayAll，基于 [HD838A/remote-mic-app](https://github.com/HD838A/remote-mic-app) 改的，不对外发布，跟 SayAll 官方没有关系。

官方版本的功能、下载和教程都在上游仓库与官网；这个 README 只讲三件事：我为什么改、改了什么、怎么自己构建。

## 我为什么另开一个仓库

官方版本来就能用，我动手只有几个很具体的理由。

**一台遥控器，在不同 App 里应该干不同的事。** 官方只有全局映射（外加私有方案），而我希望在编辑器里按 F5 是录音、在浏览器里按 F5 是刷新、在剪辑软件里又是第三种。

**我想让开发版和官方版一起装着。** 两个 App 抢同一把单实例锁、共用一份数据目录，调试时官方版打不开，数据也可能互相污染。

**我要一条能随时跟上上游的分支。** 上游迭代很快，我不想把改动摊在 `main` 上，以后每次合并都打架。

## 我改了什么

### 一、App 专属按键

- 每个 App 一份稀疏键位：只记录我显式改过的「按键 + 触发方式」，没改的继续走全局，不用给每个 App 复制一整张表。
- 显式设成「禁用」的不会回落到全局——我需要「在这个 App 里这个键什么都不做」这种状态。
- **按下瞬间记录前台 App，整个手势沿用同一份映射**：单击、双击、长按、按住、重复、松开都算同一次手势，中途切 App 不会一半用 A 的配置、一半用 B 的。
- 解析顺序是 App 专属按键 > 私有方案覆盖（公开构建里为空）> 全局映射。按住执行、原生透传、交互模式判定都按同一顺序，不会出现「显示是一个键、执行是另一个键」。
- 设置页加了顶部栏：「全局按键」+「添加 App…」。选中某个 App 时只编辑那个 App 的按键，其余按键保持全局。
- 导入配置时会校验这份映射（schema、动作是否合法、引用的 App 是否存在），不合法就整份拒绝，而不是半套生效；完整配置备份也包含它。

### 二、能和官方版共存的开发版

- `AppIdentity` 靠 Info.plist 里的 `SayAllDevelopmentEdition` 判断自己是哪一版，再决定用哪套 bundle id 和目录。
- 开发版有独立的单实例锁、Application Support 目录（`RemoteMicDev`）、日志目录（`Logs/RemoteMicDev`）、诊断目录（`SayAllDev`）。官方版继续用历史目录名 `RemoteMic`，已有数据不迁移、不受影响。
- 开发版打包时去掉 `SUFeedURL`、关掉 Sparkle 的自动更新，所以不会被官方 appcast 换成正式版；没有 feed 时启动直接跳过更新器。
- `scripts/package-dev-app.sh` 一条命令走完：release 构建 → 改身份 → 校验 → 递增构建号 → 退出旧实例 → 安装到 `~/Applications/SayAllDev.app` → 启动，旧版本进废纸篓。
- `scripts/build-app.sh` 支持 `SAYALL_BUNDLE_IDENTIFIER` / `SAYALL_APP_DISPLAY_NAME` / `SAYALL_URL_SCHEME` 三个变量成组覆盖身份：必须同时提供并做格式校验；三个都不给时，行为和官方发布完全一致。

## 自己构建

需要 macOS 和 Swift 6.2 工具链（Xcode 或 Command Line Tools），要有 `swift` 和 `xcrun`。

```bash
swift build --disable-keychain
```

只编译，不打包。

```bash
scripts/test.sh
```

仓库自带的自测，跑的是 `Tests/SelfTest`，不依赖 Xcode 的 Testing 框架，48 项全过才算好。

```bash
scripts/package-dev-app.sh
```

构建并安装开发版。默认 bundle id `com.hehf.SayAllDev`、显示名 `SayAll Dev`、装在 `~/Applications/SayAllDev.app`，装完自动启动；加 `SAYALL_DEV_DEFER_LAUNCH=1` 只装不启动。

想换身份：

```bash
SAYALL_DEV_BUNDLE_IDENTIFIER=com.example.SayAllDev \
SAYALL_DEV_DISPLAY_NAME="SayAll 自用" \
SAYALL_DEV_URL_SCHEME=sayall-dev \
scripts/package-dev-app.sh
```

`Tests/RemoteMicTests` 用的是 Swift Testing，需要完整 Xcode：`swift test --disable-keychain`。只装 Command Line Tools 会报 `no such module 'Testing'`，这是工具链限制，不是我改动的问题。

## 分支与跟上上游

- `main` 和 `feature/app-keymap-dev` 指向同一个提交：上游的最新提交，加上我的两个改动。
- `upstream` 远端指向官方仓库，同步就两步：

```bash
git fetch upstream
git merge upstream/main
```

## 来源、许可与边界

- 上游项目：[HD838A/remote-mic-app](https://github.com/HD838A/remote-mic-app)；官网 [sayall.app](https://sayall.app/)。
- 代码许可：`GPL-3.0-only`，全文见 [LICENSE.md](LICENSE.md)；版权与第三方来源见 [COPYRIGHT.md](COPYRIGHT.md)、[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 官方的 App Logo、图标等品牌资源不在 GPL 范围内，需要单独授权（[LOGO-LICENSE.md](LOGO-LICENSE.md)）。我没有拿到这份授权，所以这个仓库只在我自己机器上用、不公开分发构建产物；哪天要对外发，我会先把图标换成自己画的。
- 这个仓库不是官方发行版，和 SayAll 官方没有任何关系，出问题不要去找官方。

## 致谢

上游作者和所有贡献者已经把 Mac 端这套底座做出来了——蓝牙、音频、HID、发布流程都在里面，我只是在上面加了自己需要的两个功能。

开发文档入口：[DOCUMENTATION.md](DOCUMENTATION.md)

---

署名 hehf，有问题请开 [Issue](https://github.com/hehuifeng/sayall/issues)。
