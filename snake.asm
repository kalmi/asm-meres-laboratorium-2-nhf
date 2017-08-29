#define SIMULATION 1          ; KONSTANSOK:
                              ;   A pálya ...
.equ width = 20               ;     magassága
.equ height = 4               ;     szélessége.


                              ; REGISZTERKIOSZTÁS:
                              ;
                              ;   Ideiglenes változók:
.def temp1 = r21              ;     Ideiglenes változó (valamint az LCD API param1-je)
.def temp2 = r22              ;     Ideiglenes változó (valamint az LCD API param2-je)
.def temp = r21               ;   Megengedjük, hogy temp-ként hivatkozzunk a temp1-re.
                              ;
                              ;   Következõ lépés iránya:
.def dir_x = r16              ;     Merre halad a kígyó köv lépésnél a különbözõ tengelyeken.
.def dir_y = r17              ;     Mindössze ezt a két reg-et állítjuk irányállító
                              ;     gombnyomásnál. Kettes komplemensben tároljuk.
                              ;     Lehetséges értékek: +1, 0, -1
                              ;
.def collected = r18          ;    A már összeszedett kaják száma. Ez jelenik meg a LED-eken.
                              ;
                              ;
.def turn = r19               ;    Kígyóléptetés kérés. TimerIT állítja 1-be. MAIN_LOOP 0-ba.
.def random = r20             ;    Randgen-léptetés kérés. TimerIT állítja 1-be. MAIN_LOOP 0-ba.
                              ;
                              ;
.def food_x = r5              ;    A jelenleg a pályán lévõ kaja x koordinátája.
.def food_y = r6              ;    A jelenleg a pályán lévõ kaja y koordinátája.
                              ;
;r21 és r22 már foglalt       ;
                              ;
.def collision = r23          ;    A CHECK_*_COLLISION hívások ezt a reg-et állítják.
                              ;
                              ;    Randomság:
.def random_x = r24           ;    A Timer2-vel karbantartott random koordináta.
.def random_y = r25           ;    A Timer2-vel karbantartott random koordináta.
                              ;    Itt egyelõre a randomság annyiban nyilvánul meg, hogy
                              ;    számolnak...

                              ;    Az igazi randomságot a user adja a gombnyomásokkal:
.def random_x_at_btn = r1     ;      Gombnyomáskor a random_x-bõl
.def random_y_at_btn = r2     ;      és random_y-ból mintavételezett(átmásolt) érték.
                              ;    Ezekbe a változókba konstans nem lehet írni!
                              ;
                              ;
.def gameover = r26           ;  Meghaltunk-e.
                              ;
; Y reg                       ;  A Y reg-t (r29:r28) ideiglenes 16 bites tárolóként használjuk.
; YL = r28                    ;
; YH = r29                    ;
                              ;
; Z reg                       ;  A Z reg-ben (r31:r30) tároljuk a kígyó farkának memóriacímét.
; ZL = r30                    ;
; ZH = r31                    ;



.cseg                         ; Code segment kezdete
.org $0000                    ;
                              ;
                              ; Reset&Interrupt vektorok:
