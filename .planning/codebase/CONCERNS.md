# Concerns

## Technical Debt & Fragile Areas
- **Number vs Integer Issue (collectd-mod-lua):** There is a patch provided in the `collectd-lua-patch` directory (`999-lua_use_numbers_instead_integers_for_counters.patch`). This indicates that standard upstream `collectd-mod-lua` might suffer from counter overflow issues or improper data typing (integers instead of floating-point numbers) when handling large network traffic volumes. Deploying this plugin might require a patched version of collectd on the router, complicating standard installations.

## Missing Tooling
- **Testing:** Lack of automated testing makes it difficult to verify changes without a live OpenWrt environment.
