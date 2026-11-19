-- EZEK v48.0
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

for _, obj in pairs(player:WaitForChild("PlayerGui"):GetChildren()) do
    if obj.Name:find("EZEK") then obj:Destroy() end
end
pcall(function() RunService:UnbindFromRenderStep("EZEK_CAM") end)

local ativo, espAtivo = false, false
local alvo, hpBar = nil, nil
local gyro = nil
local miraPeito = false
local alturaCam = 2.0
local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local espEl = {}
local alvosESP = {}

local function getVida(m)
    local h = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid", true)
    if h then return h.Health, h.MaxHealth end
    local hp = m:GetAttribute("Health") or m:GetAttribute("HP") or m:GetAttribute("Vida")
    if type(hp) == "number" then return hp, 100 end
    return nil, nil
end
local function temVida(m) local hp = getVida(m) return hp and hp > 0 end

local function pegarParte(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
        or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
        or m:FindFirstChild("Root") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
end

local function getTipo(m)
    if Players:GetPlayerFromCharacter(m) then return "players" end
    local n = string.lower(m.Name)
    if n:find("dummy") or n:find("training") or n:find("test") then return "dummies" end
    if m:FindFirstChildOfClass("Humanoid") or temVida(m) then return "monstros" end
    return "objetos"
end

local function getTodos()
    local lista, vistos = {}, {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then table.insert(lista, p.Character); vistos[p.Character]=true end
    end
    local function proc(pasta, prof)
        if prof > 5 then return end
        for _, v in pairs(pasta:GetChildren()) do
            if v:IsA("Model") and not vistos[v] and temVida(v) and pegarParte(v) then
                table.insert(lista, v); vistos[v]=true
            end
            if v:IsA("Folder") or v:IsA("Model") then proc(v, prof+1) end
        end
    end
    proc(workspace, 0)
    return lista
end

local function acharAlvo()
    local melhor, angMin = nil, math.rad(120)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in pairs(getTodos()) do
        if m ~= player.Character and filtros[getTipo(m)] and temVida(m) then
            local p = pegarParte(m)
            if p then
                local dist = (p.Position - cp).Magnitude
                if dist > 0.5 then 
                    local ang = math.acos(math.clamp(cl:Dot((p.Position - cp).Unit),-1,1))
                    if ang < angMin then
                        angMin = ang
                        melhor = m
                    end
                end
            end
        end
    end
    return melhor
end

local function pararLock()
    if not ativo then return end
    ativo = false; alvo = nil
    RunService:UnbindFromRenderStep("EZEK_CAM")
    if gyro then gyro:Destroy(); gyro = nil end
    if hpBar then hpBar:Destroy(); hpBar = nil end
    local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h then h.AutoRotate = true end
end

local function criarHPBar(m)
    if hpBar then hpBar:Destroy() end
    local root = pegarParte(m)
    if not root then return end
    hpBar = Instance.new("BillboardGui", m)
    hpBar.Adornee = root; hpBar.Size = UDim2.new(0, 150, 0, 45); hpBar.StudsOffset = Vector3.new(0, 3, 0); hpBar.AlwaysOnTop = true
    
    local nome = Instance.new("TextLabel", hpBar)
    nome.Size = UDim2.new(1,0,0,14); nome.BackgroundTransparency = 1; nome.Text = m.Name; nome.TextColor3 = Color3.new(1,1,1); nome.TextStrokeTransparency = 0; nome.Font = Enum.Font.GothamBold; nome.TextSize = 12
    
    local bg = Instance.new("Frame", hpBar)
    bg.Name = "BG"; bg.Size = UDim2.new(1,0,0,10); bg.Position = UDim2.new(0,0,0,16); bg.BackgroundColor3 = Color3.fromRGB(20,20,20); bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)
    
    local fill = Instance.new("Frame", bg)
    fill.Name = "Fill"; fill.Size = UDim2.new(1,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(0,200,0); fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    
    local hpTxt = Instance.new("TextLabel", hpBar)
    hpTxt.Name = "Txt"; hpTxt.Size = UDim2.new(1,0,0,14); hpTxt.Position = UDim2.new(0,0,0,28); hpTxt.BackgroundTransparency = 1; hpTxt.TextColor3 = Color3.new(1,1,1); hpTxt.TextStrokeTransparency = 0; hpTxt.Font = Enum.Font.GothamBold; hpTxt.TextSize = 11
end

local function atualizarLock()
    if not ativo or not alvo or not alvo.Parent or not temVida(alvo) then pararLock() return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local p = pegarParte(alvo)
    if not root or not h or not p then pararLock() return end

    if gyro then
        local targetPos = Vector3.new(p.Position.X, root.Position.Y, p.Position.Z)
        if (targetPos - root.Position).Magnitude > 0.1 then gyro.CFrame = CFrame.lookAt(root.Position, targetPos) end
    end
    
    h.AutoRotate = false
    camera.CameraType = Enum.CameraType.Custom
    if camera.CameraSubject ~= h then camera.CameraSubject = h end

    local miraPos = p.Position
    if miraPeito then
        local peito = alvo:FindFirstChild("UpperTorso") or alvo:FindFirstChild("Torso")
        if peito then miraPos = peito.Position end
    else
        local cabeca = alvo:FindFirstChild("Head")
        if cabeca then miraPos = cabeca.Position end
    end
    
    miraPos = miraPos + Vector3.new(0, alturaCam, 0)
    camera.CFrame = CFrame.lookAt(camera.CFrame.Position, miraPos)

    if hpBar then
        local hp, mx = getVida(alvo)
        if hp then
            local pct = math.clamp(hp/(mx or 100),0,1)
            local fill = hpBar.BG.Fill
            fill.Size = UDim2.new(pct,0,1,0)
            fill.BackgroundColor3 = pct>0.6 and Color3.fromRGB(0,200,0) or (pct>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50))
            hpBar.Txt.Text = string.format("%d/%d | %dm", math.floor(hp), math.floor(mx or 100), math.floor((p.Position - root.Position).Magnitude))
        end
    end
end

local function toggleLock()
    if ativo then pararLock() else
        local t = acharAlvo()
        if not t then print("❌ Sem alvo na mira.") return end
        alvo = t; ativo = true
        criarHPBar(t)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if gyro then gyro:Destroy() end
            gyro = Instance.new("BodyGyro", root)
            gyro.P = 100000; gyro.D = 1000; gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        end
        RunService:UnbindFromRenderStep("EZEK_CAM")
        RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizarLock)
    end
