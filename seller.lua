repeat task.wait() until game:IsLoaded()
local LocalPlayer = game:GetService("Players").LocalPlayer
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

local Library = game.ReplicatedStorage.Library
local Client = Library.Client
local HttpService = game:GetService("HttpService")

-- تفعيل طلبات HTTP
if not HttpService:GetHttpEnabled() then
    HttpService:SetHttpEnabled(true)
end

local RAPCmds = require(Client.RAPCmds)
local Network = require(Client.Network)
local Savemod = require(Client.Save)

-- الانتقال إلى ساحة التداول
if game.PlaceId == 8737899170 or game.PlaceId == 16498369169 then
    while true do 
        Network.Invoke("Travel to Trading Plaza") 
        task.wait(1) 
    end
end

-- حجز الكشك
local HaveBooth = false
while not HaveBooth do 
    local BoothSpawns = workspace.TradingPlaza.BoothSpawns:FindFirstChildWhichIsA("Model")
    for _, Booth in ipairs(workspace.__THINGS.Booths:GetChildren()) do
        if Booth:IsA("Model") and Booth.Info.BoothBottom.Frame.Top.Text == LocalPlayer.DisplayName.."'s Booth!" then
            HaveBooth = true
            LocalPlayer.Character.HumanoidRootPart.CFrame = Booth.Table.CFrame * CFrame.new(5, 0, 0)
            break
        end
    end
    if not HaveBooth then
        LocalPlayer.Character.HumanoidRootPart.CFrame = BoothSpawns.Table.CFrame * CFrame.new(5, 0, 0)
        Network.Invoke("Booths_ClaimBooth", tostring(BoothSpawns:GetAttribute("ID")))
    end
    task.wait(1)
end

-- منع AFK
local VirtualUser = game:GetService("VirtualUser")
for _, v in pairs(getconnections(LocalPlayer.Idled)) do v:Disable() end
LocalPlayer.Idled:Connect(function()
    VirtualUser:ClickButton2(Vector2.new(math.random(0, 1000), math.random(0, 1000)))
end)

-- دالة إرسال الويبهوك
local function sendWebhook(itemName, price, amountSold, remaining, diamonds)
    local formatNumber = function(num)
        return tostring(num):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
    end
    
    local data = {
        ["content"] = "",
        ["embeds"] = {{
            ["title"] = "New Item Sold 🥳",
            ["description"] = string.format(
                "**Item Sold Info**\n> Item = %s\n> Value = %s\n> Amount = %s\n> In Inventory = %s\n\n**Seller Info**\n> Diamond = %s\n> Account = ||%s||",
                itemName,
                "💎 "..formatNumber(price),
                formatNumber(amountSold),
                formatNumber(remaining),
                formatNumber(diamonds),
                LocalPlayer.Name -- اسم حسابك هنا
            ),
            ["color"] = 65280,
            ["thumbnail"] = {
                ["url"] = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId="..(Library.GetItemIcon(itemName) or "")
            }
        }}
    }
    
    local success, err = pcall(function()
        HttpService:PostAsync(GhostSeller.WEBHOOK_URL, HttpService:JSONEncode(data))
    end)
    
    if not success then
        print("❌ [Webhook Error]:", err)
    else
        print("✅ تم إرسال إشعار!")
    end
end

-- اكتشاف عملية البيع
local Booths = workspace:FindFirstChild("Booths") or workspace:WaitForChild("__THINGS").Booths
Booths.ChildAdded:Connect(function(booth)
    booth.Info.Transactions.ChildAdded:Connect(function(transaction)
        local itemName = transaction:GetAttribute("ItemName")
        local price = transaction:GetAttribute("Price")
        local amount = transaction:GetAttribute("Amount") or 1
        local itemClass = transaction:GetAttribute("ItemClass") or "Pet"
        
        -- حساب الكمية المتبقية
        local remaining = 0
        for _, v in pairs(Savemod.Get().Inventory[itemClass] or {}) do
            local item = require(Library.Items[itemClass.."Item"])(v.id)
            if item.name == itemName then
                remaining += (v._am or 1)
            end
        end
        
        -- إرسال البيانات
        sendWebhook(itemName, price, amount, remaining, Savemod.Get().Diamonds or 0)
    end)
end)

-- عرض العناصر في الكشك
while task.wait(5) do 
    local BoothQueue = {}
    for Class, Items in pairs(Savemod.Get().Inventory) do
        if GhostSeller.Items[Class] then
            for _, v in pairs(Items) do
                local Item = GhostSeller.Items[Class][v.id]
                if Item and Item.pt == v.pt and Item.sh == v.sh and Item.tn == v.tn then
                    table.insert(BoothQueue, {Price = Item.Price, UUID = _, Item = v, Rap = RAPCmds.Get(require(Library.Items[Class.."Item"])(v.id))})
                end
            end
        end
    end
    table.sort(BoothQueue, function(a, b) return a.Rap > b.Rap end)
    
    for _, v in ipairs(BoothQueue) do
        local MaxAmount = math.min(v.Item._am or 1, 15000, math.floor(25e9 / (v.Price == "100%" and v.Rap or v.Price)))
        Network.Invoke("Booths_CreateListing", v.UUID, (v.Price == "100%" and v.Rap or v.Price), MaxAmount)
        task.wait(1)
    end
end
