-- EZEK v15.0 (Controle 100% Liberado para o Jogo) — MAPEAMENTO CORRIGIDO
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
for _, obj in pairs(player:WaitForChild("PlayerGui"):GetChildren()) do
    if obj.Name:find("EZEK") then obj:Destroy() end
end
pcall(function() RunService:UnbindFromRenderStep("EZEK_CAM") end)
local VERSAO = "v15.0"
local FOV_GRAUS = 120 
local ativo, alvo, espAtivo = false, nil, false
local modoFantasma = true 
local gyro = nil
local hpBar = nil
local miraPeito = false
local alturaCam = 2.0
local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local espEl = {}
local alvosCache = {}
local bLock, bEsp, bMira, bCam, bFantasma
-- ⚡ CACHES (evitam re-buscar Humanoid/Parte/Tipo a cada frame = menos lag)
local cacheHumanoid = {}
local cacheParte    = {}
local cacheTipo     = {}
local function getHumanoid(m)
    local h = cacheHumanoid[m]
    if h and h.Parent then return h end
    h = m:FindFirstChildOfClass("Humanoid") or m:FindFirstChildWhichIsA("Humanoid", true)
    if h then cacheHumanoid[m] = h end
    return h
end
local function getVida(m)
    local h = getHumanoid(m)
    if h then return h.Health, h.MaxHealth end
    local hp = m:GetAttribute("Health") or m:GetAttribute("HP") or m:GetAttribute("Vida")
    if type(hp) == "number" then return hp, 100 end
    return nil, nil
end
local function temVida(m) local hp = getVida(m) return hp and hp > 0 end
local function pegarParte(m)
    if not m then return nil end
    local p = cacheParte[m]
    if p and p.Parent then return p end
    if m:IsA("BasePart") then
        p = m
    else
        p = m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart")
            or m:FindFirstChild("UpperTorso") or m:FindFirstChild("Torso")
            or m:FindFirstChild("Root") or m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart")
    end
    if p then cacheParte[m] = p end
    return p
end
local function getTipo(m)
    local t = cacheTipo[m]
    if t then return t end
    if Players:GetPlayerFromCharacter(m) then
        t = "players"
    else
        local n = string.lower(m.Name)
        if n:find("dummy") or n:find("training") or n:find("test") then
            t = "dummies"
        elseif m:FindFirstChildOfClass("Humanoid") or temVida(m) then
            t = "monstros"
        else
            t = "objetos"
        end
    end
    cacheTipo[m] = t
    return t
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
task.spawn(function()
    while true do
        alvosCache = getTodos()
        task.wait(3)
        -- limpa os caches a cada ciclo pra não acumular lixo/memória
        cacheHumanoid = {}
        cacheParte = {}
        cacheTipo = {}
    end
end)
local function acharAlvo()
    local melhor, melhorAng = nil, math.rad(FOV_GRAUS)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in pairs(alvosCache) do
        if m ~= player.Character and filtros[getTipo(m)] and temVida(m) then
            local parte = pegarParte(m)
            if parte then
                local dist = (parte.Position - cp).Magnitude
                if dist > 0.5 then 
                    local dir = (parte.Position - cp).Unit
                    local ang = math.acos(math.clamp(cl:Dot(dir),-1,1))
                    if ang < melhorAng then
                        melhorAng = ang
                        melhor = m
                    end
                end
            end
        end
    end
    return melhor