end

local espGui = Instance.new("ScreenGui", player.PlayerGui)
espGui.Name = "EZEK_ESP_Hub"; espGui.ResetOnSpawn = false; espGui.IgnoreGuiInset = true

local previewEl = nil
local previewAlvo = nil

local function limparPreview()
    if previewEl and previewEl.cont then previewEl.cont:Destroy() end
    previewEl = nil; previewAlvo = nil
end

local function criarPreview(m)
    limparPreview()
    local cont = Instance.new("Frame", espGui); cont.BackgroundTransparency = 1; cont.Visible = false
    cont.AnchorPoint = Vector2.new(0.5, 0.5)
    local st = Instance.new("UIStroke", cont); st.Color = Color3.fromRGB(0, 255, 0); st.Thickness = 2; st.Transparency = 0
    previewEl = {cont = cont, st = st}; previewAlvo = m
end

local lastEspDraw = 0
RunService.RenderStepped:Connect(function()
    if tick() - lastEspDraw < 0.03 then return end
    lastEspDraw = tick()

    local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local mp = r.Position

    if not ativo then
        local t = acharAlvo()
        if t ~= previewAlvo then
            if t then criarPreview(t) else limparPreview() end
        end
        if previewEl and previewAlvo and previewAlvo.Parent and previewAlvo ~= player.Character then
            local p = pegarParte(previewAlvo)
            if p then
                local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
                local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
                if top.Z > 0 and bot.Z > 0 then
                    local alt = math.abs(top.Y - bot.Y)
                    if alt > 5 then
                        local lar = alt * 0.55; local cx = (top.X + bot.X) / 2; local cy = (top.Y + bot.Y) / 2
                        previewEl.cont.Visible = true
                        previewEl.cont.Size = UDim2.new(0, lar, 0, alt)
                        previewEl.cont.Position = UDim2.new(0, cx, 0, cy)
                    else previewEl.cont.Visible = false end
                else previewEl.cont.Visible = false end
            end
        end
    end

    if espAtivo then
        for m, d in pairs(espEl) do
            if not m.Parent or not temVida(m) then
                d.cont:Destroy()
                espEl[m] = nil
            end
        end
        for _, m in pairs(getTodos()) do
            if filtros[getTipo(m)] and temVida(m) then
                local p = pegarParte(m)
                if p then
                    if not espEl[m] then
                        local cont = Instance.new("Frame", espGui); cont.BackgroundTransparency = 1
                        cont.AnchorPoint = Vector2.new(0.5, 0.5)
                        local st = Instance.new("UIStroke", cont)
                        local nm = Instance.new("TextLabel", cont); nm.BackgroundTransparency = 1; nm.Size = UDim2.new(1,0,0,14); nm.Position = UDim2.new(0,0,0,-16); nm.Font = Enum.Font.GothamBold; nm.TextSize = 10; nm.TextStrokeTransparency = 0; nm.Text = m.Name
                        local hp = Instance.new("TextLabel", cont); hp.BackgroundTransparency = 1; hp.Size = UDim2.new(1,0,0,14); hp.Position = UDim2.new(0,0,1,2); hp.Font = Enum.Font.GothamBold; hp.TextSize = 10; hp.TextStrokeTransparency = 0
                        espEl[m] = {cont=cont, st=st, nm=nm, hp=hp}
                    end
                    local d = espEl[m]
                    local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
                    local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
                    if top.Z > 0 and bot.Z > 0 then
                        local alt = math.abs(top.Y - bot.Y)
                        if alt > 5 then
                            local lar = alt * 0.55; local cx = (top.X + bot.X) / 2; local cy = (top.Y + bot.Y) / 2
                            d.cont.Visible = true
                            d.cont.Size = UDim2.new(0, lar, 0, alt); d.cont.Position = UDim2.new(0, cx, 0, cy)
                            local hVal, hMax = getVida(m)
                            local dist = math.floor((p.Position - r.Position).Magnitude)
                            if hVal then d.hp.Text = string.format("%d/%d | %dm", math.floor(hVal), math.floor(hMax or 100), dist) end
                        else d.cont.Visible = false end
                    else d.cont.Visible = false end
                end
            end
        end
    end
end)

