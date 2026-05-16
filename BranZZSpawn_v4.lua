-- ╔══════════════════════════════════════════╗
-- ║    BRANZZ SPAWN VISUAL — v3.0            ║
-- ║       🧑‍💻 By BranZZ MetoDos 🚀            ║
-- ╚══════════════════════════════════════════╝

local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local FANDOM_BASE = "https://stealabrainrot.fandom.com/wiki/"
local WIKI_API    = "https://stealabrainrot.fandom.com/api.php"

-- ══════════════════════════════════════
-- MÓDULOS
-- ══════════════════════════════════════
local AnimalsData   = nil
local AnimalsShared = nil
pcall(function()
    AnimalsData   = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))
    AnimalsShared = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Animals"))
end)

-- ══════════════════════════════════════
-- UTILS — PARSE DE GERAÇÃO (100, 1K, 1M, 7B, etc.)
-- ══════════════════════════════════════

-- Converte string "1K", "7B", "4.5M", "100" para número
local function parseGen(str)
    if not str or str == "" then return 0 end
    str = str:upper():gsub("%s+", "")
    local num, suffix = str:match("^([%d%.]+)([KMBT]?)$")
    if not num then return 0 end
    local n = tonumber(num) or 0
    if suffix == "K" then n = n * 1000
    elseif suffix == "M" then n = n * 1000000
    elseif suffix == "B" then n = n * 1000000000
    elseif suffix == "T" then n = n * 1000000000000
    end
    return math.floor(n)
end

-- Formata número para exibição na billboard (ex: 4B/s)
local function formatGen(val)
    if val >= 1000000000000 then
        local n = val / 1000000000000
        return (n == math.floor(n)) and string.format("%dT/s", n) or string.format("%.1fT/s", n)
    elseif val >= 1000000000 then
        local n = val / 1000000000
        return (n == math.floor(n)) and string.format("%dB/s", n) or string.format("%.1fB/s", n)
    elseif val >= 1000000 then
        local n = val / 1000000
        return (n == math.floor(n)) and string.format("%dM/s", n) or string.format("%.1fM/s", n)
    elseif val >= 1000 then
        local n = val / 1000
        return (n == math.floor(n)) and string.format("%dK/s", n) or string.format("%.1fK/s", n)
    end
    return tostring(val) .. "/s"
end

-- ══════════════════════════════════════
-- BUSCA PLOT DO PLAYER
-- ══════════════════════════════════════
local function findMyPlotAndBase()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil, nil end

    -- Tenta achar pelo Synchronizer (Owner)
    for _, plot in ipairs(plots:GetChildren()) do
        local found = false
        pcall(function()
            local channel = require(ReplicatedStorage.Packages.Synchronizer):Get(plot.Name)
            if not channel then return end
            local owner = channel:Get("Owner")
            if (typeof(owner) == "Instance" and owner == localPlayer)
            or (type(owner) == "table" and owner.UserId == localPlayer.UserId) then
                found = true
            end
        end)
        if found then
            local base = plot:FindFirstChild("Base")
                      or plot:FindFirstChild("Plot")
                      or plot:FindFirstChildWhichIsA("BasePart", true)
            return plot, base
        end
    end

    -- Fallback: plot com nome igual ao do player
    local byName = plots:FindFirstChild(localPlayer.Name)
    if byName then
        local base = byName:FindFirstChild("Base")
                  or byName:FindFirstChild("Plot")
                  or byName:FindFirstChildWhichIsA("BasePart", true)
        return byName, base
    end

    -- Fallback: procura plot que tenha o character do player dentro
    local char = localPlayer.Character
    if char and char.PrimaryPart then
        local charPos = char.PrimaryPart.Position
        local closest, closestDist, closestBase = nil, math.huge, nil
        for _, plot in ipairs(plots:GetChildren()) do
            local base = plot:FindFirstChild("Base")
                      or plot:FindFirstChild("Plot")
                      or plot:FindFirstChildWhichIsA("BasePart", true)
            if base then
                local basePart = base:IsA("BasePart") and base
                              or (base:IsA("Model") and base.PrimaryPart)
                if basePart then
                    local dist = (basePart.Position - charPos).Magnitude
                    if dist < closestDist then
                        closestDist = dist
                        closest = plot
                        closestBase = base
                    end
                end
            end
        end
        if closest then
            return closest, closestBase
        end
    end

    return nil, nil
end

