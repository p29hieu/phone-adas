#!/usr/bin/env bash
# Exports YOLO11n to Core ML (640, FP16, NMS pipeline) and compiles it to
# ios/Runner/Models/yolo11n.mlmodelc for the iOS vision core.
#
# Requires: python3.12 (brew install python@3.12), Xcode command line tools.
# Note: Ultralytics YOLO11 weights are AGPL-3.0 — fine for personal/local
# use; re-check licensing before any public distribution.
set -euo pipefail
cd "$(dirname "$0")"

PY=python3.12
[ -d .venv-export ] || "$PY" -m venv .venv-export
source .venv-export/bin/activate
python -m pip install --quiet --upgrade pip
python -m pip install --quiet "ultralytics>=8.3,<9" "coremltools>=8"

yolo export model=yolo11n.pt format=coreml nms=True imgsz=640 half=True

rm -rf ../ios/Runner/Models
mkdir -p ../ios/Runner/Models
xcrun coremlcompiler compile yolo11n.mlpackage ../ios/Runner/Models/
echo "=== EXPORT DONE ==="
ls -la ../ios/Runner/Models/
