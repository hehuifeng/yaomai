#!/bin/zsh
# Build and install the development edition of SayAll.
#
# The development edition uses its own bundle identifier, display name, URL
# scheme and on-disk namespaces so it can be installed next to the official
# app. It never overwrites /Applications/SayAll.app and never registers the
# official appcast, so a local build cannot be replaced by a release update.
set -euo pipefail

ROOT="${0:A:h:h}"
BUNDLE_IDENTIFIER="${SAYALL_DEV_BUNDLE_IDENTIFIER:-com.hehf.SayAllDev}"
DISPLAY_NAME="${SAYALL_DEV_DISPLAY_NAME:-遥麦}"
URL_SCHEME="${SAYALL_DEV_URL_SCHEME:-sayall-dev}"
TARGET="${SAYALL_DEV_APP_TARGET:-$HOME/Applications/遥麦.app}"
STATE="$HOME/.sayall-dev-build"

if [[ "$(uname -m)" == x86_64 ]]; then
  RELEASE_VARIANT=intel
else
  RELEASE_VARIANT=apple-silicon
fi
source "$ROOT/scripts/release-variant.sh"

# The public build path must not see any private package inputs.
unset SAYALL_ENABLE_PRIVATE_SWIFTPM \
  SAYALL_PRIVATE_PLATFORM_PACKAGE_PATH \
  SAYALL_PRIVATE_ARTIFACT_PACKAGE_PATH \
  SAYALL_AI_PACKAGE_PATH \
  SAYALL_COMBINATION_ACTIONS_PATH \
  SAYALL_BUTTON_PROFILES_PACKAGE_PATH \
  SAYALL_MAC_REMOTE_PACKAGE_PATH \
  SAYALL_SIRI_REMOTE_PACKAGE_PATH \
  SAYALL_CHROMECAST_PACKAGE_PATH

export CONFIGURATION=release
export SAYALL_PRIVATE_PLATFORM_MODE=public
export SAYALL_BUILD_CHANNEL=public
export CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
for requirement in \
  REQUIRE_SIRI_REMOTE_SIGNING REQUIRE_DEVELOPER_ID_SIGNING \
  REQUIRE_WEB_REMOTE_CONFIGURATION REQUIRE_EARLY_ACCESS_CONFIGURATION \
  REQUIRE_SAYALL_AI_PACKAGE REQUIRE_SAYALL_COMBINATION_ACTIONS \
  REQUIRE_SAYALL_BUTTON_PROFILES REQUIRE_SAYALL_MAC_REMOTE_PACKAGE \
  REQUIRE_SAYALL_PRIVATE_ARTIFACT_PACKAGE REQUIRE_SAYALL_CHROMECAST \
  REQUIRE_DIAGNOSTIC_PUBLIC_KEY REQUIRE_DIAGNOSTIC_SERVICE \
  REQUIRE_RELEASE_BUILD_CHANNEL; do
  export "$requirement"=0
done
export SAYALL_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER"
export SAYALL_APP_DISPLAY_NAME="$DISPLAY_NAME"
export SAYALL_URL_SCHEME="$URL_SCHEME"

max_build=0
for app in "$TARGET"; do
  value="$(plutil -extract CFBundleVersion raw -o - "$app/Contents/Info.plist" 2>/dev/null || true)"
  if [[ "$value" == <-> ]] && (( value > max_build )); then
    max_build="$value"
  fi
done
if [[ -f "$STATE" ]]; then
  value="$(<"$STATE")"
  if [[ "$value" == <-> ]] && (( value > max_build )); then
    max_build="$value"
  fi
fi
next_build=$((max_build + 1))
source_commit="$(git -C "$ROOT" rev-parse HEAD)"
dirty=false
if [[ -n "$(git -C "$ROOT" status --porcelain)" ]]; then
  dirty=true
fi

"$ROOT/scripts/build-app.sh"