end
local function criarHPBar(m)
    if hpBar and hpBar.Parent then hpBar:Destroy() end
    local root = pegarParte(m)
    if not root then return end
    local bb = Instance.new("BillboardGui", m)
    bb.Adornee = root; bb.Size = UDim2.new(0, 150, 0, 45); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
    hpBar = bb
    
    local nome = Instance.new("TextLabel", bb)
    nome.Name = "N"; nome.Size = UDim2.new(1,0,0,14); nome.Position = UDim2.new(0,0,0,0)
    nome.BackgroundTransparency = 1; nome.Text = m.Name; nome.TextColor3 = Color3.new(1,1,1)
    nome.TextStrokeTransparency = 0; nome.Font = Enum.Font.GothamBold; nome.TextSize = 12
    nome.TextXAlignment = Enum.TextXAlignment.Center
    local bg = Instance.new("Frame", bb)
    bg.Name = "B"; bg.Size = UDim2.new(1,0,0,10); bg.Position = UDim2.new(0,0,0,16)
    bg.BackgroundColor3 = Color3.fromRGB(20,20,20); bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)
    
    local fill = Instance.new("Frame", bg)
    fill.Name = "F"; fill.Size = UDim2.new(1,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(0,200,0); fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local hpText = Instance.new("TextLabel", bb)
    hpText.Name = "H"; hpText.Size = UDim2.new(1,0,0,14); hpText.Position = UDim2.new(0,0,0,28)
    hpText.BackgroundTransparency = 1; hpText.TextColor3 = Color3.new(1,1,1)
    hpText.TextStrokeTransparency = 0; hpText.Font = Enum.Font.GothamBold; hpText.TextSize = 11
    hpText.TextXAlignment = Enum.TextXAlignment.Center
end
local function updateHPBar()
    if not hpBar or not alvo then return end
    local hp, mx = getVida(alvo)
    if not hp then return end
    local pct = math.clamp(hp/(mx or 100),0,1)
    local f = hpBar:FindFirstChild("B") and hpBar.B:FindFirstChild("F")
    if f then
        f.Size = UDim2.new(pct,0,1,0)
        f.BackgroundColor3 = pct>0.6 and Color3.fromRGB(0,200,0) or (pct>0.3 and Color3.fromRGB(255,200,0) or Color3.fromRGB(255,50,50))
    end
    local hTxt = hpBar:FindFirstChild("H")
    if hTxt then hTxt.Text = string.format("%d/%d", math.floor(hp), math.floor(mx or 100)) end
end
local function pararLock()
    if not ativo then return end
    ativo = false; alvo = nil
    RunService:UnbindFromRenderStep("EZEK_CAM")
    if gyro then gyro:Destroy(); gyro = nil end
    if hpBar then hpBar:Destroy(); hpBar = nil end
    local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h then 
        h.AutoRotate = true 
        h.CameraOffset = Vector3.new(0,0,0)
    end
    pcall(function()
        camera.CameraType = Enum.CameraType.Custom
        if h then camera.CameraSubject = h end
    end)
end
local function atualizar()
    if not ativo or not alvo or not alvo.Parent or not temVida(alvo) then pararLock() return end
    local c = player.Character
    if not c then pararLock() return end
    local r = c:FindFirstChild("HumanoidRootPart")
    local h = c:FindFirstChildOfClass("Humanoid")
    local p = pegarParte(alvo)
    if not r or not h or not p then pararLock() return end
    if h.CameraOffset.Magnitude > 0.01 then h.CameraOffset = Vector3.new(0,0,0) end
    if h.AutoRotate then h.AutoRotate = false end
    if h.PlatformStand then h.PlatformStand = false end
    local dir = (p.Position - r.Position)
    local flat = Vector3.new(dir.X, 0, dir.Z)
    if flat.Magnitude > 0.5 then
        if gyro then
            gyro.CFrame = CFrame.lookAt(r.Position, r.Position + flat.Unit)
        end
    end
    
    if camera.CameraType ~= Enum.CameraType.Custom then camera.CameraType = Enum.CameraType.Custom end
    if camera.CameraSubject ~= h then camera.CameraSubject = h end
    local miraPos = p.Position
    if miraPeito then
        local peito = alvo:FindFirstChild("UpperTorso") or alvo:FindFirstChild("Torso")
        if peito then miraPos = peito.Position end
    else
        local cabeca = alvo:FindFirstChild("Head")
        if cabeca then miraPos = cabeca.Position end
    end
    
    local lookAtCF = CFrame.lookAt(camera.CFrame.Position, miraPos)
    camera.CFrame = lookAtCF * CFrame.Angles(math.rad(-alturaCam * 5), 0, 0)
    
    updateHPBar()
end
local function toggleLock()
    if ativo then pararLock() else
        local t = acharAlvo()
        if not t then print("❌ Sem alvo") return end
        alvo = t; ativo = true
        criarHPBar(t)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            if gyro then gyro:Destroy() end
            gyro = Instance.new("BodyGyro", root)
            gyro.P = 100000; gyro.D = 1000; gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
        end
        RunService:UnbindFromRenderStep("EZEK_CAM")
        RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizar)
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
    local st = Instance.new("UIStroke", cont); st.Color = Color3.fromRGB(0, 255, 0); st.Thickness = 3; st.Transparency = 0
    previewEl = {cont = cont, st = st}; previewAlvo = m
