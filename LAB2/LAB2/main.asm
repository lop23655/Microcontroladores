/*
* Laboratorio2.as
*
* Creado: 12/02/2025 10:32:35
* Autor : Fabian Lopez
* Descripcion: Contador con timer
*/

/****************************************/
// Encabezado (Definici n de Registros, Variables y Constantes)?
.include "M328PDEF.inc" // Include definitions specific to ATMega328P
.cseg
.org 0x0000
.def COUNTER = R24

/****************************************/
// Configuraci n de la pila
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16

/****************************************/
// Configuracion MCU

SETUP:
	// Configurar Prescaler "Principal"
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16 // Habilitar cambio de PRESCALER
	LDI R16, 0b00000100
	STS CLKPR, R16 // Configurar Prescaler a 16 F_cpu = 1MHz

	// Inicializar timer0 CALL INIT_TMR0
	CALL INIT_TMR0

	// Configurar puertos (DDRx, PORTx, PINx)
	// Configurar puerto D como salidas con LED inicialmente apagados
	LDI R16, 0xFF
	OUT DDRD, R16 // Configuramos puerto D como salida
	LDI R16, 0x00
	OUT PORTD, R16 // Se mantienen apagados

	//Configurar puerto C como SALIDAS para los botones
	LDI R16, 0xFF
	OUT DDRC, R16 // Configuramos puerto C como entrada
	LDI R16, 0x00
	OUT PORTC, R16 // APAGADOS

	//Configurar puerto b como entradas para los botones
	LDI R16, 0x00
	OUT DDRB, R16 // Configuramos puerto C como entrada
	LDI R16, 0xFF
	OUT PORTB, R16 // Habilitamos pull-ups
	
	//Colocar valores iniciales a variables
	LDI COUNTER, 0x00
	LDI R23, 0x00
	LDI R17, 0xFF // R17 se usara para guardar el estado de los botones
	LDI R19, 0x00 // R18 se usara para reinicial el contador y llevar conteo de los bits 
	LDI R20, 0b01000111 //
	LDI R21, 0x7E //
	LDI R25, 0x00

	//Valores del display
	LDI R16, 0x7E //VALOR 0
	LDI XL, 0x00
	LDI XH, 0x01
	ST X+, R16 //GUARDAR EN EL 0x0100 VALOR 0
	LDI R16, 0b00110000 // VALOR 1
	ST X+, R16
	LDI R16, 0x6D //VALOR 2
	ST X+, R16
	LDI R16, 0x79// VALOR 3
	ST X+, R16
	LDI R16, 0x33 // VALOR 4
	ST X+, R16
	LDI R16, 0x5B //VALOR 5
	ST X+, R16
	LDI R16, 0x5F// VALOR 6
	ST X+, R16
	LDI R16, 0x70 // VALOR 7
	ST X+, R16
	LDI R16, 0x7F //VALOR 8
	ST X+, R16
	LDI R16, 0x7B// VALOR 9
	ST X+, R16
	LDI R16, 0b01110111// VALOR A
	ST X+, R16
	LDI R16, 0b00011111// VALOR B
	ST X+, R16
	LDI R16, 0b01001110// VALOR C
	ST X+, R16
	LDI R16, 0b00111101// VALOR D
	ST X+, R16
	LDI R16, 0b01001111// VALOR E
	ST X+, R16
	LDI R16, 0b01000111// VALOR F
	ST X+, R16
	LDI XL, 0x00
	LDI XH, 0x01

	LD R16, X
	OUT PORTD, R16
	


/****************************************/
// Loop Infinito
MAIN_LOOP:
	IN R16, PINB
	CPSE R17, R16
	CALL DISPLAY7
	IN R22, TIFR0 // Leer registro de interrupciOn de TIMER 0
	SBRS R22, TOV0 // Salta si el bit 0 estA "set" (TOV0 bit)
	RJMP MAIN_LOOP // Reiniciar loop
	SBI TIFR0, TOV0 // Limpiar bandera de "overflow"
	LDI R22, 158
	OUT TCNT0, R22 // Volver a cargar valor inicial en TCNT0
	INC COUNTER
	CPI COUNTER, 10 // R20 = 10 after 100ms (since TCNT0 is set to 10 ms)
	BRNE MAIN_LOOP
	CLR COUNTER
	CALL TEMP
	OUT PORTC, R23
	CLR R24
	RJMP MAIN_LOOP
	
/****************************************/
// NON-Interrupt subroutines

DISPLAY7:
	IN R16, PINB // Leer el puerto C a 0ms
	CP R17, R16 // Compara para ver si cambio el valor
	BREQ MAIN_LOOP // Regresa si no se pulso nada 
	CALL DELAY
	IN R16, PINB // Leer el puerto B a 20ms
	CP R17, R16 // Compara para ver si no fue accidente nuevamente
	BREQ MAIN_LOOP
	MOV R17, R16 // Guardando Estado nuevo de botones
	CALL SUMA
	CALL RESTA
	OUT PORTD, R19// Saca el valor actual del contador 1
	RET

INIT_TMR0:
	LDI R22, (1<<CS02) | (1<<CS00)
	OUT TCCR0B, R22 // Setear prescaler del TIMER 0 a 1024
	LDI R22, 158
	OUT TCNT0, R22 // Cargar valor inicial en TCNT0
	RET
	
DELAY: // Aumenta el mismo valor para dar un delay de 20ms para los antirrebotes
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
	LD R19, X
	SBRC R16, 0 // R16 = 0b11111110 
	RET
	LD R19,X+
	CALL OVERFLOW
	INC R25
	ANDI R25, 0x0F
	RET

RESTA:
	SBRC R16, 1 // R16 = 0b11111101 
	RET
	CALL UNDERFLOW
	LD R19,-X
	DEC R25
	ANDI R25, 0x0F
	RET

OVERFLOW:
	CPSE R19, R20
	RET
	LDI XL, 0x00
	LDI XH, 0x01
	LD R19, X
	RET

UNDERFLOW:
	CPSE R19, R21
	RET
	LDI XL, 0x10
	LDI XH, 0x01
	LD R19, X
	RET

TEMP:
	CLR R24
	MOV R24, R23
	ANDI R24, 0x0F
	CP R24, R25
	BRGE REST
	RJMP AUMENTO
	RET
REST:
	ANDI R23, 0x20
	SBRC R23, 5
	RJMP LIMP
	SBR R23, 0x20
	RET

LIMP:
	LDI R23, 0x00
	RET

AUMENTO:
	INC R23
	RET


/****************************************/
// Interrupt routines
/****************************************/
