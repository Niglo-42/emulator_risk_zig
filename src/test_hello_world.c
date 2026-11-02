typedef unsigned int size_t;

static inline void syscall_write(int fd, const char *buf, int len)
{
    register int a0 asm("a0") = fd;
    register const char *a1 asm("a1") = buf;
    register int a2 asm("a2") = len;

    asm volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2)
        : "memory"
    );
}

int main(void)
{
    const char msg[] = "Hello World!\n";
    syscall_write(1, msg, sizeof(msg) - 1);
    return 0;
}