-- Retorna uma posição DENTRO do plot, em cima da base (não cai no chão)
local function getSpawnPosInsidePlot(base)
    local function fromPart(part)
        -- Topo da base + 3 studs de altura
        local topY = part.Position.Y + (part.Size.Y / 2) + 3
        -- Offset aleatório dentro de 40% do tamanho do plot
        local rx = math.random(-math.floor(part.Size.X * 0.35), math.floor(part.Size.X * 0.35))
        local rz = math.random(-math.floor(part.Size.Z * 0.35), math.floor(part.Size.Z * 0.35))
        return Vector3.new(part.Position.X + rx, topY, part.Position.Z + rz)
    end

    if not base then return Vector3.new(0, 10, 0) end

    if base:IsA("BasePart") then
        return fromPart(base)
    elseif base:IsA("Model") and base.PrimaryPart then
        return fromPart(base.PrimaryPart)
    else
        -- Tenta achar qualquer BasePart dentro do model
        local part = base:FindFirstChildWhichIsA("BasePart", true)
        if part then return fromPart(part) end
    end

    return Vector3.new(0, 10, 0)
end

-- ══════════════════════════════════════
-- BUSCA MODELO EM ReplicatedStorage > Models > Animals > [nome]
-- ══════════════════════════════════════
local function findModelInRS(name)
    local modelsFolder  = ReplicatedStorage:FindFirstChild("Models")
    if not modelsFolder then return nil end
    local animalsFolder = modelsFolder:FindFirstChild("Animals")
    if not animalsFolder then return nil end

    local nameLower = name:lower():gsub("%s+", "")

    -- Busca exata primeiro
    for _, child in ipairs(animalsFolder:GetChildren()) do
        if child.Name:lower():gsub("%s+", "") == nameLower then
            return child
        end
    end
    -- Busca parcial
    for _, child in ipairs(animalsFolder:GetChildren()) do
        local cn = child.Name:lower():gsub("%s+", "")
        if cn:find(nameLower, 1, true) or nameLower:find(cn, 1, true) then
            return child
        end
    end
    return nil
end

-- ══════════════════════════════════════
-- BUSCA ANIMAÇÃO EM ReplicatedStorage > Animations > Animals > [nome]
-- ══════════════════════════════════════
local function findAnimationInRS(name)
    local animFolder = ReplicatedStorage:FindFirstChild("Animations")
    if not animFolder then return nil end
    local animAnimals = animFolder:FindFirstChild("Animals")
    if not animAnimals then return nil end

    local nameLower = name:lower():gsub("%s+", "")

    for _, child in ipairs(animAnimals:GetChildren()) do
        if child.Name:lower():gsub("%s+", "") == nameLower then
            return child
        end
    end
    for _, child in ipairs(animAnimals:GetChildren()) do
        local cn = child.Name:lower():gsub("%s+", "")
        if cn:find(nameLower, 1, true) or nameLower:find(cn, 1, true) then
            return child
        end
    end
    return nil
end

-- Aplica a animação ao modelo clonado (se tiver Humanoid/AnimationController)
local function applyAnimation(model, animObj)
    if not model or not animObj then return end
    pcall(function()
        local controller = model:FindFirstChildWhichIsA("AnimationController", true)
                        or model:FindFirstChildWhichIsA("Humanoid", true)
        if not controller then return end
        local track = controller:LoadAnimation(animObj)
        track.Looped = true
        track:Play()
    end)
end

-- ══════════════════════════════════════
-- IMAGEM DA WIKI — PARALELO
-- ══════════════════════════════════════
local BAD_KEYWORDS = {
    "star","background","banner","logo","wiki_","button","badge",
    "fundo","placeholder","cursor","arrow","wordmark","favicon",
    "navicon","header","footer","spotlight","transparent","question","default","noimage","blank",
}

local function isBadImage(url)
    if not url or url == "" then return true end
    local low = url:lower()
    for _, kw in ipairs(BAD_KEYWORDS) do
        if low:find(kw, 1, true) then return true end
    end
    local px = low:match("/(%d+)px%-")
    if px and tonumber(px) < 150 then return true end
    return false
end

local function httpGet(url)
    local res = nil
    if not res then local ok,r = pcall(function() return request({ Url=url, Method="GET" }) end); if ok and r then res=r end end
    if not res then local ok,r = pcall(function() return http.request({ Url=url, Method="GET" }) end); if ok and r then res=r end end
    if not res then local ok,r = pcall(function() return syn.request({ Url=url, Method="GET" }) end); if ok and r then res=r end end
    return res
