/*
 * LAB5.c
 *
 * Created: 9/04/2025 09:25:22
 *  Author: fabis
 */ 
#include "LAB5.h"
void initServoTimer1()
{
	// PB1 (OC1A) como salida
	DDRB |= (1 << DDB1);

	// Modo 14: Fast PWM con ICR1 como TOP
	TCCR1A = (1 << WGM11); // WGM11 = 1
	TCCR1B = (1 << WGM13) | (1 << WGM12); // WGM13 y WGM12 = 1

	// No invertido en OC1A: COM1A1 = 1, COM1A0 = 0
	TCCR1A |= (1 << COM1A1) ;

	// Establecer TOP en ICR1 para 20 ms (50 Hz)
	// f = 16 MHz / 8 = 2 MHz, 20 ms = 40000 ticks
	ICR1 = 39999;

	// Prescaler = 8
	TCCR1B |= (1 << CS11);
}

void updateServoPulse(uint16_t pulso)
{
	// pulse_width entre 1000 (1ms) y 2000 (2ms)
	OCR1A = pulso;
}