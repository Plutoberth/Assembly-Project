IDEAL
MODEL small
STACK 200h
p186

	;Constants
	TOP_OF_THE_PAGE EQU 2
	BOTTOM_OF_THE_PAGE EQU 24

;The program is a simple text editor. It contains more instructions about its use
;inside the prorgam..
;The user may delete, enter characters, move freely with arrow keys, tab,
;delete characters with backspace, delete. Finally, he can save or read from a file
;with the appropriate keys displayed in the toolbar.



DATASEG

extendedUserChar db 0 								;This variable will store the extended ASCII char or scan code.
charFromUser db 0     								;This variable will store the regular char from the user.
charToPrint db 0      								;Stores the char we want to print to the screen.
currentLineNum db 0  									;Cursor line
currentCharNum db 0                   ;Current char location.

tempCol db 0
color db 3            								;The current color we are using.

toolbar_message db 186, ' F1 - Title Screen | F2 - Change Color | F3 - Save | F4 - Load              ', 186, 10, 13
				db 200,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,205,188, 10, 13, '$'

;^ Our toolbar message.

filename_prompt db 'Filename:                                                                  $'


; ============================================
; ============ Bmp file properties ===========
; ============================================
menufilename db 'menu.bmp', 0          ;Filename for the menu image.
colormenufilename db 'colMenu.bmp', 0  ;Filename for the color menu image.
textfilename db 64 dup (0)             ;Filename from the user.

currentFileLoc dw 0                    ;Our location in the current file.

currentMemLoc dw 0                     ;Memory location/offset.

successFlag db 0                       ;Flag used to indicate success in various parts.
newline dw 0A0Dh                       ;CR/LF chars. Indicate a new line.
filenameOffset dw 0                    ;A pointer to the name of the file we want to display on screen.

filehandle dw ?                        ;Handle from the OS.

Header db 54 dup (0)									 ;Bmp headers.

Palette db 256*4 dup (0)							 ;Bmp color pallete.

ScrLine db 320 dup (0)                 ;Variables for bmp loader.

ErrorMsg db 'Error, couldnt load bmp file', 13, 10,'$'

specialCharPressed db 0 							 ;A flag that indicates if a special char was pressed.

; This variable will store the text the user writes. 1884 to temporarily accomodate newlines.
textStorage db 1884 dup (20h)    ;Default is 20h, the value of the Space char.

; This variable will store the color of the text the user writes.
textColorStorage db 1884 dup (3) ;Default is 3, the color cyan.

storeInMemFlag db 0 ; Activate the flag if the text needs to be stored in memory.

CODESEG

;------------------------------------------------------------
;-----------------opening the main menu image----------------
;------------------------------------------------------------

