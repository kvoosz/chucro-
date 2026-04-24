-- ============================================================
--  CHUCRO $! — PAINEL ROBLOX
--  Versao: v7  |  F1 para mostrar/esconder
-- ============================================================

-- [[ SERVICOS ]]
local Players            = game:GetService("Players")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local HttpService        = game:GetService("HttpService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local mouse      = player:GetMouse()

-- ============================================================
-- [[ CONFIGURACAO — AJUSTE AQUI ]]
-- ============================================================

-- Remote de pickup (igual ao seu script original)
local REMOTE_PICKUP = nil
pcall(function()
    REMOTE_PICKUP = ReplicatedStorage
        :WaitForChild("Shared", 5)
        :WaitForChild("Universe", 5)
        :WaitForChild("Network", 5)
        :WaitForChild("RemoteEvent", 5)
        :WaitForChild("Pickup", 5)
end)

local OBJECT_MODELS = workspace:FindFirstChild("ObjectModels")

-- Items disponíveis na aba Client
local ITEMS = {
    "Sword of Dawn", "Shadow Cloak", "Mana Crystal",
    "Iron Shield", "Elixir of Speed", "Fire Staff",
    "Dragon Scale", "Void Dagger",
}

-- Tiers de acesso
local TIER_CONFIG = {
    admin        = { name = "Admin",        canInfinite = true,  maxPerRequest = 999, cooldownSec = 0  },
    premium      = { name = "Premium",      canInfinite = true,  maxPerRequest = 50,  cooldownSec = 0  },
    ["semi-premium"] = { name = "Semi",     canInfinite = false, maxPerRequest = 20,  cooldownSec = 30 },
    normal       = { name = "Normal",       canInfinite = false, maxPerRequest = 10,  cooldownSec = 60 },
    client       = { name = "Client",       canInfinite = false, maxPerRequest = 10,  cooldownSec = 60 },
}

-- Chaves válidas — edite conforme necessário
-- formato: code = { level, tier, permanent, days }
local VALID_KEYS = {
    ["chucro"]       = { level = "admin",  tier = "admin",         permanent = true  },
    ["NORMAL-DEMO"]  = { level = "client", tier = "normal",        permanent = false, days = 30 },
    ["SEMI-DEMO"]    = { level = "client", tier = "semi-premium",  permanent = false, days = 30 },
    ["PREMIUM-DEMO"] = { level = "client", tier = "premium",       permanent = false, days = 30 },
}

-- Usuarios banidos (ID Roblox)
local BANNED_IDS = {}

-- Usuarios da aba Admin (simulados — adapte para RemoteFunction se quiser dados reais)
local USERS_DATA = {
    { name = "Lucas Martins",  online = true,  key = "KEY-4F9A-2X", keyExpires = "12d 4h",  keyStatus = "active"   },
    { name = "Ana Silva",      online = false, key = "KEY-8C3B-7Z", keyExpires = "2d 1h",   keyStatus = "expiring" },
}

-- Lista de banidos (persistida apenas na sessão)
local BAN_LIST = {
    { name = "Pedro Hack",   date = "23 Abr 2025", duration = "permanent", durLabel = "Permanente", reason = "Uso de cheats detectado." },
    { name = "Xpto Griefer", date = "20 Abr 2025", duration = "week",      durLabel = "1 Semana",   reason = "Comportamento abusivo."   },
}

-- ============================================================
-- [[ CORES ]]
-- ============================================================
local C = {
    bg      = Color3.fromRGB(255, 255, 255),
    surface = Color3.fromRGB(247, 247, 245),
    border  = Color3.fromRGB(17,  17,  17 ),
    text    = Color3.fromRGB(13,  13,  13 ),
    muted   = Color3.fromRGB(107, 107, 107),
    online  = Color3.fromRGB(26,  158, 92 ),
    warn    = Color3.fromRGB(217, 119, 6  ),
    danger  = Color3.fromRGB(220, 38,  38 ),
    admin   = Color3.fromRGB(124, 58,  237),
    client  = Color3.fromRGB(37,  99,  235),
    panelBg = Color3.fromRGB(240, 240, 238),
}

-- ============================================================
-- [[ ESTADO GLOBAL ]]
-- ============================================================
local sessionLevel  = nil
local sessionKey    = nil
local currentTab    = "admin"
local selectedItems = {}   -- set de nomes de items
local isInfinite    = false
local isRunning     = false
local infiniteConn  = nil
local bfAttempts    = 0
local bfLocked      = false
local bfLockUntil   = 0
local BF_MAX        = 5
local BF_LOCK_SEC   = 30
local expandedUser  = nil   -- indice do usuario expandido na aba admin
local cooldownStart = 0

-- ============================================================
-- [[ UTILITARIOS ]]
-- ============================================================

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function tweenColor(obj, prop, target, t)
    local info = TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad)
    TweenService:Create(obj, info, { [prop] = target }):Play()
end

local function makeTween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
end

-- Separa os itens a cada N chars para caber na label
local function truncate(str, max)
    if #str <= max then return str end
    return str:sub(1, max - 2) .. ".."
end

-- ============================================================
-- [[ CONSTRUTOR UI (helpers) ]]
-- ============================================================

local function newInst(class, props)
    local obj = Instance.new(class)
    for k, v in pairs(props) do
        obj[k] = v
    end
    return obj
end

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or 1.5
    s.Parent = parent
end

local function addPadding(parent, top, right, bottom, left)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, top    or 0)
    p.PaddingRight  = UDim.new(0, right  or 0)
    p.PaddingBottom = UDim.new(0, bottom or 0)
    p.PaddingLeft   = UDim.new(0, left   or 0)
    p.Parent = parent
end

local function addListLayout(parent, dir, padding, fillDir)
    local l = Instance.new("UIListLayout")
    l.FillDirection  = dir      or Enum.FillDirection.Vertical
    l.Padding        = UDim.new(0, padding or 6)
    l.SortOrder      = Enum.SortOrder.LayoutOrder
    if fillDir then l.HorizontalFillMode = Enum.UIFlexAlignment.Fill end
    l.Parent = parent
    return l
end

local function makeLabel(parent, text, size, bold, color, align, font)
    return newInst("TextLabel", {
        Parent              = parent,
        Text                = text,
        TextSize            = size or 13,
        Font                = font or (bold and Enum.Font.GothamBold or Enum.Font.Gotham),
        TextColor3          = color or C.text,
        BackgroundTransparency = 1,
        TextXAlignment      = align or Enum.TextXAlignment.Left,
        AutomaticSize       = Enum.AutomaticSize.XY,
        Size                = UDim2.new(0, 0, 0, 0),
    })
end

local function makeButton(parent, text, bg, tc, w, h, cornerR)
    local btn = newInst("TextButton", {
        Parent          = parent,
        Text            = text,
        TextSize        = 11,
        Font            = Enum.Font.GothamBold,
        TextColor3      = tc or C.text,
        BackgroundColor3= bg or C.bg,
        Size            = UDim2.new(0, w or 80, 0, h or 26),
        AutoButtonColor = false,
    })
    addCorner(btn, cornerR or 6)
    addStroke(btn, bg or C.border, 1.5)
    return btn
end

-- ============================================================
-- [[ SCREEN GUI ROOT ]]
-- ============================================================

local screenGui = newInst("ScreenGui", {
    Name          = "ChucroPanel",
    ResetOnSpawn  = false,
    ZIndexBehavior= Enum.ZIndexBehavior.Sibling,
    Parent        = (gethui and gethui()) or player:WaitForChild("PlayerGui"),
})

-- ============================================================
-- ██  KEY SCREEN
-- ============================================================

local keyScreen = newInst("Frame", {
    Name             = "KeyScreen",
    Size             = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = C.panelBg,
    BorderSizePixel  = 0,
    ZIndex           = 10,
    Parent           = screenGui,
})

-- Card central
local ksCard = newInst("Frame", {
    Size             = UDim2.new(0, 360, 0, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    Position         = UDim2.new(0.5, -180, 0.5, -120),
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
    Parent           = keyScreen,
})
addCorner(ksCard, 14)
addStroke(ksCard, C.border, 2)
addPadding(ksCard, 24, 24, 20, 24)

local ksCardLayout = addListLayout(ksCard, Enum.FillDirection.Vertical, 10)

-- Titulo
local ksBrand = newInst("TextLabel", {
    Text             = "Chucro $!",
    TextSize         = 28,
    Font             = Enum.Font.GothamBlack,
    TextColor3       = C.text,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 34),
    TextXAlignment   = Enum.TextXAlignment.Center,
    LayoutOrder      = 0,
    Parent           = ksCard,
})

