## Controlli di sicurezza del disco della VM personale

| Esito | Passo | Tempo |
|---|---|---|
| OK | nessun file authorized_keys (né per root né per altri utenti) | 2 s |
| OK | la chiave SSH effimera dei test non è presente | 3 s |
| OK | nessun account utente preconfigurato (lo crea il proprietario al primo avvio) | 3 s |
| OK | account root bloccato (nessuna password) | 3 s |
| OK | sshd non abilitato | 3 s |
| OK | argomenti del kernel senza opzioni di test (sshd, console seriale) | 3 s |
| OK | OMNI Shell: eseguibile di root, permessi 755 | 3 s |
| OK | nessun file setuid/setgid in OMNI Shell | 3 s |

Esito complessivo: SUPERATO
