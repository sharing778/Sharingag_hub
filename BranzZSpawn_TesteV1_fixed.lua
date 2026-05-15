-- ╔══════════════════════════════════════════╗
-- ║    BRANZZ SPAWN VISUAL — v2.0            ║
-- ║       🧑‍💻 By BranZZ MetoDos 🚀            ║
-- ╚══════════════════════════════════════════╝

local TweenService      = game:GetService("TweenService")
local CoreGui           = game:GetService("CoreGui")
local Players           = game:GetService("Players")
local HttpService       = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace         = game:GetService("Workspace")
local UserInputService  = game:GetService("UserInputService")

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
-- UTILS
-- ══════════════════════════════════════
local function formatGen(val)
    if val >= 1000000000 then
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
-- BUSCA MODELO REAL DO BRAINROT NO JOGO
-- ══════════════════════════════════════
local function findRealBrainrotModel(name)
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end

    -- Procura em TODOS os plots (não só o seu)
    for _, plot in ipairs(plots:GetChildren()) do
        local podiums = plot:FindFirstChild("AnimalPodiums")
        if podiums then
            for _, podium in ipairs(podiums:GetChildren()) do
                local base = podium:FindFirstChild("Base")
                if base then
                    local spawn = base:FindFirstChild("Spawn") or base
                    -- Procura modelo com nome parecido
                    for _, child in ipairs(spawn:GetChildren()) do
                        if child:IsA("Model") or child:IsA("BasePart") then
                            local childName = child.Name:lower():gsub("%s+","")
                            local searchName = name:lower():gsub("%s+","")
                            if childName:find(searchName, 1, true) or searchName:find(childName, 1, true) then
                                return child
                            end
                        end
                    end
                    -- Procura pelo BillboardGui que tem o nome
                    for _, child in ipairs(spawn:GetDescendants()) do
                        if child:IsA("TextLabel") then
                            local txt = (child.Text or ""):lower()
                            if txt:find(name:lower(), 1, true) then
                                -- Pega o modelo pai
                                local parent = child.Parent
                                while parent and parent ~= spawn do
                                    if parent:IsA("Model") then return parent end
                                    parent = parent.Parent
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

-- Busca usando o Synchronizer pra achar o slot do brainrot pelo nome
local function findBrainrotSlotAndPlot(name)
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil, nil end

    for _, plot in ipairs(plots:GetChildren()) do
        pcall(function()
            local channel = require(ReplicatedStorage.Packages.Synchronizer):Get(plot.Name)
            if not channel then return end
            local animalList = channel:Get("AnimalList")
            if not animalList then return end

            for slot, animalData in pairs(animalList) do
                if type(animalData) ~= "table" or not animalData.Index then continue end
                local info = AnimalsData and AnimalsData[animalData.Index]
                if not info then continue end
                local displayName = (info.DisplayName or animalData.Index):lower()
                if displayName:find(name:lower(), 1, true) then
                    return plot, tostring(slot)
                end
            end
        end)
    end
    return nil, nil
end

-- Busca o modelo 3D real do podium pelo slot
local function getRealModelFromPodium(plot, slot)
    if not plot or not slot then return nil end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    local podium = podiums:FindFirstChild(slot)
    if not podium then return nil end
    local base = podium:FindFirstChild("Base")
    if not base then return nil end
    local spawn = base:FindFirstChild("Spawn") or base

    for _, child in ipairs(spawn:GetChildren()) do
        if child:IsA("Model") and #child:GetChildren() > 0 then
            return child
        end
    end
    -- Tenta pegar direto do base
    for _, child in ipairs(base:GetChildren()) do
        if child:IsA("Model") and child.Name ~= "Spawn" then
            return child
        end
    end
    return nil
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
-- SPAWN COM MODELO REAL
-- ══════════════════════════════════════
local spawnedBrainrots = {}

local function findMyPlotBase()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil, nil end

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
                      or plot:FindFirstChildWhichIsA("BasePart")
            return plot, base
        end
    end

    -- Fallback
    local p = plots:FindFirstChild(localPlayer.Name) or plots:GetChildren()[1]
    return p, p and (p:FindFirstChild("Base") or p:FindFirstChildWhichIsA("BasePart") or p)
end

