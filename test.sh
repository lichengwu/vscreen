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
expect "边界 @25%（÷0.25）"          5880x3676 mba13@25%
expect "边界 @400%（÷4）"            368x230   mba13@400%
expect "x 形 + % + 系数"            1210x756  1512x945@125%

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
refuse "系数在前（@125% mba13）"   @125% mba13
refuse "两个位置参数（mba13 mbp14）" mba13 mbp14

echo "自更新保护（file:// 假远端，不碰网络）："
cur_ver=$(sed -n 's/^VERSION="\([^"]*\)".*/\1/p' vscreen | head -1)
sed 's/^VERSION="[^"]*"/VERSION="1.0.0"/'  vscreen > /tmp/vscreen_remote_old
sed 's/^VERSION="[^"]*"/VERSION="9.9.9"/'  vscreen > /tmp/vscreen_remote_new
sed "s/^VERSION=\"[^\"]*\"/VERSION=\"$cur_ver\"/" vscreen > /tmp/vscreen_remote_eq
sed 's/^VERSION="[^"]*"/VERSION="1.1.10"/' vscreen > /tmp/vscreen_remote_num
sed 's/^VERSION="[^"]*"/VERSION="garbage"/' vscreen > /tmp/vscreen_remote_gbg
grep -v '^VERSION=' vscreen > /tmp/vscreen_remote_nover

run_upd() {  # $1=假远端路径；UPD_OUT 记录输出，副本每次重置
  cp -p vscreen /tmp/vscreen_upd_test
  UPD_OUT=$(VSCREEN_RAW_URL="file://$1" /tmp/vscreen_upd_test update 2>&1)
}
skip_case() {  # skip_case <描述> <远端文件> <期望消息片段> —— 应跳过且副本不变
  run_upd "$2"
  if diff -q vscreen /tmp/vscreen_upd_test >/dev/null && [[ "$UPD_OUT" == *"$3"* ]]; then
    ok "$1"
  else
    bad "$1" "副本被改动或消息不符（${UPD_OUT}）"
  fi
}
skip_case "旧远端不降级"          /tmp/vscreen_remote_old   "未覆盖"
skip_case "等版本跳过"            /tmp/vscreen_remote_eq    "已是最新"
skip_case "垃圾远端版本不覆盖"    /tmp/vscreen_remote_gbg   "无法比较"
skip_case "远端无版本行不覆盖"    /tmp/vscreen_remote_nover "无法解析"
run_upd /tmp/vscreen_remote_num
if grep -q 'VERSION="1.1.10"' /tmp/vscreen_upd_test; then ok "数值段比较 1.1.10 > 1.1.1 升级"; else bad "数值段比较升级" "未升级到 1.1.10"; fi
run_upd /tmp/vscreen_remote_new
if grep -q 'VERSION="9.9.9"' /tmp/vscreen_upd_test; then ok "新远端正常升级"; else bad "新远端正常升级" "未升级到 9.9.9"; fi

echo "版本与帮助："
./vscreen version    | grep -q "v$cur_ver"         && ok "version 命令（动态断言）" || bad "version 命令" "版本号不符"
./vscreen --version  | grep -q "^vscreen v"        && ok "--version 旗标"      || bad "--version 旗标" "无输出"
./vscreen --help     | grep -q -- "-v | --version" && ok "帮助含 -v|--version" || bad "帮助" "缺 -v | --version"
./vscreen --help     | grep -q "@系数"             && ok "帮助含 @系数说明"    || bad "帮助" "缺 @系数"
./vscreen --help     | grep -q "空格宽限"          && ok "帮助含空格宽限说明"  || bad "帮助" "缺 空格宽限"
./vscreen list       | grep -q "1470x919"          && ok "list 含 mba13 补偿档" || bad "list" "缺 1470x919"

# pitfall 扫描：$VAR 紧跟多字节字符（全角标点/CJK）——bash 3.2 会把多字节
# 字节吸进变量名，`set -u` 下报 "<NAME><乱码>: unbound variable"。zsh 不受
# 影响，所以只在 `curl | bash`（管道忽略 shebang）时才会炸（实测 install.sh:28）。
hits=$(grep -rnE '\$[A-Za-z_][A-Za-z0-9_]*[^ -~]' install.sh vscreen vscreen-linux test.sh test-linux.sh test-docker.sh 2>/dev/null || true)
if [[ -z "$hits" ]]; then
  ok "pitfall 扫描：无 \$VAR 紧跟多字节字符"
else
  bad "pitfall 扫描（请改为 \${VAR}）" "$hits"
fi

echo
if [[ $fail -eq 0 ]]; then
  echo "全部通过：$pass 项 ✅"
else
  echo "失败 $fail / $((pass+fail)) ❌"
fi
exit $fail
