/*
 * Lab6.c
 *
 * Created: 23/04/2025 08:26:52
 * Author : fabis
 */

#include <avr/io.h>
#include <avr/interrupt.h>
#include <stdlib.h>     // itoa/utoa
#include <stdint.h>

//Mandar cómo mandar y recibir caracteres
//Reconoce
void setup();
void initUART();
void writeChar(char caracter);
void writeString(const char *texto);
void initADC();
void convADC(uint8_t valor);

/*––––– VARIABLES GLOBALES –––––*/
volatile uint8_t contador_vol = 0;   // valor del ADC 
volatile uint8_t temporal     = 0;   // último byte recibido 
volatile uint8_t ready        = 0;   // bandera de comando listo 

int main(void)
{
    setup();

    writeString("\r\n"
                "Ingrese la opción que desee realizar\r\n"
                "1. Leer el valor del potenciometro\r\n"
                "2. Mandar el valor del potenciometro en ASCII\r\n");

    while (1)
    {
        if (ready)               // Verificar si ya escribio
        {
            ready = 0;           // Ya que ya se escribio la desactivamos para que no se repita el menu de la terminal

            if (temporal == '1') // comparar con ASCII '1' 
            {
                convADC(contador_vol);
                writeString("\r\n");
            }
            else if (temporal == '2') // comparar con ASCII '2' 
            {
                writeChar(contador_vol);   // Envía los valores del 0 - 255.
                writeString("\r\n");

                PORTB = contador_vol;

                PORTD = (PORTD & ~((1 << PORTD7) | (1 << PORTD6)))   // Borra PD7 y PD6
                         | (contador_vol & ((1 << PORTD7) | (1 << PORTD6))); // Coloca bits 7-6 del PuertoD
            }
            else
            {
                writeString("Opción inválida\r\n");
            }

            // Vuelve a mostrar el menú 
            writeString("\r\n"
                        "Ingrese la opción que desee realizar\r\n"
                        "1. Leer el valor del potenciometro\r\n"
                        "2. Mandar el valor del potenciometro en ASCII\r\n");
        }
        
    }
}

/*––––– CONFIGURACIÓN –––––*/
void setup()
{
    cli();
    //Con la calculadora se decide el Baud Rate, ahorita se puede elegir cualquiera, ahorita elegimos 9600 (ver en hoja de datos)
    //Se asume 9600 por ahora
    //Modo asíncrono
    //En Double Speed sale bien, entonces se configura para double speed, esto es con prescaler de 1
    //Sin prescaler de 1 double speed y el half speed funcionan bien con 9615
    //Estamos usando prescaler de 1 ahorita
    //UBRR en 103

    DDRB  = 0xFF;   // puerto B como salida
    PORTB = 0x00;

    initUART();
    initADC();

    sei();
}

void initUART(void)
{
    //Se usa PD0 y PD1
    //Mirar el pinout
    DDRD |=  (1 << DDD1);   // PD1 TX
    DDRD &= ~(1 << DDD0);   // PD0 RX
    DDRD |=  (1 << DDD6);   
    DDRD |=  (1 << DDD7);   

    //Configurar UCS0A
    UCSR0A = 0;

    UCSR0B = (1 << RXCIE0) | (1 << RXEN0) | (1 << TXEN0);

    UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);

    //Se configura baud rate
    UBRR0 = 103; //9615 @ 16MHz
}

void writeChar(char caracter)
{
    while ((UCSR0A & (1 << UDRE0)) == 0);
    UDR0 = caracter;
}

void writeString(const char *texto)
{
    for (uint8_t i = 0; texto[i] != '\0'; i++)
    {
        writeChar(texto[i]);
    }
}

/*––––– INTERRUPCIONES –––––*/
ISR(USART_RX_vect)
{
    temporal = UDR0;    
    ready    = 1;       // Avisa que ya escribio para el menu
}

void initADC(void)
{
    ADMUX  = 0;
    ADMUX |= (1 << REFS0);      // AVCC
    ADMUX |= (1 << ADLAR);      // resultado en ADCH
	// No hay MUX porque esta conectado al PC0

    ADCSRA = 0;
    // prescaler ÷128 ? 125 kHz @16 MHz
    ADCSRA |= (1<<ADPS2) | (1<<ADPS1) | (1<<ADPS0) | (1<<ADEN) | (1<<ADIE);

    ADCSRA |= (1 << ADSC);      
    DDRC  &= ~(1 << DDC0);      // PC0 como entrada 
}

ISR(ADC_vect)
{
    contador_vol = ADCH;
    ADCSRA |= (1 << ADSC); // Inicia nueva conversión
}

/*––––– UTILIDAD –––––*/
void convADC(uint8_t valor)
{
    char buf[4];                // 0-255 ? máx. “255” 
    utoa(valor, buf, 10);       // base 10
    writeString(buf);           // Envía el valor convertido del ASCII
}