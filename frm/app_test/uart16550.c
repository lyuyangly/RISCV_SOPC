#include <stdint.h>
#include <stdlib.h>
#include <stdarg.h>
#include "board.h"

extern int vsscanf(const char *, const char *, va_list);
extern int vsprintf(const char *, const char *, va_list);

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

int scanf(const char *fmt, ...)
{
    int i = 0;
    unsigned char ch;
    char buf[80];
    va_list args;

    while(1) {
        ch = uart_rx_byte();
        uart_tx_byte(ch);
        if(ch == '\n' || ch == '\r') {
            buf[i] = '\0';
            break;
        } else {
            buf[i++] = ch;
        }
    }

    va_start(args, fmt);
    i = vsscanf(buf, fmt, args);
    va_end(args);
    uart_tx_byte('\r');
    uart_tx_byte('\n');
    return i;
}

int printf(const char *fmt, ...)
{
    int i = 0;
    unsigned int n = 0;
    char buf[80];
    va_list args;

    va_start(args, fmt);
    n = vsprintf(buf, fmt, args);
    va_end(args);

    for(i = 0; i < n; ++i) {
        uart_tx_byte(buf[i]);
    }
    return n;
}

