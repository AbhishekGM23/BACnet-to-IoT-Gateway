# BACnet to Cloud IoT Gateway Project

## 📌 Project Overview
This project bridges the gap between legacy **Building Automation and Control Networks (BACnet)** and modern **cloud IoT platforms**. It demonstrates how to read data from industrial BACnet/MSTP devices (over RS485) and upload it to **Google Firebase Realtime Database** for remote monitoring.

### 🎯 Key Objectives
1.  **Simulate** a BACnet device on a PC (acting as an HVAC/Sensor controller).
2.  **Read** data using a Raspberry Pi Gateway via RS485 (MSTP).
3.  **Upload** the data to the Cloud (Firebase) for real-time access.

---

## 📂 Project Structure: "What & Why"

Understanding the files is crucial for maintaining or extending the project.

| File / Directory | Purpose (What it does) | Why script/code is needed |
| :--- | :--- | :--- |
| **`bacnet-stack/`** | **The Core Library** | Contains the open-source C stack that handles the complex BACnet protocol (encoding, decoding, token passing). We didn't write this from scratch; we use it as a foundation. |
| **`bacnet_to_firebase.sh`** | **The Main Gateway Script** | **(Crucial)** This Bash script runs on the Raspberry Pi. It orchestrates the whole process: calls the C tool to get data, uses `awk` to parse the text output, formatted it as JSON, and uses `curl` to push it to Firebase. |
| **`apps/server/main.c`** | **The Simulator Source** | This C program compiles into the `bacserv` tool. It simulates a BACnet device with random values (Analog Inputs, Binary Inputs) so you can test the gateway without expensive hardware sensors. |
| **`apps/epics/main.c`** | **The Client Source** | This compilies into the `bacepics` tool. It is a "Client" that asks other devices "Who are you?" and "What is your data?". Our script uses this tool to fetch the data. |
| **`src/`** | **Protocol Logic** | Contains the deep-level C code for MS/TP (RS485) communication. You usually don't need to touch this unless you are changing the protocol behavior itself. |

---

## 🛠️ Hardware Requirements
1.  **Raspberry Pi (3B/4/5):** Acts as the IoT Gateway.
2.  **Laptop/PC:** Acts as the simulated BACnet Device.
3.  **2x USB-to-RS485 Adapters:** One for the Pi, one for the Laptop.
4.  **Twisted Pair Cable:** To connect the two adapters (A to A, B to B).

---

## 🚀 How to Run the Project

### Phase 1: The Simulator (Laptop/Windows)
*We need a device to talk to. We will turn your laptop into a fake Thermostat/Sensor.*

1.  **Install MinGW:** (GCC Compiler for Windows).
2.  **Open CMD** and navigate to `bacnet-stack`.
3.  **Compile:**
    ```cmd
    mingw32-make BACNET_PORT=win32 BACDL_DEFINE=-DBACDL_MSTP=1 clean all
    ```
4.  **Run:** (Replace `COM3` with your USB-RS485 COM port).
    ```cmd
    set BACNET_IFACE=COM3
    set BACNET_MSTP_BAUD=38400
    set BACNET_MSTP_MAC=1
    set BACNET_MAX_INFO_FRAMES=10
    set BACNET_MAX_MASTER=127
    bin\bacserv 1234
    ```
    *(The Simulator is now running giving Device ID 1234).*

### Phase 2: The Gateway (Raspberry Pi/Linux)
*The Pi will ask the laptop for data and send it to the cloud.*

1.  **Install Dependencies:**
    ```bash
    sudo apt update
    sudo apt install build-essential jq
    ```
2.  **Compile:**
    ```bash
    cd bacnet-stack
    make clean mstp
    ```
3.  **Configure & Run:**
    *   Edit `bacnet_to_firebase.sh` and add your **Firebase URL**.
    *   Make it executable: `chmod +x bacnet_to_firebase.sh`
    *   Run it:
    ```bash
    ./bacnet_to_firebase.sh
    ```

---

## 📊 Viewing Data
Go to your **Firebase Console > Realtime Database**. You should see a live tree structure building up:
```json
bacnet/
  1234/
    ANALOG_INPUT_0: { "value": "24.5", "timestamp": "..." }
    BINARY_INPUT_0: { "value": "Active", "timestamp": "..." }
```

---

## ❓ Troubleshooting

*   **"bacepics not found"**: You forgot to run `make mstp` on the Pi.
*   **"jq not found"**: Install it using `sudo apt install jq`.
*   **No Data in Firebase**: Check if `curl` gave an error (e.g., 401 Unauthorized if rules deny write access, or 404 if URL is wrong).
