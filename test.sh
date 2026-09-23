#!/bin/zsh
# vscreen 回归测试 —— 全部走 CLI 黑盒路径
# --print 不触碰 BetterDisplay / 显示器，可安全反复运行
set -u
cd "$(dirname "$0")"

pass=0; fail=0
ok()  { pass=$((pass+1)); echo "  ok    $1"; }
bad() { fail=$((fail+1)); echo "  FAIL  $1 — $2"; }

# 取 --print 输出中最后一个 WxH（即最终生效分辨率）
res() { ./vscreen "$@" --print 2>/dev/null | grep -oE '[0-9]+x[0-9]+' | tail -1; }

expect() {  # expect <描述> <期望WxH> <参数...>
  local desc="$1" want="$2"; shift 2
  local got; got=$(res "$@")
  if [[ "$got" == "$want" ]]; then ok "$desc"; else bad "$desc" "got '$got', want '$want'"; fi
}

refuse() {  # refuse <描述> <参数...> —— 期望非零退出
  local desc="$1"; shift
  if ./vscreen "$@" >/dev/null 2>&1; then bad "$desc" "unexpected exit 0"; else ok "$desc"; fi
}

echo "设备档位："
expect "mba13 补偿档"              1470x919  mba13
expect "mba13 native 档"          1470x956  mba13-native
expect "mba13 full 档"            2560x1664 mba13-full
expect "mba15 补偿档"             1710x1069 mba15
expect "同义词 air13"             1470x919  air13
expect "直接 WxH（x 分隔）"       1512x945  1512x945
expect "直接 WxH（大写 X）"       1512x945  1512X945
expect "直接 WxH（空格分隔）"     1512x945  1512 945

echo "缩放系数："
expect "mba13@125%"               1176x735  mba13@125%
expect "mba13@1.25（小数）"       1176x735  mba13@1.25
expect "mba13@80（无 % 按百分数）" 1838x1149 mba13@80
expect "mba13@80%"                1838x1149 mba13@80%
expect "mbp14-native@1.5"         1008x655  mbp14-native@1.5
expect "mba13-full@50"            5120x3328 mba13-full@50
expect "空格 WxH + @系数"         1176x735  1470 919@125

echo "输入宽限："
expect "空格 @（mba13 @125%）"       1176x735  mba13 @125%
expect "空格 @（mba13 @ 125%）"      1176x735  mba13 @ 125%
expect "空格 @ 小数（mba13 @ 1.25）" 1176x735  mba13 @ 1.25
expect "档位后缀 + 空格 @"           1008x655  mbp14-native @ 1.5
expect "旗标在前 + 空格 @"           1176x735  mba13 --no-mirror @125%
expect "WxH 空格 + 空格 @"           1890x1181 1512 945 @ 80
expect "小数 WxH（x 分隔）"          1336x835  1336.36x835.45
expect "小数 WxH（空格分隔）"        1336x835  1336.36 835.45
expect "小数 WxH + 系数"            1069x668  1336.36x835.45@125

echo "错误路径（应拒绝）："
refuse "系数越界 @500%"            mba13@500%
refuse "系数过小 @0.1"             mba13@0.1
refuse "非法系数 @abc"             mba13@abc
refuse "空系数 mba13@"             mba13@
refuse "@ 后无系数（mba13 @）"     mba13 @
refuse "@ 后非系数（mba13 @ abc）" mba13 @ abc
refuse "系数配 off"                off@125
refuse "系数配 status"             status@125
refuse "--print 配 list"           list --print

echo "版本与帮助："
./vscreen version    | grep -q "v1.1.0"            && ok "version 命令"        || bad "version 命令" "版本号不符"
./vscreen --version  | grep -q "^vscreen v"        && ok "--version 旗标"      || bad "--version 旗标" "无输出"
./vscreen --help     | grep -q -- "-v | --version" && ok "帮助含 -v|--version" || bad "帮助" "缺 -v | --version"
./vscreen --help     | grep -q "@系数"             && ok "帮助含 @系数说明"    || bad "帮助" "缺 @系数"
./vscreen --help     | grep -q "空格宽限"          && ok "帮助含空格宽限说明"  || bad "帮助" "缺 空格宽限"
./vscreen list       | grep -q "1470x919"          && ok "list 含 mba13 补偿档" || bad "list" "缺 1470x919"

echo
if [[ $fail -eq 0 ]]; then
  echo "全部通过：$pass 项 ✅"
else
  echo "失败 $fail / $((pass+fail)) ❌"
fi
exit $fail
