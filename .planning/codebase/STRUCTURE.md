# Project Structure

## Directory Layout
- `nlbw2collectd/` - Main OpenWrt package source code
  - `Makefile` - OpenWrt build and packaging instructions
  - `src/usr/share/collectd-mod-lua/nlbw2collectd.lua` - The core Lua logic for the plugin
  - `src/etc/collectd/conf.d/nlbwmon.conf` - Configuration to enable the plugin in collectd
  - `src/www/luci-static/resources/statistics/rrdtool/definitions/nlbwmon.js` - LuCI chart config
- `collectd-lua-patch/` - Contains a C patch (`999-lua_use_numbers...`) for the `collectd-mod-lua` upstream codebase to handle large counters smoothly.
- `graphics/` - Presumably project images or diagrams
- `debug/` - Debugging scripts or helpers

## Key Locations
- **Logic:** `nlbw2collectd/src/usr/share/collectd-mod-lua/nlbw2collectd.lua`
- **Packaging:** `nlbw2collectd/Makefile`
