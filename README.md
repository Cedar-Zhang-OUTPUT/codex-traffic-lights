# Codex Traffic Lights

[下载 macOS 应用](https://github.com/Cedar-Zhang-OUTPUT/codex-traffic-lights/releases/latest) · [Agent 使用说明](AGENTS.md) · [MIT License](LICENSE)

一个简单的 macOS 26 原生 Codex 状态灯。高对比度深色外壳与高亮灯珠，竖排三灯从上到下为绿、黄、红，只点亮当前状态对应的灯。黄色呼吸时保持明亮，避免变得难以辨认。

- 绿色常亮：所有已监听会话空闲或完成，没有会话时也为绿色。
- 黄色呼吸：至少一个会话正在运行。
- 红色常亮：明确等待权限、等待回答或结构化工具错误。
- 多会话优先级：红 > 黄 > 绿。拖动移动位置，右键或菜单栏圆点打开菜单。

## 安装与启动

支持 macOS 26，预编译包适用于 Apple Silicon（arm64）。本应用是菜单栏常驻应用，桌面显示悬浮红绿灯，不显示在 Dock 中。

### 给 agent 的最快安装方式

需要 Xcode 的 Swift 6 工具链，无第三方依赖：

```sh
git clone https://github.com/Cedar-Zhang-OUTPUT/codex-traffic-lights.git
cd codex-traffic-lights
swift test
./script/build_and_run.sh --install
```

这会构建应用、安装到 `/Applications/Codex Light.app`、合并安装 Codex Hooks 并启动。已有 Hooks 和其他配置保留，修改前自动备份。不需要 API Key 或其他账号。

### 使用预编译包

从 [Releases](https://github.com/Cedar-Zhang-OUTPUT/codex-traffic-lights/releases/latest) 下载 `Codex-Light-macOS.zip`，解压后把 `Codex Light.app` 放到「应用程序」。打开应用，从菜单栏圆点或红绿灯右键菜单选择「安装／更新 Codex Hooks…」。

自动化安装可以在工作目录中执行：

```sh
curl -fL https://github.com/Cedar-Zhang-OUTPUT/codex-traffic-lights/releases/latest/download/Codex-Light-macOS.zip -o Codex-Light-macOS.zip
curl -fL https://github.com/Cedar-Zhang-OUTPUT/codex-traffic-lights/releases/latest/download/SHA256SUMS.txt -o SHA256SUMS.txt
shasum -a 256 -c SHA256SUMS.txt
ditto -x -k Codex-Light-macOS.zip .
ditto 'Codex Light.app' '/Applications/Codex Light.app'
'/Applications/Codex Light.app/Contents/MacOS/CodexLight' --install-hooks
open '/Applications/Codex Light.app'
```

预编译包使用本地签名，尚未经过 Apple 公证。如果 macOS 阻止打开，建议从源码构建。

## 首次使用

打开 `/Applications/Codex Light.app`。Hooks 已由安装流程写入 Codex 的 `hooks.json`；请在新对话顶部检查并信任，已打开的客户端可能需要重启。CLI 可以用 `/hooks` 检查。不自动写入信任设置。

应用只保存匿名会话标识、状态、时间和用于清理的进程信息，不保存对话正文，不访问网络。开机自启、声音、通知和会话列表均未加入。

## 接入范围

依据本机 Codex CLI 0.162.0-alpha.17.2 的事件定义，支持 SessionStart、SessionEnd、UserPromptSubmit、PreToolUse、PermissionRequest、PostToolUse、PreCompact、PostCompact、Stop 和 Interrupt。

输入等待通过明确的 `request_user_input` 工具事件识别；工具错误通过 `isError`、`success:false`、非零 `exit_code` 等结构化字段识别。Codex 没有向这些 Hooks 暴露的系统错误、模型只用文字提问的情况或不可观测的等待无法识别；不会通过时间或回复文字猜测“卡住”。目前只汇总本机接入这些 Hooks 的会话，远程主机不包含在内。

退出悬浮应用后再次启动会清除上次收集的记录，等待新的 Hooks 事件更新。请在开始任务前打开状态灯。不会按状态持续时间自动回收；明确的会话结束或已记录的 Codex 进程退出才回收。

## 构建

需要 macOS 26 和 Xcode Swift 6 工具链，无第三方依赖。

```sh
swift test
./script/build_and_run.sh --install
```

`--install` 构建、签名、安装应用与 Hooks 并启动。默认脚本构建并启动开发版本，`--build-only` 只构建，`--verify` 启动并检查进程。Codex Run 按钮也使用此脚本。

Hooks 的执行程序独立保存在 `~/Library/Application Support/Codex Light/bin/CodexLightHook`，因此把 UI 应用移到废纸篓不会造成旧会话脚本缺失。卸载时先从 Codex `hooks.json` 移除包含 `--codex-light-hook` 的处理器；等旧会话全部结束、客户端重启后，再清理该程序与状态目录。其他 Hooks 和配置应保留。配置备份以 `hooks.before-codex-light-` 开头，保存在 Codex 配置目录内。

官方事件参考：[Codex Hooks](https://learn.chatgpt.com/docs/hooks)。

## License

MIT。允许其他 agent 和开发者使用、修改和分发。