end

local function fetchFandomImage(name)
    local url  = nil
    local done = false
    local v1   = name:gsub("(%a)([%w]*)", function(a,b) return a:upper()..b:lower() end):gsub(" ","_")
    local v2   = name:gsub(" ","_")

    task.spawn(function()
        if done then return end
        for _, v in ipairs({v1, v2}) do
            if done then break end
            pcall(function()
                local res = httpGet(WIKI_API.."?action=query&titles="..v.."&prop=pageimages&format=json&pithumbsize=400&piprop=original|thumbnail")
                if done or not res or not res.Body then return end
                if res.Body:find('"missing"') then return end
                local orig = res.Body:match('"original":%s*{.-"source":%s*"([^"]+)"')
                if orig and not isBadImage(orig) then done=true; url=orig:gsub("\\",""); return end
                local thumb = res.Body:match('"thumbnail":%s*{.-"source":%s*"([^"]+)"')
                if thumb and not isBadImage(thumb) then done=true; url=thumb:gsub("\\","") end
            end)
        end
    end)

    task.spawn(function()
        if done then return end
        pcall(function()
            local res = httpGet(FANDOM_BASE..v1)
            if done or not res or not res.Body then return end
            local body = res.Body
            local ogImg = body:match('property="og:image"%s+content="([^"]+)"')
                       or body:match('content="([^"]+)"%s+property="og:image"')
            if ogImg and not isBadImage(ogImg) then done=true; url=ogImg:gsub("&amp;","&"); return end
            for img in body:gmatch('data%-src="(https://static%.wikia%.nocookie%.net/stealabrainrot/images/[^"]+)"') do
                local c = img:gsub("&amp;","&"):match("^([^?]+)")
                if c and not isBadImage(c) then done=true; url=c; return end
            end
        end)
    end)

    local waited = 0
    while not done and waited < 4 do
        task.wait(0.05)
        waited = waited + 0.05
    end
    return url
end

-- ══════════════════════════════════════
-- CONTROLE DE BILLBOARDS (ativar/desativar)
-- ══════════════════════════════════════
local spawnedBrainrots  = {}  -- lista de containers spawnados
local billboardsVisible = true

local function setAllBillboardsVisible(visible)
    billboardsVisible = visible
    for _, entry in ipairs(spawnedBrainrots) do
        if entry.billboard and entry.billboard.Parent then
            entry.billboard.Enabled = visible
        end
    end
end

