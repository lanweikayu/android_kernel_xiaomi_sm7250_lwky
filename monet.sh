#!/usr/bin/env bash
set -euo pipefail

# One-shot build for Xiaomi MI 10 Lite 5G (monet, SM7250):
#   - merges lito-perf_defconfig with arch/arm64/configs/vendor/xiaomi/monet.config
#   - compiles an uncompressed arm64 Image (same layout as the stock boot image)
#   - stages Image into the ak3/ AnyKernel3 template and produces a flashable zip
#
# Notes:
#   - dtbo is intentionally NOT included. The stock dtbo partition contains
#     monet/picasso/vangogh overlays and replacing it with a single overlay
#     makes the bootloader fall back to fastboot.
#   - out/ is the kernel build directory, dist/ holds the final zip.
#   - CLEAN=0 keeps out/ for incremental builds; CLEAN=1 (default) rebuilds
#     from a fresh .config so kconfig never prompts interactively.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/out"
DIST="$ROOT/dist"
AK3="$ROOT/ak3"

DEFCONFIG="vendor/lito-perf_defconfig"
MONET_FRAG="$ROOT/arch/arm64/configs/vendor/xiaomi/monet.config"
JOBS="${JOBS:-$(nproc)}"
CLEAN="${CLEAN:-1}"

error() {
    echo "monet: error: $*" >&2
    exit 1
}

[ -d "$AK3" ] || error "missing ak3 template at $AK3"
[ -f "$MONET_FRAG" ] || error "missing monet config at $MONET_FRAG"
[ -e "$ROOT/drivers/kernelsu" ] || error "missing drivers/kernelsu symlink"

mkdir -p "$OUT" "$DIST"

if [ "$CLEAN" = "1" ]; then
    echo "monet: cleaning $OUT"
    rm -rf "$OUT"
    mkdir -p "$OUT"
fi

echo "monet: merging $DEFCONFIG + monet.config"
ARCH=arm64 scripts/kconfig/merge_config.sh -O "$OUT" \
    "arch/arm64/configs/$DEFCONFIG" \
    "$MONET_FRAG" </dev/null >/dev/null

echo "monet: resolving any remaining config defaults non-interactively"
make O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld \
    olddefconfig </dev/null >/dev/null

echo "monet: building Image (jobs=$JOBS)"
# LOCALVERSION="" pins the version string (no scm "+" even when the
# working tree is dirty), so the release shows as e.g. 4.19.325-KaYuKernel
make O="$OUT" ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld \
    CROSS_COMPILE=aarch64-linux-gnu- LOCALVERSION= -j"$JOBS" Image

IMAGE="$OUT/arch/arm64/boot/Image"
[ -f "$IMAGE" ] || error "Image not produced"

echo "monet: verifying key config"
for opt in CONFIG_KSU=y CONFIG_KSU_SUSFS=y CONFIG_EROFS_FS=y CONFIG_FUSE_BPF=y CONFIG_BOARD_MONET=y; do
    grep -q "^${opt%%=*}=${opt#*=}$" "$OUT/.config" ||
        error "missing expected $opt in $OUT/.config"
done

echo "monet: staging kernel into ak3 template"
rm -f "$AK3/Image" "$AK3/Image.gz" "$AK3/Image.gz-dtb" "$AK3/dtbo.img"
cp "$IMAGE" "$AK3/Image"

ZIP="$DIST/monet-4.19-KSU-SUSFS.zip"
rm -f "$ZIP"
echo "monet: packaging $ZIP"
(cd "$AK3" && find . -type f | sort | zip -9 -X "$ZIP" -@ >/dev/null)

echo "monet: done -> $ZIP"
ls -lh "$ZIP"
