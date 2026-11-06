-- EZEK v37.0 - A VERDADEIRA CORREÇÃO (Fim do Lag e UI Funcional)
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
local align, attach = nil, nil
local miraPeito = false
local alturaCam = 2.0
local filtros = {players=true, dummies=true, monstros=true, objetos=true}
local espGui = Instance.new("ScreenGui", player.PlayerGui)
espGui.Name = "EZEK_ESP"

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

local function getParte(m)
    if not m then return nil end
    if m:IsA("BasePart") then return m end
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
end

local function getTipo(m)
    if Players:GetPlayerFromCharacter(m) then return "players" end
    local n = string.lower(m.Name)
    if n:find("dummy") or n:find("training") then return "dummies" end
    if m:FindFirstChildOfClass("Humanoid") or temVida(m) then return "monstros" end
    return "objetos"
end

-- Cache da lista (roda em background)
task.spawn(function()
    while true do
        task.wait(1)
        local lista, vistos = {}, {}
        for _, p in pairs(Players:GetPlayers()) do
            if p ~= player and p.Character and temVida(p.Character) then table.insert(lista, p.Character); vistos[p.Character]=true end
        end
        local function proc(pasta, prof)
            if prof > 4 then return end
            for _, v in pairs(pasta:GetChildren()) do
                if v:IsA("Model") and not vistos[v] and getParte(v) then
                    local tipo = getTipo(v)
                    if tipo == "objetos" then
                        if filtros.objetos then table.insert(lista, v); vistos[v]=true end
                    elseif temVida(v) then
                        table.insert(lista, v); vistos[v]=true
                    end
                end
                if v:IsA("Folder") then proc(v, prof+1) end
            end
        end
        proc(workspace, 0)
        alvosESP = lista
    end
end)

local function acharAlvo()
    local melhor, angMin = nil, math.rad(120)
    local cp = camera.CFrame.Position
    local cl = camera.CFrame.LookVector
    for _, m in pairs(alvosESP) do
        if m ~= player.Character and not m:IsDescendantOf(player.Character) then
            if filtros[getTipo(m)] and temVida(m) then
                local p = getParte(m)
                if p then
                    local dist = (p.Position - cp).Magnitude
                    if dist > 4 then
                        local ang = math.acos(math.clamp(cl:Dot((p.Position - cp).Unit), -1, 1))
                        if ang < angMin then angMin = ang; melhor = m end
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
    if align then align:Destroy(); align = nil end
    if attach then attach:Destroy(); attach = nil end
    if hpBar then hpBar:Destroy(); hpBar = nil end
    local h = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    if h then h.AutoRotate = true end
end

local function criarHPBar(m)
    if hpBar then hpBar:Destroy() end
    local root = getParte(m)
    if not root then return end
    hpBar = Instance.new("BillboardGui", m)
    hpBar.Adornee = root; hpBar.Size = UDim2.new(0, 150, 0, 40); hpBar.StudsOffset = Vector3.new(0, 3, 0); hpBar.AlwaysOnTop = true
    
    local nome = Instance.new("TextLabel", hpBar)
    nome.Size = UDim2.new(1,0,0,14); nome.BackgroundTransparency = 1; nome.Text = m.Name; nome.TextColor3 = Color3.new(1,1,1); nome.TextStrokeTransparency = 0; nome.Font = Enum.Font.GothamBold; nome.TextSize = 11
    
    local bg = Instance.new("Frame", hpBar)
    bg.Name = "BG"; bg.Size = UDim2.new(1,0,0,10); bg.Position = UDim2.new(0,0,0,16); bg.BackgroundColor3 = Color3.new(0,0,0); bg.BorderSizePixel = 0
    local fill = Instance.new("Frame", bg)
    fill.Name = "Fill"; fill.Size = UDim2.new(1,0,1,0); fill.BackgroundColor3 = Color3.fromRGB(0,200,0); fill.BorderSizePixel = 0
    
    local hpTxt = Instance.new("TextLabel", hpBar)
    hpTxt.Name = "Txt"; hpTxt.Size = UDim2.new(1,0,0,14); hpTxt.Position = UDim2.new(0,0,0,26); hpTxt.BackgroundTransparency = 1; hpTxt.TextColor3 = Color3.new(1,1,1); hpTxt.TextStrokeTransparency = 0; hpTxt.Font = Enum.Font.GothamBold; hpTxt.TextSize = 10