BMPProcs:
	proc OpenFile

	    ; Open file

	    mov ah, 3Dh
	    xor al, al
	    mov dx, [filenameOffset]
	    int 21h

	    jc openerror
	    mov [filehandle], ax
	    ret

	    openerror:
	    mov dx, offset ErrorMsg
	    mov ah, 9h
	    int 21h
	    ret ;BMP image.
	endp OpenFile
	proc ReadHeader

	    ; Read BMP file header, 54 bytes

	    mov ah,3fh
	    mov bx, [filehandle]
	    mov cx,54
	    mov dx,offset Header
	    int 21h
	    ret
	    endp ReadHeader
	    proc ReadPalette

	    ; Read BMP file color palette, 256 colors * 4 bytes (400h)

	    mov ah,3fh
	    mov cx,400h
	    mov dx,offset Palette
	    int 21h
	    ret
	endp ReadPalette
	proc CopyPal

	    ; Copy the colors palette to the video memory
	    ; The number of the first color should be sent to port 3C8h
	    ; The palette is sent to port 3C9h

	    mov si,offset Palette
	    mov cx,256
	    mov dx,3C8h
	    mov al,0

	    ; Copy starting color to port 3C8h

	    out dx,al

	    ; Copy palette itself to port 3C9h

	    inc dx
	    PalLoop:

	    ; Note: Colors in a BMP file are saved as BGR values rather than RGB.

	    mov al,[si+2] ; Get red value.
	    shr al,2 ; Max. is 255, but video palette maximal

	    ; value is 63. Therefore dividing by 4.

	    out dx,al ; Send it.
	    mov al,[si+1] ; Get green value.
	    shr al,2
	    out dx,al ; Send it.
	    mov al,[si] ; Get blue value.
	    shr al,2
	    out dx,al ; Send it.
	    add si,4 ; Point to next color.

	    ; (There is a null chr. after every color.)

	    loop PalLoop
	    ret
	endp CopyPal

	proc CopyBitmap

	    ; BMP graphics are saved upside-down.
	    ; Read the graphic line by line (200 lines in VGA format),
	    ; displaying the lines from bottom to top.

	    mov ax, 0A000h
	    mov es, ax
	    mov cx,200
	    PrintBMPLoop:
	    push cx

	    ; di = cx*320, point to the correct screen line

	    mov di,cx
	    shl cx,6
	    shl di,8
	    add di,cx

	    ; Read one line

	    mov ah,3fh
	    mov cx,320
	    mov dx,offset ScrLine
	    int 21h

	    ; Copy one line into video memory

	    cld

	    ; Clear direction flag, for movsb

	    mov cx,320
	    mov si,offset ScrLine
	    rep movsb

	    ; Copy line to the screen
	    ;rep movsb is same as the following code:
	    ;mov es:di, ds:si
	    ;inc si
	    ;inc di
	    ;dec cx
	    ;loop until cx=0
	    pop cx
	    loop PrintBMPLoop
	    ret
	endp CopyBitmap

	proc CloseBmpFile
	    pusha
	    mov ah,3Eh
	    mov bx, [FileHandle]
	    int 21h
	    popa
	    ret
	endp CloseBmpFile

	proc ShowImage
	    pusha

		mov ax, 13h ; move to graphic mode
		int 10h

		call OpenFile
	    call ReadHeader
	    call ReadPalette
	    call CopyPal
	    call CopyBitmap
		call CloseBmpFile

	    popa
	    ret
	endp ShowImage

proc clearScreen ;clears the screen
	pusha
	mov ax, 2	;Set back to text mode and reset everything.
	int 10h
	mov dx, offset toolbar_message
	call printdx
	popa
	ret
endp clearScreen

;printdx prints the value that is in dx, for printing long strings
proc printdx
	mov ah, 9h
	int 21h
	ret
endp printdx

proc initMouse ;displays the cursor
	pusha
	xor ax, ax
	int 33h
	popa
	ret
endp initMouse

proc resetCursor ;Simply resets the cursor to the default position.
	pusha

	mov al, TOP_OF_THE_PAGE
	mov [currentLineNum], al
	mov [currentCharNum], 0
	call setCursorPosition
	popa
	ret
endp resetCursor

proc loadMemory ;Load the memory buffer onto the screen, and handle special chars.
	pusha

	call clearScreen

	mov al, TOP_OF_THE_PAGE
	mov [currentLineNum], al
	inc al
	mov [currentCharNum], 0
	call setCursorPosition ; setting cursor position to the beginning of the page

	mov [storeInMemFlag], 0 ; We do not need to store what's already in mem again.
	; I opted to use a long loop instead of just printing it as a string due to the colors.

	mov dx, 0 ;The offset for the current char
	mov cx, 1884
	loadMemLoop:
		jmp printCharMemLoop

		lineDownMemLoop:
			inc [currentLineNum]
			mov [currentCharNum], 0 ; Go a line down

		printCharMemLoop:
			call setCursorPosition
			mov bx, offset textStorage
			add bx, dx ;to get the correct char

			checkForNewline: ; This is to support opening files that were not made by this program.
				mov ax, [word ptr bx] ; The char to print
				cmp ax, [newline]
				jne nextChar ;Keep counting if it isn't a newline.

			addnewline:
				sub cx, 2; To manually decrement the loop, as the "loop" keyword is unused.
				add dx, 2 ;To skip to the next chars after the newline.
				jmp lineDownMemLoop

			nextchar:
				mov al, [byte ptr bx]

				cmp al, 9d ;Tab character.
				je addTabLoader

				mov [charToPrint], al ; Move the correct char to the variable

				mov bx, offset textColorStorage
				add bx, dx ;to get the correct char
				mov al, [byte ptr bx] ; The char to print
				mov [color], al ; Move the correct char to the variable

				call writeAsciiCharAtCursor
				inc dx ; Go to the next char that we want to print
				dec cx

				call incCharNum

				cmp cx, 1
				ja loadMemLoop
				jmp endLoadMem

				addTabLoader:
					call incCharNum
					call incCharNum
					call incCharNum
					call incCharNum ; 4 spaces for a tab.
					inc dx ; Go to the next char that we want to print
					dec cx
					cmp cx, 1
					ja loadMemLoop


	endLoadMem:
		mov [storeInMemFlag], 1 ;We need to store the user's chars.
		call clearMemory
		call scanScreen ; We use scanScreen to deal with newlines.
		popa
		ret ;Loads the memory into the screen.
