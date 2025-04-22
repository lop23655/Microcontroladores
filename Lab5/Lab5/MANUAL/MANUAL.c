/*
 * MANUAL.c
 *
 * Created: 22/04/2025 08:49:16
 *  Author: fabis
 */ 

#include "MANUAL.h"

void initTimer0(){
	
	DDRB |= (1 << DDB0);
	
	TCCR0A= 0;
	TCCR0B= 0;
	TCCR0B |= (1<<CS00);
	TIMSK0 |= (1<<TOIE0);
}