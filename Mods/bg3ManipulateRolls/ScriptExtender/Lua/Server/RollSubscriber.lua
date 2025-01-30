-- RollSubscriber: code for intercepting roll events in the game (only roll events that pop up a )

-- filenames for the latest rolled value and previous (used for advantage/disadvantage)
-- relative path from %localappdata%\Larian Studios\Baldur's Gate 3\Script Extender\
local rollValPathLatest = "manualD20RollValueLatest"
local rollValPathPrev = "manualD20RollValuePrevious"


---  Console commands - Allow testing stuff
Ext.RegisterConsoleCommand("setnextd20", function(_, givenRollVal)
    if givenRollVal == nil or type(givenRollVal) ~= "string" then
        _P("roll value was not valid, give a number between 1 and 20")
        return false
    end
    -- Attempt to convert the string to a number
    local rollNum = tonumber(givenRollVal)
    if rollNum == nil or rollNum < 1 or rollNum > 20 then
        _P("roll value was not valid, give a number between 1 and 20")
        return false
    end

    -- SAVE previous roll value if applicable for use with advantage/disadvantage
    local prevRollVal = ""
    prevRollVal = Ext.IO.LoadFile(rollValPathLatest)
    if prevRollVal then
        Ext.IO.SaveFile(rollValPathPrev, prevRollVal)
    end
    
    -- put the new roll val into the file
    Ext.IO.SaveFile(rollValPathLatest, givenRollVal)
    _P("successfully set the next d20 roll to " .. givenRollVal)
    return true
end)

--- - For triggering roll window popup from console, !roll skillcheck|ability|savingthrow
Ext.RegisterConsoleCommand("roll", function(_, givenType)
    local rollTypeTable = {
        ["skillcheck"] = "Persuasion",
        ["ability"] = "Constitution",
        ["savingthrow"] = "Dexterity", -- Not sure on "SavingThrow" as rollType, don't think this works :hmm:
    }
    local givenType = givenType and givenType:lower() or "skillcheck"
    local type = givenType == "savingthrow" and "SavingThrow" or givenType == "ability" and "Ability" or "SkillCheck"
    local player = Osi.GetHostCharacter() --[[@as Guid]]
    if rollTypeTable[givenType] then
        -- "ea049218-36a8-4440-a3fc-f3019a57c86b" is DC20
        Osi.RequestActiveRoll(player, player, type, rollTypeTable[givenType], "ea049218-36a8-4440-a3fc-f3019a57c86b", 0, "")
    end
end)

Ext.RegisterConsoleCommand("rolladv", function(_, givenType)
    local rollTypeTable = {
        ["skillcheck"] = "Persuasion",
        ["ability"] = "Constitution",
        ["savingthrow"] = "Dexterity", -- Not sure on "SavingThrow" as rollType, don't think this works :hmm:
    }
    local givenType = givenType and givenType:lower() or "skillcheck"
    local type = givenType == "savingthrow" and "SavingThrow" or givenType == "ability" and "Ability" or "SkillCheck"
    local player = Osi.GetHostCharacter() --[[@as Guid]]
    if rollTypeTable[givenType] then
        -- "ea049218-36a8-4440-a3fc-f3019a57c86b" is DC20
        Osi.RequestActiveRoll(player, player, type, rollTypeTable[givenType], "ea049218-36a8-4440-a3fc-f3019a57c86b", 1, "")
    end
end)