-- ══════════════════════════════════════
-- SPAWN DO BRAINROT
-- ══════════════════════════════════════
local function spawnVisualBrainrot(name, mutation, traits, genVal)
    local myPlot, myBase = findMyPlotAndBase()

    -- Sem plot não spawna
    if not myPlot then
        return nil, "❌ Seu plot não foi encontrado!"
    end

    -- Posição garantida dentro do plot
    local spawnPos = getSpawnPosInsidePlot(myBase)

    -- Busca modelo em RS > Models > Animals
    local sourceModel = findModelInRS(name)

    -- Busca animação em RS > Animations > Animals
    local animObj = findAnimationInRS(name)

    local container = Instance.new("Model")
    container.Name = "BRANZZ_VISUAL_" .. name:gsub(" ", "_") .. "_" .. tostring(os.time())
    container.Parent = myPlot  -- sempre dentro do plot

    local primaryPart = nil

    if sourceModel then
        local clone = sourceModel:Clone()
        clone.Name = name
        clone.Parent = container

        pcall(function()
            if clone:IsA("Model") and clone.PrimaryPart then
                clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
                primaryPart = clone.PrimaryPart
            elseif clone:IsA("BasePart") then
                clone.CFrame = CFrame.new(spawnPos)
                clone.Anchored = true
                primaryPart = clone
            else
                -- Tenta achar qualquer BasePart dentro do clone
                primaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
                if primaryPart then
                    clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
                end
            end
        end)

        -- Aplica animação se encontrou
        if animObj then
            applyAnimation(clone, animObj)
            print("[BranzZ] 🎬 Animação aplicada: " .. name)
        end

        print("[BranzZ] ✅ Modelo de RS clonado: " .. name)
    else
        -- Fallback: part roxa com Neon
        local part = Instance.new("Part")
        part.Size = Vector3.new(3, 4, 3)
        part.BrickColor = BrickColor.new("Bright purple")
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.CanCollide = false
        part.CFrame = CFrame.new(spawnPos)
        part.Name = name
        part.Parent = container
        container.PrimaryPart = part
        primaryPart = part
        print("[BranzZ] ⚠️ Modelo não encontrado em RS, usando placeholder: " .. name)
    end

    -- ── Billboard com infos ──
    local billboard = nil
    if primaryPart then
        billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 220, 0, 130)
        billboard.StudsOffset = Vector3.new(0, 5, 0)
        billboard.AlwaysOnTop = false
        billboard.Enabled = billboardsVisible
        billboard.Parent = primaryPart

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1, 0, 1, 0)
        bg.BackgroundColor3 = Color3.fromRGB(13, 11, 22)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel = 0
        bg.Parent = billboard
        local bgc = Instance.new("UICorner")
        bgc.CornerRadius = UDim.new(0, 10)
        bgc.Parent = bg
        local bgs = Instance.new("UIStroke")
        bgs.Color = Color3.fromRGB(150, 100, 240)
        bgs.Thickness = 1.5
        bgs.Parent = bg

        local topB = Instance.new("Frame")
        topB.Size = UDim2.new(1, 0, 0, 3)
        topB.BackgroundColor3 = Color3.fromRGB(160, 100, 255)
        topB.BorderSizePixel = 0
        topB.Parent = bg
        local topBc = Instance.new("UICorner")
        topBc.CornerRadius = UDim.new(0, 3)
        topBc.Parent = topB

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1, -10, 0, 26)
        nameL.Position = UDim2.new(0, 5, 0, 6)
        nameL.BackgroundTransparency = 1
        nameL.Text = "👑 " .. name
        nameL.TextColor3 = Color3.fromRGB(220, 185, 255)
        nameL.TextSize = 14
        nameL.Font = Enum.Font.GothamBold
        nameL.TextWrapped = true
        nameL.Parent = bg

        local genL = Instance.new("TextLabel")
        genL.Size = UDim2.new(1, -10, 0, 20)
        genL.Position = UDim2.new(0, 5, 0, 34)
        genL.BackgroundTransparency = 1
        genL.Text = "💰 " .. formatGen(genVal)
        genL.TextColor3 = Color3.fromRGB(140, 230, 140)
        genL.TextSize = 13
        genL.Font = Enum.Font.Gotham
        genL.Parent = bg

        local mutL = Instance.new("TextLabel")
        mutL.Size = UDim2.new(1, -10, 0, 20)
        mutL.Position = UDim2.new(0, 5, 0, 56)
        mutL.BackgroundTransparency = 1
        mutL.Text = "🧬 Mut: " .. mutation
        mutL.TextColor3 = Color3.fromRGB(255, 205, 100)
        mutL.TextSize = 12
        mutL.Font = Enum.Font.Gotham
        mutL.Parent = bg

        local traitL = Instance.new("TextLabel")
        traitL.Size = UDim2.new(1, -10, 0, 30)
        traitL.Position = UDim2.new(0, 5, 0, 78)
        traitL.BackgroundTransparency = 1
        traitL.Text = "⭐ " .. traits
        traitL.TextColor3 = Color3.fromRGB(170, 210, 255)
        traitL.TextSize = 11
        traitL.Font = Enum.Font.Gotham
        traitL.TextWrapped = true
        traitL.Parent = bg

        -- Animação flutuante da billboard
        task.spawn(function()
            local t = 0
            while billboard and billboard.Parent do
                t = t + 0.05
                billboard.StudsOffset = Vector3.new(0, 5 + math.sin(t) * 0.35, 0)
                task.wait(0.05)
            end
        end)
    end

    table.insert(spawnedBrainrots, { container = container, billboard = billboard })
    return container, nil
end

local function removeAllVisuals()
    for _, entry in ipairs(spawnedBrainrots) do
        pcall(function() entry.container:Destroy() end)
    end
    spawnedBrainrots = {}
end

-- ══════════════════════════════════════
-- HELPERS UI
-- ══════════════════════════════════════
local function makeCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 12)
    c.Parent = parent
end

local function makeStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(180, 160, 220)
    s.Thickness = thickness or 1.5
    s.Parent = parent
    return s
end

