// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Tabelle ACPI statiche (specifica ACPI 6.5, cap. 5): RSDP, intestazione SDT, XSDT,
//! MADT, HPET. Solo lettura e verifica su fette di byte: il kernel fornisce le fette
//! leggendo la memoria fisica, i test usano tabelle costruite a mano.

/// Somma di controllo: tutti i byte sommati devono dare 0 modulo 256.
pub fn checksum_ok(b: &[u8]) -> bool {
    b.iter().fold(0u8, |a, &x| a.wrapping_add(x)) == 0
}

fn u32_le(d: &[u8], o: usize) -> u32 {
    u32::from_le_bytes([d[o], d[o + 1], d[o + 2], d[o + 3]])
}
fn u64_le(d: &[u8], o: usize) -> u64 {
    let mut b = [0u8; 8];
    b.copy_from_slice(&d[o..o + 8]);
    u64::from_le_bytes(b)
}

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum ErroreAcpi {
    FirmaErrata,
    ChecksumErrato,
    VersioneNonSupportata,
    Troncata,
}

/// RSDP verificata (ACPI 2.0+: serve l'indirizzo della XSDT).
#[derive(Debug, Clone, Copy)]
pub struct Rsdp {
    pub revisione: u8,
    pub xsdt: u64,
    pub oem: [u8; 6],
}

/// `b` deve contenere almeno 36 byte a partire dalla RSDP.
pub fn rsdp(b: &[u8]) -> Result<Rsdp, ErroreAcpi> {
    if b.len() < 36 {
        return Err(ErroreAcpi::Troncata);
    }
    if &b[0..8] != b"RSD PTR " {
        return Err(ErroreAcpi::FirmaErrata);
    }
    if !checksum_ok(&b[0..20]) {
        return Err(ErroreAcpi::ChecksumErrato);
    }
    let revisione = b[15];
    if revisione < 2 {
        return Err(ErroreAcpi::VersioneNonSupportata);
    }
    let lunghezza = u32_le(b, 20) as usize;
    if lunghezza < 36 || lunghezza > b.len() || !checksum_ok(&b[..lunghezza]) {
        return Err(ErroreAcpi::ChecksumErrato);
    }
    let mut oem = [0u8; 6];
    oem.copy_from_slice(&b[9..15]);
    Ok(Rsdp { revisione, xsdt: u64_le(b, 24), oem })
}

/// Lunghezza dichiarata da un'intestazione SDT (primi 8 byte bastano).
pub fn lunghezza_sdt(intestazione: &[u8]) -> Option<usize> {
    (intestazione.len() >= 8).then(|| u32_le(intestazione, 4) as usize)
}

/// Verifica una tabella SDT completa con la firma attesa.
pub fn verifica_sdt<'a>(t: &'a [u8], firma: &[u8; 4]) -> Result<&'a [u8], ErroreAcpi> {
    if t.len() < 36 {
        return Err(ErroreAcpi::Troncata);
    }
    if &t[0..4] != firma {
        return Err(ErroreAcpi::FirmaErrata);
    }
    let n = u32_le(t, 4) as usize;
    if n < 36 || n > t.len() {
        return Err(ErroreAcpi::Troncata);
    }
    if !checksum_ok(&t[..n]) {
        return Err(ErroreAcpi::ChecksumErrato);
    }
    Ok(&t[..n])
}

/// Indirizzi fisici delle tabelle elencate dalla XSDT (già verificata).
pub fn voci_xsdt(xsdt: &[u8]) -> impl Iterator<Item = u64> + '_ {
    xsdt[36..].chunks_exact(8).map(|c| u64_le(c, 0))
}

/// Contenuto della MADT rilevante per K1.
#[derive(Debug, Default, Clone, Copy)]
pub struct Madt {
    pub apic_locale: u64,
    pub cpu_abilitate: u32,
    pub cpu_totali: u32,
    pub ioapic: u64,
    pub ioapic_gsi_base: u32,
    /// GSI della IRQ 0 (timer ISA) e della IRQ 1 (tastiera), dopo le sostituzioni.
    pub gsi_irq: [u32; 16],
    /// Flag di polarità/attivazione per IRQ ISA (dalle sostituzioni).
    pub flag_irq: [u16; 16],
    /// ID APIC delle CPU abilitate, nell'ordine della MADT (le prime `cpu_abilitate`).
    pub id_apic: [u8; MAX_CPU],
}

