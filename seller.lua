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

-- Helper Functions --
local function GetItemId(ClassName, ItemName)
    local success, items = pcall(function()
        return require(Library.Items[ClassName .. "Item"]).GetAll()
    end)
    if not success then return nil end
    
    for id, data in pairs(items) do
        if data.name:lower() == ItemName:lower() then
            return id
        end
    end
    return nil
end

local function ConvertPrice(Price, Rap)
    if type(Price) == "string" then
        local percentage = tonumber(Price:match("^(%d+)%%"))
        return percentage and (Rap * percentage/100) or Rap
    end
    return tonumber(Price) or Rap
end

-- Auto Teleport Handler --
if (game.PlaceId == 8737899170 or game.PlaceId == 16498369169) and Config.AutoTeleport then
    Network.Invoke("Travel to Trading Plaza")
    task.wait(3)
end

-- Booth Claiming System --
local function ClaimBooth()
    local foundBooth = false
    repeat
        local boothSpawns = workspace.TradingPlaza.BoothSpawns:FindFirstChildWhichIsA("Model")
        for _, booth in ipairs(workspace.__THINGS.Booths:GetChildren()) do
            if booth:FindFirstChild("Info") and booth.Info.BoothBottom.Frame.Top.Text:match(LocalPlayer.DisplayName) then
                LocalPlayer.Character.HumanoidRootPart.CFrame = booth.Table.CFrame * Config.BoothPosition
                foundBooth = true
                break
            end
        end
        
        if not foundBooth and boothSpawns then
            LocalPlayer.Character.HumanoidRootPart.CFrame = boothSpawns.Table.CFrame * Config.BoothPosition
            Network.Invoke("Booths_ClaimBooth", tostring(boothSpawns:GetAttribute("ID")))
        end
        task.wait(1)
    until foundBooth
end

-- Anti AFK System --
local VirtualUser = game:GetService("VirtualUser")
LocalPlayer.Idled:Connect(function()
    VirtualUser:ClickButton2(Vector2.new(math.random(), math.random()))
end)

-- Network Protection --
local originalNamecall
originalNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if not checkcaller() and table.find({"Server Closing", "Move Server"}, tostring(self)) then
        return nil
    end
    return originalNamecall(self, ...)
end)

-- Webhook Notification System --
local function SendSaleNotification(ItemName, TotalPrice, SoldAmount, Remaining)
    if Config.Webhook == "" then return end
    
    local HttpService = game:GetService("HttpService")
    local formattedPrice = tostring(TotalPrice):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
    local diamonds = Savemod.Get().Diamonds
    
    local embed = {
        {
            title = "🛍️ New Item Sold!",
            color = 65280,
            fields = {
                {
                    name = "Item Details",
                    value = string.format("```Name: %s\nAmount: %d\nTotal: %s```", 
                        ItemName, 
                        SoldAmount, 
                        formattedPrice
                    ),
                    inline = true
                },
                {
                    name = "Player Stats",
                    value = string.format("```Diamonds: %s\nRemaining: %d```",
                        tostring(diamonds):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", ""),
                        Remaining
                    ),
                    inline = true
                }
            },
            footer = {text = "Seller: " .. LocalPlayer.DisplayName},
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

-- Main Selling Logic --
ClaimBooth()

while task.wait(5) do
    local sellQueue = {}
    
    -- Process Inventory
    for classType, items in pairs(Savemod.Get().Inventory) do
        if Config.Prices[classType] then
            for uuid, itemData in pairs(items) do
                local itemName = require(Library.Items[classType .. "Item"])(itemData.id).name
                local configData = Config.Prices[classType][itemName]
                
                if configData then
                    local matchProperties = (
                        configData.pt == itemData.pt and
                        configData.sh == itemData.sh and
                        (configData.tn or 0) == (itemData.tn or 0)
                    
                    if matchProperties then
                        local rapValue = RAPCmds.Get(require(Library.Items[classType .. "Item"])(itemData.id))
                        table.insert(sellQueue, {
                            uuid = uuid,
                            class = classType,
                            data = itemData,
                            name = itemName,
                            price = ConvertPrice(configData.Price, rapValue),
                            rap = rapValue
                        })
                    end
                end
            end
        end
    end
    
    -- Sort by RAP Descending
    table.sort(sellQueue, function(a,b) return a.rap > b.rap end)
    
    -- Create Listings
    for _, item in ipairs(sellQueue) do
        local maxAmount = math.min(item.data._am or 1, math.floor(25e9 / item.price))
        local originalAmount = item.data._am
        
        Network.Invoke("Booths_CreateListing", item.uuid, math.ceil(item.price), maxAmount)
        
        -- Track Sales
        spawn(function()
            local startTime = os.time()
            while os.time() - startTime < 60 do
                local currentAmount = Savemod.Get().Inventory[item.class][item.uuid]?._am or 0
                if currentAmount < originalAmount then
                    SendSaleNotification(
                        item.name,
                        item.price * (originalAmount - currentAmount),
                        originalAmount - currentAmount,
                        currentAmount
                    )
                    break
                end
                task.wait(5)
            end
        end)
        
        task.wait(1)
    end
    end
