// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Lettura delle tabelle ACPI statiche dalla memoria fisica (mappa diretta), con le
//! verifiche del modulo `omni_comune::acpi` (firme e somme di controllo).

use crate::mem::frame::virtuale;
use omni_comune::acpi::{self, Fadt, Madt, Rsdp};

pub struct InfoAcpi {
    pub rsdp: Rsdp,
    pub tabelle: usize,
    pub madt: Madt,
    pub hpet: u64,
    pub firme: [[u8; 4]; 24],
    pub fadt: Fadt,
    /// SLP_TYPa e SLP_TYPb dal pacchetto \_S5 della DSDT
    pub s5: Option<(u8, u8)>,
}

fn fetta(fisico: u64, n: usize) -> &'static [u8] {
    // SAFETY: tabelle ACPI (memoria riservata o recuperabile) raggiunte dalla mappa diretta;
    // la lunghezza viene dall'intestazione già letta e il contenuto è solo letto
    unsafe { core::slice::from_raw_parts(virtuale(fisico) as *const u8, n) }
}

fn tabella(fisico: u64) -> Option<&'static [u8]> {
    let n = acpi::lunghezza_sdt(fetta(fisico, 36))?;
    (36..=1 << 20).contains(&n).then(|| fetta(fisico, n))
}

pub fn leggi(rsdp_fisico: u64) -> Result<InfoAcpi, &'static str> {
    if rsdp_fisico == 0 {
        return Err("RSDP assente");
    }
    let rsdp = acpi::rsdp(fetta(rsdp_fisico, 36)).map_err(|_| "RSDP non valida")?;
    let xsdt = tabella(rsdp.xsdt).ok_or("XSDT illeggibile")?;
    let xsdt = acpi::verifica_sdt(xsdt, b"XSDT").map_err(|_| "XSDT non valida (firma o somma di controllo)")?;
    let mut info = InfoAcpi { rsdp, tabelle: 0, madt: Madt::default(), hpet: 0, firme: [[b' '; 4]; 24], fadt: Fadt::default(), s5: None };
    let mut madt = None;
    for ind in acpi::voci_xsdt(xsdt) {
        let Some(t) = tabella(ind) else { continue };
        if info.tabelle < info.firme.len() {
            info.firme[info.tabelle].copy_from_slice(&t[0..4]);
        }
        info.tabelle += 1;
        match &t[0..4] {
            b"APIC" => madt = Some(acpi::verifica_sdt(t, b"APIC").map_err(|_| "MADT non valida")?),
            b"HPET" => info.hpet = acpi::hpet_base(acpi::verifica_sdt(t, b"HPET").map_err(|_| "HPET non valida")?).map_err(|_| "HPET troncata")?,
            b"FACP" => info.fadt = acpi::fadt(acpi::verifica_sdt(t, b"FACP").map_err(|_| "FADT non valida")?).map_err(|_| "FADT troncata")?,
            _ => {}
        }
    }
    if info.fadt.dsdt != 0 {
        if let Some(d) = tabella(info.fadt.dsdt) {
            if let Ok(d) = acpi::verifica_sdt(d, b"DSDT") {
                info.s5 = acpi::s5(&d[36..]);
            }
        }
    }
    info.madt = acpi::madt(madt.ok_or("MADT assente")?).map_err(|_| "MADT illeggibile")?;
    Ok(info)
}