app="$RELEASE_OUTPUT_DIR/SayAll.app"
plist="$app/Contents/Info.plist"
plutil -replace CFBundleVersion -string "$next_build" "$plist"
plutil -replace SayAllSourceDirty -bool "$dirty" "$plist" 2>/dev/null ||
  plutil -insert SayAllSourceDirty -bool "$dirty" "$plist"

# 中文/英文的本地化表把官方产品名写死在 InfoPlist.strings 和
# Localizable.strings 里，会盖掉上面写进 Info.plist 的显示名；这里只改构建
# 产物，仓库资源继续跟随上游。
python3 "$ROOT/scripts/apply-dev-branding.py" "$app" "$DISPLAY_NAME"

actual_bundle="$(plutil -extract CFBundleIdentifier raw -o - "$plist")"
if [[ "$actual_bundle" != "$BUNDLE_IDENTIFIER" ]]; then
  print -u2 "Built app has bundle identifier $actual_bundle, expected $BUNDLE_IDENTIFIER"
  exit 1
fi
if [[ "$(plutil -extract SayAllDevelopmentEdition raw -o - "$plist" 2>/dev/null || true)" != "true" ]]; then
  print -u2 "Built app is missing SayAllDevelopmentEdition=true"
  exit 1
fi
if plutil -extract SUFeedURL raw -o - "$plist" >/dev/null 2>&1; then
  print -u2 "Development build must not ship an SUFeedURL"
  exit 1
fi

codesign --force --timestamp=none --sign - \
  --requirements "=designated => identifier \"$BUNDLE_IDENTIFIER\"" \
  --entitlements "$ROOT/packaging/app.entitlements" "$app"
codesign --verify --deep --strict "$app"

install_app() {
  local destination="$1" staged backup=""
  mkdir -p "${destination:h}" || return 1
  staged="$(mktemp -d "${destination:h}/.sayall-dev-stage.XXXXXX")" || return 1
  {
    ditto "$app" "$staged/SayAll.app" || return 1
    codesign --verify --deep --strict "$staged/SayAll.app" || return 1
    if [[ -e "$destination" ]]; then
      backup="$HOME/.Trash/yaomai.app.local-$(date -u +%Y%m%dT%H%M%S)-$$"
      test ! -e "$backup" && mv "$destination" "$backup" || return 1
    fi
    if ! mv "$staged/SayAll.app" "$destination"; then
      if [[ -n "$backup" ]] && ! mv "$backup" "$destination"; then
        print -u2 -- "Could not restore the previous development app. Recover it from: $backup"
        return 2
      fi
      return 1
    fi
  } always {
    mv "$staged" "$HOME/.Trash/${staged:t}-$$" ||
      print -u2 -- "Could not move the staging directory to Trash: $staged"
  }
}

for pid in $(pgrep -fx -- "$TARGET/Contents/MacOS/RemoteMic" || true); do
  kill -TERM "$pid"
  for attempt in {1..25}; do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.2
  done
  if kill -0 "$pid" 2>/dev/null; then
    # Modal sheets can delay the normal termination path. A local development
    # build is replaceable, so force it instead of leaving a stale bundle.
    print -u2 "The previous development instance ignored SIGTERM; forcing termination."
    kill -KILL "$pid" 2>/dev/null || true
    for attempt in {1..10}; do
      kill -0 "$pid" 2>/dev/null || break
      sleep 0.2
    done
  fi
  if kill -0 "$pid" 2>/dev/null; then
    print -u2 "The previous development instance could not be terminated."
    exit 1
  fi
done

install_app "$TARGET"
codesign --verify --deep --strict "$TARGET"
print "$next_build" > "$STATE"
print "Installed $TARGET, bundle $BUNDLE_IDENTIFIER, build $next_build, source $source_commit, dirty=$dirty"
if [[ "${SAYALL_DEV_DEFER_LAUNCH:-0}" != 1 ]]; then
  open -a "$TARGET"
fi
