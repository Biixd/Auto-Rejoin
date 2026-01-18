-- auto_rejoin_bridge.lua
-- เวอร์ชันปรับแต่งจาก Nexus สำหรับ Auto Rejoin (websocket + heartbeat)
-- ใส่ใน autoexec หรือ execute ทุกครั้งที่เข้าเกม

if _G.AutoRejoinBridge then return end  -- ป้องกันรันซ้ำ
_G.AutoRejoinBridge = true

local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
    LocalPlayer = Players.PlayerAdded:Wait()
end

-- ================== ตั้งค่า ==================
local WS_URL = "ws://127.0.0.1:5243"  -- เปลี่ยน port ได้ตาม server Python ของคุณ
local HEARTBEAT_INTERVAL = 10         -- วินาที
local SHUTDOWN_ON_DISCONNECT = true   -- ถ้า disconnect นาน ให้ shutdown client
local DISCONNECT_TIMEOUT = 45         -- วินาที

-- ================== WebSocket ==================
local WebSocketConnect = syn and syn.websocket.connect
    or (Krnl and Krnl.WebSocket.connect)
    or WebSocket and WebSocket.connect

if not WebSocketConnect then
    warn("[AutoRejoinBridge] WebSocket ไม่รองรับใน executor นี้")
    return
end

local socket
local isConnected = false

local function connectWS()
    local success, err = pcall(function()
        socket = WebSocketConnect(WS_URL)
    end)
    
    if not success then
        warn("[AutoRejoinBridge] เชื่อม websocket ล้มเหลว: " .. tostring(err))
        task.delay(5, connectWS)  -- retry
        return
    end
    
    socket.OnMessage:Connect(function(message)
        local success, data = pcall(function()
            return HttpService:JSONDecode(message)
        end)
        
        if success and data.Command then
            print("[AutoRejoinBridge] รับคำสั่ง: " .. data.Command)
            
            if data.Command == "rejoin" then
                if data.PlaceId then
                    TeleportService:Teleport(data.PlaceId, LocalPlayer)
                else
                    TeleportService:Teleport(game.PlaceId, LocalPlayer)
                end
                
            elseif data.Command == "shutdown" then
                game:Shutdown()
                
            elseif data.Command == "ping" then
                socket:Send(HttpService:JSONEncode({ Response = "pong" }))
            end
        end
    end)
    
    socket.OnClose:Connect(function()
        isConnected = false
        print("[AutoRejoinBridge] WebSocket ปิด → พยายามเชื่อมใหม่")
        task.delay(5, connectWS)
    end)
    
    isConnected = true
    print("[AutoRejoinBridge] เชื่อม websocket สำเร็จ: " .. WS_URL)
end

connectWS()

-- ================== Heartbeat ส่งทุก 10 วินาที ==================
spawn(function()
    while true do
        task.wait(HEARTBEAT_INTERVAL)
        
        if isConnected and socket then
            local success, err = pcall(function()
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
            
            if not success then
                warn("[AutoRejoinBridge] ส่ง heartbeat ล้มเหลว: " .. tostring(err))
            end
        end
    end
end)

-- ================== จัดการ Disconnect / Error (คล้าย Nexus) ==================
if SHUTDOWN_ON_DISCONNECT then
    local disconnectStart = nil
    
    GuiService.ErrorMessageChanged:Connect(function()
        local code = GuiService:GetErrorCode()
        if code >= Enum.ConnectionError.DisconnectErrors.Value then
            if not disconnectStart then
                disconnectStart = tick()
            end
        else
            disconnectStart = nil
        end
    end)
    
    RunService.Heartbeat:Connect(function()
        if disconnectStart and (tick() - disconnectStart) > DISCONNECT_TIMEOUT then
            print("[AutoRejoinBridge] Disconnect นานเกิน → Shutdown client")
            game:Shutdown()
        end
    end)
end

-- ================== OnTeleport Cleanup ==================
LocalPlayer.OnTeleport:Connect(function(state)
    if state == Enum.TeleportState.Started and isConnected then
        if socket then
            socket:Close()
        end
    end
end)

print("[AutoRejoinBridge] โหลดสำเร็จ | WS: " .. WS_URL .. " | Heartbeat: ทุก " .. HEARTBEAT_INTERVAL .. " วินาที")