local function makeLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = props.font or Enum.Font.Gotham
    l.TextColor3 = props.color or Color3.fromRGB(220, 210, 240)
    l.TextSize = props.size or 13
    l.Text = props.text or ""
    l.Size = props.sz or UDim2.new(1, 0, 0, 22)
    l.Position = props.pos or UDim2.new(0, 0, 0, 0)
    l.ZIndex = props.z or 3
    l.TextXAlignment = props.align or Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function makeInput(parent, placeholder, ypos, z)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, -20, 0, 36)
    bg.Position = UDim2.new(0, 10, 0, ypos)
    bg.BackgroundColor3 = Color3.fromRGB(22, 18, 36)
    bg.BorderSizePixel = 0
    bg.ZIndex = z or 3
    bg.Parent = parent
    makeCorner(bg, 8)
    makeStroke(bg, Color3.fromRGB(90, 70, 150), 1.2)

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1, -16, 1, 0)
    input.Position = UDim2.new(0, 8, 0, 0)
    input.BackgroundTransparency = 1
    input.Text = ""
    input.PlaceholderText = placeholder
    input.TextColor3 = Color3.fromRGB(215, 205, 240)
    input.PlaceholderColor3 = Color3.fromRGB(90, 75, 130)
    input.TextSize = 13
    input.Font = Enum.Font.Gotham
    input.ClearTextOnFocus = false
    input.ZIndex = (z or 3) + 1
    input.Parent = bg
    return input, bg
end

local function makeDrag(frame, handle)
    local dragging, dragStart, startPos = false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

-- ══════════════════════════════════════
-- UI PRINCIPAL
-- ══════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "BRANZZ_SPAWN_UI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent = CoreGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 320, 0, 510)
main.Position = UDim2.new(0.5, -160, 0.5, -255)
main.BackgroundColor3 = Color3.fromRGB(13, 11, 22)
main.BorderSizePixel = 0
main.ZIndex = 2
main.Parent = sg
makeCorner(main, 20)
makeStroke(main, Color3.fromRGB(150, 120, 220), 1.5)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 14, 32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 8, 18)),
})
grad.Rotation = 135
grad.Parent = main

local topBarLine = Instance.new("Frame")
topBarLine.Size = UDim2.new(1, 0, 0, 4)
topBarLine.BackgroundColor3 = Color3.fromRGB(160, 100, 255)
topBarLine.BorderSizePixel = 0
topBarLine.ZIndex = 3
topBarLine.Parent = main
makeCorner(topBarLine, 4)

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
header.BorderSizePixel = 0
header.ZIndex = 3
header.Parent = main
makeCorner(header, 20)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1, 0, 0, 20)
headerFix.Position = UDim2.new(0, 0, 1, -20)
headerFix.BackgroundColor3 = Color3.fromRGB(20, 16, 36)
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 3
headerFix.Parent = header

makeDrag(main, header)

makeLabel(header, {
    text = "🧠 BranzZ Spawn Visual",
    font = Enum.Font.GothamBold,
    size = 15,
    color = Color3.fromRGB(210, 185, 255),
    sz = UDim2.new(1, -80, 0, 22),
    pos = UDim2.new(0, 14, 0, 8),
    z = 4,
})
makeLabel(header, {
    text = "By BranZZ MetoDos  •  v3.0",
    size = 11,
    color = Color3.fromRGB(110, 90, 160),
    sz = UDim2.new(1, -80, 0, 16),
    pos = UDim2.new(0, 14, 0, 30),
    z = 4,
})

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 5
closeBtn.Parent = header
makeCorner(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        { BackgroundTransparency = 1 }):Play()
    task.wait(0.35)
    sg:Destroy()
end)

-- ── Preview ──
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(1, -20, 0, 100)
previewFrame.Position = UDim2.new(0, 10, 0, 58)
previewFrame.BackgroundColor3 = Color3.fromRGB(20, 15, 35)
previewFrame.BorderSizePixel = 0
previewFrame.ZIndex = 3
previewFrame.Parent = main
makeCorner(previewFrame, 12)
makeStroke(previewFrame, Color3.fromRGB(80, 55, 140), 1.2)

local previewImg = Instance.new("ImageLabel")
previewImg.Size = UDim2.new(0, 88, 0, 88)
previewImg.Position = UDim2.new(0, 6, 0.5, -44)
previewImg.BackgroundColor3 = Color3.fromRGB(30, 20, 50)
previewImg.Image = ""
previewImg.ScaleType = Enum.ScaleType.Fit
previewImg.ZIndex = 4
previewImg.Parent = previewFrame
makeCorner(previewImg, 10)