endp loadMemory

proc scanScreen ; Scans the screen using the cursor and spits to textStorage
	pusha					; Useful to easily deal with newlines.

	call resetCursor
	mov dx, 0 ;The textStorage offset. We cannot use bx because int 10h expects it.
	mov cx, 1840
	scanCharsLoop:
		mov ah, 8 ;Service to scan at cursor.
		mov bh, 0
		int 10h
		mov bx, offset textStorage
		add bx, dx ;Offset.
		mov [byte ptr bx], al ;Move char to memory.
		inc dx
		call incCharNum ;Go to the next char.
		dec cx
		cmp cx, 0
		jne scanCharsLoop


	call resetCursor
	popa
	ret
endp scanScreen


proc clearMemory ;Sets all of the memory to 0.
	pusha
	mov cx, 1840
	mov bx, offset textStorage
	clearLoop:
		mov [byte ptr bx], 20h ;Space
		inc bx
		loop clearLoop
	popa
	ret
endp clearMemory

proc createTextFile ;Creates a file with the name in textfilename and moves the handle to [filehandle].
	pusha
	mov cx, 0
	mov dx, offset textfilename
	mov ah, 3Ch
	int 21h

	mov [filehandle], ax
	;jc error_func ; will be called if there is an error.

	popa
	ret
endp createTextFile

proc openTextFile ;Opens the text file with the file name in the variable, and moves the handle to [filehandle].
	pusha

	mov dx, offset textfilename ;The chosen filename by the user.
	mov ah, 3Dh
	mov al, 0
	int 21h
	jc fileMissing ;If there is an error, this most likely means that the file doesn't exist.
	mov [filehandle], ax
	popa
	ret
	fileMissing: ;So we can create it.
		call createTextFile
		popa
		ret
endp openTextFile

proc closeTextFile ;Closes the text file whose handle is in [filehandle].
	pusha
	mov bx, [filehandle]
	mov ah, 3Eh
	int 21h
	;jc error_func ; will be called if there is an error.

	popa
	ret
endp closeTextFile

proc writeToTextFile ;Writes the data in [textStorage] into a text file whose name is in [textfilename].
	pusha

	mov dx, offset textfilename
	mov ah, 41h
	mov cl, 0
	int 21h ;try to delete file

	call createTextFile
	mov bx, offset textStorage
	mov [currentFileLoc], bx
	mov si, 23
	storeCharsLoop:

		mov ah, 40h;Write to file
		mov bx, [filehandle] ;Handle
		mov cx, 80;number of bytes to write.
		mov dx, [currentFileLoc] ;Buffer to read from
		int 21h ;Write text file contents.

		cmp si, 1 ;If it is the last line, there is no need to add a newline.
		je endOfStoreCharsLoop
		;Add a CR/LF newline to the file.
		mov ah, 40h;Write to file
		mov bx, [filehandle] ;Handle
		mov cx, 2;number of bytes to write.
		mov dx, offset newline
		int 21h ;Add a new line.

		add [currentFileLoc], 80 ;Go to the next line.
		endOfStoreCharsLoop:
			dec si
			cmp si, 0
			ja storeCharsLoop

	call closeTextFile
	popa
	ret
endp writeToTextFile

