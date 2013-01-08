; PrintASCII Procedure
; INPUT:		AX
; CLEARS/USES : CX,DX
; OUTPUT:		Converts each digit of AX into ASCII and prints it to the screen

PrintASCII:
    MOV BX,0x10
    XOR CX,CX

Continue:
    XOR DX,DX		; clear DX for further use in division
    DIV BX			; divide AX by the base (16)
                    ; the remainder of this division goes into DX
                    ; the result goes into AX
    CMP DL,0xA		; if the value is less than AH (10 in decimal) it's a number
    JL IsNumber

    SUB DL,0xA		; subtract A from the value to get the offset from 'A'
    ADD DL,0x41		; add the ASCII of A to this offset
    PUSH DX			; push the final ASCII value onto the stack
    JMP Check

IsNumber:

    ADD DL,030H		; add the ASCII of '0' to the number
    PUSH DX			; push the final ASCII value onto the stack

Check:
    INC CX
    CMP CX,4		; if there are still more numbers to output
    JL Continue		; go back to the start
    XOR CX,CX

Output:
    INC CL
    POP DX
    CALL PrintChar  ; print the digit which was converted to ASCII
    CMP CL,0x4		; run this 4 times -> once for each digit
    JL Output

    RET

; *******************************************************************


; *******************************************************************
; PrintChar Procedure
; INPUT: DL
; OUTPUT: Prints the contents of DL

PrintChar:
    MOV AL, DL
    MOV AH,0x0E ; print to screen
    INT 0x10
    RET
; *******************************************************************


