local function rollsubtestCmd(cmd, a1, a2, ...)
    _P("Cmd: " .. cmd .. ", args: ", a1, ", ", a2);
end
Ext.RegisterConsoleCommand("rollsubtest", rollsubtestCmd);


-- Ext.Events.GameStateChanged:Subscribe(function (e)
--     _P("RollSubTest State change from " .. e.FromState .. " to " .. e.ToState)
-- end)