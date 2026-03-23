# PS2 Virtual Controller

A fully functional, web-based PlayStation 2 virtual controller that runs on your smartphone and instantly connects to your Windows PC over local Wi-Fi. It emulates a physical Xbox 360 controller via `vgamepad`, giving you native plug-and-play support in almost all modern PC games and emulators!

## 🎮 Features
- **Flutter Android Client:** A native Android app with haptic feedback (vibration) for a true console experience, and auto-discovery of the host PC.
- **Zero-Latency Local Web Socket:** Instantly streams your touch inputs directly to your PC without internet dependencies.
- **Fully Customizable Layout:** Hit "Edit Layout" to drag, drop, and resize individual buttons or groups to match your exact hand size and preferences.
- **Persistent Memory:** Your custom layout saves locally to your mobile device and instantly restores the next time you open the controller.
- **Multi-Touch Support:** Engineered for multi-touch accuracy to handle dual-analog movement while pressing multiple action buttons simultaneously.
- **PWA Support (Web Client):** Add it to your smartphone's Home Screen to launch it in full-screen as a standalone native app!

## 📹 Demo
*(Watch the controller in action seamlessly driving gameplay in **God of War 2**, mirrored directly from phone to PC!)*

![Demo of PS2 Controller playing God of War 2 via Windows Phone Link](demo.gif)

---

## 🚀 Installation & Setup

### Prerequisites
- A **Windows PC** (required for the `vgamepad` virtual controller driver).
- **Python 3.7+** installed on your system.
- Your PC and smartphone must be on the **same local network (Wi-Fi/LAN)**.

### Step 1: Install Dependencies
Open your terminal inside the project directory and install the required Python libraries:
```bash
pip install -r requirements.txt
```

### Step 2: Start the Server
Run the provided batch file or execute the uvicorn command directly:
```bash
# Easy start via batch script
start_server.bat

# Or start it manually
uvicorn host.main:app --host 0.0.0.0 --port 8000
```
When the server starts, it will print your PC's local IP address in the console.

### Step 3: Connect your Smartphone
1. Open the web browser on your phone.
2. Navigate to the IP address printed in the console (e.g., `http://192.168.1.5:8000`).
3. Tap **"ENTER FULLSCREEN"**. 
4. The server will assign you a Player Index (e.g., `[P1]`), confirming your virtual gamepad is successfully plugged into Windows!

## 🛠️ Layout Customization
1. Tap the **"Edit Layout"** button floating at the top right of the controller screen.
2. **Move:** Drag any button or control group across the screen.
3. **Resize:** Tap to select a button, then use the slider at the top to scale it up or down.
4. **Save:** Tap "**Save Layout**" to lock your changes in place.
If you ever want to revert everything back to standard, jump into Edit Layout and press **"Reset Defaults"**.

## 💻 Tech Stack
- **Backend:** Python, FastAPI, Uvicorn, VGamepad
- **Frontend (Web):** Vanilla HTML5, CSS3, JavaScript (WebSocket, Touch Events)
- **Frontend (Android):** Flutter, Dart (with vibration support)

## 👋 Credits
Created and developed by **Halwest**.

## 📝 License
This project is open-source. Feel free to fork, modify, and improve upon the virtual controller design!
