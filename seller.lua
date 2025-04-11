repeat task.wait() until game:IsLoaded()
local LocalPlayer = game:GetService("Players").LocalPlayer
repeat task.wait() until not LocalPlayer.PlayerGui:FindFirstChild("__INTRO")

--═══════ إعدادات الويب هوك ═══════--
local CUSTOM_USERNAME = "Plaza Seller"
local CUSTOM_AVATAR = "https://i.imgur.com/AVATAR.jpg"
local FOOTER_ICON = "https://i.imgur.com/FOOTER.png"

--═══════ إعدادات السكريبت الأساسية ═══════--
local Library = game:GetService("ReplicatedStorage").Library
local Client = Library.Client
local Network = require(Client.Network)
local Savemod = require(Client.Save)
local HttpService = game:GetService("HttpService")

--═══════ دالات المساعدة ═══════--
local FormatInt = function(int)
    return tostring(int):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

local GetRap = function(Class, ItemTable)
    local Item = require(Library.Items[Class.."Item"])(ItemTable.id)
    if ItemTable.sh then Item:SetShiny(true) end
    if ItemTable.pt == 1 then Item:SetGolden() end
    return RAPCmds.Get(Item) or 0
end

--═══════ إرسال ويبهوك مخصص ═══════--
local SendWebhook = function(itemName, price, amount)
    local data = {
        username = CUSTOM_USERNAME,
        avatar_url = CUSTOM_AVATAR,
        embeds = {{
            title = "🎉 تم البيع بنجاح!",
            description = string.format(
                "**العنصر:** %s\n**السعر:** 💎 %s\n**الكمية:** %s",
                itemName,
                FormatInt(price),
                amount
            ),
            color = 0x00FF00,
            footer = {
                text = "Plaza Seller • " .. os.date("%d/%m/%Y"),
                icon_url = FOOTER_ICON
            },
            thumbnail = {
                url = "https://www.roblox.com/Thumbs/Asset.ashx?width=420&height=420&assetId="..game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId).IconImageAssetId
            }
        }}
    }

    local success, err = pcall(function()
        syn.request({
            Url = GhostSniper.WebhookUrl,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = HttpService:JSONEncode(data)
        })
    end)

    if not success then
        warn("فشل إرسال الويب هوك:", err)
    end
end

--═══════ الانتقال إلى ساحة التداول ═══════--
if game.PlaceId == 8737899170 then
    for _ = 1, 3 do
        Network.Invoke("Travel to Trading Plaza")
        task.wait(1)
    end
end

--═══════ حجز الكشك ═══════--
local function ClaimBooth()
    local BoothSpawns = workspace.TradingPlaza.BoothSpawns:FindFirstChildWhichIsA("Model")
    if not BoothSpawns then return false end

    LocalPlayer.Character.HumanoidRootPart.CFrame = BoothSpawns.Table.CFrame * CFrame.new(5, 0, 0)
    Network.Invoke("Booths_ClaimBooth", tostring(BoothSpawns:GetAttribute("ID")))
    task.wait(1)
    
    return BoothSpawns:GetAttribute("Owner") == LocalPlayer.UserId
end

repeat task.wait() until ClaimBooth()

--═══════ منع AFK ═══════--
for _, v in pairs(getconnections(LocalPlayer.Idled)) do 
    v:Disable() 
end

--═══════ اكتشاف عملية البيع ═══════--
workspace.__THINGS.Booths.ChildAdded:Connect(function(booth)
    booth.Info.Transactions.ChildAdded:Connect(function(transaction)
        local itemName = transaction:GetAttribute("ItemName")
        local price = transaction:GetAttribute("Price")
        local amount = transaction:GetAttribute("Amount") or 1
        SendWebhook(itemName, price, amount)
    end)
end)

--═══════ عرض العناصر في الكشك ═══════--
while task.wait(5) do 
    for Class, Items in pairs(Savemod.Get().Inventory) do
        if GhostSniper.Items[Class] then
            for _, v in pairs(Items) do
                local Item = GhostSniper.Items[Class][v.id]
                if Item then
                    local MaxAmount = math.min(v._am or 1, 15000)
                    Network.Invoke("Booths_CreateListing", _, (Item.Price == "100%" and GetRap(Class, v) or Item.Price), MaxAmount)
                    task.wait(0.5)
                end
            end
        end
    end
endAmount)
        task.wait(1)
    end
end
