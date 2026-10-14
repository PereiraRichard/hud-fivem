Config = {}

-- Topo do HUD ---------------------------------------------------------------
Config.Name = 'SUA CIDADE'     -- nome mostrado no topo (quando nao ha logo)
Config.Logo = 'img/logo.png'   -- logo (arquivo em html/img/). Use nil para mostrar so o texto
Config.LogoHeight = 40         -- altura da logo em pixels
Config.LogoPosition = 'top'    -- 'top' = no topo | 'center' = discreta no meio da tela

Config.ShowInfo = true         -- ID, jogadores online e ping (canto superior direito)
Config.InfoInterval = 5000     -- ms entre as atualizacoes de online e ping

-- ID fixo: mostra o ID do personagem (vem do pvp_creator) e ele nunca muda.
-- false = mostra o ID temporario do FiveM (muda a cada conexao)
Config.UseFixedId = true
Config.CreatorResource = 'pvp_creator'   -- nome da pasta do resource do criador de personagem

-- Canto inferior direito ------------------------------------------------------
Config.ShowStats = true        -- kills e % de headshot
Config.SpeedUnit = 'kmh'       -- 'kmh' ou 'mph'
Config.ShowFuel = false        -- true = mostra combustivel (so se o servidor tiver sistema de combustivel)

-- Kills ----------------------------------------------------------------------
-- true = o HUD conta sozinho as kills em jogadores (e o tiro na cabeca).
-- Se outro script ja conta, coloque false e chame:  exports.pvp_hud:addKill(true/false)
Config.AutoDetectKills = true
Config.SaveStats = true        -- guarda kills e headshots neste computador (continuam apos reconectar)

-- XP e nivel ------------------------------------------------------------------
-- Todo jogador novo comeca no nivel 1 com 0 de XP.
-- XP para subir do nivel N para o N+1 = XPBase + (N - 1) * XPStep
Config.XPPerKill = 25          -- XP ganho por kill
Config.XPHeadshotBonus = 10    -- XP extra quando a kill e tiro na cabeca
Config.XPBase = 100            -- XP necessario para sair do nivel 1
Config.XPStep = 50             -- quanto aumenta o XP necessario a cada nivel
Config.MaxLevel = 100          -- nivel maximo (barra fica cheia e mostra MAX)
-- Se outro script da XP, chame:  exports.pvp_hud:addXP(quantidade)

-- Teclas 1, 2, 3 e 4 pegam a arma do slot (apertar de novo guarda a arma)
Config.SlotKeys = true

-- Slots das armas: true = o HUD mostra os 4 slots escolhidos no menu de armas (F2, resource 'armas').
-- false (ou se o resource nao estiver ligado) = o HUD organiza sozinho por tipo de arma.
Config.UseArmasSlots = true
Config.ArmasResource = 'armas'   -- nome da pasta do menu de armas

-- Esconde itens nativos do GTA que o HUD ja mostra
Config.HideNativeHud = true     -- estrelas de procurado, icone de arma, dinheiro, municao
Config.HideMinimapBars = true   -- barras verde/azul de vida e colete embaixo do minimapa
Config.MinimapBig = false       -- true = radar expandido do GTA (bem grande)
Config.MinimapScale = 1.0       -- 1.0 = minimapa normal do GTA (recomendado). Acima de 1.0 e experimental e pode desalinhar

-- true = o HUD some quando o radar esta escondido (ex: durante o menu de spawn)
Config.HideWhenRadarHidden = true

-- Atalhos no centro, embaixo da tela -----------------------------------------
Config.ShowHotkeys = true
-- key     = tecla padrao (o jogador pode trocar em Configuracoes > Teclas > FiveM)
-- label   = texto mostrado no HUD
-- icon    = 'team', 'weapon', 'car' ou 'skin'
-- command = comando executado ao apertar (ex: 'times'). Use nil para so mostrar o atalho
-- event   = evento client disparado ao apertar (opcional)
Config.Hotkeys = {
    { key = 'F1', label = 'TIMES',  icon = 'team',   command = nil, event = nil },
    { key = 'F2', label = 'ARMAS',  icon = 'weapon', command = nil, event = nil },
    { key = 'F3', label = 'CARROS', icon = 'car',    command = nil, event = nil },
    { key = 'F4', label = 'SKINS',  icon = 'skin',   command = nil, event = nil },
}