@ Part 3 of Project 2
@ ECE371
@ full LED button interrupt procedure with timers
@ Nick Porter Dec 12, 2019

.text
.global _start
.global INT_DIRECTOR
_start:

@ set up stacks
			LDR		R13,=STACK1			@ point to base of STACK for SVC mode
			ADD		R13,R13,#0x1000		@ point to top of stack
			CPS		#0x12				@ switch to IRQ mode
			LDR		R13,=STACK2			@ point to IRQ stack
			ADD		R13,R13,#0x1000		@ point to top of stack
			CPS		#0x13				@ back to SVC mode
			
@ enable clock for GPIO1
			MOV		R0,#0x02			@ value to enable clocks for a GPIO module
			LDR		R1,=0x44E000AC		@ addr of CM_PER_GPIO1_CLKCTRL register
			STR 	R0,[R1]				@ write to register
			LDR		R0,=0x4804C000		@ base addr for GPIO registers
@ load value to turn off all 4 USR LEDs
			MOV		R7,#0x01E00000		@ GPIO 21-24
			ADD 	R4,R0,#0x190		@ make GPIO_CLEARDATAOUT register addr
			STR 	R7,[R4]				@ write to GPIO_CLEARDATAOUT register
@ set GPIO1 bits 24-21 as outputs
			ADD 	R1,R0,#0x134		@ make GPIO1_OE register addr
			LDR		R6,[R1]				@ read current GPIO1_OE register
			MOV		R7,#0xFE1FFFFF		@ word to enable bits 21-24
			AND		R6,R7,R6			@ clear bits 21-24
			STR 	R6,[R1]				@ write to GPIO1_OE register
			
@ Detect falling edge on GPIO1_29 and enable to assert POINTRPEND1
			ADD		R1,R0,#0x14C		@ R1=addr of GPIO1_FALLINGDETECT register
			MOV		R2,#0x20000000		@ load value for bit 29
			LDR		R3,[R1]				@ read GPIO_fallingdetect register
			ORR		R3,R3,R2			@ modify (set bit 29)
			STR		R3,[R1]				@ write back
			ADD		R1,R0,#0x34			@ addr of GPIO_IRQSTATUS_SET_0 register
			STR		R2,[R1]				@ enable GIO1_29 request on POINTRPEND1
			
