#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "uart16550.h"
#include "board.h"

void delay(unsigned int t)
{
	volatile uint32_t i, j;
	for(i = 0; i < t; i++)
		for(j = 0; j < 1024; j++);
}

int main(void)
{
    char str[10];
    int a, b, c;
    int n;

    // GPIO
	*((volatile uint32_t *)(GPIO_BASE + 8)) = 0xff;
	*((volatile uint32_t *)(GPIO_BASE + 4)) = 0xaa;

    // UART 115200 8N1
    uart_init(27);
    uart_puts("RISC-V CPU Boot ...\r\n");

	*((volatile uint32_t *)(GPIO_BASE + 4)) = 0x55;

    while(1) {
        printf("\rInput Something\r\n");
        n = scanf("%s%d%d%d", str, &a, &b, &c);
        printf("%d Arguments. str = %s, a = %d, b = %d, c = %d\r\n", n, str, a, b, c);
	    *((volatile uint32_t *)(GPIO_BASE + 4)) = n;
    }

	return 0;
}
