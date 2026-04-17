include $(TOPDIR)/rules.mk

PKG_NAME:=nlbw2collectd
PKG_VERSION:=0.0.5
PKG_RELEASE:=1
PKG_MAINTAINER:=Marek Stojek <mstojek@gmail.com>
PKG_LICENSE:=GPL-3.0-or-later

include $(INCLUDE_DIR)/package.mk

define Package/nlbw2collectd
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Nlbwmon to Collectd traffic statistics exporter
  DEPENDS:=+collectd +collectd-mod-lua +libubus-lua +nlbwmon +luci-app-statistics
  URL:=https://github.com/mstojek/nlbw2collectd
  PKGARCH:=all
endef

define Package/nlbw2collectd/description
  This plugin allows you to export nlbwmon traffic statistics directly to Collectd.
endef

define Build/Prepare
	mkdir -p $(PKG_BUILD_DIR)
	$(CP) ./src/* $(PKG_BUILD_DIR)/
endef

define Build/Compile
endef

define Package/nlbw2collectd/install
	$(INSTALL_DIR) $(1)/usr/share/collectd-mod-lua
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/usr/share/collectd-mod-lua/nlbw2collectd.lua $(1)/usr/share/collectd-mod-lua/nlbw2collectd.lua

	$(INSTALL_DIR) $(1)/etc/collectd/conf.d
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/etc/collectd/conf.d/nlbwmon.conf $(1)/etc/collectd/conf.d/nlbwmon.conf

	$(INSTALL_DIR) $(1)/www/luci-static/resources/statistics/rrdtool/definitions
	$(INSTALL_DATA) $(PKG_BUILD_DIR)/www/luci-static/resources/statistics/rrdtool/definitions/nlbwmon.js $(1)/www/luci-static/resources/statistics/rrdtool/definitions/nlbwmon.js
endef

define Package/nlbw2collectd/postinst
#!/bin/sh
# Check if we are running on the real system (not during image building)
if [ -z "$${IPKG_INSTROOT}" ]; then

    # 1. Configure luci_statistics to include our custom config directory
    uci set luci_statistics.collectd.Include='/etc/collectd/conf.d'
    uci commit luci_statistics

    # 2. Clear LuCI caches (index and modules)
    # This forces the web interface to refresh the menu structure
    rm -rf /tmp/luci-indexcache
    rm -rf /tmp/luci-modulecache/

    # 3. Restart services
    # Restart luci_statistics generation
    /etc/init.d/luci_statistics restart

    # Force reload of collectd configuration (to start collecting data immediately)
    /etc/init.d/collectd restart

    # Restart RPCD service
    # rpcd handles ACLs and menu generation in modern LuCI.
    # Without this, the new menu tab might not appear until logout/reboot.
    /etc/init.d/rpcd reload 2>/dev/null || /etc/init.d/rpcd restart
fi
endef

define Package/nlbw2collectd/postrm
#!/bin/sh
# Check if we are running on the real system
if [ -z "$${IPKG_INSTROOT}" ]; then

    # 1. Clear LuCI caches
    rm -rf /tmp/luci-indexcache
    rm -rf /tmp/luci-modulecache/

    # 2. Restart services to apply removal
    /etc/init.d/luci_statistics restart
    /etc/init.d/collectd restart
    /etc/init.d/rpcd reload 2>/dev/null || /etc/init.d/rpcd restart
fi
endef

$(eval $(call BuildPackage,nlbw2collectd))
