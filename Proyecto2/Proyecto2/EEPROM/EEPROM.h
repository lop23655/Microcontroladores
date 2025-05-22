/*
 * EEPROM.h
 *
 * Created: 14/05/2025 16:26:15
 *  Author: fabis
 */ 


#ifndef EEPROM_H_
#define EEPROM_H_

#include <stdint.h>
#include <avr/io.h>

void eeprom_init(void);
uint8_t eeprom_read(uint16_t addr);
void    eeprom_store_block(uint16_t start_addr);
void    eeprom_playback(uint16_t start_addr);



#endif /* EEPROM_H_ */