local function spawnVisualBrainrot(name, mutation, traits, genVal)
    local myPlot, myBase = findMyPlotBase()

    -- Tenta achar o modelo real do brainrot em qualquer plot
    local realModel = findRealBrainrotModel(name)

    -- Posição de spawn na base
    local spawnPos = Vector3.new(0, 10, 0)
    if myBase then
        if myBase:IsA("Model") and myBase.PrimaryPart then
            spawnPos = myBase.PrimaryPart.Position + Vector3.new(math.random(-10,10), 3, math.random(-10,10))
        elseif myBase:IsA("BasePart") then
            spawnPos = myBase.Position + Vector3.new(math.random(-10,10), 3, math.random(-10,10))
        end
    end

    local container = Instance.new("Model")
    container.Name = "BRANZZ_VISUAL_" .. name:gsub(" ","_") .. "_" .. tostring(os.time())
    container.Parent = myPlot or Workspace

    if realModel then
        -- Clona o modelo real do jogo
        local clone = realModel:Clone()
        clone.Name = name
        clone.Parent = container

        -- Posiciona o clone
        pcall(function()
            if clone:IsA("Model") and clone.PrimaryPart then
                clone:SetPrimaryPartCFrame(CFrame.new(spawnPos))
            elseif clone:IsA("BasePart") then
                clone.CFrame = CFrame.new(spawnPos)
                clone.Anchored = true
            end
        end)

        print("[BranzZ] ✅ Modelo real encontrado e clonado: " .. name)
    else
        -- Fallback: cria um part com aparência boa
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

        print("[BranzZ] ⚠️ Modelo real não encontrado, usando placeholder: " .. name)
    end

    -- Billboard com infos (sempre adicionado)
    local primaryPart = nil
    pcall(function()
        if container:IsA("Model") and container.PrimaryPart then
            primaryPart = container.PrimaryPart
        else
            primaryPart = container:FindFirstChildWhichIsA("BasePart", true)
        end
    end)

    if primaryPart then
        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0,220,0,130)
        billboard.StudsOffset = Vector3.new(0,4,0)
        billboard.AlwaysOnTop = false
        billboard.Parent = primaryPart

        local bg = Instance.new("Frame")
        bg.Size = UDim2.new(1,0,1,0)
        bg.BackgroundColor3 = Color3.fromRGB(13,11,22)
        bg.BackgroundTransparency = 0.15
        bg.BorderSizePixel = 0
        bg.Parent = billboard
        local bgc = Instance.new("UICorner")
        bgc.CornerRadius = UDim.new(0,10)
        bgc.Parent = bg
        local bgs = Instance.new("UIStroke")
        bgs.Color = Color3.fromRGB(150,100,240)
        bgs.Thickness = 1.5
        bgs.Parent = bg

        local topB = Instance.new("Frame")
        topB.Size = UDim2.new(1,0,0,3)
        topB.BackgroundColor3 = Color3.fromRGB(160,100,255)
        topB.BorderSizePixel = 0
        topB.Parent = bg
        local topBc = Instance.new("UICorner")
        topBc.CornerRadius = UDim.new(0,3)
        topBc.Parent = topB

        local nameL = Instance.new("TextLabel")
        nameL.Size = UDim2.new(1,-10,0,26)
        nameL.Position = UDim2.new(0,5,0,6)
        nameL.BackgroundTransparency = 1
        nameL.Text = "👑 " .. name
        nameL.TextColor3 = Color3.fromRGB(220,185,255)
        nameL.TextSize = 14
        nameL.Font = Enum.Font.GothamBold
        nameL.TextWrapped = true
        nameL.Parent = bg

        local genL = Instance.new("TextLabel")
        genL.Size = UDim2.new(1,-10,0,20)
        genL.Position = UDim2.new(0,5,0,34)
        genL.BackgroundTransparency = 1
        genL.Text = "💰 " .. formatGen(genVal)
        genL.TextColor3 = Color3.fromRGB(140,230,140)
        genL.TextSize = 13
        genL.Font = Enum.Font.Gotham
        genL.Parent = bg

        local mutL = Instance.new("TextLabel")
        mutL.Size = UDim2.new(1,-10,0,20)
        mutL.Position = UDim2.new(0,5,0,56)
        mutL.BackgroundTransparency = 1
        mutL.Text = "🧬 Mut: " .. mutation
        mutL.TextColor3 = Color3.fromRGB(255,205,100)
        mutL.TextSize = 12
        mutL.Font = Enum.Font.Gotham
        mutL.Parent = bg

        local traitL = Instance.new("TextLabel")
        traitL.Size = UDim2.new(1,-10,0,30)
        traitL.Position = UDim2.new(0,5,0,78)
        traitL.BackgroundTransparency = 1
        traitL.Text = "⭐ " .. traits
        traitL.TextColor3 = Color3.fromRGB(170,210,255)
        traitL.TextSize = 11
        traitL.Font = Enum.Font.Gotham
        traitL.TextWrapped = true
        traitL.Parent = bg

        -- Animação hover billboard
        task.spawn(function()
            local t = 0
            while billboard.Parent do
                t = t + 0.05
                billboard.StudsOffset = Vector3.new(0, 4 + math.sin(t) * 0.3, 0)
                task.wait(0.05)
            end
        end)
    end

    table.insert(spawnedBrainrots, container)
    return container