jmp RESET                     ;   Reset Handler
jmp DUMMY_IT                  ;   Ext. INT0 Handler
jmp DUMMY_IT                  ;   Ext. INT1 Handler
jmp DUMMY_IT                  ;   Ext. INT2 Handler
jmp DUMMY_IT                  ;   Ext. INT3 Handler
jmp RIGHT_IT                  ;   Ext. INT4 Handler (INT gomb)
jmp LEFT_IT                   ;   Ext. INT5 Handler (BT0)
jmp UP_IT                     ;   Ext. INT6 Handler (BT1)
jmp DOWN_IT                   ;   Ext. INT7 Handler (BT2)
jmp DUMMY_IT                  ;   Timer2 Compare Match Handler
jmp DUMMY_IT                  ;   Timer2 Overflow Handler
jmp DUMMY_IT                  ;   Timer1 Capture Event Handler
jmp TIMER_IT                  ;   Timer1 Compare Match A Handler
jmp DUMMY_IT                  ;   Timer1 Compare Match B Handler
jmp DUMMY_IT                  ;   Timer1 Overflow Handler
jmp RANDOMGEN_TIMER_IT        ;   Timer0 Compare Match Handler
jmp DUMMY_IT                  ;   Timer0 Overflow Handler
jmp DUMMY_IT                  ;   SPI Transfer Complete Handler
jmp DUMMY_IT                  ;   USART0 RX Complete Handler
jmp DUMMY_IT                  ;   USART0 Data Register Empty Hanlder
jmp DUMMY_IT                  ;   USART0 TX Complete Handler
jmp DUMMY_IT                  ;   ADC Conversion Complete Handler
jmp DUMMY_IT                  ;   EEPROM Ready Hanlder
jmp DUMMY_IT                  ;   Analog Comparator Handler
jmp DUMMY_IT                  ;   Timer1 Compare Match C Handler
jmp DUMMY_IT                  ;   Timer3 Capture Event Handler
jmp DUMMY_IT                  ;   Timer3 Compare Match A Handler
jmp DUMMY_IT                  ;   Timer3 Compare Match B Handler
jmp DUMMY_IT                  ;   Timer3 Compare Match C Handler
jmp DUMMY_IT                  ;   Timer3 Overflow Handler
jmp DUMMY_IT                  ;   USART1 RX Complete Handler
jmp DUMMY_IT                  ;   USART1 Data Register Empty Hanlder
jmp DUMMY_IT                  ;   USART1 TX Complete Handler
jmp DUMMY_IT                  ;   Two-wire Serial Interface Handler
jmp DUMMY_IT                  ;   Store Program Memory Ready Handler
                              ;
.org $0046                    ; (jmp darabszám)*(jmp utasításhossz) == 0x46
                              ; 35*2 == 70 == 0x46
                              ; Ez az utasítás talán azért jó, mert kiderülne
                              ; fordításidõben, ha eggyel több jmp van.
                              ;
                              ;
                              ; A DUMMY_IT tájékoztat minket a nem lekezelt IT-krõl.
DUMMY_IT:                     ;   A következõ mintázatot jeleníti meg az LED ilyen esetben:
    ldi r16,   0xFF           ;     *-
    out DDRC,  r16            ;     -*
    ldi r16,   0xA5           ;     *-
    out PORTC, r16            ;     -*
DUMMY_LOOP:                   ;   Ezután pedig beragasztja magát egy végtelen ciklusba.
    rjmp DUMMY_LOOP           ;   Fontos megjegyezni, hogy mivel megszakítás kezelõ rutinban
                              ;   vagyunk, ezért jelenleg le van tiltva új IT fogadása, és így
                              ;   ezt a végtelen ciklust nem tudja semmi megszakítani.
                              ;
                              ;
.org $004B;                   ; Gondolom a RESET vektornak fix helye van, és ez az. (?)
jmp RESET                     ;

                              ; INCLUDE-OLT FÁJLOK:
.include "m128def.inc"        ;       - Def fájl az ATmega128-hoz
                              ;         Ez adja a "SRAM_START"-ot például.
.include "lcd.inc"            ;       - LCD AVR assembly API
.include "delay.inc"          ;   - DELAY* fgv-k. Egyes LCD parancsok használata után szükséges.
                              ;


RESET:                        ; RESET: Stack Pointer beállítása:
    ldi temp, LOW(RAMEND)     ;
    out SPL, temp             ;
    ldi temp, HIGH(RAMEND)    ;
    out SPH, temp             ;
                              ;
