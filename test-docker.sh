#!/usr/bin/env bash
# test-docker.sh — 在 ubuntu:25.10 容器里跑 Linux 侧全量测试（无需虚拟机）
# 覆盖：test-linux.sh 基础回归 + root 路径（fake sysfs 注入缝）+ provision 免密闭环
set -euo pipefail
cd "$(dirname "$0")"

IMG=vscreen-test:latest
echo "==> 构建测试镜像（$IMG，ubuntu 容器）..."
docker build -q -t "$IMG" -f docker/Dockerfile.test . >/dev/null
echo "==> 运行容器测试..."
docker run --rm "$IMG" bash /repo/docker/run-tests.sh
