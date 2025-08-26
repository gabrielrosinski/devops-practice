# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a FastAPI-based REST application (`rest_app.py`) that provides basic CRUD endpoints for user management. The application uses environment variables for configuration and includes endpoints for creating, reading, updating, and deleting users.

## Development Setup

The project uses Poetry for dependency management:
- Dependencies: defined in `pyproject.toml`
- Poetry manages virtual environments automatically

### Setting up the environment:
```bash
# Install Poetry (if not already installed)
curl -sSL https://install.python-poetry.org | python3 -

# Install dependencies
poetry install
```

### Alternative setup with pip (legacy):
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## Running the Application

Start the FastAPI development server with Poetry:
```bash
poetry run python rest_app.py
```

Or with pip (legacy):
```bash
python rest_app.py
```

The server runs with these defaults (configurable via environment variables):
- Host: `0.0.0.0` (HOST env var)
- Port: `5000` (PORT env var)  
- Reload: `true` (RELOAD env var)

## API Endpoints

- `POST /users` - Create a new user
- `GET /users` - Get users (currently returns Hello World)
- `PUT /` - Update (currently returns Hello World)
- `DELETE /` - Delete (currently returns Hello World)

## Dependencies

Key packages used:
- `fastapi[standard]==0.116.1` - Web framework
- `uvicorn==0.32.0` - ASGI server
- `pydantic==2.9.2` - Data validation
- `requests==2.31.0` - HTTP client
- `pymysql==1.1.1` - MySQL database driver
- `selenium==4.34.2` - Web automation
- `webdriver-manager==4.0.2` - WebDriver management

## Notes

- The PUT and DELETE endpoints have empty paths (`""`) which may need correction
- The application loads environment variables from a `.env` file using `python-dotenv`
- Database connection setup is implied by the `pymysql` dependency but not yet implemented in the main app file