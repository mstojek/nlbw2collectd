-- Configuration options:
local HOSTNAME = "Testing" -- leave empty if you track statistics for local system
local PLUGIN = "nlbwmon"
local PLUGIN_INSTANCE_RX = "uplink"
local PLUGIN_INSTANCE_TX = "downlink"
local TYPE_BYTES = "ipt_bytes"
local TYPE_PACKETS = "ipt_packets"
local TYPE_INSTANCE_PREFIX_RX = ""
local TYPE_INSTANCE_PREFIX_TX = ""
-- End of configuration options

local io = require "io"
local has_ubus, ubus_mod = pcall(require, "ubus")
local ubus = has_ubus and ubus_mod.connect()

local pairs, ipairs, tonumber = pairs, ipairs, tonumber

local function exec(command)
    local pp, err = io.popen(command)
    if not pp then return nil end
    local data = pp:read("*a")
    pp:close()
    return data
end

-- Ultra-robust pure Lua CSV parser
-- Matches sequences of characters separated by commas OR whitespace.
-- Safely strips surrounding quotes.
local function parse_line(line)
    local res = {}
    for v in line:gmatch("[^%s,]+") do
        -- Strip quotes if present
        v = v:gsub('^"?(.-)"?$', '%1')
        table.insert(res, v)
    end
    return res
end

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

local function get_hostname(ip)
    local hostname = ip_to_host[ip]

    if not hostname then
        refresh_hosts()
        hostname = ip_to_host[ip]
        if not hostname then
            -- We abandoned nslookup to avoid blocking the collectd daemon.
            -- We simply return the IP address as a fallback.
            return ip
        end
    end

    if hostname:match("^[0-9.]+$") or hostname:match(":") then
        return hostname
    end
    -- Extract only the hostname without the domain
    return hostname:match("^([^.]+)") or hostname
end

local function read()
    local output = exec("/usr/sbin/nlbw -c csv -g ip -n")
    if not output or output == "" then return end

    local lines = {}
    for line in output:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end
    if #lines < 2 then return end

    local header = parse_line(lines[1])
    local cols = {}
    for i, h in ipairs(header) do
        cols[h:lower()] = i
    end

    local idx_ip = cols["ip"] or 1
    local idx_rx_bytes = cols["rx_bytes"] or 3
    local idx_rx_packets = cols["rx_pkts"] or 4
    local idx_tx_bytes = cols["tx_bytes"] or 5
    local idx_tx_packets = cols["tx_pkts"] or 6

    local values = {}

    for i = 2, #lines do
        local row = parse_line(lines[i])
        local ip = row[idx_ip]

        if ip and ip ~= "" then
            -- Convert to numbers. If nlbwmon returns an error or empty field, the result will be nil.
            local rx_b = tonumber(row[idx_rx_bytes])
            local rx_p = tonumber(row[idx_rx_packets])
            local tx_b = tonumber(row[idx_tx_bytes])
            local tx_p = tonumber(row[idx_tx_packets])

            -- Process only when all 4 values are valid numbers.
            -- Otherwise, we skip the device (Collectd will record NaN, avoiding artificial spikes).
            if rx_b and rx_p and tx_b and tx_p then
                local client = get_hostname(ip)

                local v = values[client] or {
                    tx_b = 0, tx_p = 0,
                    rx_b = 0, rx_p = 0
                }

                -- Direct 64-bit summation
                v.tx_b = v.tx_b + rx_b
                v.tx_p = v.tx_p + rx_p
                v.rx_b = v.rx_b + tx_b
                v.rx_p = v.rx_p + tx_p

                values[client] = v
            end
        end
    end

    for client, v in pairs(values) do
        if collectd then
            local c_host = HOSTNAME == "" and collectd.hostname() or HOSTNAME

            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_TX, type = TYPE_BYTES, type_instance = TYPE_INSTANCE_PREFIX_TX .. client, values = { v.tx_b } }
            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_RX, type = TYPE_BYTES, type_instance = TYPE_INSTANCE_PREFIX_RX .. client, values = { v.rx_b } }
            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_TX, type = TYPE_PACKETS, type_instance = TYPE_INSTANCE_PREFIX_TX .. client, values = { v.tx_p } }
            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_RX, type = TYPE_PACKETS, type_instance = TYPE_INSTANCE_PREFIX_RX .. client, values = { v.rx_p } }
        else
            print(string.format("Client: %-15s | TX: %10d B | RX: %10d B", client, v.tx_b, v.rx_b))
        end
    end
end

if collectd then
    collectd.register_read(function()
        local ok, err = pcall(read)
        if not ok then
            collectd.log_error("nlbw2collectd: " .. tostring(err))
        end
        return 0
    end)
else
    print("--- DEBUG MODE (Manual Execution) ---")
    read()
end