M_INIT:                       ; M_INIT: Inicializálás...
    ldi temp, 0xFF            ; Beállítjuk a C portot kimenetként (LED-ek).
    out DDRC, temp            ;
                              ;
    ldi temp, 0x00            ; Beállítjuk az E portot bemenetként (gombok).
    out DDRE, temp            ;
                              ;
    sbi  DDRB, 5              ; LCD backlight ON
                              ;
                              ;
                              ; TIMER1:
                              ; 1 mp-re TIMER1 beállítása: A mikrokontroller 11.0592 MHz-es órajelét 1024-gyel elõosztva, 10800 Hz-en fog mûködni a számláló. Ez még mindig túl gyors, ezért tovább kell osztani, de a 16 bites Timer/Counter periféria miatt ezt már megtehetjük hardveresen is, OCR1AH:OCR1AL 16 byte-jába írva egy megfelelõ osztási (komparálási) értéket.)
#if SIMULATION
    .equ const = 108
#else // !SIMULATION
    .equ const = 10800
#endif

    ldi temp, 0b00000000      ;
    out TCCR1A, temp          ;   CTC(Clear on Timer Compare) mód
    ldi temp, 0b00001111      ;     és 1024 elõosztás bekapcsolása.
#if SIMULATION
    ldi temp, 0b00001101      ; Szimuláció esetén gyorsítunk egy kicsit a dolgokon.
#endif

    out TCCR1B, temp          ;

    ldi temp, HIGH(const)     ;
    out OCR1AH, temp          ;   A 16 bites OCR(Output Compare Flag) reg. közül

    ldi temp, LOW(const)      ;    az OCRA-t választjuk.
    out OCR1AL, temp          ;

    ldi temp, 0               ;   Nullázzuk a 16 bites számlálót.
    out TCNT1H, temp          ;   (Õ az, amit a számláló növelget
    out TCNT1L, temp          ;    minden x == 0(mod 1024) után.)
                              ;
                              ;
                              ; TIMER0:
                              ; beállítása a randomszám generáláshoz:
                              ;
    ldi temp, 0b00001111      ;   TCCR0: CTC mód, 1024-es elõosztó
    ;           0.00....      ;   FOC=0 COM=00 (kimenet tiltva)
    ;           .0..1...      ;   WGM=10 (CTC mód)
    ;           .....111      ;   CS0=111 (CLK/1024)
#if SIMULATION
    ldi temp, 0b00001101      ; Szimuláció esetén gyorsítunk egy kicsit a dolgokon.
