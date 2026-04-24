# Integrations

## Core Systems
- **nlbwmon:** Data source. The plugin fetches traffic statistics via OpenWrt's `ubus` mechanism from `nlbwmon`.
- **collectd:** Target metrics sink. The Lua script pushes data into the `collectd` daemon.
- **LuCI Statistics / RRDtool:** The JavaScript file integrates the metrics collected by collectd into the OpenWrt web UI (LuCI) for visualization.
