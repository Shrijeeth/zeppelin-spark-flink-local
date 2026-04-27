#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZEPPELIN_HOME="$(dirname "$SCRIPT_DIR")/zeppelin-0.12.0-bin-all"

if [ ! -d "$ZEPPELIN_HOME" ]; then
  echo "Zeppelin not found. Run scripts/setup.sh first."
  exit 1
fi

"$ZEPPELIN_HOME/bin/zeppelin-daemon.sh" start
echo ""
echo "Open: http://localhost:8080"
echo "Spark UI: http://localhost:4040  (after first %spark paragraph)"
echo "Flink UI: http://localhost:8081  (after first %flink paragraph)"
