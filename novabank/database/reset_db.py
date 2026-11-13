#!/usr/bin/env python3
"""TiDB-compatible NovaBank schema and sample-data installer."""
from setup_tidb import install
if __name__ == '__main__': install(reset=True)
