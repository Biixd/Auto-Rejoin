-- auto_rejoin_bridge.lua (สคริปต์หลักที่ดึงจาก GitHub)
-- ส่ง heartbeat ผ่าน websocket + รับคำสั่ง rejoin/shutdown

if _G.AutoRejoinBridgeLoaded then return end
_G.AutoRejoinBridgeLoaded = true

print("[AutoRejoinBridge] เวอร์ชัน 1.0 - โหลดสำเร็จ")

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer or Players.PlayerAdded:Wait()

-- ตั้งค่า websocket
local WS_URL = "ws://127.0.0.1:5243"  -- เปลี่ยน port ได้ตาม server
local HEARTBEAT_INTERVAL = 10
local DISCONNECT_TIMEOUT = 45

local WebSocketConnect = syn and syn.websocket.connect
    or (Krnl and Krnl.WebSocket.connect)
    or WebSocket and WebSocket.connect

if not WebSocketConnect then
    warn("[AutoRejoinBridge] Executor ไม่รองรับ WebSocket")
    return
end

local socket = nil
local isConnected = false

local function connectWS()
    local success = pcall(function()
        socket = WebSocketConnect(WS_URL)
    end)

    if not success then
        warn("[AutoRejoinBridge] เชื่อม websocket ล้มเหลว")
        task.delay(5, connectWS)
        return
    end

    socket.OnMessage:Connect(function(msg)
        local success, data = pcall(HttpService.JSONDecode, HttpService, msg)
        if success and data.Command then
            if data.Command == "rejoin" then
                TeleportService:Teleport(data.PlaceId or game.PlaceId, LocalPlayer)
            elseif data.Command == "shutdown" then
                game:Shutdown()
            elseif data.Command == "ping" then
                socket:Send(HttpService:JSONEncode({Response = "pong"}))
            end
        end
    end)

    socket.OnClose:Connect(function()
        isConnected = false
        task.delay(5, connectWS)
    end)

    isConnected = true
    print("[AutoRejoinBridge] WebSocket เชื่อมต่อสำเร็จ")
end

connectWS()

-- ส่ง heartbeat
spawn(function()
    while true do
        task.wait(HEARTBEAT_INTERVAL)
        if isConnected and socket then
            pcall(function()
                local payload = {
                    Type = "heartbeat",
                    Timestamp = os.time(),
                    PlaceId = game.PlaceId,
                    JobId = game.JobId or "N/A",
                    PlayerName = LocalPlayer.Name,
                    UserId = LocalPlayer.UserId
                }
                socket:Send(HttpService:JSONEncode(payload))
            end)
        end
    end
end)

-- จัดการ disconnect timeout
local disconnectStart
GuiService.ErrorMessageChanged:Connect(function()
    if GuiService:GetErrorCode() >= Enum.ConnectionError.DisconnectErrors.Value then
        disconnectStart = disconnectStart or tick()
    else
        disconnectStart = nil
    end
end)

RunService.Heartbeat:Connect(function()
    if disconnectStart and tick() - disconnectStart > DISCONNECT_TIMEOUT then
        game:Shutdown()
    end
end)

print("[AutoRejoinBridge] พร้อมใช้งาน - ส่ง heartbeat ทุก " .. HEARTBEAT_INTERVAL .. " วินาที")
