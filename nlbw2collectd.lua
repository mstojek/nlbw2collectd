-- Configuration options:
local HOSTNAME = "" -- leave empty if you track statistics for local system, change when you really know that you want different hostname to be used
local PLUGIN = "iptables"
local PLUGIN_INSTANCE_RX = "mangle-nlbwmon_rx" -- change to "mangle-iptmon_rx" to have full compliance with iptmon
local PLUGIN_INSTANCE_TX = "mangle-nlbwmon_tx" -- change to "mangle-iptmon_tx" to have full compliance with iptmon
local TYPE_BYTES = "ipt_bytes"
local TYPE_PACKETS = "ipt_packets"
local TYPE_INSTANCE_PREFIX_RX = "rx_"
local TYPE_INSTANCE_PREFIX_TX = "tx_"
-- End of configuration options

-- Load the necessary modules
local io     = require "io"
local ip_lib = require "luci.ip" -- Requires "luci-lib-ip" (~12kB installed)
local jsonc  = require "luci.jsonc" -- Requires "luci-lib-jsonc" (~5.1kB installed)
local ubus   = (require "ubus").connect()

-- Save some often-used global functions as local variables for a slight speed
-- boost.
local pairs, ipairs = pairs, ipairs

-- Helper function to execute a shell command and return its output
local function exec(command)
	local pp, err = io.popen(command)
    if not pp then
        collectd.error("nlbw2collectd: Failed to execute command '" ..
                       command .. "': " .. err)
        return nil
    end

	local data = pp:read("*a")
	pp:close()

	return data
end

-- IPv6 addresses can be in various formats (hex character letter case, ::
-- compression, leading zeros, etc.), so we'll normalize them here.
local function normalize_ip(ip_str)
    return ip_lib.new(ip_str):string()
end

-- Map IP addresses to hostnames by using the getHostHints ubus procedure.
local ip_to_host = {}
local function refresh_hosts()
    local hosts = ubus:call("luci-rpc", "getHostHints", {})

    for mac, data in pairs(hosts) do
        local name = data.name

        for _, ipv4 in ipairs(data.ipaddrs or {}) do
            ipv4 = normalize_ip(ipv4)
            ip_to_host[ipv4] = name
        end
        for _, ipv6 in ipairs(data.ip6addrs or {}) do
            ipv6 = normalize_ip(ipv6)
            ip_to_host[ipv6] = name
        end
    end
end

-- Function to find a hostname from an IP address
local function get_hostname(ip)
    ip = normalize_ip(ip)
    local hostname = ip_to_host[ip]

    if not hostname then
        -- Refresh the list of hosts if the MAC is not found
        refresh_hosts()
        hostname = ip_to_host[ip]
        if not hostname then
            return ip
        end
    end

    -- Extract only the hostname without domain
    return hostname:match("^([^.]+)")
end

-- Fetch all the statistics
local function read()
    local json = exec("/usr/sbin/nlbw -c json -g ip")
    local pjson = jsonc.parse(json)
    local values = {}

    -- Aggregate the values for each client
    for _, value in ipairs(pjson.data) do
        local ip = value[1]
        local tx_bytes = value[3]
        local tx_packets = value[4]
        local rx_bytes = value[5]
        local rx_packets = value[6]

        local client = get_hostname(ip)

        -- collectd only accepts a single value for each
        -- plugin_instance/type_instance, but with IPv4 and IPv6, a single host
        -- can have multiple IPs, so we'll need to sum them here.
        local value = values[client] or {
            tx_bytes = 0,
            tx_packets = 0,
            rx_bytes = 0,
            rx_packets = 0
        }

        -- collectd can only handle signed 32-bit integers, so we'll wrap any
        -- values greater than this.
        value.tx_bytes   = (value.tx_bytes   + tx_bytes  ) % 0x7fffffff
        value.rx_bytes   = (value.rx_bytes   + rx_bytes  ) % 0x7fffffff
        value.tx_packets = (value.tx_packets + tx_packets) % 0x7fffffff
        value.rx_packets = (value.rx_packets + rx_packets) % 0x7fffffff

        values[client] = value
    end

    -- Send the values to collectd
    for client, value in pairs(values) do
        collectd.dispatch_values {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_TX,
            type = TYPE_BYTES,
            type_instance =  TYPE_INSTANCE_PREFIX_TX .. client,
            values = { value.tx_bytes },
        }

        collectd.dispatch_values {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_RX,
            type = TYPE_BYTES,
            type_instance =  TYPE_INSTANCE_PREFIX_RX .. client,
            values = { value.rx_bytes },
        }

        collectd.dispatch_values {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_TX,
            type = TYPE_PACKETS,
            type_instance =  TYPE_INSTANCE_PREFIX_TX .. client,
            values = { value.tx_packets },
        }

        collectd.dispatch_values {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_RX,
            type = TYPE_PACKETS,
            type_instance =  TYPE_INSTANCE_PREFIX_RX .. client,
            values = { value.rx_packets },
        }
    end
end

-- We'll catch any errors in the read function here so that they don't propagate
-- into collectd.
collectd.register_read(function()
    local ok, err = pcall(read)
    if not ok then
        collectd.log_error("Error in read function: " .. tostring(err))
    end
    return 0
end)
