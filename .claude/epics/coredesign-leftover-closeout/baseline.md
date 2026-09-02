# 开工基线（实测，勿引用历史数字）

测于 `main` = `56adc26`，工作区仅 `Package.resolved` 一处修改。

## macOS 腿（`swift test`）

```
$ swift test --scratch-path <scratch>
Test run with 454 tests in 68 suites passed after 27.878 seconds with 2 known issues.
[exited with code 0]
```

- **454 tests / 68 suites / 2 known issues**
- ⚠️ **这条不覆盖 `#if os(iOS)` 的 suite**（如 `SurfaceContrastTests`、`DynamicTypeLayoutTests`）——它们在 macOS 上是空 suite，`swift test` 通过在其上是**假绿**。iOS 腿见下。

## iOS 腿（`xcodebuild test -destination 'platform=iOS Simulator,name=iPhone 17 Pro'`）

```
━ Test run with 495 tests in 73 suites passed after 33.209 seconds with 1 known issue.
** TEST SUCCEEDED **
```

- **495 tests / 73 suites / 1 known issue**
- **比 macOS 腿多 41 tests / 5 suites**——这就是 `#if os(iOS)` 盲区的具体大小。
  `SurfaceContrastTests`（显示名「叠加元素与父背景不同色」）**只在这条腿里执行**，
  task 001 的 iOS 断言必须走这里验。

### ⚠️ 取这个数时踩到的两个坑（后续每次验证都适用）

1. **`xcodebuild ... | tail` 的退出码来自 `tail`**。第一次跑拿到 `exited with code 0`，
   输出里却明写 `** TEST FAILED **`。⇒ **判绿读输出，不读退出码**；要退出码就
   `set -o pipefail` + `${PIPESTATUS[0]}`。
2. **`-quiet` 会把汇总行一起吞掉**。只剩退出码、没有测试数时，
   **「跑 0 个测试 + 退出 0」与「全绿」无法区分**。⇒ 取基线务必带
   `-resultBundlePath` 或去掉 `-quiet`，并**核对实际执行的测试数**。

### ⚠️ 模拟器设备本身可能是坏的

`xcodebuild -downloadPlatform iOS` 装完 runtime 后注册的 `iPhone 17 Pro` 磁盘数据目录不存在，
boot 直接失败——而 `xcrun simctl list devices available` **照样把它列为可用**。
⇒ 设备可用性以 `simctl boot` 成功为准；坏了就 `simctl delete` + `simctl create` 重建。

## 环境

- Xcode 26.4（Build 17E192）／ Swift 6.3
- iOS runtime：26.4 (23E244)，设备 `iPhone 17 Pro`（本轮新装）

## 用法

Success Criteria #6 要求「测试数不低于改动前基线」——**用本文件的数，不要用任何 memory 或历史 PR 里记的数**。
