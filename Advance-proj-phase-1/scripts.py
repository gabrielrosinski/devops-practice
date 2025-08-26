import subprocess
from pynput.keyboard import Key, Controller

def new_terminal():
    keyboard = Controller()

    # Press Ctrl+Shift+`
    with keyboard.pressed(Key.ctrl, Key.shift):
        keyboard.press('`')
        keyboard.release('`')

    print("✅ Terminal shortcut sent!")

def dev():
    """Start development server"""
    subprocess.run(['uvicorn', 'rest_app:app', '--reload'], check=True)

def test():
    """Run tests"""
    subprocess.run(['pytest'], check=True)

def lint():
    """Run linter"""
    subprocess.run(['flake8', 'app'], check=True)