end
local lastEspDraw = 0
local lastAchar = 0
RunService.RenderStepped:Connect(function()
    if tick() - lastEspDraw < 0.05 then return end
    lastEspDraw = tick()
    local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if not r then return end
    local mp = r.Position
    if not ativo then
        -- busca de alvo do preview só a cada 0.2s (não precisa rodar a cada frame)
        if tick() - lastAchar > 0.2 then
            lastAchar = tick()
            local t = acharAlvo()
            if t ~= previewAlvo then
                if t then criarPreview(t) else limparPreview() end
            end
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
                d.cont:Destroy(); espEl[m] = nil
            end
        end
        for _, m in pairs(alvosCache) do
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
                            
                            if modoFantasma then
                                d.st.Transparency = 0.9; d.st.Thickness = 1
                                d.nm.TextTransparency = 1; d.hp.TextTransparency = 1
                            else
                                d.st.Transparency = 0.3; d.st.Thickness = 1.5
                                d.nm.TextTransparency = 0; d.hp.TextTransparency = 0
                            end
                            local hVal, hMax = getVida(m)
                            local dist = math.floor((p.Position - mp).Magnitude)
                            if hVal then d.hp.Text = string.format("%d/%d | %dm", math.floor(hVal), math.floor(hMax or 100), dist) end
                        else d.cont.Visible = false end
                    else d.cont.Visible = false end
                end
            end
        end
    end
end)
local sg = Instance.new("ScreenGui", player.PlayerGui)
sg.Name = "EZEK_GUI_v15"; sg.ResetOnSpawn = false
local main = Instance.new("Frame", sg)
main.Size = UDim2.new(0, 200, 0, 470); main.Position = UDim2.new(0, 15, 0, 60)
main.BackgroundColor3 = Color3.fromRGB(20,20,25); main.BorderSizePixel = 0; main.Active = true
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local topBar = Instance.new("Frame", main)
topBar.Size = UDim2.new(1,0,0,36); topBar.BackgroundColor3 = Color3.fromRGB(30,30,40)
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 10)
local title = Instance.new("TextLabel", topBar)
title.Size = UDim2.new(1,-70,1,0); title.Position = UDim2.new(0,10,0,0); title.BackgroundTransparency = 1
title.Text = "🎯 EZEK "..VERSAO; title.TextColor3 = Color3.fromRGB(240,240,240); title.Font = Enum.Font.GothamBold; title.TextSize = 12; title.TextXAlignment = Enum.TextXAlignment.Left
local minBtn = Instance.new("TextButton", topBar)
minBtn.Size = UDim2.new(0,26,0,26); minBtn.Position = UDim2.new(1,-60,0,5); minBtn.BackgroundColor3 = Color3.fromRGB(45,45,60)
minBtn.Text = "—"; minBtn.TextColor3 = Color3.new(1,1,1); minBtn.Font = Enum.Font.GothamBold; minBtn.TextSize = 16
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)
local closeBtn = Instance.new("TextButton", topBar)
closeBtn.Size = UDim2.new(0,26,0,26); closeBtn.Position = UDim2.new(1,-30,0,5); closeBtn.BackgroundColor3 = Color3.fromRGB(180,50,50)
closeBtn.Text = "✕"; closeBtn.TextColor3 = Color3.new(1,1,1); closeBtn.Font = Enum.Font.GothamBold; closeBtn.TextSize = 14
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
local content = Instance.new("Frame", main)
content.Size = UDim2.new(1,-10,1,-44); content.Position = UDim2.new(0,5,0,40); content.BackgroundTransparency = 1
local statusFrame = Instance.new("Frame", content)
statusFrame.Size = UDim2.new(1,0,0,40); statusFrame.BackgroundColor3 = Color3.fromRGB(30,30,40)
Instance.new("UICorner", statusFrame).CornerRadius = UDim.new(0, 8)
local statusLbl = Instance.new("TextLabel", statusFrame)
statusLbl.Size = UDim2.new(1,-12,1,-8); statusLbl.Position = UDim2.new(0,6,0,4); statusLbl.BackgroundTransparency = 1
statusLbl.Text = "🔓 Lock: OFF\n👁️ ESP: OFF"; statusLbl.TextColor3 = Color3.fromRGB(160,160,170); statusLbl.Font = Enum.Font.GothamMedium; statusLbl.TextSize = 11; statusLbl.TextXAlignment = Enum.TextXAlignment.Left; statusLbl.TextYAlignment = Enum.TextYAlignment.Top
local function mkBtn(txt, y, cb)
    local b = Instance.new("TextButton", content)
    b.Size = UDim2.new(1,0,0,36); b.Position = UDim2.new(0,0,0,y)
    b.BackgroundColor3 = Color3.fromRGB(45,45,60); b.Text = txt; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseButton1Click:Connect(cb)
    return b
