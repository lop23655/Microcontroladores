;
; ProyectoReloj2.asm
;
; Created: 11/03/2025 12:15:41
; Author : Fabian Lopez


/****************************************/
// Encabezado (Definicion de Registros, Variables y Constantes)
.include "M328PDEF.inc" // Incluye libreria del ATMEGA328P
.equ T0VALUE = 131

.equ MODES = 5//Modos que puede tener la programacion
.def MODE = R20//Registro para el modo actual
.equ MAX_USEC = 10// Maximo de unidades
.equ MIN_UNDER = -1// Valor minimo para que haga underflow
.equ MAX_DSEC = 6//Maximo valor de decenas
.equ MAX_UHR = 10//Maximo de horas en unidades
.equ MAX_DHR = 24//Maximo total de horas
.def MAXDHR = R14//Registro para cantidad de horas
.def COUNTER = R21//Contador para el timer
.def ACTION = R22//Accion actual para que boton fue presionado
.def COUNTERHR = R13//Registro para igualar el maximo de horas
.def COUNTERHRA = R12//Registro " " " en alarma
.def COUNTERDIA = R2//Registro comparar dias
.def COUNTERMES = R5//Registro para llevar en cuenta los meses
.equ MODESLR = 2//Switch para cambio entre display izquierdos o derechos
.def MODELR = R19//Llevar registro de izq/der
.def ACTIONLR = R24//Lleva registro de que accion realizar
.def COUNTER2 = R18//Contador para poder llegar a minutos
.def MINUNDER = R3//Registro para comparar el valor minimo para hacer underflow
.equ MIN_UNDERM = 0//Valor para hacer underflow
.def MINUNDERM = R4//Registro para hacer underflow

/************************Registro que se guardan en la RAM**************************************************/
.dseg
.org SRAM_START
/***Minutos***/
USEC: .byte 1
DSEC: .byte 1
/***Horas***/
UHR: .byte 1
DHR: .byte 1
/***Dias***/
UDIA: .byte 1
DDIA: .byte 1
/***Meses***/
UMES: .byte 1
DMES: .byte 1
PMES: .byte 1
/***Alarma***/
USECA: .byte 1
DSECA: .byte 1
UHRA: .byte 1
DHRA: .byte 1


.cseg
.org 0x0000
    JMP START
//Interrupcion por presionar un boton
.org PCI1addr
	JMP PCINT_ISR
//Ir a interrupcion por Timer
.org OVF0addr
    JMP RUTINA_DE_TIMER0_OV

NUM7: .DB 0x7D, 0x50, 0x6E, 0x76, 0x53, 0x37, 0x3F, 0x70, 0x7F, 0x73, 0x77, 0x0A// Tabla para los valores del display
LIMTMES: .DB 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 2, 4// Tabla limite de meses
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
	
	//Habilitar interrupciones botontes en puerto C
	LDI R16, (1 << PCINT8) | (1 << PCINT9) |(1 << PCINT10) | (1 << PCINT11)
	STS PCMSK1, R16
	LDI R16, (1 << PCIE1)
	STS PCICR, R16 

	// Configurar Prescaler "Principal"
	LDI R16, (1 << CLKPCE)
	STS CLKPR, R16 // Habilitar cambio de PRESCALER
	LDI R16, 0b00000100
	STS CLKPR, R16 // Configurar Prescaler a 16 F_cpu = 1MHz

	//Configurar el tipo de reloj, prescaler 8
	LDI R16, (1<<CS01) 
	OUT TCCR0B, R16
	LDI R16, T0VALUE
	OUT TCNT0, R16 

	// Habilitar interrupciones del TOV0
	LDI R16, (1 <<TOIE0)
	STS TIMSK0, R16

	// Configurar puertos (DDRx, PORTx, PINx)
	//Configurar puerto C como entradas para los botones
	LDI R16, 0xF0
	OUT DDRC, R16 // Configuramos puerto C como entradas
	LDI R16, 0x0F
	OUT PORTC, R16 // Pullups en primeros cuatro bits, luego las salidas apagadas

	//Configurar puerto D como salidas para los botones
	LDI R16, 0xFF
	OUT DDRD, R16 // Configuramos puerto D como SALIDAS
	LDI R16, 0x00
	OUT PORTD, R16 // APAGADOS

	//Configurar puerto B como salidas para los botones
	LDI R16, 0xFF
	OUT DDRB, R16 // Configuramos puerto B como salidas
	LDI R16, 0x00
	OUT PORTB, R16 // APAGADOS
	
	//Colocar valores iniciales a variables
	CLR COUNTER
	LDI R16, 0x00
	STS USEC, R16
	STS DSEC, R16
	STS UHR, R16
	STS DHR, R16
	STS USECA, R16
	STS DSECA, R16
	STS DDIA, R16
	STS DMES, R16
	STS PMES, R16
	STS DHRA, R16
	MOV COUNTERDIA, R16
	LDI R16, 0x01
	STS UDIA, R16
	LDI R16, 0x01
	STS UMES, R16
	LDI MODE, 0x00
	LDI MODELR, 0x00
	LDI ACTIONLR, 0x01
	CLR ACTION
	CLR COUNTERHR
	LDI R16, 1
	MOV COUNTERHRA, R16
	LDI R16, 0x18//Maximo de horas = 24
	MOV MAXDHR, R16
	LDI R16, 0x0C
	MOV COUNTERMES, R16
	LDI R16, -1
	MOV MINUNDER, R16
	LDI R16, 0
	MOV MINUNDERM, R16
	LDI R16, 0x01
	STS UHRA, R16
	
	SEI// Activar las interrupciones

