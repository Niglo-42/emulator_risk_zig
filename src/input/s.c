#define W 40
#define H 20



// Avant : un ecall 64 (write) traduit vers l'hôte. Depuis les traps, un
// ecall saute au handler du guest, et ce programme n'en a pas : on écrit
// donc directement dans l'UART, octet par octet.
static void write(const char *s, int len)
{
    volatile char *uart = (volatile char *)0x10000000;

    for (int i = 0; i < len; i++)
        *uart = s[i];
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
