#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZEPPELIN_HOME="$(dirname "$SCRIPT_DIR")/zeppelin-0.12.0-bin-all"

if [ ! -d "$ZEPPELIN_HOME" ]; then
  echo "Zeppelin not found."
  exit 1
fi

"$ZEPPELIN_HOME/bin/zeppelin-daemon.sh" stop
