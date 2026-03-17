#!/bin/bash
# SPDX-License-Identifier: (LGPL-2.1 OR BSD-2-Clause)
#
# Build elftoolchain's libelf as a static library for use with libbpf.
# This provides a BSD-licensed alternative to elfutils' libelf, enabling
# fully static builds without GPL/LGPL concerns.
#
# Usage:
#   ./scripts/build_elftoolchain.sh [install-prefix]
#
# After building, compile libbpf with:
#   make -C src USE_ELFTOOLCHAIN=1 \
#        ELFTOOLCHAIN_PREFIX=<install-prefix> \
#        BUILD_STATIC_ONLY=y
#
set -eux

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

PREFIX="${1:-$TOP_DIR/elftoolchain-install}"
SRCDIR="$TOP_DIR/elftoolchain-src"

CC="${CC:-cc}"
CFLAGS="${CFLAGS:--O2 -g}"
AR="${AR:-ar}"

if [ ! -d "$SRCDIR" ]; then
    git clone --depth 1 https://github.com/nicowilliams/inern-elftoolchain.git "$SRCDIR" 2>/dev/null || \
    git clone --depth 1 https://github.com/nicowilliams/inern-elftoolchain "$SRCDIR" 2>/dev/null || \
    git clone --depth 1 https://github.com/nicowilliams/elftoolchain.git "$SRCDIR" 2>/dev/null || \
    git clone --depth 1 https://github.com/nicowilliams/elftoolchain "$SRCDIR" 2>/dev/null || \
    git clone --depth 1 https://github.com/nicowilliams/elftoolchain "$SRCDIR" 2>/dev/null || \
    {
        echo "ERROR: Could not clone elftoolchain."
        echo ""
        echo "Clone it manually to $SRCDIR, for example:"
        echo "  svn checkout svn://svn.code.sf.net/p/elftoolchain/code/trunk $SRCDIR"
        echo ""
        echo "Or install via system packages:"
        echo "  Alpine:   apk add libelf-static libelf-dev  (provides elftoolchain's libelf)"
        echo "  FreeBSD:  (bundled in base system)"
        exit 1
    }
fi

mkdir -p "$PREFIX/lib" "$PREFIX/include"

COMMON_DIR="$SRCDIR/common"
LIBELF_DIR="$SRCDIR/libelf"

BUILD_CFLAGS="$CFLAGS -I$COMMON_DIR -I$LIBELF_DIR"

if [ -d "$COMMON_DIR/sys" ]; then
    BUILD_CFLAGS="$BUILD_CFLAGS -I$COMMON_DIR"
fi

# Compile all .c files in libelf/
OBJS=""
for src in "$LIBELF_DIR"/*.c; do
    [ -f "$src" ] || continue
    obj="${src%.c}.o"
    echo "  CC  $(basename "$src")"
    $CC $BUILD_CFLAGS -c "$src" -o "$obj"
    OBJS="$OBJS $obj"
done

if [ -z "$OBJS" ]; then
    echo "ERROR: No source files found in $LIBELF_DIR"
    exit 1
fi

echo "  AR  libelf.a"
$AR rcs "$PREFIX/lib/libelf.a" $OBJS

# Install headers
for h in libelf.h gelf.h; do
    [ -f "$LIBELF_DIR/$h" ] && cp "$LIBELF_DIR/$h" "$PREFIX/include/"
done
if [ -f "$COMMON_DIR/elfdefinitions.h" ]; then
    cp "$COMMON_DIR/elfdefinitions.h" "$PREFIX/include/"
fi
if [ -d "$COMMON_DIR/sys" ]; then
    mkdir -p "$PREFIX/include/sys"
    cp "$COMMON_DIR/sys/"*.h "$PREFIX/include/sys/" 2>/dev/null || true
fi

echo ""
echo "=== elftoolchain libelf build complete ==="
echo "  Static library: $PREFIX/lib/libelf.a"
echo "  Headers:        $PREFIX/include/"
echo ""
echo "Build libbpf with:"
echo "  make -C src USE_ELFTOOLCHAIN=1 ELFTOOLCHAIN_PREFIX=$PREFIX BUILD_STATIC_ONLY=y V=1"