//Main Loop
MAIN_LOOP:
	CALL REVISAR_ALARMA//Verificar si los valores del reloj y la alarma son iguales
	CPI MODE, 0
	BREQ RELOJ//Ir al reloj
	CPI MODE, 1
	BREQ FECHA //Ir a la fecha
	CPI MODE, 2
	BREQ GO_CONFIG_RELOJ//Ir a configurar reloj
	CPI MODE, 3
	BREQ GO_CONFIG_FECHA//Ir a configurar fecha
	CPI MODE, 4
	BREQ GO_CONFIG_ALARMA//Ir a configurar alarma
	RJMP MAIN_LOOP

GO_CONFIG_RELOJ:
	RJMP CONFIG_RELOJ

GO_CONFIG_FECHA:
	RJMP CONFIG_FECHA

GO_CONFIG_ALARMA:
	RJMP CONFIG_ALARMA

//MODOS RELOJ
RELOJ:
	SBI PORTC, PC4//Activar solo un LED y desactivando la otra
	CBI PORTC, PC5
	SBRC COUNTER, 0//Ciclos para el multiplexeado de los display
	CALL SHOW_USEC
	SBRS COUNTER, 0
	CALL SHOW_DSEC
	SBRC COUNTER, 1
	CALL SHOW_UHR
	SBRS COUNTER, 1
	CALL SHOW_DHR
	SBRS COUNTER2, 1//Cada medio segundo cambiar el estado de las led para los segundos
	CALL CAMBIAR_LED
	RJMP SALIDA

CAMBIAR_LED:
    SBIC PINB, PB4    //Si esta encendido la ira a apagar, si esta apgado saltara para encenderlos
    RJMP APAGAR_LED     
    SBI PORTB, PB4   //Enciende los leds
    RJMP FIN_CAMBIO //Salir
APAGAR_LED:
    CBI PORTB, PB4 
	CALL DELAY   
FIN_CAMBIO:
    RET
	
FECHA:
	CBI PORTC, PC4//Se enciende el otro led y se apaga el de el reloj
	SBI PORTC, PC5
	SBRC COUNTER, 0//Mismo proceso solo cambia el modo en las funciones SHOW que ahora mostraran fechas
	CALL SHOW_USEC
	SBRS COUNTER, 0
	CALL SHOW_DSEC
	SBRC COUNTER, 1
	CALL SHOW_UHR
	SBRS COUNTER, 1
	CALL SHOW_DHR
	SBRS COUNTER2, 1
	CALL CAMBIAR_LED
	RJMP SALIDA
	
//**********************************************************CONGIGURACION RELOJ*****************************************************
CONFIG_RELOJ:
	CBI PORTB, 0
	CBI PORTB, 1
	CBI PORTB, 2
	CBI PORTB, 3
	SBI PORTC, PC4//Se vuelve a encender el LED de reloj y se apaga el de fecha
	CBI PORTC, PC5
	CPI ACTION, 0x00//Ve en si se ha presionado un boton, si se presiona PC0, incrementa y si se presiona PC1 decrementa
	BREQ EXIT_CRELOJ
	CPI ACTION, 0x01
	BREQ INC_CRELOJ
	CPI ACTION, 0x02
	BREQ GO_DEC_CRELOJ
	RJMP SALIDA
	
GO_DEC_CRELOJ:
	RJMP DEC_CRELOJ

EXIT_CRELOJ:
	CPI ACTIONLR, 0x01//Cambia de valor dependiendo si se presiono PC3, y alterna entre izquierda y derecha 
	BREQ SHOW_LEFT
	CPI ACTIONLR, 0x02
	BREQ SHOW_RIGHT
	RJMP SALIDA