#endif
    out TCCR0, temp           ;
                              ;
    ldi temp, 35              ;   A komparálandó érték (0107 a lehetséges tartomány. 107 esetén kapnánk 100Hz idõzítést. Legyen mondjuk 300Hz...)
    out OCR0, temp            ;
                              ;
                              ;
                              ; MINDKÉT TIMERHEZ:
    ldi temp, 0b00010010      ;   Megszakítást kérünk, ha TCNT == OCR mindkét Timer esetén.
    out TIMSK, temp           ;

    call LCD_INIT             ; LCD_INIT-et kötelezõ meghívni az LCD használata elõtt.

    ldi temp, 0b00100000      ;
    out   PORTB, temp         ; LCD háttérvilágítás bekapcsolása
    rcall DELAY100MS          ; Elõírt várakozás az elõzõ parancs után.


                              ; Játéklogika regiszterek alaphelyzetbe:
                              ;
    ldi gameover, 0           ; Élve kezdünk.
                              ; (Ebben a játékban az a poén, hogy nem lehet nyerni.
                              ;  Még soha senki nem élte túl.)
                              ;
    LDI random_x, 10          ; A randomsághoz a számlálok alap állapotát 0-ra állítjuk.
    LDI random_y, 1           ;
    call SAMPLE_RANDOMNESS
                              ;   Alapból jobbra haladunk, tehát
    ldi dir_x, 1              ;     x-tengely mentén +1-et
    ldi dir_y, 0              ;     és y-tengely mentén 0-et fogunk mozogni lépésnél.

    ldi temp, -1              ;
    mov food_x, temp          ;    Kezdetben nincs kaja a pályán, mert a kaja elhelyezést
    mov food_y, temp          ;    majd a a NEW_FODD olja meg a kígyó pályára helyezése után.
                              ;
    ldi collected, 0          ;    Kezdetben még egyetlen kaját se szedtünk össze.
    CALL SET_LEDS             ;      Ezt jelenítsük is meg a LED-eken.

    ldi random, 0             ;
    ldi turn, 0               ;

                              ;
                              ;
                              ; A kígyó kiinduló állapota:
                              ;
                              ;     012345...
                              ;     --------------------
                              ;   0|                    |
                              ;   1| XXX                | (és jobbra indul)
                              ;   2|                    |
                              ;   3|                    |
                              ;     --------------------
                              ;
                              ; Ez a memóriában:
                              ;  ---------
                              ; |  fej_x  | <- SRAM_START
                              ; |---------|
                              ; |  fej_y  | <- SRAM_START+1
                              ; |---------|
                              ; | elem1_x | <- SRAM_START+2
                              ; |---------|
                              ; | elem1_y | <- SRAM_START+3
                              ; |---------|
                              ; | elem2_x | <- SRAM_START+4 / INITIAL_TAIL (és a Z, ami
                              ; |---------|             mindig a farokelemre x koordjára mutat)
                              ; | elem2_y | <- SRAM_START+5 / INITIAL_TAIL+1 (és Z+1)
                              ; |---------|
                              ; |   ...   |
                              ;
                              ;
    .equ INITIAL_LENGTH = 3   ; A kígyónk kezdetben 3 egységbõl áll.
                              ;   Kiszámoljuk a farka kezdeti memóriacímét fordítási idõben:
    .equ INITIAL_TAIL = SRAM_START+(INITIAL_LENGTH-1)*2
                              ;   Majd betöltjük a Z 16 bites regbe:
    ldi ZH, HIGH(INITIAL_TAIL)
    ldi ZL, LOW(INITIAL_TAIL)
                              ;
                              ; Kígyó testrészeinek beállítása a memóriában az ábra szerint:
                              ;
    ldi temp, 3               ;   A fej x koordinátája:
    sts SRAM_START, temp      ;     x=3 (mivel 0-indexelésû, ezért ez a negyedik oszlop)
                              ;
    ldi temp, 1               ;     y=1 (0-indexelés továbbra is...)
    sts SRAM_START+1, temp    ;
                              ;
                              ;
    ldi temp, 2               ;   A második testrész koordinátái:
    sts SRAM_START+2, temp    ;     x=2 (0-indexelésû)
                              ;
    ldi temp, 1               ;     y=1 (0-indexelésû)
    sts SRAM_START+3, temp    ;
                              ;
                              ;
    ldi temp, 1               ;   A harmadik testrész koordinátái:
    sts SRAM_START+4, temp    ;     x=1 (0-indexelésû)
                              ;
    ldi temp, 1               ;     y=1 (0-indexelésû)
    sts SRAM_START+5, temp    ;

                              ; Ezen testrészek kirajzolása az LCD-re:
                              ;   Az LCD API 1-indexelésû sajnos a mi kódunkkal ellentétben.
    ldi temp1, 1              ;   <- bal oldali testrész x. (0-indexelésûen..) (temp1==param)
    ldi temp2, 1              ;   <- bal oldali testrész y. (0-indexelésûen..) (temp2==param2)
    call LCD_GOTOXY           ;   Kurzor pozícióba helyezése.
                              ;
    ldi temp1, 0xFF           ;   Blokk karakter kiválasztása. (temp1==param)
                              ;
    call LCD_PUTCHAR          ;   0-indexelésûen az (1,1)-re ír és jobbra lép
    call LCD_PUTCHAR          ;   0-indexelésûen az (2,1)-re ír és jobbra lép
    call LCD_PUTCHAR          ;   0-indexelésûen az (3,1)-re ír és jobbra lép
                              ;
    call LCD_CURSOR_OFF       ; Kikapcsolja a kurzos megjelenítését.

    call NEW_FOOD             ; Helyezzünk el ételt a pályán.

    ldi temp, 0b10101010      ; Az összes gombnál lenyomásra vagyunk kíváncsiak.
    out EICRB, temp           ;

    ldi temp, 0b11110000      ; INT4-7 megszakításának engedélyezése ELVILEG
    out EIMSK, temp           ;

    sei

