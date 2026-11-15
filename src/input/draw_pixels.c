int main(void){
    volatile int *screen = (volatile int *)0x1000;
    volatile char   *uart = (volatile char *)0x10000000;
    char buf;

    for (int j = 0; j < 864 * 1536; j++)
    {
        screen[j] = 0xff0000ff;
    }
    while (1)
    {
        if (uart[5] & 1) // 0x61
        {
            buf = uart[0];
            *uart = buf;
        }
        if (buf == 'q' || buf == 'Q') {
            return 0;
        }
    }
    return 0;
}
