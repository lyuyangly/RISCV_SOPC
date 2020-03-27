#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "uart16550.h"
#include "board.h"

extern int xmodemReceive(unsigned char*, int);

typedef void (*p_func)(void);

void delay(unsigned int t)
{
	volatile uint32_t i, j;
	for(i = 0; i < t; i++)
		for(j = 0; j < 1024; j++);
}

int main(void)
{
    int st;
    p_func boot_main=(p_func)(0x10000000);

    // GPIO
	*((volatile uint32_t *)(GPIO_BASE + 8)) = 0xff;
	*((volatile uint32_t *)(GPIO_BASE + 4)) = 0xaa;

    // UART 115200 8N1
    uart_init(27);
    uart_puts("RISC-V CPU Boot ...\r\n");
    uart_puts("Receive Program Via Xmodem in 10s ...\r\n");
    delay(10000);

    st = xmodemReceive((unsigned char *)(0x10000000), 8192);

	*((volatile uint32_t *)(GPIO_BASE + 4)) = 0x55;

    if(st < 0) {
        uart_puts("Xmodem Receive FAIL.\r\n");
    	while(1);
    } else {
        uart_puts("\rBooting ...\r\n");
        boot_main();
    }

	return 0;
}
