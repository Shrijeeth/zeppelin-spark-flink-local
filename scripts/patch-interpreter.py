#!/usr/bin/env python3
"""
Patches Zeppelin's interpreter.json with correct Spark and Flink paths.
Usage: patch-interpreter.py <interpreter.json> <spark_home> <spark_python> <flink_home> <flink_python>
"""
import json
import sys
import shutil
from datetime import datetime

interpreter_json, spark_home, spark_python, flink_home, flink_python = sys.argv[1:]

# Backup original
shutil.copy(interpreter_json, interpreter_json + ".bak." + datetime.now().strftime("%Y%m%d%H%M%S"))

with open(interpreter_json) as f:
    d = json.load(f)

settings = d["interpreterSettings"]

# Patch Spark
spark = settings["spark"]["properties"]
spark["SPARK_HOME"]["value"]              = spark_home
spark["spark.master"]["value"]            = "local[*]"
spark["spark.submit.deployMode"]["value"] = "client"
spark["PYSPARK_PYTHON"]["value"]          = spark_python
spark["PYSPARK_DRIVER_PYTHON"]["value"]   = spark_python
spark["zeppelin.pyspark.useIPython"]["value"] = True

# Patch Flink
flink = settings["flink"]["properties"]
flink["FLINK_HOME"]["value"]                  = flink_home
flink["flink.execution.mode"]["value"]        = "local"
flink["zeppelin.pyflink.python"]["value"]     = flink_python

with open(interpreter_json, "w") as f:
    json.dump(d, f, indent=2)

print(f"  SPARK_HOME  → {spark_home}")
print(f"  FLINK_HOME  → {flink_home}")
print(f"  Spark Python → {spark_python}")
print(f"  Flink Python → {flink_python}")
