#!/usr/bin/env bash
# 容器内测试程序（由 test-docker.sh 调起；ubuntu:25.10 容器内以 root 运行）
# 覆盖：A 基础回归 → B root 路径（fake sysfs 端到端）→ C provision 免密闭环
set -u
cd /repo
pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1 — $2"; }

echo "===== A. 基础回归（test-linux.sh）====="
if bash test-linux.sh >/tmp/tl.log 2>&1; then
  ok "test-linux.sh 全部通过"
  grep -o "全部通过：.*" /tmp/tl.log | head -1
else
  bad "test-linux.sh" "存在失败项"
  grep "FAIL" /tmp/tl.log | head -5
fi

echo "===== B. root 路径：fake sysfs 端到端 ====="
export VSCREEN_DRM_SYS=/tmp/fake-drm VSCREEN_PARAM=/tmp/fake-param
F=/tmp/fake-drm/card0-Virtual-1
mkdir -p "$F"
printf 'connected\n' > "$F/status"
printf 'enabled\n'  > "$F/enabled"
printf '3072x1728\n1280x800\n' > "$F/modes"
printf 'fake-original-edid-not-ours\n' > "$F/edid"   # 非空但非我们的（模拟“内核未装载新 EDID”）
: > "$VSCREEN_PARAM"

# B1. 内核未装载（fake edid 为空）→ md5 网关必须拒绝
if ./vscreen-linux mba13 --no-vt >/tmp/a1.log 2>&1; then
  bad "md5 网关" "fake edid 为空时应失败"
else
  ok "md5 验证网关生效（未装载即拒绝，exit≠0）"
  grep -q "内核未装载新 EDID" /tmp/a1.log && ok "警告文案正确" || bad "警告文案" "未出现"
fi

# B2. 内嵌 EDID 生成器与实机验证过的字节一致（防生成器漂移）
GEN=/lib/firmware/edid/vscreen-2940x1838.bin
M=$(md5sum "$GEN" | awk '{print $1}')
if [ "$M" = "50fd88d27709e63103b3ca8c71d7d952" ]; then
  ok "内嵌生成器字节与实机一致"
else
  bad "EDID 漂移" "$M"
fi

# B3. 模拟内核装载 → 全流程成功（find→gen→param→detect→verify→完成）
cp "$GEN" "$F/edid"
printf '2940x1838\n' >> "$F/modes"
printf 'connected\n' > "$F/status"        # apply 前重置状态
if OUT=$(./vscreen-linux mba13 --no-vt 2>&1); then
  ok "apply 全流程成功"
else
  bad "apply" "$OUT"
fi
if [ "$(cat "$VSCREEN_PARAM")" = "Virtual-1:edid/vscreen-2940x1838.bin" ]; then
  ok "覆盖参数写入正确"
else
  bad "覆盖参数" "$(cat "$VSCREEN_PARAM")"
fi
grep -q "完成" <<< "$OUT" && ok "完成输出正确" || bad "完成输出" "$OUT"

# B4. off 恢复
printf 'connected\n' > "$F/status"
if ./vscreen-linux off --no-vt >/tmp/a3.log 2>&1; then
  ok "off 成功"
else
  bad "off" "$(tail -2 /tmp/a3.log)"
fi
P=$(tr -d '[:space:]' < "$VSCREEN_PARAM")
if [ -z "$P" ]; then ok "参数已清空"; else bad "参数未清空" "$P"; fi

echo "===== C. provision 免密闭环（普通用户 + 限定路径 NOPASSWD）====="
useradd -m -s /bin/bash tester 2>/dev/null || true
# 模拟"用户具备 sudo 权限"的宿主机（env_keep 让注入缝穿透 sudo 重执行）
cat > /etc/sudoers.d/zz-test-env <<'SUDOENV'
Defaults env_keep += "VSCREEN_DRM_SYS VSCREEN_PARAM"
tester ALL=(ALL) NOPASSWD: ALL
SUDOENV
chmod 0440 /etc/sudoers.d/zz-test-env
mkdir -p /home/tester/.local/bin
cp /repo/vscreen-linux /home/tester/.local/bin/vscreen   # 模拟旧的用户副本（PATH 遮蔽）
chown -R tester:tester /home/tester

if su tester -c 'bash /repo/vscreen-linux provision' >/tmp/p.log 2>&1; then
  ok "provision（自提权→root 安装→写规则→清遮蔽）成功"
else
  bad "provision" "$(tail -3 /tmp/p.log)"
fi
[ -f /usr/local/bin/vscreen ] && ok "root 副本已安装到 /usr/local/bin" || bad "安装" "副本缺失"
R=$(cat /etc/sudoers.d/vscreen 2>/dev/null)
if [ "$R" = "tester ALL=(root) NOPASSWD: /usr/local/bin/vscreen" ]; then
  ok "免密规则精确限定路径（仅此一文件）"
else
  bad "免密规则" "$R"
fi
[ ! -f /home/tester/.local/bin/vscreen ] && ok "遮蔽副本已自动移除" || bad "遮蔽副本" "仍在"

# 普通用户零前缀免密直跑（自提权 → 限定规则 → env_keep 注入缝）
printf 'connected\n' > "$F/status"
RUN="VSCREEN_DRM_SYS=$VSCREEN_DRM_SYS VSCREEN_PARAM=$VSCREEN_PARAM /usr/local/bin/vscreen"
if OUT2=$(su tester -c "$RUN mba13 --no-vt" 2>&1); then
  ok "普通用户免密直跑 apply（零 sudo 前缀）"
else
  bad "免密直跑" "$OUT2"
fi
printf 'connected\n' > "$F/status"
if su tester -c "$RUN off --no-vt" >/dev/null 2>&1; then
  ok "普通用户免密 off"
else
  bad "免密 off" "exit≠0"
fi

echo
if [ $fail -eq 0 ]; then
  echo "容器测试全部通过：$pass 项 ✅"
else
  echo "失败 $fail / $((pass + fail)) ❌"
fi
exit $fail
