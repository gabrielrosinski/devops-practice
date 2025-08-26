
---

## 🚀 Features

- 📊 Earthquake data dashboard
- 📁 Structured logging to `/var/log/flask-data`
- 🐳 Fully containerized with Docker
- 🧱 Modular Flask structure (blueprints-friendly)
- 🔄 Live development ready

---

### 🧰 Prerequisites

Install [Docker](https://www.docker.com/products/docker-desktop) and [Docker Compose](https://docs.docker.com/compose/install/) for your platform:

---

### 🪟 For Windows Users

1. Install **Docker Desktop for Windows**
2. Install and enable **WSL 2** (if not already):
   - [WSL 2 installation guide](https://learn.microsoft.com/en-us/windows/wsl/install)
3. Enable WSL integration in Docker Desktop:
   - **Settings → Resources → WSL Integration → Enable for your distro (e.g., Ubuntu)**
4. Restart Docker Desktop and your terminal

---

### 🐧 For Linux Users

1. Install Docker Engine:
   ```bash
   sudo apt update
   sudo apt install docker.io docker-compose -y

### ▶️ Run the App

From the project root (`Final project phase 1/`):

### Pull from dockerHub and run
```bash
docker compose up --no-build  
```
OR 

### Build local image then run
```bash
docker compose build
docker compose up
```

### Access running app
You can access the app web page in the browser in this address. http://localhost:5000

### Link to image on docker hub
https://hub.docker.com/r/blaqr/earthquake