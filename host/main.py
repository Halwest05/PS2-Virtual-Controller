import asyncio
import json
import logging
import socket
import threading
import time
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
import vgamepad as vg

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

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

BUTTON_MAP = {
    "CROSS": vg.XUSB_BUTTON.XUSB_GAMEPAD_A,
    "CIRCLE": vg.XUSB_BUTTON.XUSB_GAMEPAD_B,
    "SQUARE": vg.XUSB_BUTTON.XUSB_GAMEPAD_X,
    "TRIANGLE": vg.XUSB_BUTTON.XUSB_GAMEPAD_Y,
    
    "UP": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_UP,
    "DOWN": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_DOWN,
    "LEFT": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_LEFT,
    "RIGHT": vg.XUSB_BUTTON.XUSB_GAMEPAD_DPAD_RIGHT,
    
    "L1": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_SHOULDER,
    "R1": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_SHOULDER,
    
    "L3": vg.XUSB_BUTTON.XUSB_GAMEPAD_LEFT_THUMB,
    "R3": vg.XUSB_BUTTON.XUSB_GAMEPAD_RIGHT_THUMB,
    
    "START": vg.XUSB_BUTTON.XUSB_GAMEPAD_START,
    "SELECT": vg.XUSB_BUTTON.XUSB_GAMEPAD_BACK,
}

class ConnectionManager:
    def __init__(self):
        # Maps web socket object to a new VX360Gamepad instance
        self.active_pads: dict[WebSocket, vg.VX360Gamepad] = {}
        self.player_counter = 0

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        try:
            loop = asyncio.get_running_loop()
            # Create a brand new virtual gamepad for this specific connection
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
            
            # Notify the client of their Player Index
            index_data = json.dumps({"type": "assign_index", "index": self.player_counter})
            await websocket.send_text(index_data)
            
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
            # Deleting the pad object destroys the virtual gamepad device in Windows
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
            pressed = msg.get("pressed")
            btn_code = BUTTON_MAP.get(btn_name)
            if btn_code:
                if pressed:
                    gamepad.press_button(button=btn_code)
                else:
                    gamepad.release_button(button=btn_code)
        
        elif input_type == "trigger":
            trigger = msg.get("trigger")
            value = float(msg.get("value", 0))
            int_val = int(value * 255)
            if trigger == "L2":
                gamepad.left_trigger(value=int_val)
            elif trigger == "R2":
                gamepad.right_trigger(value=int_val)
                
        elif input_type == "stick":
            stick = msg.get("stick")
            x = float(msg.get("x", 0))
            y = float(msg.get("y", 0))
            
            val_x = int(x * 32767)
            val_y = int(y * 32767)
            
            val_x = max(-32768, min(32767, val_x))
            val_y = max(-32768, min(32767, val_y))
            
            if stick == "left":
                gamepad.left_joystick(x_value=val_x, y_value=val_y)
            elif stick == "right":
                gamepad.right_joystick(x_value=val_x, y_value=val_y)
                
        gamepad.update()
        
    except Exception as e:
        logger.error(f"Error handling input: {e}")