/// CPU gestite dal kernel K2.
pub const MAX_CPU: usize = 16;

/// Analizza una MADT ("APIC") già verificata.
pub fn madt(t: &[u8]) -> Result<Madt, ErroreAcpi> {
    if t.len() < 44 {
        return Err(ErroreAcpi::Troncata);
    }
    let mut m = Madt { apic_locale: u32_le(t, 36) as u64, ..Default::default() };
    for (i, g) in m.gsi_irq.iter_mut().enumerate() {
        *g = i as u32;
    }
    let mut o = 44;
    while o + 2 <= t.len() {
        let tipo = t[o];
        let len = t[o + 1] as usize;
        if len < 2 || o + len > t.len() {
            return Err(ErroreAcpi::Troncata);
        }
        let e = &t[o..o + len];
        match tipo {
            0 if len >= 8 => {
                // APIC locale del processore: bit 0 abilitato, bit 1 attivabile
                m.cpu_totali += 1;
                if u32_le(e, 4) & 0b11 != 0 {
                    if (m.cpu_abilitate as usize) < MAX_CPU {
                        m.id_apic[m.cpu_abilitate as usize] = e[3];
                    }
                    m.cpu_abilitate += 1;
                }
            }
            1 if len >= 12 && m.ioapic == 0 => {
                m.ioapic = u32_le(e, 4) as u64;
                m.ioapic_gsi_base = u32_le(e, 8);
            }
            2 if len >= 10 => {
                let irq = e[3] as usize;
                if irq < 16 {
                    m.gsi_irq[irq] = u32_le(e, 4);
                    m.flag_irq[irq] = u16::from_le_bytes([e[8], e[9]]);
                }
            }
            5 if len >= 12 => m.apic_locale = u64_le(e, 4),
            _ => {}
        }
        o += len;
    }
    Ok(m)
}

/// Indirizzo base dei registri HPET dalla tabella "HPET" verificata.
pub fn hpet_base(t: &[u8]) -> Result<u64, ErroreAcpi> {
    if t.len() < 56 {
        return Err(ErroreAcpi::Troncata);
    }
    // struttura Generic Address a offset 40: spazio (0 = memoria), poi indirizzo a +4
    Ok(u64_le(t, 44))
}

/// Campi della FADT ("FACP") usati per spegnimento e riavvio (ACPI 6.5, 5.2.9).
#[derive(Debug, Default, Clone, Copy, PartialEq, Eq)]
pub struct Fadt {
    pub dsdt: u64,
    /// Porta I/O del registro PM1a_CNT (0 se assente).
    pub pm1a_cnt: u32,
    pub pm1b_cnt: u32,
    /// Registro di reset: (spazio d'indirizzi: 0 memoria, 1 I/O), indirizzo, valore.
    pub reset: Option<(u8, u64, u8)>,
}

/// Analizza una FADT già verificata.
pub fn fadt(t: &[u8]) -> Result<Fadt, ErroreAcpi> {
    if t.len() < 116 {
        return Err(ErroreAcpi::Troncata);
    }
    let mut f = Fadt { dsdt: u32_le(t, 40) as u64, pm1a_cnt: u32_le(t, 64), pm1b_cnt: u32_le(t, 68), reset: None };
    let flag = u32_le(t, 112);
    if t.len() >= 129 && flag & (1 << 10) != 0 {
        f.reset = Some((t[116], u64_le(t, 120), t[128]));
    }
    if t.len() >= 148 {
        let x = u64_le(t, 140);
        if x != 0 {
            f.dsdt = x;
        }
    }
    // indirizzi estesi (ACPI 2.0+), solo se nello spazio I/O
    if t.len() >= 184 && t[172] == 1 && u64_le(t, 176) != 0 {
        f.pm1a_cnt = u64_le(t, 176) as u32;
    }
    if t.len() >= 196 && t[184] == 1 && u64_le(t, 188) != 0 {
        f.pm1b_cnt = u64_le(t, 188) as u32;
    }
    Ok(f)
}

