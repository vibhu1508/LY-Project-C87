"""Allow running as ``python -m framework``, which powers the ``teamagents`` console entry point."""

from framework.cli import main

if __name__ == "__main__":
    main()
