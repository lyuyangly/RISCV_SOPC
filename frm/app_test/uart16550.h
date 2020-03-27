#ifndef UART16550_H
#define UART16550_H

#include <stdint.h>

extern void uart_init(uint16_t);
extern void uart_tx_byte(uint8_t);
extern uint8_t uart_rx_byte(void);
extern void uart_puts(const char *);
extern int scanf(const char *fmt, ...);
extern int printf(const char *fmt, ...);

#endif
