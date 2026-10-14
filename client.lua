local ready = false          -- a interface (HTML) ja carregou
local lastHud = ''          -- ultimo HUD enviado (so reenvia quando muda)
local stats = { kills = 0, heads = 0, level = 1, xp = 0 }
local info = { online = 0, ping = 0 }
local hiddenBySkins = false     -- true enquanto a previa da loja de skins (pvp_skins) esta aberta

local KVP_KILLS, KVP_HEADS = 'pvp_hud:kills', 'pvp_hud:heads'
local KVP_LEVEL, KVP_XP = 'pvp_hud:level', 'pvp_hud:xp'
local HEAD_BONE = 31086     -- SKEL_Head

if Config.SaveStats then
    stats.kills = GetResourceKvpInt(KVP_KILLS)
    stats.heads = GetResourceKvpInt(KVP_HEADS)
    stats.level = math.max(1, GetResourceKvpInt(KVP_LEVEL))   -- sem save = nivel 1
    stats.xp = GetResourceKvpInt(KVP_XP)
end

-- XP necessario para sair do nivel informado (0 = ja esta no nivel maximo)
local function xpNeeded(level)
    if level >= (Config.MaxLevel or 100) then return 0 end
    return (Config.XPBase or 100) + (level - 1) * (Config.XPStep or 50)
end

local function u32(n) return n & 0xFFFFFFFF end

----------------------------------------------------------------
-- Armas: 4 slots por tipo de arma
--   1 = corpo a corpo / granadas | 2 = pistolas | 3 = SMG, escopeta, metralhadora | 4 = fuzis, snipers, pesadas
----------------------------------------------------------------
local GROUPS = {}
local function addGroup(name, slot, icon, noAmmo)
    GROUPS[u32(GetHashKey(name))] = { slot = slot, icon = icon, noAmmo = noAmmo }
end
addGroup('GROUP_MELEE',   1, 'melee', true)
addGroup('GROUP_THROWN',  1, 'grenade')
addGroup('GROUP_PISTOL',  2, 'pistol')
addGroup('GROUP_STUNGUN', 2, 'taser')
addGroup('GROUP_SMG',     3, 'smg')
addGroup('GROUP_SHOTGUN', 3, 'shotgun')
addGroup('GROUP_MG',      3, 'lmg')
addGroup('GROUP_RIFLE',   4, 'rifle')
addGroup('GROUP_SNIPER',  4, 'sniper')
addGroup('GROUP_HEAVY',   4, 'heavy')

-- armas que o HUD procura no jogador (armas fora da lista aparecem quando estao na mao)
local WEAPON_NAMES = {
    -- corpo a corpo
    'WEAPON_KNIFE', 'WEAPON_NIGHTSTICK', 'WEAPON_HAMMER', 'WEAPON_BAT', 'WEAPON_CROWBAR', 'WEAPON_GOLFCLUB',
    'WEAPON_BOTTLE', 'WEAPON_DAGGER', 'WEAPON_HATCHET', 'WEAPON_KNUCKLE', 'WEAPON_MACHETE', 'WEAPON_FLASHLIGHT',
    'WEAPON_SWITCHBLADE', 'WEAPON_POOLCUE', 'WEAPON_WRENCH', 'WEAPON_BATTLEAXE', 'WEAPON_STONE_HATCHET',
    -- pistolas
    'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL', 'WEAPON_APPISTOL', 'WEAPON_STUNGUN',
    'WEAPON_PISTOL50', 'WEAPON_SNSPISTOL', 'WEAPON_SNSPISTOL_MK2', 'WEAPON_HEAVYPISTOL', 'WEAPON_VINTAGEPISTOL',
    'WEAPON_FLAREGUN', 'WEAPON_MARKSMANPISTOL', 'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION',
    'WEAPON_CERAMICPISTOL', 'WEAPON_NAVYREVOLVER', 'WEAPON_GADGETPISTOL',
    -- submetralhadoras
    'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2', 'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW',
    'WEAPON_MACHINEPISTOL', 'WEAPON_MINISMG',
    -- escopetas
    'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN', 'WEAPON_ASSAULTSHOTGUN',
    'WEAPON_BULLPUPSHOTGUN', 'WEAPON_MUSKET', 'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN',
    'WEAPON_COMBATSHOTGUN',
    -- metralhadoras
    'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_GUSENBERG',
    -- fuzis
    'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE', 'WEAPON_CARBINERIFLE_MK2',
    'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE', 'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE',
    'WEAPON_BULLPUPRIFLE_MK2', 'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE',
    -- snipers
    'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2', 'WEAPON_MARKSMANRIFLE',
    'WEAPON_MARKSMANRIFLE_MK2',
    -- pesadas
    'WEAPON_RPG', 'WEAPON_GRENADELAUNCHER', 'WEAPON_MINIGUN', 'WEAPON_FIREWORK', 'WEAPON_RAILGUN',
    'WEAPON_HOMINGLAUNCHER', 'WEAPON_COMPACTLAUNCHER',
    -- arremessaveis
    'WEAPON_GRENADE', 'WEAPON_STICKYBOMB', 'WEAPON_SMOKEGRENADE', 'WEAPON_BZGAS', 'WEAPON_MOLOTOV',
    'WEAPON_PROXMINE', 'WEAPON_PIPEBOMB',
}

