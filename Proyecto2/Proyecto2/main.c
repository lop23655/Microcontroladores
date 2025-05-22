/*
 * Proyecto2.c
 *
 * Created: 9/04/2025 09:24:09
 * Author: Fabian Lopez
 * Description: Control de 4 servos en tres modos:
 *   1) Manual   (potenciómetro por ADC)
 *   2) EEPROM   (guarda/recupera bloques de 4 lecturas ADC)
 *   3) Adafruit (recibe comandos por UART/Adafruit IO)
 */

#define F_CPU 16000000UL

#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>
#include <stdint.h>
#include <util/delay.h>

#include "EEPROM/EEPROM.h"
#include "EEPROM/PWM/PWM.h"

#define RX_BUF_SIZE 16

// Buffers y flags UART
char         rx_buf[RX_BUF_SIZE];
volatile uint8_t rx_idx    = 0;
volatile uint8_t cmd_ready = 0;

// Modos de operación
enum { MODE_MANUAL = 1, MODE_ADAFRUIT, MODE_EEPROM } mode = MODE_MANUAL;
enum { MODE_WRITE  = 1, MODE_READ   } mode2 = MODE_WRITE;

// Variables globales ADC/servo/EEPROM
volatile uint8_t canal_actual   = 0;
uint16_t          servo_position = 1000;
uint8_t           posicion       = 0;
uint16_t          eeprom_addr    = 0;  // dirección base 0,4,8,12
uint8_t           eeprom_stay    = 0;  // 0=no grabar, 1=grabar

// Prototipos
void setup(void);
void initUART(void);
void writeChar(char c);
void writeString(const char *s);
void initADC(void);

int main(void) {
    setup();
    writeString("\r\nSeleccione modo:\r\n1.Manual 2.EEPROM 3.Adafruit\r\n");

    while (1) {
        if (cmd_ready) {//Espera a una señal para de la UART para comenzar
            cmd_ready = 0;
            switch (rx_buf[0]) {
                // CAMBIAR MODO PRINCIPAL
                case 'M': {//Case viene de python es la señal que esta conectada a su respectivo receiver, en este caso Modo_tx
                    uint8_t m = atoi(&rx_buf[1]);
                    if (m >= MODE_MANUAL && m <= MODE_EEPROM) {
                        mode = m;
                        writeString("\r\nModo cambiado: ");
                        if (mode == MODE_MANUAL) {
                            writeString("Manual\r\n");
                            PORTD |=  (1<<PORTD4);//Enciende las leds que indican el modo
                            PORTD &= ~(1<<PORTD5);
                            // Arrancar ADC free-running
                            ADCSRA |= (1<<ADEN)|(1<<ADSC);//Activa interrupcion manual en modo EEPROM
                        }
                        else if (mode == MODE_EEPROM) {
                            writeString("EEPROM\r\n");
                            PORTD |=  (1<<PORTD4)|(1<<PORTD5);
                            // Parar ADC
                            ADCSRA &= ~(1<<ADEN);
                        }
                        else { // MODE_ADAFRUIT
                            writeString("Adafruit\r\n");
                            PORTD |=  (1<<PORTD5);
                            PORTD &= ~(1<<PORTD4);
                            ADCSRA &= ~(1<<ADEN);// Desactiva las interrupcion para poder mandar señales con ADAFRUIT
                        }
                        writeString("1.Manual 2.EEPROM 3.Adafruit\r\n");
                    }
                    break;
                }

                // MODO ADAFRUIT: control servos por UART
                case 'S': case 'T': case 'U': case 'W': {
                    if (mode == MODE_ADAFRUIT) {
                        uint16_t p = atoi(&rx_buf[1]);
                        if (rx_buf[0]=='S') updateServoPulse ((p*3850UL)/255+1200);
                        if (rx_buf[0]=='T') updateServoPulse2((p*3850UL)/255+1200);
                        if (rx_buf[0]=='U') updateServoPulse3((p*   15UL)/255+   16);
                        if (rx_buf[0]=='W') updateServoPulse4((p*   15UL)/255+   16);
                    }
                    break;
                }

                // MODO EEPROM: elegir submodo write/read
                case 'E': {
                    if (mode == MODE_EEPROM) {
                        mode2 = atoi(&rx_buf[1]);
                        writeString(mode2==MODE_WRITE?"Write block\r\n":"Read block\r\n");
                        writeString("1.Write 2.Read\r\n");
                    }
                    break;
                }

                // MODO EEPROM: seleccionar bloque 1–4
                case 'P': {
                    if (mode == MODE_EEPROM) {
                        posicion = atoi(&rx_buf[1]);
                        if (posicion>=1 && posicion<=4) {
                            eeprom_addr = (posicion-1)*4;
                            writeString("Bloque ");
                            writeChar('0'+posicion);
                            writeString(" seleccionado\r\n");
                            writeString("Use N0/N1 para stay\r\n");
                        }
                    }
                    break;
                }

                // NUEVO: N<payload> fija eeprom_stay (0=no grabar,1=grabar)
                case 'N': {
                    if (mode == MODE_EEPROM) {
                        eeprom_stay = (atoi(&rx_buf[1]) != 0);
                        writeString("Stay = ");
                        writeChar(eeprom_stay?'1':'0');
                        writeString("\r\n");
                    }
                    break;
                }

                default:
                    break;
            }
        }

        

    }
}