SHOW_LEFT:
	CALL SHOW_DHR//Muestra los valores solo del lado izquierdo ciclandolos con un delay
	CALL DELAY
	CALL SHOW_UHR
	CALL DELAY
	CALL SHOW_DHR
	RJMP SALIDA

SHOW_RIGHT:
	CALL SHOW_USEC//Muestra los valores solo del lado derecho ciclandolos con un delay
	CALL DELAY
	CALL SHOW_DSEC
	CALL DELAY
	CALL SHOW_USEC
	RJMP SALIDA

INC_CRELOJ:
	CPI ACTIONLR, 0x01//Dependiendo de los displays que se estan mostrando incrementara el valor de ese display
	BREQ INC_LEFT
	CPI ACTIONLR, 0x02
	BREQ INC_RIGHT
	RJMP SALIDA

INC_LEFT:
	LDI ACTION, 0x00//Reiniciando el cambio del boton
	LDS R16, UHR//Cargando valor de la RAM
	INC R16
	INC COUNTERHR
	CPSE COUNTERHR, MAXDHR//Comparandolo con el maximo para overflow de horas
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_UHR//Comparandolo con el maximo para que reinicie en 0
	BRNE GUARDAR_UHR//Si no ha llegado al maximo ira a gurdar el valor en otra funcion
	CLR R16
	STS UHR, R16//Guardando el valor en la RAM
	//Valores del cuarto display
	LDS R16, DHR//Mismo proceso solo cambia el maximo de la hora
	INC R16
	CPI R16, MAX_DHR
	BRNE GUARDAR_DHR
	CLR R16//Reiniciando todos los valor por overflow
	CLR COUNTERHR
	STS UHR, R16
	STS DHR, R16
	RJMP SALIDA

GUARDAR_UHR:
	STS UHR, R16
	RJMP SALIDA

GUARDAR_DHR:
	STS DHR, R16
	RJMP SALIDA

INC_RIGHT:
	LDI ACTION, 0x00//Mismo proceso ahora que del lado de los segundos, solo mas simplificado
	LDS R16, USEC	//ya que los limites son numeros exactos de 10 no hay necesidad de un contador extra
	INC R16
	CPI R16, MAX_USEC
	BRNE GUARDAR_USEC
	CLR R16
	//Valores en segundo display
	STS USEC, R16
	LDS R16, DSEC
	INC R16
	CPI R16, MAX_DSEC
	BRNE GUARDAR_DSEC
	CLR R16
	STS DSEC, R16
	RJMP SALIDA
	
GUARDAR_USEC:
	STS USEC, R16
	RJMP SALIDA

GUARDAR_DSEC:
	STS DSEC, R16
	RJMP SALIDA

DEC_CRELOJ:
	CPI ACTIONLR, 0x01//Cambiara a quien restara dependiendo de cual se este mostrando
	BREQ DEC_LEFT
	CPI ACTIONLR, 0x02
	BREQ DEC_RIGHT
	RJMP SALIDA

DEC_LEFT:
	LDI ACTION, 0x00//Mismo codigo solo cambian los INC a DEC y los limites
	LDS R16, UHR
	DEC R16
	DEC COUNTERHR
	CPSE COUNTERHR, MINUNDER//El limite seria cuando llegue el valor a 0
	RJMP PC+2
	RJMP PC+11
	CPI R16, MIN_UNDER
	BRNE GUARDAR_UHR
	LDI R16, 9// Ahora inicia en 9 por el underflow
	STS UHR, R16
	//Valores del cuarto display
	LDS R16, DHR
	DEC R16
	CPI R16, MIN_UNDER//Cuando llegue a cero reiniciaria los valores a 23 hrs
	BRNE GUARDAR_DHR
	LDI R16, 0x18
	MOV COUNTERHR, R16
	DEC COUNTERHR
	LDI R16, 3
	STS UHR, R16
	LDI R16, 2
	STS DHR, R16
	RJMP SALIDA
	
DEC_RIGHT:
	LDI ACTION, 0x00
	LDS R16, USEC//Mimso codigo solo cambiando los limites y el valor inicial
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GUARDAR_USEC
	LDI R16, 9
	//Valores en segundo display
	STS USEC, R16
	LDS R16, DSEC
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GUARDAR_DSEC
	LDI R16, 5
	STS DSEC, R16
	RJMP SALIDA
	//*******************************************CONGIFURACION DE FECHA *****************************************
