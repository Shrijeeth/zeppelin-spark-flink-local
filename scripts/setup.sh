#!/bin/bash
# =============================================================================
# Zeppelin + Spark + Flink Local Practice Setup
# Supports: Scala, Python, Java, SQL — all in one notebook
# No cluster needed — everything runs in local mode

# What setup.sh does automatically:                                                                                                                                                                                      
# 1. Downloads Zeppelin 0.12.0                                                                                                                                                                                         
# 2. Creates Python 3.11 venv → installs PySpark 3.5.1                                                                                                                                                                   
# 3. Creates Python 3.10 venv → installs apache-flink 1.17.2                                                                                                                                                           
# 4. Fixes missing Flink jars (moves from opt/, downloads Scala bridge jars from Maven)                                                                                                                                  
# 5. Writes zeppelin-env.sh with correct paths                                                                                                                                                                           
# 6. Patches interpreter.json   
# =============================================================================
set -e

ZEPPELIN_VERSION="0.12.0"
ZEPPELIN_DIR="zeppelin-${ZEPPELIN_VERSION}-bin-all"
ZEPPELIN_TGZ="${ZEPPELIN_DIR}.tgz"
ZEPPELIN_URL="https://archive.apache.org/dist/zeppelin/zeppelin-${ZEPPELIN_VERSION}/${ZEPPELIN_TGZ}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[setup]${NC} $1"; }
warn() { echo -e "${YELLOW}[warn]${NC}  $1"; }
fail() { echo -e "${RED}[error]${NC} $1"; exit 1; }

# ── 1. Check prerequisites ────────────────────────────────────────────────────
log "Checking prerequisites..."

command -v java >/dev/null 2>&1 || fail "Java not found. Install Java 11 (recommended: Amazon Corretto 11)"
command -v python3 >/dev/null 2>&1 || fail "python3 not found"
command -v curl >/dev/null 2>&1 || fail "curl not found"

JAVA_VERSION=$(java -version 2>&1 | awk -F '"' '/version/ {print $2}' | cut -d'.' -f1)
if [ "$JAVA_VERSION" -gt 11 ]; then
  warn "Java $JAVA_VERSION detected. Flink 1.17 works best with Java 11."
  warn "If Flink fails, set JAVA_HOME to Java 11 in conf/zeppelin-env.sh"
fi

# ── 2. Download Zeppelin ──────────────────────────────────────────────────────
if [ ! -d "$REPO_DIR/$ZEPPELIN_DIR" ]; then
  log "Downloading Apache Zeppelin ${ZEPPELIN_VERSION}..."
  curl -L "$ZEPPELIN_URL" -o "/tmp/$ZEPPELIN_TGZ" --progress-bar
  log "Extracting..."
  tar -xzf "/tmp/$ZEPPELIN_TGZ" -C "$REPO_DIR"
  rm "/tmp/$ZEPPELIN_TGZ"
else
  log "Zeppelin already downloaded, skipping."
fi

ZEPPELIN_HOME="$REPO_DIR/$ZEPPELIN_DIR"

# ── 3. Detect Python versions ─────────────────────────────────────────────────
log "Detecting Python versions..."

PYTHON311=$(command -v python3.11 || command -v python3 || echo "")
PYTHON310=$(command -v python3.10 || echo "")

[ -z "$PYTHON311" ] && fail "Python 3.11 not found. Install it first."
[ -z "$PYTHON310" ] && fail "Python 3.10 not found (required for Flink 1.17). Install it first."

log "  Spark venv: $PYTHON311"
log "  Flink venv: $PYTHON310"

# ── 4. Create Spark venv (Python 3.11) ───────────────────────────────────────
SPARK_VENV="$ZEPPELIN_HOME/zeppelin-pyenv"
if [ ! -d "$SPARK_VENV" ]; then
  log "Creating Spark Python venv (Python 3.11)..."
  "$PYTHON311" -m venv "$SPARK_VENV"
  "$SPARK_VENV/bin/pip" install --quiet pyspark==3.5.1 ipython
  log "  Installed: pyspark 3.5.1, ipython"
else
  log "Spark venv already exists, skipping."
fi

SPARK_HOME="$SPARK_VENV/lib/python3.11/site-packages/pyspark"

# ── 5. Create Flink venv (Python 3.10) ───────────────────────────────────────
FLINK_VENV="$ZEPPELIN_HOME/flink-pyenv"
if [ ! -d "$FLINK_VENV" ]; then
  log "Creating Flink Python venv (Python 3.10)..."
  "$PYTHON310" -m venv "$FLINK_VENV"
  "$FLINK_VENV/bin/pip" install --quiet "apache-flink==1.17.2" --no-deps
  "$FLINK_VENV/bin/pip" install --quiet "apache-flink-libraries==1.17.2" --no-deps
  "$FLINK_VENV/bin/pip" install --quiet "py4j==0.10.9.7" "python-dateutil>=2.8.0"
  log "  Installed: apache-flink 1.17.2"
