-- EZEK v31.0 LITE (Teste de execução)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

for _, obj in pairs(player.PlayerGui:GetChildren()) do
    if obj.Name:find("EZEK") then obj:Destroy() end
end

local ativo, espAtivo = false, false
local alvo = nil
local espGui = Instance.new("ScreenGui", player.PlayerGui)
espGui.Name = "EZEK_LITE"

local function getParte(m)
    return m:FindFirstChild("Head") or m:FindFirstChild("HumanoidRootPart") or m:FindFirstChildWhichIsA("BasePart")
end

local function temVida(m)
    local h = m:FindFirstChildOfClass("Humanoid")
    return h and h.Health > 0
end

local function getTodos()
    local l = {}
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player and p.Character and temVida(p.Character) then table.insert(l, p.Character) end
    end
    for _, v in pairs(workspace:GetChildren()) do
        if v:IsA("Model") and v ~= player.Character and temVida(v) and getParte(v) then table.insert(l, v) end
    end
    return l
end

-- LOCK (Tecla P)
local function ligarLock()
    if alvo then alvo = nil; ativo = false; camera.CameraType = Enum.CameraType.Custom return end
    for _, m in pairs(getTodos()) do
        local p = getParte(m)
        if p then
            local dist = (p.Position - camera.CFrame.Position).Magnitude
            if dist < 300 then
                alvo = m; ativo = true
                camera.CameraType = Enum.CameraType.Custom
                break
            end
        end
    end
end

RunService.RenderStepped:Connect(function()
    if ativo and alvo and alvo.Parent and temVida(alvo) then
        local p = getParte(alvo)
        if p then
            camera.CFrame = CFrame.lookAt(camera.CFrame.Position, p.Position)
        end
    end
end)

-- ESP (Tecla O)
RunService.RenderStepped:Connect(function()
    if not espAtivo then espGui:ClearAllChildren() return end
    for _, m in pairs(getTodos()) do
        local p = getParte(m)
        if p then
            local pos, onScreen = camera:WorldToViewportPoint(p.Position)
            if onScreen then
                local box = Instance.new("Frame", espGui)
                box.Size = UDim2.new(0, 50, 0, 50)
                box.Position = UDim2.new(0, pos.X - 25, 0, pos.Y - 25)
                box.BackgroundTransparency = 1
                local stroke = Instance.new("UIStroke", box)
                stroke.Color = Color3.new(0, 1, 0)
            end
        end
    end
end)

UIS.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.P then ligarLock() end
    if input.KeyCode == Enum.KeyCode.O then espAtivo = not espAtivo end
end)