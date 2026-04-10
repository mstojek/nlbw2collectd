# nlbw2collectd
Nlbw2collectd jest pluginem Lua do Collectd który pozwala wrzucić statystyki [Nlbwmon](https://github.com/jow-/nlbwmon) do Collectd (moduł luci-app-statistics). Domyślnie statystyki sa aktualizowane co 30 sekund co pozwala otrzymac wykresy ruchu per host dla systemu Openwrt w czasie (prawie) rzeczywistym

# Dlaczego ten plugin został stworzony
Przez kilka lat używałem programu [Iptmon](https://github.com/oofnikj/iptmon) do analizy ruchu (per host) w mojej sieci. Niestety od wydania Openwrt 22.03 [Iptmon](https://github.com/oofnikj/iptmon) przestał działać ze wzgladu na zamiane Iptables na Nftables. Okazało sie jednak ze nie ma żadnej dobrej alternatywy dla [Iptmon](https://github.com/oofnikj/iptmon), dlatego wpadłem na pomysł eksportowania danych z [Nlbwmon](https://github.com/jow-/nlbwmon) do Collectd.

# Zależności
Dla poprawnego działania pluginu należy mieć zainstalowane Luci i luci-app-statistics.
Wymaganymi bibliotekami (instalowanymi automatycznie z pakietem) są `collectd`, `collectd-mod-lua`, `libubus-lua`, `nlbwmon` oraz `luci-app-statistics`.

# Instrukcja instalacji

## Opcja 1: Automatyczna instalacja (Zalecana)
Gotowe pakiety niezależne od architektury (`noarch`) znajdziesz w sekcji [Releases](https://github.com/mstojek/nlbw2collectd/releases).

### Dla OpenWrt 24.10 i starszych (.ipk)
1. Pobierz najnowszy plik `.ipk` na swój router.
2. Zainstaluj go używając `opkg`:
   ```bash
   opkg update
   opkg install nlbw2collectd_*.ipk
   ```

### Dla OpenWrt 25.12 i nowszych (.apk)
1. Pobierz najnowszy plik `.apk` na swój router.
2. Zainstaluj go używając `apk`:
   ```bash
   apk add --allow-untrusted nlbw2collectd_*.apk
   ```

Pakiet automatycznie skonfiguruje statystyki LuCI i zrestartuje wymagane usługi.

## Opcja 2: Kompilacja ze źródeł (Używając OpenWrt Feed)
Jeśli wolisz samodzielnie zbudować pakiet przy użyciu OpenWrt SDK lub Buildroot:

1. Dodaj feed do swojego pliku `feeds.conf` lub `feeds.conf.default`:
   ```text
   src-git nlbwmon_stats https://github.com/mstojek/nlbw2collectd.git
   ```

2. Zaktualizuj i zainstaluj feed:
   ```bash
   ./scripts/feeds update nlbwmon_stats
   ./scripts/feeds install -p nlbwmon_stats nlbw2collectd
   ```

3. Wybierz pakiet w `make menuconfig`:
   `Utilities` -> `nlbw2collectd`

4. Skompiluj pakiet:
   ```bash
   make package/nlbw2collectd/compile V=s
   ```

## Opcja 3: Instalacja ręczna
1. Upewnij się, że masz zainstalowane zależności:
   ```bash
   opkg update
   opkg install collectd collectd-mod-lua libubus-lua nlbwmon luci-app-statistics
   ```

2. Skopiuj [nlbw2collectd.lua](nlbw2collectd/src/usr/share/collectd-mod-lua/nlbw2collectd.lua) do katalogu `/usr/share/collectd-mod-lua/`.

3. Skopiuj [nlbwmon.conf](nlbw2collectd/src/etc/collectd/conf.d/nlbwmon.conf) do `/etc/collectd/conf.d/`.

4. Skopiuj [nlbwmon.js](nlbw2collectd/src/www/luci-static/resources/statistics/rrdtool/definitions/nlbwmon.js) do `/www/luci-static/resources/statistics/rrdtool/definitions/`.

5. Skonfiguruj LuCI, aby uwzględniało nowy katalog:
   ```bash
   uci set luci_statistics.collectd.Include='/etc/collectd/conf.d'
   uci commit luci_statistics
   ```

6. Wyczyść cache LuCI i zrestartuj usługi:
   ```bash
   rm -rf /tmp/luci-indexcache /tmp/luci-modulecache/
   /etc/init.d/luci_statistics restart
   /etc/init.d/collectd restart
   /etc/init.d/rpcd restart
   ```

7. Zaloguj się do Luci i sprawdź Statistics -> Graphs -> nlbwmon.

# Zamiennik dla Iptmon 
Od wydania Openwrt 22.03  [Iptmon](https://github.com/oofnikj/iptmon) przestał działać ze względu na zamianę iptables na nftables. Ten plugin pozwala na otrzymanie takiego samego zestawu statystyk jak Iptmon. Aby to sie stało należy zmienić trzy linie w pliku `/usr/share/collectd-mod-lua/nlbw2collectd.lua`:

Znajdujemy linijki poniżej:
```lua
local PLUGIN = "nlbwmon"
local PLUGIN_INSTANCE_RX = "nlbwmon_rx"
local PLUGIN_INSTANCE_TX = "nlbwmon_tx"
```
i zamieniamy je na:
```lua
local PLUGIN = "iptables" -- pelna zgodnosc z iptmon
local PLUGIN_INSTANCE_RX = "mangle-iptmon_rx" -- pelna zgodnosc z iptmon
local PLUGIN_INSTANCE_TX = "mangle-iptmon_tx" -- pelna zgodnosc z iptmon
```

Upewniamy się że Iptmon nie jest zainstalowany ponieważ po tej zmianie Iptmon i ten plugin nie mogą być zainstalowane jednoczesnie.

# Przykładowe wykresy

![RX traffic picture](graphics/Nlbwmon_rx.jpg)

![TX traffic picture](graphics/Nlbwmon_tx.jpg)

# Eksport statystyk do Influx DB i Grafany

Statystyki mozna wyeksportować do Influxdb/Grafany dzięki czemu można uzyskać znacznie ładniejsze wykresy. Instrukcje mozna znaleźć na [Github](https://github.com/mstojek/gociwd)

![Grafana RX chart](graphics/Grafana_Nlbwmon_rx_chart.jpg)
![Grafana TX chart](graphics/Grafana_Nlbwmon_tx_chart.jpg)
![Grafana RX Total](graphics/Grafana_Nlbwmon_rx.jpg)
![Grafana TX Total](graphics/Grafana_Nlbwmon_tx.jpg)
