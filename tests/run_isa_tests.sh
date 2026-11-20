#!/usr/bin/env bash
# Compile et lance les riscv-tests dans l'émulateur.
#
# usage :
#   tests/run_isa_tests.sh                 # rv32ui + rv32um
#   tests/run_isa_tests.sh rv32ui          # une seule suite
#   tests/run_isa_tests.sh rv32ui/add      # un seul test
#   tests/run_isa_tests.sh local           # nos tests maison (tests/isa/*.S)
#   tests/run_isa_tests.sh rv32mi          # tests du mode machine (traps)
#
# variables optionnelles :
#   EMU=chemin/vers/emulateur   (défaut : zig-out/bin/emulator_zig)
#   CC=compilateur              (défaut : riscv64-unknown-elf-gcc, sinon clang)
#   ENV=nu ou ENV=p             (défaut : p pour rv32mi, nu pour le reste)
#       nu : environnement sans trap (tests/env/nu)
#       p  : environnement officiel adapté, qui a BESOIN des traps
#            (tests/env/p) ; les tests rv32ui y tournent en mode U

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
# le sous-module env contient encoding.h (numéros des CSR, des causes...)
if [ ! -f "$RT/env/encoding.h" ]; then
    git -C "$RT" submodule update -q --init env || exit 2
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
    # tcontrol : nom de CSR inconnu de clang 18 -> on donne son numéro
    CFLAGS="--target=riscv32-unknown-elf -march=$MARCH -mabi=ilp32 -fuse-ld=lld -Dtcontrol=0x7a5"
else
    CFLAGS="-march=$MARCH -mabi=ilp32"
fi
CFLAGS="$CFLAGS -static -mcmodel=medany -nostdlib -nostartfiles \
    -I$RT/isa/macros/scalar -I$RT/env"

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

# Tests qui supposent une extension optionnelle que notre machine n'a pas.
# Ce ne sont pas des bugs : on les saute en disant pourquoi.
skip_reason() {
    case "$1" in
        rv32mi/breakpoint) echo "déclencheurs de debug (Sdtrig) non implémentés, optionnels" ;;
        rv32mi/pmpaddr)    echo "suppose des entrées PMP ; on en a 0, ce qui est permis" ;;
        *) echo "" ;;
    esac
}

mkdir -p "$OUT"
pass=0
fail=0
skipped=0
failed=()
for t in "${TESTS[@]}"; do
    reason=$(skip_reason "$t")
    if [ -n "$reason" ]; then
        echo "[SAUTÉ]  $t : $reason"
        skipped=$((skipped + 1))
        continue
    fi
    suite=$(dirname "$t")
    name=$(basename "$t")
    elf="$OUT/$suite-$name.elf"
    mkdir -p "$(dirname "$elf")"
    if [ "$suite" = "local" ]; then
        src="$ROOT/tests/isa/$name.S"
    else
        src="$RT/isa/$t.S"
    fi
    # quel environnement pour ce test ?
    if [ -n "${ENV:-}" ]; then
        env_dir="$ROOT/tests/env/$ENV"
    elif [ "$suite" = "rv32mi" ]; then
        env_dir="$ROOT/tests/env/p"
    else
        env_dir="$ROOT/tests/env/nu"
    fi
    if [ "$CC" = "clang" ]; then
        # L'assembleur de clang refuse qu'un symbole déclaré .weak par
        # l'environnement (mtvec_handler) soit redéclaré .global par le
        # test (GCC l'accepte). On compile une copie sans ces lignes.
        # On copie aussi le fichier inclus (rv32mi/x.S inclut ../rv64mi/x.S).
        tmp="$OUT/src/$suite"
        mkdir -p "$tmp" "$OUT/src/rv64mi" "$OUT/src/rv64si" "$OUT/src/rv64ui" "$OUT/src/rv64um"
        for d in rv64mi rv64si rv64ui rv64um; do
            for f in "$RT/isa/$d"/*.S; do
                sed '/\.glob[a]*l *[ms]tvec_handler/d' "$f" > "$OUT/src/$d/$(basename "$f")"
            done
        done
        sed '/\.glob[a]*l *[ms]tvec_handler/d' "$src" > "$tmp/$name.S"
        src="$tmp/$name.S"
    fi
    if ! $CC $CFLAGS -I"$env_dir" -T"$env_dir/link.ld" "$src" -o "$elf" 2> "$OUT/$suite-$name.cc.log"; then
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
echo "$pass réussis, $fail échoués, $skipped sautés"
if [ $fail -ne 0 ]; then
    printf '  %s\n' "${failed[@]}"
    exit 1
fi
