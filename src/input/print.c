#define MAX_SIZE 0x100

void flush(char *buf, int n, volatile char *uart) {
    for (int j = 0; j < n; j++)
        *uart = buf[j];
}

int main(void){
    volatile char   *uart = (volatile char *)0x10000000;
    int             i = 0;
    char            buf[MAX_SIZE];

    while (i < MAX_SIZE) {
        if (uart[5] & 1) // 0x61
            buf[i++] = uart[0];
        if (buf[i - 1] == '\n' || i + 1 == MAX_SIZE) {
            flush(buf, i, uart);
            i = 0;
        }
    }
    return 0;
}