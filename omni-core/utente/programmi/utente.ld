/* Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
 * Programmi utente OMNI: caricati a 4 MiB, tre segmenti con permessi separati (W^X). */
ENTRY(_start)

PHDRS
{
  testo  PT_LOAD FLAGS(5);   /* R-X */
  sola   PT_LOAD FLAGS(4);   /* R-- */
  dati   PT_LOAD FLAGS(6);   /* RW- */
}

SECTIONS
{
  . = 0x400000;
  .text : { *(.text .text.*) } :testo
  . = ALIGN(4096);
  .rodata : { *(.rodata .rodata.*) } :sola
  .eh_frame_hdr : { *(.eh_frame_hdr) } :sola
  .eh_frame : { *(.eh_frame) } :sola
  . = ALIGN(4096);
  .data : { *(.data .data.*) *(.got .got.*) } :dati
  .bss : { *(.bss .bss.*) *(COMMON) } :dati
  . = ALIGN(4096);

  /DISCARD/ : { *(.comment) *(.note .note.*) }
}
