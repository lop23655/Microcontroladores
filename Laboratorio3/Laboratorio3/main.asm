;
; Laboratorio3.asm
;
; Created: 19/02/2025 13:36:25
; Author : Fabian Lopez
;
/****************************************/
// Encabezado (Definicion de Registros, Variables y Constantes)
.include "M328PDEF.inc" // Include definitions specific to ATMega328P
.cseg
.org 0x0000
    jmp START

; Vector de Pin Change Interrupt 0 (PCINT0) en ATmega328P -> 0x0006
.org 0x0006
    JMP BOTON

; Vector de Timer0 Overflow -> 0x0020
.org 0x0020
    JMP RUTINA_DE_TIMER0_OV


/****************************************/
// Configuraci n de la pila
START:
	LDI R16, LOW(RAMEND)
	OUT SPL, R16
	LDI R16, HIGH(RAMEND)
	OUT SPH, R16

/****************************************/
// Configuracion MCU

SETUP:
	CLI// Desactivar las interrupciones
	
	//Configuración de Interrupciones
	LDI R16, (1 << PCIE0)
	STS PCICR, R16
	
	LDI R16, (1 << PCINT0) | (1 << PCINT1)
	STS PCMSK0, R16

	// Configurar Prescaler "Principal"
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16 // Habilitar cambio de PRESCALER
	LDI R16, 0b00000100
	STS CLKPR, R16 // Configurar Prescaler a 16 F_cpu = 1MHz

	//Configurar el tipo de reloj, prescaler 64
	LDI R16, (1<<CS01) | (1 << CS00)
	OUT TCCR0B, R16
	LDI R16, 100
	OUT TCNT0, R16 

	// Habilitar interrupciones del TOV0
	LDI R16, (1 <<TOIE0)
	STS TIMSK0, R16

	// Configurar puertos (DDRx, PORTx, PINx)
	//Configurar puerto C como SALIDAS para los botones
	LDI R16, 0xFF
	OUT DDRC, R16 // Configuramos puerto C como SALIDAS
	LDI R16, 0x00
	OUT PORTC, R16 // APAGADOS

	//Configurar puerto D como SALIDAS para los botones
	LDI R16, 0xFF
	OUT DDRD, R16 // Configuramos puerto D como SALIDAS
	LDI R16, 0x00
	OUT PORTD, R16 // APAGADOS

	//Configurar puerto B como entradas para los botones
	LDI R16, 0x00
	OUT DDRB, R16 // Configuramos puerto B como entrada
	LDI R16, 0xFF
	OUT PORTB, R16 // Habilitamos pull-ups
	
	//Colocar valores iniciales a variables
	LDI R16, 0x00
	LDI R23, 0x00
	LDI R25, 0x00
	//Valores del display
NUM7: .DB 0x7E, 0x30, 0x6D, 0x79, 0x33, 0x5B, 0x5F, 0x70, 0x7F, 0x7B, 0x77, 0x0A// Tabla para los valores del display

	SEI// Activar las interrupciones
	
/****************************************/
// Loop Infinito
MAIN_LOOP:
	LDI ZH, HIGH(NUM7 << 1)//Rotacion de valor del display
	LDI ZL, LOW(NUM7 << 1)
	ADD ZL, R23// Colocar la posicion en Z de la tabla 
	LPM R24, Z//Cargar el valor actual de Z
	CBI PORTC, 5
	CBI PORTC, 4//Desactivar los transistores
	OUT PORTD, R24// Se saca el valor del display actual cargado de Z
	SBI PORTC, 4//Se activa los el transistor
	CALL DELAY//Se deja encendido por un poco de tiempo
	CBI PORTC, 4// Se apaga nuevamente
	LDI ZH, HIGH(NUM7 << 1)//Mismo procedimiento para display de decenas solo se cambia el registro que lleva la posicion de la tabla
	LDI ZL, LOW(NUM7 << 1)
	ADD ZL, R25// Se cambia el registro para ser independiente
	LPM R24, Z
	CBI PORTC, 5
	OUT PORTD, R24
	SBI PORTC, 5
	CALL DELAY
	CBI PORTC, 5
	CPI R20, 100//Contador para el segundo
	BRNE MAIN_LOOP
	CLR R20
	INC R23
	CPI R23, 0x0A
	BREQ OVERFLOW
	RJMP MAIN_LOOP
	

	
/****************************************/
// NON-Interrupt subroutines

/****************************************/
// Interrupt routines
/****************************************/
OVERFLOW://Cuando ya pasaron diez segundos se lleva a cabo 
	CLR R23//Reinciar el contador del display  y aumentar el del 2
	INC R25
	CPI R25, 0x06
	BRNE MAIN_LOOP
	CLR R25
	JMP MAIN_LOOP


RUTINA_DE_TIMER0_OV:// Interrupcion del contador
	LDI R16, 100
	OUT TCNT0, R16
	INC R20
	RETI

BOTON:// Interrupcion del boton
	LDI R18, (1<<PCIF0)//Cargar al registro
    OUT PCIFR, R18
	IN R17, PINB
	SBRC R17, 0// Revisa si el boton de restar esta presionada
	RJMP RESTAR
	INC R19
	ANDI R19, 0xFF
	OUT PORTC, R19
	RETI

RESTAR://Decremente el valor si se presiona el vbton
	DEC R19
	DEC R19
	OUT PORTC, R19
	RETI

DELAY: //Delay para mantener la luz encendida
LDI R30, 0
SUBDELAY1:
INC R30
CPI R30, 100
BRNE SUBDELAY1
RET