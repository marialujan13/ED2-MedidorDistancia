    LIST P=16F887
    #INCLUDE <P16F887.inc>

    ;Configuraciones del dispositivo
    __CONFIG _CONFIG1, _FOSC_INTRC_NOCLKOUT & _WDTE_OFF & _PWRTE_ON & _MCLRE_ON & _CP_OFF & _CPD_OFF & _BOREN_ON & _IESO_OFF & _FCMEN_OFF & _LVP_OFF
    __CONFIG _CONFIG2, _BOR4V_BOR40V & _WRT_OFF

    ;Variables
    #DEFINE TRIGGER PORTB,2	;Declaramos la palabra Trigger como el pin 2 del puerto b
    #DEFINE ECHO    PORTB,1	;Declaramos la palabra Echo como el pin 1 del puerto b
    
    CBLOCK 0x70
	    STATUS_TEMP
	    W_TEMP
	    DISTANCIA
	    CONT1
	    CONT2
	    CONTADOR1   
	    CONTADOR2 
	    CONTADOR3
	    DATO
	    CEN
	    DEC
	    UNI
    ENDC

    ;Inicialización
    ORG	    0x00
    GOTO    MAIN

    ;Rutina de interrupción
    ORG	    0x04
    GOTO    ISR
    ORG	    0x05
MAIN
    ;Configuración de puertos
    BANKSEL	ANSELH		;Configuro puerto B y A como digital
    CLRF	ANSELH
    BANKSEL	ANSEL
    CLRF	ANSEL

    BANKSEL	TRISA	
    MOVLW	0X00		;Puerto A como salidas
    MOVWF	TRISA
    MOVLW	b'00000011'	;Configuro RB0 y RB1 como entradas y RB2 como salida
    MOVWF	TRISB
    
    BANKSEL	PORTA
    CLRF	PORTA
    CLRF	PORTB		;Limpio puerto B
    
    BANKSEL	OPTION_REG
    MOVLW	b'00000001'	;Configurar TMR0 como temporizador (T0CS = 0)
    MOVWF	OPTION_REG	;Asignar el preescalador al temporizador TMR0 (PSA = 0), prescaler = 4
				;Habilito resistencias de pull-up
    BANKSEL	WPUB
    MOVLW	b'00000001'	;Configurar resistencia de pull-up interna para RB0
    MOVWF	WPUB
    CLRF	DISTANCIA
    
    ;Configuracion del EUSART
    BANKSEL	SPBRG
    MOVLW	0x19		;Baud rate = 9600bps a 4MHZ
    MOVWF	SPBRG
    BANKSEL	TXSTA
    MOVLW	0x24		;SYNC=0, BRGH=1, TX9=0, TXEN=1
    MOVWF	TXSTA
    BANKSEL	RCSTA
    MOVLW	0x90
    MOVWF	RCSTA   
    BANKSEL	PIR1
    BCF		PIR1, TXIF	;Limpiar el flag de transmisión
 
    ;Configuracion de LCD   
    CALL	RETARDO40ms
    MOVLW	0X30		;Este es un comando de inicialización para el LCD. 
				;El valor 0x30 se envía para configurar el LCD en el modo de 8 bits.
    CALL	ENVIARCOMANDO
    MOVLW	0X38		;Modo de 8 bits, 2 líneas de display y una matriz 
				;de 5x8 puntos por carácter
    CALL	ENVIARCOMANDO
    MOVLW	0X08		;APAGA EL DISPLAY
    CALL	ENVIARCOMANDO
    MOVLW	0X01		;LIMPIA EL DISPLAY
    CALL	ENVIARCOMANDO
    MOVLW	0X03		;Return home, o regreso a la primera linea
    CALL	ENVIARCOMANDO
    MOVLW	0X0C		;Enciende el display, sin cursor, sin parpadeo
    CALL	ENVIARCOMANDO
    
    ;Escribir en la primera línea
    MOVLW	0x80		;Dirección DDRAM para la primera línea (0x00 + 0x80)
    CALL	ENVIARCOMANDO
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	'D'
    CALL	ENVIARLETRA
    MOVLW	'i'
    CALL	ENVIARLETRA
    MOVLW	's'
    CALL	ENVIARLETRA
    MOVLW	't'
    CALL	ENVIARLETRA
    MOVLW	'a'
    CALL	ENVIARLETRA
    MOVLW	'n'
    CALL	ENVIARLETRA
    MOVLW	'c'
    CALL	ENVIARLETRA
    MOVLW	'i'
    CALL	ENVIARLETRA
    MOVLW	'a'
    CALL	ENVIARLETRA
    
    
