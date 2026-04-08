-- Mocking collectd for testing
collectd = {
    error = function(msg) print("COLLECTD ERROR: " .. msg) end,
    dispatch_values = function(t)
        print(string.format("DISPATCH: plugin=%s, inst=%s, type=%s, inst=%s, val=%s",
            t.plugin, t.plugin_instance, t.type, t.type_instance, t.values[1]))
    end,
    register_read = function(f) end
}

-- Mocking io.popen to return sample nlbw CSV output
local original_popen = io.popen
io.popen = function(cmd)
    if cmd:find("nlbw") then
        local f = {
            read = function()
                return [["IP","Family","Received Bytes","Received Packets","Transmitted Bytes","Transmitted Packets"
"192.168.1.10","ipv4","1000","10","5000","20"
"192.168.1.11","ipv4","2000","20","8000","40"
]]
            end,
            close = function() end
        }
        return f
    elseif cmd:find("nslookup") then
        local f = {
            read = function()
                if cmd:find("1.10") then
                    return "name = laptop.local\n"
                elseif cmd:find("1.11") then
                    return "Name:   phone\n"
                end
                return ""
            end,
            close = function() end
        }
        return f
    end
    return original_popen(cmd)
end

-- Mocking ubus
package.loaded["ubus"] = {
    connect = function()
        return {
            call = function(self, obj, method, args)
                return {} -- Simulate no DHCP hints to test nslookup fallback
            end
        }
    end
}

-- Add TEST mode export
local script_content = io.open("nlbw2collectd.lua"):read("*a")
script_content = script_content .. "\n_G.read_for_test = read\n"
local f = load(script_content)
f()

if _G.read_for_test then
    print("RUNNING READ TEST")
    _G.read_for_test()
else
    print("ERROR: read_for_test not found")
end
