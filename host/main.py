import asyncio
import json
import logging
import os
import socket
import ssl
import threading
import time

import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
import vgamepad as vg

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# Self-signed certificate generation
# ──────────────────────────────────────────────
CERT_FILE = "cert.pem"
KEY_FILE  = "key.pem"

def generate_self_signed_cert():
    """Generate a self-signed cert+key pair if they don't already exist."""
    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        return
    try:
        from cryptography import x509
        from cryptography.x509.oid import NameOID
        from cryptography.hazmat.primitives import hashes, serialization
        from cryptography.hazmat.primitives.asymmetric import rsa
        import datetime

        key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

        # Try to include all local IPs as SANs so the browser trusts the cert
        local_ips = []
        try:
            hostname = socket.gethostname()
            for ip in socket.gethostbyname_ex(hostname)[2]:
                local_ips.append(x509.IPAddress(ipaddress.ip_address(ip)))
        except Exception:
            pass
        local_ips.append(x509.IPAddress(ipaddress.ip_address("127.0.0.1")))

        subject = issuer = x509.Name([
            x509.NameAttribute(NameOID.COMMON_NAME, u"PS2Controller"),
        ])
        cert = (
            x509.CertificateBuilder()
            .subject_name(subject)
            .issuer_name(issuer)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(datetime.datetime.utcnow())
            .not_valid_after(datetime.datetime.utcnow() + datetime.timedelta(days=3650))
            .add_extension(
                x509.SubjectAlternativeName(
                    [x509.DNSName(u"localhost"), x509.DNSName(u"*")] + local_ips
                ),
                critical=False,
            )
            .sign(key, hashes.SHA256())
        )

        with open(KEY_FILE, "wb") as f:
            f.write(key.private_bytes(
                serialization.Encoding.PEM,
                serialization.PrivateFormat.TraditionalOpenSSL,
                serialization.NoEncryption(),
            ))
        with open(CERT_FILE, "wb") as f:
            f.write(cert.public_bytes(serialization.Encoding.PEM))

        logger.info("Generated self-signed TLS certificate.")
    except ImportError:
        logger.warning("'cryptography' package not installed — HTTPS disabled. Run: pip install cryptography")
    except Exception as e:
        logger.error(f"Failed to generate certificate: {e}")

import ipaddress  # needed inside generate_self_signed_cert
generate_self_signed_cert()

# ──────────────────────────────────────────────
# FastAPI app
# ──────────────────────────────────────────────
app = FastAPI()

def get_local_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "?.?.?.?"

def get_broadcast_addresses():
    bcast = ["<broadcast>", "255.255.255.255"]
    try:
        host = socket.gethostname()
        ips = socket.gethostbyname_ex(host)[2]
        for ip in ips:
            parts = ip.split('.')
            parts[-1] = '255'
            bcast.append('.'.join(parts))
    except:
        pass
    return set(bcast)

def udp_broadcast():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    while True:
        targets = get_broadcast_addresses()
        msg = b"PS2_CONTROLLER_SERVER"
        for t in targets:
            try:
                sock.sendto(msg, (t, 8001))
            except Exception:
                pass
        time.sleep(2)

threading.Thread(target=udp_broadcast, daemon=True).start()

app.mount("/client", StaticFiles(directory="../client", html=True), name="client")

@app.get("/")
async def root():
    return RedirectResponse(url="/client/index.html")

# ──────────────────────────────────────────────
# Button / input maps
# ──────────────────────────────────────────────
BUTTON_MAP = {
    "CROSS":    vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
    "CIRCLE":   vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
    "SQUARE":   vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
    "TRIANGLE": vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,

    "UP":    vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,
    "DOWN":  vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,
    "LEFT":  vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,
    "RIGHT": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,

    "L1": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
    "R1": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,

    "L3": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
    "R3": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB,

    "START":  vg.XUSB_BUTTON.XUSB_GAMEPAD_START,
    "SELECT": vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,
}