local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "EZEK_GUI_v48"; sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 180, 0, 390); main.Position = UDim2.new(0, 20, 0.5, -195)
main.BackgroundColor3 = Color3.fromRGB(25, 25, 30); main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1, 0, 0, 36); title.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
title.Text = "🎯 EZEK v48.0"; title.TextColor3 = Color3.fromRGB(0, 255, 255); title.Font = Enum.Font.GothamBold; title.TextSize = 14
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local closeBtn = Instance.new("TextButton", title)
closeBtn.Size = UDim2.new(0, 30, 1, 0); closeBtn.Position = UDim2.new(1, -30, 0, 0)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeBtn.Text = "X"; closeBtn.TextColor3 = Color3.new(1,1,1)
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

local minBtn = Instance.new("TextButton", title)
minBtn.Size = UDim2.new(0, 30, 1, 0); minBtn.Position = UDim2.new(1, -60, 0, 0)
minBtn.BackgroundColor3 = Color3.fromRGB(200, 150, 50); minBtn.Text = "-"; minBtn.TextColor3 = Color3.new(1,1,1)
minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 8)

local floatingBtn = Instance.new("TextButton", sg)
floatingBtn.Size = UDim2.new(0, 44, 0, 44); floatingBtn.Position = UDim2.new(0, 20, 0, 100)
floatingBtn.BackgroundColor3 = Color3.fromRGB(25, 25, 30); floatingBtn.Text = "🎯"; floatingBtn.TextSize = 20
floatingBtn.TextColor3 = Color3.fromRGB(0, 255, 255)
floatingBtn.Visible = false
Instance.new("UICorner", floatingBtn).CornerRadius = UDim.new(1,0)

minBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    floatingBtn.Visible = true
end)

floatingBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    floatingBtn.Visible = false
end)

local dragging, dragStart, startPos
title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true; dragStart = input.Position; startPos = main.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

local function mkBtn(txt, y, cb)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(1,-20,0,35); b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = Color3.fromRGB(40,40,50); b.Text = txt; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
    return b
