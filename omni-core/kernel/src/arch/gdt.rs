// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! GDT e TSS **per CPU** (ogni CPU ha il proprio TSS: il descrittore diventa "occupato" con
//! `ltr`) con stack dedicati (IST) per double fault (IST1) e NMI (IST2). Intel SDM vol. 3,
//! cap. 3 e 8.

use core::arch::asm;
use core::mem::size_of;
use omni_comune::acpi::MAX_CPU;

pub const CODICE_KERNEL: u16 = 0x08;
pub const DATI_KERNEL: u16 = 0x10;
const SELETTORE_TSS: u16 = 0x18;
pub const IST_DOPPIO_ERRORE: u8 = 1;
pub const IST_NMI: u8 = 2;

const DIM_STACK_IST: usize = 16 * 1024;

#[repr(C, align(16))]
struct StackIst([u8; DIM_STACK_IST]);

#[repr(C, packed)]
struct Tss {
    _r0: u32,
    rsp: [u64; 3],
    _r1: u64,
    ist: [u64; 7],
    _r2: u64,
    _r3: u16,
    iomap: u16,
}

#[repr(C, align(16))]
struct DatiCpu {
    /// null, codice kernel (64 bit), dati kernel, TSS (2 voci).
    gdt: [u64; 5],
    tss: Tss,
    doppio_errore: StackIst,
    nmi: StackIst,
}

const VUOTO: DatiCpu = DatiCpu {
    gdt: [0, 0x00af_9a00_0000_ffff, 0x00cf_9200_0000_ffff, 0, 0],
    tss: Tss { _r0: 0, rsp: [0; 3], _r1: 0, ist: [0; 7], _r2: 0, _r3: 0, iomap: size_of::<Tss>() as u16 },
    doppio_errore: StackIst([0; DIM_STACK_IST]),
    nmi: StackIst([0; DIM_STACK_IST]),
};

static mut CPU: [DatiCpu; MAX_CPU] = [VUOTO; MAX_CPU];

#[repr(C, packed)]
struct Puntatore {
    limite: u16,
    base: u64,
}

/// Carica GDT e TSS della CPU `indice` (una sola volta per CPU, sulla CPU stessa).
pub fn inizializza(indice: usize) {
    assert!(indice < MAX_CPU);
    // SAFETY: ogni CPU tocca solo la propria voce dell'array, una volta, prima di attivare le
    // interruzioni; le strutture statiche restano valide per sempre
    unsafe {
        let d = &raw mut CPU[indice];
        let tss = &raw mut (*d).tss;
        (*tss).ist[(IST_DOPPIO_ERRORE - 1) as usize] = (&raw const (*d).doppio_errore) as u64 + DIM_STACK_IST as u64;
        (*tss).ist[(IST_NMI - 1) as usize] = (&raw const (*d).nmi) as u64 + DIM_STACK_IST as u64;
        let base = tss as u64;
        let limite = (size_of::<Tss>() - 1) as u64;
        // descrittore di sistema a 16 byte: TSS a 64 bit disponibile (tipo 0x9), presente
        let basso = (limite & 0xffff) | ((base & 0xff_ffff) << 16) | (0x89u64 << 40) | (((limite >> 16) & 0xf) << 48) | (((base >> 24) & 0xff) << 56);
        let gdt = &raw mut (*d).gdt;
        (*gdt)[3] = basso;
        (*gdt)[4] = base >> 32;
        let p = Puntatore { limite: (size_of::<[u64; 5]>() - 1) as u16, base: gdt as u64 };
        asm!(
            "lgdt [{p}]",
            // ricarica CS con un ritorno lontano, poi i segmenti dati
            "push {cs}",
            "lea {t}, [rip + 2f]",
            "push {t}",
            "retfq",
            "2:",
            "mov ds, {ds:x}",
            "mov es, {ds:x}",
            "mov ss, {ds:x}",
            "xor {t:e}, {t:e}",
            "mov fs, {t:x}",
            "mov gs, {t:x}",
            "ltr {tss:x}",
            p = in(reg) &p,
            cs = in(reg) CODICE_KERNEL as u64,
            ds = in(reg) DATI_KERNEL as u64,
            tss = in(reg) SELETTORE_TSS as u64,
            t = out(reg) _,
        );
    }
}
