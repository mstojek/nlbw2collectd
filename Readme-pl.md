# nlbw2collectd
Nlbw2collectd jest pluginem Lua do Collectd który pozwala wrzucić statystyki [Nlbwmon](https://github.com/jow-/nlbwmon) do Collectd (moduł luci-app-statistics). Domyślnie statystyki sa aktualizowane co 30 sekund co pozwala otrzymac wykresy ruchu per host dla systemu Openwrt w czasie (prawie) rzeczywistym

# Dlaczego ten plugin został stworzony
Przez kilka lat używałem programu [Iptmon](https://github.com/oofnikj/iptmon) do analizy ruchu (per host) w mojej sieci. Niestety od wydania Openwrt 22.03 [Iptmon](https://github.com/oofnikj/iptmon) przestał działać ze wzgladu na zamiane Iptables na Nftables. Okazało sie jednak ze nie ma żadnej dobrej alternatywy dla [Iptmon](https://github.com/oofnikj/iptmon), dlatego wpadłem na pomysł eksportowania danych z [Nlbwmon](https://github.com/jow-/nlbwmon) do Collectd.

# Zależności
Dla poprawnego działania pluginu należy mieć zainstalowane Luci i luci-app-statistics.
Wymaganymi bibliotekami są `collectd-mod-lua` oraz `libubus-lua`.

# Instrukcja instalacji
1. Sprawdź czy na Openwrt są zainstalowane `collectd-mod-lua` i `libubus-lua`, jeżeli nie to wykonujemy:
   ```
   opkg update
   opkg install collectd-mod-lua libubus-lua
   ```

2. Sprawdź czy biblioteki są zainstalowane:
   ```console
   # opkg list-installed | grep -E 'collectd-mod-lua|libubus-lua'
   [...]
   collectd-mod-lua - xx.yy.zzzz-zzzzz
   libubus-lua - xx.yy.zzzz-zzzzz
   ```
   
3. Kopiujemy [lua.conf](lua.conf) do `katalogu konfiguracyjnego collectd` 
   ```
   cp lua.conf /etc/collectd/conf.d
   ```
   
4. Kopiujemy [nlbw2collectd.lua](nlbw2collectd.lua) do katalogu `/usr/share/collectd-mod-lua/`
   ```
   cp nlbw2collectd.lua /usr/share/collectd-mod-lua/
   ```
5. Restartujemy Collectd
   ```
   /etc/init.d/collectd  restart
   ```
6. Logujemy się do Luci i sprawdzamy Statistics->Graphs->Firewall. Po około minucie powinny nam sie ukazac wykresy ruchu.

# Zamiennik dla Iptmon 
Od wydania Openwrt 22.03  [Iptmon](https://github.com/oofnikj/iptmon) przestał działać ze względu na zamianę iptables na nftables. Ten plugin pozwala na otrzymanie takiego samego zestawu statystyk jak Iptmon. Aby to sie stało należy zmienic dwie linie w pliku [nlbw2collectd.lua](nlbw2collectd.lua)
Zanjdujemy linijki poniżej:
```
local PLUGIN_INSTANCE_RX="mangle-nlbwmon_rx" -- change to "mangle-iptmon_rx" to have full compliance with iptmon
local PLUGIN_INSTANCE_TX="mangle-nlbwmon_tx" -- change to "mangle-iptmon_tx" to have full compliance with iptmon
```
i zamieniamy je na:
```
local PLUGIN_INSTANCE_RX="mangle-iptmon_rx" -- we have full compliance with iptmon
local PLUGIN_INSTANCE_TX="mangle-iptmon_tx" -- we have full compliance with iptmon
```

Upewniamy się że Iptmon nie jest zainstalowany ponieważ po tej zmianie Iptmon i ten plugin nie mogą być zainstalowane jednoczesnie.

# Gotowe paczki (Automatyczne budowanie)
Możesz znaleźć gotowe pakiety `.ipk` (dla starszych wersji OpenWrt) oraz `.apk` (dla OpenWrt 25.12+) w sekcji [Releases](https://github.com/mstojek/nlbw2collectd/releases) tego repozytorium.

# Przykładowe wykresy

![RX traffic picture](graphics/Nlbwmon_rx.jpg)

![TX traffic picture](graphics/Nlbwmon_tx.jpg)

# Eksport statystyk do Influx DB i Grafany

Statystyki mozna wyeksportować do Influxdb/Grafany dzięki czemu można uzyskać znacznie ładniejsze wykresy. Instrukcje mozna znaleźć na [Github](https://github.com/mstojek/gociwd)

![Grafana RX chart](graphics/Grafana_Nlbwmon_rx_chart.jpg)
![Grafana TX chart](graphics/Grafana_Nlbwmon_tx_chart.jpg)
![Grafana RX Total](graphics/Grafana_Nlbwmon_rx.jpg)
![Grafana TX Total](graphics/Grafana_Nlbwmon_tx.jpg)

   
   