MAIN_LOOP:
    CPI random, 1             ; ha itt van a véletlenszámgen léptetés ideje,
    BREQ RANDOM_TIME          ;   akkor hajrá

    CPI turn, 1               ; ha itt van a kígyó léptetés ideje,
    BREQ TURN_TIME            ;   akkor hajrá

    JMP MAIN_LOOP

RANDOM_TIME:
    cli
    call GET_RANDOM
    ldi random, 0
    sei
    JMP MAIN_LOOP

TURN_TIME:
    cli                       ; A tényleges ciklusmag alatt nem szeretnénk IT-ket.

    LDI turn, 0               ; lépésidõ nullázása
    LDI collision, 0          ; collision nullázása

    CALL CHECK_WALL_COLLISION
    CPI collision, 1          ; megnézzük van-e a mozgás után fal
    BREQ GAME_OVER            ; ha van, akkor game over

    CALL CHECK_SELF_COLLISION
    CPI collision, 1          ; testrészbe ütközés lesz-e
    BREQ GAME_OVER            ; ha igen, game over

    CALL CHECK_FOOD_COLLISION
    LDI temp, 1               ;
    CPSE collision, temp      ; van-e kaja?
    CALL MOVE                 ; ha igen, akkor CALL EAT
    LDI temp, 0               ;
    CPSE collision, temp      ;
    CALL EAT                  ; ha nincs, akkor CALL MOVE

    CALL SET_LEDS             ; pontszám kiirítása

    sei                       ; Újra jöhetnek IT-k,
    JMP MAIN_LOOP             ; mert kilépünk a tényleges ciklusmagból.



GAME_OVER:                    ; Innen nem térünk vissza, viszont
                              ;   a játék gombnyomás IT-re újrakezdõdik.
    ldi gameover, 1

    ldi temp, 0b00010000      ;
    out TIMSK, temp           ; Timerek letiltása.

    LDS temp1, SRAM_START     ; betöltjük a fej jelenlegi helyét
    LDS temp2, SRAM_START+1   ;

    call LCD_GOTOXY
    ldi temp1, 'X'            ;   Halottkígyófej karakter kiválasztása.
    call LCD_PUTCHAR          ;   Rajzolj!

    cli                       ; Minden IT letiltása,
    call DELAY1S              ;   hogy 1 mp-ig tartsuk meg ezt az állapotot.
    sei                       ; Majd engedélyezésük.
                              ; Ha bármelyik gombot megnyomták a letiltás alatt, akkor
                              ; itt most az ahhoz tartozó IT meg fogja hívni a
                              ; RESET_IF_GAME_OVER-t.

GAME_OVER_WAIT_FOR_RESET:
    jmp GAME_OVER_WAIT_FOR_RESET



EAT:                          ; Kígyó megnövelése a dir_* által megadott irányba,
                              ; és új kaja igénylése.
    push temp1
    push temp2

    inc collected             ; Yéy! Gyûjtöttünk kaját! Kajaszámláló növelése!
    call SHIFT_DA_SNAKE       ; Kígyó testrészeinek hátrébbcsúsztatása a memóriában.
    adiw Z, 2                 ; Vegyük be a hátrébbshiftelt farkat is a kígyóba.

    LDS temp1, SRAM_START+2   ; betöltjük a fej régi helyét, amit már
    LDS temp2, SRAM_START+2+1 ;  hátrébbshifteltünk 2-vel...

    add temp1, dir_x          ;   Új fel koordinátáinak kiszámolása:
    add temp2, dir_y          ;

                              ;   Új fej beírása mem-be a fej helyére:
    sts SRAM_START, temp1     ;     x
    sts SRAM_START+1, temp2   ;     y

    ; Új fel kirajzolása:
    call LCD_GOTOXY
    ldi temp1, 0xFF           ;   Blokk karakter kiválasztása. (temp1==param1)
    call LCD_PUTCHAR          ;   Rajzolj!

    call NEW_FOOD             ; Megettük a kaját => Kell új kaja.

    pop temp2
    pop temp1
    ret