end

local function atualizarLock()
    if not ativo or not alvo or not alvo.Parent or not temVida(alvo) then pararLock() return end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local h = char and char:FindFirstChildOfClass("Humanoid")
    local p = getParte(alvo)
    if not root or not h or not p then pararLock() return end

    if align then
        local tPos = Vector3.new(p.Position.X, root.Position.Y, p.Position.Z)
        align.CFrame = CFrame.lookAt(root.Position, tPos)
    end
    
    h.AutoRotate = false
    camera.CameraType = Enum.CameraType.Custom
    if camera.CameraSubject ~= h then camera.CameraSubject = h end

    local miraPos = p.Position
    if miraPeito then
        local torso = alvo:FindFirstChild("UpperTorso") or alvo:FindFirstChild("Torso")
        if torso then miraPos = torso.Position end
    else
        local cabeca = alvo:FindFirstChild("Head")
        if cabeca then miraPos = cabeca.Position end
    end
    
    local cPos = camera.CFrame.Position
    local nPos = Vector3.new(cPos.X, root.Position.Y + alturaCam, cPos.Z)
    camera.CFrame = CFrame.lookAt(nPos, miraPos)

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
        if not t then 
            print("❌ Nenhum alvo encontrado!")
            return 
        end
        alvo = t; ativo = true
        criarHPBar(t)
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            attach = Instance.new("Attachment", root)
            align = Instance.new("AlignOrientation", root)
            align.Mode = Enum.OrientationAlignmentMode.OneAttachment
            align.Attachment0 = attach
            align.RigidityEnabled = true
            align.MaxTorque = 100000
            align.Responsiveness = 200
        end
        RunService:UnbindFromRenderStep("EZEK_CAM")
        RunService:BindToRenderStep("EZEK_CAM", Enum.RenderPriority.Camera.Value + 1, atualizarLock)
    end
end