local ksSub = newInst("TextLabel", {
    Text             = "Digite sua chave de acesso",
    TextSize         = 12,
    Font             = Enum.Font.Gotham,
    TextColor3       = C.muted,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 18),
    TextXAlignment   = Enum.TextXAlignment.Center,
    LayoutOrder      = 1,
    Parent           = ksCard,
})

-- Input da chave
local ksInput = newInst("TextBox", {
    PlaceholderText  = "XXXX-XXXX-XXXX",
    Text             = "",
    TextSize         = 14,
    Font             = Enum.Font.RobotoMono,
    TextColor3       = C.text,
    PlaceholderColor3= C.muted,
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
    Size             = UDim2.new(1, 0, 0, 40),
    TextXAlignment   = Enum.TextXAlignment.Center,
    ClearTextOnFocus = false,
    LayoutOrder      = 2,
    Parent           = ksCard,
})
addCorner(ksInput, 8)
local ksInputStroke = addStroke(ksInput, C.border, 2)

-- Status label
local ksStatus = newInst("TextLabel", {
    Text             = "",
    TextSize         = 11,
    Font             = Enum.Font.GothamBold,
    TextColor3       = C.danger,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 16),
    TextXAlignment   = Enum.TextXAlignment.Center,
    Visible          = false,
    LayoutOrder      = 3,
    Parent           = ksCard,
})

-- Brute force bar
local bfBarBg = newInst("Frame", {
    Size             = UDim2.new(1, 0, 0, 4),
    BackgroundColor3 = Color3.fromRGB(220, 220, 220),
    BorderSizePixel  = 0,
    Visible          = false,
    LayoutOrder      = 4,
    Parent           = ksCard,
})
addCorner(bfBarBg, 2)
local bfBar = newInst("Frame", {
    Size             = UDim2.new(0, 0, 1, 0),
    BackgroundColor3 = C.admin,
    BorderSizePixel  = 0,
    Parent           = bfBarBg,
})
addCorner(bfBar, 2)

-- Botao verificar
local ksBtn = makeButton(ksCard, "Verificar chave", C.border, C.bg, 0, 38)
ksBtn.Size       = UDim2.new(1, 0, 0, 38)
ksBtn.TextSize   = 13
ksBtn.Font       = Enum.Font.GothamBold
ksBtn.LayoutOrder= 5
addStroke(ksBtn, C.border, 2)

-- ID do jogador
local ksId = newInst("TextLabel", {
    Text             = "ID Roblox: " .. tostring(player.UserId),
    TextSize         = 10,
    Font             = Enum.Font.RobotoMono,
    TextColor3       = C.muted,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 14),
    TextXAlignment   = Enum.TextXAlignment.Center,
    LayoutOrder      = 6,
    Parent           = ksCard,
})

-- ============================================================
-- ██  MAIN UI (painel principal)
-- ============================================================

local mainUI = newInst("Frame", {
    Name             = "MainUI",
    Size             = UDim2.new(1, 0, 1, 0),
    BackgroundTransparency = 1,
    Visible          = false,
    ZIndex           = 5,
    Parent           = screenGui,
})

-- Painel arrastável
local panelOuter = newInst("Frame", {
    Name             = "PanelOuter",
    Size             = UDim2.new(0, 580, 0, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    Position         = UDim2.new(0.5, -290, 0.5, -200),
    BackgroundColor3 = C.border,
    BorderSizePixel  = 0,
    Active           = true,
    Parent           = mainUI,
})
addCorner(panelOuter, 14)

local panel = newInst("Frame", {
    Size             = UDim2.new(1, -4, 1, -4),
    Position         = UDim2.new(0, 2, 0, 2),
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
    AutomaticSize    = Enum.AutomaticSize.Y,
    ClipsDescendants = true,
    Parent           = panelOuter,
})
addCorner(panel, 12)

-- HEADER
local header = newInst("Frame", {
    Size             = UDim2.new(1, 0, 0, 46),
    BackgroundColor3 = C.surface,
    BorderSizePixel  = 0,
    Parent           = panel,
})
addStroke(header, C.border, 1)

-- Tabs container
local tabsFrame = newInst("Frame", {
    Size             = UDim2.new(0.7, 0, 1, 0),
    BackgroundTransparency = 1,
    Parent           = header,
})
addPadding(tabsFrame, 10, 0, 10, 10)
local tabsLayout = addListLayout(tabsFrame, Enum.FillDirection.Horizontal, 5)

-- Lado direito do header
local headerRight = newInst("Frame", {
    Size             = UDim2.new(0.3, -10, 1, 0),
    Position         = UDim2.new(0.7, 0, 0, 0),
    BackgroundTransparency = 1,
    Parent           = header,
})
addPadding(headerRight, 10, 10, 10, 0)

local sessionBadge = newInst("TextLabel", {
    Text             = "ADMIN",
    TextSize         = 10,
    Font             = Enum.Font.GothamBold,
    TextColor3       = C.admin,
    BackgroundColor3 = Color3.fromRGB(240, 235, 254),
    Size             = UDim2.new(0, 0, 1, 0),
    AutomaticSize    = Enum.AutomaticSize.X,
    TextXAlignment   = Enum.TextXAlignment.Center,
    Parent           = headerRight,
})
addCorner(sessionBadge, 20)
addPadding(sessionBadge, 2, 9, 2, 9)
addStroke(sessionBadge, C.admin, 1.5)

local logoutBtn = newInst("TextButton", {
    Text             = "Sair",
    TextSize         = 10,
    Font             = Enum.Font.GothamBold,
    TextColor3       = C.muted,
    BackgroundColor3 = C.bg,
    Size             = UDim2.new(0, 36, 1, 0),
    Position         = UDim2.new(1, -46, 0, 0),
    AutoButtonColor  = false,
    Parent           = headerRight,
})
addCorner(logoutBtn, 6)
addStroke(logoutBtn, Color3.fromRGB(220, 220, 220), 1.5)

-- BODY
local panelBody = newInst("ScrollingFrame", {
    Size                  = UDim2.new(1, 0, 0, 340),
    Position              = UDim2.new(0, 0, 0, 46),
    BackgroundTransparency= 1,
    BorderSizePixel       = 0,
    ScrollBarThickness    = 3,
    ScrollBarImageColor3  = Color3.fromRGB(200, 200, 200),
    CanvasSize            = UDim2.new(0, 0, 0, 0),
    AutomaticCanvasSize   = Enum.AutomaticSize.Y,
    Parent                = panel,
})
addPadding(panelBody, 14, 16, 14, 16)

-- Hint F1
local hintLabel = newInst("TextLabel", {
    Text             = "F1  mostrar / esconder",
    TextSize         = 10,
    Font             = Enum.Font.Gotham,
    TextColor3       = Color3.fromRGB(160, 160, 160),
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 16),
    Position         = UDim2.new(0, 0, 0, -18),
    TextXAlignment   = Enum.TextXAlignment.Center,
    Parent           = panelOuter,
})

-- ============================================================
-- [[ MODAIS (popup de confirmacao) ]]
-- ============================================================

-- Overlay escuro
local modalOverlay = newInst("Frame", {
    Size             = UDim2.new(1, 0, 1, 0),
    BackgroundColor3 = Color3.fromRGB(0, 0, 0),
    BackgroundTransparency = 0.5,
    ZIndex           = 20,
    Visible          = false,
    Parent           = screenGui,
})

local modalCard = newInst("Frame", {
    Size             = UDim2.new(0, 320, 0, 0),
    AutomaticSize    = Enum.AutomaticSize.Y,
    Position         = UDim2.new(0.5, -160, 0.5, -100),
    BackgroundColor3 = C.bg,
    BorderSizePixel  = 0,
    ZIndex           = 21,
    Parent           = modalOverlay,
})
addCorner(modalCard, 12)
addStroke(modalCard, C.border, 2)
addPadding(modalCard, 18, 18, 16, 18)

local modalLayout = addListLayout(modalCard, Enum.FillDirection.Vertical, 8)

local modalTitle = newInst("TextLabel", {
    Text             = "",
    TextSize         = 13,
    Font             = Enum.Font.GothamBold,
    TextColor3       = C.text,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 18),
    LayoutOrder      = 0,
    Parent           = modalCard,
})

local modalSub = newInst("TextLabel", {
    Text             = "",
    TextSize         = 11,
    Font             = Enum.Font.Gotham,
    TextColor3       = C.muted,
    BackgroundTransparency = 1,
    Size             = UDim2.new(1, 0, 0, 14),
    LayoutOrder      = 1,
    Parent           = modalCard,
})

