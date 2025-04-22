/*
 * SEV2.c
 *
 * Created: 9/04/2025 16:23:16
 *  Author: fabis
 */ 
#include "SEV2.h"
void initServoTimer12()
{
	// PB2 (OC1B) como salida
	DDRB |= (1 << DDB2);
	
	TCCR1A |= (1 << COM1B1);
}

void updateServoPulse2(uint16_t pulso2)
{
	// pulse_width entre 1000 (1ms) y 2000 (2ms)
	OCR1B = pulso2;
}