local WEAPON_HASHES = {}
for i, name in ipairs(WEAPON_NAMES) do WEAPON_HASHES[i] = GetHashKey(name) end

local UNARMED = GetHashKey('WEAPON_UNARMED')
local groupCache = {}

local function classify(hash)
    local g = groupCache[hash]
    if g == nil then
        g = GROUPS[u32(GetWeapontypeGroup(hash))] or false
        groupCache[hash] = g
    end
    return g
end

local slotsCache = { false, false, false, false }
local slotHashes = {}
local lastScan = 0

-- Slots escolhidos no menu de armas (resource 'armas'): o jogador decide o que aparece em cada slot
local function armasActive()
    return Config.UseArmasSlots ~= false and GetResourceState(Config.ArmasResource or 'armas') == 'started'
end

local function scanFromArmas(ped)
    local ok, ids = pcall(function() return exports[Config.ArmasResource or 'armas']:getSlots() end)
    if not ok or type(ids) ~= 'table' then return nil end

    local current = u32(GetSelectedPedWeapon(ped))
    local out, hashes = { false, false, false, false }, {}

    for i = 1, 4 do
        local id = ids[i]
        if id then
            local hash = GetHashKey(id)
            local g = classify(hash)
            local entry = { icon = g and g.icon or 'pistol', selected = u32(hash) == current }
            if not (g and g.noAmmo) and HasPedGotWeapon(ped, hash, false) then
                entry.ammo = GetAmmoInPedWeapon(ped, hash)
                if entry.icon ~= 'grenade' then
                    local okc, clip = GetAmmoInClip(ped, hash)
                    if okc then entry.clip = clip end
                end
            end
            out[i] = entry
            hashes[i] = hash
        end
    end
    return out, hashes
end

-- o menu de armas avisa quando os slots mudam
AddEventHandler('armas:slotsChanged', function()
    lastScan = 0
    lastHud = ''
end)

local function scanSlots(ped)
    if armasActive() then
        local out, hashes = scanFromArmas(ped)
        if out then return out, hashes end
    end

    local current = GetSelectedPedWeapon(ped)
    local out, hashes = { false, false, false, false }, {}

    local function consider(hash)
        local g = classify(hash)
        if not g then return end

        local selected = hash == current
        local cur = out[g.slot]
        -- cada slot guarda uma arma: a que esta na mao, senao a primeira encontrada
        if cur and not (selected and not cur.selected) then return end

        local entry = { icon = g.icon, selected = selected }
        if not g.noAmmo then
            entry.ammo = GetAmmoInPedWeapon(ped, hash)
            if g.icon ~= 'grenade' then
                local ok, clip = GetAmmoInClip(ped, hash)
                if ok then entry.clip = clip end
            end
        end
        out[g.slot] = entry
        hashes[g.slot] = hash
    end

    for _, hash in ipairs(WEAPON_HASHES) do
        if HasPedGotWeapon(ped, hash, false) then consider(hash) end
    end
    if current ~= UNARMED and current ~= 0 then consider(current) end

    return out, hashes