end
local function updateUI()
    bLock.Text = ativo and "🔒 LOCK: ON" or "🔓 LOCK: OFF"
    bLock.BackgroundColor3 = ativo and Color3.fromRGB(0,170,90) or Color3.fromRGB(45,45,60)
    bEsp.Text = espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF"
    bEsp.BackgroundColor3 = espAtivo and Color3.fromRGB(0,170,90) or Color3.fromRGB(45,45,60)
    statusLbl.Text = (ativo and "🔒 Lock: ON" or "🔓 Lock: OFF").."\n"..(espAtivo and "👁️ ESP: ON" or "👁️ ESP: OFF")
end
bLock = mkBtn("🔓 LOCK: OFF", 46, function() toggleLock(); updateUI() end)
bEsp = mkBtn("👁️ ESP: OFF", 86, function() espAtivo = not espAtivo; updateUI() end)
bMira = mkBtn("🎯 MIRA: CABEÇA", 126, function()
    miraPeito = not miraPeito
    bMira.Text = miraPeito and "🎯 MIRA: PEITO" or "🎯 MIRA: CABEÇA"
end)
bCam = mkBtn("📷 INCLINAÇÃO: 2.0", 166, function()
    if alturaCam == 2.0 then alturaCam = 4.0
    elseif alturaCam == 4.0 then alturaCam = 6.0
    elseif alturaCam == 6.0 then alturaCam = 8.0
    else alturaCam = 2.0 end
    bCam.Text = "📷 INCLINAÇÃO: " .. tostring(alturaCam)
end)
bFantasma = mkBtn("👻 MODO STREAMER: ON", 206, function()
    modoFantasma = not modoFantasma
    bFantasma.Text = modoFantasma and "👻 MODO STREAMER: ON" or "👻 MODO STREAMER: OFF"
    bFantasma.BackgroundColor3 = modoFantasma and Color3.fromRGB(150,50,200) or Color3.fromRGB(45,45,60)
end)
bFantasma.BackgroundColor3 = Color3.fromRGB(150,50,200)
local filtFrame = Instance.new("Frame", content)
filtFrame.Size = UDim2.new(1,0,0,126); filtFrame.Position = UDim2.new(0,0,0,250); filtFrame.BackgroundColor3 = Color3.fromRGB(30,30,40)
Instance.new("UICorner", filtFrame).CornerRadius = UDim.new(0, 8)
local fTit = Instance.new("TextLabel", filtFrame)
fTit.Size = UDim2.new(1,-10,0,16); fTit.Position = UDim2.new(0,6,0,2); fTit.BackgroundTransparency = 1
fTit.Text = "🎛️ Filtros"; fTit.TextColor3 = Color3.fromRGB(160,160,170); fTit.Font = Enum.Font.GothamBold; fTit.TextSize = 10; fTit.TextXAlignment = Enum.TextXAlignment.Left
local function mkCheck(txt, chave, y)
    local cf = Instance.new("Frame", filtFrame)
    cf.Size = UDim2.new(1,-12,0,24); cf.Position = UDim2.new(0,6,0,y); cf.BackgroundTransparency = 1
    local box = Instance.new("TextButton", cf)
    box.Size = UDim2.new(0,20,0,20); box.Position = UDim2.new(0,0,0,2)
    box.BackgroundColor3 = filtros[chave] and Color3.fromRGB(0,170,90) or Color3.fromRGB(60,60,75)
    box.Text = filtros[chave] and "✓" or ""; box.TextColor3 = Color3.new(1,1,1); box.Font = Enum.Font.GothamBold; box.TextSize = 12
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 4)
    
    local lb = Instance.new("TextLabel", cf)
    lb.Size = UDim2.new(1,-26,1,0); lb.Position = UDim2.new(0,26,0,0)
    lb.BackgroundTransparency = 1; lb.Text = txt; lb.TextColor3 = Color3.new(1,1,1); lb.Font = Enum.Font.GothamMedium; lb.TextSize = 12; lb.TextXAlignment = Enum.TextXAlignment.Left
    
    box.MouseButton1Click:Connect(function()
        filtros[chave] = not filtros[chave]
        box.BackgroundColor3 = filtros[chave] and Color3.fromRGB(0,170,90) or Color3.fromRGB(60,60,75)
        box.Text = filtros[chave] and "✓" or ""
    end)
