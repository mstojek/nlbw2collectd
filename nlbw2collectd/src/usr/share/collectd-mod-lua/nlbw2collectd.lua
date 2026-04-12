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

local pairs, ipairs, tonumber, type = pairs, ipairs, tonumber, type

-- Helper function to execute shell commands
local function exec(command)
    local pp, err = io.popen(command)
    if not pp then return nil end
    local data = pp:read("*a")
    pp:close()
    return data
end

-- ============================================================================
-- Embedded Pure Lua JSON Parser (Decode Only)
-- Zero dependencies required. Highly compact and optimized for nlbwmon output.
-- ============================================================================
local function json_decode(str)
    local idx = 1
    local function next_char()
        while idx <= #str do
            local c = str:sub(idx, idx)
            if not c:match("[%s\r\n\t]") then return c end
            idx = idx + 1
        end
        return nil
    end

    local parse_value, parse_object, parse_array, parse_string, parse_number

    parse_string = function()
        local res = ""
        idx = idx + 1 -- skip '"'
        while idx <= #str do
            local c = str:sub(idx, idx)
            if c == '"' then
                idx = idx + 1
                return res
            end
            if c == '\\' then
                idx = idx + 1
                c = str:sub(idx, idx)
                if c == 'n' then res = res .. '\n'
                elseif c == 't' then res = res .. '\t'
                elseif c == 'r' then res = res .. '\r'
                elseif c == '"' then res = res .. '"'
                elseif c == '\\' then res = res .. '\\'
                else res = res .. c end
            else
                res = res .. c
            end
            idx = idx + 1
        end
        error("Unterminated JSON string")
    end

    parse_number = function()
        local start = idx
        while idx <= #str do
            local c = str:sub(idx, idx)
            if not c:match("[0-9%.%-eE%+]") then break end
            idx = idx + 1
        end
        local num = tonumber(str:sub(start, idx - 1))
        if not num then error("Invalid JSON number") end
        return num
    end

    parse_object = function()
        local res = {}
        idx = idx + 1 -- skip '{'
        while true do
            local c = next_char()
            if c == '}' then idx = idx + 1; break end
            if c == ',' then idx = idx + 1; c = next_char() end
            if c ~= '"' then error("Expected string key in JSON object") end
            local key = parse_string()
            c = next_char()
            if c ~= ':' then error("Expected colon in JSON object") end
            idx = idx + 1 -- skip ':'
            res[key] = parse_value()
        end
        return res
    end

    parse_array = function()
        local res = {}
        idx = idx + 1 -- skip '['
        while true do
            local c = next_char()
            if c == ']' then idx = idx + 1; break end
            if c == ',' then idx = idx + 1; c = next_char() end
            if c == ']' then idx = idx + 1; break end
            table.insert(res, parse_value())
        end
        return res
    end

    parse_value = function()
        local c = next_char()
        if not c then return nil end
        if c == '{' then return parse_object() end
        if c == '[' then return parse_array() end
        if c == '"' then return parse_string() end
        if c == 't' then idx = idx + 4; return true end
        if c == 'f' then idx = idx + 5; return false end
        if c == 'n' then idx = idx + 4; return nil end
        return parse_number()
    end

    return parse_value()
end
-- ============================================================================

local ip_to_host = {}