-- Textarea de razao / mensagem
local modalInput = newInst("TextBox", {
    PlaceholderText  = "Motivo...",
    Text             = "",
    TextSize         = 12,
    Font             = Enum.Font.Gotham,
    TextColor3       = C.text,
    PlaceholderColor3= C.muted,
    BackgroundColor3 = C.surface,
    BorderSizePixel  = 0,
    MultiLine        = true,
    ClearTextOnFocus = false,
    Size             = UDim2.new(1, 0, 0, 60),
    LayoutOrder      = 2,
    TextXAlignment   = Enum.TextXAlignment.Left,
    TextYAlignment   = Enum.TextYAlignment.Top,
    Parent           = modalCard,
})
addCorner(modalInput, 7)
addStroke(modalInput, C.border, 1.5)
addPadding(modalInput, 8, 10, 8, 10)

-- Select de duracao (simulado com botoes)
local modalDurRow = newInst("Frame", {
    Size             = UDim2.new(1, 0, 0, 28),
    BackgroundTransparency = 1,
    LayoutOrder      = 3,
    Parent           = modalCard,
})
local durLayout = addListLayout(modalDurRow, Enum.FillDirection.Horizontal, 6)

local DUR_OPTIONS = { "permanent", "month", "week" }
local DUR_LABELS  = { permanent = "Permanente", month = "1 Mes", week = "1 Semana" }
local selectedDur = "permanent"
local durBtns = {}

for _, dur in ipairs(DUR_OPTIONS) do
    local isActive = dur == "permanent"
    local btn = newInst("TextButton", {
        Text             = DUR_LABELS[dur],
        TextSize         = 10,
        Font             = Enum.Font.GothamBold,
        TextColor3       = isActive and C.bg or C.muted,
        BackgroundColor3 = isActive and C.danger or C.bg,
        Size             = UDim2.new(0, 0, 1, 0),
        AutomaticSize    = Enum.AutomaticSize.X,
        AutoButtonColor  = false,
        Parent           = modalDurRow,
    })
    addCorner(btn, 5)
    addStroke(btn, C.danger, 1.5)
    addPadding(btn, 0, 8, 0, 8)
    durBtns[dur] = btn
end

-- Botoes OK / Cancelar
local modalFooter = newInst("Frame", {
    Size             = UDim2.new(1, 0, 0, 32),
    BackgroundTransparency = 1,
    LayoutOrder      = 4,
    Parent           = modalCard,
})
addListLayout(modalFooter, Enum.FillDirection.Horizontal, 8)

local modalCancelBtn = makeButton(modalFooter, "Cancelar", C.bg, C.muted, 0, 32)
modalCancelBtn.Size = UDim2.new(0.5, -4, 1, 0)
addStroke(modalCancelBtn, Color3.fromRGB(210, 210, 210), 1.5)

local modalConfirmBtn = makeButton(modalFooter, "Confirmar", C.danger, C.bg, 0, 32)
modalConfirmBtn.Size = UDim2.new(0.5, -4, 1, 0)

local activeModal = nil   -- "ban" | "warn" | "revoke" | "extend" | "newkey"
local activeModalIdx = nil

local function openModal(kind, idx)
    activeModal = kind
    activeModalIdx = idx
    modalOverlay.Visible = true
    modalInput.Text = ""

    if kind == "ban" then
        local u = USERS_DATA[idx]
        modalTitle.Text   = "Banir — " .. (u and u.name or "?")
        modalSub.Text     = "Informe o motivo e a duracao do ban."
        modalInput.PlaceholderText = "Motivo..."
        modalInput.Visible = true
        modalDurRow.Visible= true
        selectedDur = "permanent"
        for d, b in pairs(durBtns) do
            b.BackgroundColor3 = d == "permanent" and C.danger or C.bg
            b.TextColor3       = d == "permanent" and C.bg or C.muted
        end
        modalConfirmBtn.BackgroundColor3 = C.danger
        addStroke(modalConfirmBtn, C.danger, 1.5)
        modalConfirmBtn.Text = "Banir"

    elseif kind == "warn" then
        local u = USERS_DATA[idx]
        modalTitle.Text    = "Aviso — " .. (u and u.name or "?")
        modalSub.Text      = "Digite a mensagem de aviso."
        modalInput.PlaceholderText = "Mensagem..."
        modalInput.Visible  = true
        modalDurRow.Visible = false
        modalConfirmBtn.BackgroundColor3 = C.warn
        addStroke(modalConfirmBtn, C.warn, 1.5)
        modalConfirmBtn.Text = "Enviar"

    elseif kind == "revoke" then
        local u = USERS_DATA[idx]
        modalTitle.Text    = "Revogar chave — " .. (u and u.name or "?")
        modalSub.Text      = "A chave sera desativada imediatamente."
        modalInput.Visible  = false
        modalDurRow.Visible = false
        modalConfirmBtn.BackgroundColor3 = C.border
        addStroke(modalConfirmBtn, C.border, 1.5)
        modalConfirmBtn.Text = "Revogar"

    elseif kind == "extend" then
        local key = idx  -- idx e o codigo da chave
        modalTitle.Text    = "Adicionar tempo — " .. tostring(key)
        modalSub.Text      = "Escolha o tempo extra."
        modalInput.Visible  = false
        modalDurRow.Visible = false
        modalConfirmBtn.BackgroundColor3 = C.online
        addStroke(modalConfirmBtn, C.online, 1.5)
        modalConfirmBtn.Text = "Confirmar"

    elseif kind == "newkey" then
        modalTitle.Text    = "Gerar nova chave"
        modalSub.Text      = "Deixe em branco para gerar codigo automatico."
        modalInput.PlaceholderText = "Codigo personalizado (opcional)"
        modalInput.Visible  = true
        modalDurRow.Visible = false
        modalConfirmBtn.BackgroundColor3 = C.admin
        addStroke(modalConfirmBtn, C.admin, 1.5)
        modalConfirmBtn.Text = "Gerar"
    end
end

local function closeModal()
    modalOverlay.Visible = false
    activeModal = nil
    activeModalIdx = nil
end

-- ============================================================
-- [[ CONSTRUCAO DAS ABAS ]]
-- ============================================================

-- Referencia para os botoes de tabs gerados dinamicamente
local tabButtons = {}

local function clearBody()
    for _, c in ipairs(panelBody:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then
            c:Destroy()
        end
    end
end

local function setBodyLayout()
    -- remove layout anterior se existir
    local existing = panelBody:FindFirstChildOfClass("UIListLayout")
    if not existing then
        addListLayout(panelBody, Enum.FillDirection.Vertical, 8)
    end
end

-- ── SECAO LABEL ──
local function sectionLabel(parent, text, order)
    local lbl = newInst("TextLabel", {
        Text             = text:upper(),
        TextSize         = 10,
        Font             = Enum.Font.GothamBold,
        TextColor3       = C.muted,
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, 0, 0, 14),
        LayoutOrder      = order or 0,
        Parent           = parent,
    })
    return lbl
end

-- ── DIVIDER ──
local function divider(parent, order)
    local d = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 1),
        BackgroundColor3 = C.border,
        BackgroundTransparency = 0.88,
        BorderSizePixel  = 0,
        LayoutOrder      = order or 99,
        Parent           = parent,
    })
    return d
end

-- ============================================================
-- ██  ABA ADMIN
-- ============================================================

