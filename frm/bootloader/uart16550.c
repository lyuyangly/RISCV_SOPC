#include <stdint.h>
#include <stdlib.h>
#include "board.h"

void uart_init(uint16_t baudrate)
{
    uint8_t tmp;
    tmp = *((volatile uint8_t *)(UART_BASE + 3*4));

    // DLAB
    *((volatile uint8_t *)(UART_BASE + 3*4)) = tmp | 0x80;

    *((volatile uint8_t *)(UART_BASE + 0*4)) = baudrate & 0xff;
    *((volatile uint8_t *)(UART_BASE + 1*4)) = baudrate >> 8;

    *((volatile uint8_t *)(UART_BASE + 3*4)) = tmp & 0x7f;
}


void uart_tx_byte(uint8_t ch)
{
    uint8_t tmp;

    do {
        tmp = *((volatile uint8_t *)(UART_BASE + 5*4));
    } while((tmp & 0x20) == 0x00);

    *((volatile uint8_t *)(UART_BASE + 0*4)) = ch;
}

uint8_t uart_rx_byte(void)
{
    uint8_t tmp;

    do {
        tmp = *((volatile uint8_t *)(UART_BASE + 5*4));
    } while((tmp & 0x01) == 0x00);

    return (*((volatile uint8_t *)(UART_BASE + 0*4)));
}

void uart_puts(const char *str)
{
    while(*str) {
        uart_tx_byte(*str++);
    }
}
