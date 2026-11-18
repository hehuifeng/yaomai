# 遥麦 (YaoMai)

One remote, one button — but a different action in every app.

遥麦 gives each macOS app its own button keymap for the **Xiaomi Bluetooth Remote 2 Pro (RC003)** and **Xiaomi Bluetooth Remote 2 (RC001)**: whichever app is in front, the remote follows it. It is a modified build of [SayAll](https://github.com/HD838A/remote-mic-app) for macOS, and its development build is designed to install alongside the official app without sharing locks, data or update feeds.

The name comes from 遥 (remote) and 麦 (microphone).

Being a modified build, it also fills one gap: per-app keymap switching ships in SayAll's private `SayAllButtonProfiles` package, so public builds only have a single global mapping — 遥麦 re-implements that behaviour in public code. It does not unlock membership, bundle private components or bypass any licence check.

This is **not** an official SayAll release and is not affiliated with the project or its authors.

The documentation is written in Chinese — start with [README.md](README.md).

- Licence: `GPL-3.0-only`, see [LICENSE.md](LICENSE.md). Upstream copyright and third-party notices: [COPYRIGHT.md](COPYRIGHT.md), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
- The app icon in this repository is my own artwork and is not covered by the upstream [LOGO-LICENSE.md](LOGO-LICENSE.md).

— hehf · issues: https://github.com/hehuifeng/yaomai/issues
