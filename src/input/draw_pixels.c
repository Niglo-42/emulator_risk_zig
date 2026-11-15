int main(void){
    volatile char *screen = (volatile char *)0x1000;
    for (int j = 0; j < 0x1000000; j++)
    {
        screen[j] = 255;
    }
    return 0;
}