---@param entity EntityHandle
---@param rollType string
---@param forcedRollValue integer
local function SetRoll(entity, rollType, forcedRollValue, forcedPrevRollValueAdvantage)
    -- begin defining SetRoll scoped functions
    local function updateRequestedRoll(entityUuid, rv, rva, criticalString)
        local activeRolls = Ext.Entity.GetAllEntitiesWithComponent("RequestedRoll")
        for _, r in pairs(activeRolls) do
            if r.RequestedRoll.EntityUuid == entityUuid then
                -- THIS ACTUALLY PRINTS THE FULL USERDATA in JSON
                _P('roll before')
                --_D(r:GetAllComponents())
                --_P(r.RequestedRoll.AdvantageType)

                -- prioritize bigger advantage die if applicable
                if r.RequestedRoll.AdvantageType == 1 then
                    if rva > rv then
                        r.RequestedRoll.NaturalRoll = rva
                        r.RequestedRoll.DiscardedDiceTotal = rv

                        r.RequestedRoll.Result.NaturalRoll = rva
                        r.RequestedRoll.Result.DiscardedDiceTotal = rv
                        r.RequestedRoll.Result.Total = rva + r.RequestedRoll.DiceAdditionalValue

                    else

                        r.RequestedRoll.NaturalRoll = rv
                        r.RequestedRoll.DiscardedDiceTotal = rva
                        
                        r.RequestedRoll.Result.NaturalRoll = rv
                        r.RequestedRoll.Result.DiscardedDiceTotal = rva
                        r.RequestedRoll.Result.Total = rv + r.RequestedRoll.DiceAdditionalValue
                    end
                else
                    r.RequestedRoll.NaturalRoll = rv

                    r.RequestedRoll.Result.NaturalRoll = rv
                    r.RequestedRoll.Result.Total = rv + r.RequestedRoll.DiceAdditionalValue
                end

                r.RequestedRoll.Result.Critical = criticalString
                -- presumably this takes our manipulated copy and 'overwrites' the internal game state before the roll prompt is resolved
                _P('roll after')
                --_D(r:GetAllComponents())
                r:Replicate("RequestedRoll")
            end
        end
    end
    -- (Entity e, "SkillCheckEvent" componentName, skillCheckEventTarget, roll, previousroll)
    local function handleRollEvent(e, eventComponentName, target, forcedRollValue, forcedPrevRollValueAdvantage)
        if e and e[eventComponentName] then
            local rollEvent = e[eventComponentName]

            

            local rollResult = rollEvent.ConditionRoll.Roll.Result
            local additionalValue = rollEvent.ConditionRoll.Roll.Roll.Roll.DiceAdditionalValue
            local difficulty = rollEvent.ConditionRoll.Difficulty
            local advantage = rollEvent.ConditionRoll.Roll.Roll.Advantage

            _P('rollevent BEFORE modifications')
            _D(e:GetAllComponents())
            _P(rollEvent.ConditionRoll.Roll.Result.NaturalRoll)
            _P(rollEvent.Success)
            _P('success calc ' .. rollResult.Total .. " >= " .. difficulty)
    
            local trueForcedRollValue
            if advantage then
                if forcedRollValue >= forcedPrevRollValueAdvantage then
                    trueForcedRollValue = forcedRollValue
                else
                    trueForcedRollValue = forcedPrevRollValueAdvantage
                end
            else
                trueForcedRollValue = forcedRollValue
            end

            rollResult.NaturalRoll = trueForcedRollValue
            rollResult.Total = trueForcedRollValue + additionalValue
            -- TODO check this . it seems a reroll 20 does show critical success ... why?
            -- are we ourselves marking failure somehow?
            -- rollResult.Critical = 
            -- (trueForcedRollValue == 1 and "Fail")
            -- or
            -- (trueForcedRollValue >= rollResult.CriticalThreshold) and "Success" 
            -- or "None"

            if trueForcedRollValue == 1 then
                rollResult.Critical = "Fail"
            elseif trueForcedRollValue >= difficulty then
                rollResult.Critical = "Success"
            else
                rollResult.Critical = "None"
            end
    
            -- if eventComponentName == "SkillCheckEvent" then
            --     -- skill check has .Critical field
            --     rollEvent.Critical = rollResult.Critical == "Fail" and 2 or rollResult.Critical == "Success" and 1 or 0
            -- end

            if eventComponentName == "SkillCheckEvent" then
                if rollResult.Critical == "Fail" then
                    rollEvent.Critical = 2
                elseif rollResult.Critical == "Success" then
                    rollEvent.Critical = 1
                else
                    rollEvent.Critical = 0
                end
            end

           
        
            rollEvent.Success = rollResult.Total >= difficulty

            _P('rollevent AFTER modifications')
            _D(e:GetAllComponents())
            _P(rollEvent.ConditionRoll.Roll.Result.NaturalRoll)
            _P(rollEvent.Success)
            _P('success calc ' .. rollResult.Total .. " >= " .. difficulty)

            _P('final critical values')
            _P('event')
            _P(rollEvent.Critical)
            _P('rollResult')
            _P(rollResult.Critical)

            --TODO does/can any of this be replicated and does it matter? haven't figured out how if applicable
            --e:Replicate("SkillCheckEvent")
    
            updateRequestedRoll(Ext.Entity.HandleToUuid(target), forcedRollValue, forcedPrevRollValueAdvantage, rollResult.Critical)
        end
    end
    
    local function handleAbilityRoll(entity, forcedRollValue, forcedPrevRollValueAdvantage)
        if entity and entity.AbilityCheckEvent then
            local criticalString = forcedRollValue == 1 and "Fail" or forcedRollValue == 20 and "Success" or "None"
            updateRequestedRoll(Ext.Entity.HandleToUuid(entity.AbilityCheckEvent.Target), forcedRollValue, forcedPrevRollValueAdvantage, criticalString)
        end
    end
    
    local function handleSkillCheckRoll(entity, forcedRollValue, forcedPrevRollValueAdvantage)
        if entity and entity.SkillCheckEvent then
            handleRollEvent(entity, "SkillCheckEvent", entity.SkillCheckEvent.Target, forcedRollValue, forcedPrevRollValueAdvantage)
        end
    end
    
    local function handleSavingThrowRoll(entity, forcedRollValue, forcedPrevRollValueAdvantage)
        if entity and entity.SavingThrowRolledEvent then
            handleRollEvent(entity, "SavingThrowRolledEvent", entity.SavingThrowRolledEvent.Source, forcedRollValue, forcedPrevRollValueAdvantage)
            rollOverrideInfoMap[entity.SavingThrowRolledEvent.ConditionRoll.RollUuid] = {
                ["NaturalRoll"] = forcedRollValue,
                ["Total"] = entity.SavingThrowRolledEvent.ConditionRoll.Roll.Result.Total,
                ["Critical"] = entity.SavingThrowRolledEvent.ConditionRoll.Roll.Result.Critical,
                ["Success"] = entity.SavingThrowRolledEvent.ConditionRoll.Roll.Result.Total >= entity.SavingThrowRolledEvent.ConditionRoll.Difficulty,
            }
        end
    end
    
    -- SetRoll actually continues now to use its inline functions to handle different roll usecases
    if rollType == "Ability" then
        handleAbilityRoll(entity, forcedRollValue, forcedPrevRollValueAdvantage)
    elseif rollType == "SkillCheck" then
        handleSkillCheckRoll(entity, forcedRollValue, forcedPrevRollValueAdvantage)
    -- TODO does this saving throw usecase matter?
    elseif rollType == "SavingThrow" then
        handleSavingThrowRoll(entity, forcedRollValue, forcedPrevRollValueAdvantage)
    end
