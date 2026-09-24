#!/usr/bin/env python3
"""vscreen EDID 生成器 — 生成 128 字节 EDID 1.3 基础块（无扩展）。

DTD1 = 自定义模式；DTD2 = 监视器名 "vscreen"（mutter/RustDesk 里显示的身份）。
逻辑已实机验证（Ubuntu 25.10 / GNOME 49 / 内核 6.17）。

用法：
    gen_edid.py <宽> <高> [输出文件] [--name 名字] [--hmm 水平mm] [--vmm 垂直mm]

无扩展、含校验和；生成后自带解析回读自检。
"""
import sys


def make_edid(ha, hfp, hsw, hbp, va, vfp, vsw, vbp,
              name="vscreen", hsize_mm=310, vsize_mm=195):
    ht, vt = ha + hfp + hsw + hbp, va + vfp + vsw + vbp
    hb, vb = ht - ha, vt - va
    clock_khz = round(ht * vt * 60 / 1000)          # 60Hz
    clock10k = round(clock_khz / 10)
    assert 0 < clock10k < 0x10000, "pixel clock overflow"
    assert ha < 0x1000 and va < 0x1000 and hb < 0x1000 and vb < 0x1000

    d = bytearray(128)
    d[0:8] = bytes([0x00, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00])

    def letter(ch):
        return ord(ch) - 64

    mid = (letter('V') << 10) | (letter('S') << 5) | letter('C')   # 厂商 "VSC"
    d[8], d[9] = (mid >> 8) & 0xFF, mid & 0xFF
    d[10], d[11] = 0x01, 0x00                               # 产品码 LE
    d[12:16] = bytes([1, 0, 0, 0])                          # 序列号
    d[16], d[17] = 0, 36                                    # 周/年（2026）
    d[18], d[19] = 1, 3                                     # EDID 1.3
    d[20] = 0x00                                            # 模拟输入（KMS 不关心）
    d[21], d[22] = hsize_mm // 10, vsize_mm // 10           # 最大尺寸 cm
    d[23], d[24] = 120, 0x00                                # gamma 2.2
    for i in range(38, 54, 2):                              # 标准时序 = 未用
        d[i], d[i + 1] = 0x01, 0x01

    t = bytearray(18)                                       # DTD1：自定义模式
    t[0], t[1] = clock10k & 0xFF, (clock10k >> 8) & 0xFF
    t[2], t[3] = ha & 0xFF, hb & 0xFF
    t[4] = ((ha >> 8) << 4) | ((hb >> 8) & 0x0F)
    t[5], t[6] = va & 0xFF, vb & 0xFF
    t[7] = ((va >> 8) << 4) | ((vb >> 8) & 0x0F)
    t[8] = hfp & 0xFF
    t[9] = (((hfp >> 8) & 3) << 6) | (((hsw >> 8) & 3) << 4) | \
           (((vfp >> 8) & 3) << 2) | ((vsw >> 8) & 3)
    t[10] = hsw & 0xFF
    t[11] = ((vfp & 0x0F) << 4) | (vsw & 0x0F)
    t[12], t[13] = hsize_mm & 0xFF, (hsize_mm >> 8) & 0xFF
    t[14], t[15] = vsize_mm & 0xFF, (vsize_mm >> 8) & 0xFF
    t[17] = 0x18                                            # 数字独立同步
    d[54:72] = t

    nm = bytearray(18)                                      # DTD2：名称
    nm[0:5] = bytes([0, 0, 0, 0xFC, 0])
    nm[5:18] = name.encode()[:13].ljust(13, b' ')
    d[72:90] = nm                                           # DTD3/4 留零

    d[126] = 0                                              # 无扩展
    d[127] = (0x100 - (sum(d) & 0xFF)) & 0xFF
    assert sum(d) & 0xFF == 0, "checksum error"
    return bytes(d)


def parse_selfcheck(blob):
    """回读 DTD 自检：解析出的模式应与输入一致。"""
    c10k = blob[54] | (blob[55] << 8)
    ha = blob[56] | ((blob[58] >> 4) << 8)
    hb = blob[57] | ((blob[58] & 0xF) << 8)
    va = blob[59] | ((blob[61] >> 4) << 8)
    vb = blob[60] | ((blob[61] & 0xF) << 8)
    name = bytes(blob[77:90]).decode(errors="replace").strip()
    return c10k * 10, ha, va, ha + hb, va + vb, name


# 通用 porch（对任意 WxH 都成立的保守时序）
FP, SW, BP, VFP, VSW, VBP = 88, 44, 156, 3, 5, 27


def main(argv):
    if len(argv) < 3:
        print(__doc__, file=sys.stderr)
        return 2
    try:
        ha, va = int(argv[1]), int(argv[2])
    except ValueError:
        print(f"错误：宽/高必须是整数（收到 {argv[1]!r} x {argv[2]!r}）", file=sys.stderr)
        return 2
    if ha <= 0 or va <= 0:
        print("错误：宽/高必须是正整数", file=sys.stderr)
        return 2
    name, hmm, vmm = "vscreen", 310, 195
    args = argv[3:]
    i = 0
    while i < len(args):
        if args[i] == "--name" and i + 1 < len(args):
            name = args[i + 1]
            i += 2
        elif args[i] == "--hmm" and i + 1 < len(args):
            try:
                hmm = int(args[i + 1])
            except ValueError:
                print(f"错误：--hmm 需要整数（收到 {args[i + 1]!r}）", file=sys.stderr)
                return 2
            i += 2
        elif args[i] == "--vmm" and i + 1 < len(args):
            try:
                vmm = int(args[i + 1])
            except ValueError:
                print(f"错误：--vmm 需要整数（收到 {args[i + 1]!r}）", file=sys.stderr)
                return 2
            i += 2
        else:
            i += 1
    out = next((a for a in args if not a.startswith("--")), None)

    try:
        blob = make_edid(ha, FP, SW, BP, va, VFP, VSW, VBP, name, hmm, vmm)
    except (AssertionError, ValueError) as e:
        print(f"错误：无法为 {ha}x{va} 生成 EDID：{e}", file=sys.stderr)
        return 1
    if out:
        try:
            with open(out, "wb") as f:
                f.write(blob)
        except OSError as e:
            print(f"错误：无法写入 {out}：{e}", file=sys.stderr)
            return 1
    pclk, pa, pv, pt, vtt, nm = parse_selfcheck(blob)
    ok = (pa == ha and pv == va and nm == name)
    print(f"{pa}x{pv} (total {pt}x{vtt}) {pclk / 1000:.2f}MHz name='{nm}' "
          f"{'OK' if ok else 'SELFCHECK-FAIL'}")
    if not ok:
        return 1
    if not out:
        sys.stdout.buffer.write(blob)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
