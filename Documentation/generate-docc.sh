#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/ease-call-docc.XXXXXX")"
printf 'DocC build workspace %s\n' "$work_dir"

mkdir -p "$work_dir/package" "$work_dir/symbols"
cp -R "$repo_root/Package.swift" "$repo_root/Package@swift-6.1.swift" \
    "$repo_root/Sources" "$repo_root/Tests" "$work_dir/package/"
sdk_path="$(xcrun --sdk iphonesimulator --show-sdk-path)"

# The full API archive includes both optional incoming-call implementations.
swift build --package-path "$work_dir/package" \
    --target EaseCallUIKit --enable-all-traits --jobs 4 \
    --triple arm64-apple-ios15.0-simulator --sdk "$sdk_path" \
    -Xswiftc -emit-symbol-graph \
    -Xswiftc -emit-symbol-graph-dir -Xswiftc "$work_dir/symbols" \
    > "$work_dir/build.log" 2>&1 || {
        tail -n 60 "$work_dir/build.log"
        exit 1
    }

python3 - "$work_dir/symbols" <<'PY'
import json
import sys
from pathlib import Path

# Dependency wrapper graphs are also emitted by SwiftPM; document this module only.
for graph in Path(sys.argv[1]).glob('*.symbols.json'):
    if json.loads(graph.read_text())['module']['name'] != 'EaseCallUIKit':
        graph.unlink()
PY

xcrun docc convert "$repo_root/Documentation/EaseCallUIKit.docc" \
    --additional-symbol-graph-dir "$work_dir/symbols" \
    --fallback-display-name EaseCallUIKit \
    --fallback-bundle-identifier org.cocoapods.EaseCallUIKit \
    --output-path "$work_dir/EaseCallUIKit.doccarchive" \
    --emit-digest --emit-lmdb-index --warnings-as-errors \
    > "$work_dir/docc.log" 2>&1 || {
        cat "$work_dir/docc.log"
        exit 1
    }

# Replace the previous archive only after conversion succeeds.
python3 - "$work_dir/EaseCallUIKit.doccarchive" "$repo_root/Documentation/EaseCallUIKit.doccarchive" <<'PY'
import shutil
import sys
from pathlib import Path

source, destination = map(Path, sys.argv[1:])
if destination.exists():
    shutil.rmtree(destination)
shutil.copytree(source, destination)
PY

printf 'Generated %s\nBuild log %s\nDocC log %s\n' \
    "$repo_root/Documentation/EaseCallUIKit.doccarchive" \
    "$work_dir/build.log" "$work_dir/docc.log"