proc readTextFile ;Loads from the text file in [textfilename]
	pusha
	call clearMemory
	call openTextFile ;transfers handle into the variable

	mov ah, 3Fh ;"READ" int code
	mov bx, [filehandle] ; handle
	mov cx, 1884 ;Number of bytes + newlines (without the last ones)
	mov dx, offset textStorage ;Buffer to read into
	int 21h

	call clearScreen
	call loadMemory

	call closeTextFile
	popa
	ret
endp readTextFile

proc storeCharInMemory
	pusha
	mov al, [currentLineNum]
	sub al, 2
	mov bl, 80
	mul bl ;multiplying line  num by line to get

	xor dx, dx
	mov dl, [currentCharNum]

	add ax, dx
	mov bx, offset textStorage
	add bx, ax ;Setting the pointer to the location of the current char

	mov cl, [charToPrint]
	mov [bx], cl

	mov bx, offset textColorStorage
	add bx, ax ;Setting the pointer to the location of the current color char

	mov cl, [color]
	mov [bx], cl

	popa
	ret ;Stores a char in the correct memory spot.
endp storeCharInMemory

proc writeAsciiCharAtCursor
	pusha

	locationParams:
		mov dh, [currentLineNum] ;dh = line number - 25 lines
		mov dl, [currentCharNum] ;dl = character in the line - 80 chars
		mov bh, 0h ;bh ═ page
		mov bl, [color] ;bl ═ foreground color
		mov cx, 1 ;cx ═ number of repetitions

	mov al, [charToPrint] ; al = ascii code

	mov ah, 9 ;int code for writing a char at the cursor position.
	int 10h   ;https://en.wikipedia.org/wiki/INT_10H
	cmp [storeInMemFlag], 1
	jne endWriteAsciiChar
	storeACharInMem:
		call storeCharInMemory ;Stores the char in textStorage
	endWriteAsciiChar:
		popa
		ret
endp writeAsciiCharAtCursor


proc setCursorPosition ;sets the cursor (typeface position)
	pusha
	mov dh, [currentLineNum] ;dh = row
	mov dl, [currentCharNum] ;dl = column
	mov bh, 0
	mov ah, 2
	int 10h
	popa
	ret
endp setCursorPosition



proc getChar ;get a char directly from the keyboard and block, but doesn't echo. al ══> ascii ah ══> scan code
			;Often, it'll transfer an extended ascii charset instead, and will put 0 in al if it does.
	mov ah, 0h ;just so it wont block
	int 16h
	mov [charFromUser] ,al
	mov [extendedUserChar], ah
	ret
endp getChar

proc backspaceChar ;Move a char backwards and delete.
	cmp [currentCharNum], 0 ;checks if it's the first letter in the line
	je backspaceLine
	dec [currentCharNum]
	call setCursorPosition
	mov [charToPrint], 20h ;Space
	call writeAsciiCharAtCursor
	ret
	backspaceLine: ;if it is, it moves back a line
		mov [currentCharNum], 79 ;changes cursor to the end of the line
		call lineUp
		mov [charToPrint], 20h
		call writeAsciiCharAtCursor ;Delete the char.

		ret ;Moves a char backwards and deletes it.
endp backspaceChar

proc deleteChar

	cmp [currentCharNum], 40 ;checks if it's the last letter in the line
	je deleteLine
	inc [currentCharNum]
	call setCursorPosition
	mov [charToPrint], 20h ;Space
	call writeAsciiCharAtCursor
	ret
	deleteLine: ;if it is, it moves a line down
		mov [currentCharNum], 0 ;resets cursor to the beginning of said line
		call lineDown
		ret ;Moves a char forwards and delete.
endp deleteChar


proc lineDown ;Move a line down appropriately.
	pusha
	mov dh, [currentLineNum]
	cmp dh, [BOTTOM_OF_THE_PAGE]
  je endOfLineDown
	inc [currentLineNum] ;increases line number by one
	call setCursorPosition
	endOfLineDown:
		popa
		ret
endp lineDown

proc lineUp
	pusha
	mov dh, [currentLineNum]
	cmp dh, TOP_OF_THE_PAGE
	je endOfLineUp
	;  TODO: IMPLEMENT BETTER LOGIC
	dec [currentLineNum] ;decreases line number by one
	call setCursorPosition
	endOfLineUp:
		popa
		ret ;Move a line up appropriately. ;Moves a line up and complies with page size reqs.

