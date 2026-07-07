#!/bin/bash
# 用 Xcode 的 xcodebuild 构建项目，输出到 ./build/ 目录。
# 用法: ./build.sh [Debug|Release]
set -e
CONFIG="${1:-Debug}"
xcodebuild -scheme SalaryTrain \
    -derivedDataPath build \
    -configuration "$CONFIG" \
    -destination "platform=macOS" \
    2>&1 | tail -5
echo ""
echo "二进制文件: build/Build/Products/$CONFIG/SalaryTrain"
