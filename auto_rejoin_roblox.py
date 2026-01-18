import os
import time
import psutil
import subprocess
import sys
from plyer import notification
import datetime

# ---------------- แก้ไขตรงนี้ ----------------
PLACE_ID = 1537690962   # Place ID ของเกมคุณ

HEARTBEAT_FILE = r"C:\Users\billx\AppData\Local\seliware-autoexec\roblox_heartbeat.txt"

HEARTBEAT_TIMEOUT = 25          # วินาที ถ้าไม่ได้รับอัปเดตนานเกินนี้ → ค้าง
GRACE_PERIOD = 90               # วินาที รอหลังเปิดเกมใหม่ก่อนเริ่มตรวจ timeout จริง (ให้เวลาโหลด + เข้าเกม)
HEARTBEAT_NOTIFY_INTERVAL = 30
# ------------------------------------------------

PROCESS_NAME = "RobloxPlayerBeta.exe".lower()

last_heartbeat_notify = datetime.datetime.now() - datetime.timedelta(seconds=60)
last_launch_time = datetime.datetime.now() - datetime.timedelta(seconds=300)  # ย้อนไปก่อนเพื่อไม่ให้ grace ทำงานตอนเริ่มโปรแกรม
game_ready = False

def send_notification(title, message, timeout=8):
    try:
        notification.notify(
            title=title,
            message=message,
            app_name="Auto Rejoin Roblox",
            timeout=timeout,
        )
    except Exception as e:
        print(f"แจ้งเตือนไม่ได้: {e}")

def is_roblox_running():
    for proc in psutil.process_iter(['pid', 'name']):
        if proc.info['name'] and proc.info['name'].lower() == PROCESS_NAME:
            return True
    return False

def kill_roblox():
    killed = False
    for proc in psutil.process_iter(['pid', 'name']):
        if proc.info['name'] and proc.info['name'].lower() == PROCESS_NAME:
            try:
                proc.kill()
                print(f"Kill process PID {proc.pid} สำเร็จ")
                killed = True
            except Exception as e:
                print(f"Kill ล้มเหลว: {e}")
    return killed

def launch_roblox():
    global last_launch_time, game_ready
    join_url = f"roblox://placeId={PLACE_ID}"
    print(f"กำลังเปิด Roblox ใหม่ | Place ID: {PLACE_ID}")
    
    send_notification(
        "Roblox หยุดทำงาน!",
        f"กำลัง rejoin Place ID {PLACE_ID}... (รอโหลด {GRACE_PERIOD} วินาที)"
    )
    
    try:
        os.startfile(join_url)
    except Exception as e:
        print("os.startfile ล้มเหลว:", e)
        try:
            subprocess.Popen(["start", "", join_url], shell=True)
        except Exception as e2:
            print("เปิดไม่ได้:", e2)
            send_notification("ข้อผิดพลาด!", f"เปิด Roblox ไม่ได้: {e2}")
    
    last_launch_time = datetime.datetime.now()
    game_ready = False  # reset

# เริ่มโปรแกรม
print("Auto Rejoin Roblox (มี Grace Period ป้องกันรีโจนซ้ำ) เริ่มแล้ว...")
print(f"Place ID: {PLACE_ID} | Grace Period: {GRACE_PERIOD} วินาที")
print(f"ตรวจไฟล์: {HEARTBEAT_FILE}")
print("กด Ctrl+C เพื่อหยุด")

was_running = is_roblox_running()
if not was_running:
    launch_roblox()
    time.sleep(15)

while True:
    time.sleep(3)
    
    now = datetime.datetime.now()
    running = is_roblox_running()
    
    since_launch = (now - last_launch_time).total_seconds()
    in_grace = since_launch < GRACE_PERIOD
    
    heartbeat_age = 999
    if os.path.exists(HEARTBEAT_FILE):
        try:
            with open(HEARTBEAT_FILE, "r") as f:
                timestamp_str = f.read().strip()
                if timestamp_str.isdigit():
                    last_ts = int(timestamp_str)
                    heartbeat_age = time.time() - last_ts
                
                print(f"อ่าน heartbeat ล่าสุด: {heartbeat_age:.1f} วินาทีที่แล้ว (since launch: {since_launch:.0f}s)")
                
                if heartbeat_age < 15 and (now - last_heartbeat_notify).total_seconds() >= HEARTBEAT_NOTIFY_INTERVAL:
                    send_notification("Heartbeat ปกติ!", "เกมยังไม่ค้าง")
                    last_heartbeat_notify = now
                
                # แจ้งพร้อมเมื่อได้รับ heartbeat หลัง grace period หรือระหว่าง grace ถ้าได้เร็ว
                if not game_ready and running and heartbeat_age < 20:
                    print("ได้รับ heartbeat ปกติ → Roblox พร้อมแล้ว!")
                    send_notification(
                        "Roblox พร้อมเล่น!",
                        f"เปิดสำเร็จและ heartbeat ปกติ | Place ID: {PLACE_ID}"
                    )
                    game_ready = True
        except Exception as e:
            print("อ่านไฟล์ heartbeat ล้มเหลว:", e)
    
    # Logic หลัก: ถ้าอยู่ใน grace period → อย่ารีโจนแม้ process หายหรือ heartbeat เก่า
    if in_grace:
        print(f"ยังอยู่ใน grace period ({since_launch:.0f}/{GRACE_PERIOD}s) → รอโหลดเกมก่อน")
        was_running = running
        continue
    
    # นอก grace period แล้ว → ตรวจปกติ
    if not running:
        print("Roblox process หายไป (นอก grace) → rejoin")
        launch_roblox()
        time.sleep(15)
    
    elif heartbeat_age > HEARTBEAT_TIMEOUT:
        print(f"heartbeat เก่าเกิน {heartbeat_age:.1f}s (นอก grace) → ค้าง → kill + rejoin")
        send_notification(
            "Roblox ค้าง!",
            f"ไม่ได้รับอัปเดต {heartbeat_age:.0f} วินาที → ปิดและเปิดใหม่"
        )
        
        if kill_roblox():
            time.sleep(2)
        launch_roblox()
        time.sleep(15)
    
    was_running = running