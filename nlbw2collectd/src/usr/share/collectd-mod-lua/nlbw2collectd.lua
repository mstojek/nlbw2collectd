-- Configuration options:
local HOSTNAME = "Testing" -- leave empty if you track statistics for local system, change when you really know that you want different hostname to be used
local PLUGIN = "nlbwmon" -- change to "iptables" to have full compliance with iptmon
local PLUGIN_INSTANCE_RX = "nlbwmon_rx" -- change to "mangle-iptmon_rx" to have full compliance with iptmon
local PLUGIN_INSTANCE_TX = "nlbwmon_tx" -- change to "mangle-iptmon_tx" to have full compliance with iptmon
local TYPE_BYTES = "ipt_bytes"
local TYPE_PACKETS = "ipt_packets"
local TYPE_INSTANCE_PREFIX_RX = "rx_"
local TYPE_INSTANCE_PREFIX_TX = "tx_"
-- End of configuration options

-- Load the necessary modules
local io = require "io"
local has_ubus, ubus_mod = pcall(require, "ubus")
local ubus = has_ubus and ubus_mod.connect()

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

-- Improved parser supporting quotes, commas, and tabs
local function parse_csv_line(line)
    local res = {}
    -- Regular expression extracting text between quotes or separated by spaces/tabs
    for v in line:gmatch('"?([^"%s,\t]+)"?') do
        table.insert(res, v)
    end
    return res
end

-- Map IP addresses to hostnames by using the getHostHints ubus procedure.
local ip_to_host = {}
local function refresh_hosts()
    if not ubus then return end
    local hosts = ubus:call("luci-rpc", "getHostHints", {}) or {}

    for mac, data in pairs(hosts) do
        local name = data.name
        if name then
            for _, ipv4 in ipairs(data.ipaddrs or {}) do
                ip_to_host[ipv4] = name
            end
            for _, ipv6 in ipairs(data.ip6addrs or {}) do
                ip_to_host[ipv6] = name
            end
        end
    end
end

-- Function to find a hostname from an IP address
local function get_hostname(ip)
    local hostname = ip_to_host[ip]

    if not hostname then
        refresh_hosts()
        hostname = ip_to_host[ip]

        if not hostname then
            local res = exec("nslookup " .. ip .. " 2>/dev/null")
            if res then
                hostname = res:match("name = ([^%s\r\n]+)")
            end

            if not hostname then
                hostname = ip
            end
            ip_to_host[ip] = hostname
        end
    end

    if hostname:match("^[0-9.]+$") or hostname:match(":") then
        return hostname
    end
    return hostname:match("^([^.]+)") or hostname
end

-- Fetch all the statistics
local function read()
    local output = exec("/usr/sbin/nlbw -c csv -g ip -n")
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

    -- Matching columns to the actual nlbw output
    local idx_ip = cols["ip"] or 1
    local idx_rx_bytes = cols["rx_bytes"] or 3
    local idx_rx_packets = cols["rx_pkts"] or 4
    local idx_tx_bytes = cols["tx_bytes"] or 5
    local idx_tx_packets = cols["tx_pkts"] or 6

    local values = {}

    for i = 2, #lines do
        local row = parse_csv_line(lines[i])
        local ip = row[idx_ip]

        if ip and ip ~= "" then
            local received_bytes = tonumber(row[idx_rx_bytes]) or 0
            local received_packets = tonumber(row[idx_rx_packets]) or 0
            local transmitted_bytes = tonumber(row[idx_tx_bytes]) or 0
            local transmitted_packets = tonumber(row[idx_tx_packets]) or 0

            local client = get_hostname(ip)

            local value = values[client] or {
                tx_bytes = 0,
                tx_packets = 0,
                rx_bytes = 0,
                rx_packets = 0
            }

            -- Summation (Received -> TX chart, Transmitted -> RX chart)
            value.tx_bytes   = value.tx_bytes   + received_bytes
            value.tx_packets = value.tx_packets + received_packets
            value.rx_bytes   = value.rx_bytes   + transmitted_bytes
            value.rx_packets = value.rx_packets + transmitted_packets

            values[client] = value
        end
    end

    -- Sending to collectd or console
    for client, value in pairs(values) do
        if collectd then
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
        else
            -- Debug for manual execution
            print(string.format("Client: %-15s | TX: %10d B | RX: %10d B", client, value.tx_bytes, value.rx_bytes))
        end
    end
end

-- Registration or test run
if collectd then
    collectd.register_read(function()
        local ok, err = pcall(read)
        if not ok then
            collectd.error("nlbw2collectd: Error: " .. tostring(err))
        end
        return 0
    end)
else
    print("--- DEBUG MODE (Manual Execution) ---")
    read()
end