;/////////////////INICIALIZACION DEL SENSOR ULTRASONICO/////////////////////////
    
    ;Verificar si el pulsador ha sido presionado
WAIT_RB0
    BTFSC	PORTB,0         ;Salir del bucle si el pulsador está presionado
    GOTO	WAIT_RB0
    GOTO	TRIGGER_ON
    
TRIGGER_ON
    CALL	RETARDO100ms
    BSF		TRIGGER		;Envío pulso de 10us al pin TRIGGER del sensor
    CALL	DELAY_10micros
    BCF		TRIGGER
    
NO_ES_UNO
    BTFSS	ECHO		;Pregunto si el pin echo se puso en 1
    GOTO	NO_ES_UNO
    ;Cargar el valor inicial en el registro TMR0
    BANKSEL	TMR0
    MOVLW	.249             ; Cargar el valor 249 para contar 58us
    MOVWF	TMR0	           
    MOVLW	b'10100000'	 ; Limpiar la bandera de desbordamiento de TMR0, habilitar
    MOVWF	INTCON		 ; GIE y T0IE
    
NO_ES_CERO
    BTFSC	ECHO		 ;Pregunto si se puso en 0
    GOTO	NO_ES_CERO
    CLRF	INTCON           ;Se ha producido el flanco de bajada. Prohíbe interrup.
    MOVLW	.2
    SUBWF	DISTANCIA,W	 ;DISTANCIA - W(2)
    BTFSS	STATUS,C
    GOTO	MSJ_ERROR        ;DISTANCIA =< 2cm FUERA DE LOS LIMITES
    MOVLW	.200		 ;Salta si distancia no es menor a dos y testea que no sea mayor a 200
    SUBWF	DISTANCIA,W	 ;DISTANCIA - W(200) 
    BTFSS	STATUS,C	   
    GOTO	MOSTRAR_DIS	 ;DISTANCIA <= 200cm
    GOTO	MSJ_ERROR	 ;DISTANCIA > 200 FUERA DE LOS LIMITES
    
MSJ_ERROR
    MOVLW	0xC0		 ;Dirección DDRAM para la segunda línea (0x40 + 0x80)
    CALL	ENVIARCOMANDO
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	'E'
    CALL	ENVIARLETRA
    MOVLW	'R'
    CALL	ENVIARLETRA
    MOVLW	'R'
    CALL	ENVIARLETRA
    MOVLW	'O'
    CALL	ENVIARLETRA
    MOVLW	'R'
    CALL	ENVIARLETRA
    CALL	TRANSMIT_STRING
    GOTO	FIN
    
MOSTRAR_DIS
    MOVLW	0xC0		;Dirección DDRAM para la segunda línea (0x40 + 0x80)
    CALL	ENVIARCOMANDO
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	' '
    CALL	ENVIARLETRA
    CALL	ENVIARNUMERO
    MOVLW	' '
    CALL	ENVIARLETRA
    MOVLW	'c'
    CALL	ENVIARLETRA
    MOVLW	'm'
    CALL	ENVIARLETRA
    CALL	TRANSMIT_DISTANCIA
    GOTO	FIN
    
ENVIARCOMANDO	    
    MOVWF	PORTA
    BCF		PORTB, 7
    BSF		PORTB, 5
    CALL	RETARDO1ms
    BCF		PORTB, 5
    RETURN
    
ENVIARLETRA	
    MOVWF	PORTA
    BSF		PORTB, 7
    BSF		PORTB, 5
    CALL	RETARDO1ms
    BCF		PORTB, 5
    RETURN
 
ENVIARNUMERO
    CALL	DCU
    MOVF	CEN,W		 ;Almacena el dígito de las centenas
    CALL	ENVIARDIGITO     ;Envia el dígito de las centenas
    
    MOVF	DEC,W		 ;Almacena el dígito de las decenas
    CALL	ENVIARDIGITO     ;Envia el dígito de las decenas
    
    MOVF	UNI,W		 ;Almacena el dígito de las unidades
    CALL	ENVIARDIGITO     ;Envia el dígito de las unidades
    
    RETURN

ENVIARDIGITO
    ADDLW	'0'		 ;Convierte el valor en W a su ASCII equivalente
    CALL	ENVIARLETRA
    RETURN   

