# Auto-Rejoin Bridge for Roblox

สคริปต์ Lua สำหรับ auto rejoin เมื่อ Roblox ค้าง / disconnect / crash โดยใช้ websocket bridge เชื่อมกับ external tool (เช่น Python server)

## วิธีใช้
1. ใส่สคริปต์นี้ใน autoexec ของ executor ที่รองรับ websocket (Fluxus, Delta, Synapse, Krnl)
2. รัน server ด้านนอก (ตัวอย่าง Python websocket server) เพื่อรับ heartbeat และส่งคำสั่ง
3. เข้าเกม Roblox → สคริปต์จะส่ง heartbeat อัตโนมัติ

## การตั้งค่า
- WS_URL = "ws://127.0.0.1:5243" → เปลี่ยน port ถ้าต้องการ
- HEARTBEAT_INTERVAL = 10 → เปลี่ยนความถี่ส่ง heartbeat

## คำสั่งที่รองรับจาก server
- { "Command": "rejoin", "PlaceId": 1234567890 } → rejoin เกม
- { "Command": "shutdown" } → ปิด Roblox
- { "Command": "ping" } → ตอบ pong

**คำเตือน**: ใช้ด้วยความระมัดระวัง อาจเสี่ยง detect จาก anti-cheat Roblox