local function buildAdminTab()
    clearBody()
    setBodyLayout()
    local order = 0

    sectionLabel(panelBody, "Ultimo acesso", order) ; order = order + 1

    for i, u in ipairs(USERS_DATA) do
        local isExpanded = (expandedUser == i)

        -- Card do usuario
        local card = newInst("Frame", {
            Size             = UDim2.new(1, 0, 0, 56),
            BackgroundColor3 = C.bg,
            BorderSizePixel  = 0,
            LayoutOrder      = order,
            Parent           = panelBody,
        })
        order = order + 1
        addCorner(card, 10)
        addStroke(card, C.border, 1.5)

        -- Avatar circulo
        local av = newInst("Frame", {
            Size             = UDim2.new(0, 38, 0, 38),
            Position         = UDim2.new(0, 10, 0.5, -19),
            BackgroundColor3 = C.surface,
            BorderSizePixel  = 0,
            Parent           = card,
        })
        addCorner(av, 19)
        addStroke(av, u.online and C.online or C.border, 2)
        local initials = ""
        for word in u.name:gmatch("%S+") do
            initials = initials .. word:sub(1,1)
            if #initials >= 2 then break end
        end
        newInst("TextLabel", {
            Text             = initials,
            TextSize         = 13,
            Font             = Enum.Font.GothamBold,
            TextColor3       = C.text,
            BackgroundTransparency = 1,
            Size             = UDim2.new(1, 0, 1, 0),
            TextXAlignment   = Enum.TextXAlignment.Center,
            Parent           = av,
        })

        -- Nome e meta
        newInst("TextLabel", {
            Text             = u.name,
            TextSize         = 13,
            Font             = Enum.Font.GothamBold,
            TextColor3       = C.text,
            BackgroundTransparency = 1,
            Size             = UDim2.new(0, 260, 0, 20),
            Position         = UDim2.new(0, 58, 0, 9),
            TextXAlignment   = Enum.TextXAlignment.Left,
            Parent           = card,
        })
        newInst("TextLabel", {
            Text             = u.online and "Online agora" or "Offline",
            TextSize         = 10,
            Font             = Enum.Font.Gotham,
            TextColor3       = u.online and C.online or C.muted,
            BackgroundTransparency = 1,
            Size             = UDim2.new(0, 200, 0, 14),
            Position         = UDim2.new(0, 58, 0, 30),
            TextXAlignment   = Enum.TextXAlignment.Left,
            Parent           = card,
        })

        -- Badge online/offline
        local badge = newInst("TextLabel", {
            Text             = u.online and "Online" or "Offline",
            TextSize         = 9,
            Font             = Enum.Font.GothamBold,
            TextColor3       = u.online and C.online or C.muted,
            BackgroundColor3 = u.online and Color3.fromRGB(230, 253, 242) or C.surface,
            Size             = UDim2.new(0, 0, 0, 20),
            AutomaticSize    = Enum.AutomaticSize.X,
            Position         = UDim2.new(1, -90, 0.5, -10),
            TextXAlignment   = Enum.TextXAlignment.Center,
            Parent           = card,
        })
        addCorner(badge, 20)
        addStroke(badge, u.online and C.online or Color3.fromRGB(200,200,200), 1.5)
        addPadding(badge, 2, 8, 2, 8)

        -- Painel expandido (acoes)
        if isExpanded then
            local exp = newInst("Frame", {
                Size             = UDim2.new(1, 0, 0, 0),
                AutomaticSize    = Enum.AutomaticSize.Y,
                BackgroundColor3 = Color3.fromRGB(250, 250, 249),
                BorderSizePixel  = 0,
                LayoutOrder      = order,
                Parent           = panelBody,
            })
            order = order + 1
            addCorner(exp, 10)
            addStroke(exp, C.border, 1.5)
            addPadding(exp, 12, 14, 12, 14)
            local expLayout = addListLayout(exp, Enum.FillDirection.Vertical, 6)

            local function expRow(label, value, color)
                local row = newInst("Frame", {
                    Size             = UDim2.new(1, 0, 0, 18),
                    BackgroundTransparency = 1,
                    Parent           = exp,
                })
                newInst("TextLabel", {
                    Text             = label,
                    TextSize         = 11,
                    Font             = Enum.Font.GothamBold,
                    TextColor3       = C.muted,
                    BackgroundTransparency = 1,
                    Size             = UDim2.new(0.5, 0, 1, 0),
                    TextXAlignment   = Enum.TextXAlignment.Left,
                    Parent           = row,
                })
                newInst("TextLabel", {
                    Text             = value,
                    TextSize         = 11,
                    Font             = Enum.Font.GothamBold,
                    TextColor3       = color or C.text,
                    BackgroundTransparency = 1,
                    Size             = UDim2.new(0.5, 0, 1, 0),
                    Position         = UDim2.new(0.5, 0, 0, 0),
                    TextXAlignment   = Enum.TextXAlignment.Right,
                    Parent           = row,
                })
            end

            expRow("Chave ativa", u.key)
            expRow("Expira em",   u.keyExpires, u.keyStatus == "expiring" and C.warn or C.online)
            expRow("Status",      u.keyStatus == "active" and "Ativa" or "Expirando",
                   u.keyStatus == "active" and C.online or C.warn)

            divider(exp)

            -- Botoes de acao
            local actRow = newInst("Frame", {
                Size             = UDim2.new(1, 0, 0, 30),
                BackgroundTransparency = 1,
                Parent           = exp,
            })
            addListLayout(actRow, Enum.FillDirection.Horizontal, 6)

            local banBtn    = makeButton(actRow, "Ban",    C.bg, C.danger, 0, 30) ; banBtn.Size = UDim2.new(0.33, -4, 1, 0) ; addStroke(banBtn, C.danger, 1.5)
            local warnBtn   = makeButton(actRow, "Aviso",  C.bg, C.warn,   0, 30) ; warnBtn.Size= UDim2.new(0.33, -4, 1, 0) ; addStroke(warnBtn, C.warn, 1.5)
            local revokeBtn = makeButton(actRow, "Revogar",C.bg, C.text,   0, 30) ; revokeBtn.Size= UDim2.new(0.34, -4, 1, 0) ; addStroke(revokeBtn, C.border, 1.5)

            local ci = i
            banBtn.MouseButton1Click:Connect(function()    openModal("ban",    ci) end)
            warnBtn.MouseButton1Click:Connect(function()   openModal("warn",   ci) end)
            revokeBtn.MouseButton1Click:Connect(function() openModal("revoke", ci) end)
        end

        -- Clique no card para expandir/recolher
        local ci = i
        card.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                expandedUser = (expandedUser == ci) and nil or ci
                buildAdminTab()
            end
        end)
    end

    divider(panelBody, order) ; order = order + 1
    sectionLabel(panelBody, "Resumo", order) ; order = order + 1

    -- Metricas
    local metricRow = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 56),
        BackgroundTransparency = 1,
        LayoutOrder      = order,
        Parent           = panelBody,
    })
    addListLayout(metricRow, Enum.FillDirection.Horizontal, 8)

    local onlineCount = 0
    for _, u in ipairs(USERS_DATA) do if u.online then onlineCount = onlineCount + 1 end end

    local function metricCard(label, value, color)
        local mc = newInst("Frame", {
            Size             = UDim2.new(0.33, -6, 1, 0),
            BackgroundColor3 = C.surface,
            BorderSizePixel  = 0,
            Parent           = metricRow,
        })
        addCorner(mc, 9)
        addStroke(mc, C.border, 1.5)
        addPadding(mc, 10, 12, 10, 12)
        addListLayout(mc, Enum.FillDirection.Vertical, 2)
        newInst("TextLabel", {
            Text             = label:upper(),
            TextSize         = 9,
            Font             = Enum.Font.GothamBold,
            TextColor3       = C.muted,
            BackgroundTransparency = 1,
            Size             = UDim2.new(1, 0, 0, 12),
            Parent           = mc,
        })
        newInst("TextLabel", {
            Text             = tostring(value),
            TextSize         = 22,
            Font             = Enum.Font.GothamBlack,
            TextColor3       = color or C.text,
            BackgroundTransparency = 1,
            Size             = UDim2.new(1, 0, 0, 28),
            Parent           = mc,
        })
    end

    metricCard("Sessoes", #USERS_DATA, C.text)
    metricCard("Online",  onlineCount, C.online)
    metricCard("Offline", #USERS_DATA - onlineCount, C.muted)
end

-- ============================================================
-- ██  ABA CLIENT
-- ============================================================

local itemBtns = {}   -- referencia para atualizar visual

local function buildClientTab()
    clearBody()
    setBodyLayout()

    local tier       = (sessionKey and (sessionKey.tier or sessionKey.level)) or "normal"
    local tierCfg    = TIER_CONFIG[tier] or TIER_CONFIG.normal
    local onCooldown = tierCfg.cooldownSec > 0 and (os.time() - cooldownStart) < tierCfg.cooldownSec
    local coolLeft   = onCooldown and (tierCfg.cooldownSec - (os.time() - cooldownStart)) or 0

    -- Badge de tier
    local tierColors = {
        admin = C.admin, premium = C.online,
        ["semi-premium"] = C.warn, normal = C.muted, client = C.muted,
    }
    local tc = tierColors[tier] or C.muted

    local topRow = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 22),
        BackgroundTransparency = 1,
        LayoutOrder      = 0,
        Parent           = panelBody,
    })
    local tierBadge = newInst("TextLabel", {
        Text             = tierCfg.name:upper(),
        TextSize         = 10,
        Font             = Enum.Font.GothamBold,
        TextColor3       = tc,
        BackgroundColor3 = C.bg,
        Size             = UDim2.new(0, 0, 1, 0),
        AutomaticSize    = Enum.AutomaticSize.X,
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = topRow,
    })
    addCorner(tierBadge, 20) ; addStroke(tierBadge, tc, 1.5) ; addPadding(tierBadge, 2, 8, 2, 8)

    if onCooldown then
        newInst("TextLabel", {
            Text     = ("⏳ Cooldown: %ds"):format(math.ceil(coolLeft)),
            TextSize = 10,
            Font     = Enum.Font.GothamBold,
            TextColor3 = C.warn,
            BackgroundTransparency = 1,
            Size     = UDim2.new(0, 140, 1, 0),
            Position = UDim2.new(1, -140, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Right,
            Parent   = topRow,
        })
    end

    -- Layout de duas colunas
    local cols = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 200),
        BackgroundTransparency = 1,
        LayoutOrder      = 1,
        Parent           = panelBody,
    })

    -- Coluna esquerda: lista de items
    local listCol = newInst("ScrollingFrame", {
        Size                  = UDim2.new(0.62, -6, 1, 0),
        BackgroundColor3      = C.bg,
        BorderSizePixel       = 0,
        ScrollBarThickness    = 3,
        ScrollBarImageColor3  = Color3.fromRGB(200,200,200),
        CanvasSize            = UDim2.new(0,0,0,0),
        AutomaticCanvasSize   = Enum.AutomaticSize.Y,
        Parent                = cols,
    })
    addCorner(listCol, 9) ; addStroke(listCol, C.border, 1.5)
    local listLayout2 = addListLayout(listCol, Enum.FillDirection.Vertical, 0)
    listLayout2.Padding = UDim.new(0, 0)

    itemBtns = {}
    for idx, itemName in ipairs(ITEMS) do
        local isSelected = selectedItems[itemName] == true
        local row = newInst("TextButton", {
            Text             = "  " .. itemName,
            TextSize         = 12,
            Font             = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham,
            TextColor3       = isSelected and C.text or C.muted,
            BackgroundColor3 = isSelected and Color3.fromRGB(240,240,240) or C.bg,
            Size             = UDim2.new(1, 0, 0, 34),
            TextXAlignment   = Enum.TextXAlignment.Left,
            AutoButtonColor  = false,
            Parent           = listCol,
        })

        -- Separador
        if idx < #ITEMS then
            newInst("Frame", {
                Size = UDim2.new(1, 0, 0, 1),
                BackgroundColor3 = Color3.fromRGB(235,235,235),
                BorderSizePixel = 0,
                Parent = row,
                Position = UDim2.new(0,0,1,-1),
                ZIndex = 2,
            })
        end

        -- Checkmark
        local ck = newInst("Frame", {
            Size             = UDim2.new(0, 14, 0, 14),
            Position         = UDim2.new(1, -24, 0.5, -7),
            BackgroundColor3 = isSelected and C.border or C.bg,
            BorderSizePixel  = 0,
            Parent           = row,
        })
        addCorner(ck, 3)
        addStroke(ck, isSelected and C.border or Color3.fromRGB(190,190,190), 1.5)

        local iname = itemName
        row.MouseButton1Click:Connect(function()
            selectedItems[iname] = not selectedItems[iname] or nil
            buildClientTab()
        end)

        itemBtns[itemName] = row
    end

    -- Coluna direita: controles
    local rightCol = newInst("Frame", {
        Size             = UDim2.new(0.38, -6, 1, 0),
        Position         = UDim2.new(0.62, 6, 0, 0),
        BackgroundTransparency = 1,
        Parent           = cols,
    })
    addListLayout(rightCol, Enum.FillDirection.Vertical, 8)

    -- Input de quantidade
    local qtyLabel = newInst("TextLabel", {
        Text             = ("QTD. (max %d)"):format(tierCfg.maxPerRequest),
        TextSize         = 9,
        Font             = Enum.Font.GothamBold,
        TextColor3       = C.muted,
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, 0, 0, 12),
        Parent           = rightCol,
    })

    local qtyInput = newInst("TextBox", {
        Text             = "1",
        PlaceholderText  = "Qtd.",
        TextSize         = 13,
        Font             = Enum.Font.GothamBold,
        TextColor3       = C.text,
        BackgroundColor3 = C.bg,
        BorderSizePixel  = 0,
        Size             = UDim2.new(1, 0, 0, 34),
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = rightCol,
    })
    addCorner(qtyInput, 7) ; addStroke(qtyInput, C.border, 1.5)
    if isInfinite then qtyInput.TextColor3 = C.muted ; qtyInput.Editable = false end

    -- Botoes Get / Stop  +  Infinite
    local btnRow = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 32),
        BackgroundTransparency = 1,
        Parent           = rightCol,
    })
    addListLayout(btnRow, Enum.FillDirection.Horizontal, 6)

    local getBtn = makeButton(btnRow,
        isRunning and "Stop" or "Get",
        isRunning and C.bg or C.border,
        isRunning and C.text or C.bg,
        0, 32)
    getBtn.Size = UDim2.new(0.55, -3, 1, 0)
    getBtn.TextSize = 12
    if isRunning then addStroke(getBtn, C.border, 1.5) end

    local infBtn = makeButton(btnRow,
        tierCfg.canInfinite and (isInfinite and "INF ON" or "INF") or "LOCK",
        isInfinite and C.border or C.bg,
        isInfinite and C.bg or C.text,
        0, 32)
    infBtn.Size = UDim2.new(0.45, -3, 1, 0)
    infBtn.TextSize = 11

    -- Info de selecao
    local selCount = 0
    for _ in pairs(selectedItems) do selCount = selCount + 1 end
    newInst("TextLabel", {
        Text             = selCount == 0 and "Nenhum selecionado" or (tostring(selCount) .. " item(s) selecionado(s)"),
        TextSize         = 10,
        Font             = Enum.Font.Gotham,
        TextColor3       = C.muted,
        BackgroundTransparency = 1,
        Size             = UDim2.new(1, 0, 0, 20),
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = rightCol,
    })

    -- ── Logica dos botoes ──
    getBtn.MouseButton1Click:Connect(function()
        if isRunning then
            isRunning = false
            isInfinite = false
            if infiniteConn then infiniteConn:Disconnect() ; infiniteConn = nil end
            buildClientTab()
            return
        end
        if onCooldown then return end

        local sel = {}
        for name, v in pairs(selectedItems) do if v then table.insert(sel, name) end end
        if #sel == 0 then return end

        local qty = math.min(tonumber(qtyInput.Text) or 1, tierCfg.maxPerRequest)

        if isInfinite and tierCfg.canInfinite then
            isRunning = true
            buildClientTab()
            infiniteConn = task.spawn(function()
                while isRunning do
                    if REMOTE_PICKUP and OBJECT_MODELS then
                        for _, item in ipairs(OBJECT_MODELS:GetChildren()) do
                            if selectedItems[item.Name] then
                                local id = item:GetAttribute("serverEntity")
                                if id then REMOTE_PICKUP:FireServer(id) end
                            end
                        end
                    end
                    task.wait(0.3)
                end
            end)
        else
            cooldownStart = os.time()
            if REMOTE_PICKUP and OBJECT_MODELS then
                for _, item in ipairs(OBJECT_MODELS:GetChildren()) do
                    if selectedItems[item.Name] then
                        local id = item:GetAttribute("serverEntity")
                        if id then
                            for _ = 1, qty do
                                REMOTE_PICKUP:FireServer(id)
                                task.wait(0.05)
                            end
                        end
                    end
                end
            end
            buildClientTab()
        end
    end)

    infBtn.MouseButton1Click:Connect(function()
        if not tierCfg.canInfinite then
            makeTween(infBtn, { BackgroundColor3 = Color3.fromRGB(254,226,226) }, 0.1)
            task.wait(0.4)
            makeTween(infBtn, { BackgroundColor3 = C.bg }, 0.15)
            return
        end
        isInfinite = not isInfinite
        buildClientTab()
    end)
