// Copyright (c) 2026 OMNI OS. Tutti i diritti riservati.
//! Strumento di sviluppo di OMNI (non fa parte del sistema): costruisce OMNI Boot e il
//! kernel, prepara la partizione di avvio (cartella FAT per QEMU, nessuna ISO), avvia QEMU
//! con OVMF, guida la tastiera e cattura lo schermo via QMP, verifica i criteri delle milestone (K1, K2) e
//! scrive il rapporto.
//!
//!   cargo xtask controlli        licenze/dipendenze e blocchi `unsafe` documentati
//!   cargo xtask prova [--tcg]    tutte le prove in QEMU, rapporto in target/prove/rapporto/
//!   cargo xtask avvia            avvio interattivo in QEMU (finestra)

use omni_comune::sha256;
use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

type Esito<T> = Result<T, String>;

fn radice() -> PathBuf {
    Path::new(env!("CARGO_MANIFEST_DIR")).parent().unwrap().to_path_buf()
}

fn esegui(cmd: &mut Command) -> Esito<()> {
    let s = cmd.status().map_err(|e| format!("{cmd:?}: {e}"))?;
    if s.success() {
        Ok(())
    } else {
        Err(format!("{cmd:?}: uscita {s}"))
    }
}

// --------------------------------------------------------------------------------- build

/// Costruisce caricatore e kernel con le funzioni indicate e prepara la cartella ESP.
fn costruisci(variante: &str, funzioni: &str) -> Esito<PathBuf> {
    let r = radice();
    esegui(Command::new("cargo").current_dir(&r).args(["build", "-q", "-p", "omni-boot", "--target", "x86_64-unknown-uefi", "--release"]))?;
    let dir_build = r.join("target").join("varianti").join(variante);
    let mut c = Command::new("cargo");
    c.current_dir(&r).args(["build", "-q", "-p", "omni-kernel", "--target", "x86_64-unknown-none", "--release", "--target-dir"]).arg(&dir_build);
    if !funzioni.is_empty() {
        c.args(["--features", funzioni]);
    }
    esegui(&mut c)?;
    let esp = r.join("target").join("prove").join(variante).join("esp");
    fs::create_dir_all(esp.join("EFI/BOOT")).map_err(|e| e.to_string())?;
    fs::create_dir_all(esp.join("OMNI")).map_err(|e| e.to_string())?;
    fs::copy(r.join("target/x86_64-unknown-uefi/release/omni-boot.efi"), esp.join("EFI/BOOT/BOOTX64.EFI")).map_err(|e| e.to_string())?;
    fs::copy(dir_build.join("x86_64-unknown-none/release/omni-kernel"), esp.join("OMNI/KERNEL.ELF")).map_err(|e| e.to_string())?;
    Ok(esp)
}

fn hash_file(p: &Path) -> String {
    let d = fs::read(p).unwrap_or_default();
    String::from_utf8(sha256::esadecimale(&sha256::sha256(&d)).to_vec()).unwrap()
}

// ---------------------------------------------------------------------------------- QEMU

struct Macchina {
    figlio: Child,
    qmp: BufReader<UnixStream>,
    seriale: PathBuf,
    inizio: Instant,
}

fn ovmf() -> (String, String) {
    (
        std::env::var("OMNI_OVMF_CODE").unwrap_or_else(|_| "/usr/share/OVMF/OVMF_CODE_4M.fd".into()),
        std::env::var("OMNI_OVMF_VARS").unwrap_or_else(|_| "/usr/share/OVMF/OVMF_VARS_4M.fd".into()),
    )
}

fn kvm(forza_tcg: bool) -> bool {
    !forza_tcg && fs::OpenOptions::new().read(true).write(true).open("/dev/kvm").is_ok()
}

