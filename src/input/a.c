int main(void){
    volatile char *uart = (volatile char *)0x10000000;
    *uart = 'A';
    return 0;
}