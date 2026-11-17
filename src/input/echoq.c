#define MAX_SIZE 0x100

int main(void){
    volatile char   *uart = (volatile char *)0x10000000;
    int             i = 0;
    char            buf[MAX_SIZE];

    while (i < MAX_SIZE) {
        if (uart[5] & 1) // 0x61
        {
            buf[i] = uart[0];
            *uart = buf[i];
        }
        if (buf[i] == 'q' || buf[i] == 'Q') {
            return 0;
        }
    }
    return 0;
}