void setup(void) {
    cli();
    // LEDs en PD4 y PD5
    DDRD |= (1<<DDD4)|(1<<DDD5);
    initUART();
    initADC();
    initServoTimer1();
    initServoTimer12();
    initServoTimer2();
    sei();
}

void initUART(void) {
    // PD1 TX, PD0 RX
    DDRD |=  (1<<DDD1);
    DDRD &= ~(1<<DDD0);
    UCSR0A = 0;
    UCSR0B = (1<<RXCIE0)|(1<<RXEN0)|(1<<TXEN0);
    UCSR0C = (1<<UCSZ01)|(1<<UCSZ00);
    UBRR0  = 103; // 9600 bps @16MHz
}

void writeChar(char c) {
    while (!(UCSR0A & (1<<UDRE0)));
    UDR0 = c;
}

void writeString(const char *s) {
    while (*s) writeChar(*s++);//Sigue escribiendo hasta que se termine la señal mandada
}

void initADC(void) {
    // AVcc ref, ajuste izquierdo, canal0
    ADMUX  = (1<<REFS0)|(1<<ADLAR);
    // habilita ADC + ISR + prescaler128
    ADCSRA = (1<<ADEN)|(1<<ADIE)|(1<<ADPS2)|(1<<ADPS1)|(1<<ADPS0);
    // arranca free-running
    ADCSRA |= (1<<ADSC);
}

ISR(USART_RX_vect) {
	char c = UDR0;                // Leer el carácter que acaba de llegar al registro de datos de la UART

	// Comprobar si es fin de línea (‘\n’) o si hemos llenado el buffer menos uno
	if (c == '\n' || rx_idx >= RX_BUF_SIZE - 1) {
		rx_buf[rx_idx] = '\0';    // Añadir terminador nulo para convertir rx_buf en cadena C válida
		rx_idx = 0;               // Reiniciar el índice para la próxima señal
		cmd_ready = 1;            // Señalar al main() que hay un comando completo listo para procesar
		} else {
		rx_buf[rx_idx++] = c;     // Almacenar el carácter en el buffer y avanzar el índice
	}
}

ISR(ADC_vect) {
    uint8_t v = ADCH;
    // Solo si ADC habilitado (modo manual)
    if (ADCSRA & (1<<ADEN)) {
        switch (canal_actual) {
            case 0:
                updateServoPulse ((v*3600UL)/255 +1200);
                ADMUX = (ADMUX&0xF0)|1; canal_actual=1;
                break;
            case 1:
                updateServoPulse2((v*3600UL)/255 +1200);
                ADMUX = (ADMUX&0xF0)|2; canal_actual=2;
                break;
            case 2:
                updateServoPulse3((v*   15UL)/255 +   16);
                ADMUX = (ADMUX&0xF0)|3; canal_actual=3;
                break;
            default:
                updateServoPulse4((uint16_t)((v*0.106f)+10));
                ADMUX = (ADMUX&0xF0)|0; canal_actual=0;
                break;
        }
    }
    ADCSRA |= (1<<ADSC);  // siguiente conversión
}