impl Macchina {
    fn avvia(esp: &Path, lavoro: &Path, cpu: u32, usa_kvm: bool, riavvio: bool) -> Esito<Self> {
        fs::create_dir_all(lavoro).map_err(|e| e.to_string())?;
        let (codice, vars) = ovmf();
        let copia_vars = lavoro.join("OVMF_VARS.fd");
        fs::copy(&vars, &copia_vars).map_err(|e| format!("{vars}: {e}"))?;
        let seriale = lavoro.join("seriale.log");
        let _ = fs::remove_file(&seriale);
        let sock = lavoro.join("qmp.sock");
        let _ = fs::remove_file(&sock);
        let mut c = Command::new("qemu-system-x86_64");
        c.args(["-machine", "q35", "-m", "2G", "-smp"]).arg(cpu.to_string());
        if usa_kvm {
            c.args(["-accel", "kvm", "-cpu", "host"]);
        } else {
            c.args(["-accel", "tcg", "-cpu", "max"]);
        }
        c.arg("-drive").arg(format!("if=pflash,format=raw,readonly=on,file={codice}"));
        c.arg("-drive").arg(format!("if=pflash,format=raw,file={}", copia_vars.display()));
        c.arg("-drive").arg(format!("format=raw,file=fat:rw:{}", esp.display()));
        c.arg("-serial").arg(format!("file:{}", seriale.display()));
        c.arg("-qmp").arg(format!("unix:{},server=on,wait=off", sock.display()));
        c.args(["-device", "isa-debug-exit,iobase=0xf4,iosize=0x04", "-display", "none", "-vga", "std", "-net", "none"]);
        if !riavvio {
            c.arg("-no-reboot"); // un riavvio inatteso termina QEMU invece di ripetere l'avvio
        }
        c.stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::piped());
        let figlio = c.spawn().map_err(|e| format!("qemu-system-x86_64: {e}"))?;
        let inizio = Instant::now();
        let mut flusso = None;
        while inizio.elapsed() < Duration::from_secs(20) {
            if let Ok(s) = UnixStream::connect(&sock) {
                flusso = Some(s);
                break;
            }
            std::thread::sleep(Duration::from_millis(100));
        }
        let s = flusso.ok_or("QMP non raggiungibile")?;
        s.set_read_timeout(Some(Duration::from_secs(30))).ok();
        let mut m = Macchina { figlio, qmp: BufReader::new(s), seriale, inizio };
        let mut riga = String::new();
        m.qmp.read_line(&mut riga).map_err(|e| e.to_string())?; // saluto
        m.comando(r#"{"execute":"qmp_capabilities"}"#)?;
        Ok(m)
    }

    fn comando(&mut self, json: &str) -> Esito<String> {
        self.qmp.get_mut().write_all(json.as_bytes()).map_err(|e| e.to_string())?;
        self.qmp.get_mut().write_all(b"\n").map_err(|e| e.to_string())?;
        loop {
            let mut r = String::new();
            if self.qmp.read_line(&mut r).map_err(|e| e.to_string())? == 0 {
                return Err("QMP chiuso".into());
            }
            if r.contains("\"return\"") {
                return Ok(r);
            }
            if r.contains("\"error\"") {
                return Err(r);
            }
        }
    }

    fn testo_seriale(&self) -> String {
        String::from_utf8_lossy(&fs::read(&self.seriale).unwrap_or_default()).replace('\r', "")
    }

    fn attendi_seriale(&mut self, testo: &str, secondi: u64) -> Esito<f64> {
        let t0 = Instant::now();
        while t0.elapsed() < Duration::from_secs(secondi) {
            if self.testo_seriale().contains(testo) {
                return Ok(self.inizio.elapsed().as_secs_f64());
            }
            if let Ok(Some(s)) = self.figlio.try_wait() {
                return Err(format!("QEMU terminato ({s}) prima di \"{testo}\""));
            }
            std::thread::sleep(Duration::from_millis(100));
        }
        Err(format!("\"{testo}\" non comparso entro {secondi} s"))
    }