end


-- try to retrieve a manual override roll values from a specified file paths
local function getOverrideRollValue()
    local rollValStr = ""
    local rollValNum

    -- Attempt to load the file
    rollValStr = Ext.IO.LoadFile(rollValPathLatest)
    if rollValStr then
        -- Attempt to convert the string to a number
        rollValNum = tonumber(rollValStr)
        if rollValNum then
            -- wipe the result so it can't be used again unless die rerolled -> new file contents were written
            Ext.IO.SaveFile(rollValPathLatest, "")
            -- Ext.IO.SaveFile(rollValPathPrev, "")
            return rollValNum -- Successfully converted to a number
        end
    end

    -- If loading or conversion fails, default to a random roll
    _P("d20 value in rollValPathLatest file not found, generating a random d20 result...")
    return math.random(1, 20)
end

local function getOverrideRollValuePrevious()
    local rollValStr = ""
    local rollValNum

    -- Attempt to load the file
    rollValStr = Ext.IO.LoadFile(rollValPathPrev)
    if rollValStr then
        -- Attempt to convert the string to a number
        rollValNum = tonumber(rollValStr)
        if rollValNum then
            -- wipe the result so it can't be used again unless die rerolled -> new file contents were written
            Ext.IO.SaveFile(rollValPathPrev, "")
            return rollValNum -- Successfully converted to a number
        end
    end

    -- If loading or conversion fails, default to a random roll
    _P("d20 value in rollValPathPrev file not found, generating a random d20 result...")
    return math.random(1, 20)
end

-- EVENT CALLBACKS ---

---@param entity EntityHandle
Ext.Entity.OnCreateDeferred("SkillCheckEvent", function(entity)
    if entity and entity.SkillCheckEvent then
        local rollVal
        local prevRollVal
        rollVal = getOverrideRollValue()
        prevRollVal = getOverrideRollValuePrevious()
        SetRoll(entity, "SkillCheck", rollVal, prevRollVal)
        _P("SkillCheckEvent, set roll to: " .. rollVal .. " previous roll was: " .. prevRollVal)
    end
end)