end

-- ============================================================
-- ██  ABA BANLANDIA
-- ============================================================

local function buildBanlandiaTab()
    clearBody()
    setBodyLayout()

    -- Header
    local headerRow = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 24),
        BackgroundTransparency = 1,
        LayoutOrder      = 0,
        Parent           = panelBody,
    })
    newInst("TextLabel", {
        Text             = "BanLandia",
        TextSize         = 13,
        Font             = Enum.Font.GothamBold,
        TextColor3       = C.danger,
        BackgroundTransparency = 1,
        Size             = UDim2.new(0.6, 0, 1, 0),
        TextXAlignment   = Enum.TextXAlignment.Left,
        Parent           = headerRow,
    })
    local countBadge = newInst("TextLabel", {
        Text             = tostring(#BAN_LIST) .. " banido(s)",
        TextSize         = 10,
        Font             = Enum.Font.GothamBold,
        TextColor3       = C.danger,
        BackgroundColor3 = Color3.fromRGB(254, 226, 226),
        Size             = UDim2.new(0, 0, 1, 0),
        AutomaticSize    = Enum.AutomaticSize.X,
        Position         = UDim2.new(1, -90, 0, 0),
        TextXAlignment   = Enum.TextXAlignment.Center,
        Parent           = headerRow,
    })
    addCorner(countBadge, 20) ; addStroke(countBadge, C.danger, 1.5) ; addPadding(countBadge, 2, 8, 2, 8)

    if #BAN_LIST == 0 then
        newInst("TextLabel", {
            Text             = "Nenhum banido. Por enquanto.",
            TextSize         = 12,
            Font             = Enum.Font.Gotham,
            TextColor3       = C.muted,
            BackgroundTransparency = 1,
            Size             = UDim2.new(1, 0, 0, 40),
            TextXAlignment   = Enum.TextXAlignment.Center,
            LayoutOrder      = 1,
            Parent           = panelBody,
        })
        return
    end

    for i, b in ipairs(BAN_LIST) do
        local card = newInst("Frame", {
            Size             = UDim2.new(1, 0, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundColor3 = C.bg,
            BorderSizePixel  = 0,
            LayoutOrder      = i,
            Parent           = panelBody,
        })
        addCorner(card, 9)
        addStroke(card, Color3.fromRGB(229,229,229), 1.5)
        -- borda esquerda vermelha
        newInst("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = C.danger,
            BorderSizePixel = 0,
            Parent = card,
        })
        addPadding(card, 10, 12, 10, 16)
        addListLayout(card, Enum.FillDirection.Vertical, 5)

        -- Linha topo: nome + badge duracao
        local topRow2 = newInst("Frame", {
            Size = UDim2.new(1, 0, 0, 20),
            BackgroundTransparency = 1,
            Parent = card,
        })
        newInst("TextLabel", {
            Text = b.name,
            TextSize = 13, Font = Enum.Font.GothamBold,
            TextColor3 = C.text, BackgroundTransparency = 1,
            Size = UDim2.new(0.6, 0, 1, 0), Parent = topRow2,
        })
        local durColor = b.duration == "permanent" and C.danger or C.warn
        local durBadge = newInst("TextLabel", {
            Text = b.durLabel,
            TextSize = 9, Font = Enum.Font.GothamBold,
            TextColor3 = durColor,
            BackgroundColor3 = C.bg,
            Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
            Position = UDim2.new(1, -90, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = topRow2,
        })
        addCorner(durBadge, 20) ; addStroke(durBadge, durColor, 1.5) ; addPadding(durBadge, 2, 7, 2, 7)

        newInst("TextLabel", {
            Text = "Banido em: " .. b.date,
            TextSize = 10, Font = Enum.Font.Gotham,
            TextColor3 = C.muted, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 14), Parent = card,
        })
        newInst("TextLabel", {
            Text = b.reason,
            TextSize = 11, Font = Enum.Font.Gotham,
            TextColor3 = C.text, BackgroundColor3 = C.surface,
            Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            TextXAlignment = Enum.TextXAlignment.Left,
            TextWrapped = true,
            Parent = card,
        })

        local unbanBtn = makeButton(card, "Remover ban", C.bg, C.online, 0, 28)
        unbanBtn.Size = UDim2.new(1, 0, 0, 28)
        addStroke(unbanBtn, C.online, 1.5)
        local bi = i
        unbanBtn.MouseButton1Click:Connect(function()
            table.remove(BAN_LIST, bi)
            buildBanlandiaTab()
        end)
    end
end

-- ============================================================
-- ██  ABA KEYS
-- ============================================================

-- Armazena chaves em memoria (nao ha localStorage no Roblox)
local keysData = {}
local boundKeys = {}  -- { [code] = userId }

-- Inicializa chaves padrao
for code, cfg in pairs(VALID_KEYS) do
    table.insert(keysData, {
        code      = code,
        level     = cfg.level,
        tier      = cfg.tier,
        permanent = cfg.permanent,
        days      = cfg.days or 0,
        created   = os.time(),
        expires   = cfg.permanent and nil or (os.time() + (cfg.days or 30) * 86400),
        revokedAt = nil,
    })
end

local function genCode()
    local chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    local function seg()
        local s = ""
        for _ = 1, 4 do
            local idx = math.random(1, #chars)
            s = s .. chars:sub(idx, idx)
        end
        return s
    end
    return seg().."-"..seg().."-"..seg()
end

local function fmtExpiry(expires, permanent)
    if permanent then return "Permanente" end
    if not expires then return "—" end
    local left = math.floor((expires - os.time()) / 86400)
    if left < 0 then return "Expirada" end
    return tostring(left) .. "d restantes"
end

local function buildKeysTab()
    clearBody()
    setBodyLayout()

    -- Header
    local kHeader = newInst("Frame", {
        Size             = UDim2.new(1, 0, 0, 26),
        BackgroundTransparency = 1,
        LayoutOrder      = 0,
        Parent           = panelBody,
    })
    newInst("TextLabel", {
        Text = "Gerenciar Chaves",
        TextSize = 13, Font = Enum.Font.GothamBold,
        TextColor3 = C.admin, BackgroundTransparency = 1,
        Size = UDim2.new(0.6, 0, 1, 0), Parent = kHeader,
    })
    local newKeyBtn = makeButton(kHeader, "+ Nova chave", C.admin, C.bg, 0, 26)
    newKeyBtn.Size = UDim2.new(0, 100, 1, 0)
    newKeyBtn.Position = UDim2.new(1, -100, 0, 0)
    newKeyBtn.TextSize = 11

    newKeyBtn.MouseButton1Click:Connect(function()
        openModal("newkey", nil)
    end)

    if #keysData == 0 then
        newInst("TextLabel", {
            Text = "Nenhuma chave criada.",
            TextSize = 12, Font = Enum.Font.Gotham,
            TextColor3 = C.muted, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 40),
            TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = 1, Parent = panelBody,
        })
        return
    end

    local tierColors2 = {
        admin = C.admin, premium = C.online,
        ["semi-premium"] = C.warn, normal = C.muted, client = C.muted,
    }

    for i, k in ipairs(keysData) do
        local tier     = k.tier or k.level or "normal"
        local tc2      = tierColors2[tier] or C.muted
        local expired  = not k.permanent and k.expires and (os.time() > k.expires)
        local revoked  = k.revokedAt ~= nil
        local boundId  = boundKeys[k.code]
        local tierCfgK = TIER_CONFIG[tier] or TIER_CONFIG.normal

        local card2 = newInst("Frame", {
            Size             = UDim2.new(1, 0, 0, 0),
            AutomaticSize    = Enum.AutomaticSize.Y,
            BackgroundColor3 = (expired or revoked) and Color3.fromRGB(248,248,248) or C.bg,
            BorderSizePixel  = 0,
            LayoutOrder      = i,
            Parent           = panelBody,
        })
        addCorner(card2, 9)
        addStroke(card2, (expired or revoked) and Color3.fromRGB(210,210,210) or Color3.fromRGB(229,229,229), 1.5)
        -- borda esquerda colorida
        newInst("Frame", {
            Size = UDim2.new(0, 3, 1, 0),
            BackgroundColor3 = (expired or revoked) and Color3.fromRGB(200,200,200) or C.admin,
            BorderSizePixel = 0, Parent = card2,
        })
        addPadding(card2, 9, 12, 9, 16)
        addListLayout(card2, Enum.FillDirection.Vertical, 5)
        if expired or revoked then card2.BackgroundTransparency = 0.4 end

        -- Linha topo: codigo + badge tier
        local kTop = newInst("Frame", {
            Size = UDim2.new(1, 0, 0, 18),
            BackgroundTransparency = 1, Parent = card2,
        })
        newInst("TextLabel", {
            Text = k.code,
            TextSize = 12, Font = Enum.Font.RobotoMono,
            TextColor3 = C.text, BackgroundTransparency = 1,
            Size = UDim2.new(0.65, 0, 1, 0), Parent = kTop,
        })
        local tierBadge2 = newInst("TextLabel", {
            Text = tierCfgK.name:upper(),
            TextSize = 9, Font = Enum.Font.GothamBold,
            TextColor3 = tc2, BackgroundColor3 = C.bg,
            Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
            Position = UDim2.new(1, -80, 0, 0),
            TextXAlignment = Enum.TextXAlignment.Center, Parent = kTop,
        })
        addCorner(tierBadge2, 20) ; addStroke(tierBadge2, tc2, 1.5) ; addPadding(tierBadge2, 1, 7, 1, 7)

        -- Meta: criada + expiry + revoked
        local metaTxt = "Criada: " .. os.date("%d/%m/%Y", k.created)
        metaTxt = metaTxt .. "   " .. fmtExpiry(k.expires, k.permanent)
        if revoked then metaTxt = metaTxt .. "   REVOGADA" end
        newInst("TextLabel", {
            Text = metaTxt, TextSize = 10, Font = Enum.Font.Gotham,
            TextColor3 = revoked and C.danger or C.muted,
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 13), Parent = card2,
        })

        -- Tier info
        local infoTxt = (tierCfgK.canInfinite and "✓ Infinite" or "✕ Apenas Get")
            .. "  |  Max " .. tostring(tierCfgK.maxPerRequest)
            .. "  |  " .. (tierCfgK.cooldownSec > 0 and ("CD " .. tierCfgK.cooldownSec .. "s") or "Sem cooldown")
        newInst("TextLabel", {
            Text = infoTxt, TextSize = 10, Font = Enum.Font.Gotham,
            TextColor3 = C.muted, BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, 13), Parent = card2,
        })

        -- Jogador vinculado
        if boundId then
            local playerRow = newInst("Frame", {
                Size = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = C.surface,
                BorderSizePixel = 0, Parent = card2,
            })
            addCorner(playerRow, 7) ; addStroke(playerRow, Color3.fromRGB(232,232,232), 1.5)
            newInst("TextLabel", {
                Text = "Vinculada: ID " .. tostring(boundId),
                TextSize = 11, Font = Enum.Font.GothamBold,
                TextColor3 = C.online, BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 1, 0),
                TextXAlignment = Enum.TextXAlignment.Center,
                Parent = playerRow,
            })
        else
            newInst("TextLabel", {
                Text = "Livre (nao vinculada)",
                TextSize = 11, Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(180,180,180), BackgroundTransparency = 1,
                Size = UDim2.new(1, 0, 0, 14), Parent = card2,
            })
        end

        -- Botoes de acao
        local actRow2 = newInst("Frame", {
            Size = UDim2.new(1, 0, 0, 26),
            BackgroundTransparency = 1, Parent = card2,
        })
        addListLayout(actRow2, Enum.FillDirection.Horizontal, 6)

        local copyBtn2 = makeButton(actRow2, "Copiar", C.bg, C.muted, 0, 26)
        copyBtn2.Size = UDim2.new(0, 60, 1, 0) ; addStroke(copyBtn2, Color3.fromRGB(210,210,210), 1.5)

        if boundId then
            local unbindBtn = makeButton(actRow2, "Desvincular", C.bg, C.muted, 0, 26)
            unbindBtn.Size = UDim2.new(0, 80, 1, 0) ; addStroke(unbindBtn, Color3.fromRGB(200,200,200), 1.5)
            local ki = i
            unbindBtn.MouseButton1Click:Connect(function()
                boundKeys[keysData[ki].code] = nil
                buildKeysTab()
            end)
        end

        if not revoked and not expired and not k.permanent then
            local extBtn = makeButton(actRow2, "+Tempo", C.bg, C.online, 0, 26)
            extBtn.Size = UDim2.new(0, 60, 1, 0) ; addStroke(extBtn, C.online, 1.5)
            local kcode = k.code
            extBtn.MouseButton1Click:Connect(function()
                openModal("extend", kcode)
            end)
        end

        if not revoked then
            local revokeBtn2 = makeButton(actRow2, "Revogar", C.bg, C.danger, 0, 26)
            revokeBtn2.Size = UDim2.new(0, 65, 1, 0) ; addStroke(revokeBtn2, C.danger, 1.5)
            local ki = i
            revokeBtn2.MouseButton1Click:Connect(function()
                keysData[ki].revokedAt = os.time()
                buildKeysTab()
            end)
        else
            local delBtn = makeButton(actRow2, "Apagar", C.bg, C.danger, 0, 26)
            delBtn.Size = UDim2.new(0, 65, 1, 0) ; addStroke(delBtn, C.danger, 1.5)
            local ki = i
            delBtn.MouseButton1Click:Connect(function()
                table.remove(keysData, ki)
                buildKeysTab()
            end)
        end

        -- Copy acao
        local kcode = k.code
        copyBtn2.MouseButton1Click:Connect(function()
            copyBtn2.Text = "Copiado!"
            -- nao ha clipboard no Lua do Roblox, mas registra no output
            print("[Chucro] Chave: " .. kcode)
            task.wait(1.2)
            copyBtn2.Text = "Copiar"
        end)
    end