CONFIG_FECHA:
	CBI PORTC, PC4//Se enciende LED de fecha y se apaga LED de reloj
	SBI PORTC, PC5
	CPI ACTION, 0x00
	BREQ GO_EXIT_CRELOJ//Mismo proceso que el codigo de cambio de reloj, solo se modifica lo que muestran las funciones SHOW
	CPI ACTION, 0x01//	y los limites para UNDERFLOW y OVERFLOW
	BREQ INC_CFECHA
	CPI ACTION, 0x02
	BREQ GO_DEC_CFECHA
	RJMP SALIDA
	
GO_DEC_CFECHA:
	RJMP DEC_CFECHA

GO_EXIT_CRELOJ:
	RJMP EXIT_CRELOJ

INC_CFECHA:
	CPI ACTIONLR, 0x02
	BREQ INC_LEFT_F
	CPI ACTIONLR, 0x01
	BREQ INC_RIGHT_F
	RJMP SALIDA

INC_LEFT_F:
	LDI ACTION, 0x00
	LDS R17, PMES// Se carga la tabla para limite de dias para poder realizar el overflow
	LDI ZL, LOW(LIMTMES << 1)
	LDI ZH, HIGH(LIMTMES << 1)
	ADD ZL, R17
	ADC ZH, R1
	LPM R17, Z
	//Comienza Fecha
	LDS R16, UDIA
	INC R16
	INC COUNTERDIA
	CPSE COUNTERDIA, R17//Se compara si llego al maximo de dias del mes actual
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_USEC
	BRNE GUARDAR_UDIA
	CLR R16
	STS UDIA, R16
	//Valores en segundo display
	LDS R16, DDIA
	INC R16
	CPI R16, MAX_DSEC
	BRNE GUARDAR_DDIA
	LDI R16, 0x01//Siempre comienza en 1 el overflow porque no hay dias 0 
	CLR COUNTERDIA
	STS UDIA, R16
	CLR R16
	STS DDIA, R16
	RJMP SALIDA

GUARDAR_UDIA:
	STS UDIA, R16
	RJMP SALIDA

GUARDAR_DDIA:
	STS DDIA, R16
	RJMP SALIDA

INC_RIGHT_F:
	LDI ACTION, 0x00
	LDS R16, UMES//Mismo codigo solo que en este caso el limite es 12 para los meses
	INC R16
	LDS R17, PMES
	INC R17
	STS PMES, R17
	CPSE R17, COUNTERMES
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_UHR
	BRNE GUARDAR_UMES
	CLR R16
	STS UMES, R16
	LDS R16, DMES
	INC R16
	CPI R16, 0x02
	BRNE GUARDAR_DMES
	LDI R16, 0x01//Tambien empieza desde 1 
	STS UMES, R16
	CLR R16
	STS PMES, R16
	STS DMES, R16
	RJMP SALIDA
	
GUARDAR_UMES:
	STS UMES, R16
	RJMP SALIDA

GUARDAR_DMES:
	STS DMES, R16
	RJMP SALIDA

DEC_CFECHA:
	CPI ACTIONLR, 0x02//Decremente el valor del display
	BREQ DEC_LEFT_F
	CPI ACTIONLR, 0x01
	BREQ DEC_RIGHT_F
	RJMP SALIDA

DEC_LEFT_F:
	LDI ACTION, 0x00
	LDS R17, PMES//Solo cambias los limites para cuando iniciaran los dias en unas funciones extras, luego es lo mismo que en reloj
	LDI ZL, LOW(LIMTMES << 1)
	LDI ZH, HIGH(LIMTMES << 1)
	ADD ZL, R17
	ADC ZH, R1
	LPM R17, Z
	//Comienza Fecha
	LDS R16, UDIA
	DEC R16
	DEC COUNTERDIA
	CPSE COUNTERDIA, MINUNDER
	RJMP PC+2
	RJMP PC+11
	CPI R16, MIN_UNDER
	BRNE GO_GUARDAR_UDIA
	LDI R16, 9
	STS UDIA, R16
	//Valores en segundo display
	LDS R16, DDIA
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GO_GUARDAR_DDIA
	MOV COUNTERDIA, R17//Compara con la tabla el dia actual
	DEC COUNTERDIA//Decremento o no podra hacer overflow luego
	CPI R17, 28
	BREQ FEBRERO
	CPI R17, 30
	BREQ MES_PAR
	CPI R17, 31
	BREQ MES_IMPAR
	RJMP SALIDA
	
FEBRERO://Si esta en mes 2, el underflow te devolvera al dia 28
	LDI R16, 8
	STS UDIA, R16
	LDI R16, 2
	STS DDIA, R16
	RJMP SALIDA

MES_PAR:// Si el mes es par, entonces el valor que regresara sera 30
	LDI R16, 0
	STS UDIA, R16
	LDI R16, 3
	STS DDIA, R16
	RJMP SALIDA

