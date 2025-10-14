# Thermostat Data Logger & Grafana Integration

This FastAPI-based server provides a real-time interface between a **network-connected thermostat** (communicating via TCP socket) and **Grafana** for live data visualization.

The server polls the thermostat every second, processes its JSON responses, stores the data in CSV format, and exposes endpoints to query the latest readings or stream the full dataset for visualization.

---

## 📡 How It Works

### 1. Communication with the Thermostat

* The thermostat runs a **simple TCP socket interface** (SCPI-like commands on port 23).
* The server connects to it and sends the `report` command:

  ```text
  report\n
  ```
* The thermostat returns a **JSON array**, e.g.:

  ```json
  [
    {"channel": 0, "temperature": 25.0, "i_tec": 1.5, ...},
    {"channel": 1, "temperature": 31.9, "i_tec": 1.55, ...}
  ]
  ```
* Each object represents one channel (CH0 or CH1).

### 2. Server Processing

* Every **1 second**, the server:

  1. Connects to the thermostat.
  2. Sends `report\n`.
  3. Parses the JSON response.
  4. Adds timestamps:

     * `time`: ISO-8601 UTC (`2025-10-14T19:51:58.892Z`)
     * `ts`: Epoch milliseconds.
  5. Stores all data in a **wide-format CSV**:

     ```
     time,ts,temperature_ch0,temperature_ch1,i_tec_ch0,i_tec_ch1,...
     ```
  6. Keeps the last ~10 minutes of readings in memory for `/report` and `/series` APIs.

### 3. Grafana Visualization

* The server exposes `/data.csv`, which Grafana fetches periodically.
* Using the **Infinity plugin**, Grafana plots metrics like `temperature_ch0` and `temperature_ch1` over time.
* You can also visualize other numeric fields (`i_tec`, `pid_output`, etc.) in additional panels.

---

## 🧰 Features

| Endpoint                      | Description                                              |
| ----------------------------- | -------------------------------------------------------- |
| **`/report`**                 | Returns the most recent reading (two channels).          |
| **`/series?from=...&to=...`** | Returns data between two timestamps (epoch ms).          |
| **`/data.csv`**               | Serves the combined CSV (one row per second).            |
| **`/save_once`**              | Forces one immediate poll and CSV write (for debugging). |

---

## 🧩 Dependencies

Install Python 3.8+ and the following packages:

```bash
pip install fastapi uvicorn
```

Optionally, for debugging:

```bash
pip install requests jq
```

---

## ⚙️ Configuration

Edit these constants in `server.py` to match your setup:

```python
HOST = "192.168.1.26"        # Thermostat IP address
PORT = 23                    # TCP port
POLL_PERIOD = 1.0            # Polling interval in seconds
CSV_PATH = "/home/jrydberg/Documents/Projects/thermostat_data.csv"
FIELDS = [
    "temperature", "i_tec", "pid_output",
    "adc", "sens", "i_set", "dac_value", "dac_feedback",
    "tec_i", "tec_u_meas", "pid_engaged", "current_swapped", "interval"
]
```

---

## 🚀 How to Start the Server

### 1. Run manually

```bash
uvicorn server:app --host 0.0.0.0 --port 8000
```

Visit [http://localhost:8000/docs](http://localhost:8000/docs) for the interactive API.

### 2. Verify data collection

```bash
# Force one data collection and CSV write
curl -X POST http://localhost:8000/save_once

# Check that the CSV file exists
ls -lh /home/jrydberg/Documents/Projects/thermostat_data.csv
head -5 /home/jrydberg/Documents/Projects/thermostat_data.csv
```

---

## 🖥️ Grafana Setup

1. Install Grafana and the **Infinity datasource** plugin:

   ```bash
   sudo grafana-cli plugins install yesoreyeram-infinity-datasource
   sudo systemctl restart grafana-server
   ```
2. Add a new **Infinity** datasource:

   * URL: `http://localhost:8000`
3. Create a new panel:

   * Query → URL: `/data.csv`
   * Format: CSV
   * Parser: **Frontend**
   * Map fields:

     * `time` → **Time**
     * `temperature_ch0` → **Number**
     * `temperature_ch1` → **Number**
   * Visualization: **Time Series**
   * Unit: **°C**

Now Grafana will show live temperature traces for both channels.

---

## 🧩 Optional: Run as a system service

Create `/etc/systemd/system/thermostat-api.service`:

```ini
[Unit]
Description=Thermostat JSON/CSV API
After=network.target

[Service]
User=jrydberg
WorkingDirectory=/home/jrydberg/Documents/Projects/Artiq_envs/defult/Artiq_VM/Experiments/Thermostat
ExecStart=/usr/bin/uvicorn server:app --host 0.0.0.0 --port 8000
Restart=always
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable thermostat-api
sudo systemctl start thermostat-api
sudo systemctl status thermostat-api
```

---

## 📁 Output Example

```
time,ts,temperature_ch0,temperature_ch1,i_tec_ch0,i_tec_ch1,pid_output_ch0,pid_output_ch1,...
2025-10-14T19:51:56.877487+00:00,1760471516877, ,31.99,1.514,1.553,0.0,0.267,...
2025-10-14T19:51:57.887253+00:00,1760471517887, ,31.99,1.514,1.554,0.0,0.264,...
```

---

## 🧠 Summary

* **Purpose**: Bridge your networked thermostat’s TCP API to Grafana.
* **How**: FastAPI polls, parses, timestamps, and writes CSV.
* **Why**: Gives you a robust, real-time dashboard without needing InfluxDB or Prometheus.
* **Extendable**: Add more channels or fields by editing the `FIELDS` list.

---

Would you like me to add a small diagram (ASCII or Mermaid) showing how the thermostat ↔ server ↔ Grafana data flow works for this README?
