# Testing

## Framework & Structure
- No automated unit tests or continuous integration pipelines are present in the repository.

## Practices
- Testing involves manual building into an OpenWrt `.ipk` package and deploying it to a test device.
- Verification is done by verifying metrics are visible in the LuCI interface and properly stored by `rrdtool`/`collectd`.
