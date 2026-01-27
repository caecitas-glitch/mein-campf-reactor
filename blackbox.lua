-- Add this to your existing processCommands function
function processCommands(response)
    local text = response:upper()
    local action = ""
    
    -- SAFETY CHECK: Only SCRAM if the reactor is actually active
    if text:find("SCRAM") or text:find("SHUTDOWN") then
        if reactor.getStatus() == true then 
            reactor.scram()
            action = "\n[SYSTEM: SCRAM EXECUTED]"
        else
            action = "\n[SYSTEM: ALREADY STOPPED]"
        end

    -- FORCED OVERRIDE: Looks for "OVERRIDE" to bypass safety checks
    elseif text:find("OVERRIDE") or (text:find("ACTIVATE") and text:find("NOW")) then
        reactor.activate()
        action = "\n[SYSTEM: SAFETY OVERRIDDEN - REACTOR STARTED]"

    elseif text:find("ACTIVATE") or text:find("START") then
        -- The script itself now checks temp. If > 400K, it refuses.
        if reactor.getTemperature() > 400 then
            action = "\n[SYSTEM: START ABORTED - CORE TOO HOT ( >400K )]"
        elseif reactor.getStatus() == false then
            reactor.activate()
            action = "\n[SYSTEM: REACTOR ACTIVATED]"
        end
        
    -- NEW COOLING MODE
    elseif text:find("VENT") or text:find("COOL DOWN") then
        turbine.setDumpMode("DUMPING") -- Dumps all steam to clear heat
        action = "\n[SYSTEM: TURBINE VENTING EXCESS HEAT]"
    
    elseif text:find("NORMAL OPS") then
        turbine.setDumpMode("IDLE")
        action = "\n[SYSTEM: TURBINE RESET TO NORMAL]"
    end

    -- Burn Rate Logic
    if text:find("BURN RATE") then
        local rate = text:match("SET TO (%d+%.?%d*)")
        if rate then
            reactor.setBurnRate(tonumber(rate))
            action = action .. "\n[SYSTEM: BURN RATE " .. rate .. "]"
        end
    end

    return action
end
