"""CLI for local inspection and optional GCS/BigQuery ingestion."""

import argparse
import json
from pathlib import Path

from .config import load_settings
from .inspect_data import inspect_directory
from .logging_config import configure_logging
from .validate_data import validate_source_directory


def main() -> None:
    configure_logging()
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["inspect", "validate"])
    parser.add_argument("--data-dir", type=Path)
    args = parser.parse_args()
    directory = args.data_dir or load_settings().data_dir
    result = inspect_directory(directory) if args.command == "inspect" else validate_source_directory(directory)
    print(json.dumps(result, indent=2, default=str, ensure_ascii=False))


if __name__ == "__main__":
    main()
