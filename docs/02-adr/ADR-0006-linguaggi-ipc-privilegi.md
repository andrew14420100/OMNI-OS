# ADR-0006 — Linguaggi, IPC e separazione dei privilegi

- **Stato:** Proposto
- **Data:** 2026-11-05
- **Decisioni approvate correlate:** 51 (Qt/QML, Rust, Python, KDE/Wayland, isolamento), 9, 41
- **Requisiti correlati:** RF-05, RF-07

## Contesto

La decisione 51 fissa i linguaggi; resta da definire come i componenti
comunicano e dove passano i confini di privilegio.

## Proposta

| Ambito | Scelta | Motivazione |
|---|---|---|
| Interfacce | Qt 6 + QML (plasmoid, applicazioni) | Decisione 51; integrazione nativa Plasma |
| Servizi di sistema | Rust (crate `zbus` per D-Bus, `tokio` per I/O) [P] | Decisione 51; sicurezza della memoria |
| Motore AI | Python 3 (versione di Fedora 45) in ambiente isolato | Decisione 51; ecosistema ML |
| IPC | D-Bus di sistema (servizi privilegiati) e di sessione (componenti utente) | Standard Linux, integrazione polkit |
| Autorizzazione | polkit con azioni granulari; default `auth_admin` per operazioni distruttive | RF-05 |
| Confinamento servizi | Hardening systemd + SELinux | Riduce l'impatto di vulnerabilità |
| Confinamento app ed estensioni | Flatpak + portali; estensioni con manifest di permessi | RF-07 |
| Audit | `omni-auditd` con registro append-only | Decisione 41 |

### Regole di privilegio

1. Nessun componente OMNI in sessione utente gira come root.
2. Il motore AI non ha mai `sudo`, `pkexec` automatici o accesso a socket privilegiati non mediati.
3. Ogni operazione privilegiata passa da un'azione polkit dichiarata, che mostra all'utente **cosa** verrà fatto.
4. Le azioni avviate dall'AI sono marcate nel registro con l'ID dell'agente e del compito.
5. polkit non deve avere regole che concedono automaticamente azioni distruttive all'utente della sessione AI.

## Alternative scartate

- Socket/REST locale personalizzato: reinventa autenticazione e autorizzazione già presenti in D-Bus/polkit.
- Servizi in Python privilegiati: superficie di attacco maggiore.

## Decisione del proprietario

_In attesa._