local previewName = makeLabel(previewFrame, {
    text = "Nome do Brainrot",
    font = Enum.Font.GothamBold,
    size = 13,
    color = Color3.fromRGB(200, 175, 245),
    sz = UDim2.new(1, -105, 0, 20),
    pos = UDim2.new(0, 100, 0, 8),
    z = 4,
})
local previewGen = makeLabel(previewFrame, {
    text = "Gen: —",
    size = 12,
    color = Color3.fromRGB(140, 220, 140),
    sz = UDim2.new(1, -105, 0, 18),
    pos = UDim2.new(0, 100, 0, 30),
    z = 4,
})
local previewMut = makeLabel(previewFrame, {
    text = "Mut: —",
    size = 11,
    color = Color3.fromRGB(255, 200, 100),
    sz = UDim2.new(1, -105, 0, 18),
    pos = UDim2.new(0, 100, 0, 50),
    z = 4,
})
local previewTraits = makeLabel(previewFrame, {
    text = "Traits: —",
    size = 10,
    color = Color3.fromRGB(160, 200, 255),
    sz = UDim2.new(1, -105, 0, 18),
    pos = UDim2.new(0, 100, 0, 70),
    z = 4,
})

-- Badge modelo real
local realBadge = Instance.new("TextLabel")
realBadge.Size = UDim2.new(0, 90, 0, 16)
realBadge.Position = UDim2.new(0, 6, 0, 6)
realBadge.BackgroundColor3 = Color3.fromRGB(40, 160, 80)
realBadge.BackgroundTransparency = 0.3
realBadge.Text = "✅ Modelo RS"
realBadge.TextColor3 = Color3.fromRGB(180, 255, 180)
realBadge.TextSize = 10
realBadge.Font = Enum.Font.GothamBold
realBadge.ZIndex = 5
realBadge.Visible = false
realBadge.Parent = previewFrame
makeCorner(realBadge, 4)

-- Badge animação
local animBadge = Instance.new("TextLabel")
animBadge.Size = UDim2.new(0, 90, 0, 16)
animBadge.Position = UDim2.new(0, 6, 0, 26)
animBadge.BackgroundColor3 = Color3.fromRGB(60, 100, 200)
animBadge.BackgroundTransparency = 0.3
animBadge.Text = "🎬 Anim OK"
animBadge.TextColor3 = Color3.fromRGB(180, 210, 255)
animBadge.TextSize = 10
animBadge.Font = Enum.Font.GothamBold
animBadge.ZIndex = 5
animBadge.Visible = false
animBadge.Parent = previewFrame
makeCorner(animBadge, 4)

-- ── Divisor ──
local div1 = Instance.new("Frame")
div1.Size = UDim2.new(0.88, 0, 0, 1)
div1.Position = UDim2.new(0.06, 0, 0, 166)
div1.BackgroundColor3 = Color3.fromRGB(55, 40, 88)
div1.BorderSizePixel = 0
div1.ZIndex = 3
div1.Parent = main

-- ── Inputs ──
makeLabel(main, {
    text = "Nome do Brainrot",
    size = 12,
    color = Color3.fromRGB(170, 145, 215),
    sz = UDim2.new(1, -20, 0, 16),
    pos = UDim2.new(0, 10, 0, 175),
    z = 3,
})
local inputName, _ = makeInput(main, "Ex: Capitano Moby", 192, 3)

makeLabel(main, {
    text = "Geração /s  (ex: 100 · 1K · 4.5M · 7B · 1T)",
    size = 12,
    color = Color3.fromRGB(170, 145, 215),
    sz = UDim2.new(1, -20, 0, 16),
    pos = UDim2.new(0, 10, 0, 235),
    z = 3,
})
local inputGen, _ = makeInput(main, "Ex: 100  /  1K  /  4.5M  /  7B", 252, 3)

makeLabel(main, {
    text = "Mutação",
    size = 12,
    color = Color3.fromRGB(170, 145, 215),
    sz = UDim2.new(1, -20, 0, 16),
    pos = UDim2.new(0, 10, 0, 295),
    z = 3,
})
local inputMut, _ = makeInput(main, "Ex: Gold, Rainbow, Shiny...", 312, 3)