MES_IMPAR:// Si el mes es impar, entonces el valor que regresara sera 31
	LDI R16, 1
	STS UDIA, R16
	LDI R16, 3
	STS DDIA, R16
	RJMP SALIDA

GO_GUARDAR_UDIA:
	RJMP GUARDAR_UDIA

GO_GUARDAR_DDIA:
	RJMP GUARDAR_DDIA

DEC_RIGHT_F:// Solo cambia el hecho que INC es ahora DEC y los limites para realizar underflow son -1
	LDI ACTION, 0x00
	LDS R16, UMES
	DEC R16
	LDS R17, PMES
	DEC R17
	STS PMES, R17
	CPSE R17, MINUNDER
	RJMP PC+2
	RJMP PC+11
	CPI R16, MIN_UNDER
	BRNE GO_GUARDAR_UMES
	LDI R16, 9
	STS UMES, R16
	LDS R16, DMES
	DEC R16
	CPI R16, -1
	BRNE GO_GUARDAR_DMES
	LDI R16, 0x02// El valor luego de hacer underflow seria 12
	STS UMES, R16
	LDI R16, 1
	STS DMES, R16
	LDI R16, 11
	STS PMES, R16
	RJMP SALIDA

GO_GUARDAR_UMES:
	RJMP GUARDAR_UMES

GO_GUARDAR_DMES:
	RJMP GUARDAR_DMES

/*****************************************CONFIGURACION DE ALARMA*****************************************************/
CONFIG_ALARMA:
	SBI PORTC, PC4//Se activan las dos led para notificar que se esta modificando la alarma
	SBI PORTC, PC5
	CBI PORTB, PB5
	CBI PORTB, 0
	CBI PORTB, 1
	CBI PORTB, 2
	CBI PORTB, 3
	CPI ACTION, 0x00
	BREQ EXIT_ALARMA//Ahora las funciones SHOW mostraran los valores actuales de alarma
	CPI ACTION, 0x01
	BREQ INC_ALARMA// Los codigos para incrementar y decrementar son los mismo que en configuracion de reloj
	CPI ACTION, 0x02//solo cambia las variables que modifican de la RAM de reloj a alarma
	BREQ GO_DEC_ALARMA
	RJMP SALIDA
	
GO_DEC_ALARMA:
	RJMP DEC_ALARMA

EXIT_ALARMA:
	CPI ACTIONLR, 0x01
	BREQ GO2_SHOW_LEFT
	CPI ACTIONLR, 0x02
	BREQ GO2_SHOW_RIGHT
	RJMP SALIDA

GO2_SHOW_LEFT:
	RJMP SHOW_LEFT

GO2_SHOW_RIGHT:
	RJMP SHOW_RIGHT

INC_ALARMA:
	CPI ACTIONLR, 0x01
	BREQ INC_LEFT_ALARMA
	CPI ACTIONLR, 0x02
	BREQ INC_RIGHT_ALARMA
	RJMP SALIDA

INC_LEFT_ALARMA:
	LDI ACTION, 0x00
	LDS R16, UHRA
	INC R16
	INC COUNTERHRA
	CPSE COUNTERHRA, MAXDHR
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_UHR
	BRNE GUARDAR_UHRA
	CLR R16
	STS UHRA, R16
	//Valores del cuarto display
	LDS R16, DHRA
	INC R16
	CPI R16, MAX_DHR
	BRNE GUARDAR_DHRA
	CLR R16
	CLR COUNTERHRA
	STS UHRA, R16
	STS DHRA, R16
	RJMP SALIDA

GUARDAR_UHRA:
	STS UHRA, R16
	RJMP SALIDA

GUARDAR_DHRA:
	STS DHRA, R16
	RJMP SALIDA

INC_RIGHT_ALARMA:
	LDI ACTION, 0x00
	LDS R16, USECA
	INC R16
	CPI R16, MAX_USEC
	BRNE GUARDAR_USECA
	CLR R16
	//Valores en segundo display
	STS USECA, R16
	LDS R16, DSECA
	INC R16
	CPI R16, MAX_DSEC
	BRNE GUARDAR_DSECA
	CLR R16
	STS DSECA, R16
	RJMP SALIDA
	
GUARDAR_USECA:
	STS USECA, R16
	RJMP SALIDA

GUARDAR_DSECA:
	STS DSECA, R16
	RJMP SALIDA

DEC_ALARMA:
	CPI ACTIONLR, 0x01
	BREQ DEC_LEFT_ALARMA
	CPI ACTIONLR, 0x02
	BREQ DEC_RIGHT_ALARMA
	RJMP SALIDA