end

-- ============================================================
-- [[ CONSTRUCAO DAS TABS (botoes do header) ]]
-- ============================================================

local function switchTab(tab)
    currentTab = tab
    for t, btn in pairs(tabButtons) do
        local active = (t == tab)
        if t == "banlandia" then
            btn.BackgroundColor3 = active and C.danger or C.bg
            btn.TextColor3       = active and C.bg or C.danger
        elseif t == "keys" then
            btn.BackgroundColor3 = active and C.admin or C.bg
            btn.TextColor3       = active and C.bg or C.admin
        else
            btn.BackgroundColor3 = active and C.border or C.bg
            btn.TextColor3       = active and C.bg or C.muted
        end
    end
    if tab == "admin"      then buildAdminTab()
    elseif tab == "client" then buildClientTab()
    elseif tab == "banlandia" then buildBanlandiaTab()
    elseif tab == "keys"   then buildKeysTab()
    end
end

local function buildTabs()
    -- Limpa tabs antigas
    for _, c in ipairs(tabsFrame:GetChildren()) do
        if not c:IsA("UIListLayout") and not c:IsA("UIPadding") then c:Destroy() end
    end
    tabButtons = {}

    local isAdmin = sessionLevel == "admin"

    sessionBadge.Text            = isAdmin and "ADMIN" or "CLIENT"
    sessionBadge.TextColor3      = isAdmin and C.admin or C.client
    sessionBadge.BackgroundColor3= isAdmin and Color3.fromRGB(240,235,254) or Color3.fromRGB(235,242,255)
    addStroke(sessionBadge, isAdmin and C.admin or C.client, 1.5)

    local tabs = isAdmin
        and { "admin", "client", "banlandia", "keys" }
        or  { "client" }

    for _, tab in ipairs(tabs) do
        local label = tab == "banlandia" and "BanLandia" or tab == "keys" and "Keys" or tab:sub(1,1):upper()..tab:sub(2)
        local isBan  = tab == "banlandia"
        local isKeys = tab == "keys"

        local btn = newInst("TextButton", {
            Text             = label,
            TextSize         = 11,
            Font             = Enum.Font.GothamBold,
            TextColor3       = isBan and C.danger or isKeys and C.admin or C.muted,
            BackgroundColor3 = C.bg,
            Size             = UDim2.new(0, 0, 1, 0),
            AutomaticSize    = Enum.AutomaticSize.X,
            AutoButtonColor  = false,
            Parent           = tabsFrame,
        })
        addCorner(btn, 6)
        addStroke(btn, isBan and C.danger or isKeys and C.admin or C.border, 1.5)
        addPadding(btn, 0, 12, 0, 12)

        tabButtons[tab] = btn
        local t = tab
        btn.MouseButton1Click:Connect(function() switchTab(t) end)
    end

    currentTab = isAdmin and "admin" or "client"
    switchTab(currentTab)