    fn tasti(&mut self, tasti: &[&str]) -> Esito<()> {
        for t in tasti {
            self.comando(&format!(r#"{{"execute":"send-key","arguments":{{"keys":[{{"type":"qcode","data":"{t}"}}]}}}}"#))?;
            std::thread::sleep(Duration::from_millis(150));
        }
        Ok(())
    }

    fn schermata(&mut self, ppm: &Path) -> Esito<()> {
        self.comando(&format!(r#"{{"execute":"screendump","arguments":{{"filename":"{}"}}}}"#, ppm.display()))?;
        Ok(())
    }

    /// Codice d'uscita di QEMU (isa-debug-exit: (valore << 1) | 1).
    fn attendi_uscita(&mut self, secondi: u64) -> Option<i32> {
        let t0 = Instant::now();
        while t0.elapsed() < Duration::from_secs(secondi) {
            if let Ok(Some(s)) = self.figlio.try_wait() {
                return s.code();
            }
            std::thread::sleep(Duration::from_millis(100));
        }
        let _ = self.figlio.kill();
        let _ = self.figlio.wait();
        None
    }
}

impl Drop for Macchina {
    fn drop(&mut self) {
        let _ = self.figlio.kill();
        let _ = self.figlio.wait();
    }
}

// ----------------------------------------------------------------------- immagini (PPM/PNG)

struct Immagine {
    l: usize,
    a: usize,
    rgb: Vec<u8>,
}

impl Immagine {
    fn leggi_ppm(p: &Path) -> Esito<Self> {
        let d = fs::read(p).map_err(|e| format!("{}: {e}", p.display()))?;
        // intestazione: P6 <l> <a> <max>\n
        let mut campi = Vec::new();
        let mut i = 0;
        while campi.len() < 4 {
            while d[i].is_ascii_whitespace() {
                i += 1;
            }
            let s = i;
            while !d[i].is_ascii_whitespace() {
                i += 1;
            }
            campi.push(String::from_utf8_lossy(&d[s..i]).to_string());
        }
        i += 1;
        if campi[0] != "P6" {
            return Err("non è un PPM P6".into());
        }
        let l: usize = campi[1].parse().map_err(|_| "larghezza")?;
        let a: usize = campi[2].parse().map_err(|_| "altezza")?;
        Ok(Immagine { l, a, rgb: d[i..i + l * a * 3].to_vec() })
    }

    fn pixel(&self, x: usize, y: usize) -> (u8, u8, u8) {
        let o = (y * self.l + x) * 3;
        (self.rgb[o], self.rgb[o + 1], self.rgb[o + 2])
    }

    /// PNG non compresso (blocchi "stored" di zlib): leggibile ovunque, senza librerie.
    fn scrivi_png(&self, p: &Path) -> Esito<()> {
        fn crc(dati: &[u8]) -> u32 {
            let mut c = 0xffff_ffffu32;
            for &b in dati {
                c ^= b as u32;
                for _ in 0..8 {
                    c = if c & 1 != 0 { 0xedb8_8320 ^ (c >> 1) } else { c >> 1 };
                }
            }
            !c
        }
        fn blocco(out: &mut Vec<u8>, tipo: &[u8; 4], dati: &[u8]) {
            out.extend_from_slice(&(dati.len() as u32).to_be_bytes());
            let mut t = tipo.to_vec();
            t.extend_from_slice(dati);
            out.extend_from_slice(&t);
            out.extend_from_slice(&crc(&t).to_be_bytes());
        }
        let mut grezzo = Vec::with_capacity((self.l * 3 + 1) * self.a);
        for y in 0..self.a {
            grezzo.push(0);
            grezzo.extend_from_slice(&self.rgb[y * self.l * 3..(y + 1) * self.l * 3]);
        }
        let mut z = vec![0x78, 0x01];
        let n = grezzo.len().div_ceil(65535);
        for (i, c) in grezzo.chunks(65535).enumerate() {
            z.push(if i + 1 == n { 1 } else { 0 });
            z.extend_from_slice(&(c.len() as u16).to_le_bytes());
            z.extend_from_slice(&(!(c.len() as u16)).to_le_bytes());
            z.extend_from_slice(c);
        }
        let (mut a, mut b) = (1u32, 0u32);
        for &x in &grezzo {
            a = (a + x as u32) % 65521;
            b = (b + a) % 65521;
        }
        z.extend_from_slice(&((b << 16) | a).to_be_bytes());
        let mut out = vec![0x89, b'P', b'N', b'G', 0x0d, 0x0a, 0x1a, 0x0a];
        let mut ihdr = Vec::new();
        ihdr.extend_from_slice(&(self.l as u32).to_be_bytes());
        ihdr.extend_from_slice(&(self.a as u32).to_be_bytes());
        ihdr.extend_from_slice(&[8, 2, 0, 0, 0]);
        blocco(&mut out, b"IHDR", &ihdr);
        blocco(&mut out, b"IDAT", &z);
        blocco(&mut out, b"IEND", &[]);
        fs::write(p, out).map_err(|e| e.to_string())
    }
}

fn vicino(c: (u8, u8, u8), atteso: u32, tolleranza: i32) -> bool {
    let (r, g, b) = (((atteso >> 16) & 0xff) as i32, ((atteso >> 8) & 0xff) as i32, (atteso & 0xff) as i32);
    (c.0 as i32 - r).abs() <= tolleranza && (c.1 as i32 - g).abs() <= tolleranza && (c.2 as i32 - b).abs() <= tolleranza
}

/// Verifica K1-10: sfondo, logo ad anello (ciano a sinistra), foro centrale, testo del titolo.
fn verifica_schermata(img: &Immagine) -> (bool, String) {
    let cx = img.l / 2;
    let cy = 150;
    let angolo = img.pixel(4, 4);
    let anello = img.pixel(cx - 52, cy);
    let anello_destra = img.pixel(cx + 52, cy);
    let foro = img.pixel(cx, cy);
    let mut chiari = 0;
    for y in 240..290.min(img.a) {
        for x in 0..img.l {
            let p = img.pixel(x, y);
            if p.0 > 200 && p.1 > 200 && p.2 > 200 {
                chiari += 1;
            }
        }
    }
    let mut verdi = 0;
    for y in 370..img.a {
        for x in 0..img.l {
            let p = img.pixel(x, y);
            if p.1 > 180 && p.0 < 160 && p.2 > 120 && p.2 < 220 {
                verdi += 1;
            }
        }
    }
    let ok = img.l == 1280
        && img.a == 800
        && vicino(angolo, 0x070a14, 6)
        && anello.1 > 150
        && anello.2 > 180
        && anello.0 < 120
        && anello_destra.0 > 100
        && anello_destra.2 > 200
        && foro.0 < 30
        && foro.1 < 30
        && foro.2 < 50
        && chiari > 800
        && verdi > 2000;
    (
        ok,
        format!(
            "{}x{}; angolo {:?} (atteso ~#070a14); anello sinistro {:?} (ciano), destro {:?} (viola); centro {:?} (sfondo); {} pixel del titolo; {} pixel verdi degli esiti",
            img.l, img.a, angolo, anello, anello_destra, foro, chiari, verdi
        ),
    )
}

// ------------------------------------------------------------------------------- scenari

struct Rapporto {
    criteri: BTreeMap<String, (bool, String)>,
    note: Vec<String>,
}

impl Rapporto {
    fn segna(&mut self, id: &str, ok: bool, prova: String) {
        let e = self.criteri.entry(id.to_string()).or_insert((true, String::new()));
        e.0 &= ok;
        if !e.1.is_empty() {
            e.1.push_str(" · ");
        }
        e.1.push_str(&prova);
        println!("{} {id}: {prova}", if ok { "OK     " } else { "FALLITO" });
    }
}

/// Valori del registro seriale: riga che inizia con il prefisso.
fn riga<'a>(s: &'a str, prefisso: &str) -> Option<&'a str> {
    s.lines().find(|l| l.contains(prefisso))
}

fn scenario_principale(rap: &mut Rapporto, cpu: u32, usa_kvm: bool, dir: &Path) -> Esito<()> {
    let nome = format!("principale-{cpu}cpu-{}", if usa_kvm { "kvm" } else { "tcg" });
    let esp = costruisci("ktest", "ktest")?;
    let lavoro = dir.join(&nome);
    let hash_atteso = hash_file(&esp.join("OMNI/KERNEL.ELF"));
    let mut m = Macchina::avvia(&esp, &lavoro, cpu, usa_kvm, true)?;
    let t_attesa = m.attendi_seriale("[K1] in attesa della tastiera", 900)?;
    let ppm = lavoro.join("schermata.ppm");
    m.schermata(&ppm)?;
    m.tasti(&["o", "m", "n", "i"])?;
    m.attendi_seriale("[tastiera] riga: omni", 30)?;
    std::thread::sleep(Duration::from_millis(400));
    let ppm2 = lavoro.join("tastiera.ppm");
    m.schermata(&ppm2)?;
    m.tasti(&["ret"])?;
    // dopo Invio: riavvio ACPI, secondo avvio completo, spegnimento ACPI (QEMU termina con 0)
    let t_riavvio = m.attendi_seriale("[K2] secondo avvio", 600);
    let uscita = m.attendi_uscita(600);
    let s = m.testo_seriale();
    fs::write(lavoro.join("seriale.txt"), &s).ok();
    let etichetta = format!("[{cpu} CPU, {}]", if usa_kvm { "KVM" } else { "TCG" });

    // K1-01: registro di OMNI Boot
    let fw = riga(&s, "[omni-boot] firmware:").unwrap_or("");
    let mm = riga(&s, "[omni-boot] mappa di memoria:").unwrap_or("");
    let gr = riga(&s, "[omni-boot] grafica:").unwrap_or("");
    let rs = riga(&s, "[omni-boot] ACPI: RSDP a").unwrap_or("");
    let mib: u64 = mm.split(" regioni, ").nth(1).and_then(|x| x.split(' ').next()).and_then(|x| x.parse().ok()).unwrap_or(0);
    let k101 =
        fw.contains("EDK II") && fw.contains("UEFI 2.") && (1900..=2048).contains(&mib) && gr.contains("1280x800") && !rs.ends_with("0x0") && !rs.is_empty();
    rap.segna("K1-01", k101, format!("{etichetta} {} | {} | {} | {}", fw.trim(), mm.trim(), gr.trim(), rs.trim()));

    // K1-02: hash del kernel visto da OMNI Boot e dal kernel = file su disco
    let kb = riga(&s, "[omni-boot] kernel:").unwrap_or("");
    let kk = riga(&s, "OMNI kernel avviato").unwrap_or("");
    let k102 = kb.contains(&hash_atteso) && kk.contains(&hash_atteso) && riga(&s, "[PROVA] K1-02 OK").is_some();
    rap.segna(
        "K1-02",
        k102,
        format!("{etichetta} sha256 del file {} = valore stampato da OMNI Boot e dal kernel: {}", &hash_atteso[..16], if k102 { "sì" } else { "NO" }),
    );

    // K1-03..K1-09: esiti delle prove nel kernel
    for id in ["K1-03", "K1-04", "K1-05", "K1-06", "K1-07", "K1-08", "K1-09", "K2-01", "K2-02", "K2-03", "K2-04", "K2-05", "K2-06"] {
        let ok = riga(&s, &format!("[PROVA] {id} OK")).is_some();
        let r = riga(&s, &format!("[PROVA] {id} ")).unwrap_or("riga assente").trim().to_string();
        rap.segna(id, ok, format!("{etichetta} {}", r.trim_start_matches(&format!("[PROVA] {id} "))));
    }
    // K1-07: numero di CPU = opzione -smp di QEMU
    let n_cpu: u32 = riga(&s, "[K1] CPU:").and_then(|l| l.rsplit(' ').next()).and_then(|x| x.trim().parse().ok()).unwrap_or(0);
    rap.segna("K1-07", n_cpu == cpu, format!("{etichetta} CPU trovate nella MADT {n_cpu}, QEMU -smp {cpu}"));

    // K1-10: schermata
    let img = Immagine::leggi_ppm(&ppm)?;
    let (ok, d) = verifica_schermata(&img);
    let png = dir.join(format!("{nome}-schermata.png"));
    img.scrivi_png(&png)?;
    Immagine::leggi_ppm(&ppm2)?.scrivi_png(&dir.join(format!("{nome}-tastiera.png")))?;
    rap.segna("K1-10", ok && riga(&s, "[PROVA] K1-10 OK").is_some(), format!("{etichetta} {d}; file {}", png.file_name().unwrap().to_string_lossy()));

    // K1-11: tastiera
    let k111 = riga(&s, "[tastiera] inviato: omni").is_some() && riga(&s, "[PROVA] K1-11 OK").is_some();
    rap.segna("K1-11", k111, format!("{etichetta} tasti o,m,n,i,Invio inviati con QMP send-key: {}", riga(&s, "[PROVA] K1-11").unwrap_or("assente").trim()));

    // K2-01: CPU in linea = opzione -smp
    let in_linea: u32 = riga(&s, "[K2] CPU in linea:").and_then(|l| l.rsplit(' ').next()).and_then(|x| x.trim().parse().ok()).unwrap_or(0);
    rap.segna("K2-01", in_linea == cpu, format!("{etichetta} CPU in linea {in_linea}, QEMU -smp {cpu}"));

    // K2-08: riavvio vero (secondo avvio di firmware, OMNI Boot e kernel) riconosciuto
    let avvii = s.matches("[omni-boot] OMNI Boot avviato").count();
    let k208 = t_riavvio.is_ok() && avvii == 2 && riga(&s, "[PROVA] K2-08 OK").is_some();
    rap.segna(
        "K2-08",
        k208,
        format!(
            "{etichetta} {}; avvii di OMNI Boot nel registro: {avvii}; {}",
            riga(&s, "[K2] riavvio ACPI richiesto").unwrap_or("riavvio non richiesto").trim(),
            riga(&s, "[PROVA] K2-08").unwrap_or("secondo avvio assente").trim()
        ),
    );
    // K2-07: spegnimento ACPI: QEMU termina da solo con codice 0 (nessun isa-debug-exit)
    let sp = riga(&s, "[K2] spegnimento ACPI").unwrap_or("").trim().to_string();
    let k207 = !sp.is_empty() && uscita == Some(0) && riga(&s, "[PROVA] K2-07 FALLITO").is_none();
    rap.segna("K2-07", k207, format!("{etichetta} {sp}; uscita di QEMU {:?} (attesa 0: macchina spenta dal kernel)", uscita));

    // nessun criterio fallito in nessuno dei due avvii (regressione)
    let fallite: Vec<&str> = s.lines().filter(|l| l.contains("[PROVA]") && l.contains("FALLITO")).collect();
    if !fallite.is_empty() {
        rap.segna("regressione", false, format!("{etichetta} prove fallite: {}", fallite.join(" | ")));
    }
    let esiti: Vec<&str> = s.lines().filter(|l| l.contains("[K2] ESITO:")).map(|l| l.trim()).collect();
    rap.note.push(format!(
        "{etichetta}: tastiera attesa dopo {t_attesa:.1} s dall'avvio di QEMU; esiti dei due avvii: {}; uscita QEMU {:?} (attesa 0 = spegnimento ACPI)",
        esiti.join(" / "),
        uscita
    ));
    if uscita != Some(0) {
        return Err(format!("{nome}: uscita {:?}", uscita));
    }
    Ok(())
}

fn scenario_errore(rap: &mut Rapporto, usa_kvm: bool, dir: &Path, variante: &str, id: &str, attesi: &[&str]) -> Esito<()> {
    let esp = costruisci(variante, variante)?;
    let lavoro = dir.join(variante);
    let mut m = Macchina::avvia(&esp, &lavoro, 1, usa_kvm, false)?;
    let uscita = m.attendi_uscita(600);
    let s = m.testo_seriale();
    fs::write(lavoro.join("seriale.txt"), &s).ok();
    let mancanti: Vec<_> = attesi.iter().filter(|a| !s.contains(**a)).collect();
    let righe: Vec<_> = s.lines().filter(|l| l.contains("PANIC") || l.contains("DOUBLE FAULT") || l.contains("PROVA K1-")).map(|l| l.trim()).collect();
    rap.segna(
        id,
        uscita == Some(33) && mancanti.is_empty(),
        format!(
            "variante {variante}: uscita QEMU {:?}; {}{}",
            uscita,
            righe.join(" | "),
            if mancanti.is_empty() { String::new() } else { format!("; mancano {mancanti:?}") }
        ),
    );
    Ok(())
}

// ------------------------------------------------------------------------------ controlli

fn controlli() -> Esito<String> {
    let r = radice();
    let mut out = String::new();
    // dipendenze: solo i pacchetti del workspace nel Cargo.lock (ADR-0011, K1)
    let lock = fs::read_to_string(r.join("Cargo.lock")).map_err(|e| e.to_string())?;
    let pacchetti: Vec<&str> = lock.lines().filter_map(|l| l.strip_prefix("name = \"")).map(|n| n.trim_end_matches('"')).collect();
    let esterni: Vec<_> = pacchetti.iter().filter(|p| !p.starts_with("omni-")).collect();
    if !esterni.is_empty() {
        return Err(format!("dipendenze esterne non approvate: {esterni:?}"));
    }
    let _ = writeln!(out, "- Dipendenze: {} pacchetti, tutti del workspace OMNI ({}); nessun codice di terzi", pacchetti.len(), pacchetti.join(", "));
    // blocchi unsafe: ciascuno preceduto da un commento SAFETY
    let mut totale = 0;
    let mut righe_codice = 0;
    let mut senza = Vec::new();
    for dir in ["comune/src", "boot/src", "kernel/src", "xtask/src"] {
        let mut file = Vec::new();
        fn visita(p: &Path, f: &mut Vec<PathBuf>) {
            for e in fs::read_dir(p).into_iter().flatten().flatten() {
                let q = e.path();
                if q.is_dir() {
                    visita(&q, f);
                } else if q.extension().is_some_and(|x| x == "rs") {
                    f.push(q);
                }
            }
        }
        visita(&r.join(dir), &mut file);
        for f in file {
            let testo = fs::read_to_string(&f).unwrap_or_default();
            let righe: Vec<&str> = testo.lines().collect();
            righe_codice += righe.iter().filter(|l| !l.trim().is_empty() && !l.trim_start().starts_with("//")).count();
            for (i, l) in righe.iter().enumerate() {
                let c = l.split("//").next().unwrap_or("");
                if !(c.contains("unsafe {") || c.contains("unsafe impl") || c.contains("unsafe fn") || c.contains("unsafe extern \"C\" {")) {
                    continue;
                }
                if c.contains("\"unsafe") || c.contains("unsafe extern \"efiapi\" fn(") || c.contains("unsafe extern \"C\" fn()") {
                    continue; // tipi di puntatori a funzione, non blocchi
                }
                totale += 1;
                let contesto = righe[i.saturating_sub(4)..=i].join("\n");
                if !(contesto.contains("SAFETY") || contesto.contains("# Safety")) {
                    senza.push(format!("{}:{}", f.strip_prefix(&r).unwrap().display(), i + 1));
                }
            }
        }
    }
    if !senza.is_empty() {
        return Err(format!("blocchi unsafe senza commento SAFETY: {senza:?}"));
    }
    let _ = writeln!(out, "- Codice: {righe_codice} righe Rust (esclusi commenti e righe vuote); {totale} usi di `unsafe`, tutti con il commento `SAFETY` che ne giustifica la correttezza");
    Ok(out)
}

// ----------------------------------------------------------------------------------- main

fn prova(forza_tcg: bool) -> Esito<bool> {
    let r = radice();
    let dir = r.join("target/prove/rapporto");
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).map_err(|e| e.to_string())?;
    let usa_kvm = kvm(forza_tcg);
    let mut rap = Rapporto { criteri: BTreeMap::new(), note: Vec::new() };
    let controlli = controlli()?;
    let t0 = Instant::now();
    let mut errori = Vec::new();
    for cpu in [1, 4] {
        if let Err(e) = scenario_principale(&mut rap, cpu, usa_kvm, &dir) {
            errori.push(e);
        }
    }
    if usa_kvm {
        // stesse prove senza KVM (emulazione completa): nessuna dipendenza dalla velocità
        for cpu in [1, 4] {
            if let Err(e) = scenario_principale(&mut rap, cpu, false, &dir) {
                errori.push(e);
            }
        }
    }
    if let Err(e) =
        scenario_errore(&mut rap, usa_kvm, &dir, "prova-panico", "K1-12", &["KERNEL PANIC: prova di panico controllata", "PROVA K1-12 panico: SUPERATA"])
    {
        errori.push(e);
    }
    if let Err(e) = scenario_errore(
        &mut rap,
        usa_kvm,
        &dir,
        "prova-doppio-errore",
        "K1-03",
        &["DOUBLE FAULT (stack IST1 dedicato)", "pagina di guardia", "PROVA K1-03 doppio errore: SUPERATA"],
    ) {
        errori.push(e);
    }
    let attesi = [
        "K1-01", "K1-02", "K1-03", "K1-04", "K1-05", "K1-06", "K1-07", "K1-08", "K1-09", "K1-10", "K1-11", "K1-12", "K2-01", "K2-02", "K2-03", "K2-04",
        "K2-05", "K2-06", "K2-07", "K2-08",
    ];
    for id in attesi {
        rap.criteri.entry(id.into()).or_insert((false, "prova non eseguita".into()));
    }
    let tutti = rap.criteri.values().all(|(ok, _)| *ok) && errori.is_empty();

    // rapporto
    let rustc = Command::new("rustc").arg("-V").output().map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string()).unwrap_or_default();
    let qemu = Command::new("qemu-system-x86_64")
        .arg("--version")
        .output()
        .map(|o| String::from_utf8_lossy(&o.stdout).lines().next().unwrap_or("").to_string())
        .unwrap_or_default();
    let mut md = String::new();
    let _ = writeln!(md, "# Milestone K2: memoria e CPU (con regressione di K1), kernel OMNI in QEMU\n");
    let _ = writeln!(
        md,
        "**Esito complessivo: {}** ({} criteri su {} superati, durata {:.0} s)\n",
        if tutti { "SUPERATO" } else { "FALLITO" },
        rap.criteri.values().filter(|c| c.0).count(),
        rap.criteri.len(),
        t0.elapsed().as_secs_f64()
    );
    let _ = writeln!(md, "| Criterio | Esito | Prova |\n|---|---|---|");
    for (id, (ok, p)) in &rap.criteri {
        let _ = writeln!(md, "| {id} | {} | {} |", if *ok { "OK" } else { "**FALLITO**" }, p.replace('|', "/"));
    }
    let _ = writeln!(md, "\n## Esecuzioni\n");
    for n in &rap.note {
        let _ = writeln!(md, "- {n}");
    }
    for e in &errori {
        let _ = writeln!(md, "- ERRORE: {e}");
    }
    let _ = writeln!(md, "\n## Codice e strumenti\n");
    md.push_str(&controlli);
    let esp = r.join("target/prove/ktest/esp");
    let _ = writeln!(md, "- `BOOTX64.EFI` (OMNI Boot) sha256 `{}`", hash_file(&esp.join("EFI/BOOT/BOOTX64.EFI")));
    let _ = writeln!(md, "- `KERNEL.ELF` (variante di prova) sha256 `{}`", hash_file(&esp.join("OMNI/KERNEL.ELF")));
    let _ = writeln!(md, "- Strumenti (non inclusi nei binari): {rustc}; {qemu}; firmware OVMF `{}`", ovmf().0);
    let _ = writeln!(
        md,
        "- Avvio da cartella FAT esposta da QEMU: **nessuna ISO**; macchina q35, 2 GiB, accelerazione {}",
        if usa_kvm { "KVM e TCG" } else { "TCG" }
    );
    fs::write(dir.join("rapporto.md"), &md).map_err(|e| e.to_string())?;
    println!("\nrapporto: {}", dir.join("rapporto.md").display());
    Ok(tutti)
}

fn main() {
    let args: Vec<String> = std::env::args().skip(1).collect();
    let risultato = match args.first().map(String::as_str) {
        Some("controlli") => controlli().map(|o| {
            print!("{o}");
            true
        }),
        Some("prova") => prova(args.iter().any(|a| a == "--tcg")),
        Some("costruisci") => costruisci("normale", "").map(|p| {
            println!("{}", p.display());
            true
        }),
        _ => Err("uso: cargo xtask controlli | prova [--tcg] | costruisci".into()),
    };
    match risultato {
        Ok(true) => {}
        Ok(false) => std::process::exit(1),
        Err(e) => {
            eprintln!("errore: {e}");
            std::process::exit(2);
        }
    }
}
