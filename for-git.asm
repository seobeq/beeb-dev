oswrch 	= &ffee
	osbyte 	= &fff4
	screen 	= &70
	tile 	= &72
	map 	= &74
	temp 	= &76
	store_a = &77
	count 	= &79
	xcoord 	= &80
	ycoord 	= &81
	width 	= &82
	height 	= &83
	wcount 	= &84
	loc 	= &85
	store 	= &87
	data 	= &89
	yreg 	= &8B
	table1 	= &8c
	xcoord1 = &8E
	ycoord1 = &8F
	cc 		= 28
	
	MACRO LOAD_TILE tile_name
	lda #tile_name mod 256
	sta tile
	lda #tile_name div 256
	sta tile+1
	jsr draw_shape
	rts
	ENDMACRO
	
	\\ this macro calls the one above with the calculated address
	MACRO SELECT_TILE
	FOR i, 0, cc
	cmp #i
	bne keep_going
	LOAD_TILE char_sprite_0+[&20*i]; base address (char_sprite_0) + offset of 32 bytes per character/tile
	.keep_going
	NEXT
	ENDMACRO
	
	org &2000
	.start
	\\ select mode 2
	lda #&16
	jsr oswrch
	lda #&02
	jsr oswrch
	
	\\ switch off the cursor
	{	
	ldx #&00
	.loop
	lda cursor_off,x
	jsr oswrch
	inx
	cpx #&09
	bne loop
	}  

	\\ change palette
	{	
	ldx #&00
	.loop
	lda palette_change,x
	jsr oswrch
	inx
	cpx #&14
	bne loop
	}  

	\\ store screen address in zero page
	lda #&00
	sta &70
	lda #&30
	sta &70+1

	\\ store map address
	lda #map_location mod 256
	sta map
	lda #map_location div 256
	sta map+1

	\\ load in char length
	lda #number_of_chars mod 256
	sta &90
	lda #number_of_chars div 256
	sta &90+1
	
	\\ clear temp
	lda #&00
	sta temp
	 
	\\ iterate through mapset data. (640 bytes)
	.read_mapset_data
	ldy #&00
	lda temp
	tay
	lda (map),y  
	sta store_a
	iny
	sty temp
	cpy #&00 
	beq increment_msb
	lda store_a
	jmp skippy

	.increment_msb
	inc map+1
	lda map+1	
	cmp #&80 ; &26
	{
	bne trick \\ so we can use the unconditional branch below
	jmp infinite_loop
	.trick
	}

	\\ switch case	
	.skippy
	
	\\ macro that selects correct tile address and places it in 'tile'
	SELECT_TILE 
	
	\\ draw tile to screen
	 .draw_shape  
	 {
	 ldy #&00
	 .loop
	 lda (tile),y \ tile
	 sta (&70),y
	 iny
	 cpy #&20
	 bne loop
	 }

	 \\ add 32 to screen address
	 lda &70
	 clc
	 adc #&20
	 sta &70
	 beq add_to_msb
	 jsr read_mapset_data

	\\ increment lsb
	 .add_to_msb
	 inc &70+1
	 lda &70+1
	 cmp #&80 \ have we got to &80?
	 beq infinite_loop
	 jsr read_mapset_data
	 .infinite_loop
	;jmp infinite_loop

	;*************************************
	; Draw sprite to screen 
	;*************************************
	.game_loop
	;jsr set_up_vdu_codes 
	jsr load_table_addresses 
	jsr set_coordinates
	jsr screeny
	.entry
	;jsr screen_refresh
	jsr draw_data
	.no_key_pressed
    jsr read_keyboard
	;jsr draw_data
	;jsr screen_refresh
	jmp entry
	;jsr read_keyboard
	
	;jmp entry
	;jmp game_loop

	;.entry
	.load_table_addresses
	lda #(shape1 mod 256)
	sta table1
	lda #(shape1 div 256) 
	sta table1+1
	rts

	.read_keyboard

	.check_right_key 
	ldx #&cd \\ move right (d key)
	jsr check_key
	bne check_left_key
	jsr reaction_right
	rts

	.check_left_key \\ move left (a key)
	ldx #&be
	jsr check_key
	bne check_up_key
	jsr reaction_left
	rts

	.check_up_key \\ move up key (w key)
	ldx #&de
	jsr check_key 
	bne check_down_key
	jsr reaction_up
	rts

	.check_down_key \\ down key (s key)
	ldx #&ae
	jsr check_key
	bne no_key_pressed
	jsr reaction_down
	rts
	jmp no_key_pressed
	rts

	.check_key
	lda #&81
	ldy #&ff
	jsr &fff4 
	cpy #&ff
	rts

	.reaction_right
	jsr screen_refresh
	jsr draw_data
	lda xcoord1
	cmp #&48
	beq edge_right
	clc
	adc #&01
	sta xcoord1
	.edge_right
	rts

	.reaction_left
	jsr screen_refresh
	jsr draw_data
	lda xcoord1
	cmp #&00
	beq edge_left
	sec
	sbc #&01
	sta xcoord1
	.edge_left
	rts

	.reaction_up
	jsr screen_refresh
	jsr draw_data
	lda ycoord1
	cmp #&05
	beq edge_top
	sec 
	sbc #&03
	sta ycoord1
	.edge_top 
	rts

	.reaction_down
	jsr screen_refresh
	jsr draw_data
	lda ycoord1
	cmp #&e0
	beq edge_bottom
	clc
	adc #&03
	sta ycoord1
	.edge_bottom
	rts

	\\ sprite starting position
	.set_coordinates
	lda #&22
	sta xcoord1
	lda #&50
	sta ycoord1
	rts

	.screeny
	lda table1
	sta data
	lda table1+1
	sta data+1
	rts

	.screen_refresh
	lda #&13
	jsr osbyte
	rts

	.draw_data
	ldx xcoord1
	ldy ycoord1

	.draw
	stx xcoord
	sty ycoord
	ldy #&00
	lda (data),y
	sta height
	iny
	lda (data),y
	sta width
	ldx #&02
	
	.newrow
	lda #&00
	sta yreg
	lda width
	sta wcount
	jsr calcaddress
	
	.newcolumn
	txa
	tay
	lda (data),y
	\ora (data),y
	\and (loc),y
	ldy yreg
	eor (loc),y 
	sta (loc),y  \\ *actual point of writing to screen*
	tya
	adc #&08
	sta yreg
	inx
	dec wcount
	bne newcolumn
	inc ycoord
	dec height
	bne newrow
	rts

	.calcaddress
	lda #&00
	sta store+1
	sta loc
	lda xcoord
	asl a
	asl a
	rol store+1
	asl a
	rol store+1
	sta store
	lda ycoord
	and #&f8
	lsr a
	lsr a
	sta loc+1
	lsr a
	lsr a
	ror loc
	adc loc+1
	tay
	lda ycoord
	and #&07
	adc loc
	adc store
	sta loc
	tya
	adc store+1
	adc #&30
	sta loc+1
	rts

	.shape1
	include  "robot_sprite.asm" ;"red_block.asm" ;"robot_sprite.asm"
	rts
	  
	INCLUDE "cool_char.asm" ;"green_tile.asm" 
	
	.palette_change
	equb &13,&03,&02,&00,&00,&00,&13,&07
	equb &06,&00,&00,&00
	equb &13,&04,&06,&00
	equb &00,&00 ;,&13,&06,&06,&00,&00,&00 
	
	
    .cursor_off
	equb &17,&00,&0a,&20,&00,&00,&00
	equb &00,&00,&00

	.map_location
	INCLUDE "cool_map.asm" \\ enter name of map.. \org &2200?

	.end
	save "love", start, end  \\ name for pling boot 
	