/// Valori SLP_TYPa e SLP_TYPb dell'oggetto `\_S5` (spegnimento) nell'AML della DSDT.
/// Non è un interprete AML: legge solo la forma `Name(_S5, Package(){a, b, ...})`.
pub fn s5(aml: &[u8]) -> Option<(u8, u8)> {
    let mut i = 0;
    while i + 4 <= aml.len() {
        if &aml[i..i + 4] != b"_S5_" {
            i += 1;
            continue;
        }
        // deve essere preceduto da NameOp (0x08), eventualmente con il prefisso radice '\'
        let nome = i >= 1 && (aml[i - 1] == 0x08 || (i >= 2 && aml[i - 1] == b'\\' && aml[i - 2] == 0x08));
        let mut p = i + 4;
        if !nome || p >= aml.len() || aml[p] != 0x12 {
            i += 4;
            continue;
        }
        p += 1; // PackageOp
        let lunghezza_extra = (aml.get(p)? >> 6) as usize;
        p += 1 + lunghezza_extra; // PkgLength
        p += 1; // NumElements
        let mut valori = [0u8; 2];
        for v in valori.iter_mut() {
            let op = *aml.get(p)?;
            match op {
                0x0a => {
                    *v = *aml.get(p + 1)?;
                    p += 2;
                }
                0x0b => {
                    *v = *aml.get(p + 1)?;
                    p += 3;
                }
                0x0c => {
                    *v = *aml.get(p + 1)?;
                    p += 5;
                }
                0x00 => {
                    *v = 0;
                    p += 1;
                }
                0x01 => {
                    *v = 1;
                    p += 1;
                }
                altro => {
                    *v = altro;
                    p += 1;
                }
            }
        }
        return Some((valori[0], valori[1]));
    }
    None
}

#[cfg(test)]
mod test {
    use super::*;
    use std::vec::Vec;

    fn sistema_checksum(t: &mut [u8], pos: usize) {
        t[pos] = 0;
        let s = t.iter().fold(0u8, |a, &x| a.wrapping_add(x));
        t[pos] = 0u8.wrapping_sub(s);
    }

    fn sdt(firma: &[u8; 4], corpo: &[u8]) -> Vec<u8> {
        let mut t = std::vec![0u8; 36];
        t[0..4].copy_from_slice(firma);
        t.extend_from_slice(corpo);
        let n = t.len() as u32;
        t[4..8].copy_from_slice(&n.to_le_bytes());
        t[8] = 1;
        sistema_checksum(&mut t, 9);
        t
    }

    #[test]
    fn rsdp_valida_e_corrotta() {
        let mut r = std::vec![0u8; 36];
        r[0..8].copy_from_slice(b"RSD PTR ");
        r[9..15].copy_from_slice(b"OMNIQ ");
        r[15] = 2;
        r[20..24].copy_from_slice(&36u32.to_le_bytes());
        r[24..32].copy_from_slice(&0x7fe1_0000u64.to_le_bytes());
        sistema_checksum(&mut r[..20], 8);
        sistema_checksum(&mut r, 32);
        let v = rsdp(&r).unwrap();
        assert_eq!(v.xsdt, 0x7fe1_0000);
        assert_eq!(&v.oem, b"OMNIQ ");
        r[30] ^= 1;
        assert_eq!(rsdp(&r).err(), Some(ErroreAcpi::ChecksumErrato));
        r[0] = b'X';
        assert_eq!(rsdp(&r).err(), Some(ErroreAcpi::FirmaErrata));
    }