MOVE:                         ; Kígyó mozgatása a dir_* által megadott irányba:

                              ; Olvassuk ki a farokelem koordinátáit:
    ld temp1, Z               ;   temp1 = farok_x
    ldd temp2, Z+1            ;   temp2 = farok_y
    CALL LCD_GOTOXY           ; Farok poz kiválasztása az LCD-n.
    ldi temp1, ' '            ;  SPACE-re fogjuk cserélni a farokelemet. (temp1==param1)
    call LCD_PUTCHAR          ; Farokelem felülcsapása az LCD-n.
                              ;
    call SHIFT_DA_SNAKE       ; Kígyó testrészeinek hátrébbcsúsztatása a memóriában.
                              ;
    LDS temp1, SRAM_START+2   ; betöltjük a fej régi helyét
    LDS temp2, SRAM_START+3   ;

                              ; Új fej beállítása memóriában:
    add temp1, dir_x          ;   Új fel koordinátáinak kiszámolása:
    add temp2, dir_y          ;

                              ;   Új fej beírása a fej helyére:
    sts SRAM_START, temp1     ;     x
    sts SRAM_START+1, temp2   ;     y

                              ; Új fel kirajzolása:
    call LCD_GOTOXY
    ldi temp1, 0xFF           ;   Blokk karakter kiválasztása. (temp1==param1)
    call LCD_PUTCHAR          ;   Rajzolj!

    ret


SHIFT_DA_SNAKE:
    push temp1
    push temp2
    push YL
    push YH
                              ; A "SHIFTELÉS":
                              ; A következõkben helyet csinálunk a memóriában az új fejnek,
                              ; és a régi testrészek koordinátáit pedig toljuk eggyel hátrébb:
    movw Y, Z                 ; Kimásoljuk a Y regpárba a Z-t, mert a
                              ;   Y-öt fogjuk csökkenteni, ahogy haladunk végig a
                              ;   kígyón a shifteléssel, és abban a pillanatban hagyjuk abba
                              ;   a shiftelést, mikor 0-ba fordult.

SHIFTER_LOOP:                 ; Loop, ami végigmegy a kígyón, és helyet csinál az új fejnek:
                              ;   kígyóelem_x[i+1]=kígyóelem_x[i]
                              ;   kígyóelem_y[i+1]=kígyóelem_y[i]

                              ; Aktuális elem koordinátájának betöltése temp reg-ekbe:
    ld temp1, Y               ;   temp1 = elem_x
    ldd temp2, Y +1           ;   temp2 = elem_y

    std Y+2, temp1            ; Aktuális elem koordinátájának beírása a
    std Y+3, temp2            ; mellette lévõ farokfelé lévõ elembe.
                              ;
                              ; Egy "shiftelés" letudva.
                              ;  Van-e még? Ha nem jutottunk el a Y-el az SRAM_START-ig,
                              ;  akkor igen, és continue:
    cpi YL, LOW(SRAM_START)
    brne SHIFTER_CONTINUE
    cpi YH, HIGH(SRAM_START)
    brne SHIFTER_CONTINUE

    jmp MOVE_SHIFTER_END      ; ha egyeztek a címek, akkor végeztünk

SHIFTER_CONTINUE:
                              ; Ciklusváltozó léptetése:
    sbiw Y, 2                 ;   A következõ fejfelé lévõ elem koordinátájára mutassunk.
    jmp SHIFTER_LOOP          ; Continue