endp lineUp

proc getColor
	pusha

	mov cl, [currentCharNum]
	mov ch, [currentLineNum]

	mov bx, offset colormenufilename
	mov [filenameOffset], bx
	call ShowImage ;show the color menu to the user

	call getChar ;get the color char from the user


	call clearScreen ;clear the screen
	call loadMemory  ;load the chars back into the program

	sub al, '0' ;change the ascii number char to the decimal representation

	mov [color], al ;move to color variable for use
	mov [currentCharNum], cl
	mov [currentLineNum], ch
	call setCursorPosition

	popa
	ret ;Get a color from the user. ;Gets a new color from the user.
endp getColor


proc incCharNum ;Increases the current char. Moves a line down if needed.
	pusha
	cmp [currentCharNum], 79 ;if it's the last char, just move to the next line
	je moveLineDownIncChar ;Move a line down.
	inc [currentCharNum]

	jmp endOfIncChar
	moveLineDownIncChar:
		call lineDown
		mov [currentCharNum], 0

	endOfIncChar:
		call setCursorPosition
		popa
		ret
endp incCharNum


;Shows the main menu, and waits for 'c' to continue.

proc showMenu
	pusha
	mov bx, offset menufilename
	mov [filenameOffset], bx
	call ShowImage
	checkInput:
		call getChar
		cmp [charFromUser], 27d ;esc char
		je ebridge2
		cmp [charFromUser], 'c'
		jne checkInput


	call clearScreen
	call loadMemory
	popa
	ret
endp showMenu

jmp endOfEbridge2
ebridge2:
	jmp exit
endOfEbridge2:

proc getFilename ;Get a filename from the user.
	pusha

	mov cl, [color] ; temporarily store the previous color
	mov [color], 7 ;Light gray, default.
	mov [tempCol], cl

	mov bx, offset textfilename ;So we know where to store the chars.

	mov [currentLineNum], 0
	mov [currentCharNum], 2 ;Just at the position to print.
	call setCursorPosition
	mov dx, offset filename_prompt
	call printdx

	mov [currentLineNum], 0
	mov [currentCharNum], 12d ;Just at the position to print.
	call setCursorPosition

	fileNameGetChars:
		call getChar

		cmp [charFromUser], 13d ;checks if it's Enter (return)
		je endCharInput ;Submit if it is.

		cmp [charFromUser], 8d ;Checks if the char is backspace
		je finputBackspace

		cmp [currentCharNum], 77d
		je fileNameGetChars ;Continue waiting for an enter if it is too long.



		jmp endOfFilenameSpecials
		finputBackspace:
			cmp [currentCharNum], 12d
			je fileNameGetChars ;We can't go back if it is the first char.

			dec [currentCharNum]
			call setCursorPosition

			mov [charToPrint], 0d ;Change to 0 for the array.
			call writeAsciiCharAtCursor

			dec bx ;Because we are going to add one to bx.
			jmp fileNameGetChars

		endOfFilenameSpecials:
			mov al, [charFromUser]
			mov [charToPrint], al
			mov [bx], al ;Move the char to the string.
			call writeAsciiCharAtCursor
			call incCharNum

			inc bx
			jmp fileNameGetChars

	endCharInput:
		mov [byte ptr bx], 0 ; To cap off the array.

		mov [currentCharNum], 0
		call setCursorPosition
		mov dx, offset toolbar_message
		call printdx
		call resetCursor

	mov cl, [tempCol] ;Restore the previous color.
	mov [color], cl

	popa
	ret
endp getFilename