end

----------------------------------------------------------------
-- Interface (NUI)
----------------------------------------------------------------
local function sendConfig()
    SendNUIMessage({
        action = 'config',
        name = Config.Name,
        logo = Config.Logo,
        logoHeight = Config.LogoHeight,
        logoPosition = Config.LogoPosition,
        showStats = Config.ShowStats,
        hotkeys = Config.ShowHotkeys and Config.Hotkeys or {},
    })
end

-- ID mostrado no HUD: o ID fixo do personagem (pvp_creator) ou, se desligado, o ID temporario
local function currentId()
    local res = Config.CreatorResource or 'pvp_creator'
    if Config.UseFixedId == false or GetResourceState(res) ~= 'started' then
        return GetPlayerServerId(PlayerId())
    end
    local ok, character = pcall(function() return exports[res]:getCharacter() end)
    if ok and type(character) == 'table' and character.id then return character.id end
    return '--'   -- personagem ainda nao carregado
end

local function sendInfo()
    SendNUIMessage({
        action = 'info',
        show = Config.ShowInfo,
        id = currentId(),
        online = info.online,
        ping = info.ping,
    })
end

RegisterNUICallback('ready', function(_, cb)
    cb('ok')
    ready = true
    lastHud = ''
    sendConfig()
    sendInfo()
    TriggerServerEvent('pvp_hud:requestInfo')
end)

-- a loja de skins (pvp_skins) avisa quando a previa abre (true) e fecha (false)
AddEventHandler('pvp_skins:preview', function(open)
    hiddenBySkins = open and true or false
    lastHud = ''   -- atualiza o HUD agora
end)

-- o criador avisa quando o personagem carrega ou e salvo
AddEventHandler('pvp_creator:characterReady', function()
    if ready then sendInfo() end
end)

RegisterNetEvent('pvp_hud:info', function(online, ping)
    info.online, info.ping = online or 0, ping or 0
    if ready then sendInfo() end
end)

----------------------------------------------------------------
-- HUD (vida, nivel/XP, armas, velocimetro)
----------------------------------------------------------------
local function buildHud()
    local visible = not IsPauseMenuActive() and not hiddenBySkins
    if visible and Config.HideWhenRadarHidden and IsRadarHidden() then visible = false end
    if not visible then return { action = 'hud', visible = false } end

    local ped = PlayerPedId()

    -- vida em porcentagem (0 a 100)
    local maxHp = math.max(1, GetEntityMaxHealth(ped) - 100)
    local hp = math.floor(math.max(0, math.min(100, (GetEntityHealth(ped) - 100) * 100 / maxHp)) + 0.5)

    -- armas (varre a cada 250 ms para nao pesar)
    local now = GetGameTimer()
    if now - lastScan > 250 then
        lastScan = now
        slotsCache, slotHashes = scanSlots(ped)
    end

    -- porcentagem de tiros na cabeca
    local hs = 0
    if stats.kills > 0 then hs = math.floor(stats.heads * 100 / stats.kills + 0.5) end

    local hud = {
        action = 'hud', visible = true,
        health = hp,
        level = stats.level, xp = stats.xp, xpMax = xpNeeded(stats.level),
        slots = slotsCache,
        kills = stats.kills, hs = hs,
        inVeh = false,
    }

    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then
        local mph = Config.SpeedUnit == 'mph'
        hud.inVeh = true
        hud.speed = math.floor(GetEntitySpeed(veh) * (mph and 2.236936 or 3.6) + 0.5)
        hud.unit = mph and 'mph' or 'km/h'
        if Config.ShowFuel then hud.fuel = math.floor(GetVehicleFuelLevel(veh) + 0.5) end
    end

    return hud
end

