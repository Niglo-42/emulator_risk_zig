int main(void){
    volatile char   *uart = (volatile char *)0x10000000;
    int             i = 0;
    char            buf[6];

    buf[5] = 0;
    while (i < 5) {
        const char x = uart[5];
        if (x & 1) // 0x61
            buf[i++] = uart[0];
    }
    for (int j = 0; j < 5; j++)
        *uart = buf[j];
    return 0;
}