makeLabel(main, {
    text = "Traits (separe por vírgula)",
    size = 12,
    color = Color3.fromRGB(170, 145, 215),
    sz = UDim2.new(1, -20, 0, 16),
    pos = UDim2.new(0, 10, 0, 355),
    z = 3,
})
local inputTraits, _ = makeInput(main, "Ex: Taco, Fire, Nyan Cat", 372, 3)

-- ── Divisor ──
local div2 = Instance.new("Frame")
div2.Size = UDim2.new(0.88, 0, 0, 1)
div2.Position = UDim2.new(0.06, 0, 0, 416)
div2.BackgroundColor3 = Color3.fromRGB(55, 40, 88)
div2.BorderSizePixel = 0
div2.ZIndex = 3
div2.Parent = main

-- ── Status ──
local statusLabel = makeLabel(main, {
    text = "",
    size = 12,
    color = Color3.fromRGB(140, 220, 140),
    sz = UDim2.new(1, -20, 0, 16),
    pos = UDim2.new(0, 10, 0, 420),
    z = 3,
    align = Enum.TextXAlignment.Center,
})

-- ── Botão Spawn ──
local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0.55, 0, 0, 40)
spawnBtn.Position = UDim2.new(0.06, 0, 0, 440)
spawnBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 190)
spawnBtn.Text = "✨  Spawn"
spawnBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
spawnBtn.TextSize = 15
spawnBtn.Font = Enum.Font.GothamBold
spawnBtn.BorderSizePixel = 0
spawnBtn.AutoButtonColor = false
spawnBtn.ZIndex = 3
spawnBtn.Parent = main
makeCorner(spawnBtn, 12)
makeStroke(spawnBtn, Color3.fromRGB(150, 100, 255), 1.5)

-- ── Botão Limpar ──
local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0.32, 0, 0, 40)
clearBtn.Position = UDim2.new(0.63, 0, 0, 440)
clearBtn.BackgroundColor3 = Color3.fromRGB(160, 60, 60)
clearBtn.Text = "🗑 Limpar"
clearBtn.TextColor3 = Color3.fromRGB(255, 220, 220)
clearBtn.TextSize = 14
clearBtn.Font = Enum.Font.GothamBold
clearBtn.BorderSizePixel = 0
clearBtn.AutoButtonColor = false
clearBtn.ZIndex = 3
clearBtn.Parent = main
makeCorner(clearBtn, 12)
makeStroke(clearBtn, Color3.fromRGB(220, 80, 80), 1.5)

-- ── Botão Toggle Billboards ──
local toggleBtn = Instance.new("TextButton")
toggleBtn.Size = UDim2.new(0.88, 0, 0, 32)
toggleBtn.Position = UDim2.new(0.06, 0, 0, 486)
toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 100)
toggleBtn.Text = "👁 Ocultar Info dos Brainrots"
toggleBtn.TextColor3 = Color3.fromRGB(200, 255, 230)
toggleBtn.TextSize = 13
toggleBtn.Font = Enum.Font.GothamBold
toggleBtn.BorderSizePixel = 0
toggleBtn.AutoButtonColor = false
toggleBtn.ZIndex = 3
toggleBtn.Parent = main
makeCorner(toggleBtn, 10)
makeStroke(toggleBtn, Color3.fromRGB(60, 200, 140), 1.2)

-- ── Rodapé ──
makeLabel(main, {
    text = "「🇧🇷」branzZ-Finder-Brainrot🧠  •  v3.0",
    size = 10,
    color = Color3.fromRGB(60, 45, 90),
    sz = UDim2.new(1, 0, 0, 16),
    pos = UDim2.new(0, 0, 1, -18),
    z = 3,
    align = Enum.TextXAlignment.Center,
})

-- ── Hovers ──
spawnBtn.MouseEnter:Connect(function()
    TweenService:Create(spawnBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(115, 80, 220) }):Play()
end)
spawnBtn.MouseLeave:Connect(function()
    TweenService:Create(spawnBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(90, 60, 190) }):Play()
end)
clearBtn.MouseEnter:Connect(function()
    TweenService:Create(clearBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(200, 70, 70) }):Play()
end)
clearBtn.MouseLeave:Connect(function()
    TweenService:Create(clearBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(160, 60, 60) }):Play()
end)
toggleBtn.MouseEnter:Connect(function()
    TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(55, 170, 125) }):Play()
end)
toggleBtn.MouseLeave:Connect(function()
    local c = billboardsVisible and Color3.fromRGB(40, 130, 100) or Color3.fromRGB(100, 50, 130)
    TweenService:Create(toggleBtn, TweenInfo.new(0.2), { BackgroundColor3 = c }):Play()
end)

