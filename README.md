# MZ UI

Project Zomboid Build 42 的深灰蓝色界面模组 / A cool grey-blue UI mod for Project Zomboid Build 42.

## 功能 / Features

- 主菜单与暂停菜单样式 / Title and pause menu styling.
- 设置页标签与普通表单左对齐、左上角返回按钮 / Left-aligned settings tabs and forms, with a top-left Back button.
- 手柄设置页可见区域适配 / Controller settings viewport adjustments.
- 多人服务器浏览器配色、选中标识与连接按钮强调 / Multiplayer browser styling and selection accents.
- 保留原版操作回调、搜索、筛选和连接流程 / Native actions, search, filters and connection flow remain in use.

## 安装 / Installation

1. 从 Releases 下载 `MZUI-0.1.0.zip` 并解压。
2. 将整个 `MZUI` 文件夹放入用户目录下的 `Zomboid/mods/`。
   - Windows: `%USERPROFILE%\Zomboid\mods\MZUI\42\mod.info`
   - Linux: `~/Zomboid/mods/MZUI/42/mod.info`
3. 在游戏模组列表启用 **MZ UI**，完全退出并重新启动游戏。

Download the install ZIP from Releases, extract `MZUI` into your user `Zomboid/mods/` directory, enable the mod and restart the game.

源码安装：复制本仓库的 `mods/MZUI` 文件夹。停用后重启可恢复原版界面。
For a source install, copy `mods/MZUI`. Disable the mod and restart to restore the vanilla UI.

## 兼容性与状态 / Compatibility and status

- 目标版本：Build 42.20 及以上；其他游戏更新可能需要适配。
- 无模组依赖；请勿与接管相同菜单的其他 UI 模组同时启用。
- 包含 PZ Optimization 设置页兼容处理，但未验证所有版本组合。
- **0.1.0 为预览版**。已通过 Lua 语法检查和无图形回归检查；最新设置、手柄和多人页修改尚未完成游戏内视觉验收。不同分辨率、字体缩放和语言可能仍有布局问题。

Targets Build 42.20+. No mod dependencies. Avoid other mods replacing the same menus. This is a preview release: syntax and headless regressions pass, but the latest visual changes still require in-game validation across resolutions, font scales and languages.

报告问题请附游戏版本、分辨率、字体缩放、相关模组和截图；日志请先去除 IP、账号等个人信息。

## 开发 / Development

- `mods/MZUI/42/media/lua/`: client presenters and shared theme/layout helpers.
- `mods/MZUI/tests/layout.lua`: headless regression checks.
- `tools/check.sh`: compile Java helpers and run checks with your local game JAR.
- `tools/package.py`: build the install ZIP and SHA-256 checksum in `dist/`.

```bash
GAME_DIR="/path/to/Project Zomboid" bash tools/check.sh
python3 tools/package.py
```

需要 Python 3、JDK 17+ 和自行安装的游戏。仓库不包含游戏文件。
Requires Python 3, JDK 17+ and your own game installation. Game files are not distributed.

## License

MIT; see [LICENSE](LICENSE). Unofficial community mod, not affiliated with The Indie Stone.