end

local function removeAllVisuals()
    for _, model in ipairs(spawnedBrainrots) do
        pcall(function() model:Destroy() end)
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
    s.Color = color or Color3.fromRGB(180,160,220)
    s.Thickness = thickness or 1.5
    s.Parent = parent
    return s
end

local function makeLabel(parent, props)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Font = props.font or Enum.Font.Gotham
    l.TextColor3 = props.color or Color3.fromRGB(220,210,240)
    l.TextSize = props.size or 13
    l.Text = props.text or ""
    l.Size = props.sz or UDim2.new(1,0,0,22)
    l.Position = props.pos or UDim2.new(0,0,0,0)
    l.ZIndex = props.z or 3
    l.TextXAlignment = props.align or Enum.TextXAlignment.Left
    l.TextWrapped = true
    l.Parent = parent
    return l
end

local function makeInput(parent, placeholder, ypos, z)
    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1,-20,0,36)
    bg.Position = UDim2.new(0,10,0,ypos)
    bg.BackgroundColor3 = Color3.fromRGB(22,18,36)
    bg.BorderSizePixel = 0
    bg.ZIndex = z or 3
    bg.Parent = parent
    makeCorner(bg, 8)
    makeStroke(bg, Color3.fromRGB(90,70,150), 1.2)

    local input = Instance.new("TextBox")
    input.Size = UDim2.new(1,-16,1,0)
    input.Position = UDim2.new(0,8,0,0)
    input.BackgroundTransparency = 1
    input.Text = ""
    input.PlaceholderText = placeholder
    input.TextColor3 = Color3.fromRGB(215,205,240)
    input.PlaceholderColor3 = Color3.fromRGB(90,75,130)
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
-- UI
-- ══════════════════════════════════════
local sg = Instance.new("ScreenGui")
sg.Name = "BRANZZ_SPAWN_UI"
sg.ResetOnSpawn = false
sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
sg.IgnoreGuiInset = true
sg.Parent = CoreGui

local main = Instance.new("Frame")
main.Size = UDim2.new(0,320,0,490)
main.Position = UDim2.new(0.5,-160,0.5,-245)
main.BackgroundColor3 = Color3.fromRGB(13,11,22)
main.BorderSizePixel = 0
main.ZIndex = 2
main.Parent = sg
makeCorner(main, 20)
makeStroke(main, Color3.fromRGB(150,120,220), 1.5)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18,14,32)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10,8,18)),
})
grad.Rotation = 135
grad.Parent = main

local topBarLine = Instance.new("Frame")
topBarLine.Size = UDim2.new(1,0,0,4)
topBarLine.BackgroundColor3 = Color3.fromRGB(160,100,255)
topBarLine.BorderSizePixel = 0
topBarLine.ZIndex = 3
topBarLine.Parent = main
makeCorner(topBarLine, 4)

local header = Instance.new("Frame")
header.Size = UDim2.new(1,0,0,50)
header.BackgroundColor3 = Color3.fromRGB(20,16,36)
header.BorderSizePixel = 0
header.ZIndex = 3
header.Parent = main
makeCorner(header, 20)

