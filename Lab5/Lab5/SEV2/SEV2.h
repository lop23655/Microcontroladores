/*
 * SEV2.h
 *
 * Created: 9/04/2025 16:23:29
 *  Author: fabis
 */ 
#ifndef SEV2_H_
#define SEV2_H_

#include <avr/io.h>

void initServoTimer12();
void updateServoPulse2(uint16_t pulso2);

#endif /* SEV2_H_ */