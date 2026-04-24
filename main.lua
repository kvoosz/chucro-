-- [[ CONFIGURAÇÃO ]]
local ADMIN_ID = 12345678 -- COLOQUE SEU ID DO ROBLOX AQUI
local player = game:GetService("Players").LocalPlayer
local REPLICATED = game:GetService("ReplicatedStorage")
local REMOTE_PICKUP = REPLICATED:WaitForChild("Shared"):WaitForChild("Universe"):WaitForChild("Network"):WaitForChild("RemoteEvent"):WaitForChild("Pickup")
local OBJECT_MODELS = workspace:WaitForChild("ObjectModels")

-- [[ INTERFACE CHUCRO $ ]]
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ChucroHub"
screenGui.Parent = (gethui and gethui()) or player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 550, 0, 320)
main.Position = UDim2.new(0.5, -275, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
main.Parent = screenGui
Instance.new("UIStroke", main).Color = Color3.new(1,1,1)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundColor3 = Color3.new(1,1,1)
title.Text = "Chucro $"
title.TextColor3 = Color3.new(0,0,0)
title.TextSize = 24
title.Font = Enum.Font.RobotoMono
title.Parent = main

-- ABAS
local container = Instance.new("Frame")
container.Size = UDim2.new(1, 0, 1, -40)
container.Position = UDim2.new(0, 0, 0, 40)
container.BackgroundTransparency = 1
container.Parent = main

-- ABA CLIENTE (Visível para todos)
local clientFrame = Instance.new("Frame")
clientFrame.Size = UDim2.new(1, 0, 1, 0)
clientFrame.BackgroundTransparency = 1
clientFrame.Parent = container

-- [Aqui vai toda a sua lista de itens e botões que criamos antes...]
-- (Resumindo para o código não ficar infinito, use a lógica de seleção de itens aqui)

-- [[ PAINEL DE ADM SECRETO ]]
if player.UserId == ADMIN_ID then
    local admBtn = Instance.new("TextButton")
    admBtn.Size = UDim2.new(0, 80, 0, 20)
    admBtn.Position = UDim2.new(1, -85, 0, 10)
    admBtn.Text = "ADM PANEL"
    admBtn.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
    admBtn.TextColor3 = Color3.new(1,1,1)
    admBtn.Parent = main

    local admFrame = Instance.new("Frame")
    admFrame.Size = UDim2.new(1, 0, 1, 0)
    admFrame.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
    admFrame.Visible = false
    admFrame.Parent = container
    
    admBtn.MouseButton1Click:Connect(function()
        admFrame.Visible = not admFrame.Visible
        clientFrame.Visible = not admFrame.Visible
    end)

    local userList = Instance.new("TextLabel")
    userList.Size = UDim2.new(0.5, 0, 1, 0)
    userList.Text = "USUÁRIOS ONLINE:\n"
    userList.TextColor3 = Color3.new(1,1,1)
    userList.BackgroundTransparency = 1
    userList.Parent = admFrame

    task.spawn(function()
        while true do
            local str = "USUÁRIOS ONLINE:\n"
            for _, p in pairs(game:GetService("Players"):GetPlayers()) do
                str = str .. p.Name .. " (" .. p.UserId .. ")\n"
            end
            userList.Text = str
            task.wait(5)
        end
    end)

    local idInput = Instance.new("TextBox")
    idInput.Size = UDim2.new(0.4, 0, 0, 30)
    idInput.Position = UDim2.new(0.55, 0, 0.2, 0)
    idInput.PlaceholderText = "USER ID"
    idInput.Parent = admFrame

    local daysInput = Instance.new("TextBox")
    daysInput.Size = UDim2.new(0.4, 0, 0, 30)
    daysInput.Position = UDim2.new(0.55, 0, 0.4, 0)
    daysInput.PlaceholderText = "DIAS (Ex: 7)"
    daysInput.Parent = admFrame

    local genBtn = Instance.new("TextButton")
    genBtn.Size = UDim2.new(0.4, 0, 0, 40)
    genBtn.Position = UDim2.new(0.55, 0, 0.6, 0)
    genBtn.Text = "GERAR STRING JSON"
    genBtn.Parent = admFrame

    genBtn.MouseButton1Click:Connect(function()
        local id = idInput.Text
        local days = tonumber(daysInput.Text) or 1
        local expireTime = os.time() + (days * 86400)
        local result = '{"id":"'..id..'", "expires":'..expireTime..'}'
        setclipboard(result)
        genBtn.Text = "COPIADO!"
        task.wait(2)
        genBtn.Text = "GERAR STRING JSON"
    end)
end