local headerFix = Instance.new("Frame")
headerFix.Size = UDim2.new(1,0,0,20)
headerFix.Position = UDim2.new(0,0,1,-20)
headerFix.BackgroundColor3 = Color3.fromRGB(20,16,36)
headerFix.BorderSizePixel = 0
headerFix.ZIndex = 3
headerFix.Parent = header

makeDrag(main, header)

makeLabel(header, {
    text = "🧠 BranzZ Spawn Visual",
    font = Enum.Font.GothamBold,
    size = 15,
    color = Color3.fromRGB(210,185,255),
    sz = UDim2.new(1,-80,0,22),
    pos = UDim2.new(0,14,0,8),
    z = 4,
})
makeLabel(header, {
    text = "By BranZZ MetoDos  •  v2.0",
    size = 11,
    color = Color3.fromRGB(110,90,160),
    sz = UDim2.new(1,-80,0,16),
    pos = UDim2.new(0,14,0,30),
    z = 4,
})

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0,28,0,28)
closeBtn.Position = UDim2.new(1,-38,0.5,-14)
closeBtn.BackgroundColor3 = Color3.fromRGB(180,60,60)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Color3.fromRGB(255,220,220)
closeBtn.TextSize = 14
closeBtn.Font = Enum.Font.GothamBold
closeBtn.BorderSizePixel = 0
closeBtn.AutoButtonColor = false
closeBtn.ZIndex = 5
closeBtn.Parent = header
makeCorner(closeBtn, 8)
closeBtn.MouseButton1Click:Connect(function()
    TweenService:Create(main, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
        {BackgroundTransparency=1}):Play()
    task.wait(0.35)
    sg:Destroy()
end)

-- Preview
local previewFrame = Instance.new("Frame")
previewFrame.Size = UDim2.new(1,-20,0,100)
previewFrame.Position = UDim2.new(0,10,0,58)
previewFrame.BackgroundColor3 = Color3.fromRGB(20,15,35)
previewFrame.BorderSizePixel = 0
previewFrame.ZIndex = 3
previewFrame.Parent = main
makeCorner(previewFrame, 12)
makeStroke(previewFrame, Color3.fromRGB(80,55,140), 1.2)

local previewImg = Instance.new("ImageLabel")
previewImg.Size = UDim2.new(0,88,0,88)
previewImg.Position = UDim2.new(0,6,0.5,-44)
previewImg.BackgroundColor3 = Color3.fromRGB(30,20,50)
previewImg.Image = ""
previewImg.ScaleType = Enum.ScaleType.Fit
previewImg.ZIndex = 4
previewImg.Parent = previewFrame
makeCorner(previewImg, 10)

local previewName = makeLabel(previewFrame, {
    text = "Nome do Brainrot",
    font = Enum.Font.GothamBold,
    size = 13,
    color = Color3.fromRGB(200,175,245),
    sz = UDim2.new(1,-105,0,20),
    pos = UDim2.new(0,100,0,8),
    z = 4,
})
local previewGen = makeLabel(previewFrame, {
    text = "Gen: —",
    size = 12,
    color = Color3.fromRGB(140,220,140),
    sz = UDim2.new(1,-105,0,18),
    pos = UDim2.new(0,100,0,30),
    z = 4,
})
local previewMut = makeLabel(previewFrame, {
    text = "Mut: —",
    size = 11,
    color = Color3.fromRGB(255,200,100),
    sz = UDim2.new(1,-105,0,18),
    pos = UDim2.new(0,100,0,50),
    z = 4,
})
local previewTraits = makeLabel(previewFrame, {
    text = "Traits: —",
    size = 10,
    color = Color3.fromRGB(160,200,255),
    sz = UDim2.new(1,-105,0,18),
    pos = UDim2.new(0,100,0,70),
    z = 4,
})

-- Badge modelo real
local realBadge = Instance.new("TextLabel")
realBadge.Size = UDim2.new(0,80,0,16)
realBadge.Position = UDim2.new(0,6,0,6)
realBadge.BackgroundColor3 = Color3.fromRGB(40,160,80)
realBadge.BackgroundTransparency = 0.3
realBadge.Text = "✅ Real"
realBadge.TextColor3 = Color3.fromRGB(180,255,180)
realBadge.TextSize = 10
realBadge.Font = Enum.Font.GothamBold
realBadge.ZIndex = 5
realBadge.Visible = false
realBadge.Parent = previewFrame
makeCorner(realBadge, 4)