-- ══════════════════════════════════════
-- LÓGICA
-- ══════════════════════════════════════

-- Preview ao sair do campo nome
inputName.FocusLost:Connect(function()
    local name = inputName.Text
    if name == "" then return end

    previewName.Text = "⏳ Buscando..."
    realBadge.Visible = false
    animBadge.Visible = false
    statusLabel.Text = "🔍 Buscando modelo e animação..."
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)

    task.spawn(function()
        local modelExists = findModelInRS(name) ~= nil
        local animExists  = findAnimationInRS(name) ~= nil
        realBadge.Visible = modelExists
        animBadge.Visible = animExists

        local img = fetchFandomImage(name)
        previewImg.Image = img or ""
        previewName.Text = name
        previewGen.Text = "Gen: " .. formatGen(parseGen(inputGen.Text))
        previewMut.Text = "Mut: " .. (inputMut.Text ~= "" and inputMut.Text or "None")
        previewTraits.Text = "Traits: " .. (inputTraits.Text ~= "" and inputTraits.Text or "None")

        if modelExists then
            statusLabel.Text = "✅ Modelo encontrado em RS!"
            statusLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
        elseif img then
            statusLabel.Text = "⚠️ Só imagem da wiki, sem modelo em RS"
            statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
        else
            statusLabel.Text = "⚠️ Não encontrado, vai usar placeholder"
            statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        end
    end)
end)

-- Atualiza preview de geração ao sair do campo
inputGen.FocusLost:Connect(function()
    local parsed = parseGen(inputGen.Text)
    previewGen.Text = "Gen: " .. formatGen(parsed)
    -- Normaliza o texto para exibição amigável
    if parsed > 0 then
        inputGen.Text = formatGen(parsed):gsub("/s", "")
    end
end)

-- Spawn
spawnBtn.MouseButton1Click:Connect(function()
    local name   = inputName.Text
    local genVal = parseGen(inputGen.Text)
    local mut    = inputMut.Text ~= "" and inputMut.Text or "None"
    local traits = inputTraits.Text ~= "" and inputTraits.Text or "None"

    if name == "" then
        statusLabel.Text = "⚠️ Coloca o nome do Brainrot!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
        return
    end

    statusLabel.Text = "⏳ Spawning..."
    statusLabel.TextColor3 = Color3.fromRGB(200, 200, 100)
    spawnBtn.Text = "⏳  Spawning..."
    spawnBtn.BackgroundColor3 = Color3.fromRGB(60, 40, 120)

    task.spawn(function()
        local model, err = spawnVisualBrainrot(name, mut, traits, genVal)

        if model then
            statusLabel.Text = "✅ " .. name .. " spawned!"
            statusLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
        else
            statusLabel.Text = err or "❌ Erro ao spawnar"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end

        task.wait(0.5)
        spawnBtn.Text = "✨  Spawn"
        spawnBtn.BackgroundColor3 = Color3.fromRGB(90, 60, 190)
    end)
end)

-- Limpar
clearBtn.MouseButton1Click:Connect(function()
    removeAllVisuals()
    statusLabel.Text = "🗑 Todos removidos!"
    statusLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
    task.wait(2)
    statusLabel.Text = ""
end)

-- Toggle Billboards (ativar/desativar GUI em cima dos brainrots)
toggleBtn.MouseButton1Click:Connect(function()
    billboardsVisible = not billboardsVisible
    setAllBillboardsVisible(billboardsVisible)

    if billboardsVisible then
        toggleBtn.Text = "👁 Ocultar Info dos Brainrots"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(40, 130, 100)
        makeStroke(toggleBtn, Color3.fromRGB(60, 200, 140), 1.2)
        statusLabel.Text = "👁 Info ativada!"
        statusLabel.TextColor3 = Color3.fromRGB(140, 220, 140)
    else
        toggleBtn.Text = "🙈 Mostrar Info dos Brainrots"
        toggleBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 130)
        makeStroke(toggleBtn, Color3.fromRGB(160, 80, 200), 1.2)
        statusLabel.Text = "🙈 Info ocultada!"
        statusLabel.TextColor3 = Color3.fromRGB(200, 160, 255)
    end

    task.wait(1.5)
    statusLabel.Text = ""
end)

print("[BranzZ] ✅ Spawn Visual v3.0 carregado!")
