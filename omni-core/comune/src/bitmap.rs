// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Bitmap di frame fisici: un bit per pagina da 4 KiB (1 = occupato).

pub struct Bitmap<'a> {
    parole: &'a mut [u64],
    bit: usize,
    liberi: usize,
    suggerimento: usize,
}

impl<'a> Bitmap<'a> {
    /// Bitmap di `bit` elementi, inizialmente tutti occupati.
    pub fn nuova(parole: &'a mut [u64], bit: usize) -> Self {
        assert!(parole.len() * 64 >= bit, "bitmap troppo piccola");
        parole.fill(u64::MAX);
        Self { parole, bit, liberi: 0, suggerimento: 0 }
    }

    pub fn capacita(&self) -> usize {
        self.bit
    }
    pub fn liberi(&self) -> usize {
        self.liberi
    }

    pub fn occupato(&self, i: usize) -> bool {
        i >= self.bit || self.parole[i / 64] & (1 << (i % 64)) != 0
    }

    /// Segna libero un intervallo [inizio, inizio+n). Gli elementi già liberi restano tali.
    pub fn libera_intervallo(&mut self, inizio: usize, n: usize) {
        for i in inizio..(inizio + n).min(self.bit) {
            self.libera(i);
        }
    }

    /// Segna occupato un intervallo.
    pub fn occupa_intervallo(&mut self, inizio: usize, n: usize) {
        for i in inizio..(inizio + n).min(self.bit) {
            if !self.occupato(i) {
                self.parole[i / 64] |= 1 << (i % 64);
                self.liberi -= 1;
            }
        }
    }

    /// Libera un elemento; restituisce false se era già libero (doppio rilascio).
    pub fn libera(&mut self, i: usize) -> bool {
        if i >= self.bit || !self.occupato(i) {
            return false;
        }
        self.parole[i / 64] &= !(1 << (i % 64));
        self.liberi += 1;
        if i < self.suggerimento {
            self.suggerimento = i;
        }
        true
    }

    /// Primo elemento libero (dal suggerimento), segnato occupato.
    pub fn alloca(&mut self) -> Option<usize> {
        if self.liberi == 0 {
            return None;
        }
        let n = self.parole.len();
        let mut w = self.suggerimento / 64;
        for _ in 0..=n {
            if w >= n {
                w = 0;
            }
            let v = self.parole[w];
            if v != u64::MAX {
                let i = w * 64 + (!v).trailing_zeros() as usize;
                if i < self.bit {
                    self.parole[w] |= 1 << (i % 64);
                    self.liberi -= 1;
                    self.suggerimento = i;
                    return Some(i);
                }
            }
            w += 1;
        }
        None
    }

    /// `n` elementi contigui liberi (per strutture che richiedono memoria fisica contigua).
    pub fn alloca_contigui(&mut self, n: usize) -> Option<usize> {
        let mut corsa = 0;
        for i in 0..self.bit {
            if self.occupato(i) {
                corsa = 0;
                continue;
            }
            corsa += 1;
            if corsa == n {
                let inizio = i + 1 - n;
                self.occupa_intervallo(inizio, n);
                return Some(inizio);
            }
        }
        None
    }
}

#[cfg(test)]
mod test {
    use super::*;

    #[test]
    fn allocazioni_e_rilasci() {
        let mut p = [0u64; 4];
        let mut b = Bitmap::nuova(&mut p, 200);
        assert_eq!(b.liberi(), 0);
        assert_eq!(b.alloca(), None);
        b.libera_intervallo(10, 100);
        assert_eq!(b.liberi(), 100);
        let a = b.alloca().unwrap();
        assert_eq!(a, 10);
        assert!(b.occupato(10));
        assert!(b.libera(10));
        assert!(!b.libera(10), "doppio rilascio rilevato");
        // 10 000 cicli senza perdite
        for _ in 0..10_000 {
            let x = b.alloca().unwrap();
            let y = b.alloca().unwrap();
            assert_ne!(x, y);
            b.libera(x);
            b.libera(y);
        }
        assert_eq!(b.liberi(), 100);
        let c = b.alloca_contigui(30).unwrap();
        for i in c..c + 30 {
            assert!(b.occupato(i));
        }
        assert_eq!(b.liberi(), 70);
        b.occupa_intervallo(0, 200);
        assert_eq!(b.liberi(), 0);
        assert!(!b.libera(500), "fuori dai limiti");
    }

    #[test]
    fn esaurimento() {
        let mut p = [0u64; 1];
        let mut b = Bitmap::nuova(&mut p, 64);
        b.libera_intervallo(0, 64);
        for _ in 0..64 {
            assert!(b.alloca().is_some());
        }
        assert_eq!(b.alloca(), None);
    }
}
