#define W 40
#define H 20



static void write(const char *s, int len)
{
    register int a0 asm("a0") = 1;
    register int a7 asm("a7") = 64;
    register const char *a1 asm("a1") = s;
    register int a2 asm("a2") = len;

    asm volatile (
        "ecall"
        : "+r"(a0)
        : "r"(a1), "r"(a2)
        : "memory"
    );
}

static void clear_screen(void)
{
    static const char esc[] = "\x1b[2J\x1b[H";
    write(esc, sizeof(esc) - 1);
}

static void delay(void)
{
    volatile unsigned int i = 0;

    while (i < 100000) { // environ 30 fps les coquinous :3
        i++;
    }
}

static char screen[H][W + 1];

int main(void)
{
    int x = 10;
    int y = 10;
    int dx = 1;
    int dy = 1;

    for (int frame = 0; frame < 200; frame++) {
        for (int j = 0; j < H; j++) {
            for (int i = 0; i < W; i++) {
                screen[j][i] = ' ';
            }
            screen[j][W] = '\n';
        }

        for (int i = 0; i < W; i++) {
            screen[0][i] = '#';
            screen[H - 1][i] = '#';
        }

        for (int j = 0; j < H; j++) {
            screen[j][0] = '#';
            screen[j][W - 1] = '#';
        }

        screen[y][x] = 'O';
        clear_screen();
        write(&screen[0][0], H * (W + 1));
        delay();
        x += dx;
        y += dy;

        if (x >= W - 1 || x <= 0)
            dx = -dx;

        if (y >= H - 1 || y <= 0) {
            dy = -dy;
            dx = 0;
        }

        if (dy == 0 && dx == 0)
            dx = 1;
    }

    return 0;
}
