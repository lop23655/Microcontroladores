/*
 * Prelab1.c
 *
 * Created: 2/04/2025 10:03:20 * Author: Fabian Lopez * Description:  *//****************************************/// Encabezado (Libraries)#define F_CPU 160000000#include <avr/io.h>#include <avr/interrupt.h>#include <util/delay.h>uint8_t contador_vol = 0;
	
uint8_t msb = 0;
uint8_t lsb = 0;uint8_t contador = 0;uint8_t tablaDIS[] ={	0x77, 0x41, 0x6E, 0x6B, 0x59, 0x3B, 0x3F, 0x61, 0x7F, 0x7B, 0x7D, 0x1F, 0x36, 0x4F, 0x3E, 0x3C};/****************************************/// Function prototypesvoid setup();void initADC();/****************************************/// Main Functionint main(void){	setup(); //	while (1)	{				}}/****************************************/// NON-Interrupt subroutinesvoid setup(){	cli();	CLKPR = (1 << CLKPCE);	CLKPR = (1 << CLKPS2);	DDRD    = 0xFF;	PORTD   = 0x00;	DDRB    = 0xFF;	PORTB   = 0x00;	DDRC = 0x00;	PORTC = 0xFF; 	UCSR0B = 0;	PCICR |= (1 << PCIE1);	PCMSK1 |= (1 << PCINT8) | (1 << PCINT9);	initADC();	sei();}void initADC(){	ADMUX = 0;	ADMUX |= (1 << REFS0); //Referencia = AVCC	ADMUX |= (1 << ADLAR);	ADMUX |= (1 << MUX1);	 	ADCSRA = 0;	ADCSRA |= (1 << ADPS1) | (1 << ADPS0) | ( 1 << ADEN) | (1 << ADIE);		ADCSRA |= (1 << ADSC); 	}/****************************************/// Interrupt routinesISR(PCINT1_vect){	if(!(PINC & (1 << PINC0)))	{		contador++;		}		if(!(PINC & (1 << PINC1)))	{		contador--;	}		}


ISR(ADC_vect)
{
 
	contador_vol = ADCH;
	if (contador_vol < 5) contador_vol = 0;
	msb = (contador_vol >> 4) & 0x0F;
	lsb = contador_vol & 0x0F;

	// Mostrar dígito más significativo
	PORTD = tablaDIS[msb];
	PORTB |= (1 << PORTB1); // Activa display 2 (decenas hex)
	_delay_us(20);
	PORTB &= ~(1 << PORTB1); // Apaga display 2

	// Mostrar dígito menos significativo
	PORTD = tablaDIS[lsb];
	PORTB |= (1 << PORTB0); // Activa display 1 (unidades hex)
	_delay_us(20);
	PORTB &= ~(1 << PORTB0); // Apaga display 1
	
	PORTD = contador;
	PORTB |= (1 << PORTB2); // Activa display 1 (unidades hex)
	_delay_us(20);
	PORTB &= ~(1 << PORTB2); // Apaga display 1
	
	if(contador_vol >= contador){
		PORTB |= (1 << PORTB3); // Activa display 1 (unidades hex)	
	}
	else if (contador_vol < contador){
		PORTB &= ~(1 << PORTB3); // Apaga display 1
	}
	ADCSRA |= (1 << ADSC); // Inicia nueva conversión
}



