#!/usr/bin/env bash
# Compile et lance les riscv-tests dans l'émulateur.
#
# usage :
#   tests/run_isa_tests.sh                 # rv32ui + rv32um
#   tests/run_isa_tests.sh rv32ui          # une seule suite
#   tests/run_isa_tests.sh rv32ui/add      # un seul test
#   tests/run_isa_tests.sh local           # nos tests maison (tests/isa/*.S)
#
# variables optionnelles :
#   EMU=chemin/vers/emulateur   (défaut : zig-out/bin/emulator_zig)
#   CC=compilateur              (défaut : riscv64-unknown-elf-gcc, sinon clang)

set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
RT="$ROOT/tests/riscv-tests"
OUT="$ROOT/tests/build"
EMU=${EMU:-$ROOT/zig-out/bin/emulator_zig}

# commit testé ; change-le seulement exprès
RT_COMMIT=3df703cd52d5f0d8224e3c50bf03c6cb70efff98

if [ ! -d "$RT/isa" ]; then
    echo "clonage de riscv-tests..."
    git clone -q https://github.com/riscv-software-src/riscv-tests "$RT" || exit 2
    git -C "$RT" checkout -q "$RT_COMMIT" || exit 2
fi
if [ ! -x "$EMU" ]; then
    echo "émulateur introuvable : $EMU (lance 'zig build' ou donne EMU=...)"
    exit 2
fi

# zicsr et zifencei : les GCC récents ne les incluent plus dans rv32i
MARCH=rv32im_zicsr_zifencei
if [ -z "${CC:-}" ]; then
    if command -v riscv64-unknown-elf-gcc >/dev/null; then
        CC=riscv64-unknown-elf-gcc
    else
        CC=clang
    fi
fi
if [ "$CC" = "clang" ]; then
    CFLAGS="--target=riscv32-unknown-elf -march=$MARCH -mabi=ilp32 -fuse-ld=lld"
else
    CFLAGS="-march=$MARCH -mabi=ilp32"
fi
CFLAGS="$CFLAGS -static -mcmodel=medany -nostdlib -nostartfiles \
    -I$ROOT/tests/env -I$RT/isa/macros/scalar -T$ROOT/tests/env/link.ld"

# quels tests ?
if [ $# -eq 0 ]; then
    set -- rv32ui rv32um local
fi
TESTS=()
for arg in "$@"; do
    if [ "$arg" = "local" ]; then
        for f in "$ROOT/tests/isa"/*.S; do
            TESTS+=("local/$(basename "$f" .S)")
        done
    elif [ -d "$RT/isa/$arg" ]; then
        for f in "$RT/isa/$arg"/*.S; do
            TESTS+=("$arg/$(basename "$f" .S)")
        done
    else
        TESTS+=("$arg")
    fi
done

mkdir -p "$OUT"
pass=0
fail=0
failed=()
for t in "${TESTS[@]}"; do
    suite=$(dirname "$t")
    name=$(basename "$t")
    elf="$OUT/$suite-$name.elf"
    mkdir -p "$(dirname "$elf")"
    if [ "$suite" = "local" ]; then
        src="$ROOT/tests/isa/$name.S"
    else
        src="$RT/isa/$t.S"
    fi
    if ! $CC $CFLAGS "$src" -o "$elf" 2> "$OUT/$suite-$name.cc.log"; then
        echo "[COMPIL] $t   (voir $OUT/$suite-$name.cc.log)"
        fail=$((fail + 1)); failed+=("$t"); continue
    fi
    # stdin=/dev/null : l'émulateur lit stdin sans bloquer
    # timeout : un test qui boucle à l'infini compte comme un échec
    log="$OUT/$suite-$name.log"
    timeout 10 "$EMU" "$elf" headless < /dev/null > "$log" 2>&1
    code=$?
    if [ $code -eq 0 ]; then
        echo "[OK]     $t"
        pass=$((pass + 1))
    else
        if [ $code -eq 124 ]; then
            why="timeout (boucle infinie ?)"
        elif grep -q "^FAIL" "$log"; then
            why="échec du cas n°$code"
        else
            why="arrêt anormal, code $code"
        fi
        echo "[ÉCHEC]  $t : $why   (voir $log)"
        fail=$((fail + 1)); failed+=("$t")
    fi
done

echo
echo "$pass réussis, $fail échoués"
if [ $fail -ne 0 ]; then
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
