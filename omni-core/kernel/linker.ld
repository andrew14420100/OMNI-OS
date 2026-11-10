/* Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
 * Kernel OMNI nella metà alta (ultimi 2 GiB): tre segmenti con permessi separati (W^X). */
ENTRY(_start)
BASE_KERNEL = 0xffffffff80000000;

PHDRS
{
  testo  PT_LOAD FLAGS(5);   /* R-X */
  sola   PT_LOAD FLAGS(4);   /* R-- */
  dati   PT_LOAD FLAGS(6);   /* RW- */
}

SECTIONS
{
  . = BASE_KERNEL;
  __testo_inizio = .;
  .text : { *(.text.ingresso) *(.text .text.*) } :testo
  . = ALIGN(4096);
  __testo_fine = .;

  __sola_inizio = .;
  .rodata : { *(.rodata .rodata.*) } :sola
  .eh_frame_hdr : { *(.eh_frame_hdr) } :sola
  .eh_frame : { *(.eh_frame) } :sola
  . = ALIGN(4096);
  __sola_fine = .;

  __dati_inizio = .;
  .data : { *(.data .data.*) *(.got .got.*) } :dati
  .bss : { *(.bss .bss.*) *(COMMON) } :dati
  . = ALIGN(4096);
  __dati_fine = .;

  /DISCARD/ : { *(.comment) *(.note .note.*) }
}
