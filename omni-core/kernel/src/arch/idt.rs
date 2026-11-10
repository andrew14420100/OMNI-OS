// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! IDT e ingressi delle interruzioni. Gli stub in assembly salvano tutti i registri generali
//! in una `Cornice` e chiamano `omni_interruzione` (Rust, convenzione C): nessuna funzione
//! instabile del compilatore (ADR-0007).

use super::gdt;
use core::arch::{asm, global_asm};

/// Registri salvati dallo stub, nell'ordine in cui si trovano sullo stack.
#[repr(C)]
#[derive(Debug)]
pub struct Cornice {
    pub r15: u64,
    pub r14: u64,
    pub r13: u64,
    pub r12: u64,
    pub r11: u64,
    pub r10: u64,
    pub r9: u64,
    pub r8: u64,
    pub rbp: u64,
    pub rdi: u64,
    pub rsi: u64,
    pub rdx: u64,
    pub rcx: u64,
    pub rbx: u64,
    pub rax: u64,
    pub vettore: u64,
    pub errore: u64,
    pub rip: u64,
    pub cs: u64,
    pub rflags: u64,
    pub rsp: u64,
    pub ss: u64,
}

// Vettori con codice d'errore spinto dalla CPU: 8, 10-14, 17, 21, 29, 30 (SDM vol. 3, 6.15).
global_asm!(
    r#"
.macro stub_senza n
.global omni_isr_\n
omni_isr_\n:
    push 0
    push \n
    jmp omni_isr_comune
.endm
.macro stub_con n
.global omni_isr_\n
omni_isr_\n:
    push \n
    jmp omni_isr_comune
.endm

.irp n, 0,1,2,3,4,5,6,7,9,15,16,18,19,20,22,23,24,25,26,27,28,31
stub_senza \n
.endr
.irp n, 8,10,11,12,13,14,17,21,29,30
stub_con \n
.endr
.irp n, 32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,255
stub_senza \n
.endr

omni_isr_comune:
    push rax
    push rbx
    push rcx
    push rdx
    push rsi
    push rdi
    push rbp
    push r8
    push r9
    push r10
    push r11
    push r12
    push r13
    push r14
    push r15
    mov rdi, rsp
    cld
    call omni_interruzione
    pop r15
    pop r14
    pop r13
    pop r12
    pop r11
    pop r10
    pop r9
    pop r8
    pop rbp
    pop rdi
    pop rsi
    pop rdx
    pop rcx
    pop rbx
    pop rax
    add rsp, 16
    iretq

.section .rodata
.balign 8
.global omni_isr_tabella
omni_isr_tabella:
.irp n, 0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47
    .quad omni_isr_\n
.endr
.global omni_isr_spuria
omni_isr_spuria:
    .quad omni_isr_255
.text
"#
);

extern "C" {
    static omni_isr_tabella: [u64; 48];
    static omni_isr_spuria: u64;
}

#[repr(C)]
#[derive(Clone, Copy)]
struct Voce {
    basso: u16,
    selettore: u16,
    ist: u8,
    tipo: u8,
    medio: u16,
    alto: u32,
    _r: u32,
}

impl Voce {
    const VUOTA: Self = Self { basso: 0, selettore: 0, ist: 0, tipo: 0, medio: 0, alto: 0, _r: 0 };
    fn porta(gestore: u64, ist: u8) -> Self {
        Self {
            basso: gestore as u16,
            selettore: gdt::CODICE_KERNEL,
            ist,
            tipo: 0x8e, // presente, DPL 0, interrupt gate a 64 bit
            medio: (gestore >> 16) as u16,
            alto: (gestore >> 32) as u32,
            _r: 0,
        }
    }
}

static mut IDT: [Voce; 256] = [Voce::VUOTA; 256];

pub const VETTORE_TIMER: u8 = 32;
pub const VETTORE_TASTIERA: u8 = 33;
pub const VETTORE_SPURIO: u8 = 255;

pub fn inizializza() {
    // SAFETY: eseguito una sola volta prima di attivare le interruzioni; la tabella è statica
    unsafe {
        let idt = &raw mut IDT;
        let tabella: [u64; 48] = (&raw const omni_isr_tabella).read();
        for (v, &g) in tabella.iter().enumerate() {
            let ist = match v {
                8 => gdt::IST_DOPPIO_ERRORE,
                2 => gdt::IST_NMI,
                _ => 0,
            };
            (*idt)[v] = Voce::porta(g, ist);
        }
        (*idt)[VETTORE_SPURIO as usize] = Voce::porta((&raw const omni_isr_spuria).read(), 0);
        #[repr(C, packed)]
        struct Puntatore {
            limite: u16,
            base: u64,
        }
        let p = Puntatore { limite: (core::mem::size_of::<[Voce; 256]>() - 1) as u16, base: idt as u64 };
        asm!("lidt [{}]", in(reg) &p, options(readonly, nostack, preserves_flags));
    }
}

pub fn nome_eccezione(v: u64) -> &'static str {
    match v {
        0 => "divisione per zero",
        1 => "debug",
        2 => "NMI",
        3 => "breakpoint",
        4 => "overflow",
        5 => "limite superato",
        6 => "istruzione non valida",
        7 => "dispositivo non disponibile",
        8 => "double fault",
        10 => "TSS non valido",
        11 => "segmento non presente",
        12 => "errore dello stack",
        13 => "protezione generale",
        14 => "page fault",
        16 => "errore x87",
        17 => "controllo di allineamento",
        18 => "machine check",
        19 => "errore SIMD",
        _ => "eccezione",
    }
}
