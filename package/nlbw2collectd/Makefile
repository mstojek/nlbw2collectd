include $(TOPDIR)/rules.mk

PKG_NAME:=nlbw2collectd
PKG_VERSION:=1.0.1
PKG_RELEASE:=1
PKG_MAINTAINER:=Marek Stojek <mstojek@gmail.com>
PKG_LICENSE:=MIT

include $(INCLUDE_DIR)/package.mk

define Package/nlbw2collectd
  SECTION:=utils
  CATEGORY:=Utilities
  TITLE:=Nlbwmon to Collectd traffic statistics exporter
  DEPENDS:=+collectd-mod-lua +libubus-lua +nlbwmon
  URL:=https://github.com/mstojek/nlbw2collectd
  PKG_ARCH:=all
endef

define Package/nlbw2collectd/description
  This plugin allows you to export nlbwmon traffic statistics directly to Collectd.
endef

define Build/Compile
endef

define Package/nlbw2collectd/install
	$(INSTALL_DIR) $(1)/usr/share/collectd-mod-lua
	$(INSTALL_DATA) ../../nlbw2collectd.lua $(1)/usr/share/collectd-mod-lua/nlbw2collectd.lua
	$(INSTALL_DIR) $(1)/etc/collectd/conf.d
	$(INSTALL_DATA) ../../lua.conf $(1)/etc/collectd/conf.d/lua.conf
endef

$(eval $(call BuildPackage,nlbw2collectd))