local div1 = Instance.new("Frame")
div1.Size = UDim2.new(0.88,0,0,1)
div1.Position = UDim2.new(0.06,0,0,166)
div1.BackgroundColor3 = Color3.fromRGB(55,40,88)
div1.BorderSizePixel = 0
div1.ZIndex = 3
div1.Parent = main

makeLabel(main, {
    text = "Nome do Brainrot",
    size = 12,
    color = Color3.fromRGB(170,145,215),
    sz = UDim2.new(1,-20,0,16),
    pos = UDim2.new(0,10,0,175),
    z = 3,
})
local inputName, _ = makeInput(main, "Ex: Capitano Moby", 192, 3)

makeLabel(main, {
    text = "Geração /s (ex: 4000000000 = 4B)",
    size = 12,
    color = Color3.fromRGB(170,145,215),
    sz = UDim2.new(1,-20,0,16),
    pos = UDim2.new(0,10,0,235),
    z = 3,
})
local inputGen, _ = makeInput(main, "Ex: 4000000000", 252, 3)

makeLabel(main, {
    text = "Mutação",
    size = 12,
    color = Color3.fromRGB(170,145,215),
    sz = UDim2.new(1,-20,0,16),
    pos = UDim2.new(0,10,0,295),
    z = 3,
})
local inputMut, _ = makeInput(main, "Ex: Gold, Rainbow, Shiny...", 312, 3)

makeLabel(main, {
    text = "Traits (separe por vírgula)",
    size = 12,
    color = Color3.fromRGB(170,145,215),
    sz = UDim2.new(1,-20,0,16),
    pos = UDim2.new(0,10,0,355),
    z = 3,
})
local inputTraits, _ = makeInput(main, "Ex: Taco, Fire, Nyan Cat", 372, 3)

local div2 = Instance.new("Frame")
div2.Size = UDim2.new(0.88,0,0,1)
div2.Position = UDim2.new(0.06,0,0,416)
div2.BackgroundColor3 = Color3.fromRGB(55,40,88)
div2.BorderSizePixel = 0
div2.ZIndex = 3
div2.Parent = main

local statusLabel = makeLabel(main, {
    text = "",
    size = 12,
    color = Color3.fromRGB(140,220,140),
    sz = UDim2.new(1,-20,0,16),
    pos = UDim2.new(0,10,0,420),
    z = 3,
    align = Enum.TextXAlignment.Center,
})

local spawnBtn = Instance.new("TextButton")
spawnBtn.Size = UDim2.new(0.55,0,0,40)
spawnBtn.Position = UDim2.new(0.06,0,0,442)
spawnBtn.BackgroundColor3 = Color3.fromRGB(90,60,190)
spawnBtn.Text = "✨  Spawn"
spawnBtn.TextColor3 = Color3.fromRGB(240,230,255)
spawnBtn.TextSize = 15
spawnBtn.Font = Enum.Font.GothamBold
spawnBtn.BorderSizePixel = 0
spawnBtn.AutoButtonColor = false
spawnBtn.ZIndex = 3
spawnBtn.Parent = main
makeCorner(spawnBtn, 12)
makeStroke(spawnBtn, Color3.fromRGB(150,100,255), 1.5)

local clearBtn = Instance.new("TextButton")
clearBtn.Size = UDim2.new(0.32,0,0,40)
clearBtn.Position = UDim2.new(0.63,0,0,442)
clearBtn.BackgroundColor3 = Color3.fromRGB(160,60,60)
clearBtn.Text = "🗑 Limpar"
clearBtn.TextColor3 = Color3.fromRGB(255,220,220)
clearBtn.TextSize = 14
clearBtn.Font = Enum.Font.GothamBold
clearBtn.BorderSizePixel = 0
clearBtn.AutoButtonColor = false
clearBtn.ZIndex = 3
clearBtn.Parent = main
makeCorner(clearBtn, 12)
makeStroke(clearBtn, Color3.fromRGB(220,80,80), 1.5)

