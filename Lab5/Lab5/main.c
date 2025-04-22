/*
 * Lab5.c
 *
 * Created: 9/04/2025 09:24:09
* Author: Fabian Lopez* Description:
 */ 

/****************************************/// Encabezado (Libraries)#define F_CPU 16000000#include <avr/io.h>#include <avr/interrupt.h>#include <util/delay.h>#include "LAB5/LAB5.h"#include "SEV2/SEV2.h"#include "MANUAL/MANUAL.h"/****************************************/// Function prototypesvoid setup();void initADC();uint8_t duty = 61;uint8_t contador_vol = 0;uint16_t servo_position = 1000; // inicio en 0°volatile uint8_t canal_actual;uint8_t limitante = 0;/****************************************/// Main Functionint main(void)
{
	setup();

	while (1)
	{
		
		}
}
/****************************************/// NON-Interrupt subroutinesvoid setup(){	cli();	//CLKPR = (1 << CLKPCE);	//CLKPR = (1 << CLKPS2); // 1 MHz frecuencia principal	//initPWMFastA(non_invert, 1024);	//initPWMFastB(invert, 1024);	initADC();	initServoTimer1();	initServoTimer12();	initTimer0();	DDRC &= ~(1 << DDC2);	DDRC &= ~(1 << DDC0);	DDRC &= ~(1 << DDC1);	sei();}void initADC()
{
	ADMUX = 0;
	ADMUX = (1<<REFS0)|(1<<ADLAR)|0x00;       // Selecciona ADC0 (PC0)
	
	ADCSRA = 0;
	ADCSRA |= (1 << ADPS1) | (1 << ADPS0); // Prescaler = 8
	ADCSRA |= (1 << ADATE);                // Auto trigger (Free Running)
	ADCSRA |= (1 << ADEN) | (1 << ADIE);   // Habilita ADC + interrupción

	//ADCSRB &= ~((1 << ADTS2) | (1 << ADTS1) | (1 << ADTS0)); // Free running mode

	ADCSRA |= (1 << ADSC); // Inicia la conversión
	canal_actual = 0;
}

/****************************************/// Interrupt routines

ISR(ADC_vect)
{

		if (canal_actual == 0)
		{
			ADMUX = 0;
			ADMUX |= (1 << REFS0);     // Referencia = AVCC
			ADMUX |= (1 << ADLAR);     // Ajuste a la izquierda (usamos ADCH)
			ADMUX = (ADMUX & 0xF0) | 0x00; // ADC0
			canal_actual++;
			servo_position = ((uint32_t)ADCH * 3850) / 255 + 1200;
			updateServoPulse(servo_position);
			//_delay_us(20); // Tiempo para que el servo reaccione
		}
		else if (canal_actual == 1)
		 {
			ADMUX = 0;
			ADMUX |= (1 << REFS0);     // Referencia = AVCC
			ADMUX |= (1 << ADLAR);     // Ajuste a la izquierda (usamos ADCH)
			ADMUX = (ADMUX & 0xF0) | 0x01; // ADC1
			canal_actual++;
			servo_position = ((uint32_t)ADCH * 3850) / 255 + 1200;
			updateServoPulse2(servo_position);
		}
		else if (canal_actual == 2)
		{
			ADMUX = 0;
			ADMUX |= (1 << REFS0);     // Referencia = AVCC
			ADMUX |= (1 << ADLAR);     // Ajuste a la izquierda (usamos ADCH)
			ADMUX = (ADMUX & 0xF0) | 0x02; // ADC2
			canal_actual = 0;
			limitante = ADCH;
			_delay_us(20);
		}
		

	//contador_vol = ADCH;
	//if (contador_vol < 0x3F) contador_vol = 0x3F;


	//duty = contador_vol;
	//updateDutyCycleA(duty);	//updateDutyCycleB(duty);
	//_delay_us(10);
	
	ADCSRA |= (1 << ADSC); // Inicia nueva conversión

}

ISR(TIMER0_OVF_vect){
	contador_vol++;
	
	if (contador_vol<limitante){
		PORTB |= (1<<PORTB0);
	}
	else
	{
		PORTB &= ~(1<<PORTB0);
	}
}