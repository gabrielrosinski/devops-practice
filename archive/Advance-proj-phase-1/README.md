# FastAPI User Management REST API

A FastAPI-based REST application that provides CRUD endpoints for user management with MySQL database integration.

## Project Structure

```
├── rest_app.py          # Main FastAPI application
├── db_connector.py      # Database connection and initialization
├── pyproject.toml       # Poetry configuration with dependencies
├── requirements.txt     # Pip requirements (legacy)
├── .env                 # Environment variables configuration
└── README.md           # This file
```

## Prerequisites

Before running the application, ensure you have the following installed:

- **Python 3.9+**
- **MySQL Server** (version 5.7+ or 8.0+)
- **Poetry** (recommended) or **pip** for dependency management
- **Minikube** (optional, for Kubernetes deployment)

## Environment Setup

### 1. Install Python Dependencies

#### Option A: Using Poetry (Recommended)
```bash
# Install Poetry if not already installed
curl -sSL https://install.python-poetry.org | python3 -

# Install project dependencies
poetry install

# Activate virtual environment
poetry shell
```

#### Option B: Using pip (Legacy)
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/macOS:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### 2. MySQL Database Setup with Docker

#### Install Docker and Docker Compose

**On Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install docker.io docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**On CentOS/RHEL:**
```bash
sudo yum install docker docker-compose
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker $USER
```

**On macOS:**
```bash
brew install --cask docker
# Start Docker Desktop from Applications
```

**On Windows:**
Download and install Docker Desktop from [official website](https://www.docker.com/products/docker-desktop/)

#### Start MySQL Container

**Option A: Using Docker Compose (Recommended)**

Create a `docker-compose.yml` file (already provided in the project):
```bash
docker-compose up -d mysql
```

**Option B: Using Docker Command**
```bash
docker run -d \
  --name mysql-container \
  -e MYSQL_ROOT_PASSWORD=black \
  -e MYSQL_DATABASE=users_db \
  -p 3306:3306 \
  mysql:8.0
```

#### Verify MySQL Container
```bash
# Check if container is running
docker ps

# Check MySQL logs
docker logs mysql-container

# Connect to MySQL (optional)
docker exec -it mysql-container mysql -u root -p
```

### 3. Environment Configuration

Copy and configure the environment variables:

```bash
# The .env file should contain:
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=black
DB_NAME=users_db
DB_ROOT_USER=root
DB_ROOT_PASSWORD=black
```

**Important:** Update the passwords in `.env` file to match your MySQL configuration.

## Running the Application

### 1. Start MySQL Container
Ensure MySQL Docker container is running:
```bash
# Using Docker Compose
docker-compose up -d mysql

# Or using Docker command directly
docker start mysql-container

# Verify container is running
docker ps | grep mysql
```

### 2. Run the FastAPI Application

#### Using Poetry:
```bash
poetry run python rest_app.py
```

#### Using pip:
```bash
python rest_app.py
```

The application will:
- Start on `http://0.0.0.0:5000` by default
- Automatically create the database and tables if they don't exist
- Enable hot reload in development mode

### 3. Verify the Application

- **API Documentation:** http://localhost:5000/docs
- **Alternative docs:** http://localhost:5000/redoc
- **Health check:** Access any endpoint to verify the database connection

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/users` | Create a new user |
| GET | `/users/{user_id}` | Get user by ID |
| PUT | `/users/{user_id}` | Update user information |
| DELETE | `/users/{user_id}` | Delete user by ID |

### Example API Usage

**Create a user:**
```bash
curl -X POST "http://localhost:5000/users" \
     -H "Content-Type: application/json" \
     -d '{"user_name": "john_doe"}'
```

**Get a user:**
```bash
curl -X GET "http://localhost:5000/users/1"
```

## Database Schema

The application automatically creates a `users` table with the following structure:

```sql
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_name VARCHAR(50) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

## Configuration Options

Environment variables can be set to customize the application:

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Server host address |
| `PORT` | `5000` | Server port |
| `RELOAD` | `true` | Enable hot reload |
| `DB_HOST` | `localhost` | MySQL host |
| `DB_USER` | `root` | MySQL username |
| `DB_PASSWORD` | `password` | MySQL password |
| `DB_NAME` | `users_db` | Database name |

## Minikube Setup (Optional)

If you plan to deploy on Kubernetes using Minikube:

### 1. Install Minikube
```bash
# On Linux
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# On macOS
brew install minikube

# On Windows
choco install minikube
```

### 2. Start Minikube
```bash
minikube start
minikube dashboard  # Optional: Access Kubernetes dashboard
```

### 3. Deploy MySQL in Minikube
```bash
# Deploy MySQL (you'll need to create Kubernetes manifests)
kubectl create deployment mysql --image=mysql:8.0
kubectl set env deployment/mysql MYSQL_ROOT_PASSWORD=black
kubectl set env deployment/mysql MYSQL_DATABASE=users_db
kubectl expose deployment mysql --port=3306
```

## Troubleshooting

### Common Issues

1. **Database Connection Failed:**
   - Verify MySQL container is running: `docker ps | grep mysql`
   - Check credentials in `.env` file
   - Restart MySQL container: `docker restart mysql-container`
   - Check container logs: `docker logs mysql-container`

2. **Port Already in Use:**
   - Change the `PORT` environment variable
   - Kill existing processes: `lsof -ti:5000 | xargs kill -9`

3. **Module Import Errors:**
   - Ensure virtual environment is activated
   - Reinstall dependencies: `poetry install` or `pip install -r requirements.txt`

4. **Permission Denied:**
   - Check MySQL user privileges
   - Run MySQL secure installation: `sudo mysql_secure_installation`

### Logs and Debugging

- Application logs are displayed in the console
- MySQL logs location (varies by system):
  - Linux: `/var/log/mysql/error.log`
  - macOS: `/usr/local/var/mysql/*.err`
  - Windows: `C:\ProgramData\MySQL\MySQL Server 8.0\Data\*.err`

## Development

### Dependencies

**Core Dependencies:**
- `fastapi[standard]==0.116.1` - Web framework
- `uvicorn==0.32.0` - ASGI server
- `pydantic==2.9.2` - Data validation
- `pymysql==1.1.1` - MySQL database driver

**Additional Dependencies:**
- `requests==2.31.0` - HTTP client
- `selenium==4.34.2` - Web automation
- `webdriver-manager==4.0.2` - WebDriver management
- `python-dotenv` - Environment variable loading

### Code Structure

- **rest_app.py**: Main FastAPI application with route definitions
- **db_connector.py**: Database connection management and initialization
- **User Model**: Pydantic model for user data validation

## License

This project is for educational/development purposes.