proc handleSpecialChars
	pusha
	mov [specialCharPressed], 1

	cmp [charFromUser], 27d ;esc char
	je exitBridge

	cmp [charFromUser], 8d ;Checks if the char is backspace
	je bkspcChar

	cmp [charFromUser], 13d ;checks if it's Enter (return)
	je returnChar ;moves line if it is

	cmp [charFromUser], 127d ;delete char. Deletes forward.
	je delChar

	cmp [extendedUserChar], 03Ch ;F2 Extended ASCII code ═ http://webpages.charter.net/danrollins/techhelp/0055.HTM
	je colorChar

	cmp [extendedUserChar], 04Bh ;left arrow extended ascii
	je leftArrowChar

	cmp [extendedUserChar], 04Dh ;right arrow extended ascii
	je rightArrowChar

	cmp [extendedUserChar], 048h ;up arrow extended ascii
	je upArrowChar

	cmp [extendedUserChar], 050h ;down arrow extended ascii
	je downArrowChar

	cmp [extendedUserChar], 03bh ;F1 character for the menu.
	je showMenuChar

	cmp [charFromUser], 9d ;Tab character.
	je tabChar

	jmp secondRoundSpecials ;Due to jmp size restrictions, I had to seperate those sections.
	mov [specialCharPressed], 0
	jmp endOfFunc

	exitBridge:
		jmp exit
	endOfBridge:

	bkspcChar:
		call backspaceChar
		jmp endOfFunc

	returnChar:
		;TODO: Add an empty line in memory, and move to it. Also reprint.
		mov [currentCharNum], 0
		call lineDown
		jmp endOfFunc

	delChar:
		mov [charToPrint], 20h ;Space
		call deleteChar
		jmp endOfFunc

	colorChar:
		call getColor
		jmp endOfFunc

	arrow_instructions:
		rightArrowChar:
			call incCharNum
			jmp endOfFunc

		leftArrowChar:
			cmp [currentCharNum], 0
			je moveLineUp
			dec [currentCharNum]
			jmp endOfFunc

		upArrowChar:
			call lineUp
			jmp endOfFunc

		downArrowChar:
			call lineDown ;in this case, we would rather stay in the same position
			jmp endOfFunc

	moveLineUp:
		mov [currentCharNum], 80 ;changes cursor to the end of said line
		call lineUp
		jmp endOfFunc

	showMenuChar:
		call showMenu
		jmp endOfFunc

	tabChar: ; A tab adds four spaces.
		mov cx, 4
		addSpace:
			call incCharNum
			loop addSpace ;Continue the loop.

		call setCursorPosition
		jmp endOfFunc

	secondRoundSpecials:
		cmp [extendedUserChar], 71d ;Home character.
		je homeKey

		cmp [extendedUserChar], 79d ;End character.
		je endKey

		cmp [charFromUser], 32d ;Space character.
		je spaceKey

		cmp [extendedUserChar], 03dh ;F3 Char.
		je saveKey

		cmp [extendedUserChar], 03eh ;F4 Char.
		je loadKey

		mov [specialCharPressed], 0 ; If it failed all of the special char tests, the flag will be turned off.
		jmp endOfFunc

	homeKey: ;Return to the beginning of the line.
		mov [currentCharNum], 0
		call setCursorPosition
		jmp endOfFunc

	endKey: ;Go to the end of the line.
		mov [currentCharNum], 79
		call setCursorPosition
		jmp endOfFunc

	spaceKey: ;When we use space, we don't want to delete the next char.
		call incCharNum ;The delete key can be used for that.
		jmp endOfFunc

	saveKey:
		call getFilename
		call writeToTextFile
		jmp endOfFunc

	loadKey:
		call getFilename
		call readTextFile
		jmp endOfFunc

	endOfFunc:
		popa
		ret ;Handle all special char tests from the user. ;Handles all of the program's special chars, and toggles a flag appropriately.
endp handleSpecialChars

start:
    mov ax, @data
    mov ds, ax

	call showMenu
	call initMouse ;initializes mouse at the beginning of the page
	mov dh, TOP_OF_THE_PAGE
	mov [currentLineNum], dh
	mov [currentCharNum], 0

	printCharLoop:

		mov [specialCharPressed], 0 ;This variable is a flag, indicating whether a special char was pressed.
		call setCursorPosition
		call getChar
		call handleSpecialChars ; This function will turn the "specialCharPressed" flag on if it was activated.

		cmp [specialCharPressed], 1 ; If a special char was pressed, it was handled, so we can safely move and receive another char.
		je printCharLoop

		mov al, [charFromUser]
		mov [charToPrint], al ;Because we need to print it, move to the correct var.
		call writeAsciiCharAtCursor

		call incCharNum

		jmp printCharLoop


exit:
	mov ax, 2
	int 10h
    mov ax, 4c00h
    int 21h

END start
