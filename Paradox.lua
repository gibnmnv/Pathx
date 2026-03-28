local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- 安全等待
if not player:FindFirstChild("PlayerGui") then
    repeat task.wait() until player:FindFirstChild("PlayerGui")
end

--================================================================
-- 配置
--================================================================
local CONFIG = {
    ENTITY_LIST = {
        "Glare","Route","A90","Lookman","Giggle","Jamming"
    },
    DOOR_NAMES = {"Door","DOOR","Gate","Exit","NextRoom","MainDoor"},
    CARD_NAMES = {"Keycard","KeyCard","Card","AccessCard","Key"},
    GLARE_NAME = "Glare",
    ROUTE_NAME = "Route",
    ALERT_SOUND = "rbxassetid://6154027264",
    MAX_DIST = 1200,
    SCAN_INTERVAL = 1.2
}

local STATE = {
    AntiGlare = true,
    RouteAlert = true,
    EntityESP = true,
    DoorESP = true,
    CardESP = true,
}

local COLOR = {
    Accent = Color3.fromRGB(0,170,255),
    Door = Color3.fromRGB(0,255,120),
    Card = Color3.fromRGB(255,215,0),
    Text = Color3.fromRGB(220,220,220),
    BG = Color3.fromRGB(25,25,35),
}

-- 缓存
local cache = { entity = {}, door = {}, card = {} }
local lastScan = 0
local camera = workspace.CurrentCamera

--================================================================
-- 稳定创建 UI
--================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "Paradox_Sapphire"
ScreenGui.Parent = player.PlayerGui
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false -- 不掉UI

local UI = Instance.new("Frame")
UI.Size = UDim2.new(0, 320, 0, 440)
UI.Position = UDim2.new(0.05,0,0.1,0)
UI.BackgroundTransparency = 1
UI.Parent = ScreenGui

local BG = Instance.new("Frame")
BG.Size = UDim2.new(1,0,1,0)
BG.BackgroundColor3 = COLOR.BG
BG.BackgroundTransparency = 0.2
BG.CornerRadius = UDim.new(0,8)
BG.Parent = UI

local Title = Instance.new("TextLabel")
Title.Text = "🔮 Paradox | Sapphire"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = COLOR.Accent
Title.Size = UDim2.new(1,0,0,32)
Title.BackgroundTransparency = 1
Title.Parent = UI

local List = Instance.new("ScrollingFrame")
List.Position = UDim2.new(0,0,0,36)
List.Size = UDim2.new(1,0,1,-40)
List.BackgroundTransparency = 1
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.Parent = UI

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0,8)
Layout.Parent = List

-- 开关组件
local function AddToggle(text, default)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(1,0,0,34)
    Frame.BackgroundTransparency = 1
    Frame.Parent = List

    local Label = Instance.new("TextLabel")
    Label.Text = text
    Label.Position = UDim2.new(0,10,0,0)
    Label.Size = UDim2.new(0.7,0,1,0)
    Label.TextColor3 = COLOR.Text
    Label.TextSize = 14
    Label.BackgroundTransparency = 1
    Label.Parent = Frame

    local Button = Instance.new("TextButton")
    Button.Size = UDim2.new(0.2,0,0,22)
    Button.Position = UDim2.new(0.75,0,0,6)
    Button.BackgroundColor3 = default and Color3.new(0.12,0.12,0.18) or Color3.new(0.2,0.2,0.25)
    Button.TextColor3 = default and COLOR.Accent or Color3.new(0.6,0.6,0.6)
    Button.Text = default and "ON" or "OFF"
    Button.Font = Enum.Font.GothamBold
    Button.TextSize = 14
    Button.CornerRadius = UDim.new(0,4)
    Button.Parent = Frame

    local val = default
    Button.MouseButton1Click:Connect(function()
        val = not val
        Button.Text = val and "ON" or "OFF"
        Button.TextColor3 = val and COLOR.Accent or Color3.new(0.6,0.6,0.6)
        Button.BackgroundColor3 = val and Color3.new(0.12,0.12,0.18) or Color3.new(0.2,0.2,0.25)

        if text == "🚫 防 Glare" then STATE.AntiGlare = val
        elseif text == "🚨 Route 预警" then STATE.RouteAlert = val
        elseif text == "👹 实体透视" then STATE.EntityESP = val
        elseif text == "🚪 正确门透视" then STATE.DoorESP = val
        elseif text == "🔑 门禁卡透视" then STATE.CardESP = val
        end
    end)
end

AddToggle("🚫 防 Glare", true)
AddToggle("🚨 Route 预警", true)
AddToggle("👹 实体透视", true)
AddToggle("🚪 正确门透视", true)
AddToggle("🔑 门禁卡透视", true)