end

-- ============================================================
-- [[ LOGICA DO MODAL — CONFIRMACOES ]]
-- ============================================================

-- Duracao selecionada pelo modal de ban
for dur, btn in pairs(durBtns) do
    local d = dur
    btn.MouseButton1Click:Connect(function()
        selectedDur = d
        for dd, b in pairs(durBtns) do
            b.BackgroundColor3 = dd == d and C.danger or C.bg
            b.TextColor3       = dd == d and C.bg or C.muted
        end
    end)
end

modalCancelBtn.MouseButton1Click:Connect(closeModal)
modalOverlay.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        -- clique fora do card fecha
        closeModal()
    end
end)
modalCard.InputBegan:Connect(function(input)
    input:GetPropertyChangedSignal("UserInputState"):Connect(function() end)
end)

-- Extend options (6 botoes dentro do modalCard para o extend)
local extendOptions = { "1h", "6h", "1d", "3d", "7d", "30d" }
local extendLabels  = { ["1h"]="1 Hora", ["6h"]="6 Horas", ["1d"]="1 Dia", ["3d"]="3 Dias", ["7d"]="7 Dias", ["30d"]="30 Dias" }
local extendSecs    = { ["1h"]=3600, ["6h"]=21600, ["1d"]=86400, ["3d"]=259200, ["7d"]=604800, ["30d"]=2592000 }
local selectedExtend = nil
local extendBtns = {}

