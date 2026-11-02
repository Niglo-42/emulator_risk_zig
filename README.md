ressources = https://cs315-f25.cs.usfca.edu/lectures/07-cs315-2025-10-02-cache-simulation/
https://docs.riscv.org/reference/isa/_attachments/riscv-unprivileged.pdf

https://msyksphinz-self.github.io/riscv-isadoc/#_lbu

pour compiler le c: 
riscv64-unknown-elf-gcc     -march=rv32i -mabi=ilp32     -ffreestanding -fno-builtin     -fno-pic -fno-pie     -nostdlib -nostartfiles     -Wl,-T,link.ld     -Wl,--no-relax     -O0     start.s test_hello_world.c     -o hello.elf

pour passer du elf structuré au binaire brut : riscv64-unknown-elf-objcopy     -O binary hello.elf hello.bin