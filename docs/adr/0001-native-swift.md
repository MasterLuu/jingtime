---
status: accepted
---

# 用原生 Swift 做悬浮时钟

悬浮时钟只跑在这台 Mac 上，要盖住全屏、登录后自己出现，并且不进程序坞。决定用 Swift 做原生应用，直接使用系统窗口。

## Considered Options

- Electron 或网页壳：能跨平台，但全屏置顶和常驻不可靠，体积也大。
- Python：能做小窗，但盖住全屏和登录自启不如系统窗口稳。
