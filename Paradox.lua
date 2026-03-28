local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ==========================================
-- 1. 核心配置与变量
-- ==========================================
local CONFIG = {
    GLARE_NAME = "Glare",
    ROUTE_NAME = "Route",
    WARNING_SOUND_ID = "rbxassetid://6154027264",
    MAX_CHECK_DISTANCE = 100,
    ESP_MAX_DISTANCE = 1500,
    DOOR_ESP_MAX_DISTANCE = 2000,

    ENTITY_LIST = {
        "Glare","Route","A90","Lookman","Giggle","Jamming"
    },

    -- 正确路线的门常用名称（可根据游戏自行添加）
    DOOR_NAMES = {
        "Door","MainDoor","Gate","Exit","NextRoom","CorrectDoor",
        "PrimaryDoor","Doorway","Entrance","ProgressDoor"
    }
}

local STATE = {
    AutoAvoidGlare = true,
    RouteWarning = true,
    EntityESP = true,
    DoorESP = true, -- 门透视开关
}

local THEME = {
    Background = Color3.fromRGB(25,25,35),
    Accent = Color3.fromRGB(0,170,255),
    Text = Color3.fromRGB(220,220,220),
    Disabled = Color3.fromRGB(120,120,130),
    DoorColor = Color3.fromRGB(0,255,120) -- 门用绿色，更清晰
}

local espCache = {}
local doorCache = {}

