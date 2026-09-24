#!/usr/bin/env bash
# vscreen-linux 回归测试 —— 全部免 root、不修改任何系统状态
# 可在 macOS（bash 3.2）与 Linux 上运行
set -u
cd "$(dirname "$0")"

pass=0; fail=0
ok()  { pass=$((pass + 1)); echo "  ok    $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $1 — $2"; }

hash_of() {  # $1 文件 → md5（跨平台，含 python3 兜底）
  if command -v md5sum >/dev/null 2>&1; then md5sum "$1" | awk '{print $1}'
  elif command -v md5 >/dev/null 2>&1; then md5 -q "$1"
  else python3 -c 'import hashlib,sys; print(hashlib.md5(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; fi
}

res() { ./vscreen-linux "$@" --print 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -1; }
expect() {  # expect <描述> <期望WxH> <参数...>
  local desc="$1" want="$2"; shift 2
  local got; got=$(res "$@")
  if [ "$got" = "$want" ]; then ok "$desc"; else bad "$desc" "got '$got', want '$want'"; fi
}
refuse() {  # refuse <描述> <参数...> —— 期望非零退出
  local desc="$1"; shift
  if ./vscreen-linux "$@" >/dev/null 2>&1; then bad "$desc" "unexpected exit 0"; else ok "$desc"; fi
}

echo "设备档位（--print 输出末项 = 2x 物理档）："
expect "mba13 补偿档"              2940x1838  mba13
expect "mba13 native 档"          2940x1912  mba13-native
expect "mba13 full 档"            5120x3328  mba13-full
expect "mba15 补偿档"             3420x2138  mba15
expect "同义词 air13"             2940x1838  air13
expect "直接 WxH（x 分隔）"       3024x1890  1512x945
expect "直接 WxH（大写 X）"       3024x1890  1512X945
expect "直接 WxH（空格分隔）"     3024x1890  1512 945
expect "--logical 退回逻辑档"     1470x919  --logical mba13

echo "缩放系数（--print 显示：逻辑档 → 2x 物理档）："
expect "mba13@125%（逻辑 1176x735 → 物理 2352x1470）" 2352x1470 mba13@125%
expect "mba13@1.25（小数）"                           2352x1470 mba13@1.25
expect "mba13@80（无 % 按百分数）"                    3676x2298 mba13@80
expect "mbp14-native@1.5（逻辑 1008x655 → 物理 2016x1310）" 2016x1310 mbp14-native@1.5
expect "空格 WxH + @系数（逻辑 1176x735 → 物理 2352x1470）" 2352x1470 1470 919@125

echo "输入宽限："
expect "空格 @（mba13 @125%）"     2352x1470 mba13 @125%
expect "空格 @（mba13 @ 125%）"    2352x1470 mba13 @ 125%
expect "小数 WxH 取整"            2672x1670 1336.36x835.45
expect "--logical 用逻辑档"       1176x735  --logical mba13@125%

echo "错误路径（应拒绝）："
refuse "系数越界 @500%"            mba13@500%
refuse "非法系数 @abc"             mba13@abc
refuse "空系数 mba13@"             mba13@
refuse "系数配 off"                off@125
refuse "--print 配 list"           list --print
refuse "系数在前（@125% mba13）"   @125% mba13
refuse "两个位置参数"              mba13 mbp14
refuse "provision 配 --print"      provision --print

echo "EDID 生成器（md5 固定断言，实机验证过的字节）："
file_size() { wc -c < "$1" | tr -d '[:space:]'; }

./tools/gen_edid.py 1470 919 /tmp/tl-1470x919.bin >/dev/null 2>&1
if [ "$(hash_of /tmp/tl-1470x919.bin)" = "6af843101b04f840d24e1505b0143f7c" ] \
   && [ "$(file_size /tmp/tl-1470x919.bin)" = 128 ]; then
  ok "vscreen-1470x919.bin（128B，md5 与实机一致）"
else
  bad "EDID 1470x919" "md5/size 不符: $(hash_of /tmp/tl-1470x919.bin)"
fi
./tools/gen_edid.py 2940 1838 /tmp/tl-2940x1838.bin >/dev/null 2>&1
if [ "$(hash_of /tmp/tl-2940x1838.bin)" = "50fd88d27709e63103b3ca8c71d7d952" ] \
   && [ "$(file_size /tmp/tl-2940x1838.bin)" = 128 ]; then
  ok "vscreen-2940x1838.bin（128B，md5 与实机一致）"
else
  bad "EDID 2940x1838" "md5/size 不符: $(hash_of /tmp/tl-2940x1838.bin)"
fi
if ./tools/gen_edid.py abc 919 /tmp/tl-bad.bin >/dev/null 2>&1; then
  bad "非法输入应拒绝" "exit 0"
else
  ok "非法输入拒绝（abc 919）"
fi

echo "设备表同步（vs macOS vscreen 的 DEVICES）："
for alias in mba13 mba15 mbp14 mbp16 imac24 studio xdr ipadpro13 ipadpro129 ipadair13; do
  zline=$(grep -E "^  $alias +\"[^\"]+\"" vscreen | head -1)
  zvals=$(printf '%s' "$zline" | sed -E 's/.*\|([0-9]+x[0-9]+)\|([0-9]+x[0-9]+)\|([0-9]+x[0-9]+)\".*/\1|\2|\3/')
  lvals=$(./vscreen-linux __deventry "$alias" 2>/dev/null || true)
  if [ -n "$zvals" ] && [ "$zvals" = "$lvals" ]; then
    ok "$alias 三档一致（$lvals）"
  else
    bad "$alias 不同步" "macOS='$zvals' linux='$lvals'"
  fi
done

echo "版本："
cur_ver=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' vscreen-linux | head -1)
./vscreen-linux version | grep -q "v$cur_ver" && ok "version 命令（动态断言）" || bad "version" "版本不符"

echo
if [ $fail -eq 0 ]; then
  echo "全部通过：$pass 项 ✅"
else
  echo "失败 $fail / $((pass + fail)) ❌"
fi
exit $fail
