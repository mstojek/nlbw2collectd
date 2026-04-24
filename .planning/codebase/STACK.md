# Tech Stack

## Core
- **Languages:** Lua, JavaScript, Makefile, Shell
- **Runtime:** OpenWrt (collectd plugin `collectd-mod-lua`, LuCI framework)

## Dependencies
- `collectd`
- `collectd-mod-lua`
- `libubus-lua`
- `nlbwmon`
- `luci-app-statistics`

## Configuration
- standard OpenWrt UCI configuration and Makefile packaging for `.ipk` generation.
- collectd `.conf` configuration snippet.