CreateThread(function()
    while true do
        Wait(100)
        if ready then
            local hud = buildHud()
            local encoded = json.encode(hud)
            if encoded ~= lastHud then
                lastHud = encoded
                SendNUIMessage(hud)
            end
        end
    end
end)

----------------------------------------------------------------
-- Teclas 1 a 4: pegam a arma do slot (apertar de novo guarda)
----------------------------------------------------------------
local SLOT_CONTROLS = { 157, 158, 160, 164 }   -- teclas 1, 2, 3 e 4

CreateThread(function()
    while true do
        if Config.SlotKeys and ready then
            Wait(0)
            if not IsNuiFocused() and not IsPauseMenuActive() then
                local ped = PlayerPedId()
                for i, control in ipairs(SLOT_CONTROLS) do
                    -- desliga a troca de arma nativa do GTA nessa tecla
                    -- (ela trocava a arma logo depois e desfazia a escolha do HUD)
                    DisableControlAction(0, control, true)

                    if IsDisabledControlJustPressed(0, control) then
                        -- varre de novo na hora, para pegar arma recem dada
                        slotsCache, slotHashes = scanSlots(ped)
                        lastScan = GetGameTimer()

                        local hash = slotHashes[i]
                        if hash then
                            if GetSelectedPedWeapon(ped) == hash then
                                SetCurrentPedWeapon(ped, UNARMED, true)   -- apertar de novo guarda
                            else
                                SetCurrentPedWeapon(ped, hash, true)
                            end
                            lastHud = ''   -- atualiza o HUD agora
                        end
                    end
                end
            end
        else
            Wait(500)
        end
    end
end)

----------------------------------------------------------------
-- Itens nativos do GTA que o HUD substitui
----------------------------------------------------------------
CreateThread(function()
    while true do
        if Config.HideNativeHud then
            Wait(0)
            HideHudComponentThisFrame(1)   -- estrelas de procurado
            HideHudComponentThisFrame(2)   -- icone da arma
            HideHudComponentThisFrame(3)   -- dinheiro
            HideHudComponentThisFrame(4)   -- dinheiro (online)
            HideHudComponentThisFrame(20)  -- detalhes da arma
            DisplayAmmoThisFrame(false)
        else
            Wait(1000)
        end
    end
end)

-- Tamanho do minimapa: escala o layout padrao do GTA (16:9) a partir do canto inferior esquerdo
local function applyMinimapScale()
    local k = Config.MinimapScale or 1.0
    if Config.MinimapBig or k == 1.0 then return end
    SetMinimapComponentPosition('minimap',      'L', 'B', -0.0045 * k, -0.082 * k, 0.150 * k, 0.188888 * k)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B',  0.020  * k,  0.022 * k, 0.111 * k, 0.159    * k)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.03   * k,  0.002 * k, 0.266 * k, 0.237    * k)
end

CreateThread(function()
    local minimap = RequestScaleformMovie('minimap')
    while not HasScaleformMovieLoaded(minimap) do Wait(0) end

    applyMinimapScale()

    -- Inicia o minimapa direito: sem esse liga/desliga ele pode ficar cinza e vazio
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(Config.MinimapBig == true, false)

    while true do
        if Config.HideMinimapBars then
            Wait(0)
            BeginScaleformMovieMethod(minimap, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)   -- 3 = esconde as barras
            EndScaleformMovieMethod()
        else
            Wait(500)
        end

        -- radar expandido: so e reforcado quando voce ligou Config.MinimapBig
        if Config.MinimapBig and not IsBigmapActive() then
            SetRadarBigmapEnabled(true, false)
        end
    end
end)

----------------------------------------------------------------
-- Kills e tiro na cabeca
----------------------------------------------------------------
local function saveStats()
    if not Config.SaveStats then return end
    SetResourceKvpInt(KVP_KILLS, stats.kills)
    SetResourceKvpInt(KVP_HEADS, stats.heads)
    SetResourceKvpInt(KVP_LEVEL, stats.level)
    SetResourceKvpInt(KVP_XP, stats.xp)