# ──────────────────────────────────────────────
# Connection Manager
# ──────────────────────────────────────────────
class ConnectionManager:
    def __init__(self):
        self.active_pads: dict[WebSocket, vg.VX360Gamepad] = {}
        self.player_counter = 0

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        try:
            loop = asyncio.get_running_loop()
            pad = vg.VX360Gamepad()
            logger.info("Created new virtual gamepad for client.")

            def rumble_callback(client, target, large_motor, small_motor, led_number, user_data):
                try:
                    msg = {"type": "rumble", "large": large_motor, "small": small_motor}
                    asyncio.run_coroutine_threadsafe(websocket.send_text(json.dumps(msg)), loop)
                except Exception as e:
                    logger.error(f"Error in rumble callback: {e}")

            pad.register_notification(rumble_callback)
            self.active_pads[websocket] = pad
            self.player_counter += 1
            await websocket.send_text(json.dumps({"type": "assign_index", "index": self.player_counter}))
        except Exception as e:
            logger.error(f"Failed to create gamepad: {e}")
            self.active_pads[websocket] = None

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_pads:
            pad = self.active_pads[websocket]
            if pad:
                try:
                    pad.unregister_notification()
                    pad.reset()
                    pad.update()
                except Exception:
                    pass
            del self.active_pads[websocket]
            logger.info("Client disconnected. Destroyed virtual controller.")

    def get_pad(self, websocket: WebSocket) -> vg.VX360Gamepad:
        return self.active_pads.get(websocket)

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            pad = manager.get_pad(websocket)
            try:
                msg = json.loads(data)
                handle_input(msg, pad)
            except json.JSONDecodeError:
                logger.warning(f"Failed to parse JSON: {data}")
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
        manager.disconnect(websocket)

def handle_input(msg: dict, gamepad: vg.VX360Gamepad):
    if not gamepad:
        return
    input_type = msg.get("type")
    try:
        if input_type == "button":
            btn_name = msg.get("button")
            pressed  = msg.get("pressed")
            btn_code = BUTTON_MAP.get(btn_name)
            if btn_code:
                if pressed:
                    gamepad.press_button(button=btn_code)
                else:
                    gamepad.release_button(button=btn_code)

        elif input_type == "trigger":
            trigger = msg.get("trigger")
            value   = float(msg.get("value", 0))
            int_val = int(value * 255)
            if trigger == "L2":
                gamepad.left_trigger(value=int_val)
            elif trigger == "R2":
                gamepad.right_trigger(value=int_val)

        elif input_type == "stick":
            stick = msg.get("stick")
            x = float(msg.get("x", 0))
            y = float(msg.get("y", 0))
            val_x = max(-32768, min(32767, int(x * 32767)))
            val_y = max(-32768, min(32767, int(y * 32767)))
            if stick == "left":
                gamepad.left_joystick(x_value=val_x, y_value=val_y)
            elif stick == "right":
                gamepad.right_joystick(x_value=val_x, y_value=val_y)

        gamepad.update()
    except Exception as e:
        logger.error(f"Error handling input: {e}")

# ──────────────────────────────────────────────
# Run both HTTP (8000) and HTTPS (8443) servers
# ──────────────────────────────────────────────
async def main():
    local_ip = get_local_ip()
    print("=" * 50)
    print(f"  HTTP  → http://{local_ip}:8000")
    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        print(f"  HTTPS → https://{local_ip}:8443  (self-signed)")
        print("  NOTE: Accept the browser security warning on first visit.")
    print("=" * 50)

    http_config = uvicorn.Config(
        app,
        host="0.0.0.0",
        port=8000,
        log_level="warning",
    )

    servers = [uvicorn.Server(http_config)]

    if os.path.exists(CERT_FILE) and os.path.exists(KEY_FILE):
        https_config = uvicorn.Config(
            app,
            host="0.0.0.0",
            port=8443,
            ssl_certfile=CERT_FILE,
            ssl_keyfile=KEY_FILE,
            log_level="warning",
        )
        servers.append(uvicorn.Server(https_config))

    await asyncio.gather(*[s.serve() for s in servers])

if __name__ == "__main__":
    asyncio.run(main())
