;
; AssemblerApplication3.asm
;
; Created: 5/02/2025 09:42:14
; Author : Fabian Lopez
;

// Encabezado
.include "M328PDEF.inc"
.cseg
.org 0x0000

// Configuracion de la pila
	LDI R16, LOW(RAMEND)
	OUT SPL, R16 // Cargar 0xff a SPL
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16 // Cargar 0x08 a SPH

// Configuracion de MCU?

SETUP:
	// Configurar puertos (DDRx, PORTx, PINx)
	// Configurar puerto C como salidas con LED inicialmente apagados
	LDI R16, 0xFF
	OUT DDRC, R16 // Configuramos puerto C como salida
	LDI R16, 0x00
	OUT PORTC, R16 // Se mantienen apagados

	// Configurar puerto B como entradas
	LDI R16, 0x00
	OUT DDRB, R16 // Configuramos puerto B como entrada
	LDI R16, 0xFF
	OUT PORTB, R16 // Habilitamos pull-ups
	
	LDI R17, 0xFF // R17 se usara para guardar el estado de los botones
	LDI R19, 0x00 // R18 se usara para reinicial el contador y llevar conteo de los bits 
	LDI R20, 0xFF // R20 se usara para guardar el estado de los botones del contador"2
	LDI R21, 0x00 // R21 se usara para reiniciar el contador y llevar el conteo del contador#2

// Loop principal o infinito
LOOP:
	IN R16, PINB // Leer el puerto B a 0ms
	CP R17, R16
	BREQ LOOP
	CALL DELAY
	IN R16, PINB // Leer el puerto B a 20ms
	CP R17, R16
	BREQ LOOP
	MOV R17, R16 // Guardando Estado nuevo de botones
	CALL SUMA
	CALL RESTA
	OUT PORTC, R19
	RJMP LOOP

// Subrutinas (que no son de interrupcion)
DELAY:
	LDI R18, 0
	
	SUBDELAY1:
	INC R18
	CPI R18, 0
	BRNE SUBDELAY1
	LDI R18, 0
	
	SUBDELAY2:
	INC R18
	CPI R18, 0
	BRNE SUBDELAY2
	LDI R18, 0
	
	SUBDELAY3:
	INC R18
	CPI R18, 0
	BRNE SUBDELAY3
	
	RET

SUMA:
	SBRC R16, 0 // R16 = 0b11111110 
	RET
	INC R19
	RET

RESTA:
	SBRC R16, 1 // R16 = 0b11111101 
	RET
	DEC R19
	RET

// Subrutinas de interrupciom