end

local bLock, bEsp

local function toggleLockManual()
    if ativo then
        pararLock()
        bLock.Text = "🔓 LOCK [K]: OFF"
        bLock.BackgroundColor3 = Color3.fromRGB(40,40,50)
    else
        local t = acharAlvo()
        if not t then return end
        alvo = t; ativo = true
        criarHPBar(t)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if gyro then gyro:Destroy() end
            gyro = Instance.new("BodyGyro", root)
            gyro.P = 100000; gyro.D = 1000; gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        end
        RunService:UnbindFromRenderStep("EZEK_CAM")
        RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizarLock)
        
        bLock.Text = "🔒 LOCK [K]: ON"
        bLock.BackgroundColor3 = Color3.fromRGB(0,150,0)
    end
end

local function toggleEspManual()
    espAtivo = not espAtivo
    bEsp.Text = espAtivo and "👁️ ESP [L]: ON" or "👁️ ESP [L]: OFF"
    bEsp.BackgroundColor3 = espAtivo and Color3.fromRGB(0,150,0) or Color3.fromRGB(40,40,50)
end

bLock = mkBtn("🔓 LOCK [K]: OFF", 45, toggleLockManual)
bEsp = mkBtn("👁️ ESP [L]: OFF", 85, toggleEspManual)

local bMira = mkBtn("🎯 MIRA: CABEÇA", 125, function()
    miraPeito = not miraPeito
    bMira.Text = miraPeito and "🎯 MIRA: PEITO" or "🎯 MIRA: CABEÇA"
    bMira.BackgroundColor3 = miraPeito and Color3.fromRGB(180,50,50) or Color3.fromRGB(40,40,50)
end)

local bCam = mkBtn("📷 INCLINAÇÃO: 2.0", 165, function()
    if alturaCam == 2.0 then alturaCam = 4.0
    elseif alturaCam == 4.0 then alturaCam = 6.0
    elseif alturaCam == 6.0 then alturaCam = 8.0
    else alturaCam = 2.0 end
    bCam.Text = "📷 INCLINAÇÃO: " .. tostring(alturaCam)
end)

local fTitle = Instance.new("TextLabel", main)
fTitle.Size = UDim2.new(1,0,0,20); fTitle.Position = UDim2.new(0,0,0,210); fTitle.BackgroundTransparency = 1
fTitle.Text = "Filtros:"; fTitle.TextColor3 = Color3.fromRGB(150,150,150); fTitle.Font = Enum.Font.GothamBold; fTitle.TextSize = 11

local function mkChk(txt, chave, y)
    local btn = Instance.new("TextButton", main)
    btn.Size = UDim2.new(0,20,0,20); btn.Position = UDim2.new(0,10,0,y)
    btn.BackgroundColor3 = filtros[chave] and Color3.fromRGB(0,150,0) or Color3.fromRGB(60,60,75)
    btn.Text = filtros[chave] and "✓" or ""; btn.TextColor3 = Color3.new(1,1,1); btn.Font = Enum.Font.GothamBold; btn.TextSize = 12
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,4)
    
    local lb = Instance.new("TextLabel", main)
    lb.Size = UDim2.new(1,-40,0,20); lb.Position = UDim2.new(0,36,0,y); lb.BackgroundTransparency = 1
    lb.Text = txt; lb.TextColor3 = Color3.new(1,1,1); lb.Font = Enum.Font.GothamMedium; lb.TextSize = 12; lb.TextXAlignment = Enum.TextXAlignment.Left
    
    lb.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then 
        filtros[chave] = not filtros[chave]
        btn.BackgroundColor3 = filtros[chave] and Color3.fromRGB(0,150,0) or Color3.fromRGB(60,60,75)
        btn.Text = filtros[chave] and "✓" or ""
    end end)
end

mkChk("👤 Players", "players", 235)
mkChk("🎯 Dummies", "dummies", 260)
mkChk("👹 Monstros", "monstros", 285)
mkChk("📦 Objetos", "objetos", 310)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then bLock:Activate() end
    if input.KeyCode == Enum.KeyCode.L then bEsp:Activate() end
end)

player.CharacterRemoving:Connect(function() if ativo then pararLock() end; limparPreview() end)

print("⚡ EZEK v48.0 Carregado.")
