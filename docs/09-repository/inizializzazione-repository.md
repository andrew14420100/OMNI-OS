# Stato del repository GitHub e inizializzazione

- **Ultimo aggiornamento:** 2026-11-05.
- **Inizializzazione:** completata il 2026-11-05 con l'**opzione 1**, autorizzata dal proprietario.
- **M0 chiusa:** PR #1 unita in `main` il 2026-11-05.

## 1. Stato attuale

| Elemento | Stato |
|---|---|
| Repository | `andrew14420100/OMNI-OS` |
| Visibilità | **Pubblico** (verificato con l'API GitHub) |
| Branch predefinito | `main` |
| `main` iniziale | Commit `25f607b4a69f762ddea6fb8a1e1f67b439aeed48` (`chore: inizializzazione del repository`): commit iniziale **vuoto**, nessun genitore, albero vuoto di Git `4b825dc642cb6eb9a060e54bf8d69288fbee4904`, **0 file** |
| `main` dopo M0 | Merge commit `4198f0bef1872ac143afc14f273be5640152a771` (PR #1, 2026-11-05), contenuto identico al commit revisionato `5b0218f`: 26 file |
| Branch di lavoro | `claude/zealous-ritchie-hnvev5`, ripartito da `main` (`4198f0b`) per M1 |
| PR #1 (M0) | **Unita** il 2026-11-05 con merge commit, su approvazione del proprietario: https://github.com/andrew14420100/OMNI-OS/pull/1 |
| Controlli automatici | Dal 2026-11-05 (M1): workflow `ci-statica` con soli controlli statici (`.github/workflows/ci.yml`). Nessuna build di immagini |
| Licenza | **Nessuna** (decisione DA-07 aperta) |
| Protezione di `main` | Non configurata: va impostata dal proprietario (§3) |

I commit della documentazione M0 sono visibili nella PR #1 (scheda *Commits*);
quelli di M1 nella relativa PR.

## 2. Come è stata fatta l'inizializzazione (cronologia)

1. **Situazione iniziale:** repository totalmente vuoto, nessun branch remoto, nessun commit. Non era possibile aprire una PR senza un branch di base; inoltre il primo branch pubblicato sarebbe diventato il branch predefinito.
2. **Preparazione locale:** il primo commit del branch di lavoro è stato creato come commit vuoto (`25f607b`), seguito dai commit della documentazione.
3. **Opzioni presentate:** (1) Claude crea `main` sul commit vuoto; (2) il proprietario crea `main` da GitHub; (3) pubblicazione del solo branch di lavoro.
4. **Opzione scelta:** 1, autorizzata dal proprietario il 2026-11-05.
5. **Esecuzione:**
   - verificato che `25f607b` non ha genitori e ha l'albero vuoto (0 file);
   - pubblicato `main` su `25f607b` (`git push origin 25f607b:refs/heads/main`); `main` è diventato il branch predefinito;
   - pubblicato `claude/zealous-ritchie-hnvev5`;
   - aperta la PR in bozza #1 verso `main`, senza merge;
   - verifica da una copia nuova del repository: `main` con 0 file, branch di lavoro con tutti i file della PR.

## 3. Impostazioni consigliate (a cura del proprietario)

Claude non può modificare le impostazioni del repository.

- Regola di protezione su `main`: PR obbligatoria, approvazione richiesta, blocco di force-push ed eliminazione.
- Decidere la licenza (vedi `../05-licenze/analisi-licenze.md` §3 e REQ-PUB-01). Il repository è già pubblico: la decisione è prioritaria ma resta del proprietario.
- Quando sarà introdotta la CI (non prima di M1, con autorizzazione): controlli obbligatori sulle PR e regole per i segreti (SEC-KEY-04).
