# Conventions

## Coding Style & Patterns
- **Packaging:** Standard OpenWrt buildroot Makefile layout.
- **System Integration:**
  - `postinst` and `postrm` scripts in Makefile handle flushing LuCI cache and restarting target services (`luci_statistics`, `collectd`, `rpcd`).
- **Configuration Layout:** Adheres to the structure expected by LuCI. Custom configs go into `/etc/collectd/conf.d`.

## Error Handling
- Minimal error handling evident from the repository root; heavily relies on the OpenWrt ecosystem standards for `ubus` error codes and `collectd` daemon logging.