---@param entity EntityHandle
Ext.Entity.OnCreateDeferred("AbilityCheckEvent", function(entity)
    if entity and entity.AbilityCheckEvent then
        local rollVal
        local prevRollVal
        rollVal = getOverrideRollValue()
        prevRollVal = getOverrideRollValuePrevious()
        SetRoll(entity, "Ability", rollVal, prevRollVal)
        _P("AbilityCheckEvent, set roll to: " .. rollVal .. " previous roll was: " .. prevRollVal)
    end
end)


-- Just see if I can use an event listener and get a print when i interact with an object/npc that triggers a dialogue
---@param dialog DIALOGRESOURCE
---@param instanceID integer
-- Ext.Osiris.RegisterListener("DialogStarted", 2, "before", function (dialog, instanceID)
--     local dialogueName = dialog
--     local instanceIDue = instanceID
--     _P(dialogueName)
--     _P(instanceIDue)
-- end)

---@param dialog DIALOGRESOURCE
---@param instanceID integer
--Ext.Osiris.RegisterListener("DialogEnded", 2, "after", function (dialog, instanceID)
    --local dialogueName = dialog
    --local instanceIDue = instanceID
    --_P(dialogueName)
    --_P(instanceIDue)
--end)


-- Note - currently don't get this event
-- ---@alias OsirisDialogRollResultCallback fun(character:CHARACTER, success:integer, dialog:DIALOGRESOURCE, isDetectThoughts:integer, criticality:CRITICALITYTYPE)
Ext.Osiris.RegisterListener("DialogRollResult", 5, "before", function(character, success, dialog, isDetectThoughts, criticality)
    _P('got DialogRollResult event osi')

    local myCrit = criticality
    -- _P(myEvent)
    -- _P(myRoller)
    -- _P(mySubject)
    -- _P(myResultType)
    -- _P(isActiveRoll)
    _P(myCrit)
    
end)

-- see if i can read the roll result event
-- arity = num of params in callback = 6... eventName, roller, rollSubject, resultType, isActiveRoll, criticality
Ext.Osiris.RegisterListener("RollResult", 6, "before", function(eventName, roller, rollSubject, resultType, isActiveRoll, criticality)
    local myEvent = eventName
    local myRoller = roller
    local mySubject = rollSubject
    local myResultType = resultType
    local isActiveRoll = isActiveRoll
    local myCrit = criticality
    _P(myEvent)
    _P(myRoller)
    _P(mySubject)
    _P(myResultType)
    _P(isActiveRoll)
    _P(myCrit)
    
end)


------ MISC SNIPPETS
---------------------

-- TODO are there other die check events we need to cover??



--- unused "Saving throw" stuff
--- 
-- TODO For tracking overridden rolls, only really necessary for SavingThrows to tie into the HitResultEvents? :smooth:
---@type table<string,table<string,any>>
--local rollOverrideInfoMap = {}

-- Ext.Entity.OnCreateDeferred("SavingThrowRolledEvent", function(entity)
--     if entity and entity.SavingThrowRolledEvent then
--         SetRoll(entity, "SavingThrow", 18)
--         _P("SavingThrowRolledEvent")
--         _D(entity.SavingThrowRolledEvent)
--     end
-- end)
-- -- TODO Annoying extra step(s) for saving throws, not sure how to intercept results
-- Ext.Entity.OnCreateDeferred("HitResultEvent", function(entity)
--     if entity and entity.HitResultEvent then
--         OverrideSavingThrowHitResults(entity)
--         _P("HitResultEvent")
--         _D(entity.HitResultEvent)
--     end
-- end)
-- Ext.Entity.OnCreateDeferred("ServerSpellInterruptResults", function(entity)
--     if entity and entity.ServerSpellInterruptResults then
--         _P("ServerSpellInterruptResults")
--         _D(entity.ServerSpellInterruptResults)
--     end
-- end)



-- --- TODO works for overriding HitResults, but other things in play makes this meaningless
-- ---@param entity EntityHandle
-- local function OverrideSavingThrowHitResults(entity)
--     if entity and entity.HitResultEvent then
--         for _,conditionRoll in ipairs(entity.HitResultEvent.Hit.ConditionRolls) do
--             if rollOverrideInfoMap[conditionRoll.RollUuid] then
--                 -- TODO maybe remove info from table after using it
--                 local rollInfo = rollOverrideInfoMap[conditionRoll.RollUuid]
--                 conditionRoll.Roll.Result.NaturalRoll = rollInfo.NaturalRoll
--                 conditionRoll.Roll.Result.Total = rollInfo.Total
--                 conditionRoll.Roll.Result.Critical = rollInfo.Critical
--             end
--         end
--     end
-- end


