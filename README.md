[Instrukcja po polsku](Readme-pl.md)

# nlbw2collectd
This collectd lua plugin allows you to put [Nlbwmon](https://github.com/jow-/nlbwmon) statistics directly to Collectd (luci-app-statistics). By default on Openwrt statistics are uploaded every 30 seconds, so it allows you to get pseudo realtime statistic about the traffic on your router.

# Why this plugin has been created
I have been using [Iptmon](https://github.com/oofnikj/iptmon) tool to get very nice statistics of per host traffic on my Openwrt router. Unfortunatelly starting from Openwrt 22.03 release [Iptmon](https://github.com/oofnikj/iptmon) stopped to work due to replacement of iptables with nftables. When looking for alternatives I was not able to find anything what was close to Iptmon and working on latest Openwrt releases. I found [Nlbwmon](https://github.com/jow-/nlbwmon) to be very nice tool but what I was missing was more detailed per hour statistics with nice charts.

# Dependencies
This plugin assumes that you have Luci and luci-app-statistics installed.
Required libraries are `collectd-mod-lua` and `libubus-lua`.

# Installation instructions.
1. Make sure that you have `collectd-mod-lua` and `libubus-lua` installed on you openwrt router if not execute:
   ```
   opkg update
   opkg install collectd-mod-lua libubus-lua
   ```

2. Check if the libraries are installed:
   ```console
   # opkg list-installed | grep -E 'collectd-mod-lua|libubus-lua'
   [...]
   collectd-mod-lua - xx.yy.zzzz-zzzzz
   libubus-lua - xx.yy.zzzz-zzzzz
   ```

3. Copy [lua.conf](lua.conf) to `collectd config` directory
   ```console
   # cp lua.conf /etc/collectd/conf.d
   ```

4. Copy [nlbw2collectd.lua](nlbw2collectd.lua) to `/usr/share/collectd-mod-lua/` directory
   ```console
   # cp nlbw2collectd.lua /usr/share/collectd-mod-lua/
   ```
5. Restart collectd
   ```console
   # /etc/init.d/collectd  restart
   ```
6. Login to Luci and go to Statistics->Graphs->Firewall. After about minute you should see your statistics.

# Iptmon replacement
Starting from Openwrt 22.03 release [Iptmon](https://github.com/oofnikj/iptmon) stopped to work due to rpelacements of iptables with nftables. This plugin allows you to get the same set of statistics as Iptmon. To do this topu need to change two lines in the file nlbw2collectd.lua
In order to do this find lines below:
```
local PLUGIN_INSTANCE_RX="mangle-nlbwmon_rx" -- change to "mangle-iptmon_rx" to have full compliance with iptmon
local PLUGIN_INSTANCE_TX="mangle-nlbwmon_tx" -- change to "mangle-iptmon_tx" to have full compliance with iptmon
```
and change them to:
```
local PLUGIN_INSTANCE_RX="mangle-iptmon_rx" -- we have full compliance with iptmon
local PLUGIN_INSTANCE_TX="mangle-iptmon_tx" -- we have full compliance with iptmon
```

Make sure that Iptmon is not installed since this plugin and Iptmon can not coexist.

# Automated Builds
You can find pre-built architecture-independent (`noarch`) `.ipk` (for older OpenWrt versions) and `.apk` (for OpenWrt 25.12+) packages in the [Releases](https://github.com/mstojek/nlbw2collectd/releases) section of this repository. These packages can be installed on any OpenWrt-supported device.

# Example pictures

![RX traffic picture](graphics/Nlbwmon_rx.jpg)

![TX traffic picture](graphics/Nlbwmon_tx.jpg)

# Export to Influx DB and Grafana

By exporting data to external Influxdb/Grafana server you can get more pleasant charts. Instruction can be found at [Github](https://github.com/mstojek/gociwd)

![Grafana RX chart](graphics/Grafana_Nlbwmon_rx_chart.jpg)
![Grafana TX chart](graphics/Grafana_Nlbwmon_tx_chart.jpg)
![Grafana RX Total](graphics/Grafana_Nlbwmon_rx.jpg)
![Grafana TX Total](graphics/Grafana_Nlbwmon_tx.jpg)