-- Scans system files and UBUS to resolve IPs to Hostnames with priority logic
local function refresh_hosts()
    -- 1. Dynamic DHCP leases (Lowest Priority)
    local f_dynamic = io.open("/tmp/dhcp.leases", "r")
    if f_dynamic then
        for line in f_dynamic:lines() do
            local _, _, ip, name = line:match("^(%d+)%s+(%S+)%s+(%S+)%s+(%S+)")
            if ip and name and name ~= "*" then
                ip_to_host[ip] = name
            end
        end
        f_dynamic:close()
    end

    -- 2. Active ARP entries from UBUS (Important for IPv6 resolution)
    if ubus then
        local hosts = ubus:call("luci-rpc", "getHostHints", {}) or {}
        for mac, data in pairs(hosts) do
            local name = data.name
            if name then
                for _, ipv4 in ipairs(data.ipaddrs or {}) do ip_to_host[ipv4] = name end
                for _, ipv6 in ipairs(data.ip6addrs or {}) do ip_to_host[ipv6] = name end
            end
        end
    end

    -- 3. Static DHCP leases from LuCI (High Priority - User defined)
    local f_static = io.open("/etc/config/dhcp", "r")
    if f_static then
        local current_name, current_ip
        for line in f_static:lines() do
            if line:match("^%s*config host") then
                if current_name and current_ip then ip_to_host[current_ip] = current_name end
                current_name, current_ip = nil, nil
            else
                local n = line:match("option%s+name%s+['\"]?([^%s'\"]+)['\"]?")
                if n then current_name = n end
                local i = line:match("option%s+ip%s+['\"]?([0-9%.]+)['\"]?")
                if i then current_ip = i end
            end
        end
        if current_name and current_ip then ip_to_host[current_ip] = current_name end
        f_static:close()
    end

    -- 4. /etc/hosts file (Highest Priority - OS level)
    local f_hosts = io.open("/etc/hosts", "r")
    if f_hosts then
        for line in f_hosts:lines() do
            -- Extract IP and the first name after space/tab, ignoring comments (#)
            local ip, name = line:match("^%s*([0-9a-fA-F:%.]+)%s+([^%s#]+)")
            -- Ignore localhost loopbacks, we only care about real devices
            if ip and name and ip ~= "127.0.0.1" and ip ~= "::1" then
                ip_to_host[ip] = name
            end
        end
        f_hosts:close()
    end
end

local function get_hostname(ip)
    local hostname = ip_to_host[ip]

    if not hostname then
        refresh_hosts()
        hostname = ip_to_host[ip]
        if not hostname then
            -- Cache the failure: if the IP has no name system-wide, store the IP as the name.
            -- This prevents the script from re-parsing all files for the same unknown IP in every cycle.
            ip_to_host[ip] = ip
            return ip
        end
    end

    if hostname:match("^[0-9.]+$") or hostname:match(":") then
        return hostname
    end
    -- Return just the base hostname (e.g., "camera" instead of "camera.lan")
    return hostname:match("^([^.]+)") or hostname
end

local function read()
    -- Request JSON format from nlbwmon
    local output = exec("/usr/sbin/nlbw -c json -g ip")
    if not output or output == "" then return end

    -- Safely decode JSON
    local ok, pjson = pcall(json_decode, output)
    if not ok or type(pjson) ~= "table" or not pjson.data then
        if collectd then collectd.log_error("nlbw2collectd: Failed to parse JSON output") end
        return
    end

    -- Dynamically map column indices based on the JSON "columns" array
    local cols = {}
    if pjson.columns then
        for i, h in ipairs(pjson.columns) do
            cols[h:lower()] = i
        end
    end

    local idx_ip = cols["ip"] or 1
    local idx_rx_bytes = cols["rx_bytes"] or 3
    local idx_rx_packets = cols["rx_pkts"] or 4
    local idx_tx_bytes = cols["tx_bytes"] or 5
    local idx_tx_packets = cols["tx_pkts"] or 6

    local values = {}

    -- Process JSON data array
    for _, row in ipairs(pjson.data) do
        local ip = row[idx_ip]

        if ip and ip ~= "" then
            local rx_b = tonumber(row[idx_rx_bytes])
            local rx_p = tonumber(row[idx_rx_packets])
            local tx_b = tonumber(row[idx_tx_bytes])
            local tx_p = tonumber(row[idx_tx_packets])

            -- Skip device if any required field is missing/corrupted to prevent data spikes
            if rx_b and rx_p and tx_b and tx_p then
                local client = get_hostname(ip)

                local v = values[client] or {
                    tx_b = 0, tx_p = 0,
                    rx_b = 0, rx_p = 0
                }

                -- Direct 64-bit summation (Collectd is expected to be patched for 64-bit)
                v.tx_b = v.tx_b + rx_b
                v.tx_p = v.tx_p + rx_p
                v.rx_b = v.rx_b + tx_b
                v.rx_p = v.rx_p + tx_p

                values[client] = v
            end
        end
    end

    -- Dispatch to Collectd
    for client, v in pairs(values) do
        if collectd then
            local c_host = HOSTNAME == "" and collectd.hostname() or HOSTNAME

            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_TX, type = TYPE_BYTES, type_instance = TYPE_INSTANCE_PREFIX_TX .. client, values = { v.tx_b } }
            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_RX, type = TYPE_BYTES, type_instance = TYPE_INSTANCE_PREFIX_RX .. client, values = { v.rx_b } }
            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_TX, type = TYPE_PACKETS, type_instance = TYPE_INSTANCE_PREFIX_TX .. client, values = { v.tx_p } }
            collectd.dispatch_values { host = c_host, plugin = PLUGIN, plugin_instance = PLUGIN_INSTANCE_RX, type = TYPE_PACKETS, type_instance = TYPE_INSTANCE_PREFIX_RX .. client, values = { v.rx_p } }
        else
            -- Print using %10.0f to avoid 'bad argument' float/integer errors in Lua 5.3+
            print(string.format("Client: %-15s | TX: %10.0f B | RX: %10.0f B", client, v.tx_b, v.rx_b))
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
