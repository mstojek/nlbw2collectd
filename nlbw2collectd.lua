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

-- Map MAC addresses to hostnames by using the getHostHints ubus procedure.
local mac_to_host = {}
local function refresh_hosts()
    local hosts = ubus:call("luci-rpc", "getHostHints", {})
    if not hosts then return end

    mac_to_host = {}
    for mac, data in pairs(hosts) do
        mac_to_host[mac:upper()] = data.name
    end
end

-- Function to find a hostname from a MAC address
local function get_hostname(mac)
    local hostname = mac_to_host[mac]

    if not hostname or hostname == "" then
        return mac
    end

    -- Extract only the hostname without domain
    return hostname:match("^([^.]+)")
end

-- Fetch all the statistics
local function read()
    refresh_hosts()

    local json_output = exec("/usr/sbin/nlbw -c json -g mac")
	if not json_output or json_output == "" then return end

    local pjson = jsonc.parse(json_output)
    if not pjson or not pjson.data then return end

    local values = {}

    -- Aggregate the values for each client
    for _, value in ipairs(pjson.data) do
        local mac = value[1]:upper()
        local tx_bytes = value[3]
        local tx_packets = value[4]
        local rx_bytes = value[5]
        local rx_packets = value[6]

        local client = get_hostname(mac)

        -- collectd only accepts a single value for each
        -- plugin_instance/type_instance, but with IPv4 and IPv6, a single host
        -- can have multiple IPs, so we'll need to sum them here.
        local value = values[client] or {
            tx_bytes = 0,
            tx_packets = 0,
            rx_bytes = 0,
            rx_packets = 0
        }

        value.tx_bytes   = (value.tx_bytes   + tx_bytes  )
        value.rx_bytes   = (value.rx_bytes   + rx_bytes  )
        value.tx_packets = (value.tx_packets + tx_packets)
        value.rx_packets = (value.rx_packets + rx_packets)

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
        collectd.error("Error in read function: " .. tostring(err))
    end
    return 0
end)