-- 🔥 ESP LOOP OTIMIZADO (Roda a 20 FPS em vez de 60, economiza 70% de CPU)
local lastEspTick = 0
RunService.Heartbeat:Connect(function()
    if not espAtivo and not ativo then 
        for _, d in pairs(espEl) do d.cont.Visible = false end
        return 
    end

    if tick() - lastEspTick < 0.05 then return end
    lastEspTick = tick()

    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local alvoPreview = nil
    if not ativo then alvoPreview = acharAlvo() end

    for m, d in pairs(espEl) do
        if not m.Parent or not temVida(m) or not filtros[getTipo(m)] then
            d.cont:Destroy()
            espEl[m] = nil
        end
    end

    for _, m in pairs(alvosESP) do
        local p = getParte(m)
        local isPreview = (m == alvoPreview)
        local showESP = (espAtivo and filtros[getTipo(m)] and (temVida(m) or getTipo(m) == "objetos"))

        if p and (showESP or isPreview) then
            local top = camera:WorldToViewportPoint(p.Position + Vector3.new(0,2.5,0))
            local bot = camera:WorldToViewportPoint(p.Position - Vector3.new(0,2.5,0))
            
            if top.Z > 0 and bot.Z > 0 then
                local alt = math.abs(top.Y - bot.Y)
                if alt > 5 then
                    if not espEl[m] then
                        local cont = Instance.new("Frame", espGui)
                        cont.BackgroundTransparency = 1
                        cont.AnchorPoint = Vector2.new(0.5, 0.5)
                        local st = Instance.new("UIStroke", cont)
                        local nm = Instance.new("TextLabel", cont)
                        nm.Size = UDim2.new(1,0,0,14); nm.Position = UDim2.new(0,0,0,-16); nm.BackgroundTransparency = 1
                        nm.Font = Enum.Font.GothamBold; nm.TextSize = 10; nm.TextStrokeTransparency = 0
                        local hpt = Instance.new("TextLabel", cont)
                        hpt.Size = UDim2.new(1,0,0,14); hpt.Position = UDim2.new(0,0,1,2); hpt.BackgroundTransparency = 1
                        hpt.Font = Enum.Font.GothamBold; hpt.TextSize = 10; hpt.TextStrokeTransparency = 0
                        
                        -- 🔥 SALVA EM TABELA (Sem erro de Attribute)
                        espEl[m] = {cont=cont, st=st, nm=nm, hpt=hpt}
                    end
                    
                    local d = espEl[m]
                    d.cont.Visible = true
                    d.cont.Size = UDim2.new(0, alt*0.55, 0, alt)
                    d.cont.Position = UDim2.new(0, (top.X+bot.X)/2, 0, (top.Y+bot.Y)/2)
                    
                    if isPreview then
                        d.st.Color = Color3.fromRGB(0, 255, 0); d.st.Thickness = 2
                        d.nm.Visible = false; d.hpt.Visible = false
                    else
                        if getTipo(m) == "objetos" then d.st.Color = Color3.fromRGB(255, 150, 0) else d.st.Color = Color3.fromRGB(0, 255, 255) end
                        d.st.Thickness = 1.5
                        d.nm.Visible = true; d.hpt.Visible = true
                        
                        local hp, mx = getVida(m)
                        local dist = math.floor((p.Position - root.Position).Magnitude)
                        
                        d.nm.Text = m.Name; d.nm.TextColor3 = d.st.Color
                        if hp then
                            d.hpt.Text = string.format("%d HP | %dm", math.floor(hp), dist); d.hpt.TextColor3 = Color3.fromRGB(0,255,0)
                        else
                            d.hpt.Text = string.format("%dm", dist); d.hpt.TextColor3 = Color3.fromRGB(255,150,0)
                        end
                    end
                else
                    if espEl[m] then espEl[m].cont.Visible = false end
                end
            else
                if espEl[m] then espEl[m].cont.Visible = false end
            end
        else
            if espEl[m] then espEl[m].cont.Visible = false end
        end
    end
end)

-- UI
local ui = Instance.new("ScreenGui", player.PlayerGui)
ui.Name = "EZEK_UI"
local main = Instance.new("Frame", ui)
main.Size = UDim2.new(0, 170, 0, 350); main.Position = UDim2.new(0, 20, 0.5, -175)
main.BackgroundColor3 = Color3.fromRGB(20,20,25); main.BorderSizePixel = 0
Instance.new("UICorner", main).CornerRadius = UDim.new(0,8)

local title = Instance.new("TextLabel", main)
title.Size = UDim2.new(1,0,0,35); title.BackgroundColor3 = Color3.fromRGB(15,15,20)
title.Text = "EZEK v37.0"; title.TextColor3 = Color3.fromRGB(0,255,255); title.Font = Enum.Font.GothamBold; title.TextSize = 14
Instance.new("UICorner", title).CornerRadius = UDim.new(0,8)

-- 🔥 DRAG DO MENU DE VOLTA
local dragging, dragStart, startPos
title.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; dragStart = i.Position; startPos = main.Position end end)
UIS.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then local d = i.Position - dragStart; main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end end)
UIS.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)

local minBtn = Instance.new("TextButton", title)
minBtn.Size = UDim2.new(0,30,1,0); minBtn.Position = UDim2.new(1,-30,0,0); minBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
minBtn.Text = "X"; minBtn.TextColor3 = Color3.new(1,1,1); minBtn.Font = Enum.Font.GothamBold