end
mkCheck("👤 Players", "players", 20)
mkCheck("🎯 Dummies", "dummies", 44)
mkCheck("👹 Monstros", "monstros", 68)
mkCheck("📦 Objetos", "objetos", 92)
floatingBtn = Instance.new("TextButton", sg)
floatingBtn.Size = UDim2.new(0, 44, 0, 44); floatingBtn.Position = UDim2.new(1, -60, 0, 20)
floatingBtn.BackgroundColor3 = Color3.fromRGB(30,30,40); floatingBtn.Text = "🎯"; floatingBtn.TextSize = 20; floatingBtn.TextColor3 = Color3.fromRGB(0,255,255)
floatingBtn.Visible = false
Instance.new("UICorner", floatingBtn).CornerRadius = UDim.new(1,0)
local function drag(f,h)
    h = h or f; local dr, ds, sp
    h.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = true; ds = i.Position; sp = f.Position end end)
    UIS.InputChanged:Connect(function(i) if dr and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - ds; f.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dr = false end end)
end
drag(main, topBar)
drag(floatingBtn)
local min = false
minBtn.MouseButton1Click:Connect(function()
    min = not min
    main.Size = min and UDim2.new(0,200,0,36) or UDim2.new(0,200,0,470)
    content.Visible = not min
    minBtn.Text = min and "+" or "—"
end)
closeBtn.MouseButton1Click:Connect(function()
    main.Visible = false
    floatingBtn.Visible = true
end)
floatingBtn.MouseButton1Click:Connect(function()
    main.Visible = true
    floatingBtn.Visible = false
end)
-- ⚙️═══════════ MAPEAMENTO (igual ao v32.1 que funciona) ═══════════⚙️
local r1, r2, l1, l2 = false, false, false, false
UIS.InputBegan:Connect(function(input, gp)
    local n = input.KeyCode == Enum.KeyCode.K or input.KeyCode == Enum.KeyCode.L
        or input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.N
        or input.KeyCode == Enum.KeyCode.ButtonR1 or input.KeyCode == Enum.KeyCode.ButtonR2
        or input.KeyCode == Enum.KeyCode.ButtonL1 or input.KeyCode == Enum.KeyCode.ButtonL2
        or input.KeyCode == Enum.KeyCode.DpadRight or input.KeyCode == Enum.KeyCode.DpadDown
    if gp and not n then return end
    -- Teclado
    if input.KeyCode == Enum.KeyCode.K then bLock:Activate() end
    if input.KeyCode == Enum.KeyCode.L then bEsp:Activate() end
    if input.KeyCode == Enum.KeyCode.M then bMira:Activate() end
    if input.KeyCode == Enum.KeyCode.N then bCam:Activate() end
    -- Controle
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end
    if r1 and r2 then bLock:Activate(); r1=false; r2=false end
    if l1 and l2 then bEsp:Activate(); l1=false; l2=false end
    if r1 and input.KeyCode == Enum.KeyCode.DpadRight then bMira:Activate(); r1=false end
    if r1 and input.KeyCode == Enum.KeyCode.DpadDown then bCam:Activate(); r1=false end
end)
UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)
player.CharacterRemoving:Connect(function() if ativo then pararLock() end; limparPreview() end)
print("⚡ EZEK "..VERSAO.." Carregado! | Controle 100% Liberado.")