makeLabel(main, {
    text = "「🇧🇷」branzZ-Finder-Brainrot🧠  •  v2.0",
    size = 10,
    color = Color3.fromRGB(60,45,90),
    sz = UDim2.new(1,0,0,16),
    pos = UDim2.new(0,0,1,-18),
    z = 3,
    align = Enum.TextXAlignment.Center,
})

spawnBtn.MouseEnter:Connect(function()
    TweenService:Create(spawnBtn, TweenInfo.new(0.2), {BackgroundColor3=Color3.fromRGB(115,80,220)}):Play()
end)
spawnBtn.MouseLeave:Connect(function()
    TweenService:Create(spawnBtn, TweenInfo.new(0.2), {BackgroundColor3=Color3.fromRGB(90,60,190)}):Play()
end)
clearBtn.MouseEnter:Connect(function()
    TweenService:Create(clearBtn, TweenInfo.new(0.2), {BackgroundColor3=Color3.fromRGB(200,70,70)}):Play()
end)
clearBtn.MouseLeave:Connect(function()
    TweenService:Create(clearBtn, TweenInfo.new(0.2), {BackgroundColor3=Color3.fromRGB(160,60,60)}):Play()
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
    statusLabel.Text = "🔍 Buscando imagem e modelo..."
    statusLabel.TextColor3 = Color3.fromRGB(200,200,100)

    task.spawn(function()
        -- Verifica se modelo real existe
        local realExists = findRealBrainrotModel(name) ~= nil
        realBadge.Visible = realExists

        -- Busca imagem
        local img = fetchFandomImage(name)
        previewImg.Image = img or ""
        previewName.Text = name
        previewGen.Text = "Gen: " .. formatGen(tonumber(inputGen.Text) or 0)
        previewMut.Text = "Mut: " .. (inputMut.Text ~= "" and inputMut.Text or "None")
        previewTraits.Text = "Traits: " .. (inputTraits.Text ~= "" and inputTraits.Text or "None")

        if realExists then
            statusLabel.Text = "✅ Modelo real encontrado!"
            statusLabel.TextColor3 = Color3.fromRGB(140,220,140)
        elseif img then
            statusLabel.Text = "⚠️ Só imagem encontrada, sem modelo real"
            statusLabel.TextColor3 = Color3.fromRGB(255,180,80)
        else
            statusLabel.Text = "⚠️ Nada encontrado, vai usar placeholder"
            statusLabel.TextColor3 = Color3.fromRGB(255,120,120)
        end
    end)
end)

-- Spawn
spawnBtn.MouseButton1Click:Connect(function()
    local name   = inputName.Text
    local genVal = tonumber(inputGen.Text) or 0
    local mut    = inputMut.Text ~= "" and inputMut.Text or "None"
    local traits = inputTraits.Text ~= "" and inputTraits.Text or "None"

    if name == "" then
        statusLabel.Text = "⚠️ Coloca o nome do Brainrot!"
        statusLabel.TextColor3 = Color3.fromRGB(255,120,120)
        return
    end

    statusLabel.Text = "⏳ Spawning..."
    statusLabel.TextColor3 = Color3.fromRGB(200,200,100)
    spawnBtn.Text = "⏳  Spawning..."
    spawnBtn.BackgroundColor3 = Color3.fromRGB(60,40,120)

    task.spawn(function()
        local model = spawnVisualBrainrot(name, mut, traits, genVal)

        if model then
            statusLabel.Text = "✅ " .. name .. " spawned!"
            statusLabel.TextColor3 = Color3.fromRGB(140,220,140)
        else
            statusLabel.Text = "❌ Erro ao spawnar"
            statusLabel.TextColor3 = Color3.fromRGB(255,100,100)
        end

        task.wait(0.5)
        spawnBtn.Text = "✨  Spawn"
        spawnBtn.BackgroundColor3 = Color3.fromRGB(90,60,190)
    end)
end)

-- Limpar
clearBtn.MouseButton1Click:Connect(function()
    removeAllVisuals()
    statusLabel.Text = "🗑 Todos removidos!"
    statusLabel.TextColor3 = Color3.fromRGB(255,180,80)
    task.wait(2)
    statusLabel.Text = ""
end)

print("[BranzZ] ✅ Spawn Visual v2.0 carregado!")