end

-- Da XP ao jogador e sobe de nivel quando enche a barra
local function addXP(amount)
    amount = math.floor(tonumber(amount) or 0)
    local maxLevel = Config.MaxLevel or 100
    if amount <= 0 or stats.level >= maxLevel then return end

    stats.xp = stats.xp + amount
    local leveled = false
    while stats.level < maxLevel and stats.xp >= xpNeeded(stats.level) do
        stats.xp = stats.xp - xpNeeded(stats.level)
        stats.level = stats.level + 1
        leveled = true
    end
    if stats.level >= maxLevel then stats.xp = 0 end

    saveStats()
    lastHud = ''
    if leveled then
        SendNUIMessage({ action = 'notify', kind = 'level', title = 'NIVEL ' .. stats.level, text = 'Voce subiu de nivel!', duration = 4000 })
    end
end

RegisterNetEvent('pvp_hud:addXP', addXP)
exports('addXP', addXP)
exports('getLevel', function() return stats.level, stats.xp end)

local function addKill(headshot)
    stats.kills = stats.kills + 1
    if headshot then stats.heads = stats.heads + 1 end
    saveStats()
    addXP((Config.XPPerKill or 0) + (headshot and (Config.XPHeadshotBonus or 0) or 0))
    lastHud = ''   -- forca o HUD a atualizar
    SendNUIMessage({ action = 'kill', headshot = headshot and true or false })
end

local lastVictim, lastVictimAt = 0, 0

AddEventHandler('gameEventTriggered', function(name, args)
    if not Config.AutoDetectKills or name ~= 'CEventNetworkEntityDamage' then return end

    local victim, attacker, fatal = args[1], args[2], args[4]
    if attacker ~= PlayerPedId() or victim == attacker then return end
    if fatal ~= 1 and fatal ~= true then return end
    if not IsPedAPlayer(victim) then return end

    -- o jogo pode avisar a mesma morte mais de uma vez
    local now = GetGameTimer()
    if victim == lastVictim and now - lastVictimAt < 1500 then return end
    lastVictim, lastVictimAt = victim, now

    local ok, bone = GetPedLastDamageBone(victim)
    addKill(ok and bone == HEAD_BONE)
end)

-- para outros scripts avisarem uma kill: TriggerEvent('pvp_hud:kill', true/false)
RegisterNetEvent('pvp_hud:kill', addKill)
exports('addKill', addKill)

RegisterCommand('zerarkills', function()
    stats.kills, stats.heads = 0, 0
    saveStats()
    lastHud = ''
end, false)

RegisterCommand('zerarxp', function()
    stats.level, stats.xp = 1, 0
    saveStats()
    lastHud = ''
end, false)

----------------------------------------------------------------
-- Avisos na tela: exports.pvp_hud:notify('safe', 'Zona segura', 'Texto', 5000)
--   kind: 'safe' (verde), 'danger' (vermelho), 'warn' (amarelo) ou 'info'
----------------------------------------------------------------
local function notify(kind, title, text, duration)
    SendNUIMessage({ action = 'notify', kind = kind, title = title, text = text, duration = duration })
end

RegisterNetEvent('pvp_hud:notify', notify)
exports('notify', notify)

----------------------------------------------------------------
-- Atalhos F1 / F2 / F3 (barra embaixo, no centro)
----------------------------------------------------------------
for i, hk in ipairs(Config.Hotkeys or {}) do
    local cmd = 'pvp_hud_hk' .. i
    RegisterCommand('+' .. cmd, function()
        if not ready or IsNuiFocused() or IsPauseMenuActive() then return end
        if hk.command then ExecuteCommand(hk.command) end
        if hk.event then TriggerEvent(hk.event) end
    end, false)
    RegisterCommand('-' .. cmd, function() end, false)
    RegisterKeyMapping('+' .. cmd, 'HUD: ' .. (hk.label or ('Atalho ' .. i)), 'keyboard', hk.key or 'F1')
end

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then SetNuiFocus(false, false) end
end)