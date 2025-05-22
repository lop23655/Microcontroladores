/*
 * EEPROM.c
 *
 * Created: 14/05/2025 16:26:04
 *  Author: fabis
 */ 
#define F_CPU 16000000
#include <avr/io.h>
#include "EEPROM.h"
#include "PWM.h"
#include <util/delay.h>


static uint16_t ee_addr = 0;

void eeprom_init(void) {
	ee_addr = 0;
}

uint8_t eeprom_read(uint16_t addr) {
	while (EECR & (1<<EEPE));
	EEAR = addr;
	EECR |= (1<<EERE);
	return EEDR;
}

void eeprom_store_block(uint16_t start_addr) {
	uint8_t valor;
	//quito la interrupción de ADC
	ADCSRA &= ~(1<<ADIE);
	// hago mis 4 lecturas en polling
	for (uint8_t ch=0; ch<4; ++ch) {
		ADMUX = (ADMUX & 0xF0) | ch;
		ADCSRA |= (1<<ADSC);
		while (ADCSRA & (1<<ADSC));
		valor = ADCH;
		// escritura EEPROM 
		while (EECR & (1<<EEPE));
		EEAR = start_addr + ch;
		EEDR = valor;
		EECR |= (1<<EEMPE);
		EECR |= (1<<EEPE);
		_delay_ms(5);
	}
	//restauro canal 0 y máquina de interrupciones
	ADMUX      = (ADMUX & 0xF0) | 0;
	ADCSRA    |= (1<<ADIE);    // primero re-habilito la interrupción
	ADCSRA    |= (1<<ADSC);    // luego disparo la primera conversión (“manual”)
}

void eeprom_playback(uint16_t start_addr) {
	uint8_t val;
	for (uint8_t ch = 0; ch < 4; ++ch) {
		// lee en start_addr + ch
		val = eeprom_read(start_addr + ch);
		uint16_t pulse = ((uint32_t)val * 3850) / 255 + 1200;
		uint16_t pulse2 = ((uint16_t)val * 0.106 + 9.8);
		switch (ch) {
			case 0: updateServoPulse (pulse); break;
			case 1: updateServoPulse2(pulse); break;
			case 2: updateServoPulse3(pulse2); break;
			case 3: updateServoPulse4(pulse2); break;
		}
		_delay_ms(5);
	}
}