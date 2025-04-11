-- GhostSeller.lua
repeat task.wait() until game:IsLoaded()
local LocalPlayer = game:GetService("Players").LocalPlayer
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

-- Configuration Check --
if not getgenv().Config then
    getgenv().Config = {
        AutoTeleport = true,
        BoothPosition = CFrame.new(5, 0, 0),
        Webhook = "",
        Prices = {}
    }
end

local Library = game.ReplicatedStorage.Library
local Client = Library.Client

local RAPCmds = require(Client.RAPCmds)
local Network = require(Client.Network)
local Savemod = require(Client.Save)

-- Auto Teleport Handler --
if (game.PlaceId == 8737899170 or game.PlaceId == 16498369169) and Config.AutoTeleport then
    Network.Invoke("Travel to Trading Plaza")
    task.wait(3)
end

-- Core Functions --
local GetRap = function(Class, ItemTable)
    local Item = require(Library.Items[Class .. "Item"])(ItemTable.id)
    
    if ItemTable.sh then Item:SetShiny(true) end
    if ItemTable.pt == 1 then Item:SetGolden() end
    if ItemTable.pt == 2 then Item:SetRainbow() end
    if ItemTable.tn then Item:SetTier(ItemTable.tn) end
    
    return RAPCmds.Get(Item) or 0
end

local ConvertPrice = function(Price, Rap)
    if type(Price) == "string" then
        local Percentage = tonumber(Price:match("^(%d+)%%"))
        return Percentage and (Percentage / 100) * Rap or 0
    end
    return Price
end

-- Booth System --
local ClaimBooth = function()
    local HaveBooth = false
    local BoothSpawns = workspace.TradingPlaza.BoothSpawns:FindFirstChildWhichIsA("Model")
    
    while not HaveBooth do
        for _, Booth in ipairs(workspace.__THINGS.Booths:GetChildren()) do
            if Booth:IsA("Model") and Booth.Info.BoothBottom.Frame.Top.Text:find(LocalPlayer.DisplayName) then
                HaveBooth = true
                LocalPlayer.Character.HumanoidRootPart.CFrame = Booth.Table.CFrame * Config.BoothPosition
                break
            end
        end
        
        if not HaveBooth then
            LocalPlayer.Character.HumanoidRootPart.CFrame = BoothSpawns.Table.CFrame * Config.BoothPosition
            Network.Invoke("Booths_ClaimBooth", tostring(BoothSpawns:GetAttribute("ID")))
        end
        task.wait(1)
    end
end

-- Anti AFK System --
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:ClickButton2(Vector2.new(math.random(0, 1000), math.random(0, 1000)))
end)

-- Network Protection --
hookmetamethod(game, "__namecall", function(self, ...)
    if not checkcaller() and table.find({"Server Closing", "Idle Tracking: Update Timer", "Move Server"}, tostring(self)) then
        return nil
    end
    return old(self, ...)
end)

Network.Fire("Idle Tracking: Stop Timer")

-- Webhook System --
local function FormatNumber(n)
    return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local function SendWebhook(SoldItem, TotalPrice, SoldAmount, Remaining)
    if Config.Webhook == "" then return end
    
    local HttpService = game:GetService("HttpService")
    local ItemName = "Unknown"
    local success, itemData = pcall(function()
        return require(Library.Items[SoldItem.Class .. "Item"])(SoldItem.id)
    end)
    
    if success and itemData then
        ItemName = itemData.name
    end
    
    local embed = {
        {
            title = "💰 New Sale!",
            color = 65280,
            fields = {
                {
                    name = "Item Sold",
                    value = string.format("```%s ×%d\nTotal: %s```", ItemName, SoldAmount, FormatNumber(TotalPrice)),
                    inline = true
                },
                {
                    name = "Player Stats",
                    value = string.format("```Diamonds: %s\nRemaining: %d```", 
                        FormatNumber(Savemod.Get().Diamonds), 
                        Remaining
                    ),
                    inline = true
                }
            },
            footer = { text = "Sold by: " .. LocalPlayer.Name },
            timestamp = DateTime.now():ToIsoDate()
        }
    }
    
    pcall(function()
        HttpService:PostAsync(Config.Webhook, HttpService:JSONEncode({
            embeds = embed,
            username = "Ghost Seller"
        }))
    end)
end

-- Main Logic --
ClaimBooth()

while task.wait(5) do
    local Queue = {}
    
    for Class, Items in pairs(Savemod.Get().Inventory) do
        if Config.Prices[Class] then
            for uuid, data in pairs(Items) do
                local ConfigData = Config.Prices[Class][data.id]
                if ConfigData and ConfigData.pt == data.pt and ConfigData.sh == data.sh and ConfigData.tn == data.tn then
                    local RapValue = GetRap(Class, data)
                    table.insert(Queue, {
                        uuid = uuid,
                        class = Class,
                        data = data,
                        price = ConvertPrice(ConfigData.Price, RapValue),
                        rap = RapValue
                    })
                end
            end
        end
    end
    
    table.sort(Queue, function(a,b) return a.rap > b.rap end)
    
    for _, item in ipairs(Queue) do
        local MaxAmount = math.min(item.data._am or 1, math.floor(25e9 / item.price))
        local OriginalAmount = item.data._am
        
        Network.Invoke("Booths_CreateListing", item.uuid, math.ceil(item.price), MaxAmount)
        
        spawn(function()
            local start = os.time()
            while os.time() - start < 60 do
                local current = Savemod.Get().Inventory[item.class][item.uuid]?._am or 0
                if current < OriginalAmount then
                    SendWebhook(
                        {Class = item.class, id = item.data.id},
                        item.price * (OriginalAmount - current),
                        OriginalAmount - current,
                        current
                    )
                    break
                end
                task.wait(5)
            end
        end)
        
        task.wait(1)
    end
end