MOVE_SHIFTER_END:             ; <- LOOP vége.
    pop YH
    pop YL
    pop temp2
    pop temp1
    ret


TIMER_IT:                     ; Eltelt 1 mp...
    ldi turn, 1               ; Ez majd jól kizökkenti a main-t a busyloop-ból.
    reti                      ;


RANDOMGEN_TIMER_IT:           ; Eltelt x ns...
    ldi random, 1             ; Ez majd jól kizökkenti a main-t a busyloop-ból.
    reti                      ;

GET_RANDOM:                   ; Ezt hívjuk a MAIN_LOOP-ból.
    push temp1
    push YL
    push YH
    COUNT_AGAIN:
    INC random_x              ; növeljük az x értékét
    CALL CHECK_X              ; megnézzük, elértük-e már a pálya szélét

CHECK_PLACE:
    MOVW Y, Z
    CHECK_IT:
    LD temp1, Y
    CP random_x, temp1        ; megnézzük, hogy az x koordináta egyezik-e
    BRNE NEXT                 ; ha nem, akkor megyünk a következõ kígyó testrészre
    LDD temp1, Y+1            ; ha egyezik, megnézzük az x koordinátát is
    CP random_y, temp1
    BRNE NEXT                 ; ha nem, akkor megyünk a következõ kígyó testrészre
    BREQ COUNT_AGAIN          ; ha mindkettõ egyezik, akkor a következõ "LCD-elemet" fogjuk megvizsgálni

NEXT:
    CPI YL, LOW(SRAM_START)
    BRNE GET_NEW_PIECE
    CPI YH, HIGH(SRAM_START)
    BRNE GET_NEW_PIECE        ; ha van még, testrész, akkor megyünk a következõre
    JMP END_IT

GET_NEW_PIECE:
    SBIW Y,2
    JMP CHECK_IT

END_IT:
    POP YH
    POP YL
    POP temp1
    RET

CHECK_X:
    LDI temp1, 20
    CPSE random_x, temp1      ; ha elérte a szélét nullázuk, különben visszatérünk
    RET
    LDI random_x,0
    INC random_y              ; ha nullázunk, akkor növeljük az y-t
    CALL CHECK_Y              ; és megnézzük, az elérte-e a szélét
    RET

CHECK_Y:
    LDI temp1, 4
    CPSE random_y, temp1
    RET
    LDI random_y,0            ; ha elérte nullázzuk, különben simán visszatérünk
    RET


CHECK_WALL_COLLISION:
    push temp1
    push temp2

    LDS temp1, SRAM_START
    LDS temp2, SRAM_START+1   ; fej koordinátáinak beállítása
    ADD temp1, dir_x          ; koordináták mozgatása a megfelelõ irányba
    ADD temp2, dir_y

    CPI temp1, -1             ; bal oldali fal ellenõrzés
    BREQ COLLISION_RETURN_1
    CPI temp2, -1             ; felsõ fal ellenõrzés
    BREQ COLLISION_RETURN_1

    CPI temp1, width          ; jobb oldal ellenõrzése
    BREQ COLLISION_RETURN_1
    CPI temp2, height         ; alsó oldal ellenõrzése
    BREQ COLLISION_RETURN_1
    JMP COLLISION_RETURN_0    ; ha egyik sem egyezik, visszatérés 0-val
                              ;ret az COLLISION_RETURN_0-ban és az COLLISION_RETURN_1-ben található

CHECK_FOOD_COLLISION:
    push temp1
    push temp2

    LDS temp1, SRAM_START     ; betöltjük a fej jelenlegi helyét
    LDS temp2, SRAM_START+1   ;

    ADD temp1, dir_x          ; kiszámoljuk fejet új helyét
    ADD temp2, dir_y          ;

    CP temp1, food_x          ; megnézzük van-e ott kaja
    BRNE COLLISION_RETURN_0   ; ha az x koordináta nem stimmel, akkor visszatérés 0-val
    CP temp2, food_Y          ; y koordináta stimmel?
    BRNE COLLISION_RETURN_0
    JMP COLLISION_RETURN_1    ; ha igen, akkor 1-el térünk vissza