--================================================================
-- ESP 绘制（不闪、不卡、不崩）
--================================================================
local function NewESP(color)
    local f = Instance.new("Folder")
    local box = Instance.new("Frame")
    box.BackgroundTransparency = 1
    box.BorderColor3 = color
    box.BorderSizePixel = 1.4
    box.Visible = false
    box.Parent = f

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.TextColor3 = color
    label.TextSize = 14
    label.Font = Enum.Font.GothamBold
    label.Visible = false
    label.Parent = f

    return f, box, label
end

--================================================================
-- 智能扫描（换房间不卡）
--================================================================
local function Scan()
    local now = tick()
    if now - lastScan < CONFIG.SCAN_INTERVAL then return end
    lastScan = now

    -- 清空旧缓存，避免内存爆炸
    table.clear(cache.entity)
    table.clear(cache.door)
    table.clear(cache.card)

    for _, obj in ipairs(workspace:GetDescendants()) do
        if not obj:IsA("BasePart") then continue end

        -- 实体
        for _, name in ipairs(CONFIG.ENTITY_LIST) do
            if obj.Name == name or obj.Parent.Name == name then
                if not cache.entity[obj] then
                    local f,b,l = NewESP(COLOR.Accent)
                    f.Parent = ScreenGui
                    cache.entity[obj] = {b,l}
                end
            end
        end

        -- 门
        for _, kw in ipairs(CONFIG.DOOR_NAMES) do
            if string.find(obj.Name:lower(), kw:lower()) then
                if not cache.door[obj] then
                    local f,b,l = NewESP(COLOR.Door)
                    f.Parent = ScreenGui
                    cache.door[obj] = {b,l}
                end
            end
        end

        -- 门禁卡
        for _, kw in ipairs(CONFIG.CARD_NAMES) do
            if string.find(obj.Name:lower(), kw:lower()) then
                if not cache.card[obj] then
                    local f,b,l = NewESP(COLOR.Card)
                    f.Parent = ScreenGui
                    cache.card[obj] = {b,l}
                end
            end
        end
    end
end

--================================================================
-- 绘制逻辑（极轻量）
--================================================================
local function Draw(cacheTable, prefix)
    local char = player.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    for part, ui in pairs(cacheTable) do
        if not part or not part.Parent then
            cacheTable[part] = nil
            continue
        end

        local box, label = ui[1], ui[2]
        local pos2d, onScreen = camera:WorldToViewportPoint(part.Position)
        local dist = (root.Position - part.Position).Magnitude

        if onScreen and dist < CONFIG.MAX_DIST then
            local size = 2800 / dist
            box.Visible = true
            label.Visible = true
            box.Size = UDim2.new(0, size, 0, size * 1.4)
            box.Position = UDim2.new(0, pos2d.X - size/2, 0, pos2d.Y - size*0.7)
            label.Text = prefix .. math.floor(dist) .. "m"
            label.Position = UDim2.new(0, pos2d.X - 100, 0, pos2d.Y - size*0.7 - 22)
        else
            box.Visible = false
            label.Visible = false
        end
    end
end

--================================================================
-- 主循环（稳定、不掉线）
--================================================================
local lastAlert = 0
RunService.Heartbeat:Connect(function()
    camera = workspace.CurrentCamera
    Scan()

    -- 防 Glare
    if STATE.AntiGlare then
        local g = workspace:FindFirstChild(CONFIG.GLARE_NAME)
        if g and g.PrimaryPart then
            local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local d = (g.PrimaryPart.Position - root.Position).Magnitude
                if d < 110 then
                    local look = camera.CFrame.LookVector
                    local dir = (g.PrimaryPart.Position - root.Position).Unit
                    if look:Dot(dir) > 0.7 then
                        camera.CFrame *= CFrame.Angles(0, math.rad(7), 0)
                    end
                end
            end
        end
    end

    -- Route 提示
    if STATE.RouteAlert then
        if workspace:FindFirstChild(CONFIG.ROUTE_NAME) and tick() - lastAlert > 3 then
            lastAlert = tick()
            local s = Instance.new("Sound")
            s.SoundId = CONFIG.ALERT_SOUND
            s.Volume = 1
            s.Parent = camera
            s:Play()
            task.delay(2, function() s:Destroy() end)
        end
    end

    -- 透视
    if STATE.EntityESP then Draw(cache.entity, "") end
    if STATE.DoorESP then Draw(cache.door, "✅ 门 ") end
    if STATE.CardESP then Draw(cache.card, "🔑 卡 ") end
end)

-- 启动完成
print("✅ Paradox 加载成功 | 稳定运行中")