-- ==========================================
-- 2. UI 框架
-- ==========================================
local function createSapphireUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "SapphireMenu"
    screenGui.DisplayOrder = 10
    screenGui.Parent = player.PlayerGui

    local Container = Instance.new("Frame")
    Container.Name = "Container"
    Container.Position = UDim2.new(0.05,0,0.1,0)
    Container.Size = UDim2.new(0,320,0,450)
    Container.BackgroundTransparency = 1
    Container.Parent = screenGui

    local Background = Instance.new("Frame")
    Background.BackgroundColor3 = THEME.Background
    Background.BackgroundTransparency = 0.2
    Background.BorderSizePixel = 0
    Background.CornerRadius = UDim.new(0,8)
    Background.Size = UDim2.new(1,0,1,0)
    Background.Parent = Container

    local Title = Instance.new("TextLabel")
    Title.Text = "🔮 Sapphire | PARADOX"
    Title.Font = Enum.Font.GothamBold
    Title.TextSize = 18
    Title.TextColor3 = THEME.Accent
    Title.Size = UDim2.new(1,0,0,30)
    Title.BackgroundTransparency = 1
    Title.Parent = Container

    local TabHolder = Instance.new("Frame")
    TabHolder.Position = UDim2.new(0,0,0,35)
    TabHolder.Size = UDim2.new(1,0,0,30)
    TabHolder.BackgroundTransparency = 1
    TabHolder.Parent = Container

    local TabListLayout = Instance.new("UIListLayout")
    TabListLayout.FillDirection = Enum.FillDirection.Horizontal
    TabListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    TabListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    TabListLayout.Parent = TabHolder

    local PageHolder = Instance.new("Frame")
    PageHolder.Position = UDim2.new(0,0,0,70)
    PageHolder.Size = UDim2.new(1,0,1,-70)
    PageHolder.BackgroundTransparency = 1
    PageHolder.Parent = Container

    local Pages = Instance.new("Folder")
    Pages.Name = "Pages"
    Pages.Parent = PageHolder

    local tabButtons = {}

    local function addTab(name, content)
        local tab = Instance.new("TextButton")
        tab.Text = name
        tab.Font = Enum.Font.Gotham
        tab.TextSize =14
        tab.TextColor3 = THEME.Text
        tab.BackgroundColor3 = Color3.fromRGB(40,40,50)
        tab.Size = UDim2.new(0,100,1,0)
        tab.BorderSizePixel =0
        tab.CornerRadius = UDim.new(0,6)
        tab.Parent = TabHolder

        table.insert(tabButtons, tab)

        local page = Instance.new("ScrollingFrame")
        page.Name = name
        page.CanvasSize = UDim2.new(0,0,0,0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.ScrollBarThickness =6
        page.BackgroundTransparency =1
        page.Parent = Pages

        local layout = Instance.new("UIListLayout")
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page

        tab.MouseButton1Click:Connect(function()
            for _, pg in ip(Pages:GetChildren()) do pg.Visible = false end
            for _, tb in ip(tabButtons) do tb.BackgroundColor3 = Color3.fromRGB(40,40,50) end
            page.Visible = true
            tab.BackgroundColor3 = THEME.Accent
        end)

        if #tabButtons ==1 then
            page.Visible = true
            tab.BackgroundColor3 = THEME.Accent
        else
            page.Visible = false
        end

        return page
    end

    local function createToggle(parent, label, defaultState)
        local togFrame = Instance.new("Frame")
        togFrame.Name = label
        togFrame.Size = UDim2.new(1,0,0,28)
        togFrame.BackgroundTransparency =1
        togFrame.Parent = parent

        local lbl = Instance.new("TextLabel")
        lbl.Text = label
        lbl.TextSize =14
        lbl.TextColor3 = THEME.Text
        lbl.Position = UDim2.new(0,10,0,0)
        lbl.Size = UDim2.new(0.7,0,1,0)
        lbl.BackgroundTransparency =1
        lbl.Parent = togFrame

        local btn = Instance.new("TextButton")
        btn.Name = "ToggleBtn"
        btn.Text = defaultState and "ON" or "OFF"
        btn.TextColor3 = defaultState and THEME.Accent or THEME.Disabled
        btn.Font = Enum.Font.GothamBold
        btn.TextSize =14
        btn.Position = UDim2.new(0.75,0,0,4)
        btn.Size = UDim2.new(0.2,0,0,20)
        btn.BackgroundColor3 = defaultState and Color3.fromRGB(30,30,40) or Color3.fromRGB(50,50,60)
        btn.CornerRadius = UDim.new(0,4)
        btn.Parent = togFrame

        local currentState = defaultState

        btn.MouseButton1Click:Connect(function()
            currentState = not currentState
            btn.Text = currentState and "ON" or "OFF"
            btn.TextColor3 = currentState and THEME.Accent or THEME.Disabled
            btn.BackgroundColor3 = currentState and Color3.fromRGB(30,30,40) or Color3.fromRGB(50,50,60)

            if label == "防 Glare (自动转头)" then
                STATE.AutoAvoidGlare = currentState
            elseif label == "Route 预警通知" then
                STATE.RouteWarning = currentState
            elseif label == "实体ESP显示" then
                STATE.EntityESP = currentState
            elseif label == "正确路线门透视" then
                STATE.DoorESP = currentState
            end
        end)

        return btn
    end

    local HomePage = addTab("主页", "HomeContent")
    local FloorPage = addTab("楼层", "FloorContent")

    createToggle(HomePage, "防 Glare (自动转头)", true)
    createToggle(HomePage, "Route 预警通知", true)
    createToggle(HomePage, "实体ESP显示", true)
    createToggle(HomePage, "正确路线门透视", true) -- 新增门透视开关

    createToggle(FloorPage, "防 A90", false)
    createToggle(FloorPage, "防 Lookman", false)
    createToggle(FloorPage, "防 Giggle", false)
    createToggle(FloorPage, "防 Jamming", false)
end

-- ==========================================
-- ESP / 门透视 绘制
-- ==========================================
local function DrawEntityESP(entity)
    if espCache[entity] then return end
    local folder = Instance.new("Folder", player.PlayerGui.SapphireMenu)
    folder.Name = "ESP_"..entity.Name

    local box = Instance.new("Frame", folder)
    box.BackgroundTransparency =1
    box.BorderColor3 = THEME.Accent
    box.BorderSizePixel =1
    box.Visible = false

    local label = Instance.new("TextLabel", folder)
    label.BackgroundTransparency =1
    label.TextColor3 = THEME.Accent
    label.TextSize =14
    label.Font = Enum.Font.GothamBold
    label.Visible = false

    espCache[entity] = {box=box, label=label}
end

local function DrawDoorESP(door)
    if doorCache[door] then return end
    local folder = Instance.new("Folder", player.PlayerGui.SapphireMenu)
    folder.Name = "DoorESP_"..door.Name

    local box = Instance.new("Frame", folder)
    box.BackgroundTransparency =1
    box.BorderColor3 = THEME.DoorColor
    box.BorderSizePixel =2
    box.Visible = false

    local label = Instance.new("TextLabel", folder)
    label.BackgroundTransparency =1
    label.TextColor3 = THEME.DoorColor
    label.TextSize =14
    label.Font = Enum.Font.GothamBold
    label.Visible = false

    doorCache[door] = {box=box, label=label}
end

-- ==========================================
-- 3. 主逻辑 + 门透视
-- ==========================================
local function mainLogic()
    local camera = workspace.CurrentCamera
    if not camera then return end

    local lastAlertTime =0
    local alertCooldown =3

    local function getChar()
        return player.Character or player.CharacterAdded:Wait()
    end

    RunService.Heartbeat:Connect(function()
        local char = getChar()
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then return end

        -- 防 Glare
        if STATE.AutoAvoidGlare then
            local glare = workspace:FindFirstChild(CONFIG.GLARE_NAME)
            if glare and glare.PrimaryPart then
                local dist = (glare.PrimaryPart.Position - root.Position).Magnitude
                if dist < CONFIG.MAX_CHECK_DISTANCE then
                    local look = camera.CFrame.LookVector
                    local toEnt = (glare.PrimaryPart.Position - root.Position).Unit
                    if look:Dot(toEnt) >0.7 then
                        camera.CFrame *= CFrame.Angles(0, math.rad(8),0)
                    end
                end
            end
        end

        -- Route 预警
        if STATE.RouteWarning then
            local route = workspace:FindFirstChild(CONFIG.ROUTE_NAME)
            if route then
                local now = tick()
                if now - lastAlertTime > alertCooldown then
                    lastAlertTime = now
                    local snd = Instance.new("Sound")
                    snd.SoundId = CONFIG.WARNING_SOUND_ID
                    snd.Volume =1
                    snd.Parent = camera
                    snd:Play()
                    task.delay(2, function() snd:Destroy() end)
                end
            end
        end

        -- 实体 ESP
        if STATE.EntityESP then
            for _, name in pairs(CONFIG.ENTITY_LIST) do
                local ent = workspace:FindFirstChild(name)
                if not ent or not ent.PrimaryPart then continue end
                DrawEntityESP(ent)

                local part = ent.PrimaryPart
                local pos2d, onScreen = camera:WorldToViewportPoint(part.Position)
                local dist = (root.Position - part.Position).Magnitude
                local esp = espCache[ent]

                if onScreen and dist < CONFIG.ESP_MAX_DISTANCE then
                    local size = 2800/dist
                    esp.box.Visible = true
                    esp.label.Visible = true
                    esp.box.Size = UDim2.new(0,size,0,size*1.5)
                    esp.box.Position = UDim2.new(0,pos2d.X-size/2,0,pos2d.Y-size*0.75)
                    esp.label.Text = string.upper(ent.Name).."  ["..math.floor(dist).."m]"
                    esp.label.Position = UDim2.new(0,pos2d.X-100,0,pos2d.Y-size*0.75-24)
                else
                    esp.box.Visible = false
                    esp.label.Visible = false
                end
            end
        else
            for _, e in pairs(espCache) do e.box.Visible = false e.label.Visible = false end
        end

        -- ======================
        -- 正确路线门透视（核心）
        -- ======================
        if STATE.DoorESP then
            for _, part in pairs(workspace:GetDescendants()) do
                if not part:IsA("BasePart") then continue end
                local isDoor = false
                for _, kw in pairs(CONFIG.DOOR_NAMES) do
                    if string.find(part.Name:lower(), kw:lower()) then
                        isDoor = true
                        break
                    end
                end
                if not isDoor then continue end

                DrawDoorESP(part)
                local pos2d, onScreen = camera:WorldToViewportPoint(part.Position)
                local dist = (root.Position - part.Position).Magnitude
                local esp = doorCache[part]

                if onScreen and dist < CONFIG.DOOR_ESP_MAX_DISTANCE then
                    local size = 3000/dist
                    esp.box.Visible = true
                    esp.label.Visible = true
                    esp.box.Size = UDim2.new(0,size*1.2,0,size*2.2)
                    esp.box.Position = UDim2.new(0,pos2d.X-size*0.6,0,pos2d.Y-size*1.1)
                    esp.label.Text = "✅ 正确路线门 ["..math.floor(dist).."m]"
                    esp.label.Position = UDim2.new(0,pos2d.X-100,0,pos2d.Y-size*1.1-24)
                else
                    esp.box.Visible = false
                    esp.label.Visible = false
                end
            end
        else
            for _, d in pairs(doorCache) do d.box.Visible = false d.label.Visible = false end
        end
    end)
end

-- ==========================================
-- 启动
-- ==========================================
local success, err = pcall(function()
    createSapphireUI()
    mainLogic()
end)

if not success then
    warn("启动失败:", err)
end