CHECK_SELF_COLLISION:
    push temp1
    push temp2
    push YL
    push YH

    MOVW Y, Z
    SBIW Y,2                  ; rögtön megyünk a farok elõtti elemre
                              ;itt nem kell ellenõrizni, hogy van-e még elem, mert a farok elõtt kell lennie még 2 kígyórésznek

CHECK_SELF:
    LDS temp1, SRAM_START
    ADD temp1, dir_x
    LD temp2, Y
    CP temp1, temp2           ; x koordináta egyezik-e
    BRNE NEXT_ONE             ; ha nem, megyünk a köv darabra

    LDS temp1, SRAM_START+1
    ADD temp1, dir_y
    LDD temp2, Y+1
    CP temp1, temp2           ; ha igen, akkor csekkoljuk az y-nt
    BRNE NEXT_ONE             ; ha az y nem stimmel, akkor megyünk a köv darabra
    BREQ SELF_COLL_RETURN_1   ; ha az y is stimmel, ret 1-el

NEXT_ONE:
    CPI YL, LOW(SRAM_START)
    BRNE GET_NEW_SNAKE_PIECE
    CPI YH, HIGH(SRAM_START)
    BRNE GET_NEW_SNAKE_PIECE
    JMP SELF_COLL_RETURN_0    ; ha nem, akkor 0-val kilépünk

GET_NEW_SNAKE_PIECE:
    SBIW Y,2
    JMP CHECK_SELF

SELF_COLL_RETURN_0:
    pop YH
    pop YL
    jmp COLLISION_RETURN_0

SELF_COLL_RETURN_1:
    pop YH
    pop YL
    jmp COLLISION_RETURN_1

COLLISION_RETURN_0:
    LDI collision,0           ; visszatérés 0-val
    pop temp2
    pop temp1
    RET

COLLISION_RETURN_1:
    LDI collision,1           ; visszatérés 1-el
    pop temp2
    pop temp1
    RET


                              ; GOMB IT-k
LEFT_IT:
    ldi dir_x, -1
    ldi dir_y, 0
    call SAMPLE_RANDOMNESS
    call RESET_IF_GAME_OVER
    reti

RIGHT_IT:
    ldi dir_x, 1
    ldi dir_y, 0
    call SAMPLE_RANDOMNESS
    call RESET_IF_GAME_OVER
    reti

UP_IT:
    ldi dir_x, 0
    ldi dir_y, -1
    call SAMPLE_RANDOMNESS
    call RESET_IF_GAME_OVER
    reti

DOWN_IT:
    ldi dir_x, 0
    ldi dir_y, 1
    call SAMPLE_RANDOMNESS
    call RESET_IF_GAME_OVER
    reti

RESET_IF_GAME_OVER:
    ldi temp, 0
    cpse gameover, temp
    jmp RESET
    ret

SAMPLE_RANDOMNESS:
    MOV random_x_at_btn, random_x
    MOV random_y_at_btn, random_y
    ret

NEW_FOOD:
    push temp1
    push temp2

    call GET_RANDOM
    call SAMPLE_RANDOMNESS

    mov food_x, random_x_at_btn
    mov food_y, random_y_at_btn

    mov temp1, food_x
    mov temp2, food_y

    CALL LCD_GOTOXY           ; Új kaja poz kiválasztása az LCD-n,
    ldi temp1, '*'            ; és egy csillag berakása oda.
    call LCD_PUTCHAR          ;

    pop temp2
    pop temp1
    ret

SET_LEDS:
    OUT portc,collected       ;kiküldjük a ledre a begyûjtött kaják számát
    RET
