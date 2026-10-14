-- Envia para cada jogador: quantos estao online e o ping dele
local function sendInfo(src, online)
    TriggerClientEvent('pvp_hud:info', src, online, GetPlayerPing(src))
end

RegisterNetEvent('pvp_hud:requestInfo', function()
    sendInfo(source, #GetPlayers())
end)

CreateThread(function()
    while true do
        Wait(Config.InfoInterval or 5000)
        local list = GetPlayers()
        local online = #list
        for _, id in ipairs(list) do
            sendInfo(tonumber(id), online)
        end
    end
end)