    #[test]
    fn madt_quattro_cpu_e_sostituzione() {
        let mut corpo = Vec::new();
        corpo.extend_from_slice(&0xfee0_0000u32.to_le_bytes());
        corpo.extend_from_slice(&1u32.to_le_bytes());
        for id in 0..4u8 {
            corpo.extend_from_slice(&[0, 8, id, id, 1, 0, 0, 0]);
        }
        corpo.extend_from_slice(&[0, 8, 9, 9, 0, 0, 0, 0]); // CPU disattivata
        let mut io = std::vec![1u8, 12, 0, 0];
        io.extend_from_slice(&0xfec0_0000u32.to_le_bytes());
        io.extend_from_slice(&0u32.to_le_bytes());
        corpo.extend_from_slice(&io);
        let mut iso = std::vec![2u8, 10, 0, 0];
        iso.extend_from_slice(&2u32.to_le_bytes());
        iso.extend_from_slice(&0u16.to_le_bytes());
        corpo.extend_from_slice(&iso);
        let t = sdt(b"APIC", &corpo);
        let v = verifica_sdt(&t, b"APIC").unwrap();
        let m = madt(v).unwrap();
        assert_eq!(m.cpu_abilitate, 4);
        assert_eq!(&m.id_apic[..4], &[0, 1, 2, 3]);
        assert_eq!(m.cpu_totali, 5);
        assert_eq!(m.apic_locale, 0xfee0_0000);
        assert_eq!(m.ioapic, 0xfec0_0000);
        assert_eq!(m.gsi_irq[0], 2);
        assert_eq!(m.gsi_irq[1], 1);
        assert_eq!(verifica_sdt(&t, b"HPET").err(), Some(ErroreAcpi::FirmaErrata));
    }

    #[test]
    fn xsdt_e_hpet() {
        let mut corpo = Vec::new();
        corpo.extend_from_slice(&0x1000u64.to_le_bytes());
        corpo.extend_from_slice(&0x2000u64.to_le_bytes());
        let x = sdt(b"XSDT", &corpo);
        let v: Vec<u64> = voci_xsdt(verifica_sdt(&x, b"XSDT").unwrap()).collect();
        assert_eq!(v, [0x1000, 0x2000]);
        let mut h = std::vec![0u8; 20];
        h[8..16].copy_from_slice(&0xfed0_0000u64.to_le_bytes());
        let t = sdt(b"HPET", &h);
        assert_eq!(hpet_base(verifica_sdt(&t, b"HPET").unwrap()).unwrap(), 0xfed0_0000);
    }

    #[test]
    fn madt_troncata() {
        let mut t = sdt(b"APIC", &[0u8; 8]);
        t.extend_from_slice(&[0, 40]);
        let n = t.len() as u32;
        t[4..8].copy_from_slice(&n.to_le_bytes());
        sistema_checksum(&mut t, 9);
        assert_eq!(madt(&t).err(), Some(ErroreAcpi::Troncata));
    }

    #[test]
    fn fadt_e_reset() {
        let mut corpo = std::vec![0u8; 244 - 36];
        let at = |o: usize| o - 36;
        corpo[at(40)..at(44)].copy_from_slice(&0x7fe0_0000u32.to_le_bytes());
        corpo[at(64)..at(68)].copy_from_slice(&0x604u32.to_le_bytes());
        corpo[at(112)..at(116)].copy_from_slice(&(1u32 << 10).to_le_bytes());
        corpo[at(116)] = 1;
        corpo[at(120)..at(128)].copy_from_slice(&0xcf9u64.to_le_bytes());
        corpo[at(128)] = 6;
        corpo[at(140)..at(148)].copy_from_slice(&0x7fe1_0000u64.to_le_bytes());
        let t = sdt(b"FACP", &corpo);
        let f = fadt(verifica_sdt(&t, b"FACP").unwrap()).unwrap();
        assert_eq!(f.dsdt, 0x7fe1_0000, "X_DSDT ha la precedenza");
        assert_eq!(f.pm1a_cnt, 0x604);
        assert_eq!(f.reset, Some((1, 0xcf9, 6)));
    }

    #[test]
    fn pacchetto_s5() {
        // Name(_S5, Package(0x04){0x05, 0x05, Zero, Zero}) in forme diverse
        let a = [0x10, 0x08, b'_', b'S', b'5', b'_', 0x12, 0x06, 0x04, 0x0a, 0x05, 0x0a, 0x05, 0x00, 0x00];
        assert_eq!(s5(&a), Some((5, 5)));
        let b = [0x08, b'\\', b'_', b'S', b'5', b'_', 0x12, 0x06, 0x04, 0x00, 0x00, 0x00, 0x00];
        assert_eq!(s5(&b), Some((0, 0)));
        // "_S5_" che non è un oggetto Name: ignorato
        let c = [0x70, b'_', b'S', b'5', b'_', 0x00];
        assert_eq!(s5(&c), None);
        assert_eq!(s5(&[0x08, b'_', b'S', b'5', b'_', 0x12]), None, "troncato: nessun panico");
    }
}