DEC_LEFT_ALARMA:
	LDI ACTION, 0x00
	LDS R16, UHRA
	DEC R16
	DEC COUNTERHRA
	CPSE COUNTERHRA, MINUNDER
	RJMP PC+2
	RJMP PC+11
	CPI R16, MIN_UNDER
	BRNE GUARDAR_UHRA
	LDI R16, 9
	STS UHRA, R16
	//Valores del cuarto display
	LDS R16, DHRA
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GUARDAR_DHRA
	LDI R16, 0x18
	MOV COUNTERHRA, R16
	DEC COUNTERHRA
	LDI R16, 3
	STS UHRA, R16
	LDI R16, 2
	STS DHRA, R16
	RJMP SALIDA
	
DEC_RIGHT_ALARMA:
	LDI ACTION, 0x00
	LDS R16, USECA
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GUARDAR_USECA
	LDI R16, 9
	//Valores en segundo display
	STS USECA, R16
	LDS R16, DSECA
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GUARDAR_DSECA
	LDI R16, 5
	STS DSECA, R16
	RJMP SALIDA

SALIDA:
	RJMP MAIN_LOOP//Salida para regresar al MAIN_LOOP
	
/*****************************Funciones que no interrumpen********************************/
REVISAR_ALARMA:
	LDS R27, USEC//Compara los valores de cada uno de los registros entre el valor actual del reloj y el de la alarma
	LDS R28, USECA//si todos son iguales encendera el buzzer
	CPSE R27, R28
	RJMP REGRESAR
	LDS R27, DSEC
	LDS R28, DSECA
	CPSE R27, R28
	RJMP REGRESAR
	LDS R27, UHR
	LDS R28, UHRA
	CPSE R27, R28
	RJMP REGRESAR
	LDS R27, DHR
	LDS R28, DHRA
	CPSE R27, R28
	RJMP REGRESAR
	SBI PORTB, 5	//Se enciende el buzzer
	RET

REGRESAR:
	RET

DELAY:
LDI R30, 0//Delay para mostrar los SHOW cuando estan en configuracion
SUBDELAY1:
INC R30
CPI R30, 100
BRNE SUBDELAY1
RET
	
SHOW_USEC:
	CBI PORTB, 0//Apaga todos los transistores
	CBI PORTB, 1
	CBI PORTB, 2
	CBI PORTB, 3
	CPI MODE, 1//Si esta en modo fecha ira a mostrar la fecha actual 
	BREQ SHOW_UDIA
	CPI MODE, 3//Si esta en modo configuracion de fecha mostrara la fecha actual
	BREQ SHOW_UDIA
	CPI MODE, 4//Si esta en modo alarma mostrara los valores de la alarma
	BREQ SHOW_USECA
	LDS R16, USEC
	LDI ZL, LOW(NUM7 << 1)//Se carga la tabla de los display
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16//Se coloca en la posicion actual de donde esta el display en la tabla para mostrar ese valor
	ADC ZH, R1//Para evitar desplazamiento de la tabla cuando se guarda en Z
	LPM R16, Z//Cargar el valor actual en el display sacandolo de la tabla
	OUT PORTD, R16
	SBI PORTB, 3//Encendiendo solo el display actual
	RET

SHOW_UDIA:// Todos los SHOW realizan lo mismo solo cambia el valor de RAM actual que colocan en la tabla para sacar el valor
	LDS R16, UDIA
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 1
	RET

SHOW_USECA:
	LDS R16, USECA
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 3
	RET

SHOW_DSEC:
	CBI PORTB, 0
	CBI PORTB, 1
	CBI PORTB, 2
	CBI PORTB, 3
	CPI MODE, 1
	BREQ SHOW_DDIA
	CPI MODE, 3
	BREQ SHOW_DDIA
	CPI MODE, 4
	BREQ SHOW_DSECA
	LDS R16, DSEC
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 2
	RET

SHOW_DDIA:
	LDS R16, DDIA
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 0
	RET

SHOW_DSECA:
	LDS R16, DSECA
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 2
	RET

SHOW_DHR:
	CBI PORTB, 0
	CBI PORTB, 1
	CBI PORTB, 2
	CBI PORTB, 3
	CPI MODE, 1
	BREQ SHOW_DMES
	CPI MODE, 3
	BREQ SHOW_DMES
	CPI MODE, 4
	BREQ SHOW_DHRA
	LDS R16, DHR
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 0
	RET

SHOW_DMES:
	LDS R16, DMES
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 2
	RET

SHOW_DHRA:
	LDS R16, DHRA
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 0
	RET