local floatBtn = Instance.new("TextButton", ui)
floatBtn.Size = UDim2.new(0, 40, 0, 40); floatBtn.Position = UDim2.new(0, 20, 0, 100)
floatBtn.BackgroundColor3 = Color3.fromRGB(15,15,20); floatBtn.Text = "🎯"; floatBtn.TextSize = 20; floatBtn.TextColor3 = Color3.fromRGB(0,255,255)
floatBtn.Visible = false; Instance.new("UICorner", floatBtn).CornerRadius = UDim.new(1,0)

minBtn.MouseButton1Click:Connect(function() main.Visible = false; floatBtn.Visible = true end)
floatBtn.MouseButton1Click:Connect(function() main.Visible = true; floatBtn.Visible = false end)

local function mkBtn(txt, y, cb)
    local b = Instance.new("TextButton", main)
    b.Size = UDim2.new(1,-20,0,32); b.Position = UDim2.new(0,10,0,y)
    b.BackgroundColor3 = Color3.fromRGB(40,40,50); b.Text = txt; b.TextColor3 = Color3.new(1,1,1); b.Font = Enum.Font.GothamBold; b.TextSize = 11
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
    return b
end

local bLock = mkBtn("LOCK: OFF", 45, function()
    toggleLock()
    if ativo then
        bLock.Text = "LOCK: ON"
        bLock.BackgroundColor3 = Color3.fromRGB(0,150,0)
    else
        bLock.Text = "LOCK: OFF"
        bLock.BackgroundColor3 = Color3.fromRGB(40,40,50)
    end
end)

local bEsp = mkBtn("ESP: OFF", 82, function()
    espAtivo = not espAtivo
    bEsp.Text = espAtivo and "ESP: ON" or "ESP: OFF"
    bEsp.BackgroundColor3 = espAtivo and Color3.fromRGB(0,150,0) or Color3.fromRGB(40,40,50)
end)

local bMira = mkBtn("MIRA: CABEÇA", 119, function()
    miraPeito = not miraPeito
    bMira.Text = miraPeito and "MIRA: PEITO" or "MIRA: CABEÇA"
    bMira.BackgroundColor3 = miraPeito and Color3.fromRGB(180,50,50) or Color3.fromRGB(40,40,50)
end)

local bCam = mkBtn("CÂMERA ACIMA: 2.0", 156, function()
    if alturaCam == 2.0 then alturaCam = 4.0
    elseif alturaCam == 4.0 then alturaCam = 6.0
    elseif alturaCam == 6.0 then alturaCam = 8.0
    else alturaCam = 2.0 end
    bCam.Text = "CÂMERA ACIMA: " .. tostring(alturaCam)
end)

local fTitle = Instance.new("TextLabel", main)
fTitle.Size = UDim2.new(1,0,0,20); fTitle.Position = UDim2.new(0,0,0,195); fTitle.BackgroundTransparency = 1
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

mkChk("Players", "players", 220)
mkChk("Dummies", "dummies", 245)
mkChk("Monstros", "monstros", 270)
mkChk("Objetos", "objetos", 295)

-- Controles Teclado
UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.P then bLock:Activate() end
    if input.KeyCode == Enum.KeyCode.O then bEsp:Activate() end
end)

-- Controles Controle
local r1,r2,l1,l2 = false,false,false,false
UIS.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = true end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = true end
    
    if r1 and r2 then bLock:Activate(); r1=false; r2=false end
    if l1 and l2 then bEsp:Activate(); l1=false; l2=false end
end)

UIS.InputEnded:Connect(function(input)
    if input.KeyCode == Enum.KeyCode.ButtonR1 then r1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonR2 then r2 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL1 then l1 = false end
    if input.KeyCode == Enum.KeyCode.ButtonL2 then l2 = false end
end)

print("⚡ EZEK v37.0 Carregado! O botão agora funciona e o lag foi embora.")