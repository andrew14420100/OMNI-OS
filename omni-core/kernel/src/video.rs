// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Schermo del kernel sul framebuffer GOP: schermata di avvio OMNI (sfondo, logo ad anello,
//! titolo) e console di testo con il font vettoriale originale di `omni_comune::font`.

use crate::mem::frame::virtuale;
use crate::sync::Blocco;
use omni_comune::bootinfo::{FormatoPixel, Framebuffer};
use omni_comune::font;

// Colori dell'identità OMNI (stessi della shell 0.x)
pub const SFONDO_ALTO: u32 = 0x070a14;
pub const SFONDO_BASSO: u32 = 0x0d1124;
pub const CIANO: u32 = 0x38d3f2;
pub const VIOLA: u32 = 0x8b7cff;
pub const TESTO: u32 = 0xf3f6fd;
pub const TESTO_2: u32 = 0xa7b1c8;
pub const VERDE: u32 = 0x6ee7b7;
pub const ROSSO: u32 = 0xff7a8a;

pub struct Schermo {
    base: u64,
    pub larghezza: u32,
    pub altezza: u32,
    passo: u32,
    bgr: bool,
    // console
    pub riga: u32,
    prima_riga: u32,
    scala: u32,
}

pub static SCHERMO: Blocco<Option<Schermo>> = Blocco::new(None);

fn mescola(a: u32, b: u32, t: u32, n: u32) -> u32 {
    let c = |s: u32| {
        let x = (a >> s) & 0xff;
        let y = (b >> s) & 0xff;
        ((x * (n - t) + y * t) / n.max(1)) << s
    };
    c(16) | c(8) | c(0)
}

impl Schermo {
    pub fn pixel(&mut self, x: i32, y: i32, rgb: u32) {
        if x < 0 || y < 0 || x as u32 >= self.larghezza || y as u32 >= self.altezza {
            return;
        }
        let v = if self.bgr { rgb } else { ((rgb & 0xff) << 16) | (rgb & 0xff00) | ((rgb >> 16) & 0xff) };
        let o = (y as u64 * self.passo as u64 + x as u64) * 4;
        // SAFETY: coordinate dentro il framebuffer, mappato nella mappa diretta
        unsafe { core::ptr::write_volatile((self.base + o) as *mut u32, v) };
    }

    pub fn rettangolo(&mut self, x: i32, y: i32, w: i32, h: i32, rgb: u32) {
        for yy in y..y + h {
            for xx in x..x + w {
                self.pixel(xx, yy, rgb);
            }
        }
    }

    fn sfondo_riga(&self, y: u32) -> u32 {
        mescola(SFONDO_ALTO, SFONDO_BASSO, y, self.altezza)
    }

    /// Sfondo con sfumatura verticale e logo ad anello (sfumatura ciano → viola).
    pub fn schermata_avvio(&mut self) {
        for y in 0..self.altezza {
            let c = self.sfondo_riga(y);
            for x in 0..self.larghezza {
                self.pixel(x as i32, y as i32, c);
            }
        }
        let (cx, cy) = self.centro_logo();
        let (r_est, r_int) = (60i32, 44i32);
        for y in -r_est..=r_est {
            for x in -r_est..=r_est {
                let d = x * x + y * y;
                if d <= r_est * r_est && d >= r_int * r_int {
                    let t = (x + r_est) as u32;
                    self.pixel(cx + x, cy + y, mescola(CIANO, VIOLA, t, 2 * r_est as u32));
                }
            }
        }
        let titolo = "OMNI OS";
        let s = 7;
        let w = self.larghezza_testo(titolo, s);
        self.testo(((self.larghezza as i32) - w) / 2, cy + 90, titolo, s, TESTO);
        let sotto = "kernel autonomo - milestone K1";
        let w = self.larghezza_testo(sotto, 3);
        self.testo(((self.larghezza as i32) - w) / 2, cy + 160, sotto, 3, TESTO_2);
        self.prima_riga = (cy + 220) as u32;
        self.riga = self.prima_riga;
    }

    pub fn centro_logo(&self) -> (i32, i32) {
        (self.larghezza as i32 / 2, 150)
    }

    pub fn larghezza_testo(&self, t: &str, scala: i32) -> i32 {
        t.chars().count() as i32 * 6 * scala
    }

    fn linea(&mut self, x0: i32, y0: i32, x1: i32, y1: i32, spessore: i32, rgb: u32) {
        let passi = (x1 - x0).abs().max((y1 - y0).abs()).max(1);
        for i in 0..=passi {
            let x = x0 + (x1 - x0) * i / passi;
            let y = y0 + (y1 - y0) * i / passi;
            self.rettangolo(x, y, spessore, spessore, rgb);
        }
    }

    /// Testo con il font vettoriale: cella 6×9 unità, `scala` pixel per unità.
    pub fn testo(&mut self, x: i32, y: i32, t: &str, scala: i32, rgb: u32) {
        let spessore = (scala * 2 / 3).max(1);
        let mut cx = x;
        for c in t.chars() {
            let (base, extra) = font::glifo(c);
            for &(a, b, c2, d) in base.iter().chain(extra) {
                self.linea(cx + a as i32 * scala, y + b as i32 * scala, cx + c2 as i32 * scala, y + d as i32 * scala, spessore, rgb);
            }
            if font::accentato(c) {
                self.linea(cx + 2 * scala, y - 2 * scala, cx + 3 * scala, y - 3 * scala, spessore, rgb);
            }
            cx += 6 * scala;
        }
    }

    /// Riga della console sotto il titolo, a capo entro la larghezza dello schermo.
    pub fn scrivi_riga(&mut self, t: &str, rgb: u32) {
        let massimo = ((self.larghezza.saturating_sub(80)) / (6 * self.scala)).max(10) as usize;
        let mut resto = t;
        let mut prima = true;
        while !resto.is_empty() {
            let limite = if prima { massimo } else { massimo - 2 }; // le righe seguenti sono rientrate di 2 caratteri
            let fine = resto.char_indices().nth(limite).map(|(i, _)| i).unwrap_or(resto.len());
            let (pezzo, dopo) = resto.split_at(fine);
            self.scrivi_riga_singola(pezzo, rgb, if prima { 0 } else { 6 * self.scala as i32 * 2 });
            prima = false;
            resto = dopo;
        }
    }

    /// Una riga; quando lo spazio finisce, la console ricomincia dall'alto.
    fn scrivi_riga_singola(&mut self, t: &str, rgb: u32, rientro: i32) {
        let altezza_riga = 9 * self.scala;
        if self.riga + altezza_riga >= self.altezza {
            for y in self.prima_riga..self.altezza {
                let c = self.sfondo_riga(y);
                for x in 0..self.larghezza {
                    self.pixel(x as i32, y as i32, c);
                }
            }
            self.riga = self.prima_riga;
        }
        let y = self.riga as i32;
        let s = self.scala as i32;
        self.testo(40 + rientro, y, t, s, rgb);
        self.riga += altezza_riga;
    }
}

pub fn inizializza(fb: &Framebuffer) -> bool {
    if fb.fisico == 0 || fb.larghezza == 0 {
        return false;
    }
    let mut s = Schermo {
        base: virtuale(fb.fisico),
        larghezza: fb.larghezza,
        altezza: fb.altezza,
        passo: fb.passo,
        bgr: fb.formato == FormatoPixel::Bgr,
        riga: 0,
        prima_riga: 0,
        scala: 2,
    };
    s.schermata_avvio();
    *SCHERMO.prendi() = Some(s);
    true
}

/// Riga di testo sullo schermo (se presente).
pub fn riga(t: &str, rgb: u32) {
    if let Some(s) = SCHERMO.prendi().as_mut() {
        s.scrivi_riga(t, rgb);
    }
}

/// Testo a una posizione assoluta (es. riga della tastiera in fondo allo schermo).
pub fn scrivi_in_fondo(t: &str) {
    if let Some(s) = SCHERMO.prendi().as_mut() {
        let y = s.altezza as i32 - 40;
        let c = s.sfondo_riga(y as u32);
        s.rettangolo(0, y - 4, s.larghezza as i32, 30, c);
        s.testo(40, y, t, 2, CIANO);
    }
}
