"""Shared destination for installed Mario In ROMs and companion files."""
from pathlib import Path

INSTALL_DIR = Path("C:/nes/Mario In")

def ensure_install_dir():
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)
    return INSTALL_DIR
