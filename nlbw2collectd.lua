require "luci.jsonc"
require "luci.sys"

local HOSTNAME = '' -- leave empty if you track statistics for local system, change when you really know that you want different hostname to be used
local PLUGIN="nlbwmon" -- change to 'iptables-mangle' to have full compliance with iptmon
local PLUGIN_INSTANCE_RX="iptmon_rx"
local PLUGIN_INSTANCE_TX="iptmon_tx"
local TYPE_BYTES="ipt_bytes"
local TYPE_PACKETS="ipt_packets"
local TYPE_INSTANCE_PREFIX_RX="rx_"
local TYPE_INSTANCE_PREFIX_TX="tx_"

local function isempty(s)
  return s == nil or s == ''
end


function read()
    --collectd.log_info("read function called")
    local json = luci.sys.exec("/usr/sbin/nlbw -c json -g ip")
    --collectd.log_info("exec function called")
    local pjson = luci.jsonc.parse(json) 
    --collectd.log_info("Json: " .. json)


    for index, value in ipairs(pjson.data) do

    local ip = value[1]
    command = "nslookup " .. ip .. " | grep 'name = ' | sed -E 's/^.*name = ([a-zA-Z0-9-]+).*$/\\1/'"
    --collectd.log_info("Command: " .. command)
    local client = luci.sys.exec(command)
    local tx_bytes = value[3]
    local tx_packets = value[4]
    local rx_bytes = value[5]
    local rx_packets = value[6]

    local client = client:gsub('[%c]', '')

    if isempty(client) then
        client = ip
    end

    --collectd.log_info("ip: " .. ip .. " , client: " .. client)

        tx_b = {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_TX,
            type = TYPE_BYTES,
            type_instance =  TYPE_INSTANCE_PREFIX_TX .. client, 
            values = {tx_bytes},
        }
        collectd.dispatch_values(tx_b)

        rx_b = {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_RX,
            type = TYPE_BYTES,
            type_instance =  TYPE_INSTANCE_PREFIX_RX .. client,
            values = {rx_bytes},
        }
        collectd.dispatch_values(rx_b)



        tx_p = {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_TX,
            type = TYPE_PACKETS,
            type_instance =  TYPE_INSTANCE_PREFIX_TX .. client,
            values = {tx_packets},
        }
        collectd.dispatch_values(tx_p)

        rx_p = {
            host = HOSTNAME,
            plugin = PLUGIN,
            plugin_instance = PLUGIN_INSTANCE_RX,
            type = TYPE_PACKETS,
            type_instance =  TYPE_INSTANCE_PREFIX_RX .. client,
            values = {rx_packets},
        }
        collectd.dispatch_values(rx_p)


    end

    return 0
end

collectd.register_read(read)     -- pass function as variable