;////////RUTINA QUE DESCOMPONE UN NUMERO EN CENTENAS, DECENAS, UNIDADES/////////
DCU   
    CLRF	CEN
    CLRF	DEC
    CLRF	UNI
    MOVF	DISTANCIA,F
    BTFSS	STATUS,F
    GOTO	DIST_ES_DIF_DE_0
    RETURN
DIST_ES_DIF_DE_0
EVAL_SI_DIST_ES_MAY_IGUAL_A_10
    MOVLW	D'10'
    SUBWF	DISTANCIA,W
    BTFSC	STATUS,C
    GOTO	DIST_ES_MAY_IGUAL_QUE_10
    GOTO	DIST_ES_MENOR_A_10
DIST_ES_MENOR_A_10
    MOVF	DISTANCIA,W
    MOVWF	UNI
    RETURN
DIST_ES_MAY_IGUAL_QUE_10
    MOVLW	D'10'
    SUBWF	DISTANCIA,F
    INCF	DEC,F
    ;LO SIGUIENTE EVALUA SI DEC=10
    MOVLW	D'10'
    SUBWF	DEC,W
    BTFSS	STATUS,Z
    GOTO	EVAL_SI_DIST_ES_MAY_IGUAL_A_10
    CLRF	DEC
    INCF	CEN,F
    GOTO	EVAL_SI_DIST_ES_MAY_IGUAL_A_10 

;/////////////////////////RUTINA DE INTERRUPCION////////////////////////////////
ISR
    ;Guardo contexto
    MOVWF	W_TEMP
    SWAPF	STATUS,W
    MOVWF	STATUS_TEMP
	
    ;Subrutina de interrupción
    MOVLW	.1
    ADDWF	DISTANCIA,F 
    BCF		INTCON,T0IF
    MOVLW	.249
    MOVWF	TMR0
    
    ;Recuperar contexto
    SWAPF	STATUS_TEMP,W
    MOVWF	STATUS
    SWAPF	W_TEMP,F
    SWAPF	W_TEMP,W
    RETFIE

;////////////////////RUTINAS PARA TRANSMISION SERIE/////////////////////////////
TRANSMIT_BYTE
    ;Esperar hasta que el buffer esté vacío
    BANKSEL	TXSTA
wait_tx				;Loop que espera la transmision
    BTFSS	TXSTA, TRMT
    GOTO	wait_tx
    ;Enviar el dato
    BANKSEL	TXREG
    MOVWF	TXREG
    RETURN

TRANSMIT_STRING
    MOVLW 'E'
    CALL TRANSMIT_BYTE
    MOVLW 'R'
    CALL TRANSMIT_BYTE
    MOVLW 'R'
    CALL TRANSMIT_BYTE
    MOVLW 'O'
    CALL TRANSMIT_BYTE
    MOVLW 'R'
    CALL TRANSMIT_BYTE
    RETURN

TRANSMIT_DISTANCIA
    MOVF CEN,W
    CALL TRANSMIT_BYTE
    MOVF DEC,W
    CALL TRANSMIT_BYTE
    MOVF UNI,W
    CALL TRANSMIT_BYTE
    RETURN

;//////////////////////////////RETARDOS/////////////////////////////////////////
RETARDO40ms	
    MOVLW	.55
    MOVWF	CONTADOR2
T25	    
    MOVLW	.229
    MOVWF	CONTADOR1
T15	    
    DECFSZ	CONTADOR1,f
    GOTO	T15
    DECFSZ	CONTADOR2,f
    GOTO	T25
    RETURN
    
RETARDO1ms	
    MOVLW	.11
    MOVWF	CONTADOR2
T27		
    MOVLW	.25	
    MOVWF	CONTADOR1
T17		
    DECFSZ	CONTADOR1,f	
    GOTO	T17
    DECFSZ	CONTADOR2,f
    GOTO	T27
    RETURN
    
DELAY_10micros
    MOVLW	.5
    MOVWF	P
B1
    DECFSZ	P,1
    GOTO	B1
    RETURN
    
RETARDO100ms
    MOVLW	.130
    MOVWF	CONT1
R2  
    MOVLW	.255
    MOVWF	CONT2
R1  
    DECFSZ	CONT2,F
    GOTO	R1
    DECFSZ	CONT1,F
    GOTO	R2
    RETURN
	
FIN
    GOTO    $
    END