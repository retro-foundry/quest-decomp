; Quest $.QUEST1 byte-exact 6502 reconstruction.
;
; Two reference blocks follow the relocation notes below:
;   Deliberate modifications - how to enable the jet boots everywhere and how
;     to start the game in a chosen room, with the reasoning for each patch site.
;   Discovered data - the item, password, sign, terminal and per-room tables,
;     read out of the payload and cross-checked against play. Proved tables move
;     into named source blocks below as they are reconstructed;
;     analysis/room_map.md decodes the per-room tables into the map itself.
;
; Authority:
;   original/game/$.QUEST1
;   load  &1D00
;   exec  &5C11
;   size  &3F20
;
; The loader relocates loaded $2600-$5AFF to runtime $0E00-$42FF. Therefore
; loaded $2A5D-$2A83 below executes at runtime $125D-$1283, and loaded
; $34E4-$3568 executes at runtime $1CE4-$1D68. Loaded $4AC5-$4AD0
; executes at runtime $32C5-$32D0. Loaded $3F90-$3F96 executes at runtime
; $2790-$2796, loaded $3A37-$3A3A executes at runtime $2237-$223A, loaded
; $4099-$40A6 executes at runtime $2899-$28A6, and loaded $4AA7-$4ABE
; executes at runtime $32A7-$32BE. Loaded $3DC4-$3DDB executes at runtime
; $25C4-$25DB.
; The earlier loader segment maps loaded $24A0-$24A8 to runtime $0BA0-$0BA8.

; Deliberate modifications
;
; This file must assemble to the original bytes exactly, so it is never the
; place to change how the game plays. A change is a patch applied to the built
; payload by tools/reconstruction/apply_variant.py, from a definition in
; tools/reconstruction/variants/ that states the bytes it expects and is refused
; if they no longer match. What follows is where the two most-asked-for changes
; live and why they are where they are. Runtime addresses throughout.
;
; Jet boots in every room
;
;   The boots are enabled per room by $A6, jet_boots_enabled_this_room. The
;   control poller reads it at $2685 and, when it is zero, branches past BOTH
;   thrust polls, so neither INKEY -73 nor INKEY -105 is read and $0E never
;   gains upward velocity. The boots are inert in such a room, not weak.
;
;   draw_and_initialise_room clears $A6 at $1BAA as part of its per-room reset,
;   so every room starts with them off, and $167A writes 1 into it while one
;   particular cell is drawn. On screen that cell is a triangle symbol: rooms
;   showing one allow flight and rooms without one do not.
;
;   The change patches the reader, two bytes at $2685, LDA $A6 to LDA #$01.
;   Not the store at $1BAA: that store shares its LDA #$00 with ten others in
;   the same run, so retargeting it in place would set ten unrelated flags. A
;   is not read after the branch - $2689 loads X immediately - and LDA #$01
;   leaves Z clear, so the branch is never taken and nothing else shifts.
;
;   Variant: fly_in_every_room on its own, or --fly-everywhere on
;   make_start_room_variant.py to combine it with a starting room.
;
; Starting in a chosen room
;
;   Four separate pieces of state have to move together. Moving some of them
;   produces a game that misbehaves in ways easily mistaken for a corrupt room,
;   which is how each of these was found.
;
;   1. The room and its data pointer. initialise_new_game writes the room at
;      $0BD1, but set_room_data_pointer reaches the cells through the level base
;      at $72/$73, a copy of $70/$71, which the transitions maintain as the down
;      index times $78. Writing $8F alone leaves that stale and the room draws as
;      nonsense. $3200 is an unreachable developer warp that writes $8F, $90 and
;      $70/$71 together from four immediates before JMP $1206; the change
;      retargets its immediates, turns that jump into RTS and calls it.
;
;   2. Every store the call displaces. $0BD1 through $0BDE writes $90, $8F, $A0,
;      $70 and $71 from a single LDA #$00 at $0BD5. A patch that stops at $0BD8
;      leaves the last three running on whatever the call returned in A. Down 0
;      has a zero base high byte, so that fault is invisible in the opening row
;      and corrupts every other one.
;
;   3. A place the player can stand. The player is three character rows tall:
;      the movers write $18 to $41 and $290B reads one byte per scanline, so
;      twenty-four, and $2899 reaches the ground by adding $0780. Two clear rows
;      buries the player's bottom third in the floor, and the collision scan then
;      refuses to let them walk out of it. Nothing in the game stores a per-room
;      start point to copy: the edge transitions write only a horizontal and
;      inherit the height. tools/runtime_trace/find_start_point.py reads the
;      floor out of the room's drawn screen instead.
;
;   4. $2C, player_vertical_position. It is kept independently of the display
;      pointer, and $28B0 reads $2C - not the pointer - to decide the player has
;      reached the ceiling. A start point that moves the pointer and not $2C
;      leaves the game believing the player is elsewhere, and the room-above
;      transition can never fire however far they fly. The start point at $0C29
;      writes the pointer, $35 and $2C together, so all four fit one patch.
;
;   Rooms are named across then down: across is $90 and runs 0 to 7, down is
;   $8F and runs 0 to 9, and the game opens at $8F = 0, $90 = 1, which is room
;   1,0. tools/reconstruction/make_start_room_variant.py --room ACROSS,DOWN
;   generates the whole thing, with --item, --no-damage, --fly-everywhere and a
;   start point from find_start_point.py. --item takes an item code: see
;   Discovered data below for the twelve of them, of which
;   $32 is the access card.
;
; $0C29, $0C39, $167A, $2685 and $3200 are not reconstructed here yet, so those
; addresses are cited rather than shown. CONTINUE.md carries the same account
; with the trace counts behind it.

; Discovered data
;
; These tables were read out of the authority payload and, where noted,
; confirmed by play. Some now have named ORG blocks below; the remaining
; address notes are the starting points for further reconstruction. Runtime
; addresses throughout.
;
; The room grid is eight across and ten down
;
;   Across is $90 and down is $8F, and rooms are named across first, so the
;   game opens at 1,0 and the Music Room is 4,1. Eight across is not a guess:
;   $18AA is a table indexed by $90 and it is exactly eight bytes long, because
;   $18B2 is the next instruction's opcode. Ten down follows from the level
;   base moving by $78 per $8F. Moving right increments $90 and moving down
;   increments $8F, both measured from a session of known moves.
;   A room sign shows the level as down plus one, and the sector as a letter
;   from $90: a sign reading Sector F was at $90 = 5, so $90 = 4 is Sector E.
;
; Thirteen slot labels at $0B03: blank plus twelve item names
;
;   Slot label zero is blank. Item n is six characters at $0B09 + 6n,
;   hand-padded to sit in a six-wide display field, and there are twelve items
;   - the same twelve that collected_icon_count counts up to.
;
;     n   name      code     n   name      code
;     0   'key'      $28     6   'herrin'   $34
;     1   'key'      $2A     7   'mouse'    $36
;     2   'key'      $2C     8   'cheese'   $38
;     3   'salt'     $2E     9   'cross'    $3A
;     4   'worm'     $30    10   'eye'      $3C
;     5   'card'     $32    11   'bottle'   $3E
;
;   The code formula is fixed by two measured points, not inferred: a frame
;   captured with $2C in the first slot is labelled Key, which is entry 2, and
;   one with $32 is labelled card, which is entry 5. Three entries apart, six
;   codes apart, so the stride is two. Item slots are $0C and $0D, and
;   draw_two_item_slots uses a slot's value directly as a graphic index, so the
;   slot holds the code itself. Consumables such as power crystals never enter
;   a slot.
;
;   An obstruction cell names the item that answers it:
;
;     cell $28 wants item $2C, a key      ($29D3 then $29D7)
;     cell $21 wants item $34, a herring  ($2A00 then $2A04)
;     cell $24 wants item $3E, a bottle   ($2A1D then $2A28)
;
;   Those three pass the code as an immediate to
;   consume_matching_item_from_slots. The card, $32, is not among them, so
;   whatever it opens reaches that routine through one of the three sites that
;   computes the code instead: $2212, $29CC or $2C3C.
;
; Eight passwords, five letters each, in the 26 bytes at $1796
;
;   The bytes are SALLYNDAVIDIOTTERASEVENTER. $1789 prints five characters from
;   $1796,X, and $177A computes X as the password number times three, so the
;   passwords overlap and every multiple of three lands on a word. Twenty-six
;   bytes hold forty letters.
;
;     number  shown  offset  password  carried by
;       0       1       0     SALLY     across 3
;       1       2       3     LYNDA     across 5
;       2       3       6     DAVID     across 1
;       3       4       9     IDIOT     across 7
;       4       5      12     OTTER     across 6
;       5       6      15     ERASE     across 4
;       6       7      18     SEVEN     across 2
;       7       8      21     ENTER     across 0
;
;   $176A reads the column's password number from $18AA,X with X taken from
;   $90, adds $31 to print it, and records the collection with STA $91,X at
;   $1778. So the number shown is one higher than the number stored, and
;   $91 through $98 are the collected-password flags.
;
;   Confirmed by play: playing from across 4, the player collected "password
;   6". $18AA+4 holds 5, and 5 printed with $31 added is 6, which is ERASE.
;
;   The terminal's own text is at $2199: TERMINAL, PASSWORDS, ACCESS GRANTED,
;   ACTIVATED, DENIED and INVALID PASSWORD.
;
; Room-sign text at $17B0
;
;   Fifteen signs are sixteen bytes each, drawn eight characters by two rows.
;   Reading them names much of the map: the Music Room, a Level/Sector
;   template, Elephant House, Joke Shop, Teleport, The Armoury, Hydroponics,
;   two chemical signs, Time Warp, The Oracle, Optician, Chemical Supplies,
;   Ghost Maze and Chapel. A ten-byte PASSWORD prompt follows them.
;
; The per-room tables, and what each one turns out to hold
;
;   Several tables in the region from $0900 to $0AFA are indexed by the room.
;   A record's room is the packed pair
;   match_packed_record_against_references tests: byte 0's low
;   six bits are $8F, byte 1's low nibble is $90. analysis/room_map.md carries
;   the decoded contents room by room, alongside the player's account of the map and
;   marked for where the two disagree.
;
;   $09B0  room_appearance_table, eighty bytes at $8F * 8 + $90. Eighty rooms
;          for eight across by ten down. Grouping every room by the palette
;          nibble puts exactly two rooms in palette $B, and they are exactly the
;          two rooms reported to be real reactors; palette $A holds exactly one,
;          the room reported to look like a reactor without being one. So the
;          appearance byte alone separates the decoy from the genuine ones.
;
;   $0900  item_and_goal_record_table, twelve four-byte records. Eleven indices
;          line up with item_name_table and select graphic pair $28 + 2n.
;          Index 3 is special: in H8 it prints THE GOLDEN DRAGON, sets the
;          gameplay-loop exit flag, then draws pair $2E/$2F. That is the reported
;          goal rather than a placed salt item. Seven item rooms match the
;          reported pickup locations exactly, including all three keys. Two
;          records name down 10, outside the grid, matching items the account
;          says are produced by puzzles rather than found: the herring and mouse.
;
;   $0930  room_moving_object_record_table, sixteen five-byte records. A matching
;          record configures four positions for a caterpillar, fish, mouse or
;          lift. Its last three bytes are the display row and lower and upper
;          position limits. Fish and mouse records keep an existing nonzero
;          puzzle state at $63 rather than reinitialising it.
;
;   $0980  initial_item_and_goal_record_table, the 48-byte new-game image of
;          the mutable $0900 table. restore_item_and_goal_records copies the
;          whole range before room setup begins.
;
;   $0A00  room_enemy_record_table, twenty six-byte records for room-local
;          enemies. Every record resolves to one specific room; this updater
;          has no room-column transition path. The set contains
;          every room the account calls out for an enemy. So this is the table
;          the creatures come from.
;
;   $0A78  cross_room_robot_ghost_record_table, ten three-byte records
;          indexed by $8F alone. This one is per level, not per room, and
;          advance_cross_room_robot_ghost_value_and_display_pointer carries its objects
;          across room boundaries: at horizontal $4D the column increments and
;          the position resets to zero, at a negative position the column
;          decrements and the position becomes $4C, and the deltas reverse at
;          columns 0 and 7. The ordinary update path selects pointer offsets
;          $10/$12, which are the two small-bouncing-robot frames at $0B6F;
;          levels 8 and 9 use the alternate path and offsets $14/$16, the ghost
;          frames at $0B73. Thus only robots and ghosts use this cross-room
;          subsystem.
;
;   $0A96  lift_and_hazard_room_record_table, twenty five-byte records selecting
;          either the vertical-lift graphic or the damaging moth-shaped frames.
;          The lift update carries or pushes the player.
;          A room can appear twice, so it can hold two.
;
;   Twelve power crystals are reported and twelve is also the limit
;   collected_icon_count counts to, but no table of twelve crystal rooms has
;   been found. $0900 is twelve records and turned out to be the items, so
;   whatever places the crystals is still unlocated.
;
; The passwords the account and the payload disagree about
;
;   Five of the seven reported password locations match $18AA exactly. The two
;   that do not are settled by the image: neither GREEN nor EDITOR appears
;   anywhere in it, while IDIOT is at $179F and SEVEN at $17A8. Column 7 carries
;   IDIOT and column 2 carries SEVEN, and password 7 being the word SEVEN is
;   plainly deliberate.
;
;   Reading the reported room names as a column letter and a level digit also
;   makes every reported terminal number the column plus one, which the account
;   did not claim. A column's terminal number and its password number are
;   unrelated: column G holds terminal 7 and password 5.
;
; A disassembly trap in this area
;
;   print_inline_vdu_stream at $3256 prints bytes that follow its own call site,
;   reading them through its return address and replacing that address to skip
;   the zero-terminated data. Both callers, $1761 and $1782, are therefore
;   followed by bytes that are data, and a linear disassembly of $1761-$1795
;   mis-decodes because of it. The loop at $1791 branching back to $1789 is
;   what gives the real instruction boundaries away.

INCLUDE "source_bbc/memory_map.inc"

; PLAYER, CREATURE, ROBOT AND LIFT SPRITES
; =========================================
; Runtime $0400-$077F: 28 aligned 32-byte Mode 1 XOR sprite frames. The eight
; records at $0500-$05E0 are player graphics, while $06C0-$0760 is the six-
; record ghost set. xor_graphic_into_display proves the storage order: eight source
; scanlines, with the four Mode 1 bytes for scanline N at N+0, N+8, N+16 and
; N+24. Some callers double each source scanline to make a 16-pixel-high image.
; The names below describe the correctly decoded silhouettes. Where the image
; does not establish a species, the label deliberately names its visible form.
; Stage this data outside the loaded/runtime alias range. It is copied to its
; transport location only after all relocated routines have been assembled.
ORG &9000
.player_enemy_and_lift_xor_sprite_frames_source
.caterpillar_direction_frame_0
    EQUB &00, &00, &00, &00, &06, &6F, &6F, &06, &00, &00, &00, &06, &6F, &6F, &6F, &06
    EQUB &00, &00, &06, &6F, &7F, &7F, &6F, &06, &77, &88, &0E, &6F, &69, &0F, &08, &0E
.caterpillar_direction_frame_1
    EQUB &EE, &11, &07, &69, &6F, &0F, &01, &07, &00, &00, &06, &6F, &EF, &EF, &6F, &06
    EQUB &00, &00, &00, &06, &6F, &6F, &6F, &06, &00, &00, &00, &00, &06, &6F, &6F, &06
.caterpillar_direction_frame_2
    EQUB &00, &00, &00, &00, &07, &6F, &6F, &06, &00, &06, &6F, &6F, &6F, &0E, &00, &00
    EQUB &33, &06, &6F, &6F, &6F, &06, &00, &00, &88, &44, &0E, &69, &6F, &0F, &08, &0E
.caterpillar_direction_frame_3
    EQUB &11, &22, &07, &6F, &69, &0F, &01, &07, &CC, &06, &6F, &6F, &6F, &06, &00, &00
    EQUB &00, &06, &6F, &6F, &6F, &07, &00, &00, &00, &00, &00, &00, &0E, &6F, &6F, &06
.bat_wings_raised_frame
    EQUB &0C, &86, &C3, &61, &30, &10, &00, &00, &88, &44, &22, &0F, &6F, &87, &E3, &22
    EQUB &11, &22, &44, &0F, &6F, &1E, &4C, &44, &03, &16, &3C, &68, &C0, &80, &00, &00
.bat_wings_lowered_frame
    EQUB &00, &00, &00, &03, &34, &70, &00, &00, &22, &22, &22, &0F, &6F, &87, &23, &22
    EQUB &44, &44, &44, &0F, &6F, &1E, &4C, &44, &00, &00, &00, &0E, &E1, &F0, &00, &00
.moth_and_hazard_frame_0
    EQUB &02, &05, &00, &00, &33, &CC, &11, &EE, &00, &00, &68, &61, &CF, &03, &CD, &01
    EQUB &00, &00, &61, &68, &3F, &0C, &3B, &08, &04, &0A, &00, &00, &CC, &33, &88, &77
.moth_and_hazard_frame_1
    EQUB &03, &00, &00, &EE, &11, &CC, &33, &00, &08, &04, &60, &61, &CF, &03, &CD, &01
    EQUB &01, &02, &60, &68, &3F, &0C, &3B, &08, &0C, &00, &00, &77, &88, &33, &CC, &00
.player_upper_facing_right_frame
    EQUB &00, &00, &11, &11, &11, &11, &16, &78, &77, &F8, &F0, &C3, &C3, &C3, &6B, &A5
    EQUB &FF, &F1, &87, &FF, &0F, &0F, &0C, &87, &88, &00, &00, &88, &88, &08, &00, &00
.player_middle_facing_right_frame
    EQUB &9E, &F8, &F0, &F0, &F0, &70, &70, &00, &C3, &87, &C3, &87, &C3, &87, &C3, &07
    EQUB &08, &84, &08, &84, &48, &84, &48, &84, &00, &00, &00, &00, &00, &00, &00, &00
.player_lower_standing_frame
    EQUB &00, &00, &11, &11, &32, &32, &03, &03, &FA, &E8, &E4, &C0, &88, &80, &4E, &0E
    EQUB &E0, &EA, &71, &75, &31, &32, &03, &03, &00, &00, &00, &00, &00, &80, &4E, &0E
.player_upper_facing_left_frame
    EQUB &11, &00, &00, &11, &11, &01, &00, &00, &FF, &F8, &1E, &FF, &0F, &0F, &03, &1E
    EQUB &EE, &F1, &F0, &3C, &3C, &3C, &6D, &5A, &00, &00, &88, &88, &88, &88, &86, &E1
.player_middle_facing_left_frame
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &01, &12, &01, &12, &21, &12, &21, &12
    EQUB &B4, &1E, &3C, &1E, &3C, &1E, &3C, &0E, &97, &F1, &F0, &F0, &F0, &E0, &E0, &EE
.player_lower_wide_stride_frame
    EQUB &00, &00, &00, &00, &00, &10, &27, &07, &70, &75, &E8, &EA, &C8, &C4, &0C, &0C
    EQUB &F5, &71, &72, &30, &11, &10, &27, &07, &00, &00, &88, &88, &C4, &C4, &0C, &0C
.player_lower_step_left_frame
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &11, &10, &00, &00, &00, &00, &27, &07
    EQUB &F5, &FA, &E4, &EA, &E4, &EA, &0E, &0E, &00, &00, &00, &00, &00, &00, &00, &00
.player_lower_step_right_frame
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &FA, &F5, &72, &75, &72, &75, &07, &07
    EQUB &88, &80, &00, &00, &00, &00, &4E, &0E, &00, &00, &00, &00, &00, &00, &00, &00
.jellyfish_frame_1
    EQUB &00, &03, &07, &0F, &9F, &09, &99, &05, &0F, &0F, &0F, &0F, &22, &02, &22, &04
    EQUB &0F, &0F, &0F, &0F, &99, &09, &44, &04, &00, &0C, &0E, &0F, &2F, &02, &AA, &09
.jellyfish_frame_0
    EQUB &03, &07, &0F, &0F, &99, &04, &22, &02, &08, &0F, &0F, &0F, &33, &0A, &AA, &0A
    EQUB &01, &0F, &0F, &0F, &99, &0A, &AA, &0A, &0C, &0E, &0F, &0E, &22, &04, &88, &08
.small_bouncing_robot_frame_0
    EQUB &57, &57, &00, &30, &0F, &0F, &30, &00, &5F, &5F, &30, &F0, &FF, &FF, &F0, &30
    EQUB &5F, &5F, &C0, &F0, &0F, &0F, &F0, &C0, &4E, &4E, &00, &C0, &FF, &FF, &C0, &00
.small_bouncing_robot_frame_1
    EQUB &00, &00, &00, &30, &FF, &FF, &30, &00, &07, &07, &30, &F0, &0F, &0F, &F0, &30
    EQUB &0E, &0E, &C0, &F0, &FF, &FF, &F0, &C0, &00, &00, &00, &C0, &0F, &0F, &C0, &00
.mouse_facing_right_frame
    EQUB &11, &22, &44, &44, &44, &33, &00, &00, &00, &33, &77, &77, &FF, &FF, &EE, &77
    EQUB &00, &CC, &FF, &FF, &FF, &EE, &33, &00, &CC, &CC, &88, &4C, &FF, &00, &00, &88
.fish_facing_right_frame
    EQUB &08, &0C, &86, &0F, &4B, &86, &0C, &08, &01, &07, &0F, &0F, &0F, &0F, &07, &01
    EQUB &0E, &0F, &3C, &3C, &0F, &0C, &0F, &0E, &00, &08, &0C, &0E, &0F, &00, &0C, &00
.ghost_frame_0
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &10, &72, &74, &F0
    EQUB &30, &60, &40, &C0, &80, &80, &80, &00, &C0, &20, &00, &0A, &00, &00, &20, &40
.ghost_frame_1
    EQUB &00, &10, &10, &30, &30, &72, &74, &70, &F1, &F2, &F0, &F8, &F0, &A0, &F8, &F0
    EQUB &F2, &F0, &F4, &F0, &E0, &10, &F0, &F0, &FA, &E0, &C3, &01, &80, &80, &80, &80
.ghost_frame_2
    EQUB &60, &80, &10, &10, &00, &30, &70, &C0, &F0, &F0, &F0, &B0, &70, &F0, &E0, &D0
    EQUB &F0, &E0, &D0, &D0, &B0, &60, &60, &E0, &80, &80, &80, &00, &00, &00, &00, &00
.ghost_frame_3
    EQUB &70, &80, &00, &0A, &00, &00, &80, &40, &80, &C0, &60, &20, &30, &30, &30, &00
    EQUB &00, &00, &00, &00, &80, &E0, &C0, &F0, &00, &00, &00, &00, &00, &00, &00, &00
.ghost_frame_4
    EQUB &72, &3C, &38, &00, &00, &00, &00, &00, &FA, &F0, &F0, &70, &B0, &C0, &F0, &F0
    EQUB &D0, &E0, &F0, &F0, &D0, &30, &F0, &F0, &00, &00, &80, &00, &C0, &C0, &E0, &E0
.ghost_frame_5
    EQUB &10, &10, &10, &00, &00, &00, &00, &00, &F0, &B0, &F0, &B0, &D0, &60, &70, &30
    EQUB &60, &70, &D0, &E0, &F0, &F0, &70, &B0, &60, &10, &80, &C0, &00, &E0, &E0, &30
.player_enemy_and_lift_xor_sprite_frames_end
ASSERT player_enemy_and_lift_xor_sprite_frames_end-player_enemy_and_lift_xor_sprite_frames_source = &0380

; Runtime $0800-$087F: four aligned Mode 1-shaped records after the embedded
; map initializer. No pointer-table entry or committed runtime read selects
; these addresses, so their source labels identify them as unused originals.
ORG &9400
.inert_xor_sprite_frame_block_source
.inert_xor_sprite_frame_0
    EQUB &CC, &00, &00, &00, &00, &00, &00, &00, &C0, &C0, &C0, &C0, &04, &04, &04, &04
    EQUB &00, &00, &00, &64, &00, &00, &00, &FF, &00, &00, &00, &00, &00, &00, &00, &00
.inert_xor_sprite_frame_1
    EQUB &00, &00, &00, &05, &00, &00, &00, &FF, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &FF, &00, &00, &00, &00, &F0, &00, &0E
.inert_xor_sprite_frame_2
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
.inert_xor_sprite_frame_3
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &64, &06, &90, &64, &06, &90, &64, &06, &90, &64, &06, &00, &00, &00, &00, &90
.inert_xor_sprite_frame_block_end
ASSERT inert_xor_sprite_frame_block_end-inert_xor_sprite_frame_block_source = &0080

ORG room_cell_map_alignment
; Runtime $37CD-$37CF: three zero bytes aligning the 80-room cell map at $37D0.
.room_cell_map_alignment_source
    EQUB &00, &00, &00
.room_cell_map_alignment_source_end
ASSERT room_cell_map_alignment_source = room_cell_map_alignment
ASSERT room_cell_map_alignment_source_end = room_cell_map
COPYBLOCK room_cell_map_alignment_source, room_cell_map_alignment_source_end, &4FCD
CLEAR room_cell_map_alignment_source, room_cell_map_alignment_source_end

ORG room_cell_map
; Runtime $37D0-$3C7F: complete room-cell map. Each level occupies $78
; bytes: three row planes, each holding eight rooms of five cells.
.room_cell_map_source
; Level 0
.room_A0_row_0_cells
    EQUB &1B, &5D, &19, &1B, &1D
.room_B0_row_0_cells
    EQUB &E0, &D5, &C5, &D3, &D4
.room_C0_row_0_cells
    EQUB &02, &5D, &5D, &5D, &02
.room_D0_row_0_cells
    EQUB &1A, &13, &13, &13, &1A
.room_E0_row_0_cells
    EQUB &53, &53, &53, &53, &53
.room_F0_row_0_cells
    EQUB &38, &3F, &78, &3E, &38
.room_G0_row_0_cells
    EQUB &38, &00, &00, &00, &3A
.room_H0_row_0_cells
    EQUB &18, &45, &2C, &46, &19
.room_A0_row_1_cells
    EQUB &45, &3B, &46, &45, &02
.room_B0_row_1_cells
    EQUB &02, &59, &0D, &0D, &0D
.room_C0_row_1_cells
    EQUB &30, &00, &12, &12, &30
.room_D0_row_1_cells
    EQUB &30, &53, &53, &53, &30
.room_E0_row_1_cells
    EQUB &30, &13, &1F, &13, &13
.room_F0_row_1_cells
    EQUB &27, &78, &0D, &78, &27
.room_G0_row_1_cells
    EQUB &2D, &3E, &38, &38, &1A
.room_H0_row_1_cells
    EQUB &1A, &00, &00, &00, &46
.room_A0_row_2_cells
    EQUB &04, &17, &00, &06, &1A
.room_B0_row_2_cells
    EQUB &02, &05, &58, &1A, &59
.room_C0_row_2_cells
    EQUB &13, &06, &45, &00, &46
.room_D0_row_2_cells
    EQUB &45, &30, &30, &46, &02
.room_E0_row_2_cells
    EQUB &02, &34, &0F, &10, &05
.room_F0_row_2_cells
    EQUB &06, &32, &02, &32, &05
.room_G0_row_2_cells
    EQUB &12, &12, &12, &2C, &0C
.room_H0_row_2_cells
    EQUB &0C, &12, &12, &3A, &3F
; Level 1
.room_A1_row_0_cells
    EQUB &31, &0E, &00, &02, &4D
.room_B1_row_0_cells
    EQUB &30, &30, &06, &59, &38
.room_C1_row_0_cells
    EQUB &18, &59, &00, &00, &03
.room_D1_row_0_cells
    EQUB &05, &58, &02, &05, &58
.room_E1_row_0_cells
    EQUB &7E, &1E, &78, &7F, &1A
.room_F1_row_0_cells
    EQUB &05, &00, &00, &00, &00
.room_G1_row_0_cells
    EQUB &00, &12, &12, &06, &1A
.room_H1_row_0_cells
    EQUB &59, &52, &22, &3E, &7F
.room_A1_row_1_cells
    EQUB &31, &0E, &00, &02, &03
.room_B1_row_1_cells
    EQUB &02, &78, &4F, &06, &59
.room_C1_row_1_cells
    EQUB &13, &00, &06, &59, &06
.room_D1_row_1_cells
    EQUB &59, &34, &18, &02, &05
.room_E1_row_1_cells
    EQUB &06, &15, &15, &05, &02
.room_F1_row_1_cells
    EQUB &02, &05, &1F, &52, &05
.room_G1_row_1_cells
    EQUB &06, &45, &29, &46, &7E
.room_H1_row_1_cells
    EQUB &00, &00, &00, &3B, &3F
.room_A1_row_2_cells
    EQUB &31, &1A, &00, &04, &03
.room_B1_row_2_cells
    EQUB &02, &0F, &33, &59, &06
.room_C1_row_2_cells
    EQUB &10, &01, &02, &00, &06
.room_D1_row_2_cells
    EQUB &05, &58, &59, &33, &58
.room_E1_row_2_cells
    EQUB &0E, &53, &53, &0E, &02
.room_F1_row_2_cells
    EQUB &1A, &02, &05, &3D, &12
.room_G1_row_2_cells
    EQUB &4D, &3D, &3D, &3D, &31
.room_H1_row_2_cells
    EQUB &05, &56, &06, &02, &02
; Level 2
.room_A2_row_0_cells
    EQUB &04, &0E, &05, &00, &06
.room_B2_row_0_cells
    EQUB &02, &02, &59, &06, &59
.room_C2_row_0_cells
    EQUB &1F, &58, &02, &00, &00
.room_D2_row_0_cells
    EQUB &58, &05, &06, &59, &33
.room_E2_row_0_cells
    EQUB &38, &3F, &02, &59, &58
.room_F2_row_0_cells
    EQUB &1A, &45, &21, &46, &1A
.room_G2_row_0_cells
    EQUB &05, &30, &30, &30, &03
.room_H2_row_0_cells
    EQUB &02, &02, &59, &21, &58
.room_A2_row_1_cells
    EQUB &04, &0E, &31, &34, &1F
.room_B2_row_1_cells
    EQUB &13, &58, &31, &0E, &31
.room_C2_row_1_cells
    EQUB &05, &00, &00, &00, &03
.room_D2_row_1_cells
    EQUB &05, &58, &59, &06, &02
.room_E2_row_1_cells
    EQUB &02, &0B, &12, &38, &00
.room_F2_row_1_cells
    EQUB &4F, &4F, &4F, &4F, &4F
.room_G2_row_1_cells
    EQUB &58, &59, &58, &59, &12
.room_H2_row_1_cells
    EQUB &12, &02, &39, &02, &03
.room_A2_row_2_cells
    EQUB &04, &0C, &0D, &0C, &0C
.room_B2_row_2_cells
    EQUB &4D, &04, &53, &53, &0D
.room_C2_row_2_cells
    EQUB &0D, &32, &32, &0A, &32
.room_D2_row_2_cells
    EQUB &02, &05, &34, &0F, &39
.room_E2_row_2_cells
    EQUB &39, &53, &13, &30, &18
.room_F2_row_2_cells
    EQUB &19, &0F, &0F, &0F, &0F
.room_G2_row_2_cells
    EQUB &38, &18, &19, &06, &02
.room_H2_row_2_cells
    EQUB &1A, &30, &30, &4D, &06
; Level 3
.room_A3_row_0_cells
    EQUB &04, &02, &1A, &02, &02
.room_B3_row_0_cells
    EQUB &31, &04, &58, &02, &02
.room_C3_row_0_cells
    EQUB &59, &58, &02, &02, &4D
.room_D3_row_0_cells
    EQUB &0C, &1F, &17, &13, &00
.room_E3_row_0_cells
    EQUB &00, &BC, &8F, &BC, &8F
.room_F3_row_0_cells
    EQUB &13, &2A, &3B, &1F, &13
.room_G3_row_0_cells
    EQUB &1E, &00, &00, &58, &02
.room_H3_row_0_cells
    EQUB &02, &2D, &58, &05, &46
.room_A3_row_1_cells
    EQUB &04, &04, &12, &12, &12
.room_B3_row_1_cells
    EQUB &12, &1A, &04, &58, &02
.room_C3_row_1_cells
    EQUB &04, &00, &3B, &13, &03
.room_D3_row_1_cells
    EQUB &3E, &0F, &34, &0F, &10
.room_E3_row_1_cells
    EQUB &05, &8F, &BC, &8F, &12
.room_F3_row_1_cells
    EQUB &06, &02, &02, &02, &05
.room_G3_row_1_cells
    EQUB &06, &15, &15, &05, &02
.room_H3_row_1_cells
    EQUB &02, &73, &74, &58, &03
.room_A3_row_2_cells
    EQUB &04, &05, &74, &0D, &0D
.room_B3_row_2_cells
    EQUB &0C, &0C, &00, &05, &58
.room_C3_row_2_cells
    EQUB &05, &00, &45, &06, &10
.room_D3_row_2_cells
    EQUB &02, &02, &02, &02, &0C
.room_E3_row_2_cells
    EQUB &4D, &12, &18, &1A, &02
.room_F3_row_2_cells
    EQUB &0E, &26, &0E, &25, &0E
.room_G3_row_2_cells
    EQUB &02, &53, &53, &02, &02
.room_H3_row_2_cells
    EQUB &02, &02, &02, &38, &03
; Level 4
.room_A4_row_0_cells
    EQUB &31, &59, &1F, &13, &12
.room_B4_row_0_cells
    EQUB &12, &12, &06, &02, &05
.room_C4_row_0_cells
    EQUB &12, &06, &05, &13, &7F
.room_D4_row_0_cells
    EQUB &59, &13, &13, &13, &58
.room_E4_row_0_cells
    EQUB &05, &58, &02, &1F, &58
.room_F4_row_0_cells
    EQUB &59, &35, &78, &35, &58
.room_G4_row_0_cells
    EQUB &59, &3B, &1F, &00, &3B
.room_H4_row_0_cells
    EQUB &00, &78, &02, &17, &03
.room_A4_row_1_cells
    EQUB &31, &12, &0C, &13, &13
.room_B4_row_1_cells
    EQUB &52, &00, &00, &52, &00
.room_C4_row_1_cells
    EQUB &00, &13, &13, &06, &31
.room_D4_row_1_cells
    EQUB &2D, &7A, &00, &7A, &03
.room_E4_row_1_cells
    EQUB &02, &05, &58, &00, &39
.room_F4_row_1_cells
    EQUB &35, &75, &35, &75, &35
.room_G4_row_1_cells
    EQUB &06, &17, &00, &00, &17
.room_H4_row_1_cells
    EQUB &00, &06, &02, &00, &0A
.room_A4_row_2_cells
    EQUB &31, &02, &02, &10, &10
.room_B4_row_2_cells
    EQUB &32, &32, &32, &32, &32
.room_C4_row_2_cells
    EQUB &01, &01, &01, &02, &31
.room_D4_row_2_cells
    EQUB &19, &12, &02, &3A, &18
.room_E4_row_2_cells
    EQUB &02, &02, &19, &06, &02
.room_F4_row_2_cells
    EQUB &1A, &35, &75, &35, &1A
.room_G4_row_2_cells
    EQUB &02, &17, &38, &38, &17
.room_H4_row_2_cells
    EQUB &06, &02, &02, &3E, &46
; Level 5
.room_A5_row_0_cells
    EQUB &05, &0C, &73, &74, &0C
.room_B5_row_0_cells
    EQUB &0C, &13, &0E, &13, &13
.room_C5_row_0_cells
    EQUB &13, &53, &79, &1A, &03
.room_D5_row_0_cells
    EQUB &00, &18, &02, &19, &00
.room_E5_row_0_cells
    EQUB &3E, &37, &37, &38, &1F
.room_F5_row_0_cells
    EQUB &2D, &73, &18, &02, &02
.room_G5_row_0_cells
    EQUB &02, &02, &02, &02, &02
.room_H5_row_0_cells
    EQUB &59, &17, &58, &59, &03
.room_A5_row_1_cells
    EQUB &02, &02, &1A, &02, &02
.room_B5_row_1_cells
    EQUB &02, &00, &0E, &00, &10
.room_C5_row_1_cells
    EQUB &3E, &30, &53, &53, &3F
.room_D5_row_1_cells
    EQUB &18, &59, &20, &58, &19
.room_E5_row_1_cells
    EQUB &3E, &36, &38, &37, &7F
.room_F5_row_1_cells
    EQUB &05, &24, &02, &02, &59
.room_G5_row_1_cells
    EQUB &13, &13, &00, &00, &02
.room_H5_row_1_cells
    EQUB &06, &17, &03, &04, &0A
.room_A5_row_2_cells
    EQUB &04, &00, &00, &12, &0D
.room_B5_row_2_cells
    EQUB &0D, &12, &1A, &12, &30
.room_C5_row_2_cells
    EQUB &30, &0F, &30, &53, &39
.room_D5_row_2_cells
    EQUB &02, &39, &02, &39, &39
.room_E5_row_2_cells
    EQUB &39, &37, &38, &06, &02
.room_F5_row_2_cells
    EQUB &1A, &05, &02, &39, &02
.room_G5_row_2_cells
    EQUB &39, &39, &01, &01, &0E
.room_H5_row_2_cells
    EQUB &02, &33, &31, &31, &0E
; Level 6
.room_A6_row_0_cells
    EQUB &04, &00, &33, &02, &02
.room_B6_row_0_cells
    EQUB &59, &78, &78, &58, &02
.room_C6_row_0_cells
    EQUB &6E, &13, &13, &13, &39
.room_D6_row_0_cells
    EQUB &02, &37, &00, &00, &03
.room_E6_row_0_cells
    EQUB &1A, &05, &13, &30, &30
.room_F6_row_0_cells
    EQUB &30, &46, &1F, &13, &13
.room_G6_row_0_cells
    EQUB &21, &4F, &4F, &4F, &02
.room_H6_row_0_cells
    EQUB &06, &59, &06, &05, &58
.room_A6_row_1_cells
    EQUB &04, &34, &0C, &02, &12
.room_B6_row_1_cells
    EQUB &06, &32, &32, &05, &58
.room_C6_row_1_cells
    EQUB &04, &7A, &00, &7A, &03
.room_D6_row_1_cells
    EQUB &02, &2E, &00, &3B, &02
.room_E6_row_1_cells
    EQUB &59, &58, &2E, &0D, &58
.room_F6_row_1_cells
    EQUB &04, &06, &00, &06, &05
.room_G6_row_1_cells
    EQUB &12, &00, &00, &00, &0E
.room_H6_row_1_cells
    EQUB &58, &19, &58, &59, &18
.room_A6_row_2_cells
    EQUB &02, &02, &02, &02, &02
.room_B6_row_2_cells
    EQUB &45, &52, &1F, &46, &31
.room_C6_row_2_cells
    EQUB &19, &3A, &02, &3A, &18
.room_D6_row_2_cells
    EQUB &02, &02, &2E, &02, &02
.room_E6_row_2_cells
    EQUB &19, &2E, &0C, &0D, &18
.room_F6_row_2_cells
    EQUB &05, &03, &05, &00, &1A
.room_G6_row_2_cells
    EQUB &27, &32, &32, &32, &1A
.room_H6_row_2_cells
    EQUB &00, &58, &19, &18, &59
; Level 7
.room_A7_row_0_cells
    EQUB &59, &13, &13, &13, &0C
.room_B7_row_0_cells
    EQUB &0C, &46, &3B, &00, &06
.room_C7_row_0_cells
    EQUB &59, &2D, &00, &58, &2E
.room_D7_row_0_cells
    EQUB &00, &77, &77, &77, &58
.room_E7_row_0_cells
    EQUB &59, &00, &75, &1F, &58
.room_F7_row_0_cells
    EQUB &04, &06, &02, &05, &13
.room_G7_row_0_cells
    EQUB &13, &30, &30, &13, &1A
.room_H7_row_0_cells
    EQUB &14, &4D, &12, &12, &14
.room_A7_row_1_cells
    EQUB &04, &7A, &7A, &7A, &03
.room_B7_row_1_cells
    EQUB &02, &34, &46, &05, &03
.room_C7_row_1_cells
    EQUB &19, &87, &86, &38, &18
.room_D7_row_1_cells
    EQUB &19, &12, &37, &36, &18
.room_E7_row_1_cells
    EQUB &19, &38, &35, &00, &03
.room_F7_row_1_cells
    EQUB &05, &30, &4D, &02, &03
.room_G7_row_1_cells
    EQUB &10, &79, &74, &39, &02
.room_H7_row_1_cells
    EQUB &14, &12, &52, &14, &14
.room_A7_row_2_cells
    EQUB &19, &3A, &02, &3A, &18
.room_B7_row_2_cells
    EQUB &02, &02, &33, &00, &06
.room_C7_row_2_cells
    EQUB &02, &19, &38, &02, &0D
.room_D7_row_2_cells
    EQUB &0D, &0D, &12, &38, &39
.room_E7_row_2_cells
    EQUB &39, &39, &39, &39, &02
.room_F7_row_2_cells
    EQUB &02, &02, &05, &00, &06
.room_G7_row_2_cells
    EQUB &02, &39, &39, &73, &0C
.room_H7_row_2_cells
    EQUB &0C, &0C, &0D, &0C, &14
; Level 8
.room_A8_row_0_cells
    EQUB &B0, &B2, &A1, &B9, &0C
.room_B8_row_0_cells
    EQUB &30, &2B, &04, &37, &36
.room_C8_row_0_cells
    EQUB &36, &36, &36, &37, &36
.room_D8_row_0_cells
    EQUB &36, &1A, &7E, &38, &36
.room_E8_row_0_cells
    EQUB &36, &79, &1A, &38, &36
.room_F8_row_0_cells
    EQUB &36, &79, &00, &06, &02
.room_G8_row_0_cells
    EQUB &04, &13, &13, &13, &09
.room_H8_row_0_cells
    EQUB &00, &3A, &13, &13, &58
.room_A8_row_1_cells
    EQUB &59, &A1, &B4, &58, &02
.room_B8_row_1_cells
    EQUB &3E, &37, &31, &79, &36
.room_C8_row_1_cells
    EQUB &36, &36, &37, &36, &36
.room_D8_row_1_cells
    EQUB &36, &3F, &31, &79, &36
.room_E8_row_1_cells
    EQUB &36, &39, &39, &37, &36
.room_F8_row_1_cells
    EQUB &36, &38, &06, &02, &1A
.room_G8_row_1_cells
    EQUB &04, &7A, &7A, &1B, &1C
.room_H8_row_1_cells
    EQUB &05, &7A, &3D, &3D, &3D
.room_A8_row_2_cells
    EQUB &AE, &AF, &AF, &AE, &02
.room_B8_row_2_cells
    EQUB &1A, &00, &31, &3E, &36
.room_C8_row_2_cells
    EQUB &36, &1A, &38, &79, &36
.room_D8_row_2_cells
    EQUB &36, &39, &00, &36, &36
.room_E8_row_2_cells
    EQUB &36, &39, &03, &37, &36
.room_F8_row_2_cells
    EQUB &36, &39, &12, &0C, &12
.room_G8_row_2_cells
    EQUB &12, &56, &1B, &1C, &1C
.room_H8_row_2_cells
    EQUB &13, &13, &13, &13, &13
; Level 9
.room_A9_row_0_cells
    EQUB &18, &45, &46, &19, &00
.room_B9_row_0_cells
    EQUB &04, &37, &3E, &6D, &36
.room_C9_row_0_cells
    EQUB &36, &38, &58, &36, &36
.room_D9_row_0_cells
    EQUB &36, &36, &36, &37, &36
.room_E9_row_0_cells
    EQUB &36, &38, &36, &36, &36
.room_F9_row_0_cells
    EQUB &36, &79, &04, &1F, &04
.room_G9_row_0_cells
    EQUB &00, &00, &12, &02, &02
.room_H9_row_0_cells
    EQUB &E0, &D5, &C5, &D3, &D4
.room_A9_row_1_cells
    EQUB &59, &00, &28, &58, &19
.room_B9_row_1_cells
    EQUB &1A, &37, &36, &36, &36
.room_C9_row_1_cells
    EQUB &36, &36, &36, &38, &38
.room_D9_row_1_cells
    EQUB &38, &04, &38, &36, &1A
.room_E9_row_1_cells
    EQUB &02, &23, &3B, &23, &02
.room_F9_row_1_cells
    EQUB &02, &2E, &04, &04, &31
.room_G9_row_1_cells
    EQUB &10, &39, &12, &38, &03
.room_H9_row_1_cells
    EQUB &7E, &78, &7F, &78, &7F
.room_A9_row_2_cells
    EQUB &1A, &16, &05, &53, &30
.room_B9_row_2_cells
    EQUB &30, &02, &02, &3E, &36
.room_C9_row_2_cells
    EQUB &36, &36, &36, &36, &36
.room_D9_row_2_cells
    EQUB &36, &36, &36, &36, &38
.room_E9_row_2_cells
    EQUB &38, &06, &1A, &05, &02
.room_F9_row_2_cells
    EQUB &02, &38, &38, &3E, &3F
.room_G9_row_2_cells
    EQUB &02, &3D, &12, &3D, &06
.room_H9_row_2_cells
    EQUB &3E, &38, &3F, &38, &3F
.room_cell_map_source_end
ASSERT room_cell_map_source = room_cell_map
ASSERT room_cell_map_source_end = initial_mode1_display_image
COPYBLOCK room_cell_map_source, room_cell_map_source_end, &4FD0
CLEAR room_cell_map_source, room_cell_map_source_end

ORG initial_mode1_display_image
; Runtime $3C80-$417F / loaded $5480-$597F: initial 1,280-byte Mode 1
; display image before the loader entry at loaded $5980. It occupies the
; first $500 bytes of the active screen window and is overwritten by drawing.
.initial_mode1_display_image_source
    EQUB &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &EE, &EE, &EE, &EE, &EE, &EE, &EE
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &30, &30, &30, &30, &30, &30, &30, &F0, &88, &88, &88, &88, &88, &88, &88
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &EE, &EE, &EE, &EE, &EE, &EE, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &FC, &FC, &FC, &FC, &FC, &FC, &F0, &F0, &F3, &F3, &F3, &F3, &F3, &F3, &F3
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &76, &76, &76, &76, &76, &76, &76, &F0, &80, &80, &80, &80, &80, &80, &80
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &77, &77, &77, &77, &77, &77, &77, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &76, &76, &76, &76, &76, &76, &76, &F0, &80, &80, &80, &80, &80, &80, &80
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00
    EQUB &F0, &77, &77, &77, &77, &77, &77, &77, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0
    EQUB &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &FF, &FF, &EF, &8F, &0F, &F0
    EQUB &F0, &F0, &00, &00, &00, &0F, &0F, &F0, &F0, &F0, &00, &00, &00, &0F, &0F, &F0
    EQUB &F0, &F0, &70, &70, &70, &78, &78, &F0, &F0, &F0, &FF, &FF, &EF, &8F, &0F, &F0
    EQUB &F0, &F0, &00, &00, &00, &0F, &0F, &F0, &F0, &F0, &00, &00, &00, &0F, &0F, &F0
    EQUB &F0, &F0, &F1, &F1, &F1, &F1, &E1, &F0, &F0, &F0, &EE, &EE, &CE, &0F, &0F, &F0
    EQUB &F0, &F0, &00, &00, &00, &0F, &0F, &F0, &F0, &F0, &00, &00, &00, &0F, &0F, &F0
    EQUB &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &EE, &EE, &EE, &EE, &EE, &EE, &EE, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &10, &10, &10, &10, &10, &10, &10, &F0
    EQUB &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &EE, &EE, &EE, &EE, &EE, &EE, &EE, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &00, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &87, &84, &84, &87, &84, &87, &F0, &F0, &04, &04, &06, &06, &05, &04, &F0
    EQUB &F0, &0B, &0A, &0A, &0B, &0A, &0B, &F0, &F0, &0B, &02, &02, &0B, &02, &0A, &F0
    EQUB &F0, &0C, &05, &05, &0D, &09, &0C, &F0, &F0, &0E, &00, &00, &06, &02, &0E, &F0
    EQUB &F0, &08, &08, &05, &02, &02, &02, &F0, &F0, &38, &38, &30, &30, &30, &30, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &00, &00, &00, &00, &00, &00, &F0, &F0, &00, &00, &00, &00, &00, &00, &F0
    EQUB &F0, &77, &77, &77, &77, &77, &77, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0, &F0
.initial_mode1_display_image_source_end
ASSERT initial_mode1_display_image_source = initial_mode1_display_image
ASSERT initial_mode1_display_image_source_end = &4180
COPYBLOCK initial_mode1_display_image_source, initial_mode1_display_image_source_end, &5480
CLEAR initial_mode1_display_image_source, initial_mode1_display_image_source_end



; Assemble reconstructed routines at their relocated runtime addresses. This
; makes absolute symbols and cross-routine references resolve exactly as the
; executing 6502 sees them. COPYBLOCK places the resulting bytes back into the
; loaded $.QUEST1 transport image.
ORG irq1v_handler

; The installed IRQ1V handler. It changes the Video ULA
; palette twice per frame and passes every interrupt down the chain.
; On a System VIA vertical sync interrupt it arms User VIA timer 2 with $10E0
; so that timer expires part-way down the frame, then writes the twelve
; palette entries for the upper part of the display.
; On the resulting User VIA timer 2 interrupt it clears the flag by writing the
; timer-2 mask back to the flag register, spins a short fixed delay so the
; change lands on a stable raster position, and writes four more entries based
; on lower_screen_palette_base. When alternate_palette_selector is nonzero it
; instead writes sixteen entries as four selector groups.
; Every path restores X and the MOS accumulator save at $FC and leaves through
; the chained IRQ1V vector at $0380, so other interrupt sources are unaffected.
.irq1v_handler_source
    LDA mos_irq_accumulator_save
    PHA
    TXA
    PHA
    LDA SYSTEM_VIA_INTERRUPT_FLAGS
    AND #SYSTEM_VIA_VSYNC_INTERRUPT_MASK
    CMP #SYSTEM_VIA_VSYNC_INTERRUPT_MASK
    BNE check_user_via_timer2
    LDA #RASTER_TIMER2_COUNTER_LOW
    STA USER_VIA_TIMER2_COUNTER_LOW
    LDA #RASTER_TIMER2_COUNTER_HIGH
    STA USER_VIA_TIMER2_COUNTER_HIGH
    JSR write_twelve_video_ula_palette_entries

.check_user_via_timer2
    LDA USER_VIA_INTERRUPT_FLAGS
    AND #USER_VIA_TIMER2_INTERRUPT_MASK
    CMP #USER_VIA_TIMER2_INTERRUPT_MASK
    BNE restore_and_chain_to_previous_irq1v
    STA USER_VIA_INTERRUPT_FLAGS
    LDA alternate_palette_selector
    BNE write_sixteen_entry_palette_set
    LDX #RASTER_STABILISE_DELAY_ITERATIONS

.await_stable_raster_position
    DEX
    BNE await_stable_raster_position
    LDA lower_screen_palette_base
    ORA #VIDEO_ULA_PALETTE_GROUP_1
    JSR write_four_video_ula_palette_entries

.restore_and_chain_to_previous_irq1v
    PLA
    TAX
    PLA
    STA mos_irq_accumulator_save
    JMP (chained_irq1v_vector)

.write_sixteen_entry_palette_set
    LDA #VIDEO_ULA_PALETTE_GROUP_0
    PHA
    JSR write_four_video_ula_palette_entries
    PLA
    PHA
    ORA #VIDEO_ULA_PALETTE_GROUP_1
    JSR write_four_video_ula_palette_entries
    PLA
    PHA
    ORA #VIDEO_ULA_PALETTE_GROUP_2
    JSR write_four_video_ula_palette_entries
    PLA
    ORA #VIDEO_ULA_PALETTE_GROUP_3
    JSR write_four_video_ula_palette_entries
    JMP restore_and_chain_to_previous_irq1v
.irq1v_handler_source_end

ASSERT irq1v_handler_source = irq1v_handler
ASSERT irq1v_handler_source_end = &03E0
COPYBLOCK irq1v_handler_source, irq1v_handler_source_end, &5BB3

; Runtime $0383-$03DF overlaps the loaded transport image. Release it after
; copying its bytes to loaded $5BB3-$5C0F.
CLEAR irq1v_handler_source, irq1v_handler_source_end


ORG draw_record_row_pairs

; Draw X rows of two graphic records each, stepping down one
; Mode 1 character row between rows.
; Each iteration draws record_row_graphic_index twice through the blitter vector, which
; advances the display pointer by $10 per call, then adds $0260. The two
; additions come to $0280, which is one character row, so the constant is the
; row stride less the two tiles already drawn.
; $2496 presets the record to zero, drawing blank rows; $249A is the entry for
; callers that have already chosen a record.
.draw_record_row_pairs_source
    LDA #GRAPHIC_RECORD_BLANK
    STA record_row_graphic_index

.draw_next_record_row
    LDA record_row_graphic_index
    JSR enter_copy_16_byte_graphic_to_display
    JSR enter_copy_16_byte_graphic_to_display
    CLC
    LDA display_pointer_low
    ADC #LO(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA display_pointer_low
    LDA display_pointer_high
    ADC #HI(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA display_pointer_high
    DEX
    BNE draw_next_record_row
    RTS
.draw_record_row_pairs_source_end

ASSERT draw_record_row_pairs_source = draw_record_row_pairs
ASSERT draw_record_row_pairs_source_end = &24B3
COPYBLOCK draw_record_row_pairs_source, draw_record_row_pairs_source_end, &3C96

; Runtime $2496-$24B2 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3C96-$3CB2.
CLEAR draw_record_row_pairs_source, draw_record_row_pairs_source_end


ORG remove_last_icon_and_stamp_room_cell

; Erase the icon that power_crystals_remaining no longer needs, then
; mark the room cell the count was spent on.
; The icon address is status_icon_row_base plus the count times sixteen, so the icons sit
; sixteen bytes apart in one row near the top of the display; record 3 from the
; alternate bank is drawn over the one at the current count, which erases it.
; The display pointer is then restored from saved_effect_display_pointer and
; ROOM_CELL_COLUMN_PATTERNS is written through it.
; There is no terminator: the block runs off its last instruction into
; draw_record_row_pairs, which blanks a two-by-two block of records over that
; cell with X still holding ROOM_CELL_STAMP_CHARACTER_ROWS. The room therefore
; keeps the named column-pattern marker and the status row loses one icon.
.remove_last_icon_and_stamp_room_cell_source
    LDX #ROOM_CELL_STAMP_CHARACTER_ROWS
    LDA power_crystals_remaining ; scaled below by STATUS_ICON_BYTE_STRIDE
    ASL A
    ASL A
    ASL A
    ASL A
    CLC
    ADC #LO(status_icon_row_base)
    STA display_pointer_low
    LDA #&00
    ADC #HI(status_icon_row_base)
    STA display_pointer_high
    JSR draw_record_three_from_alternate_bank
    LDA saved_effect_display_pointer_low
    STA display_pointer_low
    LDA saved_effect_display_pointer_high
    STA display_pointer_high
    LDA #ROOM_CELL_COLUMN_PATTERNS
    JSR store_byte_through_saved_pointer
.remove_last_icon_and_stamp_room_cell_source_end

ASSERT remove_last_icon_and_stamp_room_cell_source = remove_last_icon_and_stamp_room_cell
ASSERT remove_last_icon_and_stamp_room_cell_source_end = &2496
COPYBLOCK remove_last_icon_and_stamp_room_cell_source, remove_last_icon_and_stamp_room_cell_source_end, &3C71

; Runtime $2471-$2495 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3C71-$3C95.
CLEAR remove_last_icon_and_stamp_room_cell_source, remove_last_icon_and_stamp_room_cell_source_end


ORG evntv_read_interval_timer

; Read the MOS interval timer into interval_timer_block
; and keep the returned low byte in game_clock_tick_pending.
; Everything is preserved across the call, the processor status included, which
; is what an installed event handler has to do: EVNTV is reached from an
; interrupt and must leave the interrupted code undisturbed.
.evntv_read_interval_timer_source
    PHP
    PHA
    TYA
    PHA
    TXA
    PHA
    LDX #LO(interval_timer_block)
    LDY #HI(interval_timer_block)
    LDA #OSWORD_READ_INTERVAL_TIMER
    JSR OSWORD
    STA game_clock_tick_pending
    PLA
    TAX
    PLA
    TAY
    PLA
    PLP
    RTS
.evntv_read_interval_timer_source_end

ASSERT evntv_read_interval_timer_source = evntv_read_interval_timer
ASSERT evntv_read_interval_timer_source_end = &0B9B
COPYBLOCK evntv_read_interval_timer_source, evntv_read_interval_timer_source_end, &2483

; Runtime $0B83-$0B9A overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2483-$249A.
CLEAR evntv_read_interval_timer_source, evntv_read_interval_timer_source_end


ORG main_gameplay_loop

; Complete the twelve-icon status row, initialise the gameplay presentation,
; then run one clock/input/update/difference cycle repeatedly until
; main_loop_exit_flag becomes nonzero. A positive exit performs the death/ending
; transition. When the last-chance chord has enabled reincarnation and the
; sequence count is below REINCARNATION_SEQUENCE_LIMIT, an inline
; REINCARNATE prompt polls Y/N: Y re-enters gameplay setup, while N continues
; polling. Otherwise an inline GAME OVER message is printed, the interval
; target is set to GAME_OVER_WAIT_TICK_TARGET, and the OSWORD wait is entered.
; A negative exit (the Golden Dragon path) skips directly to the crystal/XOR
; completion dispatcher. Its return path waits for Space to be released.
.main_gameplay_loop_source
    LDA #GAMEPLAY_INITIAL_COLLECTED_ICON_COUNT
    STA collected_icon_count
    LDX #GAMEPLAY_INITIAL_ICON_ADD_COUNT
.add_remaining_initial_icons
    JSR enter_add_collected_icon
    DEX
    BNE add_remaining_initial_icons

.initialise_gameplay_display_and_entities
    JSR enter_draw_and_initialise_room
    JSR initialise_cross_room_robot_ghost_from_record
    JSR redraw_carried_item_slots
    JSR xor_draw_player_two_parts
    JSR run_energy_bar_sweep
    JSR evntv_read_interval_timer

.main_gameplay_tick
    JSR write_system_clock_via_osword_02
    JSR poll_controls_and_apply_gameplay_actions
    JSR run_game_tick_with_player_contact_flag_cleared
    JSR apply_player_energy_delta_to_budget
    LDA main_loop_exit_flag
    BEQ main_gameplay_tick
    BMI completed_game_exit
    LDA #MAIN_LOOP_EXIT_RUNNING
    STA main_loop_exit_flag
    INC main_loop_sequence_counter
    JSR walk_player_toward_target_position
    JSR play_descending_flash_sequence
    LDA reincarnation_cheat_flag
    BEQ show_game_over
    LDA main_loop_sequence_counter
    CMP #REINCARNATION_SEQUENCE_LIMIT
    BPL show_game_over
    JSR print_inline_vdu_stream

.reincarnate_prompt_vdu_stream
    EQUB VDU_TEXT_AT, REINCARNATE_PROMPT_CURSOR_X, REINCARNATE_PROMPT_CURSOR_Y
    EQUS "REINCARNATE? (Y or N)"
    EQUB INLINE_VDU_STREAM_END

.poll_reincarnation_choice
    LDX #INKEY_Y                       ; BBC Y key, OSBYTE $81 negative key number
    JSR osbyte_81_inkey
    BCS initialise_gameplay_display_and_entities
    LDX #INKEY_N                       ; BBC N key, OSBYTE $81 negative key number
    JSR osbyte_81_inkey
    BCC poll_reincarnation_choice

.show_game_over
    JSR print_inline_vdu_stream
.game_over_vdu_stream
    EQUB VDU_TEXT_AT, GAME_OVER_CURSOR_X, GAME_OVER_CURSOR_Y
    EQUS "GAME OVER"
    EQUB INLINE_VDU_STREAM_END
    JSR write_system_clock_via_osword_02
    LDA #GAME_OVER_WAIT_TICK_TARGET
    STA bounded_tick_target_value
    JMP wait_osword_block_value_reaches_target

.completed_game_exit
    JSR dispatch_completed_crystal_message
.wait_for_completion_key_release
    LDX #INKEY_SPACE
    JSR osbyte_81_inkey
    BCC wait_for_completion_key_release
    RTS
.main_gameplay_loop_source_end

ASSERT main_gameplay_loop_source = main_gameplay_loop
ASSERT reincarnate_prompt_vdu_stream = &2578
ASSERT poll_reincarnation_choice = &2591
ASSERT game_over_vdu_stream = &25A2
ASSERT completed_game_exit = &25B9
ASSERT main_gameplay_loop_source_end = apply_player_energy_delta_to_budget
COPYBLOCK main_gameplay_loop_source, main_gameplay_loop_source_end, &3D2F
CLEAR main_gameplay_loop_source, main_gameplay_loop_source_end


ORG add_collected_icon

; Add one icon to the collected row, unless it is already
; full.
; collected_icon_count is capped at POWER_CRYSTAL_TOTAL and returns unchanged
; when full. Otherwise the count is incremented and a collected-icon record is
; drawn at collected_icon_row_base plus the count times STATUS_ICON_BYTE_STRIDE,
; with the primary graphic bank restored afterwards.
; This is the counterpart of remove_last_icon_and_stamp_room_cell, which spends
; from status_icon_row_base using power_crystals_remaining while this routine
; counts upward in collected_icon_row_base. The display therefore carries two
; twelve-icon rows, one being spent and one being collected.
;
; Twelve is also the number of power crystals the player's account lists, which
; is consistent with this being the crystal counter, but no table of twelve
; crystal rooms has been found: item_and_goal_record_table contains twelve
; records but holds the items instead. So what places the crystals is still unlocated and this
; routine is named for the mechanism rather than the object.
; discard_two_stack_bytes_and_return is also the startup room sequence's exit:
; its two pulls discard that routine's saved X and Y values before returning to
; initialise_new_game.
.add_collected_icon_source
    LDA collected_icon_count
    CMP #POWER_CRYSTAL_TOTAL
    BEQ collected_icon_row_full
    INC collected_icon_count
    LDA collected_icon_count
    ASL A
    ASL A
    ASL A
    ASL A
    ADC #LO(collected_icon_row_base)
    STA display_pointer_low
    LDA #HI(collected_icon_row_base)
    ADC #HI(STATUS_ICON_BYTE_STRIDE) ; propagate the scaled low-byte addition's carry
    STA display_pointer_high
    LDA #GRAPHIC_BANK_STATUS_OFFSET
    STA graphic_source_base_pointer_offset
    LDA #STATUS_GRAPHIC_COLLECTED_ICON
    JSR enter_copy_16_byte_graphic_to_display
    LDA #GRAPHIC_BANK_PRIMARY_OFFSET
    STA graphic_source_base_pointer_offset
    RTS

.discard_two_stack_bytes_and_return
    PLA
    PLA

.collected_icon_row_full
    RTS
.add_collected_icon_source_end

ASSERT add_collected_icon_source = add_collected_icon
ASSERT add_collected_icon_source_end = &0C6E
COPYBLOCK add_collected_icon_source, add_collected_icon_source_end, &2543

; Runtime $0C43-$0C6D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2543-$256D.
CLEAR add_collected_icon_source, add_collected_icon_source_end


ORG process_player_cell_interactions

; Tail target of both horizontal movement routines. Test
; the display pattern under/around the newly positioned player and dispatch the
; corresponding crystal, carried-item, redraw, damage, or room-effect action.
; Pattern $11 collects a power crystal. Pattern $25 consumes the item selected
; by room drawing in $A4, with item $2C accepted as a substitute when that
; selector is $28, then replaces the saved cell. Pattern $06 runs the $20B3
; action and redraws the player.
; Pattern $16 uses current interaction types $20/$21 to require item $36/$34;
; success starts effect $11 and clears $63. Pattern $1A with type $24 first
; applies player damage, then a nonzero item-$3E activation flag permits item
; $3E to be consumed and effect $3C to start. The $20 branch and both final
; successful-effect paths remain static-only; all other control flow is traced.
.process_player_cell_interactions_source
    LDA #GRAPHIC_PATTERNED_SLOPE_B
    JSR display_pattern_test
    BCC test_pattern_25_interaction
    JSR collect_power_crystal_and_refill_energy

.test_pattern_25_interaction
    LDA #GRAPHIC_UNIFORM_PATTERN
    JSR display_pattern_test
    BCC test_pattern_06_interaction
    LDA saved_interaction_item_code
    JSR consume_matching_item_from_slots
    BCS replace_consumed_interaction_cell
    LDA saved_interaction_item_code
    CMP #ITEM_CODE_KEY_1
    BNE test_pattern_06_interaction
    LDA #ITEM_CODE_KEY_3
    JSR consume_matching_item_from_slots
    BCC test_pattern_06_interaction

.replace_consumed_interaction_cell
    JSR replace_saved_cell_then_play_sound

.test_pattern_06_interaction
    LDA #GRAPHIC_SMALL_MARKER
    JSR display_pattern_test
    BCC test_pattern_16_interaction
    JSR enter_run_terminal_interaction
    JSR xor_draw_player_two_parts

.test_pattern_16_interaction
    LDA #GRAPHIC_SOLID_FILL
    JSR display_pattern_test
    BCC test_pattern_1a_interaction
    LDA room_interaction_code
    CMP #ROOM_CELL_ELEPHANT_HOUSE_SIGN
    BNE test_pattern_16_type_21
    LDA #ITEM_CODE_MOUSE
    JMP consume_pattern_16_required_item

.test_pattern_16_type_21
    CMP #ROOM_CELL_JOKE_SHOP_SIGN
    BNE test_pattern_1a_interaction
    LDA #ITEM_CODE_HERRING

.consume_pattern_16_required_item
    JSR consume_matching_item_from_slots
    BCC test_pattern_1a_interaction
    LDA #&11
    JSR start_saved_display_block_shift_effect
    LDA #&00
    STA room_moving_object_puzzle_state

.test_pattern_1a_interaction
    LDA #GRAPHIC_DIAGONAL_SLOPE_A
    JSR display_pattern_test
    BCC player_cell_interactions_rts
    LDA room_interaction_code
    CMP #ROOM_CELL_HYDROPONICS_SIGN
    BNE player_cell_interactions_rts
    JSR apply_player_damage_and_redraw_energy
    LDA special_item_3e_activation_flag
    BEQ player_cell_interactions_rts
    LDA #ITEM_CODE_BOTTLE
    JSR consume_matching_item_from_slots
    BCC player_cell_interactions_rts
    LDA #&3C
    JSR start_saved_display_block_shift_effect

.player_cell_interactions_rts
    RTS
.process_player_cell_interactions_source_end

ASSERT process_player_cell_interactions_source = process_player_cell_interactions
ASSERT process_player_cell_interactions_source_end = check_player_relative_display_pattern_15
COPYBLOCK process_player_cell_interactions_source, process_player_cell_interactions_source_end, &41B9
CLEAR process_player_cell_interactions_source, process_player_cell_interactions_source_end


ORG display_action_jump_table

; Six vectors into the display routines, giving callers a
; stable entry for each regardless of where the target moves.
; The last two entries are five bytes rather than three: they adjust the
; reference value at $90 by one, downwards then upwards, before dispatching to
; the same target as the third vector. So the table encodes three plain
; transfers and two that carry a side effect.
; The table ends at $1215. What follows is the runtime variable block, not more
; vectors: $121E, $121F, $1221, $1222, $1224 and $1225 are all read as data
; elsewhere in this source.
.display_action_jump_table_source
    JMP set_display_pointer_from_grid_position

.enter_retreat_secondary_reference_and_pointer
    JMP retreat_secondary_reference_and_pointer

    JMP draw_and_initialise_room

.enter_advance_secondary_reference_and_pointer
    JMP advance_secondary_reference_and_pointer

.decrement_reference_then_draw_and_initialise_room
    DEC reference_pair_primary_value
    JMP draw_and_initialise_room

.increment_reference_then_draw_and_initialise_room
    INC reference_pair_primary_value
    JMP draw_and_initialise_room
.display_action_jump_table_source_end

ASSERT display_action_jump_table_source = display_action_jump_table
ASSERT display_action_jump_table_source_end = &1216
COPYBLOCK display_action_jump_table_source, display_action_jump_table_source_end, &2A00

; Runtime $1200-$1215 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2A00-$2A15.
CLEAR display_action_jump_table_source, display_action_jump_table_source_end


ORG room_moving_object_graphic_state

; Mutable room-render and entity setup state. The initial
; image is all zero. $121D-$1220 is written as an indexed four-byte state set;
; the middle two bytes are also the proved lower/upper selector limits. The
; remaining fields are populated from room records before their render/update
; consumers run. Keeping each byte explicit documents the intentional overlap
; and prevents these variables being mistaken for 6502 instructions.
.room_render_state_source
    EQUB &00                         ; room-moving-object selector state, slot 0
    EQUB &00                         ; $121E lower selector limit / element 1
    EQUB &00                         ; $121F upper selector limit / element 2
    EQUB &00                         ; $1220 room-moving-object room selector / element 3
    EQUB &00                         ; $1221 active enemy species
    EQUB &00                         ; $1222 active enemy last even slot
    EQUB &00                         ; $1223 room-moving-object even-slot loop limit
    EQUB &00                         ; $1224 graphic source base pointer offset
    EQUB &00                         ; $1225 complete current room cell
.room_render_state_source_end

ASSERT room_render_state_source = room_moving_object_graphic_state
ASSERT room_render_state_source_end = enter_copy_16_byte_graphic_to_display
COPYBLOCK room_render_state_source, room_render_state_source_end, &2A1D
CLEAR room_render_state_source, room_render_state_source_end


ORG &1216

; Six unreachable zero alignment bytes and one NOP byte
; separate the display-action vectors from the mutable room-render state. No
; committed static reference or trace treats this span as executable.
.display_action_state_alignment_source
    SKIP 6
    EQUB &EA
.display_action_state_alignment_source_end

ASSERT display_action_state_alignment_source = &1216
ASSERT display_action_state_alignment_source_end = room_moving_object_graphic_state
COPYBLOCK display_action_state_alignment_source, display_action_state_alignment_source_end, &2A16
CLEAR display_action_state_alignment_source, display_action_state_alignment_source_end


ORG display_pattern_test

; Test whether the display under the current pointer matches
; a graphic record, returning carry set only if every sampled byte agrees.
; The record index in A uses the common sixteen-byte graphic-record scale and
; graphic_pattern_sample_base. Four bytes are compared at offsets 0, 8, 2 and
; 10: each pair is one Mode 1 cell column apart, and the row correction turns
; the post-pair offset sixteen into the second-row offset two.
; The first mismatch returns carry clear immediately, so a full match costs four
; comparisons and a failure usually costs one, which is why the entry runs 2,659
; times but the match path only 8.
.display_pattern_test_source
    STA graphic_pattern_record_offset_low
    LDA #GRAPHIC_RECORD_FIRST_BYTE_INDEX
    STA graphic_pattern_record_offset_high
    LDX #GRAPHIC_RECORD_INDEX_SHIFT

.shift_pattern_index_to_record_offset
    ASL graphic_pattern_record_offset_low
    ROL graphic_pattern_record_offset_high
    DEX
    BNE shift_pattern_index_to_record_offset
    CLC
    LDA #LO(graphic_pattern_sample_base)
    ADC graphic_pattern_record_offset_low
    STA graphic_source_pointer_low
    LDA #HI(graphic_pattern_sample_base)
    ADC graphic_pattern_record_offset_high
    STA graphic_source_pointer_high
    LDY #DISPLAY_PATTERN_FIRST_SAMPLE_OFFSET

.compare_next_sample_pair
    LDX #DISPLAY_PATTERN_SAMPLE_PAIR_COUNT

.compare_current_pattern_sample
    LDA (display_pointer_low),Y
    CMP (graphic_source_pointer_low),Y
    BEQ step_to_next_sample
    CLC
    RTS

.step_to_next_sample
    TYA
    CLC
    ADC #MODE1_CELL_COLUMN_BYTES
    TAY
    DEX
    BNE compare_current_pattern_sample
    TYA
    SEC
    SBC #DISPLAY_PATTERN_NEXT_ROW_CORRECTION
    TAY
    CPY #DISPLAY_PATTERN_SECOND_ROW_OFFSET
    BEQ compare_next_sample_pair
    SEC
    RTS
.display_pattern_test_source_end

ASSERT display_pattern_test_source = display_pattern_test
ASSERT display_pattern_test_source_end = &2A89
COPYBLOCK display_pattern_test_source, display_pattern_test_source_end, &424E

; Runtime $2A4E-$2A88 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $424E-$4288.
CLEAR display_pattern_test_source, display_pattern_test_source_end


ORG store_byte_and_advance_source_pointer

; Write A through graphic_source_pointer indexed by Y, then advance that pointer
; by one Mode 1 character cell, carrying into the high
; byte only on wrap. X is decremented so a caller can use it as a count.
; The pointer is named for its renderer role; here it is the destination.
.store_byte_and_advance_source_pointer_source
    STA (graphic_source_pointer_low),Y
    CLC
    LDA graphic_source_pointer_low
    ADC #MODE1_CELL_COLUMN_BYTES
    STA graphic_source_pointer_low
    BCC source_pointer_advanced_after_store
    INC graphic_source_pointer_high

.source_pointer_advanced_after_store
    DEX
    RTS
.store_byte_and_advance_source_pointer_source_end

ASSERT store_byte_and_advance_source_pointer_source = store_byte_and_advance_source_pointer
ASSERT store_byte_and_advance_source_pointer_source_end = &125D
COPYBLOCK store_byte_and_advance_source_pointer_source, store_byte_and_advance_source_pointer_source_end, &2A4E

; Runtime $124E-$125C overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2A4E-$2A5C.
CLEAR store_byte_and_advance_source_pointer_source, store_byte_and_advance_source_pointer_source_end


ORG enter_copy_16_byte_graphic_to_display

; A single JMP vector into the 16-byte graphic blitter,
; sitting between named runtime variables rather than in the table at $1200.
; The bytes either side are data: $1225 is read by the character renderer and
; the IRQ handler, and room_moving_object_graphic_selector_delta holds the first room-object selector step.
.enter_copy_16_byte_graphic_to_display_source
    JMP copy_16_byte_graphic_to_display
.enter_copy_16_byte_graphic_to_display_source_end

ASSERT enter_copy_16_byte_graphic_to_display_source = enter_copy_16_byte_graphic_to_display
ASSERT enter_copy_16_byte_graphic_to_display_source_end = &1229
COPYBLOCK enter_copy_16_byte_graphic_to_display_source, enter_copy_16_byte_graphic_to_display_source_end, &2A26

; Runtime $1226-$1228 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2A26-$2A28.
CLEAR enter_copy_16_byte_graphic_to_display_source, enter_copy_16_byte_graphic_to_display_source_end


ORG write_twelve_video_ula_palette_entries

; The IRQ handler calls this entry once in every observed
; IRQ sample. It supplies three fixed accumulator values to the four-entry
; palette helper: two ordinary JSRs followed by a final fall-through. The
; complete call therefore writes twelve Video ULA palette commands, preserves
; X and Y, and returns the final encoded palette command through the helper.
.write_twelve_video_ula_palette_entries_source
    LDA #VIDEO_ULA_PALETTE_BATCH_0_SEED
    JSR write_four_video_ula_palette_entries
    LDA #VIDEO_ULA_PALETTE_BATCH_1_SEED
    JSR write_four_video_ula_palette_entries
    LDA #VIDEO_ULA_PALETTE_BATCH_2_SEED
.write_twelve_video_ula_palette_entries_source_end

ASSERT write_twelve_video_ula_palette_entries_source = write_twelve_video_ula_palette_entries
ASSERT write_twelve_video_ula_palette_entries_source_end = &1269
COPYBLOCK write_twelve_video_ula_palette_entries_source, write_twelve_video_ula_palette_entries_source_end, &2A5D

; Evidence-backed behavior: write four related palette commands to the BBC
; Video ULA palette register. The accumulator and stack behavior are
; deliberately preserved instruction for instruction.
.write_four_video_ula_palette_entries
    EOR #VIDEO_ULA_PHYSICAL_COLOUR_XOR_MASK
    PHA
    STA VIDEO_ULA_PALETTE
    PLA
    PHA
    ORA #VIDEO_ULA_LOGICAL_COLOUR_1_BITS
    STA VIDEO_ULA_PALETTE
    PLA
    PHA
    ORA #VIDEO_ULA_LOGICAL_COLOUR_2_BITS
    STA VIDEO_ULA_PALETTE
    PLA
    ORA #VIDEO_ULA_LOGICAL_COLOUR_3_BITS
    STA VIDEO_ULA_PALETTE
    RTS
.write_four_video_ula_palette_entries_end

ASSERT write_four_video_ula_palette_entries_end = &1284
COPYBLOCK write_four_video_ula_palette_entries, write_four_video_ula_palette_entries_end, &2A69

ORG draw_room_enemy_with_xor_graphic

; Draw the graphic for the Y-indexed room enemy. Ordinary enemy frames occupy
; one character row. Moths, or records whose last slot is below the named
; threshold, configure a two-row graphic with doubled source scanlines. Bit 1
; of the horizontal position selects frame 0 or frame 1, after which the display
; pointer is loaded and the XOR renderer is tail-called.
;
; This is the enemy renderer. Suppressing it was tested in play and the enemy
; robots disappeared while the lifts kept working, which is the strongest thing
; known about any of the four sprite renderers. The species, last slot,
; horizontal position, and display pointer are exactly the fields
; initialise_room_enemy_from_table unpacks from room_enemy_record_table, so the
; table and the renderer are the same subsystem.
.draw_room_enemy_with_xor_graphic_source
    LDA #ROOM_ENEMY_DEFAULT_CHARACTER_ROWS
    STA xor_graphic_character_rows_remaining
    LDA active_enemy_species
    CMP #ENEMY_SPECIES_MOTH
    BEQ configure_two_row_repeat_for_entity
    LDA active_enemy_last_slot_index
    CMP #ROOM_ENEMY_TWO_ROW_SLOT_THRESHOLD
    BPL select_entity_row_count

.configure_two_row_repeat_for_entity
    JSR configure_two_row_repeated_xor_graphic

.select_entity_row_count
    LDX #ROOM_ENEMY_FRAME_0_POINTER_OFFSET
    LDA moving_entity_horizontal_position,Y
    ROR A
    ROR A
    BCS load_pointer_then_draw_entity
    LDX #ROOM_ENEMY_FRAME_1_POINTER_OFFSET

.load_pointer_then_draw_entity
    JSR load_room_enemy_display_pointer
    JMP select_graphic_then_xor_draw
.draw_room_enemy_with_xor_graphic_source_end

ASSERT draw_room_enemy_with_xor_graphic_source = draw_room_enemy_with_xor_graphic
ASSERT draw_room_enemy_with_xor_graphic_source_end = &3558
COPYBLOCK draw_room_enemy_with_xor_graphic_source, draw_room_enemy_with_xor_graphic_source_end, &4D32

; Runtime $3532-$3557 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4D32-$4D57.
CLEAR draw_room_enemy_with_xor_graphic_source, draw_room_enemy_with_xor_graphic_source_end


ORG apply_signed_vertical_step_to_pointer

; Add the signed step in $40 to the vertical position at $3C
; and walk the pointer at $3E/$3F to match, two display scanlines per step.
; Within a Mode 1 character cell the eight scanlines are consecutive bytes, so a
; step of two is two increments or two decrements of the low byte. Crossing a
; cell boundary costs $027A instead, which is one character row of $0280 less
; the six bytes the step would have run past. The sign of $40 selects the
; direction and each direction tests the scanline within the cell before
; committing: upwards when the low three bits are below 5, downwards when they
; are 2 or more.
; All four paths are covered: 2,038 within-cell against 679 row-crossing
; upwards, and 1,673 against 568 downwards.
.apply_signed_vertical_step_to_pointer_source
    LDA candidate_half_vertical_position
    CLC
    ADC vertical_step_delta
    STA candidate_half_vertical_position
    LDA vertical_step_delta
    BMI step_pointer_upwards
    LDA vertical_step_pointer_low
    AND #MODE1_SCANLINE_INDEX_MASK
    CMP #VERTICAL_STEP_DOWN_WRAP_LIMIT
    BPL cross_to_next_character_row
    INC vertical_step_pointer_low
    INC vertical_step_pointer_low
    RTS

.cross_to_next_character_row
    CLC
    LDA vertical_step_pointer_low
    ADC #MODE1_ROW_WRAP_LOW_ADJUST
    STA vertical_step_pointer_low
    LDA vertical_step_pointer_high
    ADC #MODE1_ROW_WRAP_HIGH_ADJUST
    STA vertical_step_pointer_high
    RTS

.step_pointer_upwards
    LDA vertical_step_pointer_low
    AND #MODE1_SCANLINE_INDEX_MASK
    CMP #VERTICAL_STEP_UP_WRAP_LIMIT
    BMI cross_to_previous_character_row
    DEC vertical_step_pointer_low
    DEC vertical_step_pointer_low
    RTS

.cross_to_previous_character_row
    SEC
    LDA vertical_step_pointer_low
    SBC #MODE1_ROW_WRAP_LOW_ADJUST
    STA vertical_step_pointer_low
    LDA vertical_step_pointer_high
    SBC #MODE1_ROW_WRAP_HIGH_ADJUST
    STA vertical_step_pointer_high
    RTS
.apply_signed_vertical_step_to_pointer_source_end

ASSERT apply_signed_vertical_step_to_pointer_source = apply_signed_vertical_step_to_pointer
ASSERT apply_signed_vertical_step_to_pointer_source_end = &3532
COPYBLOCK apply_signed_vertical_step_to_pointer_source, apply_signed_vertical_step_to_pointer_source_end, &4CF1

; Runtime $34F1-$3531 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4CF1-$4D31.
CLEAR apply_signed_vertical_step_to_pointer_source, apply_signed_vertical_step_to_pointer_source_end


ORG print_item_slot_label

; Position the VDU cursor at row Y, column X, then print
; six bytes from the item-label table. Zero selects offset zero; other ordinary
; codes select 3*(code-$26). Code $3E with nonzero $A0 takes the explicit
; offset-$18 path, which is byte-output-equivalent but preserves original flow.
.print_item_slot_label_source
    PHA
    LDA #VDU_TEXT_AT
    JSR OSWRCH
    TYA
    JSR OSWRCH
    TXA
    JSR OSWRCH
    PLA
    BEQ print_item_slot_label_zero_code
    CMP #ITEM_CODE_BOTTLE
    BNE print_item_slot_label_ordinary_code
    LDX special_item_3e_activation_flag
    CPX #&00
    BEQ print_item_slot_label_ordinary_code
    LDY #SPECIAL_ITEM_LABEL_OFFSET
    JMP print_item_slot_label_emit

.print_item_slot_label_ordinary_code
    SEC
    SBC #ITEM_LABEL_CODE_BIAS

.print_item_slot_label_zero_code
    STA item_label_index_unscaled
    ASL A
    ADC item_label_index_unscaled
    TAY

.print_item_slot_label_emit
    LDX #ITEM_LABEL_CHARACTER_COUNT

.print_item_slot_label_emit_loop
    LDA item_slot_label_table,Y
    JSR OSWRCH
    INY
    DEX
    BNE print_item_slot_label_emit_loop
    RTS
.print_item_slot_label_source_end

ASSERT print_item_slot_label_source = print_item_slot_label
ASSERT print_item_slot_label_source_end = &34F1
COPYBLOCK print_item_slot_label_source, print_item_slot_label_source_end, &4CBB

; Runtime $34BB-$34F0 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4CBB-$4CF0.
CLEAR print_item_slot_label_source, print_item_slot_label_source_end


ORG copy_16_byte_graphic_to_display

; A bits 0-5 select a 16-byte record. Bit 6 selects reversed order within each
; eight-byte half; bit 7 makes the byte helper apply GRAPHIC_BYTE_XOR_MASK. In a water
; environment, record zero is replaced by GRAPHIC_HORIZONTAL_BAR. X and Y are
; preserved, while A returns the original masked record index.
.copy_16_byte_graphic_to_display_source
    STA graphic_record_selector_flags
    AND #GRAPHIC_RECORD_INDEX_MASK
    STA graphic_record_byte_offset_low
    PHA
    TXA
    PHA
    TYA
    PHA

    LDA graphic_record_byte_offset_low
    BNE copy_16_graphic_index_selected
    LDA water_environment_flag
    BEQ copy_16_graphic_index_selected
    LDA #GRAPHIC_HORIZONTAL_BAR
    STA graphic_record_byte_offset_low
.copy_16_graphic_index_selected
    LDA #GRAPHIC_XOR_TRANSFORM_DISABLED
    STA graphic_record_byte_offset_high
    STA graphic_byte_xor_transform_enabled
    LDX #GRAPHIC_RECORD_INDEX_SHIFT
.multiply_graphic_index_by_16
    ASL graphic_record_byte_offset_low
    ROL graphic_record_byte_offset_high
    DEX
    BNE multiply_graphic_index_by_16

    LDX graphic_source_base_pointer_offset
    LDA graphic_source_base_pointers,X
    ADC graphic_record_byte_offset_low
    STA graphic_source_pointer_low
    LDA graphic_source_base_pointers+1,X
    ADC graphic_record_byte_offset_high
    STA graphic_source_pointer_high

    ASL graphic_record_selector_flags
    BCC copy_16_graphic_without_xor
    LDA #GRAPHIC_XOR_TRANSFORM_ENABLED
    STA graphic_byte_xor_transform_enabled
.copy_16_graphic_without_xor
    ASL graphic_record_selector_flags
    BCS copy_16_graphic_halves_reversed

    LDY #GRAPHIC_RECORD_FIRST_BYTE_INDEX
.copy_16_graphic_forward_loop
    JSR copy_graphic_byte_to_display
    INY
    CPY #GRAPHIC_RECORD_BYTE_COUNT
    BNE copy_16_graphic_forward_loop
    JMP restore_copy_16_graphic_registers

; Two little-endian base pointers selected by GRAPHIC_BANK_* offsets.
.graphic_source_base_pointers
    EQUW room_and_item_graphic_bank, status_icon_graphics

.copy_16_graphic_halves_reversed
    LDY #GRAPHIC_RECORD_FIRST_HALF_LAST_INDEX
.copy_16_graphic_first_half_reversed_loop
    JSR copy_graphic_byte_to_display
    DEY
    CPY #GRAPHIC_REVERSE_FIRST_HALF_END
    BNE copy_16_graphic_first_half_reversed_loop
    LDY #GRAPHIC_RECORD_SECOND_HALF_LAST_INDEX
.copy_16_graphic_second_half_reversed_loop
    JSR copy_graphic_byte_to_display
    DEY
    CPY #GRAPHIC_RECORD_FIRST_HALF_LAST_INDEX
    BNE copy_16_graphic_second_half_reversed_loop

.restore_copy_16_graphic_registers
    PLA
    TAY
    PLA
    TAX
    PLA
    RTS
.copy_16_byte_graphic_to_display_source_end

ASSERT copy_16_byte_graphic_to_display_source = copy_16_byte_graphic_to_display
ASSERT graphic_source_base_pointers = &1D34
ASSERT copy_16_byte_graphic_to_display_source_end = copy_graphic_byte_to_display
COPYBLOCK copy_16_byte_graphic_to_display_source, copy_16_byte_graphic_to_display_source_end, &34E4

ORG test_player_in_range_and_set_direction

; Test whether the player is within range of the indexed
; candidate and, if so, report which way the player lies.
; The ordinary entry presets the named horizontal, above and below extents;
; test_range_with_supplied_box is the entry for callers supplying their own.
; Four comparisons follow, the horizontal pair against candidate_horizontal_position
; and the vertical pair against candidate_half_vertical_position. Each failure
; leaves through the shared no-overlap return with carry clear.
; Only if all four pass does it compute the direction: the sign of the
; horizontal difference sets opposite signed horizontal steps, and the sign of
; the vertical difference selects a signed double-unit step. Carry set means
; both in range and direction reported.
; Those are the same signed unit and double-unit deltas the room enemy
; setters write, so what this produces is a step toward the player rather than a
; plain yes or no.
.test_player_in_range_and_set_direction_source
    LDA #PLAYER_RANGE_DEFAULT_HORIZONTAL_EXTENT
    STA candidate_range_horizontal_extent
    LDA #PLAYER_RANGE_DEFAULT_ABOVE_EXTENT
    STA candidate_range_above_extent
    LDA #PLAYER_RANGE_DEFAULT_BELOW_EXTENT
    STA candidate_range_below_extent

.test_range_with_supplied_box
    CLC
    LDA player_horizontal_position
    ADC candidate_range_horizontal_extent
    CMP candidate_horizontal_position
    BMI player_range_no_overlap_return
    LDA candidate_horizontal_position
    ADC candidate_range_horizontal_extent
    CMP player_horizontal_position
    BMI player_range_no_overlap_return

.test_vertical_range
    LDA player_vertical_position
    LSR A
    SEC
    SBC candidate_range_above_extent
    CMP candidate_half_vertical_position
    BPL player_range_no_overlap_return
    LDA player_vertical_position
    LSR A
    ADC candidate_range_below_extent
    CMP candidate_half_vertical_position
    BMI player_range_no_overlap_return

.set_direction_toward_player
    SEC
    LDA candidate_horizontal_position
    SBC player_horizontal_position
    BPL set_direction_leftward
    LDA #ENTITY_HORIZONTAL_STEP_POSITIVE
    STA candidate_horizontal_step
    LDA #ENTITY_HORIZONTAL_STEP_NEGATIVE
    STA candidate_horizontal_opposite_step
    JMP set_vertical_direction

.set_direction_leftward
    LDA #ENTITY_HORIZONTAL_STEP_NEGATIVE
    STA candidate_horizontal_step
    LDA #ENTITY_HORIZONTAL_STEP_POSITIVE
    STA candidate_horizontal_opposite_step

.set_vertical_direction
    CLC
    LDA player_vertical_position
    ADC #PLAYER_VERTICAL_CENTRE_BIAS
    SEC
    LSR A
    SBC candidate_half_vertical_position
    BPL set_vertical_direction_downward
    LDA #ENTITY_VERTICAL_STEP_NEGATIVE

.store_vertical_direction
    STA candidate_vertical_step
    SEC
    RTS

.set_vertical_direction_downward
    LDA #ENTITY_VERTICAL_STEP_POSITIVE
    JMP store_vertical_direction
.test_player_in_range_and_set_direction_source_end

ASSERT test_player_in_range_and_set_direction_source = test_player_in_range_and_set_direction
ASSERT test_player_in_range_and_set_direction_source_end = &2BFE
COPYBLOCK test_player_in_range_and_set_direction_source, test_player_in_range_and_set_direction_source_end, &439E

; Runtime $2B9E-$2BFD overlaps the loaded transport image. Release it after
; copying its bytes to loaded $439E-$43FD.
CLEAR test_player_in_range_and_set_direction_source, test_player_in_range_and_set_direction_source_end


ORG draw_fixed_pair_tile_run

; The third run painter, alongside the blank and the
; configurable alternating run. It writes the fixed pair $01 and $02 into the
; working tile pair and then alternates between them for X tiles, entering
; through the mirror-flag selector so each tile can be drawn reversed.
; Bit 0 of $F8 decides which of the pair is drawn first: when clear the run
; starts on the second index, which is why the loop is entered at its midpoint.
; $13D4 presets a run of eight; callers wanting another length enter at $13D6.
; A run that empties on the first half leaves through the alternating painter
; shared RTS at $13A2 rather than the one at $13F7.
.draw_fixed_pair_tile_run_source
    LDX #&08

.set_fixed_tile_pair
    LDA #&01
    STA active_tile_pair_first
    LDA #&02
    STA active_tile_pair_second
.draw_selected_fixed_pair_run
    LDA tile_pair_source_selector
    ROR A
    BCC draw_second_of_fixed_pair

.draw_first_of_fixed_pair
    LDA active_tile_pair_first
    JSR apply_mirror_flag_then_copy_graphic
    DEX
    BEQ alternating_tile_run_rts

.draw_second_of_fixed_pair
    LDA active_tile_pair_second
    JSR apply_mirror_flag_then_copy_graphic
    DEX
    BNE draw_first_of_fixed_pair
    RTS


ORG load_room_enemy_display_pointer

; Load the display pointer from the Y-indexed little-endian pair at room_enemy_display_pointer_low/high. The high byte is read first, so the two loads are not interchangeable with respect to Y. X and A are not preserved.
.load_room_enemy_display_pointer_source
    LDA room_enemy_display_pointer_high,Y
    STA display_pointer_high
    LDA room_enemy_display_pointer_low,Y
    STA display_pointer_low
    RTS
.load_room_enemy_display_pointer_source_end

ASSERT load_room_enemy_display_pointer_source = load_room_enemy_display_pointer
ASSERT load_room_enemy_display_pointer_source_end = &3563
COPYBLOCK load_room_enemy_display_pointer_source, load_room_enemy_display_pointer_source_end, &4D58

; Runtime $3558-$3562 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4D58-$4D62.
CLEAR load_room_enemy_display_pointer_source, load_room_enemy_display_pointer_source_end


ORG advance_secondary_reference_and_pointer

; Increment the secondary room reference, advance level_room_map_offset by one
; complete level map, then redraw and initialise the room. This is one of the
; actions reachable through display_action_jump_table. Its two adjacent table
; entries adjust the primary room reference instead before the same redraw.
.advance_secondary_reference_and_pointer_source
    INC reference_pair_secondary_value
    CLC
    LDA level_room_map_offset_low
    ADC #ROOM_LEVEL_MAP_BYTES
    STA level_room_map_offset_low
    BCC level_room_map_pointer_advanced
    INC level_room_map_offset_high

.level_room_map_pointer_advanced
    JMP draw_and_initialise_room
.advance_secondary_reference_and_pointer_source_end

ASSERT advance_secondary_reference_and_pointer_source = advance_secondary_reference_and_pointer
ASSERT advance_secondary_reference_and_pointer_source_end = &1CD7
COPYBLOCK advance_secondary_reference_and_pointer_source, advance_secondary_reference_and_pointer_source_end, &34C7

; Runtime $1CC7-$1CD6 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $34C7-$34D6.
CLEAR advance_secondary_reference_and_pointer_source, advance_secondary_reference_and_pointer_source_end


ORG update_and_draw_room_enemies

; Iterate backward over the active room-enemy slots,
; optionally erase each old XOR image, and dispatch by species. Bats use the
; direct player-range test; moths use collision-aware movement and both limit
; clamps; the small robot (and the unselected jellyfish descriptor) use the
; obstacle-reflection path. Then apply pursuit deltas when available, move,
; process player overlap, redraw, and clear the repeated-source flag.
.update_and_draw_room_enemies_source
    LDY active_enemy_last_slot_index

.update_next_room_enemy
    LDA erase_previous_xor_sprite_flag
    BEQ dispatch_room_enemy_behavior
    JSR draw_room_enemy_with_xor_graphic

.dispatch_room_enemy_behavior
    LDA active_enemy_species
    BEQ prepare_bat_player_range_test
    CMP #ENEMY_SPECIES_MOTH
    BNE update_obstacle_reflecting_room_enemy
    JSR advance_room_enemy_with_collision_checks
    JSR reverse_room_enemy_vertical_delta_at_limits
    JSR clamp_room_enemy_horizontal_delta_at_limits
    JSR prepare_room_enemy_collision_coordinates
    BCC apply_room_enemy_to_player_and_draw
    JMP apply_player_direction_if_in_range

.update_obstacle_reflecting_room_enemy
    JSR reflect_room_enemy_at_obstacles
    JMP apply_player_direction_if_in_range

.prepare_bat_player_range_test
    JSR load_room_enemy_collision_coordinates
    JSR enter_test_player_in_range_and_set_direction

.apply_player_direction_if_in_range
    BCC clamp_room_enemy_horizontal_delta
    LDA candidate_horizontal_step
    STA room_enemy_horizontal_delta,Y
    LDA candidate_vertical_step
    STA enemy_vertical_delta,Y
    JMP move_room_enemy_on_both_axes

.clamp_room_enemy_horizontal_delta
    JSR clamp_room_enemy_horizontal_delta_at_limits

.move_room_enemy_on_both_axes
    JSR reverse_room_enemy_vertical_delta_at_limits
    JSR advance_room_enemy_horizontal_position
    JSR advance_room_enemy_vertical_position

.apply_room_enemy_to_player_and_draw
    JSR load_room_enemy_collision_coordinates
    LDA #ROOM_ENEMY_COLLISION_EXTENT
    STA xor_graphic_character_rows_remaining
    JSR enter_player_candidate_bounds_overlap
    JSR draw_room_enemy_with_xor_graphic
    DEY
    DEY
    BPL update_next_room_enemy
    JMP clear_xor_graphic_repeat_and_return
.update_and_draw_room_enemies_source_end

ASSERT update_and_draw_room_enemies_source = update_and_draw_room_enemies
ASSERT update_and_draw_room_enemies_source_end = &35C2
COPYBLOCK update_and_draw_room_enemies_source, update_and_draw_room_enemies_source_end, &4D63

; Runtime $3563-$35C1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4D63-$4DC1.
CLEAR update_and_draw_room_enemies_source, update_and_draw_room_enemies_source_end


ORG copy_graphic_byte_to_display

; Inputs: Y selects a byte through graphic_source_pointer;
; graphic_byte_xor_transform_enabled selects the optional EOR transform, and
; display_pointer names the current destination.
; Output: one byte is stored, display_pointer advances by one with its page
; carry preserved, and the caller's Y source index is restored before return.
; The initial-render trace exercises 11,434 entries and 44 page carries. Its
; observed calls all disable the XOR transform; the EOR path is statically proven
; by the original instruction stream but is not exercised by a committed run.
.copy_graphic_byte_to_display_source
    LDA (graphic_source_pointer_low),Y
    STY graphic_byte_saved_source_index
    LDY graphic_byte_xor_transform_enabled
    BEQ copy_graphic_byte_without_xor
    EOR #GRAPHIC_BYTE_XOR_MASK
.copy_graphic_byte_without_xor
    LDY #GRAPHIC_RECORD_FIRST_BYTE_INDEX
    STA (display_pointer_low),Y
    INC display_pointer_low
    BNE copy_graphic_byte_pointer_advanced
    INC display_pointer_high
.copy_graphic_byte_pointer_advanced
    LDY graphic_byte_saved_source_index
    RTS
.copy_graphic_byte_to_display_source_end

ASSERT copy_graphic_byte_to_display_source = copy_graphic_byte_to_display
ASSERT copy_graphic_byte_to_display_source_end = &1D69
COPYBLOCK copy_graphic_byte_to_display_source, copy_graphic_byte_to_display_source_end, &3552

; Runtime $1CE4-$1D68 overlaps the loaded transport image. Its reconstructed
; bytes are already copied to $34E4-$3568, so release the logical range before
; filling the original loaded bytes below.
CLEAR copy_16_byte_graphic_to_display_source, copy_graphic_byte_to_display_source_end

ORG run_game_tick_with_player_contact_flag_cleared

; Clear player_contact_or_damage_flag, then fall through
; directly into dispatch_game_tick_updates. The dispatcher retains the JSR
; return address established by the gameplay loop.
.run_game_tick_with_player_contact_flag_cleared_source
    LDA #&00
    STA player_contact_or_damage_flag
.run_game_tick_with_player_contact_flag_cleared_source_end

ASSERT run_game_tick_with_player_contact_flag_cleared_source = run_game_tick_with_player_contact_flag_cleared
ASSERT run_game_tick_with_player_contact_flag_cleared_source_end = dispatch_game_tick_updates
COPYBLOCK run_game_tick_with_player_contact_flag_cleared_source, run_game_tick_with_player_contact_flag_cleared_source_end, &3A37

; Runtime $2237-$223A overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3A37-$3A3A.
CLEAR run_game_tick_with_player_contact_flag_cleared_source, run_game_tick_with_player_contact_flag_cleared_source_end

ORG dispatch_game_tick_updates

; Dispatch one gameplay tick after the wrapper has cleared
; player_contact_or_damage_flag. Optional update groups are gated by their state
; bytes, while named timed effects and Teleport, Armoury and Time Warp sign states
; select dedicated handlers. The Armoury path adds a collected icon, enables
; room_update_suppression_state, and applies ARMOURY_ENERGY_DECREMENT_COUNT
; energy decrements. Every path rejoins the frame-pacing loop, which reads the
; system clock into cross_room_robot_ghost_initial_state and waits until its low
; byte reaches bounded_tick_target_value.
.dispatch_game_tick_updates_source
    JSR update_and_draw_two_cross_room_robot_ghosts
    LDA room_tick_update_selector
    BEQ after_room_enemy_update
    JSR update_and_draw_room_enemies

.after_room_enemy_update
    LDA room_update_suppression_state
    BNE finish_optional_room_updates
    LDA room_interaction_code
    CMP #ROOM_CELL_TELEPORT_SIGN
    BNE after_teleport_update
    JSR run_horizontal_16_warp_sequence

.after_teleport_update
    LDA room_moving_objects_active
    BEQ after_room_moving_object_update
    JSR update_and_draw_room_moving_objects

.after_room_moving_object_update
    LDA lift_hazard_primary_updates_active
    BEQ after_primary_lift_hazard_update
    JSR update_lift_and_hazard_slots

.after_primary_lift_hazard_update
    LDA lift_hazard_secondary_updates_active
    BEQ after_secondary_lift_hazard_update
    JSR advance_record_counter_then_dispatch

.after_secondary_lift_hazard_update
    LDA timed_effect_selector
    CMP #TIMED_EFFECT_REPLACE_SAVED_CELL_0C
    BNE after_blank_state_cell_effect
    JSR replace_saved_cell_then_play_sound

.after_blank_state_cell_effect
    LDA timed_effect_selector
    CMP #TIMED_EFFECT_SHIFT_SAVED_DISPLAY_BLOCK
    BNE after_saved_display_shift_effect
    JSR advance_saved_display_block_shift_effect

.after_saved_display_shift_effect
    LDA game_clock_tick_pending
    BEQ after_game_clock_update
    JSR advance_bcd_counter_and_print

.after_game_clock_update
    LDA timed_effect_selector
    CMP #TIMED_EFFECT_REPLACE_SAVED_CELL_14
    BNE after_ff_state_cell_effect
    JSR replace_saved_cell_with_14_then_play_sound

.after_ff_state_cell_effect
    LDA lift_and_hazard_active
    BEQ after_lift_hazard_group_update
    JSR update_lift_and_hazard_group

.after_lift_hazard_group_update
    LDA room_interaction_code
    CMP #ROOM_CELL_ARMOURY_SIGN
    BNE finish_optional_room_updates
    JSR enter_add_collected_icon
    LDA #ROOM_UPDATE_SUPPRESSION_ENABLED
    STA room_update_suppression_state
    LDX #ARMOURY_ENERGY_DECREMENT_COUNT

.apply_next_armoury_energy_decrement
    DEC player_energy_snapshot
    JSR decrement_player_energy_and_redraw
    DEX
    BNE apply_next_armoury_energy_decrement

.finish_optional_room_updates
    LDA horizontal_band_velocity_effect_state
    LSR A
    BCC after_horizontal_band_velocity_effect
    JSR set_velocity_step_from_horizontal_band

.after_horizontal_band_velocity_effect
    LDA room_interaction_code
    CMP #ROOM_CELL_TIME_WARP_SIGN
    BNE prepare_frame_clock_wait
    JSR advance_bounded_tick_target

.prepare_frame_clock_wait
    LDX #XOR_SPRITE_ERASE_ENABLED
    STX erase_previous_xor_sprite_flag
    DEX ; XOR_SPRITE_ERASE_ENABLED becomes CROSS_ROOM_ROBOT_GHOST_COUNTDOWNS_RESET
    STX reset_cross_room_robot_ghost_countdowns

.wait_for_frame_clock_target
    LDA #OSWORD_READ_SYSTEM_CLOCK
    LDX #LO(cross_room_robot_ghost_initial_state)
    LDY #HI(cross_room_robot_ghost_initial_state)
    JSR OSWORD
    LDA cross_room_robot_ghost_initial_state
    CMP bounded_tick_target_value
    BMI wait_for_frame_clock_target
    RTS
.dispatch_game_tick_updates_source_end

ASSERT dispatch_game_tick_updates_source = dispatch_game_tick_updates
ASSERT dispatch_game_tick_updates_source_end = &22D6
COPYBLOCK dispatch_game_tick_updates_source, dispatch_game_tick_updates_source_end, &3A3B

; Runtime $223B-$22D5 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3A3B-$3AD5.
CLEAR dispatch_game_tick_updates_source, dispatch_game_tick_updates_source_end

ORG apply_mirror_flag_then_copy_graphic

; An alternate entry to the 16-byte graphic blitter that
; first decides whether the record is drawn mirrored. Bit 7 of $43 is rotated
; into carry without disturbing A; when it is set, $40 is added to the record
; index and the result masked to seven bits, which sets bit 6, the flag the
; blitter reads as reversed order within each eight-byte half.
; There is no branch at the end: the block runs off its last instruction
; straight into copy_16_byte_graphic_to_display at $1CE4, and the carry-clear
; path branches to that same address.
.apply_mirror_flag_then_copy_graphic_source
    PHA
    LDA xor_sprite_display_pointer_low
    ROL A
    PLA
    BCC copy_16_byte_graphic_to_display

.apply_mirrored_record_bias
    CLC
    ADC #GRAPHIC_RECORD_MIRROR_FLAG
    AND #GRAPHIC_RECORD_WITH_MIRROR_MASK
.apply_mirror_flag_then_copy_graphic_source_end

ASSERT apply_mirror_flag_then_copy_graphic_source = apply_mirror_flag_then_copy_graphic
ASSERT apply_mirror_flag_then_copy_graphic_source_end = &1CE4
COPYBLOCK apply_mirror_flag_then_copy_graphic_source, apply_mirror_flag_then_copy_graphic_source_end, &34D8

; Runtime $1CD8-$1CE3 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $34D8-$34E3.
CLEAR apply_mirror_flag_then_copy_graphic_source, apply_mirror_flag_then_copy_graphic_source_end


ORG match_packed_record_against_references

; Match the two-byte packed record at
; packed_record_pointer
; against the two reference values, extracting the rest of it only on success.
; Each byte carries two fields. The first is matched on its low six bits
; against reference_pair_secondary_value, and its top three bits shifted down
; and masked even become packed_record_even_field. The second is matched on its
; low nibble against reference_pair_primary_value, and its high nibble becomes
; packed_record_type_field. Carry set means both halves matched and the extracted
; fields are valid; carry clear means the complete record did not match.
; Testing the cheaper half first is what makes this affordable to call in a
; scan: 890 of 907 calls fail, 801 of them on the first comparison.
.match_packed_record_against_references_source
    LDA (packed_record_pointer_low),Y
    AND #PACKED_RECORD_SECONDARY_MASK
    CMP reference_pair_secondary_value
    BNE report_no_match
    LDA (packed_record_pointer_low),Y
    LSR A
    LSR A
    LSR A
    LSR A
    LSR A
    AND #PACKED_RECORD_EXTRACTED_EVEN_MASK
    STA packed_record_even_field
    INY
    LDA (packed_record_pointer_low),Y
    AND #PACKED_RECORD_PRIMARY_MASK
    CMP reference_pair_primary_value
    BNE report_no_match
    LDA (packed_record_pointer_low),Y
    LSR A
    LSR A
    LSR A
    LSR A
    STA packed_record_type_field
    SEC
    RTS

.report_no_match
    CLC
    RTS
.match_packed_record_against_references_source_end

ASSERT match_packed_record_against_references_source = match_packed_record_against_references
ASSERT match_packed_record_against_references_source_end = &20B2
COPYBLOCK match_packed_record_against_references_source, match_packed_record_against_references_source_end, &388A

; Runtime $208A-$20B1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $388A-$38B1.
CLEAR match_packed_record_against_references_source, match_packed_record_against_references_source_end


ORG load_room_palette_and_tile_pair

; Set the palette and the tile pairs for the current room
; from one appearance byte.
; The room is addressed as the level at $8F times eight plus the sector at $90,
; which indexes the table at $09B0: eight rooms to a level, matching the sector
; range A to H the title program describes.
; That byte carries two fields. Its low nibble becomes the lower-screen palette
; value at $0382, which the IRQ handler writes to the Video ULA after its timer
; split. Its upper bits, shifted down twice and masked to $FC, index the
; four-byte tile pair sets at $1D90, which are copied into $7FFC to $7FFF, the
; stored pairs draw_alternating_tile_run chooses between.
; So a single byte decides both what colour a room is below the raster split and
; which two tiles its walls are built from.
.load_room_palette_and_tile_pair_source
    LDA reference_pair_secondary_value
    ASL A
    ASL A
    ASL A
    ADC reference_pair_primary_value
    TAX
    LDA #ROOM_APPEARANCE_PALETTE_MASK
    AND room_appearance_table,X
    STA lower_screen_palette_base
    LDA room_appearance_table,X
    LSR A
    LSR A
    AND #ROOM_APPEARANCE_TILE_OFFSET_MASK
    TAX
    LDY #&00

.copy_next_tile_pair_byte
    LDA room_tile_pair_sets,X
    STA primary_tile_pair_first,Y
    INY
    INX
    CPY #&04
    BNE copy_next_tile_pair_byte
    RTS
.load_room_palette_and_tile_pair_source_end

ASSERT load_room_palette_and_tile_pair_source = load_room_palette_and_tile_pair
ASSERT load_room_palette_and_tile_pair_source_end = &1D90
COPYBLOCK load_room_palette_and_tile_pair_source, load_room_palette_and_tile_pair_source_end, &3569

; Runtime $1D69-$1D8F overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3569-$358F.
CLEAR load_room_palette_and_tile_pair_source, load_room_palette_and_tile_pair_source_end


ORG advance_bcd_counter_and_print

; Consume the pending clock tick, increment the low packed-BCD counter, and roll
; it after 59 while incrementing the high byte. Low-counter states zero and one
; select ROOM_CELL_BLANK_STATE_MOTIF or ROOM_CELL_FF_STATE_MOTIF for G0. While
; G0 itself is active the value becomes the transient-effect selector; otherwise
; it is written directly to the named G0 map cell. The continuation prints the
; high and low two-digit bytes at the named cursor, separated by a horizontal tab.
.advance_bcd_counter_and_print_source
    LDA #&00
    STA game_clock_tick_pending
    SED
    CLC
    LDA bcd_counter_low
    ADC #PACKED_BCD_UNIT_INCREMENT
    STA bcd_counter_low
    CMP #PACKED_BCD_LOW_ROLLOVER
    BNE finish_bcd_counter_increment
    LDA #PACKED_BCD_ZERO
    STA bcd_counter_low
    CLC
    LDA bcd_counter_high
    ADC #PACKED_BCD_UNIT_INCREMENT
    STA bcd_counter_high

.finish_bcd_counter_increment
    CLD
    LDA bcd_counter_low
    BNE test_bcd_counter_one
    LDA #ROOM_CELL_BLANK_STATE_MOTIF
    JMP apply_bcd_counter_state_value

.test_bcd_counter_one
    CMP #GAME_CLOCK_STATE_ONE
    BNE print_bcd_counter
    LDA #ROOM_CELL_FF_STATE_MOTIF

.apply_bcd_counter_state_value
    LDX reference_pair_primary_value
    CPX #GAME_CLOCK_SPECIAL_ROOM_COLUMN
    BNE store_bcd_counter_state_in_room_map
    LDX reference_pair_secondary_value
    CPX #GAME_CLOCK_SPECIAL_ROOM_LEVEL
    BNE store_bcd_counter_state_in_room_map
    STA timed_effect_selector
    JMP print_bcd_counter

.store_bcd_counter_state_in_room_map
    STA room_G0_row_2_cell_4

.print_bcd_counter
    JSR print_inline_vdu_stream

.bcd_counter_cursor_vdu_stream
    EQUB VDU_TEXT_AT, GAME_CLOCK_CURSOR_X, GAME_CLOCK_CURSOR_Y, INLINE_VDU_STREAM_END
.bcd_counter_cursor_vdu_stream_end

    LDA bcd_counter_high
    JSR print_packed_bcd_byte
    LDA #VDU_HORIZONTAL_TAB
    JSR OSWRCH
    LDA bcd_counter_low
    JMP print_packed_bcd_byte
.advance_bcd_counter_and_print_source_end

ASSERT advance_bcd_counter_and_print_source = advance_bcd_counter_and_print
ASSERT bcd_counter_cursor_vdu_stream = &37B8
ASSERT bcd_counter_cursor_vdu_stream_end = &37BC
ASSERT advance_bcd_counter_and_print_source_end = &37CD
COPYBLOCK advance_bcd_counter_and_print_source, advance_bcd_counter_and_print_source_end, &4F6F

; Runtime $376F-$37CC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4F6F-$4FCC.
CLEAR advance_bcd_counter_and_print_source, advance_bcd_counter_and_print_source_end


ORG shift_four_row_display_block_right

; Across four Mode 1 character rows, shift the eight cells of one room-cell
; graphic one cell to the right. On each scanline, copy columns seven through
; zero into columns eight through one, clear column zero, then advance
; display_pointer by one complete Mode 1 character row.
.shift_four_row_display_block_right_source
    LDA #DISPLAY_SHIFT_CHARACTER_ROW_COUNT
    STA display_shift_character_rows_remaining

.shift_next_character_row
    LDA #MODE1_CHARACTER_SCANLINE_COUNT
    STA display_shift_scanlines_remaining

.shift_next_display_scanline
    LDX #ROOM_CELL_TILE_COUNT
    LDY #DISPLAY_SHIFT_LAST_SOURCE_CELL_OFFSET

.copy_next_cell_right
    LDA (display_pointer_low),Y
    PHA
    TYA
    CLC
    ADC #MODE1_CELL_COLUMN_BYTES
    TAY
    PLA
    STA (display_pointer_low),Y
    SEC
    TYA
    SBC #DISPLAY_SHIFT_REVERSE_CELL_STEP
    TAY
    DEX
    BNE copy_next_cell_right
    LDA #&00
    TAY
    STA (display_pointer_low),Y
    INC display_pointer_low
    BNE advance_to_next_scanline
    INC display_pointer_high

.advance_to_next_scanline
    DEC display_shift_scanlines_remaining
    BNE shift_next_display_scanline
    CLC
    LDA display_pointer_low
    ADC #LO(MODE1_CHARACTER_ROW_BYTES-MODE1_CHARACTER_SCANLINE_COUNT)
    STA display_pointer_low
    LDA display_pointer_high
    ADC #HI(MODE1_CHARACTER_ROW_BYTES-MODE1_CHARACTER_SCANLINE_COUNT)
    STA display_pointer_high
    DEC display_shift_character_rows_remaining
    BNE shift_next_character_row
    RTS
.shift_four_row_display_block_right_source_end

ASSERT shift_four_row_display_block_right_source = shift_four_row_display_block_right
ASSERT shift_four_row_display_block_right_source_end = &376F
COPYBLOCK shift_four_row_display_block_right_source, shift_four_row_display_block_right_source_end, &4F2F

; Runtime $372F-$376E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4F2F-$4F6E.
CLEAR shift_four_row_display_block_right_source, shift_four_row_display_block_right_source_end


ORG initialise_room_enemy_from_table

; Find the entity record for the current room and unpack it
; into every field the entity system reads.
; room_enemy_record_table holds ROOM_ENEMY_RECORD_COUNT records of
; ROOM_ENEMY_RECORD_BYTES. The first two bytes are decoded by
; match_packed_record_against_references into active_enemy_last_slot_index and
; active_enemy_species.
; The remaining four bytes are two grid positions, each read, scaled by eight
; into named movement limits and converted to the two room-enemy display
; pointers. The species selects one four-byte frame-pointer descriptor, unless
; the descriptor override selects the jellyfish pair. Finally the two signed
; movement-delta slots are seeded from their indexes.
; Everything written here is read back by routines this source already owns:
; the limits by both delta clamps, the pointers by collision probes, the moving
; entity positions by the pair loader, and the species/slot fields by drawing.
;
; This is the room-local enemy table, not the cross-room robot/ghost table. The
; chain is: this routine writes the active species,
; last slot, position and display pointer; draw_room_enemy_with_xor_graphic reads them;
; and suppressing that renderer was tested in play and made the enemy robots
; disappear while leaving the lifts alone. Every one of the twenty records
; resolves to a room inside the grid, and the set contains every room the
; player's account calls out for an enemy.
;
; active_enemy_species selects a four-byte graphic descriptor. The selected
; graphic pairs and their rooms are
;   bat                       B5 D0 A1 G2 E3 D6
;   small bouncing robot      C3 F1 C1 B3 B6 E2 A2 C7
;   moth                      C5 E5 F4 E4 H7 D7
; See analysis/room_map.md for the rooms alongside what the account says of
; them. These are decoded graphic identities; the shared state machine means a
; visual identity alone must not be used to infer movement or collision rules.
.initialise_room_enemy_from_table_source
    LDX #ROOM_ENEMY_FIRST_RECORD_INDEX
    LDA #LO(room_enemy_record_table)
    STA packed_record_pointer_low
    LDA #HI(room_enemy_record_table)
    STA packed_record_pointer_high

.test_next_entity_record
    TXA
    ASL A
    CLC
    STA packed_record_index_scaled
    TXA
    ADC packed_record_index_scaled
    ASL A
    TAY
    JSR match_packed_record_against_references
    BCS unpack_matched_entity_record
    INX
    CPX #ROOM_ENEMY_RECORD_COUNT
    BNE test_next_entity_record
    RTS

.unpack_matched_entity_record
    LDA packed_record_even_field
    STA active_enemy_last_slot_index
    LDA packed_record_type_field
    STA active_enemy_species
    LDA #ROOM_ENEMY_ACTIVE
    STA room_tick_update_selector
    INY
    LDA room_enemy_record_table,Y
    STA display_grid_row
    ASL A
    ASL A
    ASL A
    STA enemy_vertical_lower_limit
    STA room_enemy_vertical_position
    INY
    LDA room_enemy_record_table,Y
    STA enemy_horizontal_lower_limit
    CLC
    ADC #ENEMY_FIRST_HORIZONTAL_BIAS
    STA display_grid_column
    STA moving_entity_horizontal_position
    JSR set_display_pointer_from_grid_position
    LDA display_pointer_low
    STA room_enemy_display_pointer_low
    LDA display_pointer_high
    STA room_enemy_display_pointer_high
    INY
    LDA room_enemy_record_table,Y
    SEC
    SBC #ENEMY_SECOND_VERTICAL_BIAS
    STA display_grid_row
    ASL A
    ASL A
    ASL A
    STA enemy_initial_vertical_position
    LDA room_enemy_record_table,Y
    ASL A
    ASL A
    ASL A
    STA enemy_vertical_upper_limit
    INY
    LDA room_enemy_record_table,Y
    STA enemy_horizontal_upper_limit
    SEC
    SBC #ENEMY_SECOND_HORIZONTAL_BIAS
    STA display_grid_column
    STA moving_entity_second_horizontal_position
    JSR set_display_pointer_from_grid_position
    LDA display_pointer_low
    STA room_enemy_second_display_pointer_low
    LDA display_pointer_high
    STA room_enemy_second_display_pointer_high
    LDY #WATER_ENEMY_JELLYFISH_DESCRIPTOR_OFFSET
    LDA water_environment_flag
    BNE copy_entity_descriptor
    LDA active_enemy_species
    ASL A
    ASL A
    TAY

.copy_entity_descriptor
    LDX #&00

.copy_next_descriptor_byte
    LDA enemy_graphic_descriptor_table,Y
    STA enemy_graphic_descriptor,X
    INX
    INY
    CPX #ENEMY_GRAPHIC_DESCRIPTOR_BYTES
    BNE copy_next_descriptor_byte
    LDX #ENEMY_DELTA_SEED_FIRST_INDEX

.seed_entity_deltas
    TXA
    STA room_tick_update_selector,X
    STA enemy_vertical_delta,X
    INX
    CPX #ENEMY_DELTA_SEED_END_INDEX
    BNE seed_entity_deltas
    RTS
.initialise_room_enemy_from_table_source_end

ASSERT initialise_room_enemy_from_table_source = initialise_room_enemy_from_table
ASSERT initialise_room_enemy_from_table_source_end = &1FDF
COPYBLOCK initialise_room_enemy_from_table_source, initialise_room_enemy_from_table_source_end, &372F

; Runtime $1F2F-$1FDE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $372F-$37DE.
CLEAR initialise_room_enemy_from_table_source, initialise_room_enemy_from_table_source_end


ORG initialise_lifts_and_hazards_from_table

; Initialise the room's vertical lifts or moth-shaped
; hazards from their dedicated table and state fields.
; lift_and_hazard_room_record_table holds LIFT_HAZARD_RECORD_COUNT records of
; LIFT_HAZARD_RECORD_BYTES. The packed match supplies the slot limit and class;
; the other fields supply the horizontal extent and two vertical limits. Those
; coordinates are converted into the initial slot positions and display
; pointers. The selected four-byte frame descriptor is copied beside the active
; room-enemy descriptor.
;
; This is the table the moving platforms and the room hazards come from.
; Suppressing its renderer, xor_draw_lift_or_hazard, was tested in play and made
; the vertical lifts disappear while leaving the enemy robots alone.
;
; active_lift_or_hazard_class decides which of the two a room gets.
; test_lift_or_hazard_hit_player charges energy only for the hazard class, and
; update_lift_or_hazard_by_class
; sends LIFT_OR_HAZARD_HAZARD to the player-overlap test and a lift to
; apply_moving_entity_to_player, which carries or pushes the player instead of
; hurting them. Decoding all twenty records splits them
;   LIFT_OR_HAZARD_LIFT, carries the player      A4 B2 B6
;   LIFT_OR_HAZARD_HAZARD, moth-shaped and hurts G2 A1 B3 C0 G8 F0 E8 E5 G8
;                                                G5 H7 H4 E3 C2 E6 B8 D5
; so only three rooms hold a platform of this class and seventeen hold a
; hazard, and G8 holds two. The renderer draws both alike; only contact
; differs.
.initialise_lifts_and_hazards_from_table_source
    LDA #LO(lift_and_hazard_room_record_table)
    STA packed_record_pointer_low
    LDA #HI(lift_and_hazard_room_record_table)
    STA packed_record_pointer_high
    LDX #&00

.test_next_lift_or_hazard_record
    TXA
    ASL A
    ASL A
    STA packed_record_index_scaled
    TXA
    ADC packed_record_index_scaled
    TAY
    JSR match_packed_record_against_references
    BCS unpack_matched_lift_or_hazard_record
    INX
    CPX #LIFT_HAZARD_RECORD_COUNT
    BNE test_next_lift_or_hazard_record
    RTS

.unpack_matched_lift_or_hazard_record
    LDA packed_record_even_field
    CLC
    ADC #LIFT_HAZARD_SLOT_INDEX_BIAS
    STA lift_and_hazard_slot_limit
    LDA packed_record_type_field
    STA active_lift_or_hazard_class
    LDA #&01
    STA lift_and_hazard_active
    INY
    LDA lift_and_hazard_room_record_table,Y
    STA lift_or_hazard_horizontal_extent
    SEC
    SBC #LIFT_HAZARD_FIRST_COLUMN_BIAS
    STA display_grid_column
    INY
    LDA lift_and_hazard_room_record_table,Y
    STA display_grid_row
    ASL A
    ASL A
    ASL A
    STA lift_or_hazard_lower_position
    STA lift_hazard_slot_10_position
    JSR set_display_pointer_from_grid_position
    LDA display_pointer_low
    STA lift_hazard_slot_10_display_pointer_low
    LDA display_pointer_high
    STA lift_hazard_slot_10_display_pointer_high
    LDA lift_or_hazard_horizontal_extent
    STA display_grid_column
    INY
    LDA lift_and_hazard_room_record_table,Y
    SEC
    SBC #LIFT_HAZARD_SECOND_ROW_BIAS
    STA display_grid_row
    ASL A
    ASL A
    ASL A
    STA lift_hazard_slot_8_position
    ADC #LIFT_HAZARD_UPPER_POSITION_SPAN
    STA lift_or_hazard_upper_position
    JSR set_display_pointer_from_grid_position
    LDA display_pointer_low
    STA lift_hazard_slot_8_display_pointer_low
    LDA display_pointer_high
    STA lift_hazard_slot_8_display_pointer_high
    LDA #LIFT_HAZARD_INITIAL_STEP
    STA lift_hazard_slot_8_delta
    STA lift_hazard_slot_10_delta
.copy_lift_or_hazard_descriptor_for_active_class
    LDA active_lift_or_hazard_class
    ASL A
    ASL A
    TAY
    LDX #LIFT_HAZARD_FIRST_RECORD_INDEX

.copy_next_lift_or_hazard_descriptor_byte
    LDA lift_and_hazard_graphic_descriptor_table,Y
    STA lift_and_hazard_graphic_descriptor,X
    INY
    INX
    CPX #LIFT_HAZARD_DESCRIPTOR_BYTES
    BNE copy_next_lift_or_hazard_descriptor_byte
    RTS
.initialise_lifts_and_hazards_from_table_source_end

ASSERT initialise_lifts_and_hazards_from_table_source = initialise_lifts_and_hazards_from_table
ASSERT initialise_lifts_and_hazards_from_table_source_end = &2082
COPYBLOCK initialise_lifts_and_hazards_from_table_source, initialise_lifts_and_hazards_from_table_source_end, &37EF

; Runtime $1FEF-$2081 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $37EF-$3881.
CLEAR initialise_lifts_and_hazards_from_table_source, initialise_lifts_and_hazards_from_table_source_end


ORG run_terminal_interaction

; Draw the terminal room using temporary reference and
; room-pointer values, then restore the caller's four bytes and interpret the
; control-marked terminal text stream. Ordinary bytes go to OSWRCH. Its named
; command bytes end the interaction, test for the access card, process password
; input, or display the collected-password list.
.run_terminal_interaction_source
    LDA reference_pair_primary_value
    CLC
    ADC #TERMINAL_NUMBER_CHARACTER_BIAS
    STA terminal_number_character
    LDA reference_pair_primary_value
    PHA
    LDA reference_pair_secondary_value
    PHA
    LDA level_room_map_offset_low
    PHA
    LDA level_room_map_offset_high
    PHA
    LDA #TERMINAL_DISPLAY_ROOM_COLUMN
    STA reference_pair_primary_value
    LDA #TERMINAL_DISPLAY_ROOM_LEVEL
    STA reference_pair_secondary_value
    LDA #LO(TERMINAL_DISPLAY_LEVEL_MAP_OFFSET)
    STA level_room_map_offset_low
    LDA #HI(TERMINAL_DISPLAY_LEVEL_MAP_OFFSET)
    STA level_room_map_offset_high
    JSR draw_and_initialise_room
    PLA
    STA level_room_map_offset_high
    PLA
    STA level_room_map_offset_low
    PLA
    STA reference_pair_secondary_value
    PLA
    STA reference_pair_primary_value
    LDX #TERMINAL_RESULT_NONE
    STX terminal_interaction_result

.terminal_stream_next_byte
    LDA terminal_interaction_text_stream,X
    CMP #TERMINAL_STREAM_END
    BEQ terminal_stream_end
    CMP #TERMINAL_STREAM_ACCESS_CARD_TEST
    BEQ terminal_stream_access_card_marker
    CMP #TERMINAL_STREAM_PASSWORD_INPUT
    BEQ process_terminal_password_markers
    CMP #TERMINAL_STREAM_PASSWORD_LIST
    BEQ terminal_password_list_marker
    JSR OSWRCH
    INX
    JMP terminal_stream_next_byte

.terminal_stream_end
    LDX #TERMINAL_RESULT_SOUND_PARAMETER
    STX sound_block_duration
    STX sound_block_pitch
    LDA terminal_interaction_result
    JSR play_sound_with_amplitude

.wait_for_terminal_space_release
    LDX #INKEY_SPACE
    LDA #OSBYTE_INKEY
    LDY #OSBYTE_INKEY_KEYBOARD_SCAN_Y
    JSR OSBYTE
    BCC wait_for_terminal_space_release
    JSR draw_and_initialise_room
    LDA terminal_interaction_result
    BEQ terminal_interaction_no_result_exit
    LDA #ROOM_UPDATE_SUPPRESSION_CLEAR
    STA room_update_suppression_state

.terminal_return_carry_clear
    CLC
    RTS

.terminal_stream_access_card_marker
    LDA #ITEM_CODE_ACCESS_CARD
    JSR test_item_code_matches_either_slot
    BCS terminal_access_card_present
    LDX #TERMINAL_ACCESS_DENIED_STREAM_OFFSET
    JMP terminal_stream_next_byte

.terminal_access_card_present
    INX
    JMP terminal_stream_next_byte
.run_terminal_interaction_source_end

ASSERT run_terminal_interaction_source = run_terminal_interaction
ASSERT run_terminal_interaction_source_end = test_item_code_matches_either_slot
COPYBLOCK run_terminal_interaction_source, run_terminal_interaction_source_end, &38B3

; Runtime $20B3-$213B overlaps the loaded transport image. Release it after
; copying its bytes to loaded $38B3-$393B.
CLEAR run_terminal_interaction_source, run_terminal_interaction_source_end

ORG lift_and_hazard_graphic_descriptor_table
; Two pairs of sprite-frame pointers selected by lift/hazard class.
.lift_and_hazard_graphic_descriptor_table_source
.vertical_lift_graphic_descriptor
    EQUW vertical_lift_graphic, vertical_lift_graphic ; LIFT_OR_HAZARD_LIFT
.moth_hazard_graphic_descriptor
    EQUW runtime_moth_and_hazard_frame_0, runtime_moth_and_hazard_frame_1 ; LIFT_OR_HAZARD_HAZARD
.lift_and_hazard_graphic_descriptor_table_source_end
ASSERT vertical_lift_graphic_descriptor = lift_and_hazard_graphic_descriptor_table + LIFT_OR_HAZARD_LIFT*LIFT_HAZARD_DESCRIPTOR_BYTES
ASSERT moth_hazard_graphic_descriptor = lift_and_hazard_graphic_descriptor_table + LIFT_OR_HAZARD_HAZARD*LIFT_HAZARD_DESCRIPTOR_BYTES
ASSERT lift_and_hazard_graphic_descriptor_table_source = lift_and_hazard_graphic_descriptor_table
ASSERT lift_and_hazard_graphic_descriptor_table_source_end = match_packed_record_against_references
COPYBLOCK lift_and_hazard_graphic_descriptor_table_source, lift_and_hazard_graphic_descriptor_table_source_end, &3882
CLEAR lift_and_hazard_graphic_descriptor_table_source, lift_and_hazard_graphic_descriptor_table_source_end

ORG terminal_interaction_result
; Mutable result byte initialised to zero in the loaded image.
.terminal_interaction_result_source
    EQUB &00
.terminal_interaction_result_source_end
ASSERT terminal_interaction_result_source = terminal_interaction_result
ASSERT terminal_interaction_result_source_end = run_terminal_interaction
COPYBLOCK terminal_interaction_result_source, terminal_interaction_result_source_end, &38B2
CLEAR terminal_interaction_result_source, terminal_interaction_result_source_end

ORG horizontal_band_velocity_step_table
; Signed vertical step for each sixteen-unit horizontal room band.
.horizontal_band_velocity_step_table_source
    EQUB &01, &FF, &02, &FE, &03
.horizontal_band_velocity_step_table_source_end
ASSERT horizontal_band_velocity_step_table_source = horizontal_band_velocity_step_table
ASSERT horizontal_band_velocity_step_table_source_end = advance_bounded_tick_target
COPYBLOCK horizontal_band_velocity_step_table_source, horizontal_band_velocity_step_table_source_end, &3CF4
CLEAR horizontal_band_velocity_step_table_source, horizontal_band_velocity_step_table_source_end

ORG unused_ghost_update_return
; Unreachable RTS separating the two ghost-update routine bodies.
.unused_ghost_update_return_source
    RTS
.unused_ghost_update_return_source_end
ASSERT unused_ghost_update_return_source = unused_ghost_update_return
ASSERT unused_ghost_update_return_source_end = apply_ghost_player_axis_mode
COPYBLOCK unused_ghost_update_return_source, unused_ghost_update_return_source_end, &4882
CLEAR unused_ghost_update_return_source, unused_ghost_update_return_source_end

ORG energy_bar_fill_patterns
; Four partial energy-bar fill masks, indexed by (energy AND 7) / 2.
.energy_bar_fill_patterns_source
    EQUB &00, &08, &0C, &0E
.energy_bar_fill_patterns_source_end
ASSERT energy_bar_fill_patterns_source = energy_bar_fill_patterns
ASSERT energy_bar_fill_patterns_source_end = cross_room_robot_ghost_initial_state
COPYBLOCK energy_bar_fill_patterns_source, energy_bar_fill_patterns_source_end, &3A22
CLEAR energy_bar_fill_patterns_source, energy_bar_fill_patterns_source_end

ORG cross_room_robot_ghost_initial_state
; Initial zeroed scratch followed by the two interleaved cross-room robot/ghost records.
; The final three interleaved bytes initialise delta/mode/delta to $FE/$00/$FE.
.cross_room_robot_ghost_initial_state_source
    EQUB &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00
    EQUB &FE, &00, &FE
.cross_room_robot_ghost_initial_state_source_end
ASSERT cross_room_robot_ghost_initial_state_source = cross_room_robot_ghost_initial_state
ASSERT cross_room_robot_ghost_initial_state_source_end = run_game_tick_with_player_contact_flag_cleared
COPYBLOCK cross_room_robot_ghost_initial_state_source, cross_room_robot_ghost_initial_state_source_end, &3A26
CLEAR cross_room_robot_ghost_initial_state_source, cross_room_robot_ghost_initial_state_source_end

ORG last_chance_chord_inkey_codes
; Six OSBYTE $81 negative key numbers, tested from the last entry to the first.
.last_chance_chord_inkey_codes_source
    EQUB &DD, &CC, &DC, &BE, &AA, &DA
.last_chance_chord_inkey_codes_source_end
ASSERT last_chance_chord_inkey_codes_source = last_chance_chord_inkey_codes
ASSERT last_chance_chord_inkey_codes_source_end = poll_controls_and_apply_gameplay_actions
COPYBLOCK last_chance_chord_inkey_codes_source, last_chance_chord_inkey_codes_source_end, &3E54
CLEAR last_chance_chord_inkey_codes_source, last_chance_chord_inkey_codes_source_end

ORG effect_room_appearance_indices
; Four room-appearance table offsets selected by primary reference zero-three.
.effect_room_appearance_indices_source
    EQUB &38, &01, &32, &23
.effect_room_appearance_indices_source_end
ASSERT effect_room_appearance_indices_source = effect_room_appearance_indices
ASSERT effect_room_appearance_indices_source_end = &3175
COPYBLOCK effect_room_appearance_indices_source, effect_room_appearance_indices_source_end, &4971
CLEAR effect_room_appearance_indices_source, effect_room_appearance_indices_source_end

ORG terminal_activation_records
; Eight little-endian destination pointer plus value records. Zero records are
; intentional no-op writes through address zero when selected.
.terminal_activation_records_source
    EQUW room_B0_row_1_cell_1
    EQUB &58
    EQUW NULL_POINTER
    EQUB &00
    EQUW room_B9_row_2_cell_1
    EQUB &3E
    EQUW room_D6_row_0_cell_0
    EQUB &6E
    EQUW NULL_POINTER
    EQUB &00
    EQUW room_F3_row_1_cell_1
    EQUB &0A
    EQUW NULL_POINTER
    EQUB &00
    EQUW NULL_POINTER
    EQUB &00
.terminal_activation_records_source_end
ASSERT terminal_activation_records_source = terminal_activation_records
ASSERT terminal_activation_records_source_end = restore_item_and_goal_records
COPYBLOCK terminal_activation_records_source, terminal_activation_records_source_end, &4A2D
CLEAR terminal_activation_records_source, terminal_activation_records_source_end

ORG status_panel_alignment_padding
; Zero alignment byte between the status-panel divider and warp routine.
.status_panel_alignment_padding_source
    EQUB &00
.status_panel_alignment_padding_source_end
ASSERT status_panel_alignment_padding_source = status_panel_alignment_padding
ASSERT status_panel_alignment_padding_source_end = warp_to_room_3_4
COPYBLOCK status_panel_alignment_padding_source, status_panel_alignment_padding_source_end, &49FF
CLEAR status_panel_alignment_padding_source, status_panel_alignment_padding_source_end

ORG warp_entry_alignment_nop
; Unreachable alignment NOP before write_indexed_terminal_activation_value.
.warp_entry_alignment_nop_source
    NOP
.warp_entry_alignment_nop_source_end
ASSERT warp_entry_alignment_nop_source = warp_entry_alignment_nop
ASSERT warp_entry_alignment_nop_source_end = write_indexed_terminal_activation_value
COPYBLOCK warp_entry_alignment_nop_source, warp_entry_alignment_nop_source_end, &4A13
CLEAR warp_entry_alignment_nop_source, warp_entry_alignment_nop_source_end

ORG item_restore_alignment_nop
; Unreachable alignment NOP between item restoration and the inline printer.
.item_restore_alignment_nop_source
    NOP
.item_restore_alignment_nop_source_end
ASSERT item_restore_alignment_nop_source = item_restore_alignment_nop
ASSERT item_restore_alignment_nop_source_end = print_inline_vdu_stream
COPYBLOCK item_restore_alignment_nop_source, item_restore_alignment_nop_source_end, &4A55
CLEAR item_restore_alignment_nop_source, item_restore_alignment_nop_source_end

ORG inline_printer_alignment_padding
; Two zero alignment bytes before stamp_map_bytes_and_store.
.inline_printer_alignment_padding_source
    EQUB &00, &00
.inline_printer_alignment_padding_source_end
ASSERT inline_printer_alignment_padding_source = inline_printer_alignment_padding
ASSERT inline_printer_alignment_padding_source_end = stamp_map_bytes_and_store
COPYBLOCK inline_printer_alignment_padding_source, inline_printer_alignment_padding_source_end, &4A7E
CLEAR inline_printer_alignment_padding_source, inline_printer_alignment_padding_source_end

ORG sound_block_channel
; Initial MOS SOUND parameter bytes. The duration low byte is explicit here;
; its high byte at $32A7 is also the first opcode of
; test_display_pointer_in_xor_draw_window, an intentional code/data overlap.
.initial_sound_parameter_block_source
    EQUW &0001, &FF0F, &0000
    EQUB &00
.initial_sound_parameter_block_source_end
ASSERT initial_sound_parameter_block_source = sound_block_channel
ASSERT initial_sound_parameter_block_source_end = test_display_pointer_in_xor_draw_window
COPYBLOCK initial_sound_parameter_block_source, initial_sound_parameter_block_source_end, &4AA0
CLEAR initial_sound_parameter_block_source, initial_sound_parameter_block_source_end

ORG music_tune_progress
; Mutable new-game tune progress, initially zero.
.music_tune_progress_source
    EQUB &00
.music_tune_progress_source_end
ASSERT music_tune_progress_source = music_tune_progress
ASSERT music_tune_progress_source_end = &32C0
COPYBLOCK music_tune_progress_source, music_tune_progress_source_end, &4ABF
CLEAR music_tune_progress_source, music_tune_progress_source_end

ORG place_initial_map_objects

; Write the mutable starting cell types into named locations in the room map.
; This straight-line initialiser stamps twelve centered slopes, three $FF-state
; motifs, both key motifs, and the remaining named layouts. It runs once from
; initialise_new_game before the first room is drawn.
; The Music Room location starts as ROOM_CELL_MUSIC_ROOM_SIGN;
; play_note_for_position_and_test_tune replaces it with
; ROOM_CELL_PASSWORD_PROMPT when the twelve-note tune is completed.
.place_initial_map_objects_source
    LDA #ROOM_CELL_CENTERED_SLOPE
    STA room_B0_row_1_cell_0
    STA room_F1_row_1_cell_0
    STA room_A2_row_2_cell_2
    STA room_E2_row_1_cell_1
    STA room_H3_row_1_cell_0
    STA room_C3_row_0_cell_3
    STA room_H4_row_0_cell_2
    STA room_G5_row_1_cell_4
    STA room_G6_row_0_cell_4
    STA room_C7_row_2_cell_3
    STA room_G9_row_0_cell_3
    STA room_B9_row_2_cell_2
    LDA #ROOM_CELL_FF_STATE_MOTIF
    STA room_G0_row_2_cell_4
    STA room_E1_row_1_cell_4
    STA room_G3_row_1_cell_4
    LDX #ROOM_CELL_FIRST_KEY_MOTIF
    STX room_A4_row_1_cell_2
    STX room_A6_row_1_cell_3
    STX room_A0_row_1_cell_4
    INX
    STX room_F8_row_2_cell_3
    LDA #ROOM_CELL_FOUR_TILE_HALF_ROW
    STA room_H2_row_1_cell_1
    STA room_D5_row_2_cell_0
    LDA #ROOM_CELL_ALTERNATING_RIGHT_HALF
    STA room_H2_row_1_cell_3
    STA room_F5_row_2_cell_4
    STA room_D5_row_2_cell_2
    LDA #ROOM_CELL_BORDERED_CHECKER
    STA room_F3_row_1_cell_1
    STA room_F3_row_1_cell_3
    LDA #ROOM_CELL_MIRRORED_FF_LAST_COLUMN
    STA room_D4_row_2_cell_2
    STA room_C6_row_2_cell_2
    STA room_A7_row_2_cell_2
    LDA #ROOM_CELL_MUSIC_ROOM_SIGN
    STA room_E1_row_0_cell_1
    LDA #ROOM_CELL_ORACLE_SIGN
    STA room_A9_row_1_cell_2
    LDA #ROOM_CELL_TRANSITION_3C
    STA room_F5_row_2_cell_2
    LDA #ROOM_CELL_ALTERNATING_RIGHT_HALF
    STA room_D6_row_0_cell_0
    LDA #ROOM_CELL_RIGHT_EDGE_OR_FULL
    STA room_B9_row_2_cell_1
    RTS
.place_initial_map_objects_source_end

ASSERT place_initial_map_objects_source = place_initial_map_objects
ASSERT place_initial_map_objects_source_end = &0800
COPYBLOCK place_initial_map_objects_source, place_initial_map_objects_source_end, &2080

; Runtime $0780-$07FF overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2080-$20FF.
CLEAR place_initial_map_objects_source, place_initial_map_objects_source_end


ORG apply_player_energy_delta_to_budget

; Compare the saved and live player energy. If unchanged,
; reset player_energy_delta_budget to twelve. Otherwise synchronise the snapshot
; and subtract the observed change from that budget. A non-negative result
; returns to the gameplay loop; a negative result also seeds
; slow_damage_countdown before falling into the scripted player walk.
.apply_player_energy_delta_to_budget_source
    SEC
    LDA player_energy_snapshot
    SBC player_energy
    BEQ reset_player_energy_delta_budget
    STA observed_player_energy_delta
    LDA player_energy
    STA player_energy_snapshot
    SEC
    LDA player_energy_delta_budget
    SBC observed_player_energy_delta
    STA player_energy_delta_budget
    BPL return_without_energy_budget_update
    STA slow_damage_countdown
.apply_player_energy_delta_to_budget_source_end

ASSERT apply_player_energy_delta_to_budget_source = apply_player_energy_delta_to_budget
ASSERT apply_player_energy_delta_to_budget_source_end = continue_after_negative_energy_delta_budget
COPYBLOCK apply_player_energy_delta_to_budget_source, apply_player_energy_delta_to_budget_source_end, &3DC4

; Release the runtime range after copying it into the loaded transport image.
CLEAR apply_player_energy_delta_to_budget_source, apply_player_energy_delta_to_budget_source_end

ORG osbyte_81_inkey

; X supplies the negative BBC key number. Select OSBYTE
; function $81 with Y=$FF, then tail-call the MOS so its key result returns
; directly to the original caller.
.osbyte_81_inkey_source
    LDY #OSBYTE_INKEY_KEYBOARD_SCAN_Y
    LDA #OSBYTE_INKEY
    JMP OSBYTE
.osbyte_81_inkey_source_end

ASSERT osbyte_81_inkey_source = osbyte_81_inkey
ASSERT osbyte_81_inkey_source_end = &2797
COPYBLOCK osbyte_81_inkey_source, osbyte_81_inkey_source_end, &3F90

; Runtime $2790-$2796 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3F90-$3F96.
CLEAR osbyte_81_inkey_source, osbyte_81_inkey_source_end

ORG advance_record_counter_then_dispatch

; Increment lift_hazard_secondary_record_counter, copy it
; into lift_hazard_update_schedule_mask, preset the final indexed slot, and dispatch
; through update_lift_or_hazard_from_preselected_slot. Successive calls therefore
; step through consecutive records.
.advance_record_counter_then_dispatch_source
    LDY #&08
    INC lift_hazard_secondary_record_counter
    LDA lift_hazard_secondary_record_counter
    STA lift_hazard_update_schedule_mask
    JMP update_lift_or_hazard_from_preselected_slot
.advance_record_counter_then_dispatch_source_end

ASSERT advance_record_counter_then_dispatch_source = advance_record_counter_then_dispatch
ASSERT advance_record_counter_then_dispatch_source_end = &2401
COPYBLOCK advance_record_counter_then_dispatch_source, advance_record_counter_then_dispatch_source_end, &3BF6

; Runtime $23F6-$2400 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3BF6-$3C00.
CLEAR advance_record_counter_then_dispatch_source, advance_record_counter_then_dispatch_source_end


ORG store_byte_through_saved_pointer

; Write A through indirect_write_pointer, indexed by
; saved_cell_write_offset. save_display_pointer_and_cell_reference captures
; both values from the current room-cell traversal before this write is used.
.store_byte_through_saved_pointer_source
    LDY saved_cell_write_offset
    STA (indirect_write_pointer_low),Y
    RTS
.store_byte_through_saved_pointer_source_end

ASSERT store_byte_through_saved_pointer_source = store_byte_through_saved_pointer
ASSERT store_byte_through_saved_pointer_source_end = &2453
COPYBLOCK store_byte_through_saved_pointer_source, store_byte_through_saved_pointer_source_end, &3C4E

; Runtime $244E-$2452 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3C4E-$3C52.
CLEAR store_byte_through_saved_pointer_source, store_byte_through_saved_pointer_source_end


ORG game_entry_jump_table

; A fixed-address table of three-byte JMP vectors, giving
; callers a stable entry for each gameplay routine regardless of where that
; routine moves. Seven of the eleven vectors are observed being taken, and four
; of them dispatch into routines this source already owns. The $221E NOP is
; table padding, not a reached instruction, and the table ends at $2221; $2222
; is data.
.game_entry_jump_table_source
    JMP main_gameplay_loop

    JMP test_player_in_range_and_set_direction

    JMP check_player_candidate_bounds_overlap

    JMP scan_four_display_bytes_for_markers

    JMP scan_display_column_for_blocking_byte

    JMP adjust_display_pointer_then_scan_markers

    JMP consume_matching_item_from_slots

    JMP test_range_with_supplied_box

    JMP draw_lift_or_hazard_without_slot_check

    JMP dispatch_game_tick_updates
    NOP

    JMP initialise_cross_room_robot_ghost_from_record
.game_entry_jump_table_source_end

ASSERT game_entry_jump_table_source = game_entry_jump_table
ASSERT game_entry_jump_table_source_end = &2222
COPYBLOCK game_entry_jump_table_source, game_entry_jump_table_source_end, &3A00

; Runtime $2200-$2221 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3A00-$3A21.
CLEAR game_entry_jump_table_source, game_entry_jump_table_source_end


ORG update_lift_and_hazard_slots

; Update the lift/hazard slots on a schedule driven
; by a rolling counter.
; lift_hazard_primary_record_counter is incremented once per call and copied
; into lift_hazard_update_schedule_mask: after the first three slots are updated
; unconditionally, each further slot is updated only when the next bit rotated
; out of that selector is set. So slots beyond the third take turns across frames rather
; than all moving every frame, which spreads the work.
; Y indexes the slots and advances by two between them, so each entity occupies
; a two-byte pair in the moving-entity delta, position and display-pointer
; arrays. The draws that bracket the group use the no-slot-check renderer entry.
.update_lift_and_hazard_slots_source
    INC lift_hazard_primary_record_counter
    LDA lift_hazard_primary_record_counter
    STA lift_hazard_update_schedule_mask
    LDY #LIFT_HAZARD_FIRST_SLOT_INDEX
.update_lift_or_hazard_from_preselected_slot
    JSR draw_lift_or_hazard_without_slot_check
    JSR update_one_lift_or_hazard
    JSR update_one_lift_or_hazard
    JSR draw_lift_or_hazard_without_slot_check
    INY
    INY
    JSR update_one_lift_or_hazard
    INY
    INY
    ROR lift_hazard_update_schedule_mask
    BCC test_next_scheduled_slot
    JMP update_one_lift_or_hazard

.test_next_scheduled_slot
    INY
    INY
    ROR lift_hazard_update_schedule_mask
    BCC entity_update_loop_exit
.update_lift_and_hazard_slots_source_end

ASSERT update_lift_and_hazard_slots_source = update_lift_and_hazard_slots
ASSERT update_lift_and_hazard_slots_source_end = &22FE
COPYBLOCK update_lift_and_hazard_slots_source, update_lift_and_hazard_slots_source_end, &3AD6

; Runtime $22D6-$22FD overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3AD6-$3AFD.
CLEAR update_lift_and_hazard_slots_source, update_lift_and_hazard_slots_source_end


ORG update_one_lift_or_hazard

; Update one lift or moth-shaped hazard: erase, clamp, act on the
; player, step, redraw.
; The order matters. The entity is drawn once before it moves and once after,
; and because the renderer is XOR the first call erases it from where it was.
; Between the two, its delta is clamped at the range limits, its effect on the
; player applied, and the signed step taken.
; The final draw is a tail jump rather than a call, so the redraw returns
; straight to this routine caller.
.update_one_lift_or_hazard_source
    JSR reverse_lift_or_hazard_delta_at_limits
    JSR xor_draw_lift_or_hazard
    JSR apply_moving_entity_to_player
    JSR advance_lift_or_hazard_vertical_position
    JMP xor_draw_lift_or_hazard
.update_one_lift_or_hazard_source_end

ASSERT update_one_lift_or_hazard_source = update_one_lift_or_hazard
ASSERT update_one_lift_or_hazard_source_end = &230D
COPYBLOCK update_one_lift_or_hazard_source, update_one_lift_or_hazard_source_end, &3AFE

; Runtime $22FE-$230C overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3AFE-$3B0C.
CLEAR update_one_lift_or_hazard_source, update_one_lift_or_hazard_source_end


ORG apply_moving_entity_to_player

; Let one moving entity act on the player, in whichever
; direction it is travelling.
; The entity delta at $18 selects the case. A delta of $FE means it is rising:
; its display pointer at $51/$52 is scanned for markers directly, and if $235C
; reports the player is in the way, one upward step is applied to the player
; through the $28AE entry with a count of 1.
; Any other delta means it is descending: the pointer is taken one Mode 1
; character row below instead, the four-byte marker scan runs there, and a
; positive report sets player_contact_or_damage_flag, forces an upward player
; velocity and calls the downward mover.
; So the entity pushes the player the way it is going, one step at a time, which
; is what a moving platform or a crusher does. Either path then checks $0B, and
; a nonzero value costs energy through the damage routine.
;
; This is the path a class other than 1 takes, so this is the moving platform
; behaviour proper: A4, B2 and B6 are the three rooms whose record selects it.
; A rising platform lifts the player through the $28AE entry and a descending
; one drives them down, which is why the same routine serves a lift and a
; crusher.
; Y is preserved across the whole thing, so the caller can walk its entities.
.apply_moving_entity_to_player_source
    TYA
    PHA
    LDA moving_entity_delta,Y
    CMP #&FE
    BNE entity_descending
    LDA moving_entity_display_pointer_low,Y
    STA display_pointer_low
    LDA moving_entity_display_pointer_high,Y
    STA display_pointer_high
    JSR adjust_display_pointer_then_scan_markers
    JSR test_lift_or_hazard_hit_player
    BNE restore_y_and_exit
    LDA #LIFT_HAZARD_ACTIVE
    JSR step_up_by_count
    JMP test_overlap_damage

.entity_descending
    CLC
    LDA moving_entity_display_pointer_low,Y
    ADC #&80
    STA display_pointer_low
    LDA moving_entity_display_pointer_high,Y
    ADC #&02
    STA display_pointer_high
    JSR scan_four_display_bytes_for_markers
    JSR test_lift_or_hazard_hit_player
    BNE restore_y_and_exit
    LDA #&01
    STA player_contact_or_damage_flag
    LDA #&FE
    STA player_vertical_velocity
    JSR move_player_down_by_velocity

.test_overlap_damage
    LDA display_grid_column
    BEQ restore_y_and_exit
    JSR apply_player_damage_and_redraw_energy

.restore_y_and_exit
    PLA
    TAY
    RTS
.apply_moving_entity_to_player_source_end

ASSERT apply_moving_entity_to_player_source = apply_moving_entity_to_player
ASSERT apply_moving_entity_to_player_source_end = &235C
COPYBLOCK apply_moving_entity_to_player_source, apply_moving_entity_to_player_source_end, &3B0D

; Runtime $230D-$235B overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3B0D-$3B5B.
CLEAR apply_moving_entity_to_player_source, apply_moving_entity_to_player_source_end


ORG reverse_lift_or_hazard_delta_at_limits

; Keep a lift or moth-shaped hazard inside its range by reversing
; its delta at either limit, and flag that the check ran.
; lift_hazard_limit_check_active is set on entry. The entity position is masked to an even value and tested
; against the two limits at $1246 and $1247: matching the first stores +2 into
; the delta at $18, matching the second stores -2, and matching neither leaves
; the delta alone.
; This is the third clamp of the same shape. clamp_room_enemy_horizontal_delta_at_limits
; drives +1 and -1 against $1235 and $1236, reverse_room_enemy_vertical_delta_at_limits
; drives +2 and -2 against $1237 and $1238 by equality, and this one drives +2
; and -2 against $1246 and $1247. Those last two limits are the pair
; initialise_lifts_and_hazards_from_table unpacks, so each entity class carries
; its own limits and its own clamp.
.reverse_lift_or_hazard_delta_at_limits_source
    LDA #LIFT_HAZARD_LIMIT_CHECK_SET
    STA lift_hazard_limit_check_active
    LDA moving_entity_position,Y
    AND #LIFT_HAZARD_EVEN_POSITION_MASK
    CMP lift_or_hazard_lower_position
    BEQ set_lift_or_hazard_delta_positive
    CMP lift_or_hazard_upper_position
    BEQ set_lift_or_hazard_delta_negative
    RTS

.set_lift_or_hazard_delta_positive
    LDA #&02

.store_lift_or_hazard_delta
    STA moving_entity_delta,Y
    RTS

.set_lift_or_hazard_delta_negative
    LDA #&FE
    JMP store_lift_or_hazard_delta
.reverse_lift_or_hazard_delta_at_limits_source_end

ASSERT reverse_lift_or_hazard_delta_at_limits_source = reverse_lift_or_hazard_delta_at_limits
ASSERT reverse_lift_or_hazard_delta_at_limits_source_end = &2394
COPYBLOCK reverse_lift_or_hazard_delta_at_limits_source, reverse_lift_or_hazard_delta_at_limits_source_end, &3B75

; Runtime $2375-$2393 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3B75-$3B93.
CLEAR reverse_lift_or_hazard_delta_at_limits_source, reverse_lift_or_hazard_delta_at_limits_source_end


ORG advance_lift_or_hazard_vertical_position

; Apply one signed vertical step to the Y-indexed lift or
; moth-shaped hazard, then clear lift_hazard_limit_check_active.
; The state is copied into the shared scratch fields, stepped by
; apply_signed_vertical_step_to_pointer and copied back, exactly as
; advance_room_enemy_vertical_position does for the other class and
; advance_player_vertical_position_and_display_pointer does for the player. Only
; the source fields differ: $19 for the position, $18 for the signed step and
; $51/$52 for the display pointer.
; All three movers therefore share one helper, so every moving thing in the game
; falls and climbs by the same two display scanlines per unit.
; The flag it clears is the one reverse_lift_or_hazard_delta_at_limits sets on
; entry, so the clamp and the step bracket each other.
.advance_lift_or_hazard_vertical_position_source
    LDA moving_entity_position,Y
    STA candidate_half_vertical_position
    LDA moving_entity_delta,Y
    STA vertical_step_delta
    LDA moving_entity_display_pointer_low,Y
    STA vertical_step_pointer_low
    LDA moving_entity_display_pointer_high,Y
    STA vertical_step_pointer_high
    JSR apply_signed_vertical_step_to_pointer
    LDA candidate_half_vertical_position
    STA moving_entity_position,Y
    LDA vertical_step_pointer_low
    STA moving_entity_display_pointer_low,Y
    LDA vertical_step_pointer_high
    STA moving_entity_display_pointer_high,Y
    LDA #LIFT_HAZARD_LIMIT_CHECK_CLEAR
    STA lift_hazard_limit_check_active
    RTS
.advance_lift_or_hazard_vertical_position_source_end

ASSERT advance_lift_or_hazard_vertical_position_source = advance_lift_or_hazard_vertical_position
ASSERT advance_lift_or_hazard_vertical_position_source_end = &23BF
COPYBLOCK advance_lift_or_hazard_vertical_position_source, advance_lift_or_hazard_vertical_position_source_end, &3B94

; Runtime $2394-$23BE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3B94-$3BBE.
CLEAR advance_lift_or_hazard_vertical_position_source, advance_lift_or_hazard_vertical_position_source_end


ORG xor_draw_lift_or_hazard

; XOR-draw the Y-indexed lift or moth-shaped hazard.
; The $23BF entry skips slots 0 and 8 through the shared RTS at $23BE; $23C7 is
; the entry for callers that have already decided the slot is drawable, and is
; used far more often.
; The graphic index defaults to $0C. When bit 0 of $1249 is set, bit 2 of the
; entity value at $19 selects $0E instead, which is how an entity alternates
; between two graphics as it moves. A nonzero $124A then makes the draw two
; character rows tall with the source scanlines repeated, otherwise one row.
; The display pointer comes from $51/$52 and the XOR renderer is tail-called, so
; drawing and erasing are the same operation performed twice.
;
; This is the lift renderer. Suppressing it was tested in play and the vertical
; lifts disappeared while the enemy robots were unaffected. It draws the whole
; second class the same way regardless of $1249, so a hazard and a moving
; platform look alike to this routine; only what happens on contact differs,
; which update_lift_or_hazard_by_class decides.
.xor_draw_lift_or_hazard_source
    CPY #LIFT_HAZARD_FIRST_INVALID_SLOT
    BEQ lift_or_hazard_step_rts
    CPY #LIFT_HAZARD_LAST_INVALID_SLOT
    BEQ lift_or_hazard_step_rts

.draw_lift_or_hazard_without_slot_check
    LDX #LIFT_HAZARD_FRAME_0_POINTER_OFFSET
    LDA active_lift_or_hazard_class
    LSR A
    BCC single_row_lift_or_hazard
    LDA moving_entity_position,Y
    LSR A
    LSR A
    LSR A
    BCS test_two_row_lift_or_hazard
    LDX #LIFT_HAZARD_FRAME_1_POINTER_OFFSET

.test_two_row_lift_or_hazard
    LDA lift_and_hazard_slot_limit
    BEQ single_row_lift_or_hazard
    LDA #&01
    STA xor_graphic_repeat_source_scanlines
    LDA #&02
    JMP draw_lift_or_hazard_at_pointer

.single_row_lift_or_hazard
    LDA #&01

.draw_lift_or_hazard_at_pointer
    STA xor_graphic_character_rows_remaining
    LDA moving_entity_display_pointer_high,Y
    STA display_pointer_high
    LDA moving_entity_display_pointer_low,Y
    JMP select_graphic_then_xor_draw
.xor_draw_lift_or_hazard_source_end

ASSERT xor_draw_lift_or_hazard_source = xor_draw_lift_or_hazard
ASSERT xor_draw_lift_or_hazard_source_end = &23F6
COPYBLOCK xor_draw_lift_or_hazard_source, xor_draw_lift_or_hazard_source_end, &3BBF

; Runtime $23BF-$23F5 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3BBF-$3BF5.
CLEAR xor_draw_lift_or_hazard_source, xor_draw_lift_or_hazard_source_end


ORG test_lift_or_hazard_hit_player

; Read and clear the shared collision flag, and charge energy when this room
; entity is the damaging hazard class.
; The flag is taken into X and reset in the same breath, so each collision is
; counted once no matter how many callers ask. Energy is only spent when the
; active_lift_or_hazard_class selects whether contact hurts or acts as a solid
; moving surface. A hazard hit applies damage and then returns
; LIFT_HAZARD_CONTACT_NONE; only a hit on the lift class returns
; LIFT_HAZARD_CONTACT_DETECTED, telling the caller to carry or push the player.
;
; The class comes straight from lift_and_hazard_room_record_table, so whether
; the moving thing in a room hurts
; is fixed per room. Seventeen records select LIFT_OR_HAZARD_HAZARD and hurt;
; three - A4, B2 and B6 - are not, and those are the rooms where the moving
; thing is a surface to ride.
.test_lift_or_hazard_hit_player_source
    LDX display_grid_column
    LDA #LIFT_HAZARD_CONTACT_NONE
    STA display_grid_column
    LDA active_lift_or_hazard_class
    CMP #LIFT_OR_HAZARD_HAZARD
    BNE return_lift_contact_result
    CPX #LIFT_HAZARD_CONTACT_DETECTED
    BNE return_lift_contact_result
    LDX #LIFT_HAZARD_CONTACT_NONE
    JSR apply_player_damage_and_redraw_energy

.return_lift_contact_result
    CPX #LIFT_HAZARD_CONTACT_DETECTED
    RTS
.test_lift_or_hazard_hit_player_source_end

ASSERT test_lift_or_hazard_hit_player_source = test_lift_or_hazard_hit_player
ASSERT test_lift_or_hazard_hit_player_source_end = &2375
COPYBLOCK test_lift_or_hazard_hit_player_source, test_lift_or_hazard_hit_player_source_end, &3B5C

; Runtime $235C-$2374 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3B5C-$3B74.
CLEAR test_lift_or_hazard_hit_player_source, test_lift_or_hazard_hit_player_source_end


ORG prepare_player_relative_display_scan

; First derive the display pointer three Mode 1 character
; rows below the player, then tail-transfer to the four-byte display scanner.
.prepare_player_relative_display_scan_source
    JSR set_display_pointer_three_mode1_rows_below_player
    JMP scan_four_display_bytes_for_markers
.prepare_player_relative_display_scan_source_end

ASSERT prepare_player_relative_display_scan_source = prepare_player_relative_display_scan
ASSERT prepare_player_relative_display_scan_source_end = &2899
COPYBLOCK prepare_player_relative_display_scan_source, prepare_player_relative_display_scan_source_end, &4093

; Runtime $2893-$2898 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4093-$4098.
CLEAR prepare_player_relative_display_scan_source, prepare_player_relative_display_scan_source_end

ORG draw_record_three_from_alternate_bank

; Draw graphic record 3 from the alternate source bank,
; leaving the bank selector as it was found.
; $1224 chooses which of the two pointers in the table at $1D34 the blitter
; reads its records from. This sets it to 2, draws record 3 through the blitter
; vector, then restores 0, so the caller neither sets up nor cleans up the bank.
.draw_record_three_from_alternate_bank_source
    LDA #GRAPHIC_BANK_STATUS_OFFSET
    STA graphic_source_base_pointer_offset
    LDA #STATUS_GRAPHIC_BLANK_ICON
    JSR enter_copy_16_byte_graphic_to_display
    LDA #GRAPHIC_BANK_PRIMARY_OFFSET
    STA graphic_source_base_pointer_offset
    RTS
.draw_record_three_from_alternate_bank_source_end

ASSERT draw_record_three_from_alternate_bank_source = draw_record_three_from_alternate_bank
ASSERT draw_record_three_from_alternate_bank_source_end = &24D2
COPYBLOCK draw_record_three_from_alternate_bank_source, draw_record_three_from_alternate_bank_source_end, &3CC2

; Runtime $24C2-$24D1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3CC2-$3CD1.
CLEAR draw_record_three_from_alternate_bank_source, draw_record_three_from_alternate_bank_source_end


ORG erase_collected_icon

; Blank one icon in the collected row, at the index in A.
; The address is A times sixteen plus $3F70, one slot past the $3F60 base
; add_collected_icon draws to, so this erases the icon above the given index.
; There is no terminator: the block runs off its last instruction into
; draw_record_three_from_alternate_bank, which draws the blanking record and
; restores the graphic bank.
.erase_collected_icon_source
    ASL A
    ASL A
    ASL A
    ASL A
    CLC
    ADC #LO(collected_icon_next_slot_base)
    STA display_pointer_low
    LDA #GAME_CLOCK_TICK_CONSUMED
    ADC #HI(collected_icon_next_slot_base)
    STA display_pointer_high
.erase_collected_icon_source_end

ASSERT erase_collected_icon_source = erase_collected_icon
ASSERT erase_collected_icon_source_end = &24C2
COPYBLOCK erase_collected_icon_source, erase_collected_icon_source_end, &3CB3

; Runtime $24B3-$24C1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3CB3-$3CC1.
CLEAR erase_collected_icon_source, erase_collected_icon_source_end


ORG write_system_clock_via_osword_02

; Runtime $0BA0-$0BBC has two distinct entries attached to one Ghidra function.
; $0BA0 selects OSWORD function $02 with parameter block $0E00 and tail-calls
; the MOS. $0BA9 prints the high then low nibble of A as two characters; the
; low digit tail-jumps to OSWRCH. Inputs outside packed BCD intentionally use
; the same nibble-plus-$30 conversion.
.write_system_clock_via_osword_02_source
    LDA #&02
    LDX #LO(system_clock_block)
    LDY #HI(system_clock_block)
    JMP OSWORD

.print_packed_bcd_byte_source
    PHA
    LSR A
    LSR A
    LSR A
    LSR A
    CLC
    ADC #&30
    JSR OSWRCH
    PLA
    AND #&0F
    CLC
    ADC #&30
    JMP OSWRCH
.write_system_clock_via_osword_02_source_end

ASSERT write_system_clock_via_osword_02_source = write_system_clock_via_osword_02
ASSERT print_packed_bcd_byte_source = print_packed_bcd_byte
ASSERT write_system_clock_via_osword_02_source_end = &0BBD
COPYBLOCK write_system_clock_via_osword_02_source, write_system_clock_via_osword_02_source_end, &24A0

; Runtime $0BA0-$0BBC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $24A0-$24BC.
CLEAR write_system_clock_via_osword_02_source, write_system_clock_via_osword_02_source_end


ORG enter_add_collected_icon

; A three-byte JMP vector into add_collected_icon, giving
; callers a fixed entry independent of where that routine sits.
.enter_add_collected_icon_source
    JMP add_collected_icon
.enter_add_collected_icon_source_end

ASSERT enter_add_collected_icon_source = enter_add_collected_icon
ASSERT enter_add_collected_icon_source_end = &0BC0
COPYBLOCK enter_add_collected_icon_source, enter_add_collected_icon_source_end, &24BD

; Runtime $0BBD-$0BBF overlaps the loaded transport image. Release it after
; copying its bytes to loaded $24BD-$24BF.
CLEAR enter_add_collected_icon_source, enter_add_collected_icon_source_end


ORG update_lift_and_hazard_group

; Walk the lift/hazard slots, drawing each one either
; side of its update.
; Y starts at 8 and advances by two per slot until it reaches the count at
; $124A, so the slots are two-byte pairs and the record decides how many exist.
; Each slot is drawn before and after its update, which with an XOR renderer
; erases and redraws it; the leading draw is skipped when $61 is clear, so a
; freshly entered room does not erase what was never drawn.
; Slot $0A is updated twice rather than once, which moves it at double the rate
; of its neighbours.
; The repeated-scanline flag is cleared on exit, so the two-row entity draws do
; not leak into whatever runs next.
.update_lift_and_hazard_group_source
    LDY #&08

.draw_update_next_slot
    LDA erase_previous_xor_sprite_flag
    BEQ update_this_slot
    JSR draw_lift_or_hazard_without_slot_check

.update_this_slot
    JSR update_lift_or_hazard_by_class
    CPY #&0A
    BNE redraw_slot
    JSR update_lift_or_hazard_by_class

.redraw_slot
    JSR draw_lift_or_hazard_without_slot_check
    INY
    INY
    CPY lift_and_hazard_slot_limit
    BNE draw_update_next_slot
    LDA #&00
    STA xor_graphic_repeat_source_scanlines
    RTS
.update_lift_and_hazard_group_source_end

ASSERT update_lift_and_hazard_group_source = update_lift_and_hazard_group
ASSERT update_lift_and_hazard_group_source_end = &2423
COPYBLOCK update_lift_and_hazard_group_source, update_lift_and_hazard_group_source_end, &3C01

; Runtime $2401-$2422 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3C01-$3C22.
CLEAR update_lift_and_hazard_group_source, update_lift_and_hazard_group_source_end


ORG update_lift_or_hazard_by_class

; Update one lift or moth-shaped hazard, choosing between two
; behaviours according to its class byte, then step it.
; The slot index is turned into a scaled offset by subtracting 8 from Y and
; doubling, and the range clamp runs first. A class byte of 1 then takes the
; bounding-box route: the entity position is halved into $3C, its extent
; computed as $1248 less the scaled offset into $11, and the player overlap
; tested. Any other class instead pushes the player directly through
; apply_moving_entity_to_player.
; Either way the entity is stepped by a tail jump, so both routes end in the
; same movement.
; So moth-shaped hazards hurt on overlap and lifts act as moving surfaces,
; which is the same split test_lift_or_hazard_hit_player makes when deciding
; whether to charge energy.
.update_lift_or_hazard_by_class_source
    TYA
    SEC
    SBC #LIFT_HAZARD_SLOT_GROUP_BASE_INDEX
    ASL A
    STA lift_hazard_scaled_slot_offset
    JSR reverse_lift_or_hazard_delta_at_limits
    LDA active_lift_or_hazard_class
    CMP #LIFT_OR_HAZARD_HAZARD
    BNE push_player_with_entity
    LDA moving_entity_position,Y
    LSR A
    STA candidate_half_vertical_position
    SEC
    LDA lift_or_hazard_horizontal_extent
    SBC lift_hazard_scaled_slot_offset
    STA candidate_horizontal_position
    JSR check_player_candidate_bounds_overlap
    JMP step_entity

.push_player_with_entity
    JSR apply_moving_entity_to_player

.step_entity
    JMP advance_lift_or_hazard_vertical_position
.update_lift_or_hazard_by_class_source_end

ASSERT update_lift_or_hazard_by_class_source = update_lift_or_hazard_by_class
ASSERT update_lift_or_hazard_by_class_source_end = &244E
COPYBLOCK update_lift_or_hazard_by_class_source, update_lift_or_hazard_by_class_source_end, &3C23

; Runtime $2423-$244D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3C23-$3C4D.
CLEAR update_lift_or_hazard_by_class_source, update_lift_or_hazard_by_class_source_end


ORG refill_energy_in_28_steps

; Raise the stored energy by up to twenty-eight, redrawing the bar at every step.
; X counts PLAYER_ENERGY_REFILL_STEPS iterations. Each one increments
; player_energy_snapshot, clamps it at PLAYER_ENERGY_MAX, copies it into
; player_energy, and
; calls redraw_energy_bar_segment. Redrawing once per step rather than once at the
; end is what makes a refill visible as a sweep rather than a jump.
; The traced call shows the clamp doing its work: the wrap test fell through 27 of
; the 28 iterations, so the snapshot entered one below maximum, reached maximum and
; saturated there for the rest, and the remaining 27 steps redrew a full bar.
; consume_matching_item_from_slots calls this at $2D93, immediately after it has
; found a carried item and cleared its slot, and $2468 is the other caller. So
; spending an item returns energy.
.refill_energy_in_28_steps_source
    LDX #PLAYER_ENERGY_REFILL_STEPS

.refill_energy_next_step
    INC player_energy_snapshot
    BNE show_and_redraw_energy
    LDA #PLAYER_ENERGY_MAX
    STA player_energy_snapshot

.show_and_redraw_energy
    LDA player_energy_snapshot
    STA player_energy
    JSR redraw_energy_bar_segment
    DEX
    BNE refill_energy_next_step
    RTS
.refill_energy_in_28_steps_source_end

ASSERT refill_energy_in_28_steps_source = refill_energy_in_28_steps
ASSERT refill_energy_in_28_steps_source_end = &24E7
COPYBLOCK refill_energy_in_28_steps_source, refill_energy_in_28_steps_source_end, &3CD2

; Runtime $24D2-$24E6 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3CD2-$3CE6.
CLEAR refill_energy_in_28_steps_source, refill_energy_in_28_steps_source_end


ORG set_velocity_step_from_horizontal_band

; Set the vertical velocity step from which horizontal band
; of the room the player is standing in.
; The shadow horizontal position at $16 is shifted right four times, so the room
; splits into bands sixteen units wide, and the result indexes the table that
; follows the RTS at $24F4. A room is $4C units wide, so five bands exist and the
; table's five entries are $01, $FF, $02, $FE and $03 - alternating sign with
; rising magnitude.
; vertical_velocity_step is the unit both the jet boots and gravity work in, added by the thrust code
; and subtracted at $277B, so a negative entry inverts which way the player is
; carried while standing still. Bands two and four therefore lift rather than drop.
; This runs only when horizontal_band_velocity_effect_state is odd.
; draw_and_initialise_room clears that state for every room, so it is a
; per-room effect a room has to request. It fired on 379 of 3,509 tested frames.
; What the effect is called in play is not established. A signed step that
; alternates by band is consistent with a current, and the account of the map has
; many water rooms, but no trace has been tied to a named room.
.set_velocity_step_from_horizontal_band_source
    LDA player_horizontal_position_snapshot
    LSR A
    LSR A
    LSR A
    LSR A
    TAX
    LDA horizontal_band_velocity_step_table,X
    STA vertical_velocity_step
    RTS
.set_velocity_step_from_horizontal_band_source_end

ASSERT set_velocity_step_from_horizontal_band_source = set_velocity_step_from_horizontal_band
ASSERT set_velocity_step_from_horizontal_band_source_end = &24F4
COPYBLOCK set_velocity_step_from_horizontal_band_source, set_velocity_step_from_horizontal_band_source_end, &3CE7

; Runtime $24E7-$24F3 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3CE7-$3CF3.
CLEAR set_velocity_step_from_horizontal_band_source, set_velocity_step_from_horizontal_band_source_end


ORG advance_bounded_tick_target

; Runtime $24F9-$252C plus mutable bytes $252D/$252E. Increment the delay
; counter and return through the preceding routine's RTS until the upper target
; minus the current target is smaller than the counter. On expiry, clear the
; counter and add the signed delta to bounded_tick_target_value. Reaching either
; named endpoint reads the interval timer and negates the delta with one's
; complement followed by INC. The two bytes immediately following the RTS are
; data despite forming a plausible but unreachable 6502 instruction in the
; original image.
.advance_bounded_tick_target_source
    INC bounded_tick_target_delay_counter
    SEC
    LDA #BOUNDED_TICK_TARGET_UPPER
    SBC bounded_tick_target_value
    CMP bounded_tick_target_delay_counter
    BPL bounded_tick_delay_not_elapsed_exit
    LDA #BOUNDED_TICK_DELAY_RESET
    STA bounded_tick_target_delay_counter
    CLC
    LDA bounded_tick_target_value
    ADC bounded_tick_target_delta
    STA bounded_tick_target_value
    LDA bounded_tick_target_value
    CMP #BOUNDED_TICK_TARGET_UPPER
    BEQ reverse_bounded_tick_target_delta
    CMP #BOUNDED_TICK_TARGET_LOWER
    BEQ reverse_bounded_tick_target_delta
    RTS

.reverse_bounded_tick_target_delta
    JSR evntv_read_interval_timer
    LDA bounded_tick_target_delta
    EOR #BYTE_ONES_COMPLEMENT_MASK
    STA bounded_tick_target_delta
    INC bounded_tick_target_delta
    RTS

.bounded_tick_target_initial_data
    EQUB BOUNDED_TICK_TARGET_INITIAL_DELTA
    EQUB BOUNDED_TICK_TARGET_INITIAL_DELAY
.advance_bounded_tick_target_source_end

ASSERT advance_bounded_tick_target_source = advance_bounded_tick_target
ASSERT bounded_tick_target_initial_data = bounded_tick_target_delta
ASSERT bounded_tick_target_initial_data + 1 = bounded_tick_target_delay_counter
ASSERT advance_bounded_tick_target_source_end = main_gameplay_loop
COPYBLOCK advance_bounded_tick_target_source, advance_bounded_tick_target_source_end, &3CF9

; Runtime $24F9-$252E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3CF9-$3D2E.
CLEAR advance_bounded_tick_target_source, advance_bounded_tick_target_source_end


ORG collect_power_crystal_and_refill_energy

; Handle a collected power crystal: decrement the
; twelve-diamond status count; decrement progress_pattern_pair_count when the final crystal takes that
; count to zero; configure and play the collection sound; refill energy; remove
; the corresponding status diamond and stamp the collected room cell; then
; tail-transfer to the status-divider redraw.
.collect_power_crystal_and_refill_energy_source
    DEC power_crystals_remaining
    BNE apply_power_crystal_rewards
    DEC progress_pattern_pair_count

.apply_power_crystal_rewards
    LDA #POWER_CRYSTAL_COLLECTION_SOUND_PITCH
    STA sound_block_pitch
    LDA #POWER_CRYSTAL_COLLECTION_SOUND_DURATION
    STA sound_block_duration
    LDA #POWER_CRYSTAL_COLLECTION_SOUND_AMPLITUDE
    JSR play_sound_with_amplitude
    JSR refill_energy_in_28_steps
    JSR remove_last_icon_and_stamp_room_cell
    JMP draw_status_panel_divider
.collect_power_crystal_and_refill_energy_source_end

ASSERT collect_power_crystal_and_refill_energy_source = collect_power_crystal_and_refill_energy
ASSERT collect_power_crystal_and_refill_energy_source_end = &2471
COPYBLOCK collect_power_crystal_and_refill_energy_source, collect_power_crystal_and_refill_energy_source_end, &3C53

; Runtime $2453-$2470 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3C53-$3C70.
CLEAR collect_power_crystal_and_refill_energy_source, collect_power_crystal_and_refill_energy_source_end


ORG initialise_new_game

; Set up a new game.
; Three subroutines run first, then the primary and secondary room references
; select B0. The special-item flag and level-map offset are cleared, the packed
; BCD clock is seeded, and the graphic bank selector chooses status graphics.
; One load of zero deliberately serves all five adjacent stores; a variant that
; displaces part of this sequence must still preserve zero for the remainder.
; The status row is then initialised: collected_icon_count is set to twelve and
; the display pointer selects the first icon position. The loop that follows
; clears water_environment_flag and runs once per icon.
; Those two values are what remove_last_icon_and_stamp_room_cell reads back: it
; addresses an icon as $3CF0 plus the count times sixteen, so this is where both
; the base and the starting count come from.
.initialise_new_game_source
    JSR place_initial_map_objects
    JSR restore_item_and_goal_records
    JSR run_startup_room_sequence_until_space
    LDA #NEW_GAME_START_COLUMN
    STA reference_pair_primary_value
    LDA #NEW_GAME_START_LEVEL
    STA reference_pair_secondary_value
    STA special_item_3e_activation_flag
    STA level_room_map_offset_low
    STA level_room_map_offset_high
    LDA #NEW_GAME_CLOCK_LOW_BCD
    STA bcd_counter_low
    LDA #NEW_GAME_CLOCK_HIGH_BCD
    STA bcd_counter_high
    LDA #GRAPHIC_BANK_STATUS_OFFSET
    STA graphic_source_base_pointer_offset
    LDY #POWER_CRYSTAL_TOTAL
    STY power_crystals_remaining
    LDA #LO(status_icon_row_base)
    STA display_pointer_low
    LDA #HI(status_icon_row_base)
    STA display_pointer_high

.clear_next_icon_slot
    LDA #STATUS_GRAPHIC_REMAINING_ICON
    STA water_environment_flag ; this graphic selector is also WATER_ENVIRONMENT_INACTIVE
    BEQ draw_cleared_icon_slot

; Runtime $0C00-$0C0F is skipped unconditionally by the BEQ above. Its sixteen
; bytes have the shape and size of one Mode 1 graphic record, but neither the
; static references nor committed traces read it. Preserve that evidence limit
; in the name instead of assigning an invented picture or gameplay role.
.unused_new_game_inline_mode1_record_source_data
    EQUB &7C, &C6, &C6, &C6, &C6, &D6, &7C, &0F
    EQUB &06, &06, &0F, &EB, &ED, &4F, &4F, &EF

.draw_cleared_icon_slot
    JSR enter_copy_16_byte_graphic_to_display
    DEY
    BNE clear_next_icon_slot

    ; Draw graphic record 2 three times at the collected-icon row, then seed
    ; both live and previous-frame player pointers to $7460. The initial player
    ; grid position is horizontal $1C, vertical $B0. Enter the main loop through
    ; its fixed jump-table vector; if it returns, restart initialization.
    LDA #LO(collected_icon_next_slot_base)
    STA display_pointer_low
    LDA #HI(collected_icon_next_slot_base)
    STA display_pointer_high
    LDA #STATUS_GRAPHIC_INITIAL_MARKER
    JSR enter_copy_16_byte_graphic_to_display
    JSR enter_copy_16_byte_graphic_to_display
    JSR enter_copy_16_byte_graphic_to_display
    LDA #LO(initial_player_display_pointer)
    STA player_display_pointer_snapshot_low
    STA player_display_pointer_low
    LDA #HI(initial_player_display_pointer)
    STA player_display_pointer_snapshot_high
    STA player_display_pointer_high
    LDA #NEW_GAME_PLAYER_HORIZONTAL_POSITION
    STA player_horizontal_position
    LDA #NEW_GAME_PLAYER_VERTICAL_POSITION
    STA player_vertical_position
    JSR enter_main_gameplay_loop
    JMP initialise_new_game
.initialise_new_game_source_end

ASSERT initialise_new_game_source = initialise_new_game
ASSERT unused_new_game_inline_mode1_record_source_data = unused_new_game_inline_mode1_record
ASSERT draw_cleared_icon_slot = &0C10
ASSERT initialise_new_game_source_end = &0C43
COPYBLOCK initialise_new_game_source, initialise_new_game_source_end, &24C8

; Runtime $0BC8-$0C42 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $24C8-$2542.
CLEAR initialise_new_game_source, initialise_new_game_source_end


ORG walk_player_toward_target_position

; Walk the player to a target position, one step per frame,
; without returning until it arrives. The target coordinates are supplied in
; player_walk_target_horizontal_position and player_walk_target_vertical_position.
; Each iteration halves both the current and target vertical positions before
; comparing, so the match is at half resolution. A difference stores a signed
; two-unit signed step in vertical_step_delta and calls the vertical mover; the horizontal
; difference then selects the one-cell left or right step. Every iteration ends
; by waiting for vertical sync through the display helpers, which is what paces
; the walk to one step per frame.
; Arrival requires both axes to match, at which point the energy-delta budget is
; reset. That shared tail is also reached independently when energy is unchanged.
.walk_player_toward_target_position_source
    LDX #SCRIPTED_WALK_START_FLASH_COUNT
    JSR flash_background_colour_with_sound
    LDA #SCRIPTED_WALK_SOUND_DURATION_AND_PITCH
    STA sound_block_duration
    STA sound_block_pitch
    LDA #SCRIPTED_WALK_SOUND_AMPLITUDE
    JSR play_sound_with_amplitude

.walk_one_step_toward_target
    LDA player_walk_target_vertical_position
    LSR A
    STA player_walk_target_half_vertical_position
    LDX #SCRIPTED_WALK_VERTICAL_STEP_DOWN
    LDA player_vertical_position
    LSR A
    CMP player_walk_target_half_vertical_position
    CLC
    BEQ test_horizontal_difference
    BMI apply_vertical_step
    LDX #SCRIPTED_WALK_VERTICAL_STEP_UP

.apply_vertical_step
    STX vertical_step_delta
    JSR advance_player_vertical_position_and_display_pointer
    SEC

.test_horizontal_difference
    BCS step_horizontally_toward_target
    LDA player_horizontal_position
    CMP player_walk_target_horizontal_position
    BNE step_horizontally_toward_target
    LDX #SCRIPTED_WALK_ARRIVAL_FLASH_COUNT
    JSR flash_background_colour_with_sound

.reset_energy_delta_budget_on_arrival
    LDA #PLAYER_ENERGY_DELTA_BUDGET_RESET
    STA player_energy_delta_budget
    RTS

.step_horizontally_toward_target
    LDA player_horizontal_position
    CMP player_walk_target_horizontal_position
    BEQ wait_for_frame_then_continue
    BPL step_left_toward_target
    JSR advance_player_one_cell_right
    JMP wait_for_frame_then_continue

.step_left_toward_target
    JSR advance_player_one_cell_left

.wait_for_frame_then_continue
    JSR wait_vsync_then_call_display_helpers
    JMP walk_one_step_toward_target
.walk_player_toward_target_position_source_end

ASSERT walk_player_toward_target_position_source = walk_player_toward_target_position
ASSERT walk_player_toward_target_position_source_end = &2630
COPYBLOCK walk_player_toward_target_position_source, walk_player_toward_target_position_source_end, &3DDC

; Runtime $25DC-$262F overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3DDC-$3E2F.
CLEAR walk_player_toward_target_position_source, walk_player_toward_target_position_source_end


ORG run_startup_room_sequence_until_space

; Show a repeating sixteen-room startup sequence until
; Space is pressed. Each complete restart clears the startup zero-page workspace
; and seeds progress_pattern_pair_count, collected_icon_erase_index and the XOR
; renderer row count. startup_room_sequence_table is read backwards, from
; indexes sixteen through one; its low
; nibble becomes the primary room reference and its high nibble the secondary.
; The repeated-add loop also forms the high nibble times ROOM_LEVEL_MAP_BYTES in
; level_room_map_offset_low/high before the
; the room-draw vector and cross-room robot/ghost initialiser run. Each room is then
; ticked STARTUP_ROOM_TICK_COUNT times. At STARTUP_PROMPT_TICK the inline VDU stream positions the cursor
; and prints " PRESS SPACE "; OSBYTE $81 polls Space after every tick.
; A pressed key branches to discard_two_stack_bytes_and_return, which removes the saved X
; and Y values before returning to initialise_new_game. Expiring X advances to
; the next packed room; expiring Y restarts the entire sequence.
.run_startup_room_sequence_until_space_source
    LDX #STARTUP_ZERO_PAGE_LAST_OFFSET
    LDA #STARTUP_ZERO_PAGE_CLEAR_VALUE

.clear_next_startup_zero_page_byte
    STA startup_zero_page_clear_base,X
    DEX
    BNE clear_next_startup_zero_page_byte
    LDX #PROGRESS_PATTERN_INITIAL_PAIRS
    STX progress_pattern_pair_count
    DEX
    STX collected_icon_erase_index
    LDA #STARTUP_XOR_GRAPHIC_ROWS
    STA xor_graphic_character_rows_remaining
    LDY #STARTUP_ROOM_SEQUENCE_COUNT

.select_next_startup_room
    LDA startup_room_sequence_table-1,Y
    STA startup_packed_room_reference
    AND #PACKED_ROOM_PRIMARY_MASK
    STA reference_pair_primary_value
    LDA startup_packed_room_reference
    LSR A
    LSR A
    LSR A
    LSR A
    STA reference_pair_secondary_value
    LDA #STARTUP_ZERO_PAGE_CLEAR_VALUE
    STA level_room_map_offset_low
    STA level_room_map_offset_high
    LDX #ROOM_LEVEL_MAP_BYTES

.multiply_secondary_reference_by_120
    CLC
    LDA level_room_map_offset_low
    ADC reference_pair_secondary_value
    STA level_room_map_offset_low
    BCC startup_room_offset_did_not_carry
    INC level_room_map_offset_high

.startup_room_offset_did_not_carry
    DEX
    BNE multiply_secondary_reference_by_120
    TYA
    PHA
    JSR enter_draw_and_initialise_room
    JSR enter_initialise_cross_room_robot_ghost_from_record
    LDX #STARTUP_ROOM_TICK_COUNT

.tick_startup_room
    TXA
    PHA
    CPX #STARTUP_PROMPT_TICK
    BNE update_startup_room
    JSR print_inline_vdu_stream

.startup_press_space_vdu_stream
    EQUB VDU_TEXT_AT, STARTUP_PROMPT_CURSOR_X, STARTUP_PROMPT_CURSOR_Y
    EQUS " PRESS SPACE "
    EQUB INLINE_VDU_STREAM_TERMINATOR

.update_startup_room
    JSR write_system_clock_via_osword_02
    JSR enter_dispatch_game_tick_updates
    LDA #OSBYTE_INKEY
    LDY #OSBYTE_INKEY_KEYBOARD_SCAN_Y
    LDX #INKEY_SPACE
    JSR OSBYTE
    BCS discard_two_stack_bytes_and_return
    PLA
    TAX
    DEX
    BNE tick_startup_room
    PLA
    TAY
    DEY
    BNE select_next_startup_room
    JMP run_startup_room_sequence_until_space_source
.run_startup_room_sequence_until_space_source_end

ASSERT run_startup_room_sequence_until_space_source = run_startup_room_sequence_until_space
ASSERT startup_press_space_vdu_stream = &0CBE
ASSERT update_startup_room = &0CCF
ASSERT run_startup_room_sequence_until_space_source_end = startup_room_sequence_table
COPYBLOCK run_startup_room_sequence_until_space_source, run_startup_room_sequence_until_space_source_end, &256E

; Runtime $0C6E-$0CEC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $256E-$25EC.
CLEAR run_startup_room_sequence_until_space_source, run_startup_room_sequence_until_space_source_end


ORG wait_vsync_then_call_display_helpers

; The per-frame display update. OSBYTE $13 waits for
; vertical sync, then the player is XOR-drawn, $2ABA runs, and the player is
; XOR-drawn again through a tail jump.
; Drawing the same XOR sprite twice erases and redraws it: the first call
; removes the player from where it was, $2ABA advances the state and the rest
; of the display, and the second call puts it back at its new position. Doing
; that immediately after the vsync wait is what keeps the redraw off the
; visible raster.
.wait_vsync_then_call_display_helpers_source
    LDA #OSBYTE_WAIT_VSYNC
    JSR OSBYTE
    JSR xor_draw_player_two_parts
    JSR capture_player_state_for_redraw
    JMP xor_draw_player_two_parts
.wait_vsync_then_call_display_helpers_source_end

ASSERT wait_vsync_then_call_display_helpers_source = wait_vsync_then_call_display_helpers
ASSERT wait_vsync_then_call_display_helpers_source_end = &2790
COPYBLOCK wait_vsync_then_call_display_helpers_source, wait_vsync_then_call_display_helpers_source_end, &3F82

; Runtime $2782-$278F overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3F82-$3F8F.
CLEAR wait_vsync_then_call_display_helpers_source, wait_vsync_then_call_display_helpers_source_end


ORG redraw_energy_bar_segment

; Redraw the one cell of the energy bar that the current
; energy value partially fills.
; player_energy selects both the cell and the fill. Its top five bits
; address the cell, $4071 plus the value masked to $F8, and its low three bits
; halved index the four fill patterns at $2222. That pattern is then written to
; four consecutive display bytes, Y counting down from 4 to 1.
; Y is preserved across the whole redraw. Only the partial cell is touched: the
; full and empty cells either side of it are left as they were, which is why a
; single energy change costs four byte writes rather than a whole bar redraw.
.redraw_energy_bar_segment_source
    TYA
    PHA
    LDA player_energy
    AND #&F8
    CLC
    ADC #LO(energy_bar_partial_cell_base)
    STA display_pointer_low
    LDA #HI(energy_bar_partial_cell_base)
    ADC #&00
    STA display_pointer_high
    LDA player_energy
    AND #ENERGY_BAR_SUBSTEP_MASK
    LSR A
    TAY
    LDA energy_bar_fill_patterns,Y
    LDY #&04

.write_next_fill_byte
    STA (display_pointer_low),Y
    DEY
    BNE write_next_fill_byte
    PLA
    TAY
    RTS
.redraw_energy_bar_segment_source_end

ASSERT redraw_energy_bar_segment_source = redraw_energy_bar_segment
ASSERT redraw_energy_bar_segment_source_end = &2654
COPYBLOCK redraw_energy_bar_segment_source, redraw_energy_bar_segment_source_end, &3E30

; Runtime $2630-$2653 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3E30-$3E53.
CLEAR redraw_energy_bar_segment_source, redraw_energy_bar_segment_source_end


ORG set_display_pointer_three_mode1_rows_below_player

; A Mode 1 character row occupies $0280 bytes, so $0780
; advances three such rows. The low-byte ADC carry is deliberately propagated
; into the high byte. Committed no-input and X traces exercise both carry
; states and produce $7460->$7BE0 and $42C0->$4A40 respectively.
.set_display_pointer_three_mode1_rows_below_player_source
    LDA player_display_pointer_low
    CLC
    ADC #&80
    STA display_pointer_low
    LDA player_display_pointer_high
    ADC #&07
    STA display_pointer_high
    RTS
.set_display_pointer_three_mode1_rows_below_player_source_end

ASSERT set_display_pointer_three_mode1_rows_below_player_source = set_display_pointer_three_mode1_rows_below_player
ASSERT set_display_pointer_three_mode1_rows_below_player_source_end = &28A7
COPYBLOCK set_display_pointer_three_mode1_rows_below_player_source, set_display_pointer_three_mode1_rows_below_player_source_end, &4099

; Runtime $2899-$28A6 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4099-$40A6.
CLEAR set_display_pointer_three_mode1_rows_below_player_source, set_display_pointer_three_mode1_rows_below_player_source_end

ORG move_player_right_with_collision

; Move the player one cell right unless something stops it.
; A horizontal position of $4C is the right edge of the room and transfers to
; $2ACF instead of moving. Otherwise the display pointer is set $20 ahead of the
; player and a column of $18 rows is scanned for a blocking byte. A blocked
; column recomputes the pointer to the cell boundary, adding $02B5 to the
; position masked to $F0, and transfers to $29B9. Only a clear column reaches
; the step itself, which increments the position and adds one Mode 1 character
; cell to the display pointer, touching the high byte only on carry.
.move_player_right_with_collision_source
    LDA player_horizontal_position
    CMP #&4C
    BNE scan_column_ahead_of_player
    JMP enter_room_to_the_right

.scan_column_ahead_of_player
    CLC
    LDA player_display_pointer_low
    ADC #PLAYER_COLLISION_LOOKAHEAD_BYTES
    STA display_pointer_low
    LDA player_display_pointer_high
    ADC #&00
    STA display_pointer_high
    LDA #PLAYER_COLLISION_SCAN_ROWS
    STA xor_graphic_character_rows_remaining
    JSR scan_display_column_for_blocking_byte
    BCC advance_player_one_cell_right
    CLC
    LDA player_display_pointer_low
    AND #&F0
    ADC #&B5
    STA display_pointer_low
    LDA player_display_pointer_high
    ADC #&02
    STA display_pointer_high
    JMP process_player_cell_interactions

.step_right_when_column_clear
    INC player_horizontal_position
    LDA player_display_pointer_low
    CLC
    ADC #MODE1_CELL_COLUMN_BYTES
    STA player_display_pointer_low
    BCC player_right_pointer_no_carry_exit
    INC player_display_pointer_high
    RTS
.move_player_right_with_collision_source_end

ASSERT move_player_right_with_collision_source = move_player_right_with_collision
ASSERT move_player_right_with_collision_source_end = &27D6
COPYBLOCK move_player_right_with_collision_source, move_player_right_with_collision_source_end, &3F97

; Runtime $2797-$27D5 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3F97-$3FD5.
CLEAR move_player_right_with_collision_source, move_player_right_with_collision_source_end


ORG move_player_left_with_collision

; The mirror of move_player_right_with_collision. A
; horizontal position of zero is the left edge of the room and transfers to
; $2AE6 instead of moving; otherwise a column of $18 rows is scanned one cell
; to the left of the player and a blocking byte diverts to $29B9 after
; recomputing the pointer to the cell boundary. Only a clear column reaches the
; step at $2805, which decrements the position and subtracts one Mode 1
; character cell, touching the display pointer high byte only on borrow.
; The two routines differ only where the geometry forces it: SEC/SBC against
; CLC/ADC, position zero against $4C for the edge, and $02B5 against $0275 when
; recomputing the blocked pointer.
.move_player_left_with_collision_source
    LDA player_horizontal_position
    BNE scan_column_left_of_player
    JMP enter_room_to_the_left

.scan_column_left_of_player
    SEC
    LDA player_display_pointer_low
    SBC #MODE1_CELL_COLUMN_BYTES
    STA display_pointer_low
    LDA player_display_pointer_high
    SBC #&00
    STA display_pointer_high
    LDA #PLAYER_COLLISION_SCAN_ROWS
    STA xor_graphic_character_rows_remaining
    JSR scan_display_column_for_blocking_byte
    BCC advance_player_one_cell_left

.recompute_pointer_at_blocking_cell
    CLC
    LDA player_display_pointer_low
    AND #&F0
    ADC #&75
    STA display_pointer_low
    LDA player_display_pointer_high
    ADC #&02
    STA display_pointer_high
    JMP process_player_cell_interactions

.advance_player_one_cell_left
    DEC player_horizontal_position
    SEC
    LDA player_display_pointer_low
    SBC #MODE1_CELL_COLUMN_BYTES
    STA player_display_pointer_low
    BCS player_step_rts
    DEC player_display_pointer_high
    RTS
.move_player_left_with_collision_source_end

ASSERT move_player_left_with_collision_source = move_player_left_with_collision
ASSERT move_player_left_with_collision_source_end = &2813
COPYBLOCK move_player_left_with_collision_source, move_player_left_with_collision_source_end, &3FD6

; Runtime $27D6-$2812 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3FD6-$4012.
CLEAR move_player_left_with_collision_source, move_player_left_with_collision_source_end


ORG advance_player_vertical_position_and_display_pointer

; Copy the player's vertical position and display pointer
; from $2C/$38/$39 into the candidate state at $3C/$3E/$3F, let the original
; $34F1 helper apply the signed step in $40, then copy the result back. The
; wrapper itself is straight-line and preserves X/Y around the nested call.
.advance_player_vertical_position_and_display_pointer_source
    LDA player_vertical_position
    STA candidate_half_vertical_position
    LDA player_display_pointer_low
    STA vertical_step_pointer_low
    LDA player_display_pointer_high
    STA vertical_step_pointer_high
    JSR apply_signed_vertical_step_to_pointer
    LDA candidate_half_vertical_position
    STA player_vertical_position
    LDA vertical_step_pointer_low
    STA player_display_pointer_low
    LDA vertical_step_pointer_high
    STA player_display_pointer_high
    RTS
.advance_player_vertical_position_and_display_pointer_source_end

ASSERT advance_player_vertical_position_and_display_pointer_source = advance_player_vertical_position_and_display_pointer
ASSERT advance_player_vertical_position_and_display_pointer_source_end = scan_display_column_for_blocking_byte
COPYBLOCK advance_player_vertical_position_and_display_pointer_source, advance_player_vertical_position_and_display_pointer_source_end, &40EF

; Runtime $28EF-$290A overlaps the loaded transport image. Release it after
; copying its bytes to loaded $40EF-$410A.
CLEAR advance_player_vertical_position_and_display_pointer_source, advance_player_vertical_position_and_display_pointer_source_end

ORG move_player_down_by_velocity

; Move the player downwards by however far the vertical
; velocity has carried them, and decide what happens on landing.
; player_vertical_steps_remaining is derived from the signed velocity and each
; iteration tests the room edge before testing the cells under the player. A
; position inside the lower transition band snapshots the player and enters the
; room below.
; A clear player-relative scan applies a signed +2 vertical step and loops. A
; blocked scan is the ground. Landing below PLAYER_HARD_LANDING_VELOCITY costs
; energy through
; the damage routine and adds two to the velocity; otherwise the landing is
; tested against the bounce pattern, and an available action sets the
; velocity to PLAYER_BOUNCE_VELOCITY and transfers to the climb. Any other
; landing simply zeroes the velocity.
; The tail adjusts velocity when the display scan found its special marker.
.move_player_down_by_velocity_source
    SEC
    LDA #PLAYER_VERTICAL_STEP_COUNT_COMPLEMENT_BASE
    SBC player_vertical_velocity
    ADC #PLAYER_VERTICAL_VELOCITY_STEP_BIAS
    LSR A
    LSR A
    STA player_vertical_steps_remaining

.fall_one_step
    LDA player_vertical_position
    LSR A
    CMP #PLAYER_LOWER_TRANSITION_HALF_POSITION_START
    BMI test_ground
    CMP #PLAYER_LOWER_TRANSITION_HALF_POSITION_END
    BPL test_ground
    JSR capture_player_state_for_redraw
    JMP enter_room_below

.test_ground
    JSR prepare_player_relative_display_scan
    BCC apply_downward_step
    LDA #PLAYER_GROUND_CONTACT_SET
    STA player_ground_contact_flag
    LDA player_vertical_velocity
    CMP #PLAYER_HARD_LANDING_VELOCITY
    BPL test_landing_pattern
    JSR apply_player_damage_and_redraw_energy
    ; Two increments add one PLAYER_VERTICAL_STEP_DOWN unit after a hard landing.
    INC player_vertical_velocity
    INC player_vertical_velocity
    RTS

.test_landing_pattern
    JSR check_player_relative_display_pattern_15
    LDA player_jump_or_swim_requested
    BEQ stop_fall
    LDA player_contact_or_damage_flag
    BNE stop_fall
    LDA #PLAYER_BOUNCE_VELOCITY
    STA player_vertical_velocity
    LDA #PLAYER_BOUNCE_SOUND_DURATION
    STA sound_block_duration
    LDA #PLAYER_BOUNCE_SOUND_PITCH
    STA sound_block_pitch
    LDA #PLAYER_BOUNCE_SOUND_AMPLITUDE
    JSR play_sound_with_amplitude
    JMP move_player_up_by_velocity

.stop_fall
    LDA #PLAYER_VERTICAL_VELOCITY_STOPPED
    STA player_vertical_velocity

.return_from_downward_movement
    RTS

.apply_downward_step
    LDA #PLAYER_GROUND_CONTACT_CLEAR
    STA player_ground_contact_flag
    LDA #PLAYER_VERTICAL_STEP_DOWN
    STA vertical_step_delta
    JSR advance_player_vertical_position_and_display_pointer
    DEC player_vertical_steps_remaining
    BNE fall_one_step
    LDA water_environment_flag
    BEQ return_from_downward_movement

.adjust_velocity_after_fall
    LDA player_vertical_velocity
    CMP #PLAYER_POST_FALL_ADJUST_THRESHOLD
    BPL force_velocity_on_marker
    CLC
    ADC #PLAYER_VERTICAL_VELOCITY_STEP_BIAS
    STA player_vertical_velocity
    RTS

.force_velocity_on_marker
    LDA player_jump_or_swim_requested
    BEQ return_from_downward_movement
    LDA #PLAYER_WATER_SWIM_VELOCITY
    STA player_vertical_velocity
.move_player_down_by_velocity_source_end

ASSERT move_player_down_by_velocity_source = move_player_down_by_velocity
ASSERT move_player_down_by_velocity_source_end = &2893
COPYBLOCK move_player_down_by_velocity_source, move_player_down_by_velocity_source_end, &4013

; Runtime $2813-$2892 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4013-$4092.
CLEAR move_player_down_by_velocity_source, move_player_down_by_velocity_source_end


ORG poll_controls_and_apply_gameplay_actions

; Poll documented movement, action, thrust, pause, exit and
; sound controls through osbyte_81_inkey; apply horizontal/vertical movement;
; update the slow-damage countdown; run stable-position actions; scan the
; six-key last-chance chord; clear transient input state; and subtract one
; gravity step. COPY enters a busy-wait whose INKEY -90 exit has no wired key
; on the BBC Micro Model B, so the following clock-write call is retained as
; instruction-exact declared-unreachable code.
.poll_controls_and_apply_gameplay_actions_source
    LDA #&00
    STA player_jump_or_swim_requested
    LDX #INKEY_MOVE_LEFT
    JSR osbyte_81_inkey
    BCC control_poll_right
    LDA #&FF
    STA horizontal_input_delta
    STA horizontal_input_delta_copy

.control_poll_right
    LDX #INKEY_MOVE_RIGHT
    JSR osbyte_81_inkey
    BCC control_poll_stun_grenade
    LDA #&01
    STA horizontal_input_delta
    STA horizontal_input_delta_copy
    JMP control_poll_thrust_if_enabled

.control_poll_stun_grenade
    LDX #INKEY_SPACE
    JSR osbyte_81_inkey
    BCC control_poll_thrust_if_enabled
    JSR consume_collected_icon_and_apply_effect

.control_poll_thrust_if_enabled
    LDA jet_boots_enabled_this_room
    BEQ control_poll_jump_or_swim
    LDX #INKEY_FULL_THRUST
    JSR osbyte_81_inkey
    BCC control_poll_half_thrust
    LDA player_vertical_velocity
    CLC
    ADC vertical_velocity_step
    ADC vertical_velocity_step
    STA player_vertical_velocity

.control_poll_half_thrust
    LDX #INKEY_HALF_THRUST
    JSR osbyte_81_inkey
    BCC control_poll_jump_or_swim
    CLC
    LDA player_vertical_velocity
    ADC vertical_velocity_step
    STA player_vertical_velocity

.control_poll_jump_or_swim
    LDX #INKEY_JUMP_OR_SWIM
    JSR osbyte_81_inkey
    BCC control_poll_pause
    LDA #&01
    STA player_jump_or_swim_requested
    JMP control_apply_horizontal_movement

.control_poll_pause
    LDX #INKEY_COPY_PAUSE
    JSR osbyte_81_inkey
    BCC control_apply_horizontal_movement

.control_wait_for_unwired_resume_key
    LDX #INKEY_UNWIRED_RESUME
    JSR osbyte_81_inkey
    BCC control_wait_for_unwired_resume_key
    JSR write_system_clock_via_osword_02

.control_apply_horizontal_movement
    LDA horizontal_input_delta
    CMP #PLAYER_HORIZONTAL_INPUT_RIGHT
    BNE control_apply_left_movement
    JSR move_player_right_with_collision

.control_apply_left_movement
    LDA horizontal_input_delta
    CMP #PLAYER_HORIZONTAL_INPUT_LEFT
    BNE control_apply_vertical_movement
    JSR move_player_left_with_collision

.control_apply_vertical_movement
    LDA player_vertical_velocity
    BEQ control_update_slow_damage
    BPL control_move_player_up
    JSR move_player_down_by_velocity
    JMP control_update_slow_damage

.control_move_player_up
    JSR move_player_up_by_velocity

.control_update_slow_damage
    LDA player_display_pointer_high
    CMP #SLOW_DAMAGE_DISPLAY_HIGH_THRESHOLD
    BMI control_tick_slow_damage
    LDY #SLOW_DAMAGE_COUNTDOWN_CLEAR
    LDA (player_display_pointer_low),Y
    AND #SLOW_DAMAGE_DISPLAY_BYTE_MASK
    BNE control_tick_slow_damage
    STY slow_damage_countdown
    JMP control_check_stable_player_state

.control_tick_slow_damage
    DEC slow_damage_countdown
    BNE control_check_stable_player_state
    JSR apply_player_damage_and_redraw_energy
    INC slow_damage_countdown

.control_check_stable_player_state
    LDA player_display_pointer_snapshot_low
    CMP player_display_pointer_low
    BNE control_redraw_after_state_change
    LDA player_horizontal_input_snapshot
    CMP horizontal_input_delta_copy
    BNE control_redraw_after_state_change
    LDA player_display_pointer_snapshot_high
    CMP player_display_pointer_high
    BNE control_redraw_after_state_change
    LDX #INKEY_DROP_ITEM
    JSR osbyte_81_inkey
    BCC control_poll_pick_up
    JSR drop_carried_item

.control_poll_pick_up
    LDX #INKEY_PICK_UP_ITEM
    JSR osbyte_81_inkey
    BCC control_poll_exit
    JSR pick_up_item_below_player

.control_poll_exit
    LDX #INKEY_ESCAPE
    JSR osbyte_81_inkey
    BCC control_poll_sound_off
    LDA #&01
    STA main_loop_exit_flag

.control_poll_sound_off
    LDX #INKEY_SOUND_OFF
    JSR osbyte_81_inkey
    BCC control_poll_sound_on
    LDA #&01
    STA sound_disabled_flag

.control_poll_sound_on
    LDX #INKEY_SOUND_ON
    JSR osbyte_81_inkey
    BCC control_poll_last_chance_chord
    LDA #&00
    STA sound_disabled_flag

.control_poll_last_chance_chord
    LDX #INKEY_LAST_CHANCE_TRIGGER
    JSR osbyte_81_inkey
    BCC control_skip_redraw
    LDY #&05

.control_poll_next_chord_key
    TYA
    PHA
    LDA last_chance_chord_inkey_codes,Y
    TAX
    JSR osbyte_81_inkey
    PLA
    TAY
    BCC control_skip_redraw
    DEY
    BPL control_poll_next_chord_key
    STY reincarnation_cheat_flag
    LDA #VDU_BELL
    JSR OSWRCH

.control_skip_redraw
    JMP control_clear_transient_state

.control_redraw_after_state_change
    JSR wait_vsync_then_call_display_helpers

.control_clear_transient_state
    LDA #&00
    STA horizontal_input_delta
    STA display_grid_row
    STA player_ground_contact_flag
    STA display_grid_column
    SEC
    LDA player_vertical_velocity
    SBC vertical_velocity_step
    STA player_vertical_velocity
    RTS
.poll_controls_and_apply_gameplay_actions_source_end

ASSERT poll_controls_and_apply_gameplay_actions_source = poll_controls_and_apply_gameplay_actions
ASSERT poll_controls_and_apply_gameplay_actions_source_end = &2782
COPYBLOCK poll_controls_and_apply_gameplay_actions_source, poll_controls_and_apply_gameplay_actions_source_end, &3E5A

; Runtime $265A-$2781 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3E5A-$3F81.
CLEAR poll_controls_and_apply_gameplay_actions_source, poll_controls_and_apply_gameplay_actions_source_end


ORG scan_display_column_for_blocking_byte

; Scan down a display-byte column for at most the count
; in $41. Out-of-window pointers, zero bytes, and $C0 bytes advance without a
; hit. Another in-window nonzero byte returns carry set at its pointer. Each
; successful step follows the BBC interleaved display layout: increment within
; an eight-scanline character cell, or add $0279 after scanline seven.
.scan_display_column_for_blocking_byte_source
    LDX #&00

.scan_next_display_column_byte
    JSR test_display_pointer_in_xor_draw_window
    BCS advance_display_column_pointer
    LDY #&00
    LDA (display_pointer_low),Y
    BEQ advance_display_column_pointer
    CMP #&C0
    BEQ advance_display_column_pointer
    SEC
    RTS

.advance_display_column_pointer
    LDA display_pointer_low
    AND #&07
    CMP #&07
    BEQ advance_to_next_mode1_character_row
    INC display_pointer_low

.finish_display_column_pointer_step
    INX
    CPX xor_graphic_character_rows_remaining
    BNE scan_next_display_column_byte
    CLC

.shared_display_scan_rts
    RTS

.advance_to_next_mode1_character_row
    CLC
    LDA display_pointer_low
    ADC #&79
    STA display_pointer_low
    LDA display_pointer_high
    ADC #&02
    STA display_pointer_high
    JMP finish_display_column_pointer_step
.scan_display_column_for_blocking_byte_source_end

ASSERT scan_display_column_for_blocking_byte_source = scan_display_column_for_blocking_byte
ASSERT shared_display_scan_rts = shared_display_scan_return
ASSERT scan_display_column_for_blocking_byte_source_end = adjust_display_pointer_then_scan_markers
COPYBLOCK scan_display_column_for_blocking_byte_source, scan_display_column_for_blocking_byte_source_end, &410B

; Runtime $290B-$293E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $410B-$413E.
CLEAR scan_display_column_for_blocking_byte_source, scan_display_column_for_blocking_byte_source_end

ORG adjust_display_pointer_then_scan_markers

; If the display-pointer low byte is not eight-byte
; aligned, decrement only that byte. Otherwise subtract $0279 from the full
; little-endian pointer. Both paths continue directly into the four-byte
; marker scanner at $2957, preserving the outer caller's stack frame.
.adjust_display_pointer_then_scan_markers_source
    LDA display_pointer_low
    AND #&07
    BNE decrement_display_pointer_low_before_scan
    LDA display_pointer_low
    SEC
    SBC #&79
    STA display_pointer_low
    LDA display_pointer_high
    SBC #&02
    STA display_pointer_high
    JMP scan_four_display_bytes_for_markers

.decrement_display_pointer_low_before_scan
    DEC display_pointer_low
.adjust_display_pointer_then_scan_markers_source_end

ASSERT adjust_display_pointer_then_scan_markers_source = adjust_display_pointer_then_scan_markers
ASSERT adjust_display_pointer_then_scan_markers_source_end = scan_four_display_bytes_for_markers
COPYBLOCK adjust_display_pointer_then_scan_markers_source, adjust_display_pointer_then_scan_markers_source_end, &413F

; Runtime $293F-$2956 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $413F-$4156.
CLEAR adjust_display_pointer_then_scan_markers_source, adjust_display_pointer_then_scan_markers_source_end

ORG move_player_up_by_velocity

; Move the player upwards by however much vertical velocity
; the jet boots have built up.
; player_vertical_steps_remaining is the velocity plus four, shifted right
; twice, so four velocity units buy one step. step_up_by_count is the secondary
; entry for callers that have already chosen a count.
; Each iteration first tests the room edge, and it is player_vertical_position
; that it reads, not the display pointer, even though the two describe the same
; thing. The position is (character row - 5) * 8, so halving it and comparing
; with 9 asks whether the player is above character row 7, the top of the play
; area; unless the shared transition gate blocks it, the player enters the room
; above. Otherwise the marker scan runs from the player display pointer; a clear
; scan applies a signed -2 vertical step and loops until the count runs out.
; A blocked scan is a ceiling. Hitting one below
; PLAYER_CEILING_DAMAGE_VELOCITY simply stops the climb; at or above that
; threshold it costs energy and takes three off the velocity instead.
.move_player_up_by_velocity_source
    CLC
    LDA player_vertical_velocity
    ADC #PLAYER_VERTICAL_VELOCITY_STEP_BIAS
    LSR A
    LSR A

.step_up_by_count
    STA player_vertical_steps_remaining

.climb_one_step
    LDA player_vertical_position
    LSR A
    CMP #&09
    BPL test_ceiling
    LDA vertical_room_transition_cell_flag
    BNE apply_upward_step
    JSR capture_player_state_for_redraw
    JMP enter_room_above

.test_ceiling
    LDA player_display_pointer_low
    STA display_pointer_low
    LDA player_display_pointer_high
    STA display_pointer_high
    JSR adjust_display_pointer_then_scan_markers
    BCC apply_upward_step
    LDA player_vertical_velocity
    CMP #PLAYER_CEILING_DAMAGE_VELOCITY
    BMI stop_climb
    JSR apply_player_damage_and_redraw_energy
    DEC player_vertical_velocity
    DEC player_vertical_velocity
    DEC player_vertical_velocity
    RTS

.stop_climb
    LDA #&00
    STA player_vertical_velocity
    RTS

.apply_upward_step
    LDA #PLAYER_VERTICAL_STEP_UP
    STA vertical_step_delta
    JSR advance_player_vertical_position_and_display_pointer
    DEC player_vertical_steps_remaining
    BNE climb_one_step
    RTS
.move_player_up_by_velocity_source_end

ASSERT move_player_up_by_velocity_source = move_player_up_by_velocity
ASSERT move_player_up_by_velocity_source_end = &28EF
COPYBLOCK move_player_up_by_velocity_source, move_player_up_by_velocity_source_end, &40A7

; Runtime $28A7-$28EE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $40A7-$40EE.
CLEAR move_player_up_by_velocity_source, move_player_up_by_velocity_source_end


ORG scan_four_display_bytes_for_markers

; Inspect DISPLAY_MARKER_SCAN_COUNT bytes separated by
; DISPLAY_MARKER_SCAN_STRIDE. Zero bytes are skipped. DISPLAY_MARKER_WATER
; enables the water environment; either deferred-damage byte requests damage after the
; scan; and DISPLAY_MARKER_IMMEDIATE_DAMAGE applies it immediately. Any other
; nonzero byte, including the post-damage path, marks the column occupied and
; returns carry set. A completed clear scan returns carry clear.
.scan_four_display_bytes_for_markers_source
    LDX #DISPLAY_MARKER_SCAN_COUNT
    LDY #&00
    STY display_grid_column
    STY display_marker_deferred_damage_flag
    STY water_environment_flag
    STY display_marker_scan_auxiliary_state
    JSR test_display_pointer_in_xor_draw_window
    BCS shared_display_scan_return

.scan_next_display_byte
    LDA (display_pointer_low),Y
    BEQ advance_display_scan_offset
    CMP #DISPLAY_MARKER_WATER
    BEQ mark_c0_display_byte
    CMP #DISPLAY_MARKER_DEFERRED_DAMAGE_0A
    BEQ mark_0a_or_05_display_byte
    CMP #DISPLAY_MARKER_DEFERRED_DAMAGE_05
    BEQ mark_0a_or_05_display_byte
    CMP #DISPLAY_MARKER_IMMEDIATE_DAMAGE
    BNE return_occupied_display_byte
    JSR apply_player_damage_and_redraw_energy

.return_occupied_display_byte
    LDA #&01
    STA display_grid_column
    SEC
    RTS

.mark_c0_display_byte
    LDA #WATER_ENVIRONMENT_ACTIVE
    STA water_environment_flag

.advance_display_scan_offset
    TYA
    CLC
    ADC #DISPLAY_MARKER_SCAN_STRIDE
    TAY
    DEX
    BNE scan_next_display_byte
    LDA display_marker_deferred_damage_flag
    CLC
    BEQ shared_display_scan_return
    JSR apply_player_damage_and_redraw_energy
    CLC
    RTS

.mark_0a_or_05_display_byte
    LDA #&01
    STA display_marker_deferred_damage_flag
    JMP advance_display_scan_offset
.scan_four_display_bytes_for_markers_source_end

ASSERT scan_four_display_bytes_for_markers_source = scan_four_display_bytes_for_markers
ASSERT scan_four_display_bytes_for_markers_source_end = &29A2
COPYBLOCK scan_four_display_bytes_for_markers_source, scan_four_display_bytes_for_markers_source_end, &4157

; Runtime $2957-$29A1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4157-$41A1.
CLEAR scan_four_display_bytes_for_markers_source, scan_four_display_bytes_for_markers_source_end

ORG check_player_relative_display_pattern_15

; Align the player pointer low byte, add $0795 into the
; display pointer, and test pattern selector $15. A carry-clear result returns
; through the shared RTS at $2A34; carry set tail-transfers to $337B.
.check_player_relative_display_pattern_15_source
    CLC
    LDA player_display_pointer_low
    AND #&F0
    ADC #&95
    STA display_pointer_low
    LDA player_display_pointer_high
    ADC #&07
    STA display_pointer_high
    LDA #GRAPHIC_COLUMN_JUNCTION
    JSR display_pattern_test
    BCC player_cell_interaction_no_match_return
    JMP display_pattern_match_tail_entry
.check_player_relative_display_pattern_15_source_end

ASSERT check_player_relative_display_pattern_15_source = check_player_relative_display_pattern_15
ASSERT check_player_relative_display_pattern_15_source_end = &2A4E
COPYBLOCK check_player_relative_display_pattern_15_source, check_player_relative_display_pattern_15_source_end, &4235

; Runtime $2A35-$2A4D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4235-$424D.
CLEAR check_player_relative_display_pattern_15_source, check_player_relative_display_pattern_15_source_end

ORG room_moving_object_graphic_state_block

; Zero-initialised mutable workspace used by the indexed
; XOR renderer, the two room-entity update clusters and the timed room effect.
; Even offsets $122A/$122C/$122E/$1230 form the four selector-delta slots;
; $1231-$123D are interleaved entity state, $1239 is also the tick dispatcher
; selector, and $1242-$124A are the timed-effect and room-effect fields. Odd
; padding/state bytes are retained explicitly because indexed accesses can
; address them even where no stronger gameplay meaning is yet proved.
.room_entity_and_effect_state_source
    EQUB &00                         ; room-moving-object workspace byte 0
    EQUB &00                         ; $122A selector delta slot 0
    EQUB &00                         ; room-moving-object workspace byte 2
    EQUB &00                         ; $122C selector delta slot 1
    EQUB &00                         ; room-moving-object workspace byte 4
    EQUB &00                         ; $122E selector delta slot 2
    EQUB &00                         ; room-moving-object workspace byte 6
    EQUB &00                         ; $1230 selector delta slot 3
    SKIP 9                          ; $1231-$1239 primary entity fields/dispatcher
    SKIP 8                          ; $123A-$1241 secondary room enemy fields
    EQUB &00                         ; $1242 timed effect selector
    EQUB &00, &00                    ; $1243/$1244 saved effect display pointer
    SKIP 6                          ; $1245-$124A room effect/entity state
.room_entity_and_effect_state_source_end

ASSERT room_entity_and_effect_state_source = room_moving_object_graphic_state_block
ASSERT room_entity_and_effect_state_source_end = enter_run_terminal_interaction
COPYBLOCK room_entity_and_effect_state_source, room_entity_and_effect_state_source_end, &2A29
CLEAR room_entity_and_effect_state_source, room_entity_and_effect_state_source_end

ORG enter_run_terminal_interaction

; A three-byte JMP vector to $20B3, giving its caller a
; fixed entry independent of where that routine sits.
; Like enter_copy_16_byte_graphic_to_display at $1226, it is wedged into the
; runtime variable block rather than sitting in the table at $1200: $124A before
; it is the lift/hazard slot count that
; initialise_lifts_and_hazards_from_table writes, and $124E after it is the
; first instruction of store_byte_and_advance_source_pointer. So the three bytes
; are a vector between a variable and a routine, not part of either.
.enter_run_terminal_interaction_source
    JMP run_terminal_interaction
.enter_run_terminal_interaction_source_end

ASSERT enter_run_terminal_interaction_source = enter_run_terminal_interaction
ASSERT enter_run_terminal_interaction_source_end = &124E
COPYBLOCK enter_run_terminal_interaction_source, enter_run_terminal_interaction_source_end, &2A4B

; Runtime $124B-$124D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2A4B-$2A4D.
CLEAR enter_run_terminal_interaction_source, enter_run_terminal_interaction_source_end

ORG test_item_code_matches_either_slot

; Compare the item code in A with the two carried-item
; slots. Return carry set through the local exit on either match; if neither
; matches, branch to the enclosing routine's shared CLC/RTS at $212A.
.test_item_code_matches_either_slot_source
    CMP item_slot_first
    BEQ item_code_matches_slot
    CMP item_slot_second
    BNE terminal_return_carry_clear

.item_code_matches_slot
    SEC
    RTS
.test_item_code_matches_either_slot_source_end

ASSERT test_item_code_matches_either_slot_source = test_item_code_matches_either_slot
ASSERT test_item_code_matches_either_slot_source_end = &2146
COPYBLOCK test_item_code_matches_either_slot_source, test_item_code_matches_either_slot_source_end, &393C

; Runtime $213C-$2145 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $393C-$3945.
CLEAR test_item_code_matches_either_slot_source, test_item_code_matches_either_slot_source_end

ORG process_terminal_password_markers

; Continue the terminal stream's $FD password marker and
; $FC collected-password-list marker. A collected current password sets the
; result, applies its indexed activation record, and index 5 additionally
; writes $0A to $397C. An absent password jumps to the denial text at offset
; $42. The list path begins scanning eight flags and printing inline strings;
; its next code block and all inline bytes begin at $217A and remain original.
.process_terminal_password_markers_source
    TXA
    PHA
    LDX reference_pair_primary_value
    LDA collected_password_flags,X
    CMP #&01
    BNE terminal_password_denied
    STA terminal_interaction_result
    CPX #&05
    BNE activate_terminal_password
    LDA #&0A
    STA room_F3_row_1_cell_3

.activate_terminal_password
    JSR write_indexed_terminal_activation_value
    PLA
    TAX
    INX
    JMP terminal_stream_next_byte

.terminal_password_denied
    PLA
    LDX #&42
    JMP terminal_stream_next_byte

.terminal_password_list_marker
    TXA
    PHA
    LDX #&00
    LDA #&15
    STA terminal_password_cursor_row

.test_next_terminal_password_flag
    LDA collected_password_flags,X
    BEQ terminal_password_flag_absent_step
    JSR print_inline_vdu_stream
.terminal_password_list_cursor_source
    EQUB VDU_TEXT_AT, &1B, &00
    LDA terminal_password_cursor_row
    JSR OSWRCH
    INC terminal_password_cursor_row
    TXA
    PHA
    JSR print_password_number_and_text
    PLA
    TAX
    INX
    CPX #&08
    BNE test_next_terminal_password_flag
    PLA
    TAX
    INX
    JMP terminal_stream_next_byte
.process_terminal_password_markers_source_end

ASSERT process_terminal_password_markers_source = process_terminal_password_markers
ASSERT terminal_password_list_cursor_source = &217A
ASSERT process_terminal_password_markers_source_end = terminal_interaction_text_stream
COPYBLOCK process_terminal_password_markers_source, process_terminal_password_markers_source_end, &3946

; Runtime $2146-$2195 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3946-$3995.
CLEAR process_terminal_password_markers_source, process_terminal_password_markers_source_end

ORG terminal_interaction_text_stream
; Control-marked stream consumed by run_terminal_interaction:
; zero ends the stream; $FC inserts the collected-password list; $FD tests the
; current password; $FE selects the granted continuation; $FF skips to the next
; message alternative.
.terminal_interaction_text_stream_source
    EQUB VDU_TEXT_AT, &07, &13
    EQUS "TERMINAL "
    EQUB &00
    EQUB VDU_TEXT_AT, &1A, &11
    EQUS "PASSWORDS"
    EQUB &FC
    EQUB VDU_TEXT_AT, &05, &17
    EQUS "ACCESS "
    EQUB &FE
    EQUS "GRANTED"
    EQUB &FD
    EQUB VDU_TEXT_AT, &07, &1A
    EQUS "ACTIVATED"
    EQUB &FF
    EQUS " DENIED"
    EQUB &FF
    EQUB VDU_TEXT_AT, &04, &1A
    EQUS "INVALID PASSWORD"
    EQUB &FF, &00
.terminal_interaction_text_stream_source_end
ASSERT terminal_interaction_text_stream_source = terminal_interaction_text_stream
ASSERT terminal_interaction_text_stream_source_end = terminal_interaction_text_padding
COPYBLOCK terminal_interaction_text_stream_source, terminal_interaction_text_stream_source_end, &3996
CLEAR terminal_interaction_text_stream_source, terminal_interaction_text_stream_source_end

ORG terminal_interaction_text_padding
; Nineteen zero bytes align the following game-entry vector page at $2200.
.terminal_interaction_text_padding_source
    SKIP &13
.terminal_interaction_text_padding_source_end
ASSERT terminal_interaction_text_padding_source = terminal_interaction_text_padding
ASSERT terminal_interaction_text_padding_source_end = enter_main_gameplay_loop
COPYBLOCK terminal_interaction_text_padding_source, terminal_interaction_text_padding_source_end, &39ED
CLEAR terminal_interaction_text_padding_source, terminal_interaction_text_padding_source_end


ORG check_player_candidate_bounds_overlap

; Reject non-overlapping horizontal and vertical bounds
; through the shared carry-clear return at $2B35. Nonzero $6C selects a fixed
; $17 vertical extent and advances the candidate coordinate at $3C by six.
; If all four comparisons overlap, execution falls through to the original
; action routine at $2B88. The branches deliberately consume N, not V-aware
; signed comparisons, and the second LSR carry deliberately feeds ADC $41.
.check_player_candidate_bounds_overlap_source
    LDA xor_graphic_repeat_source_scanlines
    BEQ candidate_bounds_mode_ready
    LDA #&17
    STA xor_graphic_character_rows_remaining
    CLC
    LDA candidate_half_vertical_position
    ADC #&06
    STA candidate_half_vertical_position

.candidate_bounds_mode_ready
    CLC
    LDA player_horizontal_position
    ADC #&03
    CMP candidate_horizontal_position
    BMI player_candidate_no_overlap_return

    CLC
    LDA candidate_horizontal_position
    ADC #&03
    CMP player_horizontal_position
    BMI player_candidate_no_overlap_return

    LDA player_vertical_position
    LSR A
    CMP candidate_half_vertical_position
    BPL player_candidate_no_overlap_return

    LDA player_vertical_position
    LSR A
    ADC xor_graphic_character_rows_remaining
    CMP candidate_half_vertical_position
    BMI player_candidate_no_overlap_return
.check_player_candidate_bounds_overlap_source_end

ASSERT check_player_candidate_bounds_overlap_source = check_player_candidate_bounds_overlap
ASSERT check_player_candidate_bounds_overlap_source_end = apply_player_damage_and_redraw_energy
COPYBLOCK check_player_candidate_bounds_overlap_source, check_player_candidate_bounds_overlap_source_end, &4357

; Runtime $2B57-$2B87 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4357-$4387.
CLEAR check_player_candidate_bounds_overlap_source, check_player_candidate_bounds_overlap_source_end

ORG apply_player_damage_and_redraw_energy

; Mark this tick's damage, play pitch 6, subtract
; one from the stored energy, and set the main-loop exit flag only when the
; decrement reaches zero. Redraw the affected energy-bar segment either way
; and return carry set. The separately lifted $2B8F entry deliberately skips
; the contact/damage flag write and sound while sharing the decrement, death,
; redraw and exit.
.apply_player_damage_and_redraw_energy_source
    LDA #&06
    STA player_contact_or_damage_flag
    JSR submit_sound_block_with_pitch

.decrement_player_energy_and_redraw_source
    DEC player_energy
    BNE redraw_damaged_energy
    LDA #&01
    STA main_loop_exit_flag

.redraw_damaged_energy
    JSR redraw_energy_bar_segment
    SEC
    RTS
.apply_player_damage_and_redraw_energy_source_end

ASSERT apply_player_damage_and_redraw_energy_source = apply_player_damage_and_redraw_energy
ASSERT decrement_player_energy_and_redraw_source = decrement_player_energy_and_redraw
ASSERT apply_player_damage_and_redraw_energy_source_end = &2B9C
COPYBLOCK apply_player_damage_and_redraw_energy_source, apply_player_damage_and_redraw_energy_source_end, &4388

; Runtime $2B88-$2B9B overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4388-$439B.
CLEAR apply_player_damage_and_redraw_energy_source, apply_player_damage_and_redraw_energy_source_end

; The two tile-run painters are assembled here rather than in runtime order.
; Their COPYBLOCK destinations, loaded $2B61-$2BB1, are the same image bytes as
; which lie inside the region
; check_player_candidate_bounds_overlap assembles at runtime $2B57-$2B87. The
; CLEAR above releases that region, so these blocks must follow it.

ORG tile_run_shared_rts

; The blank-tile run painter and the two entries that
; share it. $1361 is the zero-length RTS both run painters branch to. $1362
; presets a run of eight tiles and falls through; the initial-render trace
; reaches it 14 times through JMP $1362. $1364 is the general entry, taking
; the run length in X. Each tile goes through the 16-byte graphic blitter,
; which advances the display pointer by 16, and X = 0 is rejected up front
; rather than wrapping to a 256-tile run. The trace enters at $1364 123 times
; and issues 307 blitter calls; the observed callers are the room element
; loop at $19AA/$19B2 and the tile dispatcher at $14AD/$14F4/$1500.
.draw_blank_tile_run_source
    RTS

.draw_eight_blank_tiles_entry
    LDX #&08

.draw_blank_tile_run_entry
    CPX #&00
    BEQ draw_blank_tile_run_source
    LDA #GRAPHIC_BLANK

.draw_next_blank_tile
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_blank_tile
    RTS
.draw_blank_tile_run_source_end

ASSERT draw_blank_tile_run_source = tile_run_shared_rts
ASSERT draw_eight_blank_tiles_entry = draw_eight_blank_tiles
ASSERT draw_blank_tile_run_entry = draw_blank_tile_run
ASSERT draw_blank_tile_run_source_end = &1371
COPYBLOCK draw_blank_tile_run_source, draw_blank_tile_run_source_end, &2B61

; Runtime $1361-$1370 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2B61-$2B70.
CLEAR draw_blank_tile_run_source, draw_blank_tile_run_source_end

ORG test_marker_below_player

; Report whether an $FF marker sits three Mode 1 character
; rows below the player.
; $29A2 is the shared carry-set exit, reached both by falling in from elsewhere
; and by the two tests below it. $29A4 is the test proper: two bytes are sampled
; at the three-row pointer, at offsets 0 and $18, and either being $FF leaves
; through that exit. Neither matching returns carry clear.
; The two offsets are three cells apart, so this samples the ends of a span
; rather than two unrelated bytes.
.test_marker_below_player_source
    SEC
    RTS

.sample_markers_below_player
    JSR set_display_pointer_three_mode1_rows_below_player
    LDY #&00
    LDA (display_pointer_low),Y
    CMP #&FF
    BEQ test_marker_below_player_source
    LDY #PLAYER_COLLISION_SPAN_BYTES
    LDA (display_pointer_low),Y
    CMP #&FF
    BEQ test_marker_below_player_source
    CLC
    RTS
.test_marker_below_player_source_end

ASSERT test_marker_below_player_source = test_marker_below_player
ASSERT test_marker_below_player_source_end = &29B9
COPYBLOCK test_marker_below_player_source, test_marker_below_player_source_end, &41A2

; Runtime $29A2-$29B8 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $41A2-$41B8.
CLEAR test_marker_below_player_source, test_marker_below_player_source_end


ORG xor_draw_player_two_parts

; Draw the player as two XOR parts, called from the vsync
; display helpers so it runs once per frame.
; The sign of player_horizontal_input_snapshot selects the left- or right-facing
; upper and lower pointer pair. The upper body is two character rows drawn at
; player_display_pointer_snapshot; the lower body is one row drawn immediately
; below it. Ground contact and the low bit of the saved horizontal position
; select the alternate stepping frame. The lower draw is tail-called, so the XOR
; renderer returns directly to this routine's caller.
.xor_draw_player_two_parts_source
    LDX #PLAYER_UPPER_RIGHT_POINTER_OFFSET
    LDA player_horizontal_input_snapshot
    BPL draw_first_player_part
    LDX #PLAYER_UPPER_LEFT_POINTER_OFFSET

.draw_first_player_part
    LDA #PLAYER_UPPER_BODY_CHARACTER_ROWS
    STA xor_graphic_character_rows_remaining
    LDA player_display_pointer_snapshot_high
    STA display_pointer_high
    LDA player_display_pointer_snapshot_low
    JSR select_graphic_then_xor_draw
    LDX #PLAYER_LOWER_STEP_RIGHT_POINTER_OFFSET
    LDA player_horizontal_input_snapshot
    BPL select_second_part_frame
    LDX #PLAYER_LOWER_STEP_LEFT_POINTER_OFFSET

.select_second_part_frame
    LDA player_ground_contact_snapshot
    BEQ draw_second_player_part
    LDA player_horizontal_position_snapshot
    LSR A
    BCC draw_second_player_part
    DEX
    DEX

.draw_second_player_part
    LDA #PLAYER_LOWER_BODY_CHARACTER_ROWS
    STA xor_graphic_character_rows_remaining
    LDA display_pointer_low
    JMP select_graphic_then_xor_draw
.xor_draw_player_two_parts_source_end

ASSERT xor_draw_player_two_parts_source = xor_draw_player_two_parts
ASSERT xor_draw_player_two_parts_source_end = &2ABA
COPYBLOCK xor_draw_player_two_parts_source, xor_draw_player_two_parts_source_end, &4289

; Runtime $2A89-$2AB9 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4289-$42B9.
CLEAR xor_draw_player_two_parts_source, xor_draw_player_two_parts_source_end


ORG draw_room_row_cells

; Draw one row of room cells.
; room_graphics_column is copied into tile_pair_source_selector, which
; is what makes alternating tiles line up across a row. Five cells are then read
; through the room data pointer, Y counting 0 to 4, and each is drawn by the
; cell dispatcher.
; Each cell byte is kept whole in $1225 for the dispatcher to examine, and its
; low six bits become room_cell_type_index for record/character dispatch. The tile pair
; selector is restored from $F8 after every cell, because the dispatcher may
; have advanced it.
; draw_and_initialise_room calls this once per cell position as it walks a room,
; 697 times across 29 rooms.
.draw_room_row_cells_source
    LDA room_graphics_column
    STA tile_pair_source_selector
    LDY #&00

.draw_next_cell
    LDA #&00
    STA room_cell_mirror_state
    LDA (room_data_pointer_low),Y
    STA current_room_cell
    AND #ROOM_CELL_TYPE_MASK
    STA room_cell_type_index
    STY current_room_cell_offset
    JSR dispatch_room_cell
    LDA tile_pair_source_selector
    STA room_graphics_column
    LDY current_room_cell_offset
    INY
    CPY #ROOM_CELLS_PER_DRAW_ROW
    BNE draw_next_cell
    RTS
.draw_room_row_cells_source_end

ASSERT draw_room_row_cells_source = draw_room_row_cells
ASSERT draw_room_row_cells_source_end = &12A8
COPYBLOCK draw_room_row_cells_source, draw_room_row_cells_source_end, &2A84

; Runtime $1284-$12A7 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2A84-$2AA7.
CLEAR draw_room_row_cells_source, draw_room_row_cells_source_end


ORG enter_room_to_the_right

; The right-edge transition, entered when
; move_player_right_with_collision finds the horizontal position already at $4C.
; The player is placed at zero, the left edge, and the display pointer moved
; back by $0260. The reference at $90 is then incremented through the $1211
; vector before the player is redrawn by tail jump.
; This is the exact mirror of enter_room_to_the_left: SEC/SBC against CLC/ADC,
; position zero against $4C, and the incrementing vector against the
; decrementing one, which is the pair the display_action_jump_table five-byte
; entries exist to provide.
.enter_room_to_the_right_source
    LDA #&00
    STA player_horizontal_position
    SEC
    LDA player_display_pointer_low
    SBC #&60
    STA player_display_pointer_low
    LDA player_display_pointer_high
    SBC #&02
    STA player_display_pointer_high
    JSR increment_reference_then_draw_and_initialise_room
    JMP xor_draw_player_two_parts
.enter_room_to_the_right_source_end

ASSERT enter_room_to_the_right_source = enter_room_to_the_right
ASSERT enter_room_to_the_right_source_end = &2AE6
COPYBLOCK enter_room_to_the_right_source, enter_room_to_the_right_source_end, &42CF

; Runtime $2ACF-$2AE5 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $42CF-$42E5.
CLEAR enter_room_to_the_right_source, enter_room_to_the_right_source_end


ORG capture_player_state_for_redraw

; Copy the live player state into the shadow copies the
; sprite renderer draws from: display pointer, horizontal input, ground-contact
; state and horizontal position.
; wait_vsync_then_call_display_helpers calls this between its two XOR draws, so
; the first draw erases the player using the previous snapshot and the second
; draws it using this one. Every value it writes is read by
; xor_draw_player_two_parts as the position, facing and walking-frame state.
.capture_player_state_for_redraw_source
    LDA player_display_pointer_low
    STA player_display_pointer_snapshot_low
    LDA player_display_pointer_high
    STA player_display_pointer_snapshot_high
    LDA horizontal_input_delta_copy
    STA player_horizontal_input_snapshot
    LDA player_ground_contact_flag
    STA player_ground_contact_snapshot
    LDA player_horizontal_position
    STA player_horizontal_position_snapshot
.return_from_room_transition
    RTS
.capture_player_state_for_redraw_source_end

ASSERT capture_player_state_for_redraw_source = capture_player_state_for_redraw
ASSERT capture_player_state_for_redraw_source_end = &2ACF
COPYBLOCK capture_player_state_for_redraw_source, capture_player_state_for_redraw_source_end, &42BA

; Runtime $2ABA-$2ACE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $42BA-$42CE.
CLEAR capture_player_state_for_redraw_source, capture_player_state_for_redraw_source_end


ORG dispatch_room_cell

; Decide what one room cell byte draws.
; Bit 7 sends the cell to the character renderer, so a set high bit means the
; cell is text and its low six bits are a character index. Otherwise the low six
; bits are doubled and used to index the vector table at $12D2, whose entry is
; pushed onto the stack and reached by the return, which is how one byte selects
; among many tile drawers without a jump table lookup in line.
; Bit 6 then decides the direction: when set, room_graphics_column is
; mirrored by subtracting it from ROOM_COLUMN_LAST and the XOR display-pointer
; low byte is set to $FF, which makes the cell draw in reverse. The column is
; returned in A.
.dispatch_room_cell_source
    LDA current_room_cell
    ASL A
    BCC dispatch_through_vector_table
    JMP draw_character_row_as_tiles

.dispatch_through_vector_table
    ASL room_cell_type_index
    LDX room_cell_type_index
    LDA room_cell_draw_dispatch_table+1,X
    PHA
    LDA room_cell_draw_dispatch_table,X
    PHA
    LDA current_room_cell
    ASL A
    ASL A
    BCC return_column_counter

.mirror_cell_direction
    LDA #ROOM_COLUMN_LAST
    SEC
    SBC room_graphics_column
    STA room_graphics_column
    LDA #&FF
    STA room_cell_mirror_state

.return_column_counter
    LDA room_graphics_column
    RTS

; One handler-minus-one word for each six-bit room-cell type. The code above
; pushes the selected word and RTS enters its handler.
.room_cell_draw_dispatch_table_source
    EQUW draw_eight_blank_tiles-1 ; ROOM_CELL_BLANK
    EQUW draw_pillar_framed_or_pattern_row-1 ; ROOM_CELL_PILLAR_FRAMED_PATTERN
    EQUW draw_eight_alternating_tiles-1 ; ROOM_CELL_ALTERNATING_TILES
    EQUW draw_right_edge_tile_pair-1 ; ROOM_CELL_RIGHT_EDGE_PAIR
    EQUW draw_left_edge_tile_pair-1 ; ROOM_CELL_LEFT_EDGE_PAIR
    EQUW draw_curved_bowl_after_alternating_prefix-1 ; ROOM_CELL_CURVED_BOWL_RIGHT
    EQUW draw_curved_bowl_before_alternating_suffix-1 ; ROOM_CELL_CURVED_BOWL_LEFT
    EQUW draw_first_key_column_motif-1 ; ROOM_CELL_FIRST_KEY_MOTIF
    EQUW draw_second_key_column_motif-1 ; ROOM_CELL_SECOND_KEY_MOTIF; entry load remains unexecuted
    EQUW draw_repeated_87_blank_pairs_by_state-1 ; ROOM_CELL_STATE_87_PAIRS
    EQUW draw_bordered_horizontal_bar_row-1 ; ROOM_CELL_BORDERED_BAR
    EQUW draw_centered_slope_pair_by_column-1 ; ROOM_CELL_CENTERED_SLOPE
    EQUW draw_blank_state_column_motif-1 ; ROOM_CELL_BLANK_STATE_MOTIF
    EQUW draw_column_sensitive_room_patterns-1 ; ROOM_CELL_COLUMN_PATTERNS
    EQUW draw_fixed_center_motif_by_column-1 ; ROOM_CELL_FIXED_CENTER_MOTIF
    EQUW draw_pillar_base_row_in_last_column-1 ; ROOM_CELL_LAST_COLUMN_PILLAR
    EQUW draw_alternating_or_curved_bowl_row-1 ; ROOM_CELL_ALTERNATING_OR_CURVED_BOWL
    EQUW draw_table_selected_four_tile_half_row-1 ; ROOM_CELL_FOUR_TILE_HALF_ROW
    EQUW draw_record_08_or_edge_pattern_row-1 ; ROOM_CELL_RECORD_08_EDGE
    EQUW draw_58_59_pair_or_edge_pattern_row-1 ; ROOM_CELL_58_59_EDGE
    EQUW draw_ff_state_column_motif-1 ; ROOM_CELL_FF_STATE_MOTIF
    EQUW draw_narrow_bar_fixture_row-1 ; ROOM_CELL_NARROW_BAR_FIXTURE
    EQUW draw_last_column_special_pair_row-1 ; ROOM_CELL_LAST_COLUMN_SPECIAL
    EQUW draw_state_selected_13_center_row-1 ; ROOM_CELL_STATE_13_CENTER; alternate layout remains unexecuted
    EQUW draw_blank_marker_before_alternating_suffix-1 ; ROOM_CELL_BLANK_BEFORE_SUFFIX
    EQUW draw_blank_marker_after_alternating_prefix-1 ; ROOM_CELL_BLANK_AFTER_PREFIX
    EQUW draw_room_flag_then_fixed_pair_row-1 ; ROOM_CELL_FLAG_AND_FIXED_PAIR
    EQUW draw_table_selected_left_half_row-1 ; ROOM_CELL_LEFT_HALF_SEQUENCE
    EQUW draw_two_13_two_beam_two_13_two_pattern-1 ; ROOM_CELL_13_BEAM_PATTERN
    EQUW draw_left_half_sequence_twice_or_13_beam_pattern-1 ; ROOM_CELL_LEFT_SEQUENCE_OR_BEAM
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_MUSIC_ROOM_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_LEVEL_SECTOR_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_ELEPHANT_HOUSE_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_JOKE_SHOP_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_TELEPORT_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_ARMOURY_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_HYDROPONICS_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_HYDROCHLORIC_ACID_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_SODIUM_HYDROXIDE_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_TIME_WARP_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_ORACLE_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_OPTICIAN_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_CHEMICAL_SUPPLIES_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_GHOST_MAZE_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_CHAPEL_SIGN
    EQUW draw_room_sign_or_collect_password-1 ; ROOM_CELL_PASSWORD_PROMPT
    EQUW select_blank_or_right_half_pattern_by_column-1 ; ROOM_CELL_RIGHT_HALF_PATTERN
    EQUW set_ff_state_and_draw_last_column_special_row-1 ; ROOM_CELL_FF_LAST_COLUMN
    EQUW draw_column_gated_58_59_pair_row-1 ; ROOM_CELL_COLUMN_GATED_58_59
    EQUW draw_fixed_pair_gap_row-1 ; ROOM_CELL_FIXED_PAIR_GAP
    EQUW draw_bordered_checker_diagonal_row-1 ; ROOM_CELL_BORDERED_CHECKER
    EQUW draw_and_configure_dynamic_room_object-1 ; ROOM_CELL_DYNAMIC_OBJECT
    EQUW draw_or_configure_secondary_dynamic_object-1 ; ROOM_CELL_SECONDARY_DYNAMIC_OBJECT
    EQUW draw_centered_alternating_run_by_column-1 ; ROOM_CELL_CENTERED_ALTERNATING
    EQUW draw_alternating_only_in_columns_three_or_seven-1 ; ROOM_CELL_ALTERNATING_COLUMNS_3_7
    EQUW draw_alternating_only_in_column_three-1 ; ROOM_CELL_ALTERNATING_COLUMN_3
    EQUW draw_alternating_only_in_last_column-1 ; ROOM_CELL_ALTERNATING_LAST_COLUMN
    EQUW draw_alternating_in_right_half-1 ; ROOM_CELL_ALTERNATING_RIGHT_HALF
    EQUW draw_blank_then_configure_column_seven_object-1 ; ROOM_CELL_COLUMN_7_OBJECT
    EQUW draw_table_selected_sequence_in_columns_five_to_seven-1 ; ROOM_CELL_COLUMNS_5_TO_7_SEQUENCE
    EQUW draw_transition_row_by_column-1 ; ROOM_CELL_TRANSITION_3C
    EQUW draw_table_selected_eight_tiles_in_columns_four_five-1 ; ROOM_CELL_COLUMNS_4_5_SEQUENCE
    EQUW draw_left_edge_or_full_last_column-1 ; ROOM_CELL_LEFT_EDGE_OR_FULL
    EQUW draw_right_edge_or_full_last_column-1 ; ROOM_CELL_RIGHT_EDGE_OR_FULL
.room_cell_draw_dispatch_table_source_end

; Cell type $0F's handler. A is the current room column. Columns zero through
; six draw blanks; column seven draws eight pillar/base tiles.
.draw_pillar_base_row_in_last_column_source
    CMP #ROOM_COLUMN_LAST
    BNE draw_eight_blank_tiles
    LDX #&08
.draw_next_pillar_base_tile
    LDA #GRAPHIC_PILLAR_BASE
    JSR apply_mirror_flag_then_copy_graphic
    DEX
    BNE draw_next_pillar_base_tile
    RTS
.dispatch_room_cell_source_end

ASSERT dispatch_room_cell_source = dispatch_room_cell
ASSERT room_cell_draw_dispatch_table_source = room_cell_draw_dispatch_table
ASSERT room_cell_draw_dispatch_table_source_end-room_cell_draw_dispatch_table_source = 64*2
ASSERT room_cell_draw_dispatch_table_source_end = draw_pillar_base_row_in_last_column
ASSERT draw_pillar_base_row_in_last_column_source = draw_pillar_base_row_in_last_column
ASSERT dispatch_room_cell_source_end = tile_run_shared_rts


ORG enter_room_to_the_left

; The left-edge room transition, entered when
; move_player_left_with_collision finds the horizontal position already zero.
; The player is placed at $4C, the right edge, and the display pointer advanced
; by $0260. The reference value at $90 is then decremented through the
; $120C vector before the player is redrawn by a tail jump, so the room index
; moves one step and the new room is what the redraw lands on.
.enter_room_to_the_left_source
    LDA #PLAYER_RIGHT_EDGE_POSITION
    STA player_horizontal_position
    CLC
    LDA player_display_pointer_low
    ADC #LO(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA player_display_pointer_low
    LDA player_display_pointer_high
    ADC #HI(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA player_display_pointer_high
    JSR decrement_reference_then_draw_and_initialise_room
    JMP xor_draw_player_two_parts
.enter_room_to_the_left_source_end

ASSERT enter_room_to_the_left_source = enter_room_to_the_left
ASSERT enter_room_to_the_left_source_end = &2AFD
COPYBLOCK enter_room_to_the_left_source, enter_room_to_the_left_source_end, &42E6

; Runtime $2AE6-$2AFC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $42E6-$42FC.
CLEAR enter_room_to_the_left_source, enter_room_to_the_left_source_end


ORG enter_room_below

; The downward room transition, reached from the vertical
; mover when the halved vertical position is from $60 through $6B, beyond the
; bottom of the room. As in enter_room_above, shifting
; vertical_room_transition_cell_flag abandons the transition when its low bit is set.
; Otherwise the horizontal position is converted back into a display pointer,
; that pointer is advanced by $3C80, and the player is placed at vertical
; position zero, the top of the new room. The $1209 vector increments the
; secondary room reference at $8F and redraws the room; the player is then
; redrawn. Landing on level 8 additionally tail-calls the cross-room robot/ghost
; initialiser, while every other level returns through the shared RTS at $2ACE.
.enter_room_below_source
    LSR vertical_room_transition_cell_flag
    BCS return_from_room_transition
    JSR set_player_pointer_from_horizontal_position
    CLC
    LDA player_display_pointer_low
    ADC #LO(QUEST_DISPLAY_START)
    STA player_display_pointer_low
    LDA player_display_pointer_high
    ADC #HI(QUEST_DISPLAY_START)
    STA player_display_pointer_high
    LDA #PLAYER_TOP_EDGE_VERTICAL_POSITION
    STA player_vertical_position
    JSR enter_advance_secondary_reference_and_pointer
    JSR xor_draw_player_two_parts
    LDA reference_pair_secondary_value
    CMP #CROSS_ROOM_GHOST_FIRST_LEVEL
    BNE return_from_room_transition
    JMP initialise_cross_room_robot_ghost_from_record
.enter_room_below_source_end

ASSERT enter_room_below_source = enter_room_below
ASSERT enter_room_below_source_end = &2B24
COPYBLOCK enter_room_below_source, enter_room_below_source_end, &42FD

; Runtime $2AFD-$2B23 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $42FD-$4323.
CLEAR enter_room_below_source, enter_room_below_source_end


ORG enter_room_above

; The upward room transition, reached from the vertical
; mover when the halved vertical position falls below 9, the top of the room.
; vertical_room_transition_cell_flag is shifted and a set carry abandons the
; transition through the shared carry-clear exit. It is a cell attribute, not a room one: the room decoder clears
; it and then sets it from a shifted cell bit, so
; the ceiling is passable cell by cell.
; Otherwise $2B24 runs, rebuilding the display pointer as $35 times 8, the
; vertical position is set to $D0, and the pointer is advanced by $7D80. Those
; two agree, and together they fix the scale of $2C: $35 * 8 + $7D80 lands in
; character row 31, and $D0 over 8 plus 5 is 31. The start point's $B0 gives 27,
; the row its own pointer encodes, so one formula fits both. The reference is stepped through the $1203 vector, the vertical
; velocity incremented, and the player redrawn by tail jump.
; Leaving through the top and arriving near the bottom is what makes this the
; room above rather than a move within one room.
.enter_room_above_source
    LSR vertical_room_transition_cell_flag
    BCS player_candidate_no_overlap_return
    JSR set_player_pointer_from_horizontal_position
    LDA #PLAYER_BOTTOM_EDGE_VERTICAL_POSITION
    STA player_vertical_position
    CLC
    LDA player_display_pointer_low
    ADC #LO(PLAYER_BOTTOM_ROW_POINTER_BASE)
    STA player_display_pointer_low
    LDA player_display_pointer_high
    ADC #HI(PLAYER_BOTTOM_ROW_POINTER_BASE)
    STA player_display_pointer_high
    JSR enter_retreat_secondary_reference_and_pointer
    INC player_vertical_velocity
    JMP xor_draw_player_two_parts
.enter_room_above_source_end

ASSERT enter_room_above_source = enter_room_above
ASSERT enter_room_above_source_end = &2B57
COPYBLOCK enter_room_above_source, enter_room_above_source_end, &4337

; Runtime $2B37-$2B56 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4337-$4356.
CLEAR enter_room_above_source, enter_room_above_source_end


ORG set_player_pointer_from_horizontal_position

; Set the player display pointer to the horizontal position
; multiplied by eight, by three shifts of the sixteen-bit pair.
; Eight is one Mode 1 character cell, the same stride the one-cell steps apply,
; so this recomputes the pointer from scratch rather than adjusting it. The
; carry-clear RTS at $2B35 is shared with other routines and runs far more often
; than this entry.
.set_player_pointer_from_horizontal_position_source
    LDA player_horizontal_position
    STA player_display_pointer_low
    LDA #&00
    STA player_display_pointer_high
    LDX #&03

.set_player_pointer_from_horizontal_position_branch_1
    ASL player_display_pointer_low
    ROL player_display_pointer_high
    DEX
    BNE set_player_pointer_from_horizontal_position_branch_1
    CLC
    RTS
.set_player_pointer_from_horizontal_position_source_end

ASSERT set_player_pointer_from_horizontal_position_source = set_player_pointer_from_horizontal_position
ASSERT set_player_pointer_from_horizontal_position_source_end = &2B37
COPYBLOCK set_player_pointer_from_horizontal_position_source, set_player_pointer_from_horizontal_position_source_end, &4324

; Runtime $2B24-$2B36 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4324-$4336.
CLEAR set_player_pointer_from_horizontal_position_source, set_player_pointer_from_horizontal_position_source_end


ORG draw_eight_alternating_tiles

; The $1371 entry supplies a count of eight, then $1373
; draws a run of X tiles alternating between two graphic
; indices. Bit 0 of $F8 selects which stored pair is copied into the working
; pair at $7FF9/$7FFA: clear takes $7FFC/$7FFD, set takes $7FFE/$7FFF. Each
; tile then selects the second index when bits 0-4 of the display pointer low
; byte equal $10 and the first index otherwise. The blitter advances that
; pointer by 16 per tile, so the two indices alternate on consecutive tiles;
; the initial-render trace splits 162 first-index against 156 second-index
; draws across 318 tiles. X = 0 shares the $1361 RTS with the blank run.
.draw_alternating_tile_run_source
    LDX #&08
.draw_alternating_tile_run_entry_source
    CPX #&00
    BEQ draw_blank_tile_run_source
    LDA tile_pair_source_selector
    ROR A
    BCS load_alternate_tile_pair
    LDA primary_tile_pair_first
    STA active_tile_pair_first
    LDA primary_tile_pair_second
    STA active_tile_pair_second

.draw_next_alternating_tile
    LDA display_pointer_low
    AND #&1F
    CMP #&10
    BEQ draw_second_tile_of_pair
    LDA active_tile_pair_first
    JSR copy_16_byte_graphic_to_display
    JMP finish_alternating_tile

.draw_second_tile_of_pair
    LDA active_tile_pair_second
    JSR copy_16_byte_graphic_to_display

.finish_alternating_tile
    DEX
    BNE draw_next_alternating_tile
    RTS

.load_alternate_tile_pair
    LDA alternate_tile_pair_first
    STA active_tile_pair_first
    LDA alternate_tile_pair_second
    STA active_tile_pair_second
    JMP draw_next_alternating_tile

.draw_right_edge_tile_pair_source
    LDX #&06
    JSR draw_blank_tile_run
    LDX #&02
    JMP draw_alternating_tile_run

.draw_left_edge_tile_pair_source
    LDX #&02
    JSR draw_alternating_tile_run
    LDX #&06
    JMP draw_blank_tile_run

.draw_left_edge_or_full_last_column_source
    CMP #&07
    BNE draw_left_edge_tile_pair_source
    JMP draw_eight_alternating_tiles

.draw_right_edge_or_full_last_column_source
    CMP #&07
    BNE draw_right_edge_tile_pair_source
    JMP draw_eight_alternating_tiles
.draw_alternating_tile_run_source_end

ASSERT draw_alternating_tile_run_source = draw_eight_alternating_tiles
ASSERT draw_alternating_tile_run_entry_source = draw_alternating_tile_run
ASSERT draw_right_edge_tile_pair_source = draw_right_edge_tile_pair
ASSERT draw_left_edge_tile_pair_source = draw_left_edge_tile_pair
ASSERT draw_left_edge_or_full_last_column_source = draw_left_edge_or_full_last_column
ASSERT draw_right_edge_or_full_last_column_source = draw_right_edge_or_full_last_column
ASSERT draw_alternating_tile_run_source_end = draw_fixed_pair_tile_run


ORG set_display_pointer_three_rows_below_player_cell

; Set the display pointer three Mode 1 character rows below
; the player, first aligning the player pointer down to its cell boundary.
; MODE1_THREE_ROWS_BELOW_ALIGNED_OFFSET includes three character rows plus the
; correction required after applying MODE1_CELL_ALIGNMENT_MASK, making this the
; cell-aligned variant of set_display_pointer_three_mode1_rows_below_player,
; which applies the three-row offset without aligning first.
.set_display_pointer_three_rows_below_player_cell_source
    CLC
    LDA player_display_pointer_low
    AND #MODE1_CELL_ALIGNMENT_MASK
    ADC #LO(MODE1_THREE_ROWS_BELOW_ALIGNED_OFFSET)
    STA display_pointer_low
    LDA player_display_pointer_high
    ADC #HI(MODE1_THREE_ROWS_BELOW_ALIGNED_OFFSET)
    STA display_pointer_high
    RTS
.set_display_pointer_three_rows_below_player_cell_source_end

ASSERT set_display_pointer_three_rows_below_player_cell_source = set_display_pointer_three_rows_below_player_cell
ASSERT set_display_pointer_three_rows_below_player_cell_source_end = &2C0E
COPYBLOCK set_display_pointer_three_rows_below_player_cell_source, set_display_pointer_three_rows_below_player_cell_source_end, &43FE

; Runtime $2BFE-$2C0D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $43FE-$440D.
CLEAR set_display_pointer_three_rows_below_player_cell_source, set_display_pointer_three_rows_below_player_cell_source_end


ORG draw_mirrored_diagonal_beam_tile_run

; Select the diagonal-beam graphic and its mirrored form,
; then enter the fixed-pair painter for X tiles.
.draw_mirrored_diagonal_beam_tile_run_source
    LDA #GRAPHIC_DIAGONAL_BEAM
    STA active_tile_pair_first
    LDA #GRAPHIC_RECORD_MIRROR_FLAG+GRAPHIC_DIAGONAL_BEAM
    STA active_tile_pair_second
    JMP draw_selected_fixed_pair_run


ORG pick_up_item_below_player

; Scan the known even-numbered item graphic codes
; against the cell three rows below the player. A match is placed in the first
; empty carried-item slot and its room record is marked inactive,
; then execution falls through to draw_two_item_slots. With no match, or with
; both slots occupied, return directly. Herring and mouse pickups additionally
; consume their worm or cheese prerequisite and update the moving-object state.
.pick_up_item_below_player_source
    LDA #ITEM_PICKUP_SOUND_PITCH
    STA sound_block_pitch
    JSR set_display_pointer_three_rows_below_player_cell
    LDA #ITEM_CODE_KEY_1
    STA pickup_item_code_candidate

.scan_pickup_graphics
    JSR display_pattern_test
    BCS pickup_graphic_matched
    INC pickup_item_code_candidate
    INC pickup_item_code_candidate
    LDA pickup_item_code_candidate
    CMP #ITEM_CODE_END_EXCLUSIVE
    BNE scan_pickup_graphics
    RTS

.pickup_graphic_matched
    LDA pickup_item_code_candidate
    PHA
    LDX #ITEM_CODE_CHEESE
    CMP #ITEM_CODE_MOUSE
    BEQ consume_pickup_prerequisite
    CMP #ITEM_CODE_HERRING
    BNE find_empty_item_slot
    LDX #ITEM_CODE_WORM

.consume_pickup_prerequisite
    TXA
    STA room_moving_object_puzzle_state
    JSR consume_matching_item_from_slots
    LDA current_room_cell
    BEQ find_empty_item_slot
    CMP #ROOM_MOVING_OBJECT_LIFT
    BEQ find_empty_item_slot
    LDA #&00
    STA room_moving_objects_active

.find_empty_item_slot
    PLA
    STA pickup_item_code_candidate
    LDX #ITEM_SLOT_LAST_INDEX

.test_next_item_slot_for_pickup
    LDA item_slot_first,X
    BEQ store_picked_up_item
    DEX
    BPL test_next_item_slot_for_pickup
    RTS

.store_picked_up_item
    LDA pickup_item_code_candidate
    STA item_slot_first,X
    JSR convert_item_code_to_index
    LDA #ITEM_RECORD_INACTIVE
    LDX #ITEM_GOAL_RECORD_BYTES

.invalidate_picked_up_item_record
    STA item_and_goal_record_table,Y
    INY
    DEX
    BNE invalidate_picked_up_item_record
    LDA pickup_item_code_candidate
.pick_up_item_below_player_source_end

ASSERT pick_up_item_below_player_source = pick_up_item_below_player
ASSERT pick_up_item_below_player_source_end = &2C6E
COPYBLOCK pick_up_item_below_player_source, pick_up_item_below_player_source_end, &440E

; Runtime $2C0E-$2C6D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $440E-$446D.
CLEAR pick_up_item_below_player_source, pick_up_item_below_player_source_end


ORG draw_curved_bowl_before_alternating_suffix

; room-cell type $06. Draw blank tiles up to the selected
; column, one curved-bowl tile, then alternating room tiles. This mirrors the
; prefix layout below.
.draw_curved_bowl_before_alternating_suffix_source
    LDY #GRAPHIC_CURVED_BOWL
    STY single_tile_room_graphic_selector
.draw_curved_bowl_before_alternating_suffix_body
    TAX
    LDA #ROOM_COLUMN_LAST
    SEC
    SBC room_graphics_column
    TAX
    JSR draw_blank_tile_run
    LDA single_tile_room_graphic_selector
    JSR apply_mirror_flag_then_copy_graphic
    LDX room_graphics_column
    JMP draw_alternating_tile_run


ORG draw_curved_bowl_after_alternating_prefix

; room-cell type $05. Draw alternating room tiles up to the
; selected column, one curved-bowl tile, then the remaining blank tiles.
.draw_curved_bowl_after_alternating_prefix_source
    LDY #GRAPHIC_CURVED_BOWL
    STY single_tile_room_graphic_selector
.draw_curved_bowl_after_alternating_prefix_body
    TAX
    JSR draw_alternating_tile_run
    LDA single_tile_room_graphic_selector
    JSR apply_mirror_flag_then_copy_graphic
    LDA #ROOM_COLUMN_LAST
    SEC
    SBC room_graphics_column
    TAX
    JMP draw_blank_tile_run

draw_fixed_pair_tile_run_source_end = &1437
ASSERT draw_fixed_pair_tile_run_source = draw_fixed_pair_tile_run
COPYBLOCK draw_fixed_pair_tile_run_source, draw_fixed_pair_tile_run_source_end, &2BD4
CLEAR draw_fixed_pair_tile_run_source, draw_fixed_pair_tile_run_source_end


ORG draw_two_item_slots

; Draw the two-slot item display.
; The first entry renders the accumulator-selected record from
; room_and_item_graphic_bank, then XOR-draws it at the fixed backtrack from the
; aligned item probe pointer. draw_item_slots walks the two carried-item slots
; from second to first at their fixed status-panel positions. A nonzero slot
; draws its two-record item graphic; an empty slot draws one blank row. Y is
; preserved across the whole walk. convert_item_code_to_index is the embedded
; code-to-record-index entry.
; The two slots are compared against by $213C and $342A, and the title program
; states that carried objects are shown at the top-right of the screen with a
; description. The source-owned pickup routine now proves that matching codes
; are placed in this array before this renderer is entered.
.draw_two_item_slots_source
    STA graphic_source_pointer_low
    LDA #&00
    STA graphic_source_pointer_high
    JSR set_display_pointer_three_rows_below_player_cell
    LDA display_pointer_low
    SEC
    SBC #ITEM_GRAPHIC_POINTER_BACKTRACK
    STA display_pointer_low
    LDX #ITEM_GRAPHIC_RECORD_SHIFT

.shift_index_to_record_offset
    ASL graphic_source_pointer_low
    ROL graphic_source_pointer_high
    DEX
    BNE shift_index_to_record_offset
    CLC
    LDA graphic_source_pointer_high
    ADC #HI(room_and_item_graphic_bank)
    STA graphic_source_pointer_high
    LDA #ITEM_GRAPHIC_ROW_COUNT
    STA xor_graphic_character_rows_remaining
    LDA display_pointer_low
    JSR xor_graphic_into_display
    LDA #ITEM_ACTION_SOUND_DURATION
    STA sound_block_duration
    LDA #ITEM_ACTION_SOUND_AMPLITUDE
    JSR play_sound_with_amplitude

.draw_item_slots
    TYA
    PHA
    LDA #ITEM_SLOT_SECOND_DISPLAY_LOW
    STA display_pointer_low
    LDX #ITEM_SLOT_LAST_INDEX
    STX inventory_slot_index
    LDY #ITEM_SLOT_SECOND_LABEL_CURSOR_Y

.draw_next_item_slot
    LDA item_slot_first,X
    LDX #ITEM_SLOT_LABEL_CURSOR_X
    JSR print_item_slot_label
    LDA #ITEM_SLOT_DISPLAY_HIGH
    STA display_pointer_high
    LDX inventory_slot_index
    LDA item_slot_first,X
    BEQ draw_empty_slot
    JSR enter_copy_16_byte_graphic_to_display
    TAY
    INY
    TYA
    JSR enter_copy_16_byte_graphic_to_display

.move_to_next_slot_position
    LDY #ITEM_SLOT_FIRST_LABEL_CURSOR_Y
    LDA #ITEM_SLOT_FIRST_DISPLAY_LOW
    STA display_pointer_low
    DEC inventory_slot_index
    LDX inventory_slot_index
    BPL draw_next_item_slot
    PLA
    TAY
    JMP draw_status_panel_divider

.convert_item_code_to_index
    SEC
    SBC #ITEM_CODE_KEY_1
    ASL A
    TAY
    RTS

.draw_empty_slot
    LDX #ITEM_GRAPHIC_ROW_COUNT
    JSR draw_record_row_pairs
    JMP move_to_next_slot_position
.draw_two_item_slots_source_end

ASSERT draw_two_item_slots_source = draw_two_item_slots
ASSERT draw_two_item_slots_source_end = &2CE6
COPYBLOCK draw_two_item_slots_source, draw_two_item_slots_source_end, &446E

; Runtime $2C6E-$2CE5 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $446E-$44E5.
CLEAR draw_two_item_slots_source, draw_two_item_slots_source_end


ORG drop_carried_item

; The D-control action first requires an enabled state,
; a marker found by the player-relative scan, clear placement samples three
; rows below, and a player position inside the room. It chooses the second
; occupied carried-item slot before the first, moves the player upward by
; ITEM_DROP_UPWARD_VELOCITY, clears the slot, writes the current room and resulting
; player position into that item's four-byte record, and redraws the slots.
; The cross and bottle have the additional state gates retained below.
.drop_carried_item_source
    LDA player_contact_or_damage_flag
    BNE drop_carried_item_unavailable_exit
    LDA #ITEM_DROP_SOUND_PITCH
    STA sound_block_pitch
    JSR prepare_player_relative_display_scan
    LDA display_grid_column
    BEQ drop_carried_item_unavailable_exit
    JSR sample_markers_below_player
    BCS drop_carried_item_unavailable_exit
    LDA player_vertical_position
    LSR A
    CMP #ITEM_DROP_MIN_HALF_VERTICAL_POSITION
    BMI drop_carried_item_unavailable_exit
    LDX #ITEM_SLOT_LAST_INDEX

.find_occupied_item_slot_to_drop
    LDA item_slot_first,X
    BNE prepare_carried_item_drop
    DEX
    BPL find_occupied_item_slot_to_drop
    RTS

.prepare_carried_item_drop
    STA carried_item_code_being_dropped
    TXA
    PHA
    LDA #ITEM_DROP_UPWARD_VELOCITY
    STA player_vertical_velocity
    JSR move_player_up_by_velocity
    LDA #&00
    STA player_vertical_velocity
    PLA
    TAX
    LDA display_grid_column
    BNE drop_carried_item_unavailable_exit
    LDA #&00
    STA item_slot_first,X
    LDA carried_item_code_being_dropped
    PHA
    CMP #ITEM_CODE_CROSS
    BEQ apply_dropped_item_3a_state
    CMP #ITEM_CODE_BOTTLE
    BEQ apply_dropped_item_3e_state

.write_dropped_item_record
    PLA
    PHA
    JSR convert_item_code_to_index
    LDA reference_pair_secondary_value
    STA item_and_goal_record_table,Y
    INY
    LDA reference_pair_primary_value
    STA item_and_goal_record_table,Y
    INY
    LDA player_vertical_position
    LSR A
    LSR A
    LSR A
    CLC
    ADC #ITEM_RECORD_ROW_BIAS
    STA item_and_goal_record_table,Y
    INY
    LDA player_horizontal_position
    STA item_and_goal_record_table,Y
    PLA
    JSR draw_two_item_slots
    CLC
    RTS

.apply_dropped_item_3a_state
    LDA room_interaction_code
    CMP #ROOM_CELL_CHAPEL_SIGN
    BNE write_dropped_item_record
    LDA player_vertical_position
    CMP #CROSS_DROP_REQUIRED_VERTICAL_POSITION
    BNE write_dropped_item_record
    LDA #CROSS_DROP_EFFECT_COUNTDOWN
    STA timed_effect_countdown
    LDA #CROSS_DROP_EFFECT_SELECTOR
    STA timed_effect_selector
    JMP write_dropped_item_record

.apply_dropped_item_3e_state
    LDA room_interaction_code
    CMP #ROOM_CELL_HYDROCHLORIC_ACID_SIGN
    BNE write_dropped_item_record
    LDA slow_damage_countdown
    BEQ write_dropped_item_record
    LDA #SPECIAL_ITEM_ACTIVATED
    STA special_item_3e_activation_flag
    JMP write_dropped_item_record
.drop_carried_item_source_end

ASSERT drop_carried_item_source = drop_carried_item
ASSERT drop_carried_item_source_end = &2D81
COPYBLOCK drop_carried_item_source, drop_carried_item_source_end, &44E6

; Runtime $2CE6-$2D80 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $44E6-$4580.
CLEAR drop_carried_item_source, drop_carried_item_source_end


ORG draw_column_sensitive_room_patterns

; Shared room-cell entries select complete blank or
; alternating rows, a blank gap between alternating flanks, fixed rounded/
; diagonal motifs, and curved-bowl rows according to room_graphics_column.
.draw_column_sensitive_room_patterns_source
    CMP #COLUMN_PATTERN_LEFT_END
    BPL draw_blank_or_alternating_row_by_column
    LDX #COLUMN_PATTERN_FLANK_TILES
    JSR draw_alternating_tile_run
    LDA water_environment_flag
    PHA
    STX column_pattern_flank_count_saved
    LDX #COLUMN_PATTERN_CENTRE_BLANK_TILES
    JSR draw_blank_tile_run
    PLA
    STA water_environment_flag
    LDX #COLUMN_PATTERN_FLANK_TILES
    JMP draw_alternating_tile_run

.draw_blank_or_alternating_row_by_column
    CMP #COLUMN_PATTERN_RIGHT_START
    BPL tail_draw_eight_alternating_tiles
    JMP draw_eight_blank_tiles

.tail_draw_eight_alternating_tiles
    JMP draw_eight_alternating_tiles

.draw_full_rounded_pattern_pair_row
    JMP draw_fixed_pair_tile_run

.draw_fixed_center_motif_by_column
    CMP #ROOM_COLUMN_FIRST
    BEQ draw_full_rounded_pattern_pair_row
    CMP #ROOM_COLUMN_LAST
    BEQ draw_full_rounded_pattern_pair_row
    LDX #GRAPHIC_ROUNDED_PATTERN_A
    JSR set_fixed_tile_pair
    LDX #FIXED_CENTER_BEAM_TILE_COUNT
    JSR draw_mirrored_diagonal_beam_tile_run
    LDX #GRAPHIC_ROUNDED_PATTERN_B
    JMP set_fixed_tile_pair

.draw_eight_hollow_arch_diagonal_pairs
    LDX #ROOM_CELL_TILE_COUNT

.draw_hollow_arch_diagonal_pair_run
    LDA #GRAPHIC_HOLLOW_ARCH
    STA active_tile_pair_first
    LDA #GRAPHIC_SOLID_DIAGONAL_A
    STA active_tile_pair_second
    JMP draw_selected_fixed_pair_run

.draw_alternating_or_curved_bowl_row
    CMP #ROOM_COLUMN_FIRST
    BEQ draw_eight_curved_bowl_tiles
    JMP draw_eight_alternating_tiles

.draw_eight_curved_bowl_tiles
    LDX #ROOM_CELL_TILE_COUNT

.draw_next_curved_bowl_tile
    LDA #GRAPHIC_CURVED_BOWL
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_curved_bowl_tile
    RTS


ORG draw_bordered_horizontal_bar_row
; Draw bordered bars, key-selected column motifs and the
; centred patterned-slope pair. The motif handlers save either no item, one of
; the two key codes, or COLUMN_MOTIF_OUTER_ONLY. Outer columns draw alternating
; edge pairs; middle columns frame the selected two-tile motif with blanks; the
; final column uses alternating end caps. The slope handler owns columns four
; and five and delegates all others to draw_column_sensitive_room_patterns.
.draw_bordered_horizontal_bar_row_source
    LDX #GRAPHIC_HORIZONTAL_BAR
    STX bordered_row_interior_graphic
    JMP draw_bordered_row_with_selected_interior

.draw_ff_state_column_motif_source
    LDY #COLUMN_MOTIF_OUTER_ONLY
    JMP store_column_motif_selector
.draw_first_key_column_motif_source
    LDY #ITEM_CODE_KEY_1
    JMP store_column_motif_selector
.draw_second_key_column_motif_source
    LDY #ITEM_CODE_KEY_2

.store_column_motif_selector
    STY saved_interaction_item_code
    CMP #COLUMN_MOTIF_LEFT_OUTER_END
    BPL select_column_motif_middle_or_right
.draw_outer_04_03_pair_row
    JMP draw_eight_04_03_tiles

.select_column_motif_middle_or_right
    CMP #ROOM_COLUMN_LAST
    BEQ draw_column_motif_last_column
    CMP #COLUMN_MOTIF_LEFT_OUTER_END
    BNE select_column_motif_middle_columns
    JSR save_display_pointer_and_cell_reference

.select_column_motif_middle_columns
    CMP #COLUMN_MOTIF_MIDDLE_END
    BPL draw_outer_04_03_pair_row
    LDX #COLUMN_MOTIF_SIDE_BLANK_TILES
    JSR draw_blank_tile_run
    CPY #COLUMN_MOTIF_NONE
    BEQ draw_blank_column_motif_pair
    LDA #GRAPHIC_UNIFORM_PATTERN
    JMP draw_column_motif_pair
.draw_blank_column_motif_pair
    LDA #GRAPHIC_BLANK
.draw_column_motif_pair
    JSR copy_16_byte_graphic_to_display
    JSR copy_16_byte_graphic_to_display
    LDX #COLUMN_MOTIF_SIDE_BLANK_TILES
    JMP draw_blank_tile_run

.draw_column_motif_last_column
    CPY #COLUMN_MOTIF_OUTER_ONLY
    BEQ draw_outer_04_03_pair_row
    CPY #COLUMN_MOTIF_NONE
    BEQ draw_outer_04_03_pair_row
    LDX #COLUMN_MOTIF_LAST_COLUMN_EDGE_TILES
    JSR draw_04_03_alternating_run
    LDA #GRAPHIC_BLANK
    JSR copy_16_byte_graphic_to_display
    TYA
    JSR copy_16_byte_graphic_to_display
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_BLANK
    JSR copy_16_byte_graphic_to_display
    LDX #COLUMN_MOTIF_LAST_COLUMN_EDGE_TILES
    JMP draw_04_03_alternating_run

.draw_blank_state_column_motif_source
    LDY #COLUMN_MOTIF_NONE
    JMP store_column_motif_selector

.draw_centered_slope_pair_by_column_source
    CMP #CENTERED_SLOPE_FIRST_COLUMN
    BMI draw_column_sensitive_room_patterns
    CMP #CENTERED_SLOPE_END_COLUMN
    BPL draw_column_sensitive_room_patterns
    LDX #COLUMN_MOTIF_SIDE_BLANK_TILES
    JSR draw_blank_tile_run
    LDA room_graphics_column
    CMP #CENTERED_SLOPE_FIRST_COLUMN
    BNE draw_mirrored_centered_slope_pair
    JSR save_display_pointer_and_cell_reference
    LDA #GRAPHIC_PATTERNED_SLOPE_A
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_PATTERNED_SLOPE_B
    JSR copy_16_byte_graphic_to_display
    LDX #COLUMN_MOTIF_SIDE_BLANK_TILES
    JMP draw_blank_tile_run
.draw_mirrored_centered_slope_pair
    LDA #GRAPHIC_RECORD_MIRROR_FLAG+GRAPHIC_PATTERNED_SLOPE_A
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_RECORD_MIRROR_FLAG+GRAPHIC_PATTERNED_SLOPE_B
    JSR copy_16_byte_graphic_to_display
    LDX #COLUMN_MOTIF_SIDE_BLANK_TILES
    JMP draw_blank_tile_run
.draw_bordered_horizontal_bar_row_source_end

ASSERT draw_bordered_horizontal_bar_row_source = draw_bordered_horizontal_bar_row
ASSERT draw_ff_state_column_motif_source = draw_ff_state_column_motif
ASSERT draw_first_key_column_motif_source = draw_first_key_column_motif
ASSERT draw_second_key_column_motif_source = draw_second_key_column_motif
ASSERT draw_blank_state_column_motif_source = draw_blank_state_column_motif
ASSERT draw_centered_slope_pair_by_column_source = draw_centered_slope_pair_by_column
ASSERT draw_bordered_horizontal_bar_row_source_end = save_display_pointer_and_cell_reference
COPYBLOCK draw_bordered_horizontal_bar_row_source, draw_bordered_horizontal_bar_row_source_end, &2C37
CLEAR draw_bordered_horizontal_bar_row_source, draw_bordered_horizontal_bar_row_source_end


ORG draw_table_selected_four_tile_half_row

; The four-tile-half-row cell saves its cell/display reference in column zero.
; Columns zero through three draw four blanks followed by a four-selector record
; from right_half_four_tile_graphic_sequences; the right half draws alternating
; tiles.
.draw_table_selected_four_tile_half_row_source
    CMP #ROOM_COLUMN_FIRST
    BNE select_four_tile_half_row_column_half
    JSR save_display_pointer_and_cell_reference

.select_four_tile_half_row_column_half
    CMP #ROOM_HALF_COLUMN_COUNT
    BMI draw_four_tile_half_row_table_selected_half
    JMP draw_eight_alternating_tiles

.draw_four_tile_half_row_table_selected_half
    LDX #FOUR_TILE_SEQUENCE_SELECTOR_COUNT
    JSR draw_blank_tile_run
    LDA #LO(right_half_four_tile_graphic_sequences)
    STA graphic_sequence_pointer_low
    LDA #HI(right_half_four_tile_graphic_sequences)
    STA graphic_sequence_pointer_high
    JMP draw_four_graphic_selectors_from_pointer
.draw_table_selected_four_tile_half_row_source_end

ASSERT draw_table_selected_four_tile_half_row_source = draw_table_selected_four_tile_half_row
ASSERT draw_table_selected_four_tile_half_row_source_end = &156E
COPYBLOCK draw_table_selected_four_tile_half_row_source, draw_table_selected_four_tile_half_row_source_end, &2D50

; Runtime $1550-$156D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2D50-$2D6D.
CLEAR draw_table_selected_four_tile_half_row_source, draw_table_selected_four_tile_half_row_source_end

ORG right_half_four_tile_graphic_sequences
; Four four-selector records indexed directly by room columns zero through
; three for cell type $11.
.right_half_four_tile_graphic_sequences_source
    EQUB &1F, &16, &21, &22 ; column zero
    EQUB &16, &16, &61, &23 ; column one
    EQUB &25, &1D, &25, &24 ; column two
    EQUB &25, &00, &25, &00 ; column three
.right_half_four_tile_graphic_sequences_source_end
ASSERT right_half_four_tile_graphic_sequences_source = right_half_four_tile_graphic_sequences
ASSERT right_half_four_tile_graphic_sequences_source_end = draw_graphic_selector_sequence
COPYBLOCK right_half_four_tile_graphic_sequences_source, right_half_four_tile_graphic_sequences_source_end, &2D6E
CLEAR right_half_four_tile_graphic_sequences_source, right_half_four_tile_graphic_sequences_source_end


ORG save_display_pointer_and_cell_reference

; Save the current display pointer and build the indirect
; room-cell pointer used by later writes, including the current cell offset.
; Both halves are consumed elsewhere in this source:
; replace_saved_cell_then_play_sound restores the saved display position, and
; store_byte_through_saved_pointer writes through the captured room-cell
; pointer. This is the only observed producer of either saved state.
.save_display_pointer_and_cell_reference_source
    LDA display_pointer_low
    STA saved_effect_display_pointer_low
    LDA display_pointer_high
    STA saved_effect_display_pointer_high
    LDA room_data_pointer_low
    STA indirect_write_pointer_low
    LDA room_data_pointer_high
    STA indirect_write_pointer_high
    LDA current_room_cell_offset
    STA saved_cell_write_offset
    RTS

save_display_pointer_and_cell_reference_source_end = &1550
ASSERT save_display_pointer_and_cell_reference_source = save_display_pointer_and_cell_reference
COPYBLOCK save_display_pointer_and_cell_reference_source, save_display_pointer_and_cell_reference_source_end, &2CD9
CLEAR save_display_pointer_and_cell_reference_source, save_display_pointer_and_cell_reference_source_end


ORG consume_matching_item_from_slots

; Search the two slots at $0C and $0D for the code in A,
; second slot first. A match clears that slot, redraws the slot display through
; its $2CA1 entry, calls $24D2, and returns carry set; no match returns carry
; clear leaving both slots untouched.
; This is reached from the blocked path of the movement routines: when the
; player is stopped by something, its code is looked up here, and a carry-set
; return means the obstruction was resolved by giving up a carried item. The
; title program describes doors opened by keys, duplicate keys, and a handle
; symbol matching the key shape. The source-owned pickup and drop routines now
; prove that this same array holds carried item codes.
.consume_matching_item_from_slots_source
    LDX #&01

.test_next_slot
    CMP item_slot_first,X
    BEQ clear_slot_and_redraw
    DEX
    BPL test_next_slot
    CLC
    RTS

.clear_slot_and_redraw
    LDA #&00
    STA item_slot_first,X
    JSR redraw_carried_item_slots
    JSR refill_energy_in_28_steps
    SEC
    RTS
.consume_matching_item_from_slots_source_end

ASSERT consume_matching_item_from_slots_source = consume_matching_item_from_slots
ASSERT consume_matching_item_from_slots_source_end = &2D98
COPYBLOCK consume_matching_item_from_slots_source, consume_matching_item_from_slots_source_end, &4581

; Runtime $2D81-$2D97 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4581-$4597.
CLEAR consume_matching_item_from_slots_source, consume_matching_item_from_slots_source_end


ORG draw_graphic_selector_sequence

; Multiply room_graphics_column by two Y-controlled shifts,
; then draw X consecutive graphic selectors through graphic_sequence_pointer,
; applying the mirror flag to every tile.
.draw_graphic_selector_sequence_source
    LDA room_graphics_column

.scale_graphic_sequence_index
    ASL A
    DEY
    BNE scale_graphic_sequence_index
    TAY

.draw_next_graphic_sequence_selector
    LDA (graphic_sequence_pointer_low),Y
    JSR apply_mirror_flag_then_copy_graphic
    INY
    DEX
    BNE draw_next_graphic_sequence_selector
    RTS
.draw_graphic_selector_sequence_source_end

ASSERT draw_graphic_selector_sequence_source = draw_graphic_selector_sequence
ASSERT draw_graphic_selector_sequence_source_end = &158F
COPYBLOCK draw_graphic_selector_sequence_source, draw_graphic_selector_sequence_source_end, &2D7E

; Runtime $157E-$158E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2D7E-$2D8E.
CLEAR draw_graphic_selector_sequence_source, draw_graphic_selector_sequence_source_end


ORG replace_saved_cell_with_14_then_play_sound

; Select GRAPHIC_UNIFORM_PATTERN for the redraw and save
; it as the interaction item code, then enter the shared replacement tail with
; ROOM_CELL_FF_STATE_MOTIF. Unlike the ordinary entry, this prefix skips the
; ROOM_CELL_BLANK_STATE_MOTIF setup before the common write/redraw/sound tail.
.replace_saved_cell_with_14_then_play_sound_source
    LDY #GRAPHIC_UNIFORM_PATTERN
    STY record_row_graphic_index
    STY saved_interaction_item_code
    LDA #ROOM_CELL_FF_STATE_MOTIF
    JMP write_saved_cell_and_redraw
.replace_saved_cell_with_14_then_play_sound_source_end

ASSERT replace_saved_cell_with_14_then_play_sound_source = replace_saved_cell_with_14_then_play_sound
ASSERT replace_saved_cell_with_14_then_play_sound_source_end = replace_saved_cell_then_play_sound
COPYBLOCK replace_saved_cell_with_14_then_play_sound_source, replace_saved_cell_with_14_then_play_sound_source_end, &4598

; Runtime $2D98-$2DA2 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4598-$45A2.
CLEAR replace_saved_cell_with_14_then_play_sound_source, replace_saved_cell_with_14_then_play_sound_source_end


ORG replace_saved_cell_then_play_sound

; Replace the saved room cell with
; ROOM_CELL_BLANK_STATE_MOTIF, redraw the area, and play its completion sound.
; The redraw uses the blank record, clears timed_effect_selector, and starts at
; SAVED_CELL_REDRAW_POINTER_OFFSET from the saved display position. It draws
; SAVED_CELL_REDRAW_CHARACTER_ROWS before submitting the named sound values.
.replace_saved_cell_then_play_sound_source
    LDY #GRAPHIC_RECORD_BLANK
    STY record_row_graphic_index
    LDA #ROOM_CELL_BLANK_STATE_MOTIF
.write_saved_cell_and_redraw
    JSR store_byte_through_saved_pointer
    LDA #&00 ; disable timed-effect dispatch after the cell change
    STA timed_effect_selector
    CLC
    LDA saved_effect_display_pointer_low
    ADC #SAVED_CELL_REDRAW_POINTER_OFFSET
    STA display_pointer_low
    LDA saved_effect_display_pointer_high
    ADC #&00
    STA display_pointer_high
    LDX #SAVED_CELL_REDRAW_CHARACTER_ROWS
    JSR draw_next_record_row
    LDA #SAVED_CELL_CHANGE_SOUND_DURATION
    STA sound_block_duration
    LDA #SAVED_CELL_CHANGE_SOUND_PITCH
    STA sound_block_pitch
    LDA #SAVED_CELL_CHANGE_SOUND_AMPLITUDE
    JMP play_sound_with_amplitude
.replace_saved_cell_then_play_sound_source_end

ASSERT replace_saved_cell_then_play_sound_source = replace_saved_cell_then_play_sound
ASSERT replace_saved_cell_then_play_sound_source_end = &2DD4
COPYBLOCK replace_saved_cell_then_play_sound_source, replace_saved_cell_then_play_sound_source_end, &45A3

; Runtime $2DA3-$2DD3 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $45A3-$45D3.
CLEAR replace_saved_cell_then_play_sound_source, replace_saved_cell_then_play_sound_source_end


ORG draw_repeated_87_blank_pairs_by_state

; room-cell type $09. A zero column enters the adjacent
; edge-pattern handler. Other columns draw leading blanks for removed progress
; pairs, then progress_pattern_pair_count crossed-diagonal/blank pairs.
.draw_repeated_87_blank_pairs_by_state_source
    CMP #&00
    BEQ draw_58_59_pair_or_edge_pattern_row
    LDA #PROGRESS_PATTERN_CELL_MAX_PAIRS
    SEC
    SBC progress_pattern_pair_count
    ASL A
    TAX
    JSR draw_blank_tile_run
    LDX progress_pattern_pair_count
    CPX #&00
    BEQ record_87_pair_run_finished_exit

.draw_next_87_blank_pair
    LDA #GRAPHIC_RECORD_XOR_FLAG+GRAPHIC_CROSSED_DIAGONAL
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_BLANK
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_87_blank_pair
    RTS
.draw_repeated_87_blank_pairs_by_state_source_end

ASSERT draw_repeated_87_blank_pairs_by_state_source = draw_repeated_87_blank_pairs_by_state
ASSERT draw_repeated_87_blank_pairs_by_state_source_end = &15B1
COPYBLOCK draw_repeated_87_blank_pairs_by_state_source, draw_repeated_87_blank_pairs_by_state_source_end, &2D8F

; Runtime $158F-$15B0 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2D8F-$2DB0.
CLEAR draw_repeated_87_blank_pairs_by_state_source, draw_repeated_87_blank_pairs_by_state_source_end


ORG initialise_cross_room_robot_ghost_from_record

; Initialise the two cross-room robots or ghosts from the packed record for the current level.
; reference_pair_secondary_value selects one CROSS_ROOM_ROBOT_GHOST_RECORD_BYTES
; record from cross_room_robot_ghost_record_table. The first byte carries two fields:
; its low three bits become the primary field, and the byte shifted right and
; masked to $FC becomes the value field. The second byte is unpacked the same
; way into the negative-delta selector and threshold. The third byte, masked to
; six bits, is multiplied by eight and biased down by eight to become the offset
; field.
; Almost every unpacked value is written to both interleaved field sets. That is
; what makes this a pair: one record initialises two parallel entities, which
; update_and_draw_two_cross_room_robot_ghosts then advances together. The deltas are
; preset to opposite signed horizontal steps and all countdown/state bytes are
; initialised before the record is read.
; The display pointer copied into both field sets is whatever the
; display_action_jump_table call leaves behind, so the record selects the
; position indirectly rather than carrying it.
;
; This robot/ghost class is per level, not per room: the record index is the secondary
; reference times the record width, so there is one record per level, and each
; initialises two objects. advance_cross_room_robot_ghost_value_and_display_pointer then
; carries them across room boundaries and reverses them at the outer room
; columns. Levels before CROSS_ROOM_GHOST_FIRST_LEVEL use the small bouncing
; robot frames; the final two levels use the ghost frames. The pair is therefore
; two cross-room robots or ghosts, not a platform class.
.initialise_cross_room_robot_ghost_from_record_source
    LDA reference_pair_secondary_value
    ASL A
    ADC reference_pair_secondary_value
    TAY
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_POSITIVE
    STA cross_room_robot_ghost_value_delta_field
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_NEGATIVE
    STA cross_room_robot_ghost_secondary_delta_slot_1
    LDA #CROSS_ROOM_ROBOT_GHOST_INITIAL_COUNTDOWN
    LDX #CROSS_ROOM_ROBOT_GHOST_COUNTDOWN_LAST_INDEX

.preset_pair_flags
    STA cross_room_robot_ghost_redraw_countdown,X
    DEX
    BPL preset_pair_flags
    LDA cross_room_robot_ghost_record_table,Y
    AND #CROSS_ROOM_ROBOT_GHOST_SELECTOR_MASK
    STA cross_room_robot_ghost_positive_delta_selector
    STA cross_room_robot_ghost_primary_field
    LDA cross_room_robot_ghost_record_table,Y
    LSR A
    AND #CROSS_ROOM_ROBOT_GHOST_THRESHOLD_OFFSET_MASK
    STA cross_room_robot_ghost_positive_delta_threshold
    STA cross_room_robot_ghost_value_field
    STA cross_room_robot_ghost_runtime_value_slot_0
    STA display_grid_column
    INY
    LDA cross_room_robot_ghost_record_table,Y
    AND #CROSS_ROOM_ROBOT_GHOST_SELECTOR_MASK
    STA cross_room_robot_ghost_negative_delta_selector
    STA cross_room_robot_ghost_secondary_delta_slot_0
    LDA cross_room_robot_ghost_record_table,Y
    LSR A
    AND #CROSS_ROOM_ROBOT_GHOST_THRESHOLD_OFFSET_MASK
    STA cross_room_robot_ghost_negative_delta_threshold
    INY
    LDA cross_room_robot_ghost_record_table,Y
    AND #CROSS_ROOM_ROBOT_GHOST_POSITION_MASK
    STA display_grid_row
    ASL A
    ASL A
    ASL A
    SEC
    SBC #CROSS_ROOM_ROBOT_GHOST_VERTICAL_OFFSET_BIAS
    STA cross_room_robot_ghost_offset_field
    STA cross_room_robot_ghost_runtime_value_slot_1
    JSR display_action_jump_table
    LDA display_pointer_low
    STA cross_room_robot_ghost_display_pointer_low
    STA cross_room_robot_ghost_second_display_pointer_low
    LDA display_pointer_high
    STA cross_room_robot_ghost_display_pointer_high
    STA cross_room_robot_ghost_second_display_pointer_high
    LDA reference_pair_secondary_value
    STA cross_room_robot_ghost_secondary_field
    STA cross_room_robot_ghost_second_secondary_field
    RTS
.initialise_cross_room_robot_ghost_from_record_source_end

ASSERT initialise_cross_room_robot_ghost_from_record_source = initialise_cross_room_robot_ghost_from_record
ASSERT initialise_cross_room_robot_ghost_from_record_source_end = &2E44
COPYBLOCK initialise_cross_room_robot_ghost_from_record_source, initialise_cross_room_robot_ghost_from_record_source_end, &45D4

; Runtime $2DD4-$2E43 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $45D4-$4643.
CLEAR initialise_cross_room_robot_ghost_from_record_source, initialise_cross_room_robot_ghost_from_record_source_end


ORG draw_narrow_bar_fixture_row

; room-cell type $15. Column zero draws four selector-$15/blank pairs; columns one through three draw repeated $13/$07 pairs; column seven draws selector $14 then seven blanks; middle-right columns combine the repeated pair, selector $14/blank and a computed blank suffix.
.draw_narrow_bar_fixture_row_source
    CMP #&00
    BNE select_narrow_bar_column_group
    LDX #&04

.draw_next_15_blank_pair
    LDA #GRAPHIC_COLUMN_JUNCTION
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_BLANK
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_15_blank_pair

.return_from_narrow_bar_fixture
    RTS

.select_narrow_bar_column_group
    CMP #COLLECTED_ICON_EFFECT_RESERVED_COUNT
    BPL select_narrow_bar_right_edge
    LDX #&04
    JMP draw_next_13_07_pair

.select_narrow_bar_right_edge
    CMP #&07
    BNE draw_narrow_bar_middle_right_column
    LDA #GRAPHIC_WIDE_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    LDX #&07
    JMP draw_blank_tile_run

.draw_narrow_bar_middle_right_column
    SEC
    LDA #&07
    SBC room_graphics_column
    TAX
    JSR draw_next_13_07_pair
    LDA #GRAPHIC_WIDE_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_BLANK
    JSR copy_16_byte_graphic_to_display
    LDA room_graphics_column
    CMP #&04
    BEQ return_from_narrow_bar_fixture
    SEC
    SBC #&04
    ASL A
    TAX
    JMP draw_blank_tile_run

.draw_next_13_07_pair
    LDA #GRAPHIC_NARROW_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    LDA #GRAPHIC_CROSSED_DIAGONAL
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_13_07_pair
    RTS
.draw_narrow_bar_fixture_row_source_end

ASSERT draw_narrow_bar_fixture_row_source = draw_narrow_bar_fixture_row
ASSERT draw_narrow_bar_fixture_row_source_end = &1639
COPYBLOCK draw_narrow_bar_fixture_row_source, draw_narrow_bar_fixture_row_source_end, &2DDF

; Runtime $15DF-$1638 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2DDF-$2E38.
CLEAR draw_narrow_bar_fixture_row_source, draw_narrow_bar_fixture_row_source_end


ORG draw_record_08_or_edge_pattern_row

; Runtime $15B1-$15DE contains room-cell entries $12, $13 and their shared tails. Cell $12 draws its record-$08 row in column six, alternates in column seven and blanks elsewhere. Cell $13 selects blanks, alternating tiles, or the $58/$59 pair according to column.
.draw_record_08_or_edge_pattern_row_source
    CMP #&06
    BNE select_cell_12_last_column
    JMP draw_eight_curved_bowl_tiles

.select_cell_12_last_column
    CMP #&07
    BEQ draw_alternating_row_from_cell_12_13

.draw_blank_row_from_cell_12_13
    JMP draw_eight_blank_tiles

.draw_column_gated_58_59_pair_row_source
    CMP #&02
    BMI draw_58_59_pair_or_edge_pattern_row
    JSR mirror_cell_direction

.draw_58_59_pair_or_edge_pattern_row_source
    LDX #&08
    CMP #&02
    BPL draw_blank_row_from_cell_12_13
    CMP #&01
    BNE draw_alternating_row_from_cell_12_13
    LDY #&58
    STY active_tile_pair_first
    INY
    STY active_tile_pair_second
    JMP draw_selected_fixed_pair_run

.draw_alternating_row_from_cell_12_13
    JMP draw_eight_alternating_tiles
.draw_record_08_or_edge_pattern_row_source_end

ASSERT draw_record_08_or_edge_pattern_row_source = draw_record_08_or_edge_pattern_row
ASSERT draw_column_gated_58_59_pair_row_source = draw_column_gated_58_59_pair_row
ASSERT draw_58_59_pair_or_edge_pattern_row_source = draw_58_59_pair_or_edge_pattern_row
ASSERT draw_record_08_or_edge_pattern_row_source_end = &15DF
COPYBLOCK draw_record_08_or_edge_pattern_row_source, draw_record_08_or_edge_pattern_row_source_end, &2DB1

; Runtime $15B1-$15DE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2DB1-$2DDE.
CLEAR draw_record_08_or_edge_pattern_row_source, draw_record_08_or_edge_pattern_row_source_end


ORG update_and_draw_two_cross_room_robot_ghosts

; Process the two cross-room robot/ghost states. Robot levels use
; this loop; ghost levels tail-transfer to ghost_countdown_steering_update.
; Each robot iteration selects
; repeated-source drawing, optionally erases the current graphic and advances
; a countdown, conditionally updates pair state, then draws the resulting
; graphic. The final CLC/RTS is shared with the adjacent matching handler.
.update_and_draw_two_cross_room_robot_ghosts_source
    LDX #CROSS_ROOM_ROBOT_GHOST_PAIR_FIRST_INDEX
.cross_room_robot_ghost_update_loop
    LDA reference_pair_secondary_value
    CMP #CROSS_ROOM_GHOST_FIRST_LEVEL
    BMI process_cross_room_robot_ghost_update
    JMP ghost_countdown_steering_update

.process_cross_room_robot_ghost_update
    LDA #XOR_GRAPHIC_REPEAT_ENABLED
    STA xor_graphic_repeat_source_scanlines
    LDA erase_previous_xor_sprite_flag
    BEQ update_cross_room_robot_ghost_state
    JSR draw_cross_room_robot_ghost_if_reference_matches
    DEC cross_room_robot_ghost_redraw_countdown,X
    BNE draw_updated_cross_room_robot_ghost
    LDA #CROSS_ROOM_ROBOT_GHOST_INITIAL_COUNTDOWN
    STA cross_room_robot_ghost_redraw_countdown,X

.update_cross_room_robot_ghost_state
    JSR set_cross_room_robot_ghost_value_delta_at_thresholds
    JSR handle_matching_cross_room_robot_ghost
    BCS draw_updated_cross_room_robot_ghost
    JSR advance_cross_room_robot_ghost_value_and_display_pointer

.draw_updated_cross_room_robot_ghost
    JSR draw_cross_room_robot_ghost_if_reference_matches
    INX
    INX
    CPX #CROSS_ROOM_ROBOT_GHOST_PAIR_END_INDEX
    BNE cross_room_robot_ghost_update_loop
    LDA #&00
    STA xor_graphic_repeat_source_scanlines
    CLC
    RTS
.update_and_draw_two_cross_room_robot_ghosts_source_end

ASSERT update_and_draw_two_cross_room_robot_ghosts_source = update_and_draw_two_cross_room_robot_ghosts
ASSERT update_and_draw_two_cross_room_robot_ghosts_source_end = handle_matching_cross_room_robot_ghost
COPYBLOCK update_and_draw_two_cross_room_robot_ghosts_source, update_and_draw_two_cross_room_robot_ghosts_source_end, &4644

; Release the runtime range after copying it into the loaded transport image.
CLEAR update_and_draw_two_cross_room_robot_ghosts_source, update_and_draw_two_cross_room_robot_ghosts_source_end

ORG draw_last_column_special_pair_row

; room-cell type $16. Columns zero through six reuse the cell-$13 edge-pattern row. Column seven draws that row, sets the dynamic-object VDU vertical step to two, changes the active selector to $84, then enters the dynamic-object VDU setup at $19F7.
.draw_last_column_special_pair_row_source
    CMP #&07
    BEQ draw_last_column_pair_before_special_setup
    JMP draw_58_59_pair_or_edge_pattern_row

.draw_last_column_pair_before_special_setup
    JSR draw_58_59_pair_or_edge_pattern_row
    LDA #CROSS_ROOM_ROBOT_CHARACTER_ROWS
    STA dynamic_object_vdu_vertical_step_high
    LDA #&84
    STA active_tile_pair_first
    JMP prepare_dynamic_object_vdu_stream
.draw_last_column_special_pair_row_source_end

ASSERT draw_last_column_special_pair_row_source = draw_last_column_special_pair_row
ASSERT draw_last_column_special_pair_row_source_end = &1650
COPYBLOCK draw_last_column_special_pair_row_source, draw_last_column_special_pair_row_source_end, &2E39

; Runtime $1639-$164F overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2E39-$2E4F.
CLEAR draw_last_column_special_pair_row_source, draw_last_column_special_pair_row_source_end

ORG draw_state_selected_13_center_row
; room-cell type $17. The first and final room graphics Y coordinates draw
; alternating tiles. Other values draw two blanks, selector $13, the two-tile
; $04/$03 centre run at $1531, another $13 and two trailing blanks. Only the
; alternating outcome is present in committed traces; the dispatch entry and
; static flow establish the alternate layout without assigning gameplay lore.
.draw_state_selected_13_center_row_source
    LDX room_graphics_y_low
    CPX #ROOM_GRAPHICS_Y_FINAL_ROW
    BEQ draw_cell_17_alternating_row
    CPX #ROOM_GRAPHICS_Y_BEFORE_FIRST_ROW
    BNE draw_cell_17_framed_center
.draw_cell_17_alternating_row
    JMP draw_eight_alternating_tiles
.draw_cell_17_framed_center
    LDX #&02
    JSR draw_blank_tile_run
    LDA #GRAPHIC_NARROW_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    LDX #&02
    JSR draw_04_03_alternating_run
    LDA #GRAPHIC_NARROW_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    LDX #&02
    JMP draw_blank_tile_run
.draw_state_selected_13_center_row_source_end
ASSERT draw_state_selected_13_center_row_source = draw_state_selected_13_center_row
ASSERT draw_state_selected_13_center_row_source_end = draw_room_flag_then_fixed_pair_row
COPYBLOCK draw_state_selected_13_center_row_source, draw_state_selected_13_center_row_source_end, &2E50
CLEAR draw_state_selected_13_center_row_source, draw_state_selected_13_center_row_source_end


ORG handle_matching_cross_room_robot_ghost

; A failed pair comparison returns carry clear through
; the shared exit at $2E7A. A match copies one indexed field to $11, transforms
; the adjacent field into $3C, and tail-transfers to the sourced $2B57 guard.
.handle_matching_cross_room_robot_ghost_source
    JSR test_cross_room_robot_ghost_matches_reference
    BCC cross_room_robot_ghost_mismatch_return
    LDA cross_room_robot_ghost_value_field,X
    STA candidate_horizontal_position
    LDA cross_room_robot_ghost_offset_field,X
    CLC
    ADC #&08
    LSR A
    STA candidate_half_vertical_position
    JMP check_player_candidate_bounds_overlap
.handle_matching_cross_room_robot_ghost_source_end

ASSERT handle_matching_cross_room_robot_ghost_source = handle_matching_cross_room_robot_ghost
ASSERT handle_matching_cross_room_robot_ghost_source_end = &2E92
COPYBLOCK handle_matching_cross_room_robot_ghost_source, handle_matching_cross_room_robot_ghost_source_end, &467C

; Runtime $2E7C-$2E91 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $467C-$4691.
CLEAR handle_matching_cross_room_robot_ghost_source, handle_matching_cross_room_robot_ghost_source_end

ORG draw_room_flag_then_fixed_pair_row

; room-cell type $1A. Column zero enables the room-local jet-boots flag. Every column preserves its number on the stack, draws four repetitions of the active tile pair, then enters the dynamic-room-object VDU continuation.
.draw_room_flag_then_fixed_pair_row_source
    CMP #&00
    BNE draw_fixed_pair_then_configure_object
    LDA #&01
    STA jet_boots_enabled_this_room

.draw_fixed_pair_then_configure_object
    PHA
    JSR draw_fixed_pair_tile_run
    JMP configure_and_emit_dynamic_room_object_vdu_stream
.draw_room_flag_then_fixed_pair_row_source_end

ASSERT draw_room_flag_then_fixed_pair_row_source = draw_room_flag_then_fixed_pair_row
ASSERT draw_room_flag_then_fixed_pair_row_source_end = &1685
COPYBLOCK draw_room_flag_then_fixed_pair_row_source, draw_room_flag_then_fixed_pair_row_source_end, &2E76

; Runtime $1676-$1684 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2E76-$2E84.
CLEAR draw_room_flag_then_fixed_pair_row_source, draw_room_flag_then_fixed_pair_row_source_end


ORG draw_directional_ghost_if_reference_matches

; Preserve the ghost selector twice for the shared
; drawing tail, choose ghost graphic-pointer offset $14 for a non-negative
; value delta or $16 for a negative one, and configure three character rows before entering the
; common predicate-and-XOR path at $2EBC. The alternate updater at $3009 calls
; this before and after changing each active pair, forming an erase/redraw pair.
; $2EA7-$2EA9 is the shared mismatch exit: one saved selector is restored there
; both for this entry and for draw_cross_room_robot_ghost_if_reference_matches.
.draw_directional_ghost_if_reference_matches_source
    TXA
    PHA
    PHA
    LDA cross_room_robot_ghost_value_delta_field,X
    LDX #CROSS_ROOM_GHOST_FRAME_0_OFFSET
    CMP #&00
    BPL directional_ghost_selector_ready
    LDX #CROSS_ROOM_GHOST_FRAME_3_OFFSET

.directional_ghost_selector_ready
    STX cross_room_robot_ghost_graphic_pointer_offset
    LDA #CROSS_ROOM_GHOST_CHARACTER_ROWS
    JMP configure_cross_room_robot_ghost_draw_rows

ASSERT P% = restore_cross_room_robot_ghost_x_and_return
    PLA
    TAX
    RTS
.draw_directional_ghost_if_reference_matches_source_end

ASSERT draw_directional_ghost_if_reference_matches_source = draw_directional_ghost_if_reference_matches
ASSERT draw_directional_ghost_if_reference_matches_source_end = draw_cross_room_robot_ghost_if_reference_matches
COPYBLOCK draw_directional_ghost_if_reference_matches_source, draw_directional_ghost_if_reference_matches_source_end, &4692

; Runtime $2E92-$2EA9 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4692-$46A9.
CLEAR draw_directional_ghost_if_reference_matches_source, draw_directional_ghost_if_reference_matches_source_end

ORG draw_cross_room_robot_ghost_if_reference_matches

; Select small-bouncing-robot graphic-pointer offset
; $10/$12 from bit 1 of the indexed value, configure two renderer rows, and draw only when the indexed
; pair matches the reference fields. A mismatch branches to the original
; shared PLA/TAX/RTS exit at $2EA7. The $74-controlled state clear is retained
; exactly, although committed traces exercise only $74 = 0.
.draw_cross_room_robot_ghost_if_reference_matches_source
    LDA cross_room_robot_ghost_value_field,X
    LSR A
    LSR A
    TXA
    PHA
    PHA
    LDX #CROSS_ROOM_ROBOT_FRAME_0_OFFSET
    BCC cross_room_robot_ghost_draw_selector_ready
    LDX #CROSS_ROOM_ROBOT_FRAME_1_OFFSET

.cross_room_robot_ghost_draw_selector_ready
    STX cross_room_robot_ghost_graphic_pointer_offset
    LDA #CROSS_ROOM_ROBOT_CHARACTER_ROWS

.configure_cross_room_robot_ghost_draw_rows
    STA xor_graphic_character_rows_remaining
    PLA
    TAX
    JSR test_cross_room_robot_ghost_matches_reference
    BCC restore_cross_room_robot_ghost_x_and_return

    LDA cross_room_robot_ghost_display_pointer_high,X
    STA display_pointer_high
    LDA cross_room_robot_ghost_display_pointer_low,X
    PHA
    LDA reset_cross_room_robot_ghost_countdowns
    BEQ cross_room_robot_ghost_draw_state_ready
    LDA #&00
    STA cross_room_robot_ghost_redraw_countdown,X

.cross_room_robot_ghost_draw_state_ready
    PLA
    LDX cross_room_robot_ghost_graphic_pointer_offset
    JSR select_graphic_then_xor_draw
    PLA
    TAX
    RTS
.draw_cross_room_robot_ghost_if_reference_matches_source_end

ASSERT draw_cross_room_robot_ghost_if_reference_matches_source = draw_cross_room_robot_ghost_if_reference_matches
ASSERT draw_cross_room_robot_ghost_if_reference_matches_source_end = test_cross_room_robot_ghost_matches_reference
COPYBLOCK draw_cross_room_robot_ghost_if_reference_matches_source, draw_cross_room_robot_ghost_if_reference_matches_source_end, &46AA

; Runtime $2EAA-$2EDC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $46AA-$46DC.
CLEAR draw_cross_room_robot_ghost_if_reference_matches_source, draw_cross_room_robot_ghost_if_reference_matches_source_end

ORG draw_two_13_two_beam_two_13_two_pattern

; room-cell type $1C. Draw two selector-$13 tiles, two mirrored diagonal-beam tiles, another two selector-$13 tiles, then two alternating tiles. The internal $16D2 entry draws exactly two selector-$13 tiles.
.draw_two_13_two_beam_two_13_two_pattern_source
    JSR draw_two_13_tiles
    LDX #&02
    JSR draw_mirrored_diagonal_beam_tile_run
    JSR draw_two_13_tiles
    LDX #&02
    JMP draw_alternating_tile_run

.draw_two_13_tiles
    LDX #&02

.draw_next_13_tile
    LDA #GRAPHIC_NARROW_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_13_tile
    RTS
.draw_two_13_two_beam_two_13_two_pattern_source_end

ASSERT draw_two_13_two_beam_two_13_two_pattern_source = draw_two_13_two_beam_two_13_two_pattern
ASSERT draw_two_13_two_beam_two_13_two_pattern_source_end = &16DD
; The adjacent cell-$1D entry is assembled next; both are copied together
; after the cross-room robot/ghost routines that occupy their loaded destination.

ORG draw_left_half_sequence_twice_or_13_beam_pattern
; room-cell type $1D. Columns zero through three draw
; their four-selector record from left_half_four_tile_graphic_sequences twice.
; Columns four through seven reuse the cell-$1C selector-$13/beam pattern.
; This entry has not appeared in committed traces; its dispatch-table target
; and direct shared-tail structure establish the dataflow contract.
.draw_left_half_sequence_twice_or_13_beam_pattern_source
    CMP #&04
    BPL draw_cell_1d_right_half_pattern
    JSR load_left_half_graphic_sequence_pointer
    JMP load_left_half_graphic_sequence_pointer
.draw_cell_1d_right_half_pattern
    JMP draw_two_13_two_beam_two_13_two_pattern
.draw_left_half_sequence_twice_or_13_beam_pattern_source_end
ASSERT draw_left_half_sequence_twice_or_13_beam_pattern_source = draw_left_half_sequence_twice_or_13_beam_pattern
ASSERT draw_left_half_sequence_twice_or_13_beam_pattern_source_end = draw_room_sign_or_collect_password

ORG advance_cross_room_robot_ghost_offset_and_display_pointer

; Move a cross-room ghost vertically by signed step +2/-2.
; Ordinary steps are delegated through apply_signed_vertical_step_to_pointer.
; At offset $10 while moving upward, decrement secondary row and wrap to $C0;
; at $C0 while moving downward, increment the row and wrap to $10. The display
; pointer high byte follows either wrap by +/-$37. Rows 8 and 9 are endpoints:
; reaching them reverses the delta instead of crossing the boundary.
.advance_cross_room_robot_ghost_offset_and_display_pointer_source
    LDA cross_room_robot_ghost_offset_delta_field,X
    CMP #CROSS_ROOM_GHOST_VERTICAL_STEP_DOWN
    BNE cross_room_robot_ghost_test_upper_offset
    LDA cross_room_robot_ghost_offset_field,X
    CMP #CROSS_ROOM_GHOST_BOTTOM_OFFSET
    BNE move_cross_room_robot_ghost_vertical_step
    JMP wrap_cross_room_robot_ghost_to_lower_offset

.cross_room_robot_ghost_test_upper_offset
    LDA cross_room_robot_ghost_offset_field,X
    CMP #CROSS_ROOM_GHOST_TOP_OFFSET
    BNE move_cross_room_robot_ghost_vertical_step
    JMP wrap_cross_room_robot_ghost_to_upper_offset

.move_cross_room_robot_ghost_vertical_step
    LDA cross_room_robot_ghost_offset_field,X
    STA candidate_half_vertical_position
    LDA cross_room_robot_ghost_offset_delta_field,X
    STA vertical_step_delta
    LDA cross_room_robot_ghost_display_pointer_low,X
    STA vertical_step_pointer_low
    LDA cross_room_robot_ghost_display_pointer_high,X
    STA vertical_step_pointer_high
    JSR apply_signed_vertical_step_to_pointer
    LDA candidate_half_vertical_position
    STA cross_room_robot_ghost_offset_field,X
    LDA vertical_step_pointer_low
    STA cross_room_robot_ghost_display_pointer_low,X
    LDA vertical_step_pointer_high
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.wrap_cross_room_robot_ghost_to_upper_offset
    LDA cross_room_robot_ghost_secondary_field,X
    CMP #CROSS_ROOM_GHOST_TOP_LEVEL
    BEQ reverse_cross_room_robot_ghost_offset_downward
    DEC cross_room_robot_ghost_secondary_field,X
    LDA #CROSS_ROOM_GHOST_BOTTOM_OFFSET
    STA cross_room_robot_ghost_offset_field,X
    CLC
    LDA cross_room_robot_ghost_display_pointer_high,X
    ADC #CROSS_ROOM_GHOST_LEVEL_WRAP_PAGE_DELTA
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.reverse_cross_room_robot_ghost_offset_downward
    LDA #CROSS_ROOM_GHOST_VERTICAL_STEP_DOWN
    STA cross_room_robot_ghost_offset_delta_field,X
    RTS

.wrap_cross_room_robot_ghost_to_lower_offset
    LDA cross_room_robot_ghost_secondary_field,X
    CMP #CROSS_ROOM_GHOST_BOTTOM_LEVEL
    BEQ reverse_cross_room_robot_ghost_offset_upward
    INC cross_room_robot_ghost_secondary_field,X
    LDA #CROSS_ROOM_GHOST_TOP_OFFSET
    STA cross_room_robot_ghost_offset_field,X
    SEC
    LDA cross_room_robot_ghost_display_pointer_high,X
    SBC #CROSS_ROOM_GHOST_LEVEL_WRAP_PAGE_DELTA
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.reverse_cross_room_robot_ghost_offset_upward
    LDA #CROSS_ROOM_GHOST_VERTICAL_STEP_UP
    STA cross_room_robot_ghost_offset_delta_field,X
    RTS

; Alternate entry used when countdown is zero or two: XOR-draw/erase the pair,
; then enter the adjacent countdown routine at its decrement instruction.
.draw_then_decrement_ghost_source
    JSR draw_directional_ghost_if_reference_matches
    JMP decrement_ghost_countdown
.advance_cross_room_robot_ghost_offset_and_display_pointer_source_end

ASSERT advance_cross_room_robot_ghost_offset_and_display_pointer_source = advance_cross_room_robot_ghost_offset_and_display_pointer
ASSERT draw_then_decrement_ghost_source = draw_then_decrement_ghost
ASSERT advance_cross_room_robot_ghost_offset_and_display_pointer_source_end = ghost_countdown_steering_update
COPYBLOCK advance_cross_room_robot_ghost_offset_and_display_pointer_source, advance_cross_room_robot_ghost_offset_and_display_pointer_source_end, &478F
CLEAR advance_cross_room_robot_ghost_offset_and_display_pointer_source, advance_cross_room_robot_ghost_offset_and_display_pointer_source_end


ORG draw_room_sign_or_collect_password
; Shared by the named room-sign cell types. Columns two onward
; draw blanks. The first two columns patch the Level/Sector sign, position and
; colour the VDU cursor, then print the selected 16-byte room sign as two
; eight-character halves. A zero in the PASSWORD prompt instead maps the room
; column to a password number, marks it collected, and prints '=' plus the
; corresponding five-letter overlapping password. The Oracle sign changes to
; the PASSWORD prompt only while the eye is carried. The inline byte sequences
; below are source VDU/string data, not 6502 instructions.
.draw_room_sign_or_collect_password_source
    CMP #ROOM_SIGN_DRAW_COLUMN_COUNT
    BMI prepare_room_sign_text
    JMP draw_eight_blank_tiles

.prepare_room_sign_text
    LDA reference_pair_secondary_value
    CLC
    ADC #ASCII_DIGIT_ZERO
    STA level_sign_level_digit
    LDA reference_pair_primary_value
    ADC #ASCII_UPPERCASE_A
    STA level_sign_sector_letter
    CLC
    LDA display_pointer_low
    ADC #ROOM_SIGN_DISPLAY_ROW_STRIDE_LOW
    STA display_pointer_low
    LDA display_pointer_high
    ADC #&00
    STA display_pointer_high
    JSR print_inline_vdu_stream
.room_sign_cursor_prefix
    EQUB VDU_TEXT_COLOUR, ROOM_SIGN_FIRST_LINE_FOREGROUND
    EQUB VDU_TEXT_COLOUR, ROOM_SIGN_FIRST_LINE_BACKGROUND, VDU_TEXT_AT, ROOM_COLUMN_FIRST
.room_sign_cursor_prefix_end

    LDA room_graphics_x_high
    ASL A
    ASL A
    ASL A
    JSR OSWRCH
    LDA room_graphics_y_low
    SEC
    SBC #ROOM_SIGN_TEXT_ROW_ADJUSTMENT
    JSR OSWRCH
    LDA room_graphics_column
    ASL A
    ASL A
    ASL A
    STA inline_vdu_stream_pointer_low
    LDA current_room_cell
    CMP #ROOM_CELL_JOKE_SHOP_SIGN
    BNE test_password_prompt_cell
    STA horizontal_band_velocity_effect_state

.test_password_prompt_cell
    CMP #ROOM_CELL_ORACLE_SIGN
    BNE select_room_sign_record
    LDA #ITEM_CODE_EYE
    JSR test_item_code_matches_either_slot
    LDA #ROOM_CELL_ORACLE_SIGN
    BCC select_room_sign_record
    LDA #ROOM_CELL_PASSWORD_PROMPT

.select_room_sign_record
    STA room_interaction_code
    SEC
    SBC #ROOM_CELL_MUSIC_ROOM_SIGN
    ; Multiply the zero-based sign number by ROOM_SIGN_TEXT_RECORD_LENGTH.
    ASL A
    ASL A
    ASL A
    ASL A
    ADC inline_vdu_stream_pointer_low
    TAY
    LDX #ROOM_COLUMN_FIRST

.print_next_room_sign_character
    LDA room_sign_text_table,Y
    BEQ collect_room_password
    JSR OSWRCH
    INY
    INX
    CPX #ROOM_SIGN_LINE_CHARACTER_COUNT
    BNE print_next_room_sign_character

.finish_room_sign_line
    JSR print_inline_vdu_stream
.room_sign_second_line_cursor
    EQUB VDU_TEXT_COLOUR, ROOM_SIGN_SECOND_LINE_FOREGROUND
    EQUB VDU_TEXT_COLOUR, ROOM_SIGN_SECOND_LINE_BACKGROUND, INLINE_VDU_STREAM_END
.room_sign_second_line_cursor_end
    RTS

.collect_room_password
    LDX reference_pair_primary_value
    LDA across_to_password_number,X
    TAX
    CLC
    ADC #PASSWORD_NUMBER_CHARACTER_BIAS
    JSR OSWRCH
    LDA #PASSWORD_COLLECTED
    STA collected_password_flags,X
    TXA
    STA inline_vdu_stream_pointer_low
    ASL A
    CLC
    ADC inline_vdu_stream_pointer_low
    TAX
    JSR print_inline_vdu_stream
.password_equals_inline_text
    EQUS "="
    EQUB &00
.password_equals_inline_text_end
    LDY #PASSWORD_CHARACTER_COUNT

.print_next_password_letter
    LDA password_letters,X
    JSR OSWRCH
    INX
    DEY
    BNE print_next_password_letter
    JMP finish_room_sign_line
.draw_room_sign_or_collect_password_source_end

ASSERT draw_room_sign_or_collect_password_source = draw_room_sign_or_collect_password
ASSERT room_sign_cursor_prefix = &1710
ASSERT room_sign_cursor_prefix_end = &1716
ASSERT room_sign_second_line_cursor = &1764
ASSERT room_sign_second_line_cursor_end = &1769
ASSERT password_equals_inline_text = &1785
ASSERT password_equals_inline_text_end = &1787
ASSERT draw_room_sign_or_collect_password_source_end = password_letters


ORG draw_table_selected_left_half_row

; The left-half-sequence cell draws four blanks then one four-selector record in
; columns zero through three. Columns four through seven select the same records
; by their position within the right half, then append two narrow bars and two
; alternating tiles.
.draw_table_selected_left_half_row_source
    CMP #ROOM_HALF_COLUMN_COUNT
    BPL draw_left_half_sequence_right_half_layout
    LDX #FOUR_TILE_SEQUENCE_SELECTOR_COUNT
    JSR draw_blank_tile_run

.load_left_half_graphic_sequence_pointer
    LDA #LO(left_half_four_tile_graphic_sequences)
    STA graphic_sequence_pointer_low
    LDA #HI(left_half_four_tile_graphic_sequences)
    STA graphic_sequence_pointer_high
    LDX #FOUR_TILE_SEQUENCE_SELECTOR_COUNT
    LDY #FOUR_TILE_SEQUENCE_INDEX_SHIFTS
    JMP draw_graphic_selector_sequence

.draw_left_half_sequence_right_half_layout
    SEC
    SBC #ROOM_HALF_COLUMN_COUNT
    STA room_graphics_column
    JSR load_left_half_graphic_sequence_pointer
    LDA #GRAPHIC_NARROW_VERTICAL_BAR
    JSR copy_16_byte_graphic_to_display
    JSR copy_16_byte_graphic_to_display
    LDX #TWO_TILE_ALTERNATING_SUFFIX_COUNT
    JMP draw_alternating_tile_run
.draw_table_selected_left_half_row_source_end

ASSERT draw_table_selected_left_half_row_source = draw_table_selected_left_half_row
ASSERT draw_table_selected_left_half_row_source_end = left_half_four_tile_graphic_sequences
COPYBLOCK draw_table_selected_left_half_row_source, draw_table_selected_left_half_row_source_end, &2E85

; Runtime $1685-$16B1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $2E85-$2EB1.
CLEAR draw_table_selected_left_half_row_source, draw_table_selected_left_half_row_source_end

ORG left_half_four_tile_graphic_sequences
; Four four-selector records selected by room column modulo four for cell $1B.
.left_half_four_tile_graphic_sequences_source
    EQUB &17, &00, &00, &18 ; columns zero/four
    EQUB &16, &17, &18, &DA ; columns one/five
    EQUB &16, &16, &DA, &DB ; columns two/six
    EQUB &16, &13, &9A, &9B ; columns three/seven
.left_half_four_tile_graphic_sequences_source_end
ASSERT left_half_four_tile_graphic_sequences_source = left_half_four_tile_graphic_sequences
ASSERT left_half_four_tile_graphic_sequences_source_end = draw_two_13_two_beam_two_13_two_pattern
COPYBLOCK left_half_four_tile_graphic_sequences_source, left_half_four_tile_graphic_sequences_source_end, &2EB2
CLEAR left_half_four_tile_graphic_sequences_source, left_half_four_tile_graphic_sequences_source_end


ORG test_cross_room_robot_ghost_matches_reference

; X selects two fields. Return carry set only when both
; match their respective reference bytes; otherwise return carry clear at the
; first mismatch. X/Y and memory are preserved.
.test_cross_room_robot_ghost_matches_reference_source
    LDA cross_room_robot_ghost_primary_field,X
    CMP reference_pair_primary_value
    BNE cross_room_robot_ghost_mismatch
    LDA cross_room_robot_ghost_secondary_field,X
    CMP reference_pair_secondary_value
    BNE cross_room_robot_ghost_mismatch
    SEC
    RTS

.cross_room_robot_ghost_mismatch
    CLC
    RTS
.test_cross_room_robot_ghost_matches_reference_source_end

ASSERT test_cross_room_robot_ghost_matches_reference_source = test_cross_room_robot_ghost_matches_reference
ASSERT test_cross_room_robot_ghost_matches_reference_source_end = &2EEE
COPYBLOCK test_cross_room_robot_ghost_matches_reference_source, test_cross_room_robot_ghost_matches_reference_source_end, &46DD

; Runtime $2EDD-$2EED overlaps the loaded transport image. Release it after
; copying its bytes to loaded $46DD-$46ED.
CLEAR test_cross_room_robot_ghost_matches_reference_source, test_cross_room_robot_ghost_matches_reference_source_end

ORG player_range_no_overlap_return

; Shared no-overlap exit for the player range test: clear carry and return.
.player_range_no_overlap_return_source
    CLC
    RTS
.player_range_no_overlap_return_source_end

ASSERT player_range_no_overlap_return_source = player_range_no_overlap_return
ASSERT player_range_no_overlap_return_source_end = &2B9E
COPYBLOCK player_range_no_overlap_return_source, player_range_no_overlap_return_source_end, &439C

; Runtime $2B9C-$2B9D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $439C-$439D.
CLEAR player_range_no_overlap_return_source, player_range_no_overlap_return_source_end


ORG set_cross_room_robot_ghost_value_delta_at_thresholds

; Select one of two value thresholds from the indexed
; primary field. Store +1 below the positive threshold or -1 at/above the
; negative threshold; otherwise return with the last comparison flags.
.set_cross_room_robot_ghost_value_delta_at_thresholds_source
    LDA cross_room_robot_ghost_primary_field,X
    CMP cross_room_robot_ghost_positive_delta_selector
    BNE check_negative_delta_selector
    LDA cross_room_robot_ghost_value_field,X
    CMP cross_room_robot_ghost_positive_delta_threshold
    BPL return_preserving_comparison_flags
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_POSITIVE
.store_cross_room_robot_ghost_value_delta
    STA cross_room_robot_ghost_value_delta_field,X
    RTS

.check_negative_delta_selector
    CMP cross_room_robot_ghost_negative_delta_selector
    BNE return_preserving_comparison_flags
    LDA cross_room_robot_ghost_value_field,X
    CMP cross_room_robot_ghost_negative_delta_threshold
    BMI return_preserving_comparison_flags
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_NEGATIVE
    JMP store_cross_room_robot_ghost_value_delta
.set_cross_room_robot_ghost_value_delta_at_thresholds_source_end

ASSERT set_cross_room_robot_ghost_value_delta_at_thresholds_source = set_cross_room_robot_ghost_value_delta_at_thresholds
ASSERT set_cross_room_robot_ghost_value_delta_at_thresholds_source_end = &2F12
COPYBLOCK set_cross_room_robot_ghost_value_delta_at_thresholds_source, set_cross_room_robot_ghost_value_delta_at_thresholds_source_end, &46EE

; Runtime $2EEE-$2F11 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $46EE-$4711.
CLEAR set_cross_room_robot_ghost_value_delta_at_thresholds_source, set_cross_room_robot_ghost_value_delta_at_thresholds_source_end

ORG advance_cross_room_robot_ghost_value_and_display_pointer

; Add the X-selected signed unit delta to one robot/ghost position, move its
; display pointer by one Mode 1 cell column, wrap across room-column fields,
; and reverse the delta at ROOM_COLUMN_FIRST or ROOM_COLUMN_LAST. The BPL/BMI
; decisions deliberately consume the NMOS N flag directly.
.advance_cross_room_robot_ghost_value_and_display_pointer_source
    LDA cross_room_robot_ghost_value_field,X
    CLC
    ADC cross_room_robot_ghost_value_delta_field,X
    STA cross_room_robot_ghost_value_field,X

    LDA cross_room_robot_ghost_value_delta_field,X
    CMP #CROSS_ROOM_ROBOT_GHOST_STEP_NEGATIVE
    BEQ advance_cross_room_robot_ghost_pointer_negative

    LDA cross_room_robot_ghost_value_field,X
    CMP #CROSS_ROOM_ROBOT_GHOST_HORIZONTAL_WRAP_POSITION
    BPL cross_room_robot_ghost_positive_wrap_entry
    CLC
    LDA cross_room_robot_ghost_display_pointer_low,X
    ADC #MODE1_CELL_COLUMN_BYTES
    STA cross_room_robot_ghost_display_pointer_low,X
    LDA cross_room_robot_ghost_display_pointer_high,X
    ADC #HI(MODE1_CELL_COLUMN_BYTES) ; propagate the low-byte addition's carry
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.advance_cross_room_robot_ghost_pointer_negative
    LDA cross_room_robot_ghost_value_field,X
    BMI cross_room_robot_ghost_negative_wrap_entry
    SEC
    LDA cross_room_robot_ghost_display_pointer_low,X
    SBC #MODE1_CELL_COLUMN_BYTES
    STA cross_room_robot_ghost_display_pointer_low,X
    LDA cross_room_robot_ghost_display_pointer_high,X
    SBC #HI(MODE1_CELL_COLUMN_BYTES) ; propagate the low-byte subtraction's borrow
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.cross_room_robot_ghost_positive_wrap_entry
    LDA cross_room_robot_ghost_primary_field,X
    CMP #ROOM_COLUMN_LAST
    BEQ reverse_cross_room_robot_ghost_delta_negative
    INC cross_room_robot_ghost_primary_field,X
    LDA #CROSS_ROOM_ROBOT_GHOST_HORIZONTAL_FIRST_POSITION
    STA cross_room_robot_ghost_value_field,X
    SEC
    LDA cross_room_robot_ghost_display_pointer_low,X
    SBC #LO(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA cross_room_robot_ghost_display_pointer_low,X
    LDA cross_room_robot_ghost_display_pointer_high,X
    SBC #HI(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.reverse_cross_room_robot_ghost_delta_negative
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_NEGATIVE
    STA cross_room_robot_ghost_value_delta_field,X
    RTS

.cross_room_robot_ghost_negative_wrap_entry
    LDA cross_room_robot_ghost_primary_field,X
    BEQ reverse_cross_room_robot_ghost_delta_positive
    DEC cross_room_robot_ghost_primary_field,X
    LDA #CROSS_ROOM_ROBOT_GHOST_HORIZONTAL_WRAP_POSITION-1
    STA cross_room_robot_ghost_value_field,X
    CLC
    LDA cross_room_robot_ghost_display_pointer_low,X
    ADC #LO(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA cross_room_robot_ghost_display_pointer_low,X
    LDA cross_room_robot_ghost_display_pointer_high,X
    ADC #HI(MODE1_ROW_AFTER_TWO_GRAPHICS)
    STA cross_room_robot_ghost_display_pointer_high,X
    RTS

.reverse_cross_room_robot_ghost_delta_positive
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_POSITIVE
    STA cross_room_robot_ghost_value_delta_field,X
    RTS
.advance_cross_room_robot_ghost_value_and_display_pointer_source_end

ASSERT advance_cross_room_robot_ghost_value_and_display_pointer_source = advance_cross_room_robot_ghost_value_and_display_pointer
ASSERT advance_cross_room_robot_ghost_value_and_display_pointer_source_end = &2F8F
COPYBLOCK advance_cross_room_robot_ghost_value_and_display_pointer_source, advance_cross_room_robot_ghost_value_and_display_pointer_source_end, &4712

; Runtime $2F12-$2F8E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4712-$478E.
CLEAR advance_cross_room_robot_ghost_value_and_display_pointer_source, advance_cross_room_robot_ghost_value_and_display_pointer_source_end

; Copy these earlier-assembled room-cell blocks only after the cross-room robot/ghost
; routines that occupy the same runtime addresses as their loaded images.
COPYBLOCK draw_two_13_two_beam_two_13_two_pattern_source, draw_left_half_sequence_twice_or_13_beam_pattern_source_end, &2EC2
CLEAR draw_two_13_two_beam_two_13_two_pattern_source, draw_left_half_sequence_twice_or_13_beam_pattern_source_end
COPYBLOCK draw_room_sign_or_collect_password_source, draw_room_sign_or_collect_password_source_end, &2EEA
CLEAR draw_room_sign_or_collect_password_source, draw_room_sign_or_collect_password_source_end

ORG test_display_pointer_in_xor_draw_window

; Return carry clear exactly when the little-endian
; display pointer at $7C/$7D is in $4180-$7FFF. The high-byte path used by all
; 485 committed no-input calls exits at the first full display page; the $41 low-byte boundary
; and carry-set rejection paths are byte-proven but not trace-observed.
.test_display_pointer_in_xor_draw_window_source
    LDA display_pointer_high
    CMP #HI(QUEST_DISPLAY_END_EXCLUSIVE)
    BPL display_pointer_outside_xor_draw_window
    CMP #HI(XOR_DRAW_WINDOW_FIRST_FULL_PAGE)
    BPL display_pointer_inside_xor_draw_window
    CMP #HI(room_render_display_start)
    BMI display_pointer_outside_xor_draw_window
    LDA display_pointer_low
    CMP #LO(room_render_display_start)
    BMI display_pointer_outside_xor_draw_window
.display_pointer_inside_xor_draw_window
    CLC
    RTS
.display_pointer_outside_xor_draw_window
    SEC
    RTS
.test_display_pointer_in_xor_draw_window_source_end

ASSERT test_display_pointer_in_xor_draw_window_source = test_display_pointer_in_xor_draw_window
ASSERT test_display_pointer_in_xor_draw_window_source_end = &32BF
COPYBLOCK test_display_pointer_in_xor_draw_window_source, test_display_pointer_in_xor_draw_window_source_end, &4AA7

; Runtime $32A7-$32BE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4AA7-$4ABE.
CLEAR test_display_pointer_in_xor_draw_window_source, test_display_pointer_in_xor_draw_window_source_end

ORG enter_submit_osword_07_sound_block

; Runtime $32C0-$32C4 is one JMP thunk followed by two mutable packed-BCD data
; bytes. Ghidra's linear sweep decoded the initial $45,$10 as EOR $10, but no
; trace executes them and the source-owned BCD routine reads, writes and prints
; them as separate counter bytes.
.enter_submit_osword_07_sound_block_source
    JMP submit_osword_07_sound_block

.initial_bcd_counter_low
    EQUB &45

.initial_bcd_counter_high
    EQUB &10
.enter_submit_osword_07_sound_block_source_end

ASSERT enter_submit_osword_07_sound_block_source = enter_submit_osword_07_sound_block
ASSERT initial_bcd_counter_low = bcd_counter_low
ASSERT initial_bcd_counter_high = bcd_counter_high
ASSERT enter_submit_osword_07_sound_block_source_end = &32C5
COPYBLOCK enter_submit_osword_07_sound_block_source, enter_submit_osword_07_sound_block_source_end, &4AC0

; Runtime $32C0-$32C4 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4AC0-$4AC4.
CLEAR enter_submit_osword_07_sound_block_source, enter_submit_osword_07_sound_block_source_end

ORG select_graphic_then_xor_draw

; X indexes a run-time little-endian pointer table whose
; low byte starts at $0B5F and high byte is the following entry. A contains
; the display-pointer low byte needed by the fall-through XOR renderer. The
; push/pop preserves A while $7A/$7B receive the selected graphic pointer;
; X, Y, and the entry stack depth are unchanged at the fall-through boundary.
.select_graphic_then_xor_draw_source
    PHA
    LDA active_room_moving_object_pointer_table,X
    STA graphic_source_pointer_low
    LDA active_room_moving_object_pointer_table+1,X
    STA graphic_source_pointer_high
    PLA
.select_graphic_then_xor_draw_source_end

ASSERT select_graphic_then_xor_draw_source = select_graphic_then_xor_draw
ASSERT select_graphic_then_xor_draw_source_end = xor_graphic_into_display
COPYBLOCK select_graphic_then_xor_draw_source, select_graphic_then_xor_draw_source_end, &4AC5

; Runtime $32C5-$32D0 also overlaps the loaded transport image. Release the
; logical source range after its bytes have been copied to loaded $4AC5-$4AD0.
CLEAR select_graphic_then_xor_draw_source, select_graphic_then_xor_draw_source_end

ORG play_descending_flash_sequence

; Flash the background twenty-one times, sweeping X from $14
; down to zero and preserving it across each call.
; flash_background_colour_with_sound takes X as both the physical colour and the
; sound pitch, so a single descending sweep drives colour and note together: the
; screen cycles down through the palette while the pitch falls. Each call also
; waits for vertical sync, which is what paces the sequence to one flash per
; frame.
.play_descending_flash_sequence_source
    LDX #&14

.play_descending_flash_sequence_branch_1
    TXA
    PHA
    JSR flash_background_colour_with_sound
    PLA
    TAX
    DEX
    BPL play_descending_flash_sequence_branch_1
    RTS
.play_descending_flash_sequence_source_end

ASSERT play_descending_flash_sequence_source = play_descending_flash_sequence
ASSERT play_descending_flash_sequence_source_end = &314F
COPYBLOCK play_descending_flash_sequence_source, play_descending_flash_sequence_source_end, &4942

; Runtime $3142-$314E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4942-$494E.
CLEAR play_descending_flash_sequence_source, play_descending_flash_sequence_source_end


ORG flash_background_colour_with_sound

; Flash the background by redefining logical colour 0, with
; a sound, then wait for the next frame.
; VDU 19 takes five parameters. The first three, 19, 0 and X, are written before
; the sound is submitted with the same X as its pitch; the remaining three zeros
; follow it. So the palette change and the sound are issued together, and the
; closing OSBYTE $13 waits for vertical sync so the new colour is visible for at
; least one frame.
; X is therefore both the physical colour and the pitch, which is why a louder
; flash and a higher note arrive together.
.flash_background_colour_with_sound_source
    LDA #&13
    JSR OSWRCH
    LDA #&00
    JSR OSWRCH
    TXA
    JSR OSWRCH
    TXA
    JSR submit_sound_block_with_pitch
    LDA #&00
    JSR OSWRCH
    JSR OSWRCH
    JSR OSWRCH
    LDA #&13
    JMP OSBYTE
.flash_background_colour_with_sound_source_end

ASSERT flash_background_colour_with_sound_source = flash_background_colour_with_sound
ASSERT flash_background_colour_with_sound_source_end = &3171
COPYBLOCK flash_background_colour_with_sound_source, flash_background_colour_with_sound_source_end, &494F

; Runtime $314F-$3170 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $494F-$4970.
CLEAR flash_background_colour_with_sound_source, flash_background_colour_with_sound_source_end


ORG ghost_countdown_steering_update

; Process indexed entries X=$00/$02 for high-secondary
; rooms. Countdown values zero or two take the original preceding erase/step
; block at $3003; other values decrement here. On expiry, optionally erase the
; directional graphic, steer the pair relative to the player, toggle the first
; pair when both pair positions meet, test the tall overlap, and redraw.
.ghost_countdown_steering_update_source
    LDX #CROSS_ROOM_ROBOT_GHOST_PAIR_FIRST_INDEX

.ghost_countdown_loop
    LDA cross_room_robot_ghost_redraw_countdown,X
    BEQ draw_then_decrement_ghost
    CMP #CROSS_ROOM_GHOST_REDRAW_COUNTDOWN
    BEQ draw_then_decrement_ghost
.decrement_ghost_countdown
    DEC cross_room_robot_ghost_redraw_countdown,X
    BNE advance_ghost_selector
    LDA #CROSS_ROOM_GHOST_COUNTDOWN_RESET
    STA cross_room_robot_ghost_redraw_countdown,X
    LDA erase_previous_xor_sprite_flag
    BEQ update_ghost_state
    JSR draw_directional_ghost_if_reference_matches

.update_ghost_state
    JSR set_ghost_steps_toward_player
    JSR toggle_first_ghost_axis_mode_when_positions_match
    JSR handle_matching_ghost
    JSR draw_directional_ghost_if_reference_matches

.advance_ghost_selector
    INX
    INX
    CPX #CROSS_ROOM_ROBOT_GHOST_PAIR_END_INDEX
    BNE ghost_countdown_loop
    RTS
.ghost_countdown_steering_update_source_end

ASSERT ghost_countdown_steering_update_source = ghost_countdown_steering_update
ASSERT ghost_countdown_steering_update_source_end = handle_matching_ghost
COPYBLOCK ghost_countdown_steering_update_source, ghost_countdown_steering_update_source_end, &4809

; Runtime $3009-$3034 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4809-$4834.
CLEAR ghost_countdown_steering_update_source, ghost_countdown_steering_update_source_end


ORG handle_matching_ghost

; A mismatch returns through the preceding $3034 RTS. A
; match copies the indexed horizontal value to candidate_horizontal_position,
; converts the even vertical offset to the collision coordinate, selects the
; ghost's tall overlap extent, and tail-enters the player/candidate guard.
.handle_matching_ghost_source
    JSR test_cross_room_robot_ghost_matches_reference
    BCC ghost_reference_mismatch_return
    LDA cross_room_robot_ghost_value_field,X
    STA candidate_horizontal_position
    LDA cross_room_robot_ghost_offset_field,X
    LSR A
    CLC
    ADC #CROSS_ROOM_GHOST_OVERLAP_VERTICAL_BIAS
    STA candidate_half_vertical_position
    LDA #CROSS_ROOM_GHOST_COLLISION_EXTENT
    STA xor_graphic_character_rows_remaining
    JMP check_player_candidate_bounds_overlap
.handle_matching_ghost_source_end

ASSERT handle_matching_ghost_source = handle_matching_ghost
ASSERT handle_matching_ghost_source_end = set_ghost_steps_toward_player
COPYBLOCK handle_matching_ghost_source, handle_matching_ghost_source_end, &4835

; Runtime $3035-$304E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4835-$484E.
CLEAR handle_matching_ghost_source, handle_matching_ghost_source_end


ORG set_ghost_steps_toward_player

; the first body range of Ghidra function $304F. Matching
; secondary fields set the signed ghost vertical step from the player/pair
; half-offset comparison. Matching primary fields set a signed horizontal step. Control then
; enters the separately sourced mode block at $3083/$3085/$3088. The external
; $307F entry tail-jumps to the sourced horizontal value/pointer step.
.set_ghost_steps_toward_player_source
    LDA reference_pair_secondary_value
    CMP cross_room_robot_ghost_secondary_field,X
    BNE check_cross_room_robot_ghost_horizontal_reference
    LDA cross_room_robot_ghost_offset_field,X
    LSR A
    STA ghost_half_vertical_position
    LDA player_vertical_position
    LSR A
    CMP ghost_half_vertical_position
    BPL set_cross_room_robot_ghost_vertical_delta_positive
    LDA #CROSS_ROOM_GHOST_VERTICAL_STEP_UP
    JMP store_cross_room_robot_ghost_vertical_delta

.set_cross_room_robot_ghost_vertical_delta_positive
    LDA #CROSS_ROOM_GHOST_VERTICAL_STEP_DOWN

.store_cross_room_robot_ghost_vertical_delta
    STA cross_room_robot_ghost_offset_delta_field,X

.check_cross_room_robot_ghost_horizontal_reference
    LDA reference_pair_primary_value
    CMP cross_room_robot_ghost_primary_field,X
    BNE apply_cross_room_robot_ghost_axis_mode
    LDA player_horizontal_position
    CMP cross_room_robot_ghost_value_field,X
    BMI apply_ghost_player_axis_mode
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_POSITIVE
    JMP store_cross_room_robot_ghost_horizontal_delta

.advance_cross_room_robot_ghost_horizontal_position
    JMP advance_cross_room_robot_ghost_value_and_display_pointer
.set_ghost_steps_toward_player_source_end

ASSERT set_ghost_steps_toward_player_source = set_ghost_steps_toward_player
ASSERT set_ghost_steps_toward_player_source_end = &3082
COPYBLOCK set_ghost_steps_toward_player_source, set_ghost_steps_toward_player_source_end, &484F

; Runtime $304F-$3081 overlaps the loaded transport image. Byte $3082 is an
; unreachable RTS outside Ghidra's function body and remains original-owned.
CLEAR set_ghost_steps_toward_player_source, set_ghost_steps_toward_player_source_end


ORG apply_ghost_player_axis_mode

; the second body range of Ghidra function $304F. The
; entry supplies the negative horizontal step. Vertical mode advances until the
; ghost reaches player Y, then selects horizontal mode; horizontal mode advances
; until player X is reached, then selects vertical mode.
.apply_ghost_player_axis_mode_source
    LDA #CROSS_ROOM_ROBOT_GHOST_STEP_NEGATIVE

.store_cross_room_robot_ghost_horizontal_delta
    STA cross_room_robot_ghost_value_delta_field,X

.apply_cross_room_robot_ghost_axis_mode
    LDA cross_room_robot_ghost_mode_field,X
    CMP #CROSS_ROOM_GHOST_MODE_VERTICAL
    BEQ apply_cross_room_robot_ghost_vertical_mode
    LDA player_horizontal_position
    CMP cross_room_robot_ghost_value_field,X
    BNE advance_cross_room_robot_ghost_horizontal_position
    LDA #CROSS_ROOM_GHOST_MODE_VERTICAL
    STA cross_room_robot_ghost_mode_field,X
    RTS

.advance_cross_room_robot_ghost_vertical_position
    JMP advance_cross_room_robot_ghost_offset_and_display_pointer

.apply_cross_room_robot_ghost_vertical_mode
    LDA player_vertical_position
    CMP cross_room_robot_ghost_offset_field,X
    BNE advance_cross_room_robot_ghost_vertical_position
    LDA #CROSS_ROOM_GHOST_MODE_HORIZONTAL
    STA cross_room_robot_ghost_mode_field,X
    RTS
.apply_ghost_player_axis_mode_source_end

ASSERT apply_ghost_player_axis_mode_source = apply_ghost_player_axis_mode
ASSERT apply_ghost_player_axis_mode_source_end = toggle_first_ghost_axis_mode_when_positions_match
COPYBLOCK apply_ghost_player_axis_mode_source, apply_ghost_player_axis_mode_source_end, &4883

; Runtime $3083-$30AB overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4883-$48AB.
CLEAR apply_ghost_player_axis_mode_source, apply_ghost_player_axis_mode_source_end


ORG toggle_first_ghost_axis_mode_when_positions_match

; Compare the value and offset fields of ghost 0
; with pair 1 (the same arrays at index 2). A mismatch returns through the
; preceding shared RTS at $30AB. When both fields match, change the first pair's
; mode between the named horizontal and vertical modes. The alternate updater calls
; this once after processing both entries, so it detects the two positions
; meeting and alternates the first entry's mode.
.toggle_first_ghost_axis_mode_when_positions_match_source
    LDA cross_room_robot_ghost_value_field
    CMP cross_room_robot_ghost_value_field+2
    BNE cross_room_robot_ghost_positions_differ_return
    LDA cross_room_robot_ghost_offset_field
    CMP cross_room_robot_ghost_offset_field+2
    BNE cross_room_robot_ghost_positions_differ_return
    LDA cross_room_robot_ghost_mode_field
    CMP #CROSS_ROOM_GHOST_MODE_VERTICAL
    BNE set_first_cross_room_robot_ghost_mode_two
    LDA #CROSS_ROOM_GHOST_MODE_HORIZONTAL

.store_first_cross_room_robot_ghost_mode
    STA cross_room_robot_ghost_mode_field
    RTS

.set_first_cross_room_robot_ghost_mode_two
    LDA #CROSS_ROOM_GHOST_MODE_VERTICAL
    JMP store_first_cross_room_robot_ghost_mode
.toggle_first_ghost_axis_mode_when_positions_match_source_end

ASSERT toggle_first_ghost_axis_mode_when_positions_match_source = toggle_first_ghost_axis_mode_when_positions_match
ASSERT toggle_first_ghost_axis_mode_when_positions_match_source_end = run_energy_bar_sweep
COPYBLOCK toggle_first_ghost_axis_mode_when_positions_match_source, toggle_first_ghost_axis_mode_when_positions_match_source_end, &48AC

; Runtime $30AC-$30CD overlaps the loaded transport image. Release it after
; copying its bytes to loaded $48AC-$48CD.
CLEAR toggle_first_ghost_axis_mode_when_positions_match_source, toggle_first_ghost_axis_mode_when_positions_match_source_end


ORG run_energy_bar_sweep

; Sweep the energy value from 0 to $FE, redrawing the bar at
; every step, with a delay between them.
; X counts the energy level and is written to both the snapshot and live energy before each
; redraw, so the stored value and the displayed value stay together. The inner
; loop counts Y down from $FF purely to pass time, giving each step a visible
; pause; at 255 steps of 255 iterations that is the whole bar filling smoothly
; rather than jumping.
; This is an animation rather than gameplay: nothing reads input and the energy
; is overwritten on every iteration.
.run_energy_bar_sweep_source
    LDX #&00

.sweep_next_energy_level
    LDY #&FF

.delay_between_steps
    DEY
    BNE delay_between_steps
    STX player_energy_snapshot
    STX player_energy
    JSR submit_channel_one_sound_with_x_pitch
    JSR redraw_energy_bar_segment
    INX
    CPX #&FF
    BNE sweep_next_energy_level
    RTS
.run_energy_bar_sweep_source_end

ASSERT run_energy_bar_sweep_source = run_energy_bar_sweep
ASSERT run_energy_bar_sweep_source_end = &30E5
COPYBLOCK run_energy_bar_sweep_source, run_energy_bar_sweep_source_end, &48CE

; Runtime $30CE-$30E4 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $48CE-$48E4.
CLEAR run_energy_bar_sweep_source, run_energy_bar_sweep_source_end

ORG submit_channel_one_sound_with_x_pitch

; Supply X as the pitch for an OSWORD $07 sound on
; channel byte $11, then tail-enter the common fixed-amplitude submission.
.submit_channel_one_sound_with_x_pitch_source
    STX sound_block_pitch
    LDA #&11
    JMP enter_submit_osword_07_sound_block
.submit_channel_one_sound_with_x_pitch_source_end

ASSERT submit_channel_one_sound_with_x_pitch_source = submit_channel_one_sound_with_x_pitch
ASSERT submit_channel_one_sound_with_x_pitch_source_end = consume_collected_icon_and_apply_effect
COPYBLOCK submit_channel_one_sound_with_x_pitch_source, submit_channel_one_sound_with_x_pitch_source_end, &48E5

; Runtime $30E5-$30EC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $48E5-$48EC.
CLEAR submit_channel_one_sound_with_x_pitch_source, submit_channel_one_sound_with_x_pitch_source_end

ORG consume_collected_icon_and_apply_effect

; Consume one collected status icon unless the count is
; exactly four, then run the common descending flash effect.
; ROOM_INTERACTION_LONG_ICON_EFFECT selects the longer cleanup path: remove a second icon, restore the saved
; cell with $53, clear the selected room-appearance byte and effect state, flash
; once, then sweep X from 1 through $FF using OSBYTE calls and pitch-X sounds.
.consume_collected_icon_and_apply_effect_source
    LDA collected_icon_count
    CMP #&04
    BEQ run_energy_bar_sweep_rts
    DEC collected_icon_count
    LDA collected_icon_count
    JSR erase_collected_icon
    LDA #&01
    STA reset_cross_room_robot_ghost_countdowns
    LDA room_interaction_code
    CMP #ROOM_INTERACTION_LONG_ICON_EFFECT
    BNE play_descending_flash_sequence
    DEC progress_pattern_pair_count
    DEC collected_icon_erase_index
    LDA collected_icon_erase_index
    JSR erase_collected_icon
    LDA #&53
    JSR store_byte_through_saved_pointer
    LDX reference_pair_primary_value
    LDA effect_room_appearance_indices,X
    TAY
    LDA #&00
    STA room_appearance_table,Y
    STA room_interaction_code
    STA slow_damage_countdown
    JSR play_descending_flash_sequence
    LDX #&01

.collected_icon_effect_next_step
    STX collected_icon_effect_step_saved
    LDA #OSBYTE_SET_FLASH_MARK_PERIOD
    JSR OSBYTE
    LDA #OSBYTE_SET_FLASH_SPACE_PERIOD
    JSR OSBYTE
    JSR submit_channel_one_sound_with_x_pitch
    LDA #OSBYTE_WAIT_VSYNC
    JSR OSBYTE
    LDX collected_icon_effect_step_saved
    INX
    BNE collected_icon_effect_next_step
    STX lower_screen_palette_base
.consume_collected_icon_and_apply_effect_source_end

ASSERT consume_collected_icon_and_apply_effect_source = consume_collected_icon_and_apply_effect
ASSERT consume_collected_icon_and_apply_effect_source_end = play_descending_flash_sequence
COPYBLOCK consume_collected_icon_and_apply_effect_source, consume_collected_icon_and_apply_effect_source_end, &48ED

; Runtime $30ED-$3141 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $48ED-$4941.
CLEAR consume_collected_icon_and_apply_effect_source, consume_collected_icon_and_apply_effect_source_end


ORG run_horizontal_16_warp_sequence

; Return through the shared $3199 RTS unless the player
; horizontal position is HORIZONTAL_WARP_TRIGGER_POSITION. On a match, count X
; from HORIZONTAL_WARP_STEP_COUNT to zero; each step preserves X, XOR-draws the
; player, waits for two vertical syncs, and submits a channel-one sound whose pitch is X.
; After all 100 steps, warp to room references 3/4 and tail-draw the player at
; the new room position.
.run_horizontal_16_warp_sequence_source
    LDA player_horizontal_position
    CMP #HORIZONTAL_WARP_TRIGGER_POSITION
    BNE return_from_horizontal_16_warp_sequence
    LDX #HORIZONTAL_WARP_STEP_COUNT

.horizontal_16_warp_next_step
    STX warp_sequence_counter_saved
    JSR xor_draw_player_two_parts
    LDA #OSBYTE_WAIT_VSYNC
    JSR OSBYTE
    JSR OSBYTE
    LDX warp_sequence_counter_saved
    JSR submit_channel_one_sound_with_x_pitch
    DEX
    BNE horizontal_16_warp_next_step
    JSR warp_to_room_3_4
    JMP xor_draw_player_two_parts
.run_horizontal_16_warp_sequence_source_end

ASSERT run_horizontal_16_warp_sequence_source = run_horizontal_16_warp_sequence
ASSERT run_horizontal_16_warp_sequence_source_end = &31EB
COPYBLOCK run_horizontal_16_warp_sequence_source, run_horizontal_16_warp_sequence_source_end, &49C8

; Runtime $31C8-$31EA overlaps the loaded transport image. Release it after
; copying its bytes to loaded $49C8-$49EA.
CLEAR run_horizontal_16_warp_sequence_source, run_horizontal_16_warp_sequence_source_end


ORG draw_status_panel_divider

; Draw a horizontal rule across the status area by writing
; $F0 into the same scanline of 66 consecutive character cells, starting at
; $3CE0.
; store_byte_and_advance_source_pointer does the work, writing one byte and
; stepping the pointer by 8, one cell, so the 66 writes land on one display row
; rather than filling a block. $3CE0 is just past the screen base at $3C80, so
; this rule sits at the top of the display.
; draw_two_item_slots leaves through a tail jump here, so the rule is redrawn
; whenever the slots are.
.draw_status_panel_divider_source
    LDX #STATUS_PANEL_DIVIDER_CELL_COUNT
    LDA #LO(status_panel_divider_start)
    STA graphic_source_pointer_low
    LDA #HI(status_panel_divider_start)
    STA graphic_source_pointer_high
    LDY #&00

.write_next_divider_cell
    LDA #STATUS_PANEL_DIVIDER_PIXEL_BYTE
    JSR store_byte_and_advance_source_pointer
    BNE write_next_divider_cell
    RTS
.draw_status_panel_divider_source_end

ASSERT draw_status_panel_divider_source = draw_status_panel_divider
ASSERT draw_status_panel_divider_source_end = &31FF
COPYBLOCK draw_status_panel_divider_source, draw_status_panel_divider_source_end, &49EB

; Runtime $31EB-$31FE overlaps the loaded transport image. Release it after
; copying its bytes to loaded $49EB-$49FE.
CLEAR draw_status_panel_divider_source, draw_status_panel_divider_source_end

ORG warp_to_room_3_4

; Select secondary reference 4 and primary reference 3,
; set the corresponding level-base offset to 4*$78 = $01E0, then tail-dispatch
; through the $1206 vector to draw_and_initialise_room.
.warp_to_room_3_4_source
    LDA #HORIZONTAL_WARP_TARGET_LEVEL
    STA reference_pair_secondary_value
    LDA #HORIZONTAL_WARP_TARGET_COLUMN
    STA reference_pair_primary_value
    LDA #LO(HORIZONTAL_WARP_TARGET_LEVEL_MAP_OFFSET)
    STA level_room_map_offset_low
    LDA #HI(HORIZONTAL_WARP_TARGET_LEVEL_MAP_OFFSET)
    STA level_room_map_offset_high
    JMP enter_draw_and_initialise_room
.warp_to_room_3_4_source_end

ASSERT warp_to_room_3_4_source = warp_to_room_3_4
ASSERT warp_to_room_3_4_source_end = &3213
COPYBLOCK warp_to_room_3_4_source, warp_to_room_3_4_source_end, &4A00

; Runtime $3200-$3212 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4A00-$4A12.
CLEAR warp_to_room_3_4_source, warp_to_room_3_4_source_end


ORG start_saved_display_block_shift_effect

; The unobserved $3175 entry stores the caller's byte two
; positions beyond the saved cell, restores the saved offset, arms selector $04
; for 32 ticks, and replaces the saved cell with $39. Static call sites at
; $2A0D and $2A31 supply this entry from the adjacent interaction branches;
; no committed scenario takes either branch, so that prefix remains explicitly
; qualified as static dataflow rather than claimed runtime behavior.
;
; The traced $318E entry decrements the timed-effect countdown. At zero, clear the
; timed-effect selector and room_interaction_code, then return. Otherwise set the working display
; pointer to the saved display position plus $40, shift its eight-cell by
; four-row Mode 1 block right by one cell, advance the saved position by eight
; bytes with page carry, and tail-call the amplitude-1 sound player with duration
; one and pitch twice the remaining countdown.
; display_shift_expiry proves the zero branch; display_shift_pointer_carry
; proves the saved-pointer page carry; game_tick_22_state_4 supplies the natural
; active path. All authority/rebuild boundaries, complete effects, PC sequences,
; displays and video hardware compare exactly.
.start_saved_display_block_shift_effect_source
    INC saved_cell_write_offset
    INC saved_cell_write_offset
    JSR store_byte_through_saved_pointer
    DEC saved_cell_write_offset
    DEC saved_cell_write_offset
    LDA #SAVED_DISPLAY_SHIFT_INITIAL_COUNTDOWN
    STA timed_effect_countdown
    LDA #TIMED_EFFECT_SHIFT_SAVED_DISPLAY_BLOCK
    STA timed_effect_selector
    LDA #ROOM_CELL_ALTERNATING_RIGHT_HALF
    JMP store_byte_through_saved_pointer

.advance_saved_display_block_shift_effect_source
    DEC timed_effect_countdown
    BNE shift_saved_display_block_effect_step
    LDA #&00
    STA timed_effect_selector
    STA room_interaction_code
    RTS

.shift_saved_display_block_effect_step
    CLC
    LDA saved_effect_display_pointer_low
    ADC #SAVED_DISPLAY_SHIFT_ROW_OFFSET_LOW
    STA display_pointer_low
    LDA saved_effect_display_pointer_high
    ADC #&00
    STA display_pointer_high
    JSR shift_four_row_display_block_right
    CLC
    LDA saved_effect_display_pointer_low
    ADC #MODE1_CELL_COLUMN_BYTES
    STA saved_effect_display_pointer_low
    BCC play_saved_display_block_shift_sound
    INC saved_effect_display_pointer_high

.play_saved_display_block_shift_sound
    LDA timed_effect_countdown
    ASL A
    STA sound_block_pitch
    LDA #SAVED_DISPLAY_SHIFT_SOUND_DURATION
    STA sound_block_duration
    JMP play_sound_with_amplitude
.start_saved_display_block_shift_effect_source_end

ASSERT start_saved_display_block_shift_effect_source = start_saved_display_block_shift_effect
ASSERT advance_saved_display_block_shift_effect_source = advance_saved_display_block_shift_effect
ASSERT start_saved_display_block_shift_effect_source_end = &31C8
COPYBLOCK start_saved_display_block_shift_effect_source, start_saved_display_block_shift_effect_source_end, &4975

; Runtime $3175-$31C7 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4975-$49C7.
CLEAR start_saved_display_block_shift_effect_source, start_saved_display_block_shift_effect_source_end


ORG draw_blank_marker_and_column_gated_rows

; This contiguous room-cell handler cluster contains the two mirrored blank-marker layouts and cell types $36-$3A. Cells $36/$37 draw alternating rows only in columns three-or-seven / column three; $38 uses only column seven; $39 uses columns four-seven. Cell $3A optionally saves the cell/display pointers in column four, draws a blank row, then leaves A stacked for the shared $19E8 continuation. Natural room traces cover the marker, $38-$3A and shared alternating tails; focused real-dispatch fixtures cover every $36/$37 comparison and outcome with exact authority/rebuild parity.
.draw_blank_marker_and_column_gated_rows_source
    LDY #&00
    STY single_tile_room_graphic_selector
    JMP draw_curved_bowl_before_alternating_suffix_body

.draw_blank_marker_after_alternating_prefix_source
    LDY #&00
    STY single_tile_room_graphic_selector
    JMP draw_curved_bowl_after_alternating_prefix_body

.draw_alternating_only_in_columns_three_or_seven_source
    CMP #&03
    BEQ draw_eight_alternating_tiles_from_column_gate
    CMP #&07
    BEQ draw_eight_alternating_tiles_from_column_gate
    JMP draw_eight_blank_tiles

.draw_eight_alternating_tiles_from_column_gate
    JMP draw_eight_alternating_tiles

.draw_alternating_only_in_column_three_source
    CMP #&03
    BEQ draw_eight_alternating_tiles_from_column_gate
    JMP draw_eight_blank_tiles

.draw_alternating_only_in_last_column_source
    CMP #&07
    BEQ draw_eight_alternating_tiles_from_column_gate
    JMP draw_eight_blank_tiles

.draw_alternating_in_right_half_source
    CMP #&04
    BPL draw_eight_alternating_tiles_from_column_gate
    JMP draw_eight_blank_tiles

.draw_blank_then_configure_column_seven_object_source
    CMP #&04
    BNE save_column_and_draw_blank_row
    JSR save_display_pointer_and_cell_reference

.save_column_and_draw_blank_row
    PHA
    JSR draw_eight_blank_tiles
.draw_blank_marker_and_column_gated_rows_source_end

ASSERT draw_blank_marker_and_column_gated_rows_source = draw_blank_marker_and_column_gated_rows
ASSERT draw_blank_marker_and_column_gated_rows_source = draw_blank_marker_before_alternating_suffix
ASSERT draw_blank_marker_after_alternating_prefix_source = draw_blank_marker_after_alternating_prefix
ASSERT draw_alternating_only_in_columns_three_or_seven_source = draw_alternating_only_in_columns_three_or_seven
ASSERT draw_alternating_only_in_column_three_source = draw_alternating_only_in_column_three
ASSERT draw_alternating_only_in_last_column_source = draw_alternating_only_in_last_column
ASSERT draw_alternating_in_right_half_source = draw_alternating_in_right_half
ASSERT draw_blank_then_configure_column_seven_object_source = draw_blank_then_configure_column_seven_object
ASSERT draw_blank_marker_and_column_gated_rows_source_end = &19E8
COPYBLOCK draw_blank_marker_and_column_gated_rows_source, draw_blank_marker_and_column_gated_rows_source_end, &31AA

; Runtime $19AA-$19E7 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $31AA-$31E7.
CLEAR draw_blank_marker_and_column_gated_rows_source, draw_blank_marker_and_column_gated_rows_source_end


ORG draw_fixed_pair_gap_and_bordered_rows

; The cell-$31 entry draws two fixed-pair tiles, four
; blanks, then two fixed-pair tiles. Cell $32 loads graphic selector $09 and
; enters the shared bordered-row painter at $18C5. Both presets are fully
; traced through the room-cell dispatcher. The remaining cluster contains
; entries $1904, $1916, $1974, $1981 and $19A0. The bordered painter selects
; end/interior graphic records from column zero, seven or the middle columns.
; The two dynamic-object entries gate a GRAPHIC_DOUBLE_BAR room-object setup on
; DYNAMIC_OBJECT_REQUIRED_TILE_PAIR, populate the slot bound, lower position and
; class, and call the existing object helpers while preserving the display pointer.
; Cell $2E enables water_environment_flag and blanks the
; selector-matching column and otherwise enters the right-half alternating
; handler. Cell $35 draws blanks around an odd alternating run derived from the
; column. Cell $2F selects ROOM_INTERACTION_LONG_ICON_EFFECT, draws its special
; row and saves the cell/display pointers. Natural traces cover the first 95
; instructions; three
; focused real-dispatch fixtures cover every remaining cell-$2E/$35 instruction
; with exact authority/rebuild parity.
.draw_fixed_pair_gap_and_bordered_rows_source
    LDX #FIXED_PAIR_GAP_EDGE_TILE_COUNT
    JSR draw_fixed_pair_tile_run+2
    LDX #FIXED_PAIR_GAP_BLANK_TILE_COUNT
    JSR draw_blank_tile_run
    LDX #FIXED_PAIR_GAP_EDGE_TILE_COUNT
    JMP draw_fixed_pair_tile_run+2

.draw_bordered_checker_diagonal_row_source
    LDX #GRAPHIC_CHECKER_DIAGONAL
    STX bordered_row_interior_graphic

.draw_bordered_row_with_selected_interior_source
    CMP #ROOM_COLUMN_FIRST
    BNE draw_bordered_row_last_or_middle_column
    LDA #GRAPHIC_DIAGONAL_SLOPE_A
    JSR copy_16_byte_graphic_to_display
    LDX #BORDERED_ROW_INTERIOR_TILE_COUNT
    JSR draw_blank_tile_run
    LDA #GRAPHIC_DIAGONAL_SLOPE_B
    JMP copy_16_byte_graphic_to_display

.draw_bordered_row_middle_column
    LDA #GRAPHIC_FLAT_FILL
    JSR copy_16_byte_graphic_to_display
    LDA bordered_row_interior_graphic
    LDX #BORDERED_ROW_INTERIOR_TILE_COUNT

.draw_next_bordered_row_interior_tile
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_bordered_row_interior_tile
    LDA #GRAPHIC_FLAT_FILL
    JMP copy_16_byte_graphic_to_display

.draw_bordered_row_last_or_middle_column
    CMP #ROOM_COLUMN_LAST
    BNE draw_bordered_row_middle_column
    LDA #GRAPHIC_RECORD_MIRROR_FLAG+GRAPHIC_DIAGONAL_SLOPE_B
    JSR copy_16_byte_graphic_to_display
    LDX #BORDERED_ROW_INTERIOR_TILE_COUNT
    LDA #GRAPHIC_HORIZONTAL_PLATFORM

.draw_next_last_column_interior_tile
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_last_column_interior_tile
    LDA #GRAPHIC_RECORD_MIRROR_FLAG+GRAPHIC_DIAGONAL_SLOPE_A
    JMP copy_16_byte_graphic_to_display

.draw_or_configure_secondary_dynamic_object_source
    LDA tile_pair_source_selector
    BEQ enable_secondary_lift_hazard_updates_and_draw_blank_row
    LDY #DYNAMIC_OBJECT_SECONDARY_SLOT_START
    LDX #DYNAMIC_OBJECT_SECONDARY_SLOT_END
    JMP require_dynamic_object_tile_pair

.enable_secondary_lift_hazard_updates_and_draw_blank_row
    LDA #LIFT_HAZARD_UPDATES_ACTIVE
    STA lift_hazard_secondary_updates_active

.draw_blank_dynamic_object_row
    JMP draw_eight_blank_tiles

.draw_and_configure_dynamic_room_object_source
    LDA tile_pair_source_selector
    BEQ mark_dynamic_room_object_present
    LDX #DYNAMIC_OBJECT_PRIMARY_SLOT_END
    LDY #DYNAMIC_OBJECT_PRIMARY_SLOT_START
    JMP require_dynamic_object_tile_pair

.mark_dynamic_room_object_present
    LDA #LIFT_HAZARD_UPDATES_ACTIVE
    STA lift_hazard_primary_updates_active

.require_dynamic_object_tile_pair
    CMP #DYNAMIC_OBJECT_REQUIRED_TILE_PAIR
    BNE draw_blank_dynamic_object_row
    CMP room_graphics_column
    BNE configure_dynamic_object_outside_last_column
    LDA #DYNAMIC_OBJECT_COLUMN_LAST_LOWER_POSITION
    STA lift_or_hazard_lower_position
    LDA #LIFT_OR_HAZARD_LIFT
    JMP store_dynamic_room_object_class

.configure_dynamic_object_outside_last_column
    LDA #DYNAMIC_OBJECT_OTHER_COLUMN_LOWER_POSITION
    STA lift_or_hazard_lower_position
    LDA #LIFT_OR_HAZARD_HAZARD

.store_dynamic_room_object_class
    STA active_lift_or_hazard_class
    STX dynamic_room_object_slot_end
    JSR initialise_four_dynamic_room_object_slots
    LDX #DYNAMIC_OBJECT_TILE_COUNT

.draw_next_dynamic_room_object_tile
    LDA #GRAPHIC_DOUBLE_BAR
    JSR copy_16_byte_graphic_to_display
    DEX
    BNE draw_next_dynamic_room_object_tile
    LDA #DYNAMIC_OBJECT_SLOT_LIMIT_NONE
    STA lift_and_hazard_slot_limit
    JSR copy_lift_or_hazard_descriptor_for_active_class
    LDA display_pointer_low
    PHA
    LDA display_pointer_high
    PHA
    LDA dynamic_room_object_slot_end
    SEC
    SBC #DYNAMIC_OBJECT_PRIMARY_SLOT_END
    TAY

.submit_next_dynamic_room_object_slot
    JSR enter_draw_enemy_without_slot_check
    INY
    INY
    CPY dynamic_room_object_slot_end
    BNE submit_next_dynamic_room_object_slot
    PLA
    STA display_pointer_high
    PLA
    STA display_pointer_low
    RTS

.select_blank_or_right_half_pattern_by_column_source
    LDA #WATER_ENVIRONMENT_ACTIVE
    STA water_environment_flag
    LDA tile_pair_source_selector
    CMP room_graphics_column
    BNE draw_alternating_in_right_half

.draw_blank_selected_pattern_column
    JMP draw_eight_blank_tiles

.draw_centered_alternating_run_by_column_source
    CMP #ROOM_COLUMN_FIRST
    BEQ draw_blank_selected_pattern_column
    SEC
    LDA #ROOM_COLUMN_LAST
    SBC room_graphics_column
    LSR A
    STA room_pattern_selector_state
    TAX
    JSR draw_blank_tile_run
    LDA room_graphics_column
    AND #ROOM_EVEN_COLUMN_MASK
    TAX
    INX
    JSR draw_alternating_tile_run
    LDX room_pattern_selector_state
    INX
    JMP draw_blank_tile_run

.set_ff_state_and_draw_last_column_special_row_source
    LDX #ROOM_INTERACTION_LONG_ICON_EFFECT
    STX room_interaction_code
    JSR draw_last_column_special_pair_row
    JMP save_display_pointer_and_cell_reference
.draw_fixed_pair_gap_and_bordered_rows_source_end

ASSERT draw_fixed_pair_gap_and_bordered_rows_source = draw_fixed_pair_gap_and_bordered_rows
ASSERT draw_fixed_pair_gap_and_bordered_rows_source = draw_fixed_pair_gap_row
ASSERT draw_bordered_checker_diagonal_row_source = draw_bordered_checker_diagonal_row
ASSERT draw_bordered_row_with_selected_interior_source = draw_bordered_row_with_selected_interior
ASSERT draw_or_configure_secondary_dynamic_object_source = draw_or_configure_secondary_dynamic_object
ASSERT draw_and_configure_dynamic_room_object_source = draw_and_configure_dynamic_room_object
ASSERT select_blank_or_right_half_pattern_by_column_source = select_blank_or_right_half_pattern_by_column
ASSERT draw_centered_alternating_run_by_column_source = draw_centered_alternating_run_by_column
ASSERT set_ff_state_and_draw_last_column_special_row_source = set_ff_state_and_draw_last_column_special_row
ASSERT draw_fixed_pair_gap_and_bordered_rows_source_end = &19AA
COPYBLOCK draw_fixed_pair_gap_and_bordered_rows_source, draw_fixed_pair_gap_and_bordered_rows_source_end, &30B2

; Runtime $18B2-$19A9 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $30B2-$31A9.
CLEAR draw_fixed_pair_gap_and_bordered_rows_source, draw_fixed_pair_gap_and_bordered_rows_source_end


ORG write_indexed_terminal_activation_value

; Select a three-byte record with X = $90 * 3. The first
; two bytes are a little-endian destination pointer and the third is stored
; through it. The accepted-password path calls this with its current reference.
.write_indexed_terminal_activation_value_source
    LDA reference_pair_primary_value
    CLC
    ASL A
    ADC reference_pair_primary_value
    TAX
    LDA terminal_activation_records,X
    STA indirect_write_pointer_low
    LDA terminal_activation_records+1,X
    STA indirect_write_pointer_high
    LDY #&00
    LDA terminal_activation_records+2,X
    STA (indirect_write_pointer_low),Y
    RTS
.write_indexed_terminal_activation_value_source_end

ASSERT write_indexed_terminal_activation_value_source = write_indexed_terminal_activation_value
ASSERT write_indexed_terminal_activation_value_source_end = &322D
COPYBLOCK write_indexed_terminal_activation_value_source, write_indexed_terminal_activation_value_source_end, &4A14

; Runtime $3214-$322C overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4A14-$4A2C.
CLEAR write_indexed_terminal_activation_value_source, write_indexed_terminal_activation_value_source_end


ORG restore_item_and_goal_records

; Restore all twelve four-byte item/goal records from the
; initial image at $0980, then supply $59 to stamp_map_bytes_and_store by tail
; call. The natural startup call copies exactly 48 bytes and returns directly
; from the tail target to the caller at $0BCE. The padding NOP at $3255 is not
; part of this bounded routine and remains in an untouched binary slice.
.restore_item_and_goal_records_source
    LDX #&2F

.copy_next_initial_item_goal_byte
    LDA initial_item_and_goal_record_table,X
    STA item_and_goal_record_table,X
    DEX
    BPL copy_next_initial_item_goal_byte
    LDA #&59
    JMP stamp_map_bytes_and_store
.restore_item_and_goal_records_source_end

ASSERT restore_item_and_goal_records_source = restore_item_and_goal_records
ASSERT restore_item_and_goal_records_source_end = &3255
COPYBLOCK restore_item_and_goal_records_source, restore_item_and_goal_records_source_end, &4A45

; Runtime $3245-$3254 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4A45-$4A54; loaded $4A55 remains untouched.
CLEAR restore_item_and_goal_records_source, restore_item_and_goal_records_source_end


ORG print_inline_vdu_stream

; Consume the JSR return address as a little-endian pointer
; to the inline VDU stream. Each nonzero byte following the call is sent to
; OSWRCH. On the terminator, restore Y and push the terminator's address so RTS
; resumes at the byte after it. The $17FD page-end checkpoint proves the pointer
; high-byte carry as well as the normal loop and stack-rewritten return.
.print_inline_vdu_stream_source
    PLA
    STA inline_vdu_stream_pointer_low
    PLA
    STA inline_vdu_stream_pointer_high
    TYA
    PHA

.print_next_inline_vdu_byte
    LDY #&00
    LDA (inline_vdu_stream_pointer_low),Y
    BEQ finish_inline_vdu_stream
    INY
    LDA (inline_vdu_stream_pointer_low),Y
    BEQ advance_inline_vdu_pointer
    JSR OSWRCH

.advance_inline_vdu_pointer
    INC inline_vdu_stream_pointer_low
    BNE print_next_inline_vdu_byte
    INC inline_vdu_stream_pointer_high
    JMP print_next_inline_vdu_byte

.finish_inline_vdu_stream
    PLA
    TAY
    LDA inline_vdu_stream_pointer_high
    PHA
    LDA inline_vdu_stream_pointer_low
    PHA
    RTS
.print_inline_vdu_stream_source_end

ASSERT print_inline_vdu_stream_source = print_inline_vdu_stream
ASSERT print_inline_vdu_stream_source_end = &327E
COPYBLOCK print_inline_vdu_stream_source, print_inline_vdu_stream_source_end, &4A56

; Runtime $3256-$327D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4A56-$4A7D.
CLEAR print_inline_vdu_stream_source, print_inline_vdu_stream_source_end


ORG configure_and_emit_dynamic_room_object_vdu_stream

; Pops the saved room column and returns through the shared
; cell-handler RTS unless it is column seven. Column seven patches the dynamic
; room-object VDU stream from the active tile pair and named graphics coordinates,
; reverses its signed step when the cell is mirrored, converts the coordinate
; to VDU units, then emits the complete stream through OSWRCH.
.configure_and_emit_dynamic_room_object_vdu_stream_source
    PLA
    CMP #&07
    BNE dynamic_room_object_wrong_column_return
    LDA #&01
    STA dynamic_object_vdu_vertical_step_high
    LDA #&4B
    STA active_tile_pair_first
    CLC
    LDA active_tile_pair_first
    NOP
    NOP
    NOP
    STA dynamic_object_vdu_gcol_action
    LDA room_graphics_x_high
    STA dynamic_object_vdu_first_plot_x_high
    LDA room_graphics_y_low
    STA dynamic_object_vdu_first_plot_y_low
    LDA #&00
    STA dynamic_object_vdu_first_plot_y_high
    LDA room_cell_mirror_state
    BPL convert_dynamic_object_coordinate_to_vdu_units
    SEC
    LDA #&00
    SBC dynamic_object_vdu_vertical_step_high
    STA dynamic_object_vdu_vertical_step_high
    CLC
    LDA dynamic_object_vdu_vertical_step_high
    ASL A
    ASL A
    ASL A
    ADC dynamic_object_vdu_first_plot_y_low
    SEC
    SBC #&02
    STA dynamic_object_vdu_first_plot_y_low

.convert_dynamic_object_coordinate_to_vdu_units
    LDX #&04

.shift_dynamic_object_coordinate
    ASL dynamic_object_vdu_first_plot_y_low
    ROL dynamic_object_vdu_first_plot_y_high
    DEX
    BPL shift_dynamic_object_coordinate
    SEC
    LDA #&E0
    SBC dynamic_object_vdu_first_plot_y_low
    STA dynamic_object_vdu_first_plot_y_low
    LDA #&03
    SBC dynamic_object_vdu_first_plot_y_high
    STA dynamic_object_vdu_first_plot_y_high
    LDX #&00

.emit_next_dynamic_object_vdu_byte
    LDA dynamic_room_object_vdu_stream,X
    JSR OSWRCH
    INX
    CPX #&15
    BNE emit_next_dynamic_object_vdu_byte
    RTS
.configure_and_emit_dynamic_room_object_vdu_stream_source_end

ASSERT configure_and_emit_dynamic_room_object_vdu_stream_source = configure_and_emit_dynamic_room_object_vdu_stream
ASSERT configure_and_emit_dynamic_room_object_vdu_stream_source_end = &1A57
COPYBLOCK configure_and_emit_dynamic_room_object_vdu_stream_source, configure_and_emit_dynamic_room_object_vdu_stream_source_end, &31E8

; Runtime $19E8-$1A56 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $31E8-$3256.
CLEAR configure_and_emit_dynamic_room_object_vdu_stream_source, configure_and_emit_dynamic_room_object_vdu_stream_source_end


ORG dynamic_room_object_vdu_stream

; A complete MOS VDU command stream: GCOL followed by
; three PLOT commands. configure_and_emit_dynamic_room_object_vdu_stream
; patches the GCOL action, the first absolute PLOT coordinates and the signed
; high byte of the final relative vertical displacement before sending all 21
; bytes through OSWRCH. The untouched operands are explicit source constants.
.dynamic_room_object_vdu_stream_source
    EQUB VDU_GRAPHICS_COLOUR
.dynamic_object_vdu_gcol_action_source
    EQUB &00, &03
    EQUB VDU_PLOT, &04, &00
.dynamic_object_vdu_first_plot_x_high_source
    EQUB &00
.dynamic_object_vdu_first_plot_y_low_source
    EQUB &00
.dynamic_object_vdu_first_plot_y_high_source
    EQUB &00
    EQUB VDU_PLOT, &01, &00, &01, &00, &00
    EQUB VDU_PLOT, &51, &80, &FF, &00
.dynamic_object_vdu_vertical_step_high_source
    EQUB &00
.dynamic_room_object_vdu_stream_source_end

ASSERT dynamic_room_object_vdu_stream_source = dynamic_room_object_vdu_stream
ASSERT dynamic_object_vdu_gcol_action_source = dynamic_object_vdu_gcol_action
ASSERT dynamic_object_vdu_first_plot_x_high_source = dynamic_object_vdu_first_plot_x_high
ASSERT dynamic_object_vdu_first_plot_y_low_source = dynamic_object_vdu_first_plot_y_low
ASSERT dynamic_object_vdu_first_plot_y_high_source = dynamic_object_vdu_first_plot_y_high
ASSERT dynamic_object_vdu_vertical_step_high_source = dynamic_object_vdu_vertical_step_high
ASSERT dynamic_room_object_vdu_stream_source_end = draw_table_selected_sequence_in_columns_five_to_seven
COPYBLOCK dynamic_room_object_vdu_stream_source, dynamic_room_object_vdu_stream_source_end, &3257

; Runtime $1A57-$1A6B overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3257-$326B.
CLEAR dynamic_room_object_vdu_stream_source, dynamic_room_object_vdu_stream_source_end


ORG stamp_map_bytes_and_store

; Store the accumulator at $37FE, then write $69 into three
; fixed addresses at $09D3, $09E2 and $09E8.
; The three destinations are not contiguous and are outside the record tables
; that begin at $0900, so this stamps three specific map or state bytes rather
; than filling a range. What $69 means at those addresses is not established by
; this routine alone.
.stamp_map_bytes_and_store_source
    STA room_B0_row_1_cell_1
    LDA #&69
    STA room_D4_appearance
    STA room_C6_appearance
    STA room_A7_appearance
    RTS
.stamp_map_bytes_and_store_source_end

ASSERT stamp_map_bytes_and_store_source = stamp_map_bytes_and_store
ASSERT stamp_map_bytes_and_store_source_end = &328F
COPYBLOCK stamp_map_bytes_and_store_source, stamp_map_bytes_and_store_source_end, &4A80

; Runtime $3280-$328E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4A80-$4A8E.
CLEAR stamp_map_bytes_and_store_source, stamp_map_bytes_and_store_source_end


ORG dispatch_completed_crystal_message

; Completed-game main-loop exit helper. It chooses decoder
; offset zero normally or $36 when the sequence counter is zero. If crystals
; remain, the exact original PLA/RTS exit is retained; if none remain it
; tail-jumps to the transient stack-page XOR/OSWRCH decoder at $0100.
; Focused traces prove both zero-crystal message offsets. A contradictory
; nonzero-crystal checkpoint proves the PLA/RTS path does not return normally:
; it discards part of the JSR return and transfers to $3F26. Legitimate play
; reaches this helper only after the count is zero.
.dispatch_completed_crystal_message_source
    LDX #&00
    LDA main_loop_sequence_counter
    BNE completed_crystal_message_offset_selected
    LDX #&36

.completed_crystal_message_offset_selected
    LDA power_crystals_remaining
    BEQ emit_completed_crystal_message
    PLA
    RTS

.emit_completed_crystal_message
    JMP transient_xor_message_decoder
.dispatch_completed_crystal_message_source_end

ASSERT dispatch_completed_crystal_message_source = dispatch_completed_crystal_message
ASSERT dispatch_completed_crystal_message_source_end = &32A0
COPYBLOCK dispatch_completed_crystal_message_source, dispatch_completed_crystal_message_source_end, &4A8F
CLEAR dispatch_completed_crystal_message_source, dispatch_completed_crystal_message_source_end


ORG draw_table_selected_sequence_in_columns_five_to_seven

; ROOM_CELL_COLUMNS_5_TO_7_SEQUENCE draws blanks in columns zero through four.
; Columns five through seven convert the column to sequence
; index zero through two, draw two blanks, draw four graphic records selected
; from right_columns_four_tile_graphic_sequences, then draw two final blanks.
.draw_table_selected_sequence_in_columns_five_to_seven_source
    CMP #RIGHT_COLUMNS_SEQUENCE_FIRST_COLUMN
    BPL draw_right_columns_selected_middle_sequence
    JMP draw_eight_blank_tiles

.draw_right_columns_selected_middle_sequence
    SEC
    SBC #RIGHT_COLUMNS_SEQUENCE_FIRST_COLUMN
    STA right_columns_sequence_index
    STA room_update_suppression_state
    LDX #RIGHT_COLUMNS_SEQUENCE_EDGE_BLANK_TILES
    JSR draw_blank_tile_run
    LDA #LO(right_columns_four_tile_graphic_sequences)
    STA graphic_sequence_pointer_low
    LDA #HI(right_columns_four_tile_graphic_sequences)
    STA graphic_sequence_pointer_high
    JSR draw_four_graphic_selectors_from_pointer
    LDX #RIGHT_COLUMNS_SEQUENCE_EDGE_BLANK_TILES
    JMP draw_blank_tile_run
.draw_table_selected_sequence_in_columns_five_to_seven_source_end

ASSERT draw_table_selected_sequence_in_columns_five_to_seven_source = draw_table_selected_sequence_in_columns_five_to_seven
ASSERT draw_table_selected_sequence_in_columns_five_to_seven_source_end = right_columns_four_tile_graphic_sequences
COPYBLOCK draw_table_selected_sequence_in_columns_five_to_seven_source, draw_table_selected_sequence_in_columns_five_to_seven_source_end, &326C

; Runtime $1A6C-$1A8E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $326C-$328E.
CLEAR draw_table_selected_sequence_in_columns_five_to_seven_source, draw_table_selected_sequence_in_columns_five_to_seven_source_end


ORG right_columns_four_tile_graphic_sequences

; Three four-selector graphic sequences selected by room column minus
; RIGHT_COLUMNS_SEQUENCE_FIRST_COLUMN.
.right_columns_four_tile_graphic_sequences_source
    EQUB &00, &1C, &06, &00 ; column five
    EQUB &00, &5C, &46, &00 ; column six
    EQUB &5D, &24, &24, &5D ; column seven
.right_columns_four_tile_graphic_sequences_source_end

ASSERT right_columns_four_tile_graphic_sequences_source = right_columns_four_tile_graphic_sequences
ASSERT right_columns_four_tile_graphic_sequences_source_end = draw_transition_row_by_column
COPYBLOCK right_columns_four_tile_graphic_sequences_source, right_columns_four_tile_graphic_sequences_source_end, &328F

; Runtime $1A8F-$1A9A overlaps the loaded transport image. Release it after
; copying its bytes to loaded $328F-$329A.
CLEAR right_columns_four_tile_graphic_sequences_source, right_columns_four_tile_graphic_sequences_source_end


ORG draw_transition_row_by_column

; ROOM_CELL_TRANSITION_3C saves the cell/display reference in column zero.
; Columns zero and one draw blanks; columns two and three
; draw four blanks followed by a four-selector sequence from
; middle_columns_transition_graphic_sequences; columns four through seven draw
; alternating tiles. The dispatch-table entry proves this runtime-only entry;
; only its shared alternating tail has appeared in committed natural traces.
.draw_transition_row_by_column_source
    CMP #ROOM_COLUMN_FIRST
    BNE select_transition_column_layout
    JSR save_display_pointer_and_cell_reference
    LDA #ROOM_COLUMN_FIRST

.select_transition_column_layout
    CMP #TRANSITION_ALTERNATING_FIRST_COLUMN
    BMI select_transition_blank_or_sequence
.draw_transition_alternating_row
    JMP draw_eight_alternating_tiles

.select_transition_blank_or_sequence
    CMP #TRANSITION_SEQUENCE_FIRST_COLUMN
    BPL draw_transition_table_sequence
    JMP draw_eight_blank_tiles

.draw_transition_table_sequence
    LDX #FOUR_TILE_SEQUENCE_SELECTOR_COUNT
    JSR draw_blank_tile_run
    LDA #LO(middle_columns_transition_graphic_sequences)
    STA graphic_sequence_pointer_low
    LDA #HI(middle_columns_transition_graphic_sequences)
    STA graphic_sequence_pointer_high
    DEC room_graphics_column
    DEC room_graphics_column
    LDX #FOUR_TILE_SEQUENCE_SELECTOR_COUNT
    LDY #FOUR_TILE_SEQUENCE_INDEX_SHIFTS
    JMP draw_graphic_selector_sequence
.draw_transition_row_by_column_source_end

ASSERT draw_transition_row_by_column_source = draw_transition_row_by_column
ASSERT draw_transition_row_by_column_source_end = middle_columns_transition_graphic_sequences
COPYBLOCK draw_transition_row_by_column_source, draw_transition_row_by_column_source_end, &329B

; Runtime $1A9B-$1AC9 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $329B-$32C9.
CLEAR draw_transition_row_by_column_source, draw_transition_row_by_column_source_end


ORG xor_graphic_into_display

; A supplies the destination low byte; display_pointer_high supplies its high
; byte. For each requested character row, XOR four source bytes spaced one
; Mode 1 cell column apart on each of eight scanlines. The interleaved display
; pointer advances one byte between scanlines and one character row at an edge.
; xor_graphic_repeat_source_scanlines can repeat each source scanline twice.
; Without repetition, eight INCs consume one source byte per scanline. The
; final scanline comparison leaves carry set, so the subsequent source-pointer
; ADC adds $19 to the consumed $08: the next source row begins $21 bytes later.
.xor_graphic_into_display_source
    STA display_pointer_low
    TYA
    PHA
    TXA
    PHA

.xor_graphic_next_character_row
    LDA #MODE1_CHARACTER_SCANLINE_COUNT
    STA xor_graphic_scanlines_remaining
.xor_graphic_next_display_scanline
    LDY #XOR_GRAPHIC_SCANLINE_FIRST_OFFSET
    JSR test_display_pointer_in_xor_draw_window
    BCS xor_graphic_skip_clipped_scanline

.xor_graphic_four_byte_scanline_loop
    LDA (graphic_source_pointer_low),Y
    EOR (display_pointer_low),Y
    STA (display_pointer_low),Y
    TYA
    ADC #MODE1_CELL_COLUMN_BYTES
    TAY
    CMP #XOR_GRAPHIC_SCANLINE_SPAN_BYTES
    BNE xor_graphic_four_byte_scanline_loop

.xor_graphic_skip_clipped_scanline
    LDA xor_graphic_repeat_source_scanlines
    BEQ xor_graphic_advance_source_scanline
    LDA xor_graphic_scanlines_remaining
    ROR A
    BCC xor_graphic_source_scanline_ready
.xor_graphic_advance_source_scanline
    INC graphic_source_pointer_low

.xor_graphic_source_scanline_ready
    LDA display_pointer_low
    AND #MODE1_SCANLINE_INDEX_MASK
    CMP #MODE1_CHARACTER_LAST_SCANLINE
    BPL xor_graphic_advance_display_character_row
    INC display_pointer_low
.xor_graphic_display_scanline_ready
    DEC xor_graphic_scanlines_remaining
    BNE xor_graphic_next_display_scanline

    DEC xor_graphic_character_rows_remaining
    BEQ xor_graphic_restore_registers
    LDA xor_graphic_repeat_source_scanlines
    BNE xor_graphic_next_character_row

    LDA graphic_source_pointer_low
    ADC #XOR_GRAPHIC_NEXT_SOURCE_ROW_LOW_ADJUST ; carry is intentionally still set
    STA graphic_source_pointer_low
    BCC xor_graphic_next_character_row
    INC graphic_source_pointer_high
    JMP xor_graphic_next_character_row

.xor_graphic_restore_registers
    PLA
    TAX
    PLA
    TAY
    RTS

.xor_graphic_advance_display_character_row
    CLC
    LDA display_pointer_low
    ADC #MODE1_NEXT_CHARACTER_ROW_LOW_ADJUST
    STA display_pointer_low
    LDA display_pointer_high
    ADC #MODE1_NEXT_CHARACTER_ROW_HIGH_ADJUST
    STA display_pointer_high
    JMP xor_graphic_display_scanline_ready
.xor_graphic_into_display_source_end

ASSERT xor_graphic_into_display_source = xor_graphic_into_display
ASSERT xor_graphic_into_display_source_end = &3333
COPYBLOCK xor_graphic_into_display_source, xor_graphic_into_display_source_end, &4AD1

; Runtime $32D1-$3332 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4AD1-$4B32.
CLEAR xor_graphic_into_display_source, xor_graphic_into_display_source_end


ORG middle_columns_transition_graphic_sequences

; Two four-selector transition sequences selected by room column minus
; TRANSITION_SEQUENCE_FIRST_COLUMN.
.middle_columns_transition_graphic_sequences_source
    EQUB &1B, &1A, &0C, &00 ; column two
    EQUB &5B, &20, &0D, &00 ; column three
.middle_columns_transition_graphic_sequences_source_end

ASSERT middle_columns_transition_graphic_sequences_source = middle_columns_transition_graphic_sequences
ASSERT middle_columns_transition_graphic_sequences_source_end = draw_table_selected_eight_tiles_in_columns_four_five
COPYBLOCK middle_columns_transition_graphic_sequences_source, middle_columns_transition_graphic_sequences_source_end, &32CA

; Runtime $1ACA-$1AD1 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $32CA-$32D1.
CLEAR middle_columns_transition_graphic_sequences_source, middle_columns_transition_graphic_sequences_source_end

ORG draw_pillar_framed_or_pattern_row

; room-cell type $01. Column zero draws selector $02, six mirrored selector-$27 pillar tiles and selector $01. Column one draws the fixed tile pair four times; columns two through seven draw alternating tiles.
.draw_pillar_framed_or_pattern_row_source
    CMP #&00
    BEQ draw_pillar_framed_first_column
    CMP #&01
    BEQ draw_fixed_pair_second_column
    JMP draw_eight_alternating_tiles

.draw_pillar_framed_first_column
    LDA #GRAPHIC_ROUNDED_PATTERN_B
    JSR copy_16_byte_graphic_to_display
    LDX #&06

.draw_next_pillar_middle_tile
    LDA #GRAPHIC_PILLAR_BASE
    JSR apply_mirror_flag_then_copy_graphic
    DEX
    BNE draw_next_pillar_middle_tile
    LDA #GRAPHIC_ROUNDED_PATTERN_A
    JMP copy_16_byte_graphic_to_display

.draw_fixed_pair_second_column
    JMP draw_fixed_pair_tile_run
.draw_pillar_framed_or_pattern_row_source_end

ASSERT draw_pillar_framed_or_pattern_row_source = draw_pillar_framed_or_pattern_row
ASSERT draw_pillar_framed_or_pattern_row_source_end = &1B23
COPYBLOCK draw_pillar_framed_or_pattern_row_source, draw_pillar_framed_or_pattern_row_source_end, &3301

; Runtime $1B01-$1B22 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3301-$3322.
CLEAR draw_pillar_framed_or_pattern_row_source, draw_pillar_framed_or_pattern_row_source_end


ORG draw_table_selected_eight_tiles_in_columns_four_five

; ROOM_CELL_COLUMNS_4_5_SEQUENCE draws blanks in columns zero through three.
; Columns four and five select one of two eight-selector records from
; middle_columns_eight_tile_graphic_sequences; columns six and seven share the
; transition cell's alternating-row tail.
.draw_table_selected_eight_tiles_in_columns_four_five_source
    CMP #MIDDLE_EIGHT_TILE_FIRST_COLUMN
    BPL select_eight_tile_middle_or_right_columns
    JMP draw_eight_blank_tiles

.select_eight_tile_middle_or_right_columns
    CMP #MIDDLE_EIGHT_TILE_END_COLUMN
    BPL draw_transition_alternating_row
    SEC
    SBC #MIDDLE_EIGHT_TILE_FIRST_COLUMN
    STA room_graphics_column
    LDA #LO(middle_columns_eight_tile_graphic_sequences)
    STA graphic_sequence_pointer_low
    LDA #HI(middle_columns_eight_tile_graphic_sequences)
    STA graphic_sequence_pointer_high
    LDX #ROOM_CELL_TILE_COUNT
    LDY #EIGHT_TILE_SEQUENCE_INDEX_SHIFTS
    JMP draw_graphic_selector_sequence
.draw_table_selected_eight_tiles_in_columns_four_five_source_end

ASSERT draw_table_selected_eight_tiles_in_columns_four_five_source = draw_table_selected_eight_tiles_in_columns_four_five
ASSERT draw_table_selected_eight_tiles_in_columns_four_five_source_end = middle_columns_eight_tile_graphic_sequences
COPYBLOCK draw_table_selected_eight_tiles_in_columns_four_five_source, draw_table_selected_eight_tiles_in_columns_four_five_source_end, &32D2

; Runtime $1AD2-$1AF0 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $32D2-$32F0.
CLEAR draw_table_selected_eight_tiles_in_columns_four_five_source, draw_table_selected_eight_tiles_in_columns_four_five_source_end


ORG middle_columns_eight_tile_graphic_sequences

; Two eight-selector rows selected by room column minus
; MIDDLE_EIGHT_TILE_FIRST_COLUMN.
.middle_columns_eight_tile_graphic_sequences_source
    EQUB &00, &45, &5D, &1D, &16, &1D, &5D, &05 ; column four
    EQUB &00, &00, &24, &00, &16, &00, &24, &00 ; column five
.middle_columns_eight_tile_graphic_sequences_source_end

ASSERT middle_columns_eight_tile_graphic_sequences_source = middle_columns_eight_tile_graphic_sequences
ASSERT middle_columns_eight_tile_graphic_sequences_source_end = draw_pillar_framed_or_pattern_row
COPYBLOCK middle_columns_eight_tile_graphic_sequences_source, middle_columns_eight_tile_graphic_sequences_source_end, &32F1

; Runtime $1AF1-$1B00 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $32F1-$3300.
CLEAR middle_columns_eight_tile_graphic_sequences_source, middle_columns_eight_tile_graphic_sequences_source_end


ORG play_sound_with_amplitude

; Play a sound on channel 2 with the amplitude in A.
; $32A0 to $32A7 is an OSWORD $07 SOUND parameter block: channel, amplitude,
; pitch and duration as four little-endian words. This writes A as the amplitude
; low byte with a zero high byte, sets the channel word low byte to $12, which
; is flush plus channel 2, and jumps into the submission routine at $3363.
; Pitch and duration are not written here; callers preset them before calling,
; which is why several routines store to $32A4 and $32A6 immediately beforehand.
.play_sound_with_amplitude_source
    STA sound_block_amplitude
    LDA #&00
    STA sound_block_amplitude_high
    LDA #&12
    STA sound_block_channel
    JMP submit_sound_block
.play_sound_with_amplitude_source_end

ASSERT play_sound_with_amplitude_source = play_sound_with_amplitude
ASSERT play_sound_with_amplitude_source_end = &3343
COPYBLOCK play_sound_with_amplitude_source, play_sound_with_amplitude_source_end, &4B33

; Runtime $3333-$3342 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4B33-$4B42.
CLEAR play_sound_with_amplitude_source, play_sound_with_amplitude_source_end


ORG configure_two_row_repeated_xor_graphic

; Configure the adjacent XOR renderer to draw two
; eight-scanline character rows while repeating each source scanline twice.
; A returns $02; X, Y, and all flags except N/Z are unchanged. The routine
; does not touch the stack before its normal RTS.
.configure_two_row_repeated_xor_graphic_source
    LDA #&01
    STA xor_graphic_repeat_source_scanlines
    LDA #&02
    STA xor_graphic_character_rows_remaining
    RTS
.configure_two_row_repeated_xor_graphic_source_end

ASSERT configure_two_row_repeated_xor_graphic_source = configure_two_row_repeated_xor_graphic
ASSERT configure_two_row_repeated_xor_graphic_source_end = &334C
COPYBLOCK configure_two_row_repeated_xor_graphic_source, configure_two_row_repeated_xor_graphic_source_end, &4B43

; Runtime $3343-$334B overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4B43-$4B4B.
CLEAR configure_two_row_repeated_xor_graphic_source, configure_two_row_repeated_xor_graphic_source_end

ORG submit_sound_block_with_pitch

; Play a sound with the pitch in A, or submit an
; already-filled block.
; The $334C entry writes A as the pitch and fills the rest of the OSWORD $07
; block with fixed values: channel $10, which is flush plus channel 0, amplitude
; $FFF1, and duration 1. It then falls into the submission.
; The submission entry is also called directly by play_sound_with_amplitude,
; which fills the block differently first. A nonzero sound_disabled_flag
; abandons submission, so sound is silenced without changing callers. Otherwise
; A, X and Y are preserved around OSWORD SOUND with the block beginning at
; sound_block_channel.
.submit_sound_block_with_pitch_source
    STA sound_block_pitch
    LDA #&10
    STA sound_block_channel
    LDA #&FF
    STA sound_block_amplitude_high
    LDA #&F1
    STA sound_block_amplitude
    LDA #&01
    STA sound_block_duration

.submit_sound_block
    LDA sound_disabled_flag
    BNE configure_two_row_repeated_xor_graphic_rts
    PHA
    TXA
    PHA
    TYA
    PHA
    LDX #&A0
    LDY #&32
    LDA #OSWORD_SOUND
    JSR OSWORD
    PLA
    TAY
    PLA
    TAX
    PLA
    RTS
.submit_sound_block_with_pitch_source_end

ASSERT submit_sound_block_with_pitch_source = submit_sound_block_with_pitch
ASSERT submit_sound_block_with_pitch_source_end = &337B
COPYBLOCK submit_sound_block_with_pitch_source, submit_sound_block_with_pitch_source_end, &4B4C

; Runtime $334C-$337A overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4B4C-$4B7A.
CLEAR submit_sound_block_with_pitch_source, submit_sound_block_with_pitch_source_end


ORG draw_character_row_as_tiles

; Render one scanline row of a MOS character
; definition as eight tiles. The character code combines the cell's character
; bit and room_cell_type_index, then adds MOS_CHARACTER_CODE_BIAS before the
; OSWORD definition call fills character_definition_block with the eight rows.
; The room column selects the row, which is copied back over the
; block's first byte and shifted left eight times. A clear bit draws one blank
; tile and a set bit draws one alternating-pair tile, so text and patterned
; detail reach the display through the same tile pipeline as the room itself.
; Reached only by the tail JMP at $12AE.
.draw_character_row_as_tiles_source
    LDA current_room_cell
    AND #ROOM_CELL_MIRROR_FLAG
    CLC
    ADC room_cell_type_index
    ADC #MOS_CHARACTER_CODE_BIAS
    STA character_definition_block
    LDX #LO(character_definition_block)
    LDY #HI(character_definition_block)
    LDA #OSWORD_DEFINE_CHARACTER
    JSR OSWORD
    LDX room_graphics_column
    INX
    LDA character_definition_block,X
    STA character_definition_block
    LDY #&08

.shift_next_character_bit
    LDX #&01
    ASL character_definition_block
    BCS draw_set_character_bit
    JSR draw_blank_tile_run
    JMP finish_character_bit

.draw_set_character_bit
    JSR draw_alternating_tile_run

.finish_character_bit
    DEY
    BNE shift_next_character_bit
    RTS
.draw_character_row_as_tiles_source_end

ASSERT draw_character_row_as_tiles_source = draw_character_row_as_tiles
ASSERT draw_character_row_as_tiles_source_end = &1B58
COPYBLOCK draw_character_row_as_tiles_source, draw_character_row_as_tiles_source_end, &3323

; Runtime $1B23-$1B57 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3323-$3357.
CLEAR draw_character_row_as_tiles_source, draw_character_row_as_tiles_source_end


ORG reverse_room_moving_object_delta_at_limits

; Keep the selected room-moving-object graphic state moving between the
; inclusive selector limits. A lower-limit match selects the positive movement
; step; an upper-limit match selects the negative step; an interior value leaves the delta
; unchanged. X and Y are preserved.
.reverse_room_moving_object_delta_at_limits_source
    LDA room_moving_object_graphic_selector_state,Y
    CMP room_moving_object_graphic_selector_lower_limit
    BEQ room_moving_object_select_positive_delta
    CMP room_moving_object_graphic_selector_upper_limit
    BEQ room_moving_object_select_negative_delta
    RTS

.room_moving_object_select_positive_delta
    LDA #ROOM_MOVING_OBJECT_STEP_POSITIVE
.room_moving_object_store_reversed_delta
    STA room_moving_object_graphic_selector_delta,Y
    RTS

.room_moving_object_select_negative_delta
    LDA #ROOM_MOVING_OBJECT_STEP_NEGATIVE
    JMP room_moving_object_store_reversed_delta
.reverse_room_moving_object_delta_at_limits_source_end

ASSERT reverse_room_moving_object_delta_at_limits_source = reverse_room_moving_object_delta_at_limits
ASSERT reverse_room_moving_object_delta_at_limits_source_end = &3453
COPYBLOCK reverse_room_moving_object_delta_at_limits_source, reverse_room_moving_object_delta_at_limits_source_end, &4C3A

; Runtime $343A-$3452 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4C3A-$4C52.
CLEAR reverse_room_moving_object_delta_at_limits_source, reverse_room_moving_object_delta_at_limits_source_end

ORG play_note_for_position_and_test_tune

; Play the note for wherever the player is standing, then
; judge whether the tune is being played correctly.
; The player horizontal position less $0E and divided by four selects a note
; from the pitch table at $0BC0, which is submitted on channel with amplitude
; $11. The note just played is then compared against the expected one at
; $0B53 indexed by the progress counter $32BF.
; A match advances the progress. Reaching twelve completes the tune: $0C is
; stored in the flag at $1242 and, only when the primary reference is 4, $2D is
; written to $385D.
; A mismatch does not reset immediately. The previous expected note is tested
; first, and if the player is still on it the progress is left alone, which is
; what lets a note be held without breaking the sequence; only a note that is
; neither the next nor the current one resets the count to zero.
;
; The tune itself is legible from the two tables. BBC pitch runs four units to
; a semitone, and the first five entries of $0BC0 are $34, $3C, $44, $48 and
; $50: intervals of two, two, one and two semitones, which is the first five
; degrees of a major scale. The twelve expected notes at $0B53 are $44 $3C $34
; three times over in two pairs, so in scale degrees the sequence is
; 3-2-1, 3-2-1, 5-4-3, 5-4-3.
.play_note_for_position_and_test_tune_source
    SEC
    LDA player_horizontal_position
    SBC #&0E
    LSR A
    LSR A
    TAY
    LDA music_note_pitch_table,Y
    STA sound_block_pitch
    LDA #&11
    JSR submit_osword_07_sound_block
    LDX music_tune_progress
    LDA music_tune_sequence,X
    CMP sound_block_pitch
    BNE test_note_still_held
    INC music_tune_progress
    LDA music_tune_progress
    CMP #MUSIC_TUNE_NOTE_COUNT
    BNE submit_sound_block_rts
    STA timed_effect_selector
    LDA reference_pair_primary_value
    CMP #&04
    BNE submit_sound_block_rts
    LDA #&2D
    STA room_E1_row_0_cell_1
    RTS

.test_note_still_held
    DEX
    LDA music_tune_sequence,X
    CMP sound_block_pitch
    BEQ submit_sound_block_rts
    LDA #&00
    STA music_tune_progress
    RTS
.play_note_for_position_and_test_tune_source_end

ASSERT play_note_for_position_and_test_tune_source = play_note_for_position_and_test_tune
ASSERT play_note_for_position_and_test_tune_source_end = &33C1
COPYBLOCK play_note_for_position_and_test_tune_source, play_note_for_position_and_test_tune_source_end, &4B7B

; Runtime $337B-$33C0 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4B7B-$4BC0.
CLEAR play_note_for_position_and_test_tune_source, play_note_for_position_and_test_tune_source_end


ORG update_and_draw_room_moving_objects

; Update the room's active caterpillar, fish, mouse or
; lift graphics. Each instance occupies an even Y index because its display pointer is a two-byte
; zero-page entry. When erase_previous_xor_sprite_flag is nonzero the old image
; is XOR-erased first; the
; selector is then reflected at its configured limits, advanced together with
; its display pointer, and drawn in the new position.
;
; Caterpillars and lifts bypass the candidate/item path. A caterpillar also
; submits the moved graphic to the player-bounds test as an $12-high candidate.
; For the other types, $2203 tests the selector/state-derived candidate. The
; carry-set path was not reached in committed play, but its exact static code
; records the candidate delta and accepts item $30 for a fish or item $38 for
; a mouse; if neither carried slot has that item it substitutes the
; scratch value in $33. Every observed $2203 call returns carry clear.
.update_and_draw_room_moving_objects_source
    LDY #&00

.room_moving_object_update_loop
    LDA erase_previous_xor_sprite_flag
    BEQ room_moving_object_old_image_removed
    JSR draw_room_moving_object

.room_moving_object_old_image_removed
    LDA current_room_cell
    BEQ advance_room_moving_object_graphic
    CMP #ROOM_MOVING_OBJECT_LIFT
    BEQ advance_room_moving_object_graphic
    SEC
    LDA room_moving_object_graphic_selector_state,Y
    SBC #ROOM_MOVING_OBJECT_CANDIDATE_POSITION_BIAS
    STA candidate_horizontal_position
    LDA room_moving_object_graphic_state
    ASL A
    ASL A
    STA candidate_half_vertical_position
    JSR enter_test_player_in_range_and_set_direction
    BCC advance_room_moving_object_graphic

    ; Static-only carry-set path: retain the candidate delta when the required
    ; item is carried, otherwise replace it with the helper's scratch result.
    LDA candidate_horizontal_step
    STA room_moving_object_graphic_selector_delta,Y
    LDA current_room_cell
    CMP #ROOM_MOVING_OBJECT_FISH
    BNE room_moving_object_require_item_38
    LDA #ITEM_CODE_WORM
    JMP room_moving_object_test_required_item

.room_moving_object_require_item_38
    LDA #ITEM_CODE_CHEESE
    JMP room_moving_object_test_required_item

.advance_room_moving_object_graphic
    JSR reverse_room_moving_object_delta_at_limits
    JSR advance_room_moving_object_state_and_pointer
    JSR draw_room_moving_object
    LDA current_room_cell
    BNE room_moving_object_next_instance
    LDA room_moving_object_graphic_selector_state,Y
    STA candidate_horizontal_position
    LDA room_moving_object_graphic_state
    ASL A
    ASL A
    STA candidate_half_vertical_position
    LDA #ROOM_MOVING_OBJECT_CATERPILLAR_COLLISION_EXTENT
    STA xor_graphic_character_rows_remaining
    JSR enter_player_candidate_bounds_overlap

.room_moving_object_next_instance
    INY
    INY
    CPY room_moving_object_slot_limit
    BMI room_moving_object_update_loop
    LDA #&00
    STA xor_graphic_repeat_source_scanlines
    RTS

.room_moving_object_test_required_item
    CMP item_slot_first
    BEQ advance_room_moving_object_graphic
    CMP item_slot_second
    BEQ advance_room_moving_object_graphic
    LDA room_moving_object_missing_item_delta
    STA room_moving_object_graphic_selector_delta,Y
    JMP advance_room_moving_object_graphic
.update_and_draw_room_moving_objects_source_end

ASSERT update_and_draw_room_moving_objects_source = update_and_draw_room_moving_objects
ASSERT update_and_draw_room_moving_objects_source_end = reverse_room_moving_object_delta_at_limits
ASSERT room_moving_object_test_required_item = &342A
COPYBLOCK update_and_draw_room_moving_objects_source, update_and_draw_room_moving_objects_source_end, &4BC1

; Runtime $33C1-$3439 overlaps the loaded transport image. Release it after
; copying its source-built bytes to loaded $4BC1-$4C39.
CLEAR update_and_draw_room_moving_objects_source, update_and_draw_room_moving_objects_source_end


ORG initialise_four_dynamic_room_object_slots

; Called by the dynamic-room-object setup at $1943 with an even slot offset in Y. It preserves the display pointer, initialises four circular even-indexed slots with display addresses spaced $20 bytes apart and paired $FE/$00 state bytes at $18/$19, restores the pointer, then writes $FE to $1247.
.initialise_four_dynamic_room_object_slots_source
    LDX #&00
    LDA display_pointer_low
    PHA
    LDA display_pointer_high
    PHA

.initialise_next_dynamic_object_slot
    CLC
    LDA display_pointer_low
    STA moving_entity_display_pointer_low,Y
    ADC #&20
    STA display_pointer_low
    LDA display_pointer_high
    STA moving_entity_display_pointer_high,Y
    ADC #&00
    STA display_pointer_high
    LDA #&FE
    STA moving_entity_delta,Y
    LDA #&00
    STA moving_entity_position,Y
    INY
    INY
    CPY #&0A
    BMI advance_dynamic_object_slot
    DEY
    DEY
    DEY
    DEY

.advance_dynamic_object_slot
    INX
    CPX #&04
    BNE initialise_next_dynamic_object_slot
    PLA
    STA display_pointer_high
    PLA
    STA display_pointer_low
    LDA #&FE
    STA lift_or_hazard_upper_position
    RTS
.initialise_four_dynamic_room_object_slots_source_end

ASSERT initialise_four_dynamic_room_object_slots_source = initialise_four_dynamic_room_object_slots
ASSERT initialise_four_dynamic_room_object_slots_source_end = &1B98
COPYBLOCK initialise_four_dynamic_room_object_slots_source, initialise_four_dynamic_room_object_slots_source_end, &3358

; Runtime $1B58-$1B97 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3358-$3397.
CLEAR initialise_four_dynamic_room_object_slots_source, initialise_four_dynamic_room_object_slots_source_end


ORG draw_room_moving_object

; Y indexes selector inputs and a display pointer. X is
; built from whether the signed delta is $FF and whether selector-state bit 2
; is clear, giving the even graphic-table indices $00/$02/$04/$06. The common
; observed globals select the repeated-source/two-row setup; the bypass leaves
; the initial one-row count in place. The final jump tail-calls the proven
; graphic selector and XOR renderer.
.draw_room_moving_object_source
    LDA #ROOM_MOVING_OBJECT_DEFAULT_GRAPHIC_ROWS
    STA xor_graphic_character_rows_remaining
    LDX #&00
    LDA room_moving_object_graphic_selector_delta,Y
    CMP #ROOM_MOVING_OBJECT_STEP_NEGATIVE
    BNE room_moving_object_test_selector_state
    LDX #ROOM_MOVING_OBJECT_REVERSE_FRAME_OFFSET

.room_moving_object_test_selector_state
    LDA room_moving_object_graphic_selector_state,Y
    ROR A
    ROR A
    ROR A
    BCS room_moving_object_selector_ready
    INX
    INX
    INX
    INX

.room_moving_object_selector_ready
    LDA current_room_cell
    BNE room_moving_object_load_display_pointer
    LDA room_moving_object_slot_limit
    CMP #ROOM_MOVING_OBJECT_TWO_ROW_SLOT_LIMIT
    BPL room_moving_object_load_display_pointer
    JSR configure_two_row_repeated_xor_graphic

.room_moving_object_load_display_pointer
    LDA room_moving_object_display_pointer_high,Y
    STA display_pointer_high
    LDA room_moving_object_display_pointer_low,Y
    JMP select_graphic_then_xor_draw
.draw_room_moving_object_source_end

ASSERT draw_room_moving_object_source = draw_room_moving_object
ASSERT draw_room_moving_object_source_end = &3488
COPYBLOCK draw_room_moving_object_source, draw_room_moving_object_source_end, &4C53

; Runtime $3453-$3487 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4C53-$4C87.
CLEAR draw_room_moving_object_source, draw_room_moving_object_source_end

ORG draw_and_initialise_room

; Draw the current room and set up everything in it.
; The per-room state is cleared first: a dozen flags and counters, the music
; tune progress, the initial vertical velocity step, and the bounded tick target.
; Among those cleared flags is jet_boots_enabled_this_room, so every
; room begins with the jet boots disabled and a room has to grant them back.
; The triangle-symbol room-cell handler writes one into the flag while drawing,
; visibly marking rooms where flight is allowed. The
; control poller skips both thrust keys while the flag is zero, so in a room
; without the symbol the boots do nothing. The current level-map offset is
; copied into the room-cell level base; set_room_data_pointer combines it with
; the room column and backs up one row plane before drawing.
; The appearance byte is fetched for the room above and again for this one,
; which is what gives the top edge the neighbouring room colours. A secondary
; reference of zero has no room above, so that case fills the top row with
; blank tiles instead.
; The body is then drawn a row at a time through draw_room_row_cells,
; stepping the room pointer by ROOM_LEVEL_ROW_PLANE_BYTES, until
; room_graphics_y_low reaches ROOM_GRAPHICS_Y_FINAL_ROW. Records, enemies, and
; lifts/hazards are initialised from their
; three tables, the keyboard buffers are reset, and the player position and
; display pointer are snapshotted into the named walk-target and room-setup
; fields. Finally, levels below CROSS_ROOM_GHOST_FIRST_LEVEL initialise the
; per-level robot pair before the routine tail-jumps into the clock write.
.draw_and_initialise_room_source
    LDA #ROOM_ALTERNATE_PALETTE_ENABLED
    STA alternate_palette_selector
    LDA #LO(room_render_display_start)
    STA display_pointer_low
    LDA #HI(room_render_display_start)
    STA display_pointer_high
    LDA #ROOM_INITIAL_STATE_CLEAR
    STA lift_hazard_primary_updates_active
    STA lift_hazard_secondary_updates_active
    STA jet_boots_enabled_this_room
    STA room_moving_objects_active
    STA water_environment_flag
    STA room_tick_update_selector
    STA room_update_suppression_state
    STA timed_effect_selector
    STA erase_previous_xor_sprite_flag
    STA lift_and_hazard_active
    STA horizontal_band_velocity_effect_state
    STA room_interaction_code
    STA music_tune_progress
    LDA #ROOM_INITIAL_VERTICAL_VELOCITY_STEP
    STA vertical_velocity_step
    LDA #ROOM_INITIAL_TICK_TARGET
    STA bounded_tick_target_value
    LDA level_room_map_offset_low
    STA room_cell_level_base_low
    LDA level_room_map_offset_high
    STA room_cell_level_base_high
    LDA #ROOM_GRAPHICS_Y_BEFORE_FIRST_ROW
    STA room_graphics_y_low
    STA room_graphics_column
    JSR set_room_data_pointer
    LDA room_data_pointer_low
    SEC
    SBC #ROOM_LEVEL_ROW_PLANE_BYTES
    STA room_data_pointer_low
    LDA room_data_pointer_high
    SBC #HI(ROOM_LEVEL_ROW_PLANE_BYTES) ; propagate the low-byte subtraction's borrow
    STA room_data_pointer_high
    DEC reference_pair_secondary_value
    JSR load_room_palette_and_tile_pair
    INC reference_pair_secondary_value
    LDA reference_pair_secondary_value
    BNE draw_room_body
    JMP fill_top_row_when_no_room_above

.draw_room_body
    JSR draw_room_row_cells
    LDX #ROOM_TOP_EDGE_CLEAR_BYTE_COUNT
    LDA #LO(room_render_display_start)
    STA graphic_source_pointer_low
    LDA #HI(room_render_display_start)
    STA graphic_source_pointer_high

.scan_next_room_top_edge_cell
    LDY #ROOM_TOP_EDGE_SCAN_FIRST_OFFSET
    LDA (graphic_source_pointer_low),Y
    CMP #DISPLAY_MARKER_WATER
    BEQ preserve_room_top_edge_water_marker
    LDA #ROOM_TOP_EDGE_CLEAR_VALUE
    STA (graphic_source_pointer_low),Y
    INY
    STA (graphic_source_pointer_low),Y
    INY

.preserve_room_top_edge_water_marker
    JSR store_byte_and_advance_source_pointer
    BNE scan_next_room_top_edge_cell

.reload_appearance_for_this_room
    JSR load_room_palette_and_tile_pair

.start_next_room_row
    LDA #ROOM_COLUMN_FIRST
    STA room_graphics_column
    JSR advance_room_data_pointer_to_next_row_plane

.draw_next_row_cell
    INC room_graphics_y_low
    JSR draw_room_row_cells
    INC room_graphics_column
    LDA room_graphics_column
    CMP #ROOM_COLUMN_COUNT
    BNE draw_next_row_cell
    LDA room_graphics_y_low
    CMP #ROOM_GRAPHICS_Y_FINAL_ROW
    BNE start_next_room_row
    JSR draw_matching_records_from_table
    JSR initialise_room_moving_objects
    JSR initialise_room_enemy_from_table
    JSR initialise_lifts_and_hazards_from_table
    LDA #ROOM_ALTERNATE_PALETTE_DISABLED
    STA alternate_palette_selector
    LDX #ROOM_PALETTE_FLASH_PERIOD
    LDA #OSBYTE_SET_FLASH_MARK_PERIOD
    JSR OSBYTE
    LDA #OSBYTE_SET_FLASH_SPACE_PERIOD
    JSR OSBYTE
    LDA player_horizontal_position
    STA player_walk_target_horizontal_position
    LDA player_vertical_position
    STA player_walk_target_vertical_position
    LDA player_display_pointer_low
    STA room_setup_player_display_pointer_low
    LDA player_display_pointer_high
    STA room_setup_player_display_pointer_high
    LDA #OSBYTE_FLUSH_BUFFER
    LDX #OSBYTE_BUFFER_SOUND_CHANNEL_0
    JSR OSBYTE
    LDA #ROOM_INITIAL_STATE_CLEAR ; clear renderer, jump/swim, and vertical-transition state together
    STA xor_graphic_repeat_source_scanlines
    STA player_jump_or_swim_requested
    STA vertical_room_transition_cell_flag
    LDA reference_pair_secondary_value
    CMP #CROSS_ROOM_GHOST_FIRST_LEVEL
    BPL finish_room_setup
    JSR enter_initialise_cross_room_robot_ghost_from_record

.finish_room_setup
    JMP write_system_clock_via_osword_02

.fill_top_row_when_no_room_above
    LDX #ROOM_TOP_ROW_TILE_COUNT
    JSR draw_blank_tile_run
    JMP reload_appearance_for_this_room
.draw_and_initialise_room_source_end

ASSERT draw_and_initialise_room_source = draw_and_initialise_room
ASSERT draw_and_initialise_room_source_end = &1C87
COPYBLOCK draw_and_initialise_room_source, draw_and_initialise_room_source_end, &3398

; Runtime $1B98-$1C86 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3398-$3486.
CLEAR draw_and_initialise_room_source, draw_and_initialise_room_source_end


ORG advance_room_moving_object_state_and_pointer

; Add the Y-indexed signed delta to selector state, then
; move the paired display pointer by one Mode 1 byte column (eight bytes).
; Delta sign alone chooses +8 or -8. X and Y are preserved; A returns the
; updated display-pointer high byte.
.advance_room_moving_object_state_and_pointer_source
    LDA room_moving_object_graphic_selector_state,Y
    CLC
    ADC room_moving_object_graphic_selector_delta,Y
    STA room_moving_object_graphic_selector_state,Y
    LDA room_moving_object_graphic_selector_delta,Y
    BMI room_moving_object_move_display_pointer_left

    CLC
    LDA room_moving_object_display_pointer_low,Y
    ADC #MODE1_CELL_COLUMN_BYTES
    STA room_moving_object_display_pointer_low,Y
    LDA room_moving_object_display_pointer_high,Y
    ADC #&00
    STA room_moving_object_display_pointer_high,Y
    RTS

.room_moving_object_move_display_pointer_left
    SEC
    LDA room_moving_object_display_pointer_low,Y
    SBC #MODE1_CELL_COLUMN_BYTES
    STA room_moving_object_display_pointer_low,Y
    LDA room_moving_object_display_pointer_high,Y
    SBC #&00
    STA room_moving_object_display_pointer_high,Y
    RTS
.advance_room_moving_object_state_and_pointer_source_end

ASSERT advance_room_moving_object_state_and_pointer_source = advance_room_moving_object_state_and_pointer
ASSERT advance_room_moving_object_state_and_pointer_source_end = &34BB
COPYBLOCK advance_room_moving_object_state_and_pointer_source, advance_room_moving_object_state_and_pointer_source_end, &4C88

; Runtime $3488-$34BA overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4C88-$4CBA.
CLEAR advance_room_moving_object_state_and_pointer_source, advance_room_moving_object_state_and_pointer_source_end


ORG set_room_data_pointer

; Build the pointer to the current room cell data.
; The horizontal reference at $90 is multiplied by five and added to the level
; base in room_cell_level_base_low/high, then adds room_cell_map to form
; room_data_pointer_low/high. A room occupies five bytes and the saved level
; base selects its horizontal band. The level transitions maintain the source
; level_room_map_offset by one complete level stride in either direction.
; The RTS at $1CA8 is shared, running far more often than this body.
.set_room_data_pointer_source
    LDA reference_pair_primary_value
    ASL A
    ASL A
    ADC reference_pair_primary_value
    STA room_data_map_offset_low
    LDA room_cell_level_base_low
    ADC room_data_map_offset_low
    STA room_data_map_offset_low
    LDA room_cell_level_base_high
    ADC #&00
    STA room_data_map_offset_high
    LDA #LO(room_cell_map)
    CLC
    ADC room_data_map_offset_low
    STA room_data_pointer_low
    LDA #HI(room_cell_map)
    ADC room_data_map_offset_high
    STA room_data_pointer_high
    RTS
.set_room_data_pointer_source_end

ASSERT set_room_data_pointer_source = set_room_data_pointer
ASSERT set_room_data_pointer_source_end = &1CA9
COPYBLOCK set_room_data_pointer_source, set_room_data_pointer_source_end, &3487

; Runtime $1C87-$1CA8 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3487-$34A8.
CLEAR set_room_data_pointer_source, set_room_data_pointer_source_end


ORG retreat_secondary_reference_and_pointer

; Decrement the secondary reference at $8F, move the pointer
; at $70/$71 back by $78, and dispatch to $1B98.
; This is the exact mirror of advance_secondary_reference_and_pointer, SEC/SBC
; against CLC/ADC, and the two are reached through adjacent
; display_action_jump_table vectors at $1203 and $1209. enter_room_above uses
; the $1203 vector, so stepping the reference backwards is what a vertical
; transition does.
.retreat_secondary_reference_and_pointer_source
    DEC reference_pair_secondary_value
    SEC
    LDA level_room_map_offset_low
    SBC #&78
    STA level_room_map_offset_low
    LDA level_room_map_offset_high
    SBC #&00
    STA level_room_map_offset_high
    JMP draw_and_initialise_room
.retreat_secondary_reference_and_pointer_source_end

ASSERT retreat_secondary_reference_and_pointer_source = retreat_secondary_reference_and_pointer
ASSERT retreat_secondary_reference_and_pointer_source_end = &1CC7
COPYBLOCK retreat_secondary_reference_and_pointer_source, retreat_secondary_reference_and_pointer_source_end, &34B5

; Runtime $1CB5-$1CC6 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $34B5-$34C6.
CLEAR retreat_secondary_reference_and_pointer_source, retreat_secondary_reference_and_pointer_source_end


ORG advance_room_data_pointer_to_next_row_plane

; Add one ROOM_LEVEL_ROW_PLANE_BYTES stride to room_data_pointer. A clear carry
; uses the preceding shared return, so the high byte changes only after a
; low-byte wrap.
.advance_room_data_pointer_to_next_row_plane_source
    CLC
    LDA room_data_pointer_low
    ADC #ROOM_LEVEL_ROW_PLANE_BYTES
    STA room_data_pointer_low
    BCC room_row_pointer_no_carry_return
    INC room_data_pointer_high
    RTS
.advance_room_data_pointer_to_next_row_plane_source_end

ASSERT advance_room_data_pointer_to_next_row_plane_source = advance_room_data_pointer_to_next_row_plane
ASSERT advance_room_data_pointer_to_next_row_plane_source_end = &1CB5
COPYBLOCK advance_room_data_pointer_to_next_row_plane_source, advance_room_data_pointer_to_next_row_plane_source_end, &34A9

; Runtime $1CA9-$1CB4 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $34A9-$34B4.
CLEAR advance_room_data_pointer_to_next_row_plane_source, advance_room_data_pointer_to_next_row_plane_source_end


ORG reflect_room_enemy_at_obstacles

; Probe around the Y-selected room enemy and reverse its movement
; deltas wherever it is blocked, then set up its graphic and dispatch.
; The four probes come in two opposed pairs. The first pair drives the delta at
; $123A to +1 or -1, the second drives the adjacent delta at $123B to +2 or -2,
; and in each pair only the second probe is tried when the first reports clear.
; Each delta is therefore pushed away from whatever the probe found, which is
; what makes an entity turn back at an obstacle rather than pass through it.
; The tail from $35E8 loads the entity output fields, presets the three
; graphic-selection bytes to $05, $01 and $10, and tail-jumps through the $2215
; vector. That tail runs 3,987 times against 235 entries here, so it is also
; reached directly by other callers.
.reflect_room_enemy_at_obstacles_source
    JSR scan_column_behind_room_enemy
    BCC probe_opposite_horizontal
    JSR set_room_enemy_horizontal_delta_positive
    JMP probe_first_vertical

.probe_opposite_horizontal
    JSR scan_column_ahead_of_room_enemy
    BCC probe_first_vertical
    JSR set_room_enemy_horizontal_delta_negative

.probe_first_vertical
    JSR load_room_enemy_display_pointer_then_scan_markers
    BCC probe_opposite_vertical
    JSR set_room_enemy_vertical_delta_positive
    JMP prepare_room_enemy_collision_coordinates

.probe_opposite_vertical
    JSR scan_markers_below_room_enemy
    BCC prepare_room_enemy_collision_coordinates
    JSR set_room_enemy_vertical_delta_negative

.prepare_room_enemy_collision_coordinates
    JSR load_room_enemy_collision_coordinates
    LDA #OBSTACLE_REFLECTION_HORIZONTAL_RANGE
    STA candidate_range_horizontal_extent
    LDA #OBSTACLE_REFLECTION_ABOVE_RANGE
    STA candidate_range_above_extent
    LDA #OBSTACLE_REFLECTION_BELOW_RANGE
    STA candidate_range_below_extent
    JMP enter_test_range_with_supplied_box
.reflect_room_enemy_at_obstacles_source_end

ASSERT reflect_room_enemy_at_obstacles_source = reflect_room_enemy_at_obstacles
ASSERT reflect_room_enemy_at_obstacles_source_end = &35FA
COPYBLOCK reflect_room_enemy_at_obstacles_source, reflect_room_enemy_at_obstacles_source_end, &4DC2

; Runtime $35C2-$35F9 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4DC2-$4DF9.
CLEAR reflect_room_enemy_at_obstacles_source, reflect_room_enemy_at_obstacles_source_end


ORG draw_matching_records_from_table

; Walk the record table at $0900 from the last entry to the
; first, drawing every record that matches the current references.
; The table holds twelve four-byte item/goal records: X counts down from $0B
; and is multiplied by four to index them. The first two bytes are the packed match,
; tested by match_packed_record_against_references; the remaining two are the
; grid row and column, which are copied into $0A and $0B so
; set_display_pointer_from_grid_position can place the record before $1E29
; draws it.
; Scanning continues past a match rather than stopping, so several records can
; be drawn in one pass.
;
; Eleven records put pickups in their rooms. Their indices line up with
; item_name_table, so record n draws pair $28 + 2n, and seven item rooms match
; the player's account exactly, including all three keys. Two records name down
; 10, outside the grid, for the puzzle-produced herring and mouse. Record 3 is
; the exception: in H8 its draw path prints THE GOLDEN DRAGON and sets the
; gameplay-loop exit flag, matching the reported goal rather than placing salt.
; analysis/room_map.md has the full correspondence and the two remaining item
; rows that disagree.
.draw_matching_records_from_table_source
    LDX #ITEM_GOAL_LAST_RECORD_INDEX
    LDA #LO(item_and_goal_record_table)
    STA packed_record_pointer_low
    LDA #HI(item_and_goal_record_table)
    STA packed_record_pointer_high

.test_next_record
    TXA
    ASL A
    ASL A
    TAY
    JSR match_packed_record_against_references
    BCS place_and_draw_matched_record

.step_to_previous_record
    DEX
    BPL test_next_record
    RTS

.place_and_draw_matched_record
    INY
    LDA item_and_goal_record_table,Y
    STA display_grid_row
    INY
    LDA item_and_goal_record_table,Y
    STA display_grid_column
    JSR set_display_pointer_from_grid_position
    JSR draw_item_graphic_pair
    JMP step_to_previous_record
.draw_matching_records_from_table_source_end

ASSERT draw_matching_records_from_table_source = draw_matching_records_from_table
ASSERT draw_matching_records_from_table_source_end = &1DF0
COPYBLOCK draw_matching_records_from_table_source, draw_matching_records_from_table_source_end, &35C4

; Runtime $1DC4-$1DEF overlaps the loaded transport image. Release it after
; copying its bytes to loaded $35C4-$35EF.
CLEAR draw_matching_records_from_table_source, draw_matching_records_from_table_source_end


ORG advance_room_enemy_with_collision_checks

; Probe the Y-selected room enemy along its vertical direction
; and tail-transfer to the vertical mover when clear. When blocked, probe along
; its signed horizontal direction, reverse that direction if the next column is
; also blocked, and tail-transfer to the horizontal mover.
.advance_room_enemy_with_collision_checks_source
    LDA enemy_vertical_delta,Y
    CMP #&02
    BNE probe_room_enemy_vertical_path
    JSR scan_markers_below_room_enemy
    BCS handle_blocked_room_enemy_vertical_path
    JMP advance_room_enemy_vertical_position

.probe_room_enemy_vertical_path
    JSR load_room_enemy_display_pointer_then_scan_markers
    BCS handle_blocked_room_enemy_vertical_path
    JMP advance_room_enemy_vertical_position

.handle_blocked_room_enemy_vertical_path
    LDA room_enemy_horizontal_delta,Y
    CMP #&01
    BNE probe_behind_room_enemy
    JSR scan_column_ahead_of_room_enemy
    BCC advance_room_enemy_horizontally
    JSR set_room_enemy_horizontal_delta_negative

.advance_room_enemy_horizontally
    JMP advance_room_enemy_horizontal_position

.probe_behind_room_enemy
    JSR scan_column_behind_room_enemy
    BCC advance_room_enemy_horizontally
    JSR set_room_enemy_horizontal_delta_positive
    JMP advance_room_enemy_horizontally
.advance_room_enemy_with_collision_checks_source_end

ASSERT advance_room_enemy_with_collision_checks_source = advance_room_enemy_with_collision_checks
ASSERT advance_room_enemy_with_collision_checks_source_end = &362E
COPYBLOCK advance_room_enemy_with_collision_checks_source, advance_room_enemy_with_collision_checks_source_end, &4DFA

; Runtime $35FA-$362D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4DFA-$4E2D.
CLEAR advance_room_enemy_with_collision_checks_source, advance_room_enemy_with_collision_checks_source_end


ORG set_display_pointer_from_grid_position

; Convert a grid position into a display address.
; $0A is multiplied by 5 and then by 128, which is $0280, one Mode 1 character
; row, so $0A is the row. $0B is multiplied by 8, one character cell, so $0B is
; the column. The two are added and biased by the grid origin, giving
; pointer = display_grid_origin + row * $0280 + column * 8.
;
; That origin is not arbitrary. $3A00 is exactly one character row below the
; CRTC display start of $3C80, so grid row 1 lands on the first visible row
; and row 0 sits in the margin above it. The grid is therefore 1-based
; vertically against the visible display, which is why callers bias their
; stored rows before converting: initialise_room_enemy_from_table adds $0A to
; one row and subtracts 6 and 3 from the other.
;
; X is preserved across the whole computation; A and the named column-offset
; scratch word are not.
.set_display_pointer_from_grid_position_source
    TXA
    PHA
    LDA display_grid_row
    ASL A
    ASL A
    ADC display_grid_row
    STA display_pointer_low
    LDA #&00
    STA display_pointer_high
    LDX #&07

.multiply_row_by_character_row
    ASL display_pointer_low
    ROL display_pointer_high
    DEX
    BNE multiply_row_by_character_row
    LDA display_grid_column
    STA display_grid_column_offset_low
    LDA #ROOM_COLUMN_FIRST
    STA display_grid_column_offset_high
    LDX #&03

.multiply_column_by_cell
    ASL display_grid_column_offset_low
    ROL display_grid_column_offset_high
    DEX
    BNE multiply_column_by_cell
    LDA display_grid_column_offset_low
    ADC display_pointer_low
    STA display_pointer_low
    LDA display_grid_column_offset_high
    ADC display_pointer_high
    ADC #HI(display_grid_origin)
    STA display_pointer_high
    PLA
    TAX
    RTS
.set_display_pointer_from_grid_position_source_end

ASSERT set_display_pointer_from_grid_position_source = set_display_pointer_from_grid_position
ASSERT set_display_pointer_from_grid_position_source_end = &1E29
COPYBLOCK set_display_pointer_from_grid_position_source, set_display_pointer_from_grid_position_source_end, &35F0

; Runtime $1DF0-$1E28 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $35F0-$3628.
CLEAR set_display_pointer_from_grid_position_source, set_display_pointer_from_grid_position_source_end


ORG scan_column_behind_room_enemy

; Place the display pointer 8 bytes before the Y-indexed
; entry pointer, one Mode 1 character cell back, then tail-jump into
; scan_column_below_room_enemy.
; It is the opposed member of the probe pair with
; scan_column_ahead_of_room_enemy, which offsets forward by $20 into the same
; tail. reflect_room_enemy_at_obstacles tries this one first and only falls
; through to the other when this reports clear.
.scan_column_behind_room_enemy_source
    LDA room_enemy_display_pointer_low,Y
    SEC
    SBC #&08
    STA display_pointer_low
    LDA room_enemy_display_pointer_high,Y
    SBC #&00
    JMP scan_column_below_room_enemy
.scan_column_behind_room_enemy_source_end

ASSERT scan_column_behind_room_enemy_source = scan_column_behind_room_enemy
ASSERT scan_column_behind_room_enemy_source_end = &363E
COPYBLOCK scan_column_behind_room_enemy_source, scan_column_behind_room_enemy_source_end, &4E2E

; Runtime $362E-$363D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4E2E-$4E3D.
CLEAR scan_column_behind_room_enemy_source, scan_column_behind_room_enemy_source_end


ORG scan_column_ahead_of_room_enemy

; Place the display pointer $20 past the Y-room enemy
; pointer at $47/$48, two Mode 1 character cells ahead, then tail-jump into
; scan_column_below_room_enemy to scan eight rows there.
; Sharing that tail is what makes this a probe variant rather than a routine of
; its own: the caller gets the same carry-set-when-blocked answer, measured two
; cells further on.
.scan_column_ahead_of_room_enemy_source
    LDA room_enemy_display_pointer_low,Y
    CLC
    ADC #&20
    STA display_pointer_low
    LDA room_enemy_display_pointer_high,Y
    ADC #&00
    JMP scan_column_below_room_enemy
.scan_column_ahead_of_room_enemy_source_end

ASSERT scan_column_ahead_of_room_enemy_source = scan_column_ahead_of_room_enemy
ASSERT scan_column_ahead_of_room_enemy_source_end = &364E
COPYBLOCK scan_column_ahead_of_room_enemy_source, scan_column_ahead_of_room_enemy_source_end, &4E3E

; Runtime $363E-$364D overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4E3E-$4E4D.
CLEAR scan_column_ahead_of_room_enemy_source, scan_column_ahead_of_room_enemy_source_end


ORG draw_item_graphic_pair

; Draw the two consecutive graphic records selected by
; item/goal-table index X. Index 3 first calls the Golden Dragon ending sequence
; at $1E3F. The graphic pair itself is always $28 + 2X and the following index.
.draw_item_graphic_pair_source
    TXA
    PHA
    CMP #GOLDEN_DRAGON_ITEM_RECORD_INDEX
    BNE draw_selected_item_graphic_pair
    JSR show_golden_dragon_ending

.draw_selected_item_graphic_pair
    PLA
    ASL A
    ADC #ITEM_CODE_KEY_1
    JSR copy_16_byte_graphic_to_display
    CLC
    ADC #ITEM_GRAPHIC_RECORDS_PER_PAIR-1
    JMP copy_16_byte_graphic_to_display
.draw_item_graphic_pair_source_end

ASSERT draw_item_graphic_pair_source = draw_item_graphic_pair
ASSERT draw_item_graphic_pair_source_end = &1E3F
COPYBLOCK draw_item_graphic_pair_source, draw_item_graphic_pair_source_end, &3629

; Runtime $1E29-$1E3E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $3629-$363E.
CLEAR draw_item_graphic_pair_source, draw_item_graphic_pair_source_end


ORG load_room_enemy_display_pointer_then_scan_markers

; Load the display pointer for the Y-room enemy, then
; run the marker scan through the $220F jump-table vector, preserving Y across
; the call by saving it on the stack. The scan itself does not preserve Y, so
; the save is what lets the caller keep iterating over entries.
.load_room_enemy_display_pointer_then_scan_markers_source
    JSR load_room_enemy_display_pointer
    TYA
    PHA
    JSR enter_adjust_display_pointer_then_scan_markers
    PLA
    TAY
    RTS
.load_room_enemy_display_pointer_then_scan_markers_source_end

ASSERT load_room_enemy_display_pointer_then_scan_markers_source = load_room_enemy_display_pointer_then_scan_markers
ASSERT load_room_enemy_display_pointer_then_scan_markers_source_end = &3659
COPYBLOCK load_room_enemy_display_pointer_then_scan_markers_source, load_room_enemy_display_pointer_then_scan_markers_source_end, &4E4E

; Runtime $364E-$3658 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4E4E-$4E58.
CLEAR load_room_enemy_display_pointer_then_scan_markers_source, load_room_enemy_display_pointer_then_scan_markers_source_end


ORG scan_markers_below_room_enemy

; Place the display pointer one or two Mode 1 character rows
; below the Y-room enemy pointer at $47/$48, then run the four-byte marker
; scan through its jump-table vector, preserving Y across the call.
; A character row is $0280 bytes. When the repeated-scanline flag at $6C is
; clear the pointer is offset by one row; when it is set the low byte is left
; untouched and only $05 is added to the high byte, which is two rows. The
; scan itself does not preserve Y, so the save is what lets the caller keep
; iterating over entries.
.scan_markers_below_room_enemy_source
    LDA room_enemy_display_pointer_low,Y
    LDX xor_graphic_repeat_source_scanlines
    BNE offset_two_character_rows
    CLC
    ADC #&80
    STA display_pointer_low
    LDA room_enemy_display_pointer_high,Y
    ADC #&02

.store_pointer_then_scan
    STA display_pointer_high
    TYA
    PHA
    JSR enter_scan_four_display_bytes_for_markers
    PLA
    TAY
    RTS

.offset_two_character_rows
    CLC
    STA display_pointer_low
    LDA room_enemy_display_pointer_high,Y
    ADC #&05
    JMP store_pointer_then_scan
.scan_markers_below_room_enemy_source_end

ASSERT scan_markers_below_room_enemy_source = scan_markers_below_room_enemy
ASSERT scan_markers_below_room_enemy_source_end = &367F
COPYBLOCK scan_markers_below_room_enemy_source, scan_markers_below_room_enemy_source_end, &4E59

; Runtime $3659-$367E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4E59-$4E7E.
CLEAR scan_markers_below_room_enemy_source, scan_markers_below_room_enemy_source_end


ORG load_room_enemy_collision_coordinates

; Load the selected room enemy's horizontal position and
; half-resolution vertical position into the shared candidate coordinates used
; by player-overlap and pursuit tests.
.load_room_enemy_collision_coordinates_source
    LDA moving_entity_horizontal_position,Y
    STA candidate_horizontal_position
    LDA room_enemy_vertical_position,Y
    LSR A
    STA candidate_half_vertical_position
    RTS
.load_room_enemy_collision_coordinates_source_end

ASSERT load_room_enemy_collision_coordinates_source = load_room_enemy_collision_coordinates
ASSERT load_room_enemy_collision_coordinates_source_end = &368B
COPYBLOCK load_room_enemy_collision_coordinates_source, load_room_enemy_collision_coordinates_source_end, &4E7F

; Runtime $367F-$368A overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4E7F-$4E8A.
CLEAR load_room_enemy_collision_coordinates_source, load_room_enemy_collision_coordinates_source_end


ORG scan_column_below_room_enemy

; Scan a column of eight character rows for the selected
; room enemy and report whether it is blocked. A is the display pointer high byte on
; entry, the low byte having already been set by the caller.
; Y is preserved across the scan, which does not preserve it. A blocking byte
; calls $334C with A = 4 and returns carry set; a clear column returns carry
; clear.
.scan_column_below_room_enemy_source
    STA display_pointer_high
    LDA #ROOM_ENEMY_OBSTACLE_SCAN_ROWS
    STA xor_graphic_character_rows_remaining
    TYA
    PHA
    JSR enter_scan_display_column_for_blocking_byte
    BCC restore_y_and_return
    LDA #ROOM_ENEMY_BLOCKED_SOUND_PITCH
    JSR submit_sound_block_with_pitch
    SEC

.restore_y_and_return
    PLA
    TAY
    RTS
.scan_column_below_room_enemy_source_end

ASSERT scan_column_below_room_enemy_source = scan_column_below_room_enemy
ASSERT scan_column_below_room_enemy_source_end = &36A1
COPYBLOCK scan_column_below_room_enemy_source, scan_column_below_room_enemy_source_end, &4E8B

; Runtime $368B-$36A0 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4E8B-$4EA0.
CLEAR scan_column_below_room_enemy_source, scan_column_below_room_enemy_source_end


ORG clamp_room_enemy_horizontal_delta_at_limits

; Keep the Y-selected room enemy inside a range by reversing its
; movement delta at either limit. moving_entity_horizontal_position is compared
; against enemy_horizontal_lower_limit and enemy_horizontal_upper_limit: below
; the lower limit it selects a positive step, at or above the upper it selects
; a negative step, and between
; them it returns leaving the delta alone.
; The two setters share one store, the second reaching it by jumping into the
; first, which is why they form a single block. This is the range counterpart of
; reflect_room_enemy_at_obstacles: one turns an entity back at a wall, this
; one turns it back at the end of its patrol.
.clamp_room_enemy_horizontal_delta_at_limits_source
    LDA moving_entity_horizontal_position,Y
    CMP enemy_horizontal_lower_limit
    BMI set_room_enemy_horizontal_delta_positive
    CMP enemy_horizontal_upper_limit
    BPL set_room_enemy_horizontal_delta_negative
    RTS

.set_room_enemy_horizontal_delta_positive
    LDA #ENTITY_HORIZONTAL_STEP_POSITIVE

.store_room_enemy_horizontal_delta
    STA room_enemy_horizontal_delta,Y
    RTS

.set_room_enemy_horizontal_delta_negative
    LDA #ENTITY_HORIZONTAL_STEP_NEGATIVE
    JMP store_room_enemy_horizontal_delta
.clamp_room_enemy_horizontal_delta_at_limits_source_end

ASSERT clamp_room_enemy_horizontal_delta_at_limits_source = clamp_room_enemy_horizontal_delta_at_limits
ASSERT clamp_room_enemy_horizontal_delta_at_limits_source_end = &36BA
COPYBLOCK clamp_room_enemy_horizontal_delta_at_limits_source, clamp_room_enemy_horizontal_delta_at_limits_source_end, &4EA1

; Runtime $36A1-$36B9 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4EA1-$4EB9.
CLEAR clamp_room_enemy_horizontal_delta_at_limits_source, clamp_room_enemy_horizontal_delta_at_limits_source_end


ORG advance_room_enemy_horizontal_position

; Move the Y-selected room enemy horizontally by its signed delta
; and carry its display pointer with it.
; moving_entity_horizontal_position gains room_enemy_horizontal_delta, which
; the two clamps drive to +1
; or -1. The sign of that delta then chooses the pointer adjustment: 8 bytes
; forward for a positive step, 8 back for a negative one, with the high byte
; carried or borrowed.
; Eight bytes is one Mode 1 character cell, the same stride the player one-cell
; steps use, so an entity and the player cross the screen in identical units.
; The two directions are separate exits rather than a shared tail, which is why
; the routine is longer than the arithmetic needs.
.advance_room_enemy_horizontal_position_source
    LDA moving_entity_horizontal_position,Y
    CLC
    ADC room_enemy_horizontal_delta,Y
    STA moving_entity_horizontal_position,Y
    LDA room_enemy_horizontal_delta,Y
    BMI step_room_enemy_left
    CLC
    LDA room_enemy_display_pointer_low,Y
    ADC #MODE1_CELL_COLUMN_BYTES
    STA room_enemy_display_pointer_low,Y
    LDA room_enemy_display_pointer_high,Y
    ADC #&00
    STA room_enemy_display_pointer_high,Y
    RTS

.step_room_enemy_left
    SEC
    LDA room_enemy_display_pointer_low,Y
    SBC #MODE1_CELL_COLUMN_BYTES
    STA room_enemy_display_pointer_low,Y
    LDA room_enemy_display_pointer_high,Y
    SBC #&00
    STA room_enemy_display_pointer_high,Y
    RTS
.advance_room_enemy_horizontal_position_source_end

ASSERT advance_room_enemy_horizontal_position_source = advance_room_enemy_horizontal_position
ASSERT advance_room_enemy_horizontal_position_source_end = &36ED
COPYBLOCK advance_room_enemy_horizontal_position_source, advance_room_enemy_horizontal_position_source_end, &4EBA

; Runtime $36BA-$36EC overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4EBA-$4EEC.
CLEAR advance_room_enemy_horizontal_position_source, advance_room_enemy_horizontal_position_source_end


ORG reverse_room_enemy_vertical_delta_at_limits

; Keep the Y-selected room enemy inside its second range by
; reversing enemy_vertical_delta. room_enemy_vertical_position is masked to
; ENEMY_EVEN_VERTICAL_POSITION_MASK, dropping its low bit, and tested for
; equality against the vertical patrol limits:
; the first sets the delta to +2, the second to -2, and neither leaves it alone.
; Unlike the $123A clamp this tests equality rather than ordering, which is why
; the masked value has to land exactly on a limit. The two setters share one
; store, the second jumping into the first, and both entries are also called
; directly by reflect_room_enemy_at_obstacles, so they are named for what
; they do rather than for either caller reason.
.reverse_room_enemy_vertical_delta_at_limits_source
    LDA room_enemy_vertical_position,Y
    AND #ENEMY_EVEN_VERTICAL_POSITION_MASK
    CMP enemy_vertical_lower_limit
    BEQ set_room_enemy_vertical_delta_positive
    CMP enemy_vertical_upper_limit
    BEQ set_room_enemy_vertical_delta_negative
    RTS

.set_room_enemy_vertical_delta_positive
    LDA #ENTITY_VERTICAL_STEP_POSITIVE

.store_room_enemy_vertical_delta
    STA enemy_vertical_delta,Y
    RTS

.set_room_enemy_vertical_delta_negative
    LDA #ENTITY_VERTICAL_STEP_NEGATIVE
    JMP store_room_enemy_vertical_delta
.reverse_room_enemy_vertical_delta_at_limits_source_end

ASSERT reverse_room_enemy_vertical_delta_at_limits_source = reverse_room_enemy_vertical_delta_at_limits
ASSERT reverse_room_enemy_vertical_delta_at_limits_source_end = &3708
COPYBLOCK reverse_room_enemy_vertical_delta_at_limits_source, reverse_room_enemy_vertical_delta_at_limits_source_end, &4EED

; Runtime $36ED-$3707 overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4EED-$4F07.
CLEAR reverse_room_enemy_vertical_delta_at_limits_source, reverse_room_enemy_vertical_delta_at_limits_source_end


ORG advance_room_enemy_vertical_position

; Apply one signed vertical step to the Y-selected room enemy.
; The entity state is copied into the scratch fields the shared step helper
; works on: room_enemy_vertical_position, enemy_vertical_delta and the room
; enemy display pointer. apply_signed_vertical_step_to_pointer then moves both
; two display scanlines per unit, and the results are copied straight back.
; This is the same shape as
; advance_player_vertical_position_and_display_pointer, which does exactly this
; for the player using $2C and $38/$39. The two share the helper, so an entity
; and the player fall and climb through identical arithmetic.
; The step it reads is the field reverse_room_enemy_vertical_delta_at_limits and
; reflect_room_enemy_at_obstacles drive, so the direction reversals those
; apply reach the display here.
.advance_room_enemy_vertical_position_source
    LDA room_enemy_vertical_position,Y
    STA candidate_half_vertical_position
    LDA enemy_vertical_delta,Y
    STA vertical_step_delta
    LDA room_enemy_display_pointer_low,Y
    STA vertical_step_pointer_low
    LDA room_enemy_display_pointer_high,Y
    STA vertical_step_pointer_high
    JSR apply_signed_vertical_step_to_pointer
    LDA candidate_half_vertical_position
    STA room_enemy_vertical_position,Y
    LDA vertical_step_pointer_low
    STA room_enemy_display_pointer_low,Y
    LDA vertical_step_pointer_high
    STA room_enemy_display_pointer_high,Y
    RTS
.advance_room_enemy_vertical_position_source_end

ASSERT advance_room_enemy_vertical_position_source = advance_room_enemy_vertical_position
ASSERT advance_room_enemy_vertical_position_source_end = &372F
COPYBLOCK advance_room_enemy_vertical_position_source, advance_room_enemy_vertical_position_source_end, &4F08

; Runtime $3708-$372E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $4F08-$4F2E.
CLEAR advance_room_enemy_vertical_position_source, advance_room_enemy_vertical_position_source_end


ORG show_golden_dragon_ending

; Print the inline VDU stream that lays out the words
; "THE GOLDEN DRAGON", then set the gameplay-loop exit flag to $FF. The printer
; at $3256 consumes its own stacked return address, emits bytes until the zero
; terminator, and replaces that address so its RTS resumes at $1E67 rather than
; trying to execute the embedded data. The remaining caller return beneath it
; takes this routine back to draw_item_graphic_pair.
.show_golden_dragon_ending_source
    JSR print_inline_vdu_stream

.golden_dragon_inline_message
    EQUB VDU_TEXT_AT, &0A, &07
    EQUS "THE"
    EQUB VDU_TEXT_AT, &09, &09
    EQUS "GOLDEN"
    EQUB VDU_TEXT_AT, &09, &0D
    EQUS "DRAGON"
    EQUB VDU_TEXT_AT, &13, &12, &81, &20, &81
    EQUB VDU_TEXT_AT, &1B, &12, &81, &20, &81
    EQUB INLINE_VDU_STREAM_END
.golden_dragon_inline_message_end

    LDA #&FF
    STA main_loop_exit_flag
    RTS
.show_golden_dragon_ending_source_end

ASSERT show_golden_dragon_ending_source = show_golden_dragon_ending
ASSERT golden_dragon_inline_message = &1E42
ASSERT golden_dragon_inline_message_end = &1E67
ASSERT show_golden_dragon_ending_source_end = &1E6C
COPYBLOCK show_golden_dragon_ending_source, show_golden_dragon_ending_source_end, &363F

; Runtime $1E3F-$1E6B overlaps the loaded transport image. Release it after
; copying its bytes to loaded $363F-$366B.
CLEAR show_golden_dragon_ending_source, show_golden_dragon_ending_source_end


ORG initialise_room_moving_objects

; Scan room_moving_object_record_table for the
; current room. No match returns without changing the room-moving-object
; configuration. A match saves the record type and a selector derived from the
; packed room bytes; fish and mouse records return early when the existing
; room_moving_object_puzzle_state is nonzero.
;
; Otherwise the record's final three bytes become a display row and lower and
; upper position limits. Four selector states derived from those limits are
; converted into display pointers. The record type selects one named eight-byte
; set from room_moving_object_pointer_sets for the active pointer table, and the
; four alternating signed selector deltas are initialised. The room-local update,
; draw, and advance routines consume those same four instances.
.initialise_room_moving_objects_source
    LDX #&00
    LDA #LO(room_moving_object_record_table)
    STA packed_record_pointer_low
    LDA #HI(room_moving_object_record_table)
    STA packed_record_pointer_high

.test_next_room_moving_object_record
    TXA
    ASL A
    ASL A
    STA packed_record_index_scaled
    TXA
    ADC packed_record_index_scaled
    TAY
    JSR match_packed_record_against_references
    BCS load_matched_room_moving_object_record
    INX
    CPX #ROOM_MOVING_OBJECT_RECORD_COUNT
    BNE test_next_room_moving_object_record
    RTS

.load_matched_room_moving_object_record
    LDA packed_record_type_field
    STA current_room_cell
    LDX packed_record_even_field
    INX
    INX
    STX room_moving_object_slot_limit
    LDA current_room_cell
    CMP #ROOM_MOVING_OBJECT_FISH
    BEQ test_existing_special_xor_state
    CMP #ROOM_MOVING_OBJECT_MOUSE
    BNE initialise_room_moving_object_record

.test_existing_special_xor_state
    LDA room_moving_object_puzzle_state
    BEQ initialise_room_moving_object_record
    RTS

.initialise_room_moving_object_record
    LDX #ROOM_MOVING_OBJECT_ACTIVE
    STX room_moving_objects_active
    DEX

.copy_room_moving_object_record_fields
    INY
    LDA room_moving_object_record_table,Y
    STA room_moving_object_graphic_state,X
    INX
    CPX #ROOM_MOVING_OBJECT_RECORD_FIELDS
    BNE copy_room_moving_object_record_fields
    CLC
    LDA room_moving_object_graphic_selector_lower_limit
    STA room_moving_object_graphic_selector_state
    ADC room_moving_object_graphic_selector_upper_limit
    ROR A
    ADC #ROOM_MOVING_OBJECT_CENTRE_BIAS
    STA room_moving_object_inner_horizontal_position
    STA moving_entity_horizontal_position
    LDA room_moving_object_graphic_selector_upper_limit
    STA moving_entity_second_horizontal_position
    LDX #&00

.build_xor_sprite_display_pointers
    LDA room_moving_object_graphic_state
    STA display_grid_row
    LDA room_moving_object_graphic_selector_state,X
    STA display_grid_column
    JSR set_display_pointer_from_grid_position
    LDA display_pointer_low
    STA room_moving_object_display_pointer_low,X
    LDA display_pointer_high
    STA room_moving_object_display_pointer_high,X
    INX
    INX
    CPX #ROOM_MOVING_OBJECT_SLOT_END
    BNE build_xor_sprite_display_pointers
    LDA current_room_cell
    ASL A
    ASL A
    ASL A
    TAY
    LDX #&00

.copy_room_moving_object_graphic_pointers
    LDA room_moving_object_pointer_sets,Y
    STA active_room_moving_object_pointer_table,X
    INY
    INX
    CPX #ROOM_MOVING_OBJECT_POINTER_SET_BYTES
    BNE copy_room_moving_object_graphic_pointers
    LDA #ROOM_MOVING_OBJECT_STEP_POSITIVE
    STA room_moving_object_graphic_selector_delta
    STA room_moving_object_delta_slot_2
    LDA #ROOM_MOVING_OBJECT_STEP_NEGATIVE
    STA room_moving_object_delta_slot_1
    STA room_moving_object_delta_slot_3
    RTS
.initialise_room_moving_objects_source_end

ASSERT initialise_room_moving_objects_source = initialise_room_moving_objects
ASSERT initialise_room_moving_objects_source_end = &1F0F
COPYBLOCK initialise_room_moving_objects_source, initialise_room_moving_objects_source_end, &366C

; Runtime $1E6C-$1F0E overlaps the loaded transport image. Release it after
; copying its bytes to loaded $366C-$370E.
CLEAR initialise_room_moving_objects_source, initialise_room_moving_objects_source_end


; Named gameplay databases. One EQUB row is one proved record.

; Delay this copy until every routine assembled in loaded $2AA8-$2B60 has
; already copied itself elsewhere and released that overlapping runtime area.
COPYBLOCK dispatch_room_cell_source, dispatch_room_cell_source_end, &2AA8
CLEAR dispatch_room_cell_source, dispatch_room_cell_source_end

; The extended alternating-tile block copies after overlapping $2Bxx runtime
; routines have released their assembly ranges.
COPYBLOCK draw_alternating_tile_run_source, draw_alternating_tile_run_source_end, &2B71
CLEAR draw_alternating_tile_run_source, draw_alternating_tile_run_source_end

ORG status_icon_graphics
; Runtime 0880-08FF: alternate 8-by-8 Mode 1 graphics selected by setting the
; blitter bank offset to two. Records 0-3 have proved status-display callers;
; records 4-7 decode as figure fragments but have no located runtime selector.
.status_icon_graphics_source
.remaining_status_icon_graphic
; record 0: diamond icon drawn twelve times in the initial remaining-icon row
    EQUB &01, &03, &17, &3F, &17, &03, &01, &F0, &10, &08, &0C, &8E, &0C, &08, &10, &F0
.collected_status_icon_graphic
; record 1: diamond icon drawn when add_collected_icon increments its count
    EQUB &01, &01, &03, &13, &17, &37, &3F, &F0, &10, &00, &08, &08, &0C, &8C, &9E, &F0
.initial_status_marker_graphic
; record 2: marker drawn three times at $3F70 during new-game status setup
    EQUB &13, &17, &1F, &FE, &EF, &47, &07, &F0, &18, &0C, &0E, &EE, &EE, &4C, &1C, &F0
.blank_status_icon_graphic
; record 3: blank tile used to erase either status-icon row
    EQUB &00, &00, &00, &00, &00, &00, &00, &F0, &10, &00, &00, &00, &00, &00, &10, &F0
.figure_fragment_graphic_4
.unused_status_figure_graphics_source
; record 4: decoded multicolour figure fragment; no selector xref located
    EQUB &01, &FE, &04, &08, &14, &14, &14, &32, &FF, &00, &FB, &78, &50, &00, &00, &00
.figure_fragment_graphic_5
; record 5: decoded multicolour figure fragment; no selector xref located
    EQUB &06, &F1, &F6, &0A, &0C, &0A, &0A, &32, &F6, &FB, &FB, &78, &00, &00, &00, &00
.figure_fragment_graphic_6
; record 6: decoded multicolour figure fragment; no selector xref located
    EQUB &01, &02, &FF, &06, &0A, &0A, &32, &32, &FF, &00, &EC, &7E, &00, &00, &00, &00
.figure_fragment_graphic_7
; record 7: decoded multicolour figure fragment; no selector xref located
    EQUB &01, &05, &17, &36, &02, &07, &19, &14, &00, &00, &FF, &7E, &7D, &00, &00, &00
.unused_status_figure_graphics_source_end
ASSERT remaining_status_icon_graphic = status_icon_graphics + STATUS_GRAPHIC_REMAINING_ICON*16
ASSERT collected_status_icon_graphic = status_icon_graphics + STATUS_GRAPHIC_COLLECTED_ICON*16
ASSERT initial_status_marker_graphic = status_icon_graphics + STATUS_GRAPHIC_INITIAL_MARKER*16
ASSERT blank_status_icon_graphic = status_icon_graphics + STATUS_GRAPHIC_BLANK_ICON*16
ASSERT status_icon_graphics_source = status_icon_graphics
ASSERT unused_status_figure_graphics_source = unused_status_figure_graphics
ASSERT unused_status_figure_graphics_source_end = item_and_goal_record_table
COPYBLOCK status_icon_graphics_source, unused_status_figure_graphics_source_end, &2180
CLEAR status_icon_graphics_source, unused_status_figure_graphics_source_end

ORG relocated_game_entry
; Runtime 0B00-0B02: relocated entry point reached after the loader transfer.
.relocated_game_entry_source
    JMP initialise_new_game
.relocated_game_entry_source_end
ASSERT relocated_game_entry_source = relocated_game_entry
ASSERT relocated_game_entry_source_end = item_slot_label_table
COPYBLOCK relocated_game_entry_source, relocated_game_entry_source_end, &2400
CLEAR relocated_game_entry_source, relocated_game_entry_source_end

ORG item_slot_label_table
; Runtime 0B03-0B50: blank inventory slot plus twelve six-character labels.
.item_slot_label_table_source
.blank_item_slot_label
    EQUS "      "
.key_1_item_slot_label
    EQUS "  key "
.key_2_item_slot_label
    EQUS "  key "
.key_3_item_slot_label
    EQUS "  key "
.salt_item_slot_label
    EQUS "  salt"
.worm_item_slot_label
    EQUS " worm "
.access_card_item_slot_label
    EQUS "  card"
.herring_item_slot_label
    EQUS "herrin"
.mouse_item_slot_label
    EQUS " mouse"
.cheese_item_slot_label
    EQUS "cheese"
.cross_item_slot_label
    EQUS " cross"
.eye_item_slot_label
    EQUS "  eye "
.bottle_item_slot_label
    EQUS "bottle"
.item_slot_label_table_source_end
ASSERT key_1_item_slot_label = item_slot_label_table + (ITEM_CODE_KEY_1-ITEM_LABEL_CODE_BIAS)*3
ASSERT key_2_item_slot_label = item_slot_label_table + (ITEM_CODE_KEY_2-ITEM_LABEL_CODE_BIAS)*3
ASSERT key_3_item_slot_label = item_slot_label_table + (ITEM_CODE_KEY_3-ITEM_LABEL_CODE_BIAS)*3
ASSERT salt_item_slot_label = item_slot_label_table + (ITEM_CODE_GOLDEN_DRAGON_OR_SALT-ITEM_LABEL_CODE_BIAS)*3
ASSERT worm_item_slot_label = item_slot_label_table + (ITEM_CODE_WORM-ITEM_LABEL_CODE_BIAS)*3
ASSERT access_card_item_slot_label = item_slot_label_table + (ITEM_CODE_ACCESS_CARD-ITEM_LABEL_CODE_BIAS)*3
ASSERT herring_item_slot_label = item_slot_label_table + (ITEM_CODE_HERRING-ITEM_LABEL_CODE_BIAS)*3
ASSERT mouse_item_slot_label = item_slot_label_table + (ITEM_CODE_MOUSE-ITEM_LABEL_CODE_BIAS)*3
ASSERT cheese_item_slot_label = item_slot_label_table + (ITEM_CODE_CHEESE-ITEM_LABEL_CODE_BIAS)*3
ASSERT cross_item_slot_label = item_slot_label_table + (ITEM_CODE_CROSS-ITEM_LABEL_CODE_BIAS)*3
ASSERT eye_item_slot_label = item_slot_label_table + (ITEM_CODE_EYE-ITEM_LABEL_CODE_BIAS)*3
ASSERT bottle_item_slot_label = item_slot_label_table + (ITEM_CODE_BOTTLE-ITEM_LABEL_CODE_BIAS)*3
ASSERT item_slot_label_table_source_end-item_slot_label_table_source = (ITEM_GOAL_RECORD_COUNT+1)*ITEM_LABEL_CHARACTER_COUNT
ASSERT item_slot_label_table_source = item_slot_label_table
ASSERT item_slot_label_table_source_end = &0B51
COPYBLOCK item_slot_label_table_source, item_slot_label_table_source_end, &2403
CLEAR item_slot_label_table_source, item_slot_label_table_source_end

ORG &0B51
; Runtime 0B51-0B52: zero padding between the label and tune tables.
.item_label_table_padding_source
    EQUB &00, &00
.item_label_table_padding_source_end
ASSERT item_label_table_padding_source = &0B51
ASSERT item_label_table_padding_source_end = music_tune_sequence
COPYBLOCK item_label_table_padding_source, item_label_table_padding_source_end, &2451
CLEAR item_label_table_padding_source, item_label_table_padding_source_end

ORG music_tune_sequence
; Runtime 0B53-0B5E: twelve-note sequence required by the music puzzle.
.music_tune_sequence_source
    EQUB &44, &3C, &34, &44, &3C, &34, &50, &48, &44, &50, &48, &44
.music_tune_sequence_source_end
ASSERT music_tune_sequence_source_end-music_tune_sequence_source = MUSIC_TUNE_NOTE_COUNT
ASSERT music_tune_sequence_source = music_tune_sequence
ASSERT music_tune_sequence_source_end = active_room_moving_object_pointer_table
COPYBLOCK music_tune_sequence_source, music_tune_sequence_source_end, &2453
CLEAR music_tune_sequence_source, music_tune_sequence_source_end

ORG active_room_moving_object_pointer_table
; Runtime 0B5F-0B66: four pointers populated during room initialisation.
.active_room_moving_object_pointer_table_source
    EQUW NULL_POINTER, NULL_POINTER, NULL_POINTER, NULL_POINTER
.active_room_moving_object_pointer_table_source_end
ASSERT active_room_moving_object_pointer_table_source = active_room_moving_object_pointer_table
ASSERT active_room_moving_object_pointer_table_source_end = &0B67
COPYBLOCK active_room_moving_object_pointer_table_source, active_room_moving_object_pointer_table_source_end, &245F
CLEAR active_room_moving_object_pointer_table_source, active_room_moving_object_pointer_table_source_end

ORG enemy_graphic_descriptor
; Runtime 0B67-0B6A: current enemy's two sprite-frame pointers.
.enemy_graphic_descriptor_source
    EQUB &00, &00, &00, &00
.enemy_graphic_descriptor_source_end
ASSERT enemy_graphic_descriptor_source = enemy_graphic_descriptor
ASSERT enemy_graphic_descriptor_source_end = lift_and_hazard_graphic_descriptor
COPYBLOCK enemy_graphic_descriptor_source, enemy_graphic_descriptor_source_end, &2467
CLEAR enemy_graphic_descriptor_source, enemy_graphic_descriptor_source_end

ORG lift_and_hazard_graphic_descriptor
; Runtime 0B6B-0B6E: selected lift/hazard sprite-frame pointer pair.
.lift_and_hazard_graphic_descriptor_source
    EQUB &00, &00, &00, &00
.lift_and_hazard_graphic_descriptor_source_end
ASSERT lift_and_hazard_graphic_descriptor = active_room_moving_object_pointer_table + LIFT_HAZARD_FRAME_0_POINTER_OFFSET
ASSERT lift_and_hazard_graphic_descriptor+2 = active_room_moving_object_pointer_table + LIFT_HAZARD_FRAME_1_POINTER_OFFSET
ASSERT lift_and_hazard_graphic_descriptor_source = lift_and_hazard_graphic_descriptor
ASSERT lift_and_hazard_graphic_descriptor_source_end = &0B6F
COPYBLOCK lift_and_hazard_graphic_descriptor_source, lift_and_hazard_graphic_descriptor_source_end, &246B
CLEAR lift_and_hazard_graphic_descriptor_source, lift_and_hazard_graphic_descriptor_source_end

ORG cross_room_robot_ghost_frame_pointer_table
; Runtime $0B6F-$0B76: the cross-room robot/ghost graphic-pointer table. The ordinary
; per-level pair updater selects offsets $10/$12 from the common table base
; $0B5F, reaching the small-bouncing-robot frames here. The alternate updater
; used on levels 8 and 9 selects offsets $14/$16, reaching the ghost frames.
.cross_room_robot_ghost_frame_pointer_table_source
    EQUW runtime_small_bouncing_robot_frame_0, runtime_small_bouncing_robot_frame_1
    EQUW runtime_ghost_frame_0, runtime_ghost_frame_3
.cross_room_robot_ghost_frame_pointer_table_source_end
ASSERT cross_room_robot_ghost_frame_pointer_table_source = cross_room_robot_ghost_frame_pointer_table

; Runtime $0B77-$0B82: six player-part pointers. xor_draw_player_two_parts
; indexes $0500/$0560 with X=$18/$1A and draws two character rows, so the XOR
; renderer advances by $20 and consumes $0520/$0580 as the corresponding middle
; record. X=$1C/$1E/$20/$22 selects one of the four single-row lower records.
.player_graphic_frame_pointer_table_source
.player_upper_right_graphic_pointer
    EQUW runtime_player_upper_facing_right_frame
.player_upper_left_graphic_pointer
    EQUW runtime_player_upper_facing_left_frame
.player_lower_standing_graphic_pointer
    EQUW runtime_player_lower_standing_frame
.player_lower_step_right_graphic_pointer
    EQUW runtime_player_lower_step_right_frame
.player_lower_wide_graphic_pointer
    EQUW runtime_player_lower_wide_stride_frame
.player_lower_step_left_graphic_pointer
    EQUW runtime_player_lower_step_left_frame
.player_graphic_frame_pointer_table_source_end
ASSERT player_upper_right_graphic_pointer = active_room_moving_object_pointer_table + PLAYER_UPPER_RIGHT_POINTER_OFFSET
ASSERT player_upper_left_graphic_pointer = active_room_moving_object_pointer_table + PLAYER_UPPER_LEFT_POINTER_OFFSET
ASSERT player_lower_standing_graphic_pointer = active_room_moving_object_pointer_table + PLAYER_LOWER_STANDING_POINTER_OFFSET
ASSERT player_lower_step_right_graphic_pointer = active_room_moving_object_pointer_table + PLAYER_LOWER_STEP_RIGHT_POINTER_OFFSET
ASSERT player_lower_wide_graphic_pointer = active_room_moving_object_pointer_table + PLAYER_LOWER_WIDE_POINTER_OFFSET
ASSERT player_lower_step_left_graphic_pointer = active_room_moving_object_pointer_table + PLAYER_LOWER_STEP_LEFT_POINTER_OFFSET
ASSERT player_graphic_frame_pointer_table_source = player_graphic_frame_pointer_table
ASSERT player_graphic_frame_pointer_table_source_end = &0B83
COPYBLOCK cross_room_robot_ghost_frame_pointer_table_source, player_graphic_frame_pointer_table_source_end, &246F
CLEAR cross_room_robot_ghost_frame_pointer_table_source, player_graphic_frame_pointer_table_source_end

ORG interval_timer_block
; Runtime $0B9B-$0B9F: five-byte MOS interval timer value, replaced by
; OSWORD_WRITE_INTERVAL_TIMER.
.interval_timer_block_source
    EQUB &90, &E8, &FF, &FF, &FF
.interval_timer_block_source_end
ASSERT interval_timer_block_source = interval_timer_block
ASSERT interval_timer_block_source_end = write_system_clock_via_osword_02
COPYBLOCK interval_timer_block_source, interval_timer_block_source_end, &249B
CLEAR interval_timer_block_source, interval_timer_block_source_end

ORG music_note_pitch_table
; Runtime 0BC0-0BC7: eight pitches selected by the player's keyboard position.
.music_note_pitch_table_source
    EQUB &34, &3C, &44, &48, &50, &58, &60, &64
.music_note_pitch_table_source_end
ASSERT music_note_pitch_table_source = music_note_pitch_table
ASSERT music_note_pitch_table_source_end = initialise_new_game
COPYBLOCK music_note_pitch_table_source, music_note_pitch_table_source_end, &24C0
CLEAR music_note_pitch_table_source, music_note_pitch_table_source_end

ORG startup_room_sequence_table
; Runtime 0CED-0CFC: sixteen packed secondary/primary startup-room references.
.startup_room_sequence_table_source
    EQUB &86, &31, &14, &05, &96, &42, &35, &73
    EQUB &17, &54, &90, &53, &61, &45, &60, &01
.startup_room_sequence_table_source_end
ASSERT startup_room_sequence_table_source = startup_room_sequence_table
ASSERT startup_room_sequence_table_source_end = &0CFD
COPYBLOCK startup_room_sequence_table_source, startup_room_sequence_table_source_end, &25ED
CLEAR startup_room_sequence_table_source, startup_room_sequence_table_source_end

ORG unreachable_runtime_low_tail_jsr
; Runtime $0CFD-$0CFF / loaded $25FD-$25FF. These are the final three bytes of
; the loader's proved $0400-$0CFF runtime-low copy, immediately before the
; intentionally unmapped $0D00-$0DFF gap. They are byte-shaped as JSR $343A,
; but no static or dynamic entry/xref reaches $0CFD and an RTS would fall into
; that gap. Preserve them explicitly without promoting an unsupported routine.
.unreachable_runtime_low_tail_jsr_source
    EQUB &20, &3A, &34
.unreachable_runtime_low_tail_jsr_source_end
ASSERT unreachable_runtime_low_tail_jsr_source = unreachable_runtime_low_tail_jsr
ASSERT unreachable_runtime_low_tail_jsr_source_end = &0D00
COPYBLOCK unreachable_runtime_low_tail_jsr_source, unreachable_runtime_low_tail_jsr_source_end, &25FD
CLEAR unreachable_runtime_low_tail_jsr_source, unreachable_runtime_low_tail_jsr_source_end

ORG password_letters
; Runtime 1796-17AF: eight overlapping five-letter passwords at stride three.
.password_letters_source
    EQUS "SALLYNDAVIDIOTTERASEVENTER"
.password_letters_source_end
ASSERT password_letters_source = password_letters
ASSERT password_letters_source_end = room_sign_text_table
COPYBLOCK password_letters_source, password_letters_source_end, &2F96
CLEAR password_letters_source, password_letters_source_end

ORG room_sign_text_table
; Runtime 17B0-18A9: fifteen 8-by-2 signs, then the terminal password prompt.
.room_sign_text_table_source
.music_room_sign
    EQUS " Music   Room   "
.level_sector_sign
    EQUS "Level | Sector|"
    EQUB &00
.elephant_house_sign
    EQUS "ELEPHANT  HOUSE "
.joke_shop_sign
    EQUS "*Joke******Shop*"
.teleport_sign
    EQUS "TELEPORT{}{}{}{}"
.armoury_sign
    EQUS "The     Armoury "
.hydroponics_sign
    EQUS " Hydro-  ponics "
.hydrochloric_acid_sign
    EQUS "  HCL    ^^^^^  "
.sodium_hydroxide_sign
    EQUS " Na-OH  ^^^^^^^ "
.time_warp_sign
    EQUS "//TIME\\\\WARP//"
.oracle_sign
    EQUS "  The    Oracle "
.optician_sign
    EQUS "Optician''''''''"
.chemical_supplies_sign
    EQUS "CHEMICALSUPPLIES"
.ghost_maze_sign
    EQUS "~Ghost~~~~Maze~~"
.chapel_sign
    EQUS "         Chapel "
.terminal_password_prompt
    EQUS "PASSWORD>"
    EQUB &00
.room_sign_text_table_source_end
ASSERT room_sign_text_table_source = room_sign_text_table
ASSERT room_sign_text_table_source_end = across_to_password_number
COPYBLOCK room_sign_text_table_source, room_sign_text_table_source_end, &2FB0
CLEAR room_sign_text_table_source, room_sign_text_table_source_end

ORG across_to_password_number
; Runtime $18AA-$18B1: stored password number carried by each map column.
.across_to_password_number_source
    EQUB &07, &02, &06, &00, &05, &01, &04, &03
.across_to_password_number_source_end
ASSERT across_to_password_number_source = across_to_password_number
ASSERT across_to_password_number_source_end = &18B2
COPYBLOCK across_to_password_number_source, across_to_password_number_source_end, &30AA
CLEAR across_to_password_number_source, across_to_password_number_source_end

ORG room_and_item_graphic_bank
; Runtime 0E00-0E0F: blank graphic record zero. OSWORD $02 also reads its
; first five zero bytes as the system-clock parameter block.
.system_clock_and_blank_graphic_record_source
    EQUB &00, &00, &00, &00, &00, &00, &00, &00
    EQUB &00, &00, &00, &00, &00, &00, &00, &00
.system_clock_and_blank_graphic_record_source_end
ASSERT system_clock_and_blank_graphic_record_source = room_and_item_graphic_bank
ASSERT system_clock_and_blank_graphic_record_source_end = room_and_item_graphic_records
COPYBLOCK system_clock_and_blank_graphic_record_source, system_clock_and_blank_graphic_record_source_end, &2600
CLEAR system_clock_and_blank_graphic_record_source, system_clock_and_blank_graphic_record_source_end

ORG room_and_item_graphic_records
; Runtime 0E10-11FF: room-tile, status and item graphic records $01-$3F.
; Each EQUB row is one 8-by-8, four-colour Mode 1 tile: bytes 0-7 are the
; left four pixels' scanlines and bytes 8-15 are the right four. Descriptive
; shape names below come from decoding those pixels; gameplay names are used
; only for the item pairs whose record-index mapping is independently proved.
.room_and_item_graphic_records_source
.rounded_pattern_tile_a
; graphic record &01: rounded patterned room tile; appearance groups 1 and C
    EQUB &01, &03, &17, &17, &07, &17, &16, &03, &01, &0F, &FF, &5F, &AF, &5F, &FA, &0F
.rounded_pattern_tile_b
; graphic record &02: companion rounded patterned room tile; appearance groups 1 and C
    EQUB &00, &0F, &FF, &5F, &AF, &5F, &FA, &0F, &08, &0E, &CF, &4F, &8F, &4F, &CB, &0E
.solid_diagonal_tile_a
; graphic record &03: solid diagonal room tile; appearance group 6
    EQUB &7F, &3F, &3F, &1F, &1F, &0F, &0F, &0F, &FE, &FC, &FC, &F8, &F8, &F0, &F0, &F0
.hollow_arch_tile
; graphic record &04: hollow arch room tile; appearance group 6
    EQUB &0F, &0E, &0E, &0C, &0C, &08, &08, &7F, &F0, &70, &70, &30, &30, &10, &10, &FE
.diagonal_beam_tile
; graphic record &05: diagonal beam room tile; appearance group 2
    EQUB &00, &00, &00, &11, &33, &76, &FC, &E8, &33, &76, &FC, &E8, &C0, &80, &00, &00
.small_marker_tile
; graphic record &06: small marker-pattern room tile; appearance group 7
    EQUB &F0, &F0, &00, &0C, &00, &04, &00, &02, &C0, &E0, &30, &18, &10, &1C, &10, &10
.crossed_diagonal_tile
; graphic record &07: crossed-diagonal room tile; appearance group B
    EQUB &CC, &66, &33, &11, &11, &32, &64, &C8, &11, &32, &64, &C8, &CC, &66, &33, &11
.curved_bowl_tile
; graphic record &08: curved bowl-shaped room-cell tile
    EQUB &0C, &0C, &0F, &CC, &E6, &73, &31, &0F, &0C, &0C, &0F, &33, &76, &EC, &C8, &0F
.checker_diagonal_tile
; graphic record &09: checker-pattern diagonal room-cell tile
    EQUB &0A, &05, &0A, &05, &0A, &05, &0A, &05, &0A, &05, &0A, &05, &0A, &05, &0A, &05
.solid_corner_tile_a
; graphic record &0A: solid corner room-cell tile
    EQUB &FF, &FF, &23, &11, &00, &00, &00, &00, &FF, &FF, &0F, &0F, &F8, &F8, &00, &00
.solid_corner_tile_b
; graphic record &0B: companion solid corner room-cell tile
    EQUB &FF, &FF, &0F, &0E, &D0, &D0, &00, &00, &FF, &FF, &04, &08, &00, &00, &00, &00
.stepped_fixture_tile
; graphic record &0C: stepped fixture-shaped room-cell tile
    EQUB &00, &00, &10, &30, &60, &60, &F0, &F1, &00, &E0, &90, &10, &00, &00, &80, &E0
.coloured_fixture_tile
; graphic record &0D: coloured fixture-shaped room-cell tile
    EQUB &F4, &F0, &F0, &F4, &F0, &82, &80, &F0, &F4, &F0, &F8, &E0, &C0, &04, &04, &C0
.chain_link_tile_a
; graphic record &0E: chain-link room tile; appearance group 4
    EQUB &66, &77, &22, &33, &33, &11, &0E, &0F, &00, &CC, &EE, &66, &BB, &DD, &67, &0F
.chain_link_tile_b
; graphic record &0F: companion chain-link room tile; appearance group 4
    EQUB &00, &33, &77, &66, &DD, &BB, &EF, &0F, &EE, &EE, &66, &CC, &CC, &88, &0E, &03
.patterned_slope_tile_a
; graphic record &10: patterned slope room tile; appearance group 0
    EQUB &00, &00, &00, &01, &01, &03, &17, &7A, &01, &12, &17, &3E, &F7, &FA, &FD, &FA
.patterned_slope_tile_b
; graphic record &11: companion patterned slope room tile; appearance group 0
    EQUB &08, &84, &8E, &C7, &FE, &F5, &FB, &F5, &00, &00, &00, &08, &08, &0C, &8E, &E5
.horizontal_bar_tile
; graphic record &12: horizontal-bar room-cell tile; substituted for the blank
; record while water_environment_flag is nonzero
    EQUB &C0, &00, &C0, &00, &C0, &00, &C0, &00, &C0, &00, &C0, &00, &C0, &00, &C0, &00
.narrow_vertical_bar_tile
; graphic record &13: narrow vertical-bar room-cell tile
    EQUB &DF, &DF, &DF, &DF, &DF, &DF, &DF, &DF, &5E, &5E, &5E, &5E, &5E, &5E, &5E, &5E
.wide_vertical_bar_tile
; graphic record &14: wide vertical-bar room-cell tile
    EQUB &DF, &DF, &DF, &DF, &DF, &CE, &CC, &88, &5E, &4E, &4C, &08, &00, &00, &00, &00
.column_junction_tile
; graphic record &15: column/junction room-cell tile
    EQUB &07, &0F, &09, &01, &77, &DF, &DF, &DF, &0E, &0F, &09, &08, &EE, &5E, &5E, &5C
.solid_fill_tile
; graphic record &16: solid-colour room-cell tile
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
.stepped_fill_tile
; graphic record &17: stepped-fill room tile; appearance group A
    EQUB &08, &8C, &CE, &EF, &EF, &FF, &FF, &FF, &00, &00, &00, &00, &08, &0C, &8E, &CF
.sloping_ledge_tile_a
; graphic record &18: sloping ledge room-cell tile
    EQUB &00, &00, &00, &00, &01, &67, &47, &0F, &11, &23, &8F, &C1, &C0, &E0, &F7, &EE
.sloping_ledge_tile_b
; graphic record &19: companion sloping ledge room-cell tile
    EQUB &08, &48, &2D, &2D, &3C, &98, &CC, &DC, &00, &00, &00, &00, &08, &0C, &C3, &F0
.diagonal_slope_tile_a
; graphic record &1A: diagonal slope room tile; appearance group 3
    EQUB &C0, &F0, &3C, &8F, &EF, &FF, &7F, &B7, &00, &80, &C0, &E0, &68, &68, &3C, &BC
.diagonal_slope_tile_b
; graphic record &1B: companion diagonal slope room tile; appearance group 3
    EQUB &00, &10, &30, &70, &61, &61, &C3, &D3, &30, &F0, &C3, &1F, &7F, &FF, &EF, &DE
.small_panel_tile
; graphic record &1C: small panel room tile; appearance group 7
    EQUB &30, &70, &C0, &80, &80, &81, &80, &80, &F0, &F0, &00, &0C, &00, &05, &00, &08
.striped_fill_tile
; graphic record &1D: striped-fill room-cell tile
    EQUB &FF, &FF, &0F, &00, &00, &00, &00, &00, &FF, &FF, &0F, &00, &00, &00, &00, &00
.flat_fill_tile
; graphic record &1E: flat-fill room tile; appearance groups 5 and 8
    EQUB &B7, &B7, &B7, &B7, &B7, &B7, &B7, &B7, &DE, &DE, &DE, &DE, &DE, &DE, &DE, &DE
.corner_fill_tile
; graphic record &1F: corner-fill room tile; appearance group A
    EQUB &00, &00, &11, &33, &33, &77, &77, &77, &00, &77, &FF, &FF, &FF, &FF, &FF, &FF
.horizontal_platform_tile
; graphic record &20: horizontal platform-like room tile; appearance groups 5 and 8
    EQUB &F0, &0F, &FF, &FF, &FF, &FF, &0F, &F0, &F0, &0F, &FF, &FF, &FF, &FF, &0F, &F0
.decorative_diamond_tile
; graphic record &21: decorative diamond-pattern room-cell tile
    EQUB &88, &EF, &CF, &8F, &9E, &2D, &4B, &0F, &07, &0F, &A5, &0F, &4B, &2D, &0F, &0F
.diagonal_block_tile_a
; graphic record &22: diagonal block room-cell tile
    EQUB &7F, &3F, &1F, &1F, &3E, &3E, &7E, &7F, &CC, &EE, &FF, &FF, &F3, &3F, &3F, &FF
.diagonal_block_tile_b
; graphic record &23: companion diagonal block room-cell tile
    EQUB &7F, &7F, &7F, &7F, &7F, &F7, &FB, &31, &FF, &FF, &FF, &EE, &EE, &EE, &EE, &CC
.striped_vertical_tile
; graphic record &24: striped vertical room-cell tile
    EQUB &11, &10, &11, &10, &11, &10, &11, &10, &CC, &CC, &CC, &CC, &CC, &CC, &CC, &CC
.uniform_pattern_tile
; graphic record &25: uniform-pattern room-cell tile
    EQUB &77, &77, &77, &77, &77, &77, &77, &77, &EE, &EE, &EE, &EE, &EE, &EE, &EE, &EE
.double_bar_tile
; graphic record &26: double-bar room-cell tile
    EQUB &00, &00, &00, &00, &00, &00, &FF, &FF, &00, &00, &00, &00, &00, &00, &FF, &FF
.pillar_base_tile
; graphic record &27: pillar/base-shaped room-cell tile
    EQUB &00, &44, &44, &44, &4E, &EE, &4E, &F0, &00, &44, &44, &44, &4E, &EE, &4E, &F0
.key_item_graphic_pair_1
; graphic records &28-&29: first key
; graphic record &28
    EQUB &0F, &0F, &3C, &3C, &3C, &1C, &0F, &0F, &0F, &0F, &C3, &C3, &C3, &C3, &0F, &0F
; graphic record &29
    EQUB &00, &00, &00, &0F, &0F, &00, &00, &00, &00, &00, &02, &0F, &0F, &0E, &0C, &04
.key_item_graphic_pair_2
; graphic records &2A-&2B: second key
; graphic record &2A
    EQUB &01, &03, &06, &3C, &3C, &16, &03, &01, &08, &0C, &86, &C3, &C3, &86, &0C, &08
; graphic record &2B
    EQUB &00, &00, &00, &0F, &0F, &00, &00, &00, &00, &00, &00, &0F, &0F, &0E, &06, &02
.key_item_graphic_pair_3
; graphic records &2C-&2D: third key
; graphic record &2C
    EQUB &0F, &0F, &3C, &3C, &3C, &3C, &0F, &0F, &0F, &0F, &C3, &C3, &C3, &83, &0F, &0F
; graphic record &2D
    EQUB &00, &00, &00, &0F, &0F, &00, &00, &00, &00, &00, &00, &0F, &0F, &0E, &0A, &0A
.golden_dragon_graphic_pair
; graphic records &2E-&2F: the Golden Dragon. Numeric item code $2E also maps
; the inventory label "salt" to this pair, so the same bytes have both roles.
; graphic record &2E
    EQUB &00, &00, &FF, &BB, &0C, &03, &33, &FF, &11, &FF, &FC, &FF, &0F, &7F, &FF, &88
; graphic record &2F
    EQUB &CC, &FF, &EF, &EF, &FF, &FF, &77, &77, &06, &0E, &0C, &4C, &EE, &EE, &EE, &CC
.worm_item_graphic_pair
; graphic records &30-&31: worm
; graphic record &30
    EQUB &00, &00, &00, &77, &BF, &FF, &11, &77, &00, &11, &33, &76, &FA, &EC, &CC, &00
; graphic record &31
    EQUB &CC, &EE, &FD, &73, &32, &11, &00, &00, &00, &00, &00, &00, &88, &88, &CC, &73
.access_card_item_graphic_pair
; graphic records &32-&33: access card
; graphic record &32
    EQUB &30, &70, &F0, &F0, &E1, &C3, &70, &33, &F0, &E1, &C3, &69, &3C, &1E, &F0, &FF
; graphic record &33
    EQUB &F0, &3C, &1E, &0F, &87, &C3, &F0, &FF, &C0, &E0, &F0, &F0, &78, &3C, &E0, &CC
.fish_facing_left_and_herring_item_graphic_pair
; graphic records &34-&35: fish facing left; used both as the inventory herring
; graphic and as the left-facing partner of fish_facing_right_frame at $06A0
; graphic record &34
    EQUB &00, &01, &03, &07, &0F, &00, &03, &00, &07, &0F, &C3, &C3, &0F, &03, &0F, &07
; graphic record &35
    EQUB &08, &0E, &0F, &0F, &0F, &0F, &0E, &08, &01, &03, &16, &0F, &2D, &16, &03, &01
.mouse_facing_left_and_item_graphic_pair
; graphic records &36-&37: mouse facing left; used both as the inventory mouse
; graphic and as the left-facing partner of mouse_facing_right_frame at $0680
; graphic record &36
    EQUB &33, &33, &11, &23, &FF, &00, &00, &11, &00, &33, &FF, &FF, &FF, &77, &CC, &00
; graphic record &37
    EQUB &00, &CC, &EE, &EE, &FF, &FF, &66, &CC, &CC, &22, &11, &11, &22, &CC, &00, &00
.cheese_item_graphic_pair
; graphic records &38-&39: cheese
; graphic record &38
    EQUB &00, &33, &66, &77, &55, &FF, &BB, &FF, &00, &CC, &FF, &BB, &FF, &EE, &77, &FF
; graphic record &39
    EQUB &00, &00, &00, &CC, &FF, &DD, &77, &FF, &00, &00, &00, &00, &00, &CC, &66, &FF
.cross_item_graphic_pair
; graphic records &3A-&3B: cross
; graphic record &3A
    EQUB &01, &01, &10, &0F, &0F, &01, &01, &01, &08, &08, &08, &0F, &0F, &80, &08, &08
; graphic record &3B
    EQUB &00, &00, &00, &0F, &0F, &00, &00, &00, &00, &00, &07, &0F, &0F, &07, &00, &00
.eye_item_graphic_pair
; graphic records &3C-&3D: eye
; graphic record &3C
    EQUB &00, &03, &06, &0C, &0C, &06, &03, &00, &0F, &1C, &30, &60, &60, &30, &1C, &0F
; graphic record &3D
    EQUB &0F, &83, &C0, &60, &60, &C0, &83, &0F, &00, &0C, &06, &03, &03, &06, &0C, &00
.bottle_item_graphic_pair
; graphic records &3E-&3F: bottle
; graphic record &3E
    EQUB &00, &10, &FC, &BC, &FC, &AC, &10, &00, &F0, &F0, &F0, &F0, &F0, &70, &80, &F0
; graphic record &3F
    EQUB &F0, &F0, &F0, &F0, &F0, &F0, &00, &F0, &E0, &F0, &F0, &F0, &F0, &D0, &30, &E0
.room_and_item_graphic_records_source_end
ASSERT rounded_pattern_tile_a = room_and_item_graphic_records + (GRAPHIC_ROUNDED_PATTERN_A-1)*16
ASSERT rounded_pattern_tile_b = room_and_item_graphic_records + (GRAPHIC_ROUNDED_PATTERN_B-1)*16
ASSERT solid_diagonal_tile_a = room_and_item_graphic_records + (GRAPHIC_SOLID_DIAGONAL_A-1)*16
ASSERT hollow_arch_tile = room_and_item_graphic_records + (GRAPHIC_HOLLOW_ARCH-1)*16
ASSERT diagonal_beam_tile = room_and_item_graphic_records + (GRAPHIC_DIAGONAL_BEAM-1)*16
ASSERT small_marker_tile = room_and_item_graphic_records + (GRAPHIC_SMALL_MARKER-1)*16
ASSERT crossed_diagonal_tile = room_and_item_graphic_records + (GRAPHIC_CROSSED_DIAGONAL-1)*16
ASSERT curved_bowl_tile = room_and_item_graphic_records + (GRAPHIC_CURVED_BOWL-1)*16
ASSERT checker_diagonal_tile = room_and_item_graphic_records + (GRAPHIC_CHECKER_DIAGONAL-1)*16
ASSERT solid_corner_tile_a = room_and_item_graphic_records + (GRAPHIC_SOLID_CORNER_A-1)*16
ASSERT solid_corner_tile_b = room_and_item_graphic_records + (GRAPHIC_SOLID_CORNER_B-1)*16
ASSERT stepped_fixture_tile = room_and_item_graphic_records + (GRAPHIC_STEPPED_FIXTURE-1)*16
ASSERT coloured_fixture_tile = room_and_item_graphic_records + (GRAPHIC_COLOURED_FIXTURE-1)*16
ASSERT chain_link_tile_a = room_and_item_graphic_records + (GRAPHIC_CHAIN_LINK_A-1)*16
ASSERT chain_link_tile_b = room_and_item_graphic_records + (GRAPHIC_CHAIN_LINK_B-1)*16
ASSERT patterned_slope_tile_a = room_and_item_graphic_records + (GRAPHIC_PATTERNED_SLOPE_A-1)*16
ASSERT patterned_slope_tile_b = room_and_item_graphic_records + (GRAPHIC_PATTERNED_SLOPE_B-1)*16
ASSERT horizontal_bar_tile = room_and_item_graphic_records + (GRAPHIC_HORIZONTAL_BAR-1)*16
ASSERT narrow_vertical_bar_tile = room_and_item_graphic_records + (GRAPHIC_NARROW_VERTICAL_BAR-1)*16
ASSERT wide_vertical_bar_tile = room_and_item_graphic_records + (GRAPHIC_WIDE_VERTICAL_BAR-1)*16
ASSERT column_junction_tile = room_and_item_graphic_records + (GRAPHIC_COLUMN_JUNCTION-1)*16
ASSERT solid_fill_tile = room_and_item_graphic_records + (GRAPHIC_SOLID_FILL-1)*16
ASSERT stepped_fill_tile = room_and_item_graphic_records + (GRAPHIC_STEPPED_FILL-1)*16
ASSERT sloping_ledge_tile_a = room_and_item_graphic_records + (GRAPHIC_SLOPING_LEDGE_A-1)*16
ASSERT sloping_ledge_tile_b = room_and_item_graphic_records + (GRAPHIC_SLOPING_LEDGE_B-1)*16
ASSERT diagonal_slope_tile_a = room_and_item_graphic_records + (GRAPHIC_DIAGONAL_SLOPE_A-1)*16
ASSERT diagonal_slope_tile_b = room_and_item_graphic_records + (GRAPHIC_DIAGONAL_SLOPE_B-1)*16
ASSERT small_panel_tile = room_and_item_graphic_records + (GRAPHIC_SMALL_PANEL-1)*16
ASSERT striped_fill_tile = room_and_item_graphic_records + (GRAPHIC_STRIPED_FILL-1)*16
ASSERT flat_fill_tile = room_and_item_graphic_records + (GRAPHIC_FLAT_FILL-1)*16
ASSERT corner_fill_tile = room_and_item_graphic_records + (GRAPHIC_CORNER_FILL-1)*16
ASSERT horizontal_platform_tile = room_and_item_graphic_records + (GRAPHIC_HORIZONTAL_PLATFORM-1)*16
ASSERT decorative_diamond_tile = room_and_item_graphic_records + (GRAPHIC_DECORATIVE_DIAMOND-1)*16
ASSERT diagonal_block_tile_a = room_and_item_graphic_records + (GRAPHIC_DIAGONAL_BLOCK_A-1)*16
ASSERT diagonal_block_tile_b = room_and_item_graphic_records + (GRAPHIC_DIAGONAL_BLOCK_B-1)*16
ASSERT striped_vertical_tile = room_and_item_graphic_records + (GRAPHIC_STRIPED_VERTICAL-1)*16
ASSERT uniform_pattern_tile = room_and_item_graphic_records + (GRAPHIC_UNIFORM_PATTERN-1)*16
ASSERT double_bar_tile = room_and_item_graphic_records + (GRAPHIC_DOUBLE_BAR-1)*16
ASSERT pillar_base_tile = room_and_item_graphic_records + (GRAPHIC_PILLAR_BASE-1)*16
ASSERT room_and_item_graphic_records_source = room_and_item_graphic_records
ASSERT room_and_item_graphic_records_source_end = display_action_jump_table
COPYBLOCK room_and_item_graphic_records_source, room_and_item_graphic_records_source_end, &2610
CLEAR room_and_item_graphic_records_source, room_and_item_graphic_records_source_end

ORG room_tile_pair_sets
; Runtime 1D90-1DC3: thirteen four-byte tile-pair sets selected by appearance.
.room_tile_pair_sets_source
    EQUB &D0, &D1, &91, &90
    EQUB &02, &01, &01, &02
    EQUB &05, &45, &45, &05
    EQUB &1A, &1B, &5B, &5A
    EQUB &4E, &4F, &0F, &0E
    EQUB &68, &20, &1E, &00
    EQUB &03, &04, &04, &03
    EQUB &C6, &DC, &86, &9C
    EQUB &1E, &20, &20, &1E
    EQUB &6A, &7A, &7A, &6A
    EQUB &9F, &97, &DF, &D7
    EQUB &07, &07, &07, &07
    EQUB &82, &81, &81, &82
.room_tile_pair_sets_source_end
ASSERT room_tile_pair_sets_source = room_tile_pair_sets
ASSERT room_tile_pair_sets_source_end = draw_matching_records_from_table
COPYBLOCK room_tile_pair_sets_source, room_tile_pair_sets_source_end, &3590
CLEAR room_tile_pair_sets_source, room_tile_pair_sets_source_end

ORG room_moving_object_pointer_sets
; Runtime 1F0F-1F2E: four sets of four little-endian graphic pointers. They are
; the four-direction caterpillar; the fish's right- and left-facing graphics;
; the mouse's right- and left-facing graphics; and the vertical lift graphic.
; These room-local creature/puzzle graphics are separate from the room-enemy pairs
; selected by the descriptor table at $1FDF.
.room_moving_object_pointer_sets_source
.caterpillar_graphic_pointer_set
    EQUW runtime_caterpillar_direction_frame_0, runtime_caterpillar_direction_frame_1
    EQUW runtime_caterpillar_direction_frame_2, runtime_caterpillar_direction_frame_3
.fish_graphic_pointer_set
    EQUW runtime_fish_facing_right_frame, fish_facing_left_and_herring_item_graphic_pair
    EQUW runtime_fish_facing_right_frame, fish_facing_left_and_herring_item_graphic_pair
.mouse_graphic_pointer_set
    EQUW runtime_mouse_facing_right_frame, mouse_facing_left_and_item_graphic_pair
    EQUW runtime_mouse_facing_right_frame, mouse_facing_left_and_item_graphic_pair
.vertical_lift_graphic_pointer_set
    EQUW vertical_lift_graphic, vertical_lift_graphic, vertical_lift_graphic, vertical_lift_graphic
.room_moving_object_pointer_sets_source_end
ASSERT caterpillar_graphic_pointer_set = room_moving_object_pointer_sets + ROOM_MOVING_OBJECT_CATERPILLAR*ROOM_MOVING_OBJECT_POINTER_SET_BYTES
ASSERT fish_graphic_pointer_set = room_moving_object_pointer_sets + ROOM_MOVING_OBJECT_FISH*ROOM_MOVING_OBJECT_POINTER_SET_BYTES
ASSERT mouse_graphic_pointer_set = room_moving_object_pointer_sets + ROOM_MOVING_OBJECT_MOUSE*ROOM_MOVING_OBJECT_POINTER_SET_BYTES
ASSERT vertical_lift_graphic_pointer_set = room_moving_object_pointer_sets + ROOM_MOVING_OBJECT_LIFT*ROOM_MOVING_OBJECT_POINTER_SET_BYTES
ASSERT room_moving_object_pointer_sets_source = room_moving_object_pointer_sets
ASSERT room_moving_object_pointer_sets_source_end = initialise_room_enemy_from_table
COPYBLOCK room_moving_object_pointer_sets_source, room_moving_object_pointer_sets_source_end, &370F
CLEAR room_moving_object_pointer_sets_source, room_moving_object_pointer_sets_source_end

ORG item_and_goal_record_table
; Runtime 0900-092F: twelve mutable item/goal records.
.item_and_goal_record_table_source
    EQUB &08, &06, &19, &1A
    EQUB &01, &01, &11, &10
    EQUB &04, &00, &11, &15
    EQUB &08, &07, &08, &16
    EQUB &05, &07, &13, &20
    EQUB &02, &00, &19, &1D
    EQUB &0A, &00, &11, &1A
    EQUB &0A, &00, &11, &28
    EQUB &01, &05, &17, &36
    EQUB &02, &07, &19, &12
    EQUB &03, &05, &12, &16
    EQUB &01, &01, &0A, &45
.item_and_goal_record_table_source_end
ASSERT item_and_goal_record_table_source_end-item_and_goal_record_table_source = ITEM_GOAL_RECORD_COUNT*ITEM_GOAL_RECORD_BYTES
ASSERT item_and_goal_record_table_source = item_and_goal_record_table
ASSERT item_and_goal_record_table_source_end = &0930
COPYBLOCK item_and_goal_record_table_source, item_and_goal_record_table_source_end, &2200
CLEAR item_and_goal_record_table_source, item_and_goal_record_table_source_end

ORG room_moving_object_record_table
; Runtime 0930-097F: sixteen room-local creature/lift records. The second byte's
; high nibble selects ROOM_MOVING_OBJECT_*; the comments decode the packed room.
.room_moving_object_record_table_source
    EQUB &40, &01, &10, &1D, &46 ; B0 caterpillar
    EQUB &03, &00, &18, &30, &46 ; A3 caterpillar
    EQUB &05, &01, &18, &04, &1B ; B5 caterpillar
    EQUB &C4, &02, &13, &10, &2B ; C4 caterpillar
    EQUB &01, &02, &0A, &2C, &3C ; C1 caterpillar
    EQUB &42, &01, &18, &23, &4A ; B2 caterpillar
    EQUB &81, &26, &19, &1A, &33 ; G1 mouse
    EQUB &00, &05, &10, &1D, &2F ; F0 caterpillar
    EQUB &02, &32, &0F, &14, &3F ; C2 lift
    EQUB &03, &33, &0E, &04, &18 ; D3 lift
    EQUB &03, &06, &0A, &0E, &2D ; G3 caterpillar
    EQUB &04, &36, &0C, &1C, &40 ; G4 lift
    EQUB &05, &06, &12, &20, &3B ; G5 caterpillar
    EQUB &09, &26, &19, &1A, &33 ; G9 mouse
    EQUB &07, &14, &16, &00, &2F ; E7 fish
    EQUB &06, &04, &10, &24, &45 ; E6 caterpillar
.room_moving_object_record_table_source_end
ASSERT room_moving_object_record_table_source = room_moving_object_record_table
ASSERT room_moving_object_record_table_source_end = &0980
COPYBLOCK room_moving_object_record_table_source, room_moving_object_record_table_source_end, &2230
CLEAR room_moving_object_record_table_source, room_moving_object_record_table_source_end

ORG initial_item_and_goal_record_table
; Runtime 0980-09AF: twelve pristine new-game item/goal records.
.initial_item_and_goal_record_table_source
    EQUB &08, &06, &19, &08
    EQUB &01, &01, &11, &10
    EQUB &04, &00, &11, &15
    EQUB &08, &07, &08, &16
    EQUB &05, &07, &13, &20
    EQUB &02, &00, &19, &1D
    EQUB &0A, &00, &11, &1A
    EQUB &0A, &00, &11, &28
    EQUB &01, &05, &17, &36
    EQUB &02, &07, &19, &12
    EQUB &03, &05, &12, &16
    EQUB &07, &05, &11, &24
.initial_item_and_goal_record_table_source_end
ASSERT initial_item_and_goal_record_table_source_end-initial_item_and_goal_record_table_source = ITEM_GOAL_RECORD_COUNT*ITEM_GOAL_RECORD_BYTES
ASSERT initial_item_and_goal_record_table_source = initial_item_and_goal_record_table
ASSERT initial_item_and_goal_record_table_source_end = &09B0
COPYBLOCK initial_item_and_goal_record_table_source, initial_item_and_goal_record_table_source_end, &2280
CLEAR initial_item_and_goal_record_table_source, initial_item_and_goal_record_table_source_end

ORG room_appearance_table
; Runtime 09B0-09FF: ten rows of eight room appearance bytes.
.room_appearance_table_source
    EQUB &03, &13, &06, &06, &32, &92, &16, &16
    EQUB &67, &12, &83, &26, &13, &13, &16, &65
    EQUB &66, &33, &A2, &26, &C3, &36, &62, &17
    EQUB &A6, &26, &53, &63, &96, &15, &36, &82
    EQUB &63, &13, &52, &09, &35, &42, &62, &B6
    EQUB &62, &06, &92, &42, &42, &43, &42, &73
    EQUB &07, &23, &0B, &12, &45, &56, &15, &26
    EQUB &0B, &23, &42, &16, &53, &36, &05, &60
    EQUB &6A, &16, &16, &16, &16, &16, &12, &13
    EQUB &15, &16, &16, &16, &72, &12, &C3, &B2
.room_appearance_table_source_end
ASSERT room_appearance_table_source = room_appearance_table
ASSERT room_appearance_table_source_end = &0A00
COPYBLOCK room_appearance_table_source, room_appearance_table_source_end, &22B0
CLEAR room_appearance_table_source, room_appearance_table_source_end

ORG room_enemy_record_table
; Runtime 0A00-0A77: twenty six-byte room-enemy records. The matched packed
; room reference leaves the low nibble as the last even slot and the high
; nibble as ENEMY_SPECIES_*; the remaining four bytes initialise movement
; positions and limits.
.room_enemy_record_table_source
    EQUB &05, &01, &06, &11, &18, &1C ; B5 bat
    EQUB &03, &12, &05, &04, &1A, &1E ; C3 small bouncing robot
    EQUB &41, &15, &02, &00, &0C, &4A ; F1 small bouncing robot
    EQUB &40, &03, &06, &11, &11, &3C ; D0 bat
    EQUB &41, &00, &03, &21, &18, &2C ; A1 bat
    EQUB &01, &12, &03, &18, &0B, &49 ; C1 small bouncing robot
    EQUB &43, &11, &07, &14, &17, &43 ; B3 small bouncing robot
    EQUB &06, &11, &04, &06, &0B, &3E ; B6 small bouncing robot
    EQUB &45, &22, &04, &00, &11, &2B ; C5 moth
    EQUB &02, &06, &06, &1D, &08, &28 ; E5 moth
    EQUB &45, &24, &04, &00, &14, &40 ; F4 moth
    EQUB &42, &14, &06, &34, &18, &4B ; E4 moth
    EQUB &02, &10, &17, &15, &18, &4B ; G2 bat
    EQUB &03, &04, &04, &00, &13, &3E ; E3 bat
    EQUB &44, &25, &04, &15, &14, &32 ; H7 moth
    EQUB &04, &24, &04, &08, &19, &2E ; D6 bat
    EQUB &47, &27, &06, &0A, &18, &42 ; D7 moth
    EQUB &06, &03, &0C, &10, &12, &3B ; C7 small bouncing robot
    EQUB &47, &12, &05, &07, &12, &49 ; A2 small bouncing robot
    EQUB &47, &23, &04, &00, &19, &41 ; E2 small bouncing robot
.room_enemy_record_table_source_end
ASSERT room_enemy_record_table_source = room_enemy_record_table
ASSERT room_enemy_record_table_source_end-room_enemy_record_table_source = ROOM_ENEMY_RECORD_COUNT*ROOM_ENEMY_RECORD_BYTES
ASSERT room_enemy_record_table_source_end = &0A78
COPYBLOCK room_enemy_record_table_source, room_enemy_record_table_source_end, &2300
CLEAR room_enemy_record_table_source, room_enemy_record_table_source_end

ORG cross_room_robot_ghost_record_table
; Runtime $0A78-$0A95: ten per-level cross-room robot/ghost records, one per level.
; These are separate from the room-enemy table. Levels 0-7 select the small
; bouncing robot frames; levels 8-9 select the ghost frames. Only those two
; enemy classes use this cross-room subsystem.
.cross_room_robot_ghost_record_table_source
    EQUB &51, &8D, &0F
    EQUB &1D, &46, &07
    EQUB &8C, &76, &13
    EQUB &7B, &7E, &0A
    EQUB &60, &3A, &11
    EQUB &69, &7A, &18
    EQUB &4D, &8E, &08
    EQUB &6A, &94, &0B
    EQUB &28, &3F, &19
    EQUB &60, &7F, &1C
.cross_room_robot_ghost_record_table_source_end
ASSERT cross_room_robot_ghost_record_table_source = cross_room_robot_ghost_record_table
ASSERT cross_room_robot_ghost_record_table_source_end-cross_room_robot_ghost_record_table_source = CROSS_ROOM_ROBOT_GHOST_RECORD_COUNT*CROSS_ROOM_ROBOT_GHOST_RECORD_BYTES
ASSERT cross_room_robot_ghost_record_table_source_end = &0A96
COPYBLOCK cross_room_robot_ghost_record_table_source, cross_room_robot_ghost_record_table_source_end, &2378
CLEAR cross_room_robot_ghost_record_table_source, cross_room_robot_ghost_record_table_source_end

ORG lift_and_hazard_room_record_table
; Runtime 0A96-0AF9: twenty lift/hazard room records. The second byte's high
; nibble selects LIFT_OR_HAZARD_*; the comments decode the packed room.
.lift_and_hazard_room_record_table_source
    EQUB &44, &00, &08, &07, &1B ; A4 lift
    EQUB &42, &01, &28, &0C, &16 ; B2 lift
    EQUB &06, &01, &44, &14, &1B ; B6 lift
    EQUB &02, &16, &1E, &0C, &13 ; G2 moth-shaped hazard
    EQUB &41, &10, &08, &04, &13 ; A1 moth-shaped hazard
    EQUB &03, &11, &06, &07, &10 ; B3 moth-shaped hazard
    EQUB &40, &12, &14, &0C, &16 ; C0 moth-shaped hazard
    EQUB &48, &16, &08, &11, &18 ; G8 moth-shaped hazard, first
    EQUB &00, &15, &26, &05, &10 ; F0 moth-shaped hazard
    EQUB &08, &14, &10, &08, &0E ; E8 moth-shaped hazard
    EQUB &05, &14, &21, &09, &11 ; E5 moth-shaped hazard
    EQUB &08, &16, &00, &14, &18 ; G8 moth-shaped hazard, second
    EQUB &05, &16, &2E, &0C, &12 ; G5 moth-shaped hazard
    EQUB &07, &17, &26, &0E, &18 ; H7 moth-shaped hazard
    EQUB &44, &17, &18, &05, &0C ; H4 moth-shaped hazard
    EQUB &03, &14, &2E, &04, &12 ; E3 moth-shaped hazard
    EQUB &42, &12, &34, &05, &13 ; C2 moth-shaped hazard
    EQUB &06, &14, &40, &0D, &19 ; E6 moth-shaped hazard
    EQUB &08, &11, &26, &04, &15 ; B8 moth-shaped hazard
    EQUB &45, &13, &38, &11, &16 ; D5 moth-shaped hazard
.lift_and_hazard_room_record_table_source_end
ASSERT lift_and_hazard_room_record_table_source = lift_and_hazard_room_record_table
ASSERT lift_and_hazard_room_record_table_source_end-lift_and_hazard_room_record_table_source = LIFT_HAZARD_RECORD_COUNT*LIFT_HAZARD_RECORD_BYTES
ASSERT lift_and_hazard_room_record_table_source_end = &0AFA
COPYBLOCK lift_and_hazard_room_record_table_source, lift_and_hazard_room_record_table_source_end, &2396
CLEAR lift_and_hazard_room_record_table_source, lift_and_hazard_room_record_table_source_end

ORG unused_runtime_low_tail_bytes
; loaded $23FA-$23FF. These six bytes lie after the exact
; twenty-record entity table and before the independent JMP entry at $0B00.
; No static or committed dynamic reference reads or executes them, so they are
; retained as proved-unused boundary data rather than invented as a twenty-first
; entity record or false instructions.
.unused_runtime_low_tail_bytes_source
    EQUB &7C, &0E, &4C, &44, &59, &63
.unused_runtime_low_tail_bytes_source_end
ASSERT unused_runtime_low_tail_bytes_source_end = relocated_game_entry
COPYBLOCK unused_runtime_low_tail_bytes_source, unused_runtime_low_tail_bytes_source_end, &23FA
CLEAR unused_runtime_low_tail_bytes_source, unused_runtime_low_tail_bytes_source_end

; Short, explicitly identified source islands that previously occupied
; separate generated authority slices.
ORG graphic_copy_alignment_padding
.graphic_copy_alignment_padding_source
    EQUB &00
.graphic_copy_alignment_padding_source_end
ASSERT graphic_copy_alignment_padding_source = graphic_copy_alignment_padding
ASSERT graphic_copy_alignment_padding_source_end = apply_mirror_flag_then_copy_graphic
COPYBLOCK graphic_copy_alignment_padding_source, graphic_copy_alignment_padding_source_end, &34D7
CLEAR graphic_copy_alignment_padding_source, graphic_copy_alignment_padding_source_end

ORG enemy_graphic_descriptor_table
; Four decoded graphic pairs selected by room-entity type at $1FB9. The fourth
; jellyfish pair is present but no six-byte room record selects it.
.enemy_graphic_descriptor_table_source
.bat_graphic_descriptor
    EQUW runtime_bat_wings_raised_frame, runtime_bat_wings_lowered_frame
.small_bouncing_robot_graphic_descriptor
    EQUW runtime_small_bouncing_robot_frame_0, runtime_small_bouncing_robot_frame_1
.moth_graphic_descriptor
    EQUW runtime_moth_and_hazard_frame_0, runtime_moth_and_hazard_frame_1
.jellyfish_graphic_descriptor
    EQUW runtime_jellyfish_frame_0, runtime_jellyfish_frame_1 ; unselected here
.enemy_graphic_descriptor_table_source_end
ASSERT bat_graphic_descriptor = enemy_graphic_descriptor_table + ENEMY_SPECIES_BAT*ENEMY_GRAPHIC_DESCRIPTOR_BYTES
ASSERT small_bouncing_robot_graphic_descriptor = enemy_graphic_descriptor_table + ENEMY_SPECIES_SMALL_ROBOT*ENEMY_GRAPHIC_DESCRIPTOR_BYTES
ASSERT moth_graphic_descriptor = enemy_graphic_descriptor_table + ENEMY_SPECIES_MOTH*ENEMY_GRAPHIC_DESCRIPTOR_BYTES
ASSERT jellyfish_graphic_descriptor = enemy_graphic_descriptor_table + ENEMY_SPECIES_JELLYFISH*ENEMY_GRAPHIC_DESCRIPTOR_BYTES
ASSERT enemy_graphic_descriptor_table_source = enemy_graphic_descriptor_table
ASSERT enemy_graphic_descriptor_table_source_end = initialise_lifts_and_hazards_from_table
COPYBLOCK enemy_graphic_descriptor_table_source, enemy_graphic_descriptor_table_source_end, &37DF
CLEAR enemy_graphic_descriptor_table_source, enemy_graphic_descriptor_table_source_end


; Loaded-only relocation loader, assembled in scratch space so its absolute
; calls and jumps retain the load-view addresses below. Relative branches use
; source-local labels and therefore retain the same byte displacements.
ORG &8100
.relocation_loader_source
    JSR set_vdu_window_then_continue_loader
    JSR install_runtime_vectors_and_disable_via_irqs
    JMP enter_relocated_game

.copy_loaded_low_block_to_runtime_source
    LDA #LO(QUEST1_LOAD_ADDRESS)
    STA graphic_source_pointer_low
    LDA #HI(QUEST1_LOAD_ADDRESS)
    STA graphic_source_pointer_high
    LDA #LO(player_enemy_and_lift_xor_sprite_frames)
    STA display_pointer_low
    LDA #HI(player_enemy_and_lift_xor_sprite_frames)
    STA display_pointer_high
    LDY #&00
.copy_loaded_low_byte
    LDA (graphic_source_pointer_low),Y
    STA (display_pointer_low),Y
    INC graphic_source_pointer_low
    BNE copy_loaded_low_source_advanced
    INC graphic_source_pointer_high
.copy_loaded_low_source_advanced
    INC display_pointer_low
    BNE copy_loaded_low_destination_advanced
    INC display_pointer_high
.copy_loaded_low_destination_advanced
    LDA graphic_source_pointer_high
    CMP #HI(loaded_high_block_source)
    BEQ copy_loaded_high_block_source
    JMP loaded_copy_low_byte_loop

.copy_loaded_high_block_source
    LDA #LO(loaded_high_block_source)
    STA graphic_source_pointer_low
    LDA #HI(loaded_high_block_source)
    STA graphic_source_pointer_high
    LDA #LO(room_and_item_graphic_bank)
    STA display_pointer_low
    LDA #HI(room_and_item_graphic_bank)
    STA display_pointer_high
    LDY #&00
.copy_loaded_high_byte
    LDA (graphic_source_pointer_low),Y
    STA (display_pointer_low),Y
    INC graphic_source_pointer_low
    BNE copy_loaded_high_source_advanced
    INC graphic_source_pointer_high
.copy_loaded_high_source_advanced
    INC display_pointer_low
    BNE copy_loaded_high_destination_advanced
    INC display_pointer_high
.copy_loaded_high_destination_advanced
    LDA graphic_source_pointer_high
    CMP #HI(relocation_transport_source_start)
    BEQ copy_transient_decoder_source
    JMP loaded_copy_high_byte_loop

.copy_transient_decoder_source
    LDX #&00
.copy_transient_decoder_byte
    LDA relocation_transport_source_start,X
    STA transient_xor_message_decoder,X
    INX
    CPX #relocation_irq_source_start-relocation_transport_source_start
    BNE copy_transient_decoder_byte
    RTS

.install_runtime_vectors_source
    LDA #&83
    STA EVNTV
    LDA #&0B
    STA EVNTV+1
    LDA #OSBYTE_SET_ESCAPE_BREAK_EFFECT
    LDX #ESCAPE_BREAK_EFFECT_DISABLE_ESCAPE
    JSR OSBYTE
    LDA #OSBYTE_ENABLE_EVENT
    LDX #&05
    JSR OSBYTE
    LDA IRQ1V
    STA chained_irq1v_vector
    LDA IRQ1V+1
    STA chained_irq1v_vector+1
    SEI
    LDA #LO(irq1v_handler)
    STA IRQ1V
    LDA #HI(irq1v_handler)
    STA IRQ1V+1
    CLI
    LDA #&7F
    STA USER_VIA_INTERRUPT_ENABLE
    STA USER_VIA_INTERRUPT_ENABLE_ALIAS
    STA SYSTEM_VIA_INTERRUPT_ENABLE
    STA SYSTEM_VIA_INTERRUPT_ENABLE_ALIAS
    LDA #&C2
    STA SYSTEM_VIA_INTERRUPT_ENABLE
    LDA #&40
    STA USER_VIA_AUXILIARY_CONTROL
    LDA #&A0
    STA USER_VIA_INTERRUPT_ENABLE
    RTS

    NOP                             ; loaded $5A3B alignment byte

.configure_crtc_and_copy_irq_source
    LDA #&06
    STA CRTC_ADDRESS_SELECT
    LDA #&1B
    STA CRTC_DATA
    LDA #&07
    STA CRTC_ADDRESS_SELECT
    LDA #&20
    STA CRTC_DATA
    LDA #&0C
    STA CRTC_ADDRESS_SELECT
    LDA #&07
    STA CRTC_DATA
    LDA #&0D
    STA CRTC_ADDRESS_SELECT
    LDA #&90
    STA CRTC_DATA
    LDA #&02
    STA CRTC_ADDRESS_SELECT
    LDX #&00
.copy_irq_workspace_byte
    LDA relocation_irq_source_start,X
    STA chained_irq1v_vector,X
    INX
    CPX #&61
    BNE copy_irq_workspace_byte
    SEI
    JMP copy_loaded_low_block_to_runtime

.set_vdu_window_then_continue_loader_source
    LDA #VDU_DEFINE_TEXT_WINDOW
    JSR OSWRCH
    LDA #&00
    JSR OSWRCH
    LDA #&1E
    JSR OSWRCH
    LDA #&27
    JSR OSWRCH
    LDA #&00
    JSR OSWRCH
    JMP configure_crtc_and_copy_irq_workspace

.enter_relocated_game_source
    LDA #&00
    STA mos_keyboard_state_workspace                       ; MOS keyboard-state workspace
    JMP relocated_game_entry
.relocation_loader_source_end

ASSERT relocation_loader_source_end-relocation_loader_source = &11E
ASSERT copy_loaded_low_block_to_runtime_source-relocation_loader_source+loader_initialization_entry = copy_loaded_low_block_to_runtime
ASSERT copy_loaded_high_block_source-relocation_loader_source+loader_initialization_entry = copy_loaded_high_block_to_runtime
ASSERT copy_transient_decoder_source-relocation_loader_source+loader_initialization_entry = copy_transient_decoder_to_stack_page
ASSERT install_runtime_vectors_source-relocation_loader_source+loader_initialization_entry = install_runtime_vectors_and_disable_via_irqs
ASSERT configure_crtc_and_copy_irq_source-relocation_loader_source+loader_initialization_entry = configure_crtc_and_copy_irq_workspace
ASSERT set_vdu_window_then_continue_loader_source-relocation_loader_source+loader_initialization_entry = set_vdu_window_then_continue_loader
ASSERT enter_relocated_game_source-relocation_loader_source+loader_initialization_entry = enter_relocated_game
COPYBLOCK relocation_loader_source, relocation_loader_source_end, loader_initialization_entry
CLEAR relocation_loader_source, relocation_loader_source_end


; Loaded $5A9E-$5AFF. Literal dormant message immediately after the loader,
; followed by six zero bytes. The high relocation also copies these bytes to
; display RAM $429E-$42FF; no code or pointer reference to the text is known.
ORG &8300
.embedded_mountaineering_message_source
    EQUS "e Mountaineering Club.'Swing out Sister for Break-out. And goodluck Sally were ever you are!"
    EQUB &00, &00, &00, &00, &00, &00
.embedded_mountaineering_message_source_end
ASSERT embedded_mountaineering_message_source_end-embedded_mountaineering_message_source = &62
COPYBLOCK embedded_mountaineering_message_source, embedded_mountaineering_message_source_end, &5A9E
CLEAR embedded_mountaineering_message_source, embedded_mountaineering_message_source_end


; Loaded $5B00-$5B0E, copied verbatim to $0100 before gameplay. X selects one
; of the payload offsets. Each byte is XORed with the corresponding byte at
; $7000,X and sent to OSWRCH; a zero XOR result terminates the tail-called
; stream and returns directly to the caller of the $328F dispatcher.
ORG transient_xor_message_decoder
.transient_xor_message_decoder_source
.decode_transient_xor_message_byte
    LDA transient_xor_message_payload,X
    EOR xor_decoder_display_sample_page,X
    BEQ transient_xor_message_finished
    JSR OSWRCH
    INX
    BNE decode_transient_xor_message_byte
.transient_xor_message_finished
    RTS
.transient_xor_message_decoder_source_end
ASSERT transient_xor_message_decoder_source_end = &010F
COPYBLOCK transient_xor_message_decoder_source, transient_xor_message_decoder_source_end, &5B00
CLEAR transient_xor_message_decoder_source, transient_xor_message_decoder_source_end

ORG &010F
.transient_xor_message_payload
    EQUB &10, &4B, &7D, &58, &4F, &55, &20, &52, &AB, &BE, &AE, &83, &80, &DD, &6D, &50
    EQUB &88, &89, &DC, &1D, &32, &28, &54, &5B, &BF, &91, &5E, &51, &2C, &20, &57, &45
    EQUB &2F, &03, &28, &4F, &27, &54, &20, &53, &AB, &A5, &B6, &85, &E1, &DC, &73, &58
    EQUB &8E, &85, &CC, &6F, &0C, &2D, &59, &0B, &EF, &C1, &16, &4B, &4F, &4E, &47, &52
    EQUB &4E, &13, &32, &4D, &41, &54, &49, &4F, &A0, &A4, &C0, &99, &8E, &DA, &03, &55
    EQUB &99, &9F, &DD, &6E, &7B, &68, &68, &49, &D0, &87, &5E, &41, &4E, &4B, &2C, &1F
    EQUB &08, &5B, &25, &54, &54, &20, &44, &4F, &A0, &D0, &B4, &E0, &87, &C0, &71, &56
    EQUB &99, &98, &B8, &68, &62, &0D, &0D, &46, &A4, &86, &5E, &17, &0C, &1E, &4F, &55
    EQUB &5D, &67, &24, &4E, &4D, &50, &45, &54, &A7, &B8, &AE, &E1, &D0, &8E, &23
.transient_xor_message_payload_end
ASSERT transient_xor_message_payload_end = &019E
COPYBLOCK transient_xor_message_payload, transient_xor_message_payload_end, &5B0F
CLEAR transient_xor_message_payload, transient_xor_message_payload_end

ORG &019E
.transient_stack_page_padding_source
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
    EQUB &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF, &FF
.transient_stack_page_padding_source_end
ASSERT transient_stack_page_padding_source_end = &01B0
COPYBLOCK transient_stack_page_padding_source, transient_stack_page_padding_source_end, &5B9E
CLEAR transient_stack_page_padding_source, transient_stack_page_padding_source_end

ORG chained_irq1v_vector
.irq_workspace_prefix_source
    EQUW NULL_POINTER               ; replaced with the previous IRQ1V by loader
    EQUB &00                        ; lower-screen palette base initial value
.irq_workspace_prefix_source_end
ASSERT irq_workspace_prefix_source_end = irq1v_handler
COPYBLOCK irq_workspace_prefix_source, irq_workspace_prefix_source_end, &5BB0
CLEAR irq_workspace_prefix_source, irq_workspace_prefix_source_end


; Loaded $5C10 is the final byte copied by the loader to IRQ workspace $03E0.
; It is a zero immediately after the installed handler, not part of the DFS
; entry which starts at the catalogue execution address $5C11.
ORG &03E0
.irq_relocation_trailing_zero_source
    EQUB &00
.irq_relocation_trailing_zero_source_end
ASSERT irq_relocation_trailing_zero_source_end = &03E1
COPYBLOCK irq_relocation_trailing_zero_source, irq_relocation_trailing_zero_source_end, &5C10
CLEAR irq_relocation_trailing_zero_source, irq_relocation_trailing_zero_source_end


; Loaded-only DFS execution stub at $5C11-$5C1F. This code is outside every
; relocated runtime segment. It makes the two observed MOS OSBYTE calls with
; A=$E1/X=0 and A=$8C, then transfers control to the loader at $5980.
ORG &8000
.dfs_execution_entry_stub_source
    LDA #OSBYTE_READ_KEYBOARD_STATUS
    LDX #&00
    JSR OSBYTE
    LDA #&8C
    JSR OSBYTE
    JMP loader_initialization_entry
.dfs_execution_entry_stub_source_end
ASSERT dfs_execution_entry_stub_source = &8000
ASSERT dfs_execution_entry_stub_source_end = &800F
COPYBLOCK dfs_execution_entry_stub_source, dfs_execution_entry_stub_source_end, dfs_execution_entry_stub
CLEAR dfs_execution_entry_stub_source, dfs_execution_entry_stub_source_end


; Install the two staged XOR graphic-bank parts only after every relocated
; routine that assembles in the aliased $1D00-$217F address window is finished.
COPYBLOCK player_enemy_and_lift_xor_sprite_frames_source, player_enemy_and_lift_xor_sprite_frames_end, &1D00
COPYBLOCK inert_xor_sprite_frame_block_source, inert_xor_sprite_frame_block_end, &2100
CLEAR player_enemy_and_lift_xor_sprite_frames_source, player_enemy_and_lift_xor_sprite_frames_end
CLEAR inert_xor_sprite_frame_block_source, inert_xor_sprite_frame_block_end



; Complete source-owned transport image. No generated layout include or binary
; authority slice is required: every byte from $1D00 through $5C1F has been
; emitted above by source assembly/data and COPYBLOCK.
ORG &1D00
.quest1_load_start
ORG &5C20
.quest1_load_end
ASSERT quest1_load_end-quest1_load_start = &3F20
SAVE "build/reconstruction/QUEST1", quest1_load_start, quest1_load_end, QUEST1_EXECUTION_ADDRESS