local extendGrid = newInst("Frame", {
    Size = UDim2.new(1, 0, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundTransparency = 1,
    LayoutOrder = 3,
    Visible = false,
    Parent = modalCard,
})
do
    local gl = Instance.new("UIGridLayout")
    gl.CellSize = UDim2.new(0.5, -4, 0, 40)
    gl.CellPaddingSize = UDim2.new(0, 8, 0, 8)
    gl.SortOrder = Enum.SortOrder.LayoutOrder
    gl.Parent = extendGrid
end

for _, opt in ipairs(extendOptions) do
    local eb = newInst("TextButton", {
        Text = extendLabels[opt],
        TextSize = 12, Font = Enum.Font.GothamBold,
        TextColor3 = C.text, BackgroundColor3 = C.bg,
        Size = UDim2.new(0, 0, 0, 0),
        AutoButtonColor = false, Parent = extendGrid,
    })
    addCorner(eb, 7) ; addStroke(eb, Color3.fromRGB(210,210,210), 1.5)
    extendBtns[opt] = eb
    local o = opt
    eb.MouseButton1Click:Connect(function()
        selectedExtend = o
        for oo, b in pairs(extendBtns) do
            b.BackgroundColor3 = oo == o and Color3.fromRGB(240,235,254) or C.bg
            b.TextColor3       = oo == o and C.admin or C.text
            addStroke(b, oo == o and C.admin or Color3.fromRGB(210,210,210), 1.5)
        end
    end)
end

modalConfirmBtn.MouseButton1Click:Connect(function()
    if activeModal == "ban" then
        local u = USERS_DATA[activeModalIdx]
        if not u then closeModal() return end
        local reason = modalInput.Text
        if reason == "" then return end
        local durLabels2 = { permanent = "Permanente", month = "1 Mes", week = "1 Semana" }
        table.insert(BAN_LIST, 1, {
            name     = u.name,
            date     = os.date("%d %b %Y"),
            duration = selectedDur,
            durLabel = durLabels2[selectedDur],
            reason   = reason,
        })
        closeModal()
        switchTab("banlandia")

    elseif activeModal == "warn" then
        local u = USERS_DATA[activeModalIdx]
        if not u then closeModal() return end
        local msg = modalInput.Text
        if msg == "" then return end
        print(("[Chucro] Aviso para %s: %s"):format(u.name, msg))
        closeModal()

    elseif activeModal == "revoke" then
        local u = USERS_DATA[activeModalIdx]
        if not u then closeModal() return end
        for _, k in ipairs(keysData) do
            if k.code == u.key then k.revokedAt = os.time() end
        end
        boundKeys[u.key] = nil
        closeModal()
        if currentTab == "admin" then buildAdminTab() end

    elseif activeModal == "extend" then
        if not selectedExtend then return end
        local kcode = activeModalIdx
        for _, k in ipairs(keysData) do
            if k.code == kcode then
                local base = (k.expires and k.expires > os.time()) and k.expires or os.time()
                k.expires   = base + extendSecs[selectedExtend]
                k.permanent = false
                break
            end
        end
        selectedExtend = nil
        closeModal()
        buildKeysTab()

    elseif activeModal == "newkey" then
        local code = modalInput.Text ~= "" and modalInput.Text:upper() or genCode()
        -- verifica duplicata
        for _, k in ipairs(keysData) do
            if k.code:upper() == code:upper() then
                modalSub.Text = "Chave ja existe!"
                return
            end
        end
        table.insert(keysData, {
            code = code, level = "client", tier = "normal",
            permanent = false, days = 30, created = os.time(),
            expires = os.time() + 30 * 86400, revokedAt = nil,
        })
        print("[Chucro] Nova chave: " .. code)
        closeModal()
        buildKeysTab()
    end
end)

-- Mostra grid de extend quando o modal e "extend"
local _origOpen = openModal
openModal = function(kind, idx)
    _origOpen(kind, idx)
    extendGrid.Visible = (kind == "extend")
    selectedExtend = nil
    for _, b in pairs(extendBtns) do
        b.BackgroundColor3 = C.bg
        b.TextColor3 = C.text
        addStroke(b, Color3.fromRGB(210,210,210), 1.5)
    end
end

-- ============================================================
-- [[ KEY SCREEN — LOGICA ]]
-- ============================================================

local function setKsStatus(msg, color)
    ksStatus.Text    = msg
    ksStatus.TextColor3 = color or C.danger
    ksStatus.Visible = msg ~= ""
end

local function updateBfBar()
    bfBarBg.Visible = bfAttempts > 0
    local pct = math.min(1, bfAttempts / BF_MAX)
    makeTween(bfBar, { Size = UDim2.new(pct, 0, 1, 0) }, 0.3)
    bfBar.BackgroundColor3 = pct >= 1 and C.danger or pct >= 0.6 and C.warn or C.admin
end

local function launchUI()
    keyScreen.Visible = false
    mainUI.Visible    = true
    buildTabs()
end

local function logout()
    sessionLevel = nil ; sessionKey = nil
    selectedItems = {}  ; isInfinite = false ; isRunning = false
    if infiniteConn then task.cancel(infiniteConn) ; infiniteConn = nil end
    mainUI.Visible    = false
    keyScreen.Visible = true
    ksInput.Text      = ""
    ksBtn.Text        = "Verificar chave"
    ksBtn.Active      = true
    setKsStatus("", C.muted)
    ksInputStroke.Color = C.border
end

logoutBtn.MouseButton1Click:Connect(logout)

ksInput.FocusLost:Connect(function(enterPressed)
    if enterPressed then ksBtn:Invoke() end
end)

ksBtn.MouseButton1Click:Connect(function()
    local code = ksInput.Text:match("^%s*(.-)%s*$"):lower()
    if code == "" then setKsStatus("Digite sua chave de acesso.", C.warn) return end

    -- Brute force check
    if bfLocked and os.time() < bfLockUntil then
        local secs = bfLockUntil - os.time()
        setKsStatus(("Bloqueado. Aguarde %ds."):format(secs), C.danger)
        return
    end

    local found = nil
    for kcode, cfg in pairs(VALID_KEYS) do
        if kcode:lower() == code then
            found = { code = kcode, level = cfg.level, tier = cfg.tier, permanent = cfg.permanent, days = cfg.days or 0 }
            break
        end
    end

    if not found then
        bfAttempts = bfAttempts + 1
        updateBfBar()
        if bfAttempts >= BF_MAX then
            bfLocked = true
            bfLockUntil = os.time() + BF_LOCK_SEC
            bfAttempts = 0
            setKsStatus("Bloqueado por " .. BF_LOCK_SEC .. "s. Muitas tentativas.", C.danger)
            task.delay(BF_LOCK_SEC, function()
                bfLocked = false ; updateBfBar()
                setKsStatus("", C.muted) ; ksInputStroke.Color = C.border
            end)
        else
            setKsStatus(("Chave invalida. (%d/%d tentativas)"):format(bfAttempts, BF_MAX), C.danger)
        end
        ksInputStroke.Color = C.danger
        return
    end

    -- Chave valida
    bfAttempts = 0 ; updateBfBar()
    sessionLevel = found.level
    sessionKey   = found
    ksInputStroke.Color = C.online
    setKsStatus("Bem-vindo! Entrando...", C.online)
    ksBtn.Active = false
    task.delay(1, launchUI)
end)

-- ============================================================
-- [[ DRAG — PAINEL ARRASTAVEL ]]
-- ============================================================

local dragging = false
local dragStart, startPos

panelOuter.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging  = true
        dragStart = input.Position
        startPos  = panelOuter.Position
    end
end)

panelOuter.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        panelOuter.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- ============================================================
-- [[ F1 — MOSTRAR / ESCONDER ]]
-- ============================================================

UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        if mainUI.Visible then
            panelOuter.Visible = not panelOuter.Visible
        end
    end
end)

-- ============================================================
print("[Chucro] Script carregado. Digite sua chave para entrar.")