SHOW_UHR:
	CBI PORTB, 0
	CBI PORTB, 1
	CBI PORTB, 2
	CBI PORTB, 3
	CPI MODE, 1
	BREQ SHOW_UMES
	CPI MODE, 3
	BREQ SHOW_UMES
	CPI MODE, 4
	BREQ SHOW_UHRA
	LDS R16, UHR
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 1
	RET

SHOW_UMES:
	LDS R16, UMES
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 3
	RET

SHOW_UHRA:
	LDS R16, UHRA
	LDI ZL, LOW(NUM7 << 1)
	LDI ZH, HIGH(NUM7 << 1)
	ADD ZL, R16
	ADC ZH, R1
	LPM R16, Z
	OUT PORTD, R16
	SBI PORTB, 1
	RET

// INTERRUPCIONES

//Interrupcion de botones
PCINT_ISR:
	//Guardado de datos
	PUSH R16
	IN R16, SREG
	PUSH R16

	LDI ACTION, 0x00//Reinciando en 0 las acciones de los botones

	SBIC PINB, PB5//Verificar si el buzzer esta activo, asi no se podra presionar otros botones hasta que se apague
	RJMP APAGAR_ALARMA

	SBIS PINC, PC2//Idendificar si se presiono el boton para cambiar de modo y cambiar si es presionado
	INC MODE

	LDI R16, MODES
	CPSE MODE, R16//Verificar si llego al maximo de modos para dar la vuelta
	RJMP PC+2
	CLR MODE

	SBIS PINC, PC3//Ver se presiono boton para cambiar displays de lado izquierdo y derecho
	INC MODELR

	LDI R16, MODESLR
	CPSE MODELR, R16//Alternar entre los dos
	RJMP PC+2
	CLR MODELR

	CPI MODE, 0//Verificar en que modo esta y realizar las acciones correspondientes
	BREQ MODE0_ISR
	CPI MODE, 1
	BREQ MODE1_ISR
	CPI MODE, 2
	BREQ MODE2_ISR
	CPI MODE, 3
	BREQ MODE3_ISR
	CPI MODE, 4
	BREQ MODE4_ISR
	RJMP EXIT_PCINT_ISR

	MODE0_ISR://Si esta en modo reloj y fecha los saca automaticamente para que los demas botones no puedan intervenir en los procesos
	RJMP EXIT_PCINT_ISR

	MODE1_ISR:
	RJMP EXIT_PCINT_ISR

	MODE2_ISR://Verifica si presiono el boton para incrementar o decrementar y dar el valor de la accion correspondiente a cada uno
	SBIS PINC, PC0
	LDI ACTION, 0x01
	SBIS PINC, PC1
	LDI ACTION, 0x02
	CPI MODELR, 0//Ver si esta del lado izquierdo o derecho
	BREQ LEFT
	CPI MODELR, 1
	BREQ RIGHT
	RJMP EXIT_PCINT_ISR

	MODE3_ISR://Mismo proceso en el modo 3 y 4 (configuraciond de fecha y alarma)
	SBIS PINC, PC0
	LDI ACTION, 0x01
	SBIS PINC, PC1
	LDI ACTION, 0x02
	CPI MODELR, 0
	BREQ LEFT
	CPI MODELR, 1
	BREQ RIGHT
	RJMP EXIT_PCINT_ISR

	MODE4_ISR:
	SBIS PINC, PC0
	LDI ACTION, 0x01
	SBIS PINC, PC1
	LDI ACTION, 0x02
	CPI MODELR, 0
	BREQ LEFT
	CPI MODELR, 1
	BREQ RIGHT
	RJMP EXIT_PCINT_ISR

LEFT:
	LDI ACTIONLR, 0x01//Cargar valor para mostrar lado izquierdo
	RJMP EXIT_PCINT_ISR

RIGHT: 
	LDI ACTIONLR, 0x02//Cargar valor para mostrar lado derecho
	RJMP EXIT_PCINT_ISR

EXIT_PCINT_ISR://Regresar los datos guardados
	POP R16
	OUT SREG, R16
	POP R16
	RETI

APAGAR_ALARMA://Si se detecta que esta encendido el buzzer, desactivara los demas botones hasta que se presiono el indicado para apagarlo
	SBIS PINC, PC3
	CBI PORTB, PB5
	SBIS PINC, PC3
	RJMP ALARMA_SIL
	RJMP EXIT_PCINT_ISR

ALARMA_SIL://Resta uno al valor de la alarma para que no siga sonando luego de presionarla en el mismo momento
	LDS R16, USECA
	DEC R16
	CPI R16, MIN_UNDER
	BRNE GUARDAR_USECAR
	LDI R16, 9
	STS USECA, R16
	RJMP EXIT_PCINT_ISR

