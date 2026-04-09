[Instrukcja po polsku](Readme-pl.md)

# nlbw2collectd
This collectd lua plugin allows you to put [Nlbwmon](https://github.com/jow-/nlbwmon) statistics directly to Collectd (luci-app-statistics). By default on Openwrt statistics are uploaded every 30 seconds, so it allows you to get pseudo realtime statistic about the traffic on your router.

# Why this plugin has been created
I have been using [Iptmon](https://github.com/oofnikj/iptmon) tool to get very nice statistics of per host traffic on my Openwrt router. Unfortunatelly starting from Openwrt 22.03 release [Iptmon](https://github.com/oofnikj/iptmon) stopped to work due to replacement of iptables with nftables. When looking for alternatives I was not able to find anything what was close to Iptmon and working on latest Openwrt releases. I found [Nlbwmon](https://github.com/jow-/nlbwmon) to be very nice tool but what I was missing was more detailed per hour statistics with nice charts.

# Dependencies
This plugin assumes that you have Luci and luci-app-statistics installed.
Required libraries (automatically installed with the package) are `collectd-mod-lua`, `libubus-lua`, and `nlbwmon`.

# Installation instructions

## Option 1: Automatic installation (Recommended)
You can find pre-built architecture-independent (`noarch`) packages in the [Releases](https://github.com/mstojek/nlbw2collectd/releases) section.

### For OpenWrt 24.10 and earlier (.ipk)
1. Download the latest `.ipk` file to your router.
2. Install it using `opkg`:
   ```bash
   opkg update
   opkg install nlbw2collectd_*.ipk
   ```

### For OpenWrt 25.12 and later (.apk)
1. Download the latest `.apk` file to your router.
2. Install it using `apk`:
   ```bash
   apk add --allow-untrusted nlbw2collectd_*.apk
   ```

The package will automatically configure LuCI statistics and restart all necessary services.

## Option 2: Manual Installation
1. Make sure that you have the dependencies installed:
   ```bash
   opkg update
   opkg install collectd-mod-lua libubus-lua nlbwmon
   ```

2. Copy [nlbw2collectd.lua](package/nlbw2collectd/files/usr/share/collectd-mod-lua/nlbw2collectd.lua) to `/usr/share/collectd-mod-lua/` directory.

3. Copy [nlbwmon.conf](package/nlbw2collectd/files/etc/collectd/conf.d/nlbwmon.conf) to `/etc/collectd/conf.d/`.

4. Copy [nlbwmon.js](package/nlbw2collectd/files/www/luci-static/resources/statistics/rrdtool/definitions/nlbwmon.js) to `/www/luci-static/resources/statistics/rrdtool/definitions/`.

5. Configure LuCI to include the new directory:
   ```bash
   uci set luci_statistics.collectd.Include='/etc/collectd/conf.d'
   uci commit luci_statistics
   ```

6. Clear LuCI cache and restart services:
   ```bash
   rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
   /etc/init.d/luci_statistics restart
   /etc/init.d/collectd restart
   /etc/init.d/rpcd restart
   ```

7. Login to Luci and go to Statistics -> Graphs -> nlbwmon.

# Iptmon replacement
Starting from Openwrt 22.03 release [Iptmon](https://github.com/oofnikj/iptmon) stopped to work due to rpelacements of iptables with nftables. This plugin allows you to get the same set of statistics as Iptmon. To do this topu need to change two lines in the file nlbw2collectd.lua
In order to do this find lines below:
```
local PLUGIN_INSTANCE_RX = "nlbwmon_rx" -- change to "mangle-iptmon_rx" to have full compliance with iptmon
local PLUGIN_INSTANCE_TX = "nlbwmon_tx" -- change to "mangle-iptmon_tx" to have full compliance with iptmon
```
and change them to:
```
local PLUGIN_INSTANCE_RX="mangle-iptmon_rx" -- we have full compliance with iptmon
local PLUGIN_INSTANCE_TX="mangle-iptmon_tx" -- we have full compliance with iptmon
```

Make sure that Iptmon is not installed since this plugin and Iptmon can not coexist.

# Example pictures

![RX traffic picture](graphics/Nlbwmon_rx.jpg)

![TX traffic picture](graphics/Nlbwmon_tx.jpg)

# Export to Influx DB and Grafana

By exporting data to external Influxdb/Grafana server you can get more pleasant charts. Instruction can be found at [Github](https://github.com/mstojek/gociwd)

![Grafana RX chart](graphics/Grafana_Nlbwmon_rx_chart.jpg)
![Grafana TX chart](graphics/Grafana_Nlbwmon_tx_chart.jpg)
![Grafana RX Total](graphics/Grafana_Nlbwmon_rx.jpg)
![Grafana TX Total](graphics/Grafana_Nlbwmon_tx.jpg)
