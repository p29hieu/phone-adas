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
# torch is pinned: newer torch versions outpace the coremltools converter
# frontend (torch 2.13 + coremltools 9.0 fails with "only 0-dimensional
# arrays can be converted to Python scalars").
python -m pip install --quiet "torch==2.5.1" "torchvision==0.20.1" \
  "coremltools>=8.2,<9" "ultralytics>=8.3,<9"

yolo export model=yolo11n.pt format=coreml nms=True imgsz=640 half=True

rm -rf ../ios/Runner/Models
mkdir -p ../ios/Runner/Models
xcrun coremlcompiler compile yolo11n.mlpackage ../ios/Runner/Models/
echo "=== EXPORT DONE ==="
ls -la ../ios/Runner/Models/
