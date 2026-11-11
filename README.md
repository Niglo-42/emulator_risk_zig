ressources = https://cs315-f25.cs.usfca.edu/lectures/07-cs315-2025-10-02-cache-simulation/
https://docs.riscv.org/reference/isa/_attachments/riscv-unprivileged.pdf

https://msyksphinz-self.github.io/riscv-isadoc/#_lbu

pour compiler le c: 
riscv64-unknown-elf-gcc     -march=rv32i -mabi=ilp32     -ffreestanding -fno-builtin     -fno-pic -fno-pie     -nostdlib -nostartfiles     -Wl,-T,link.ld     -Wl,--no-relax     -O0     start.s <file_name>.c     -o <file_name>.elf

pour passer du elf structuré au binaire brut : riscv64-unknown-elf-objcopy     -O binary hello.elf hello.bin

ABI RISK_V(i)=
Register    ABI     Name Description Saver
x0          zero    Hard-wired zero —
x1          ra      Return address Caller
x2          sp      Stack pointer Callee
x3          gp      Global pointer —
x4          tp      Thread pointer —
x5–7        t0–2    Temporaries Caller
x8          s0/fp   Saved register/frame pointer Callee
x9          s1      Saved register Callee
x10–11      a0–1    Function arguments/return values Caller
x12–17      a2–7    Function arguments Caller
x18–27      s2–11   Saved registers Callee
x28–31      t3–6    Temporaries Caller
f0–7        ft0–7   FP temporaries Caller
f8–9        fs0–1   FP saved registers Callee
f10–11      fa0–1   FP arguments/return values Caller
f12–17      fa2–7   FP arguments Caller
f18–27      fs2–11  FP saved registers Callee
f28–31      ft8–11  FP temporaries Caller


ELF=
e_indent 16 bytes indépendantes

Index	Signification
0–3	Magic ELF : 7F 45 4C 46
4	Classe : ELF32 ou ELF64
5	Endianness
6	Version ELF
7	OS ABI
8	ABI version
9–15	Padding


la ram fait 16 méga


Adresse	Périphérique
0x00001000	RAM
0x10000000	UART
0x10010000	DISPLAY
Autre	Bus fault

TU EN ES LA :

L’ecall écrase les registres du programme invité. bus.syscall() remplace a7 par le numéro hôte et les registres pointeurs par des adresses hôte, sans jamais les restaurer. Test : après un write, a1 et a7 ont changé. Ton s.c ne le voit pas car il recharge tout avant chaque ecall en -O0. Un ecall ne doit modifier que a0 : la traduction doit se faire sur des copies.