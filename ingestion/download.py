"""Download Figshare artifacts with checksum verification."""

from hashlib import md5
from pathlib import Path
from urllib.request import urlopen


def download_file(url: str, destination: Path, expected_md5: str | None = None) -> Path:
    destination.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(url) as response, destination.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    if expected_md5:
        digest = md5(destination.read_bytes()).hexdigest()
        if digest != expected_md5:
            raise ValueError(f"Checksum mismatch for {destination.name}: {digest} != {expected_md5}")
    return destination