@ Init INTC
			LDR		R1,=0x48200000		@ base addr for INTC
			MOV		R2,#0x2				@ value to reset INTC
			STR		R2,[R1,#0x10]		@ write to INTC config register
			MOV		R2,#0x80000000		@ unmask INTC INT 95 timer7 interrupt
			STR		R2,[R1,#0xC8]		@ write to INTC_MIR_CLEAR2 register
			MOV		R2,#0x04			@ value to unmask INTC INT 98, GPIOINT1A
			STR		R2,[R1,#0xE8]		@ write to INTC_MIR_CLEAR3 register
@ Turn on timer7 CLK
			MOV 	R2,#0x2				@ value to enable timer7 clk
			LDR		R1,=0x44E0007C		@ addr of CM_PER_TIMER7_CLKCTRL
			STR		R2,[R1]				@ turn on
			LDR		R1,=0x44E00504		@ addr of PRCMCLKSEL_timer7 register
			STR		R2,[R1]				@ select 32kHz clk for timer7
@ init timer 7 registers with count/overflow interrupt generation
			LDR		R1,=0x4804A000		@ base addr for timer7 registers
			MOV		R2,#0x1				@ value to reset timer7
			STR		R2,[R1,#0x10]		@ write to timer7 CFG register
			MOV		R2,#0x2				@ value to enable overflow interrupt
			STR		R2,[R1,#0x2C]		@ write to timer7 IRQENABLE_SET
			LDR		R2,=0xFFFF0000		@ count value for 2 seconds
			STR		R2,[R1,#0x40]		@ timer7 TLDR load register
			STR		R2,[R1,#0x3C]		@ timer7 TCRR count register
			
@ enable IRQ in CPSR
			MRS		R3,CPSR				@ copy CPSR to R3
			BIC		R3,#0x80			@ clear bit 7
			MSR		CPSR_c,R3			@ write back to CPSR
			
@ set ledstatus
			MOV		R10,#0x00			@ set ledstatus to off, 01 means leds are on
			MOV		R11,#0x01			@ set pulsestatus for set of leds to turn on
										@ 01=pulse1, 10=pulse2

@ main waitloop
WAITLOOP:	NOP
			B		WAITLOOP
			
INT_DIRECTOR:
			STMFD	SP!,{R0-R3,LR}		@ push registers on stack
			LDR		R1,=0x482000F8		@ addr of INTC-PENDING_IRQ3 register
			LDR		R2,[R1]				@ read INTC-PENDING_IRQ3 register
			TST		R1,#0x00000004		@ test bit 2
			BEQ		TCHK				@ not from GPIOINT1A, check timer7, else
			LDR		R0,=0x4804C02C		@ load GPIO1_IRQSTATUS_0 register addr
			LDR		R1,[R0]				@ read status register to see if button
			TST		R1,#0x20000000		@ check if bit 29=1
			BNE		BUTTON_SVC			@ if bit 29=1, go to button pushed
			LDR		R0,=0x48200048		@ else, go back. INTC_CONTROL register
			MOV		R1,#01				@ value to clear bit 0
			STR		R1,[R0]				@ write to INTC_CONTROL register
			LDMFD	SP!,{R0-R3,LR}		@ restore registers
			SUBS	PC,LR,#4			@ pass execution to wait loop for now
TCHK:
			LDR		R1,=0x482000D8		@ addr of INTC PENDING_IRQ2 register
			LDR		R0,[R1]				@ read value
			TST		R0,#0x80000000		@ check if interrupt from timer7
			BEQ		PASS_ON				@ No, return, yes, check overflow
			LDR		R1,=0x4804A028		@ addr timer7 IRQSTATUS register
			LDR		R0,[R1]				@ read value
			TST		R0,#0x2				@ check bit 1
			BNE		LED					@ if overflow, go toggle led
PASS_ON:								@ else go back to wait loop
			LDR		R0,=0x48200048		@ addr of INTC_CONTROL register
			MOV		R1,#01				@ value to clear bit 0
			STR		R1,[R0]				@ write to INTC_CONTROL register
			LDMFD	SP!,{R0-R3,LR}		@ restore registers
			SUBS	PC,LR,#4			@ pass execution to wait loop for now
			
			LDMFD	SP!,{R0-R3,LR}
			SUBS	PC,LR,#4
			
BUTTON_SVC:
			MOV		R1,#0x20000000		@ value turns off GPIO1_29 interrupt request
										@ also turns off INTC interrupt request
			STR		R1,[R0]				@ write to GPIO_IRQSTATUS_0 register
@ turn on LED
			LDR		R0,=0x4804C194		@ load addr of GPIO1_SETDATAOUT register
			MOV		R1,#0x01200000		@ load value to light USR0 and USR3
			STR		R1,[R0]				@ write to GPIO1_SETDATAOUT register
			MOV		R2,#0x03			@ load value to auto reload timer and start
			LDR		R1,=0x4804A038		@ addr of timer7 TCLR register
			STR		R2,[R1]				@ write to TCLR register
@ turn off NEWIRQA bit in INTC_CONTROL, so processor can respond to IRQ
			LDR		R0,=0x48200048		@ addr of INTC_CONTROL register
			MOV		R1,#01				@ value to clear bit 0
			STR		R1,[R0]				@ write to INTC_CONTROL register
			LDMFD	SP!,{R0-R3,LR}		@ restore registers
			SUBS	PC,LR,#4			@ pass execution to wait loop for now
			
LED:
@ turn off timer7 interrupt request and enable INTC for next IRQ
			LDR		R1,=0x4804A028		@ load addr of timer7 IRQSTATUS register
			MOV		R2,#0x2				@ value to reset timer7 overflow IRQ request
			STR		R2,[R1]				@ write to register
@ toggle LED
			LDR		R0,=0x4804C000		@ load base addr of GPIO1
			LDR		R1,[R11]			@ load pulsestatus register
			TST		R1,#0x01			@ test pulsestatus
			BNE		PULSE1				@ if true, load values for pulse1
			BEQ		PULSE2				@ else load values for pulse2
			
PULSE1:		MOV		R2,#0x01200000		@ load value to light USR0 and USR3
			ADD		R3,R0,#0x194		@ load addr of GPIO1_SETDATAOUT register
			MOV		R11,#0x10			@ set pulsestatus for next test
			B		TOGGLE
PULSE2:		MOV		R2,#0x00C00000		@ load value to light USR1 and USR2
			ADD		R3,R0,#0x194		@ load addr of GPIO1_SETDATAOUT register
			MOV		R11,#0x01			@ set pulsestatus for next test
			
TOGGLE:
			LDR		R1,[R10]			@ load ledstatus register
			TST		R1,#0x01			@ test if led on
			BNE		TOFF				@ LED on, go to turn off
			STR		R3,[R0,#0x194]		@ LED off, turn on with GPIO1_SETDATAOUT
			MOV		R10,#0x01			@ set LEDstatus to on
			B		BACK				@ back to wait loop via back proc
			
TOFF:		MOV		R7,#0x01E00000		@ GPIO 21-24
			ADD 	R4,R0,#0x190		@ make GPIO_CLEARDATAOUT register addr
			STR 	R7,[R4]				@ write to GPIO_CLEARDATAOUT register
			MOV		R10,#0x00			@ set led status to off
BACK:		
			LDR		R1,=0x48200048		@ addr of INTC_CONTROL register
			MOV		R2,#0x01			@ value to enable new IRQ response in INTC
			STR		R2,[R1]				@ write
			LDMFD	SP!,{R0-R3,LR}		@ restore registers
			SUBS	PC,LR,#4			@ return from IRQ interrupt procedure

.data
.align 2
STACK1:		.rept	1024
			.word	0x0000
			.endr
STACK2:		.rept	1024
			.word	0x0000
			.endr
.end