else
  log "Flink venv already exists, skipping."
fi

FLINK_HOME="$FLINK_VENV/lib/python3.10/site-packages/pyflink"

# ── 6. Fix Flink jars (move opt/ jars to lib/, add Scala bridge jars) ────────
log "Fixing Flink jars for Zeppelin compatibility..."

FLINK_LIB="$FLINK_HOME/lib"
FLINK_OPT="$FLINK_HOME/opt"
MAVEN="https://repo1.maven.org/maven2/org/apache/flink"
V="1.17.2"

# Move required jars from opt/ to lib/
for jar in "flink-sql-client-${V}.jar" "flink-python-${V}.jar"; do
  if [ ! -f "$FLINK_LIB/$jar" ] && [ -f "$FLINK_OPT/$jar" ]; then
    cp "$FLINK_OPT/$jar" "$FLINK_LIB/$jar"
    log "  Moved: $jar → lib/"
  fi
done

# Download missing Scala bridge jars from Maven Central
for artifact in \
  "flink-table-api-scala-bridge_2.12/${V}/flink-table-api-scala-bridge_2.12-${V}.jar" \
  "flink-streaming-scala_2.12/${V}/flink-streaming-scala_2.12-${V}.jar"; do
  name=$(basename "$artifact")
  if [ ! -f "$FLINK_LIB/$name" ]; then
    log "  Downloading $name..."
    curl -sL "${MAVEN}/${artifact}" -o "$FLINK_LIB/$name"
    log "  Downloaded: $name"
  fi
done

# Create lib/python symlink (required by Zeppelin's Flink shims)
mkdir -p "$FLINK_HOME/lib/python"
[ ! -L "$FLINK_HOME/lib/python/pyflink" ] && ln -sf "$FLINK_HOME" "$FLINK_HOME/lib/python/pyflink"

# ── 7. Detect Java 11 home ────────────────────────────────────────────────────
JAVA_HOME_11=""
if [ "$(uname)" = "Darwin" ]; then
  JAVA_HOME_11=$(/usr/libexec/java_home -v 11 2>/dev/null || echo "")
fi
[ -z "$JAVA_HOME_11" ] && JAVA_HOME_11=$(dirname $(dirname $(readlink -f $(which java))))
log "JAVA_HOME: $JAVA_HOME_11"

# ── 8. Write zeppelin-env.sh ──────────────────────────────────────────────────
log "Writing conf/zeppelin-env.sh..."
cat > "$ZEPPELIN_HOME/conf/zeppelin-env.sh" <<EOF
#!/bin/bash
# Auto-generated by setup.sh

# Java 11 (Flink 1.17 Scala interpreter requires Java 11)
export JAVA_HOME=${JAVA_HOME_11}

SPARK_VENV=${SPARK_VENV}
FLINK_VENV=${FLINK_VENV}

# Spark — bundled inside pyspark pip package
export SPARK_HOME=\${SPARK_VENV}/lib/python3.11/site-packages/pyspark
export SPARK_MASTER=local[*]

# Flink 1.17.2 — bundled inside apache-flink pip package
export FLINK_HOME=\${FLINK_VENV}/lib/python3.10/site-packages/pyflink

# Python for Spark
export PYSPARK_PYTHON=\${SPARK_VENV}/bin/python
export PYSPARK_DRIVER_PYTHON=\${SPARK_VENV}/bin/python

# Zeppelin settings
export ZEPPELIN_ADDR=0.0.0.0
export ZEPPELIN_PORT=8080
export ZEPPELIN_MEM="-Xms512m -Xmx2g -XX:MaxMetaspaceSize=512m"
export ZEPPELIN_INTP_MEM="-Xms512m -Xmx2g -XX:MaxMetaspaceSize=512m"

export PATH="\${JAVA_HOME}/bin:\${SPARK_HOME}/bin:\${FLINK_HOME}/bin:\${PATH}"
EOF

# ── 9. Patch interpreter.json ─────────────────────────────────────────────────
log "Patching conf/interpreter.json..."
python3 "$SCRIPT_DIR/patch-interpreter.py" \
  "$ZEPPELIN_HOME/conf/interpreter.json" \
  "$SPARK_HOME" \
  "$SPARK_VENV/bin/python" \
  "$FLINK_HOME" \
  "$FLINK_VENV/bin/python"

log ""
log "✓ Setup complete!"
log ""
log "  Start:  cd $ZEPPELIN_HOME && ./bin/zeppelin-daemon.sh start"
log "  Open:   http://localhost:8080"
log "  Stop:   cd $ZEPPELIN_HOME && ./bin/zeppelin-daemon.sh stop"
log ""
log "  Spark UI:  http://localhost:4040  (after first %spark paragraph)"
log "  Flink UI:  http://localhost:8081  (after first %flink paragraph)"
