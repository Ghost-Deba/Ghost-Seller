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

-- Improved Booth Claiming System --
local function SafeWaitForChild(parent, childName, timeout)
    local endTime = os.time() + (timeout or 30)
    repeat
        local child = parent:FindFirstChild(childName)
        if child then return child end
        task.wait(1)
    until os.time() > endTime
    return nil
end

local function ClaimBooth()
    local maxAttempts = 30 -- 30 attempts max
    local attempts = 0
    
    -- Wait for Trading Plaza to load
    local tradingPlaza = SafeWaitForChild(workspace, "TradingPlaza", 60)
    if not tradingPlaza then 
        warn("Failed to find Trading Plaza")
        return false
    end

    repeat
        attempts += 1
        
        -- Wait for Character
        if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
            task.wait(1)
            continue
        end

        -- Find Existing Booth
        local myBooth
        local booths = workspace.__THINGS.Booths:GetChildren()
        for _, booth in ipairs(booths) do
            if booth:FindFirstChild("Info") then
                local boothText = booth.Info.BoothBottom.Frame.Top.Text
                if boothText:find(LocalPlayer.DisplayName, 1, true) then
                    myBooth = booth
                    break
                end
            end
        end

        -- Move to Booth if Found
        if myBooth then
            LocalPlayer.Character.HumanoidRootPart.CFrame = myBooth.Table.CFrame * Config.BoothPosition
            return true
        end

        -- Claim New Booth
        local boothSpawns = SafeWaitForChild(tradingPlaza, "BoothSpawns", 10)
        if boothSpawns then
            local spawnPoint = boothSpawns:FindFirstChildWhichIsA("Model")
            if spawnPoint then
                LocalPlayer.Character.HumanoidRootPart.CFrame = spawnPoint.Table.CFrame * Config.BoothPosition
                pcall(function()
                    Network.Invoke("Booths_ClaimBooth", tostring(spawnPoint:GetAttribute("ID")))
                end)
            end
        end

        task.wait(2)
    until attempts >= maxAttempts

    warn("Failed to claim booth after", maxAttempts, "attempts")
    return false
end

-- بقية الكود بدون تغيير (Anti AFK, Webhook, etc.) --

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