GUARDAR_USECAR:
	STS USECA, R16
	RJMP EXIT_PCINT_ISR

//Interrupcion de reloj
GO_EXIT:
	RJMP EXIT_TIMER0

GO_STORE_USEC:
	RJMP STORE_USEC

GO_STORE_DSEC:
	RJMP STORE_DSEC

GO_STORE_UHR:
	RJMP STORE_UHR

GO_STORE_DHR:
	RJMP STORE_DHR

RUTINA_DE_TIMER0_OV:
	PUSH R16
	IN R16, SREG
	PUSH R16
	//Reiniciar el contador de 10s
	LDI R16, T0VALUE
	OUT TCNT0, R16

	CPI MODE, 2//Si esta en los modos de configuracion se sale de la interrupcion para no cambiar sus datos en ese momento
	BREQ GO_EXIT
	CPI MODE, 3
	BREQ GO_EXIT
	CPI MODE, 4
	BREQ GO_EXIT

	LDI ACTION, 0x01
	INC COUNTER
	CPI COUNTER, 250//Counter para llegar a 0.25 segundos
	BRNE GO_EXIT
	CLR COUNTER
	INC COUNTER2
	CPI COUNTER2, 240//Counter para llegar a 60 segundos
	BRNE GO_EXIT
	CLR COUNTER2
	//Ver valores primer display
	LDS R16, USEC//Al llegar a 60 segundos incrementa un valor la unidad de minutos
	INC R16
	CPI R16, MAX_USEC
	BRNE GO_STORE_USEC
	CLR R16
	//Valores en segundo display
	STS USEC, R16
	LDS R16, DSEC//Luego de reiniciar el valor a 0 incrementa las decenas
	INC R16
	CPI R16, MAX_DSEC
	BRNE GO_STORE_DSEC
	CLR R16
	STS DSEC, R16
	//Valores del tercer display
	LDS R16, UHR
	INC R16
	INC COUNTERHR
	CPSE COUNTERHR, MAXDHR
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_UHR
	BRNE GO_STORE_UHR
	CLR R16
	STS UHR, R16
	//Valores del cuarto display
	LDS R16, DHR
	INC R16
	CPI R16, MAX_DHR
	BRNE GO_STORE_DHR
	CLR R16
	CLR COUNTERHR
	STS UHR, R16
	STS DHR, R16
	
	//Cargando valor del dia del mes actual
	LDS R17, PMES
	LDI ZL, LOW(LIMTMES << 1)
	LDI ZH, HIGH(LIMTMES << 1)
	ADD ZL, R17
	ADC ZH, R1
	LPM R17, Z
	
	//Comienza Fecha
	LDS R16, UDIA
	INC R16
	INC COUNTERDIA
	CPSE COUNTERDIA, R17
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_USEC
	BRNE STORE_UDIA
	CLR R16
	STS UDIA, R16
	//Valores en segundo display
	LDS R16, DDIA
	INC R16
	CPI R16, MAX_DSEC
	BRNE STORE_DDIA
	LDI R16, 0x01
	CLR COUNTERDIA
	STS UDIA, R16
	CLR R16
	STS DDIA, R16
	//Valores en tercer display
	LDS R16, UMES
	INC R16
	LDS R17, PMES
	INC R17
	STS PMES, R17
	CPSE R17, COUNTERMES
	RJMP PC+2
	RJMP PC+11
	CPI R16, MAX_UHR
	BRNE STORE_UMES
	CLR R16
	STS UMES, R16
	LDS R16, DMES
	INC R16
	CPI R16, 0x02
	BRNE STORE_DMES
	LDI R16, 0x01
	STS UMES, R16
	CLR R16
	STS PMES, R16
	STS DMES, R16
	RJMP EXIT_TIMER0

STORE_USEC:
	STS USEC, R16
	RJMP EXIT_TIMER0

STORE_DSEC:
	STS DSEC, R16
	RJMP EXIT_TIMER0

STORE_UHR:
	STS UHR, R16
	RJMP EXIT_TIMER0

STORE_DHR:
	STS DHR, R16
	RJMP EXIT_TIMER0

STORE_UDIA:
	STS UDIA, R16
	RJMP EXIT_TIMER0

STORE_DDIA:
	STS DDIA, R16
	RJMP EXIT_TIMER0

STORE_UMES:
	STS UMES, R16
	RJMP EXIT_TIMER0

STORE_DMES:
	STS DMES, R16
	RJMP EXIT_TIMER0

EXIT_TIMER0:
	POP R16
	OUT SREG, R16
	POP R16
	RETI