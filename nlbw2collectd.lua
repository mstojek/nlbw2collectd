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
local io = require "io"
local has_ubus, ubus_mod = pcall(require, "ubus")
local ubus = has_ubus and ubus_mod.connect()

-- Save some often-used global functions as local variables for a slight speed
-- boost.
local pairs, ipairs, tonumber = pairs, ipairs, tonumber

-- Helper function to execute a shell command and return its output
local function exec(command)
	local pp, err = io.popen(command)
    if not pp then
        if collectd then
            collectd.error("nlbw2collectd: Failed to execute command '" ..
                           command .. "': " .. err)
        end
        return nil
    end

	local data = pp:read("*a")
	pp:close()

	return data
end

-- Simple CSV parser
local function parse_csv_line(line)
    local res = {}
    local start = 1
    while true do
        local comma = line:find(",", start)
        if not comma then
            table.insert(res, line:sub(start))
            break
        end
        table.insert(res, line:sub(start, comma - 1))
        start = comma + 1
    end
    for i, v in ipairs(res) do
        -- Remove quotes if present
        res[i] = v:gsub('^"(.*)"$', "%1")
    end
    return res
end

-- Map MAC addresses to hostnames by using the getHostHints ubus procedure.
local mac_to_host = {}
local function refresh_hosts()
    if not ubus then return end
    local hosts = ubus:call("luci-rpc", "getHostHints", {}) or {}

    for mac, data in pairs(hosts) do
        if data.name then
            mac_to_host[mac:lower()] = data.name
        end
    end
end

-- Function to find a hostname from a MAC address
local function get_hostname(mac)
    mac = mac:lower()
    local hostname = mac_to_host[mac]

    if not hostname then
        -- Refresh the list of hosts if the MAC is not found
        refresh_hosts()
        hostname = mac_to_host[mac]
        if not hostname then
            -- If still no hostname, return MAC without colons
            return mac:gsub(":", "")
        end
    end

    -- Extract only the hostname without domain
    return hostname:match("^([^.]+)")
end

-- Fetch all the statistics
local function read()
    local output = exec("/usr/sbin/nlbw -c csv -g mac -n")
	if not output or output == "" then return end
	
    local lines = {}
    for line in output:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    if #lines < 2 then return end

    local header = parse_csv_line(lines[1])
    local cols = {}
    for i, h in ipairs(header) do
        cols[h:lower()] = i
    end

    local idx_mac = cols["mac"] or 1
    local idx_rx_bytes = cols["received bytes"] or 3
    local idx_rx_packets = cols["received packets"] or 4
    local idx_tx_bytes = cols["transmitted bytes"] or 5
    local idx_tx_packets = cols["transmitted packets"] or 6
	
    local values = {}

    -- Aggregate the values for each client
    for i = 2, #lines do
        local row = parse_csv_line(lines[i])
        local mac = row[idx_mac]

        if mac and mac ~= "" and mac ~= "00:00:00:00:00:00" then
            -- Note: nlbw "Received" means traffic from client to router (Upload)
            --       nlbw "Transmitted" means traffic from router to client (Download)
            local received_bytes = tonumber(row[idx_rx_bytes]) or 0
            local received_packets = tonumber(row[idx_rx_packets]) or 0
            local transmitted_bytes = tonumber(row[idx_tx_bytes]) or 0
            local transmitted_packets = tonumber(row[idx_tx_packets]) or 0

            local client = get_hostname(mac)

            local value = values[client] or {
                tx_bytes = 0,
                tx_packets = 0,
                rx_bytes = 0,
                rx_packets = 0
            }

            -- Summing up (e.g. if multiple MACs resolve to same hostname)
            -- We keep original mapping: Received (Upload) -> TX chart, Transmitted (Download) -> RX chart
            value.tx_bytes   = value.tx_bytes   + received_bytes
            value.tx_packets = value.tx_packets + received_packets
            value.rx_bytes   = value.rx_bytes   + transmitted_bytes
            value.rx_packets = value.rx_packets + transmitted_packets

            values[client] = value
        end
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
if collectd then
    collectd.register_read(function()
        local ok, err = pcall(read)
        if not ok then
            collectd.error("nlbw2collectd: Error in read function: " .. tostring(err))
        end
        return 0
    end)
end
