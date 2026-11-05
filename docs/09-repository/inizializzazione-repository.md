# Situazione del repository GitHub e inizializzazione

- **Stato:** verificato il 2026-11-05.
- **Aggiornamento 2026-11-05:** il proprietario ha autorizzato l'**opzione 1**. Eseguito:
  - verificato che il commit `25f607b` non ha genitori e ha l'albero vuoto di Git (`4b825dc642cb6eb9a060e54bf8d69288fbee4904`, 0 file);
  - pubblicato `main` su `25f607b`; `main` è il branch predefinito (`HEAD` remoto → `refs/heads/main`);
  - pubblicato `claude/zealous-ritchie-hnvev5` e aperta la PR in bozza #1 verso `main`, **senza merge**.
  - Da fare a cura del proprietario: regole di protezione di `main` (§5).

Le sezioni seguenti descrivono la situazione **prima** dell'inizializzazione.

## 1. Situazione rilevata

| Verifica | Risultato |
|---|---|
| Repository | `andrew14420100/OMNI-OS` |
| Branch remoti (API GitHub `list_branches`) | **Nessuno** — elenco vuoto |
| `git ls-remote origin` | Nessun riferimento |
| Commit | Nessuno: repository totalmente vuoto |
| Branch di lavoro locale | `claude/zealous-ritchie-hnvev5`, contiene i commit della documentazione M0, **non ancora pubblicato** |

## 2. Conseguenze

1. **Non si può aprire una PR**: una PR richiede un branch di base esistente (es. `main`) diverso dal branch di lavoro.
2. **Il primo branch pubblicato diventa il branch predefinito**: se si pubblicasse per primo `claude/zealous-ritchie-hnvev5`, GitHub lo imposterebbe come branch predefinito del repository. Non sarebbe `main`, ma cambierebbe comunque la struttura del repository; per questo non è stato fatto senza la tua indicazione.

## 3. Come è stato preparato il branch di lavoro

Il primo commit del branch di lavoro è un **commit iniziale vuoto**
(`chore: inizializzazione del repository`), senza file. I commit della
documentazione M0 seguono. Così `main` può essere creato puntando esattamente
a quel commit vuoto, e la PR `claude/zealous-ritchie-hnvev5 → main` mostrerà
tutta e sola la documentazione M0 da revisionare.

## 4. Opzioni di inizializzazione (scegline una)

### Opzione 1 — Claude crea `main` sul commit iniziale vuoto (consigliata)

Richiede la tua autorizzazione esplicita a creare `main`. Claude eseguirà:

```bash
# main punta al commit iniziale vuoto (nessun file)
git push origin <sha-commit-iniziale>:refs/heads/main
# poi il branch di lavoro
git push -u origin claude/zealous-ritchie-hnvev5
```

Quindi aprirà la PR in bozza verso `main`. Vantaggio: storia lineare e pulita,
nessun file su `main` prima della tua approvazione.

### Opzione 2 — Inizializzi tu `main` da GitHub

1. Su GitHub, nella pagina del repository vuoto, crea un file (es. `README.md` o `LICENSE`) con "Commit directly to the main branch".
2. Comunicamelo: Claude riallineerà il branch di lavoro sopra il tuo `main` (rebase) e aprirà la PR.

Vantaggio: `main` creato da te. Svantaggio: se il file creato coincide con uno della PR (es. `README.md`) andrà risolto un piccolo conflitto.

### Opzione 3 — Pubblicare solo il branch di lavoro (senza `main`)

Claude pubblica `claude/zealous-ritchie-hnvev5`, che diventa temporaneamente
il branch predefinito; nessuna PR possibile finché non esiste `main`. Utile solo
per mettere al sicuro il lavoro.

## 5. Impostazioni consigliate dopo la creazione di `main`

- Impostare `main` come branch predefinito (se non lo è).
- Regola di protezione su `main`: PR obbligatoria, approvazione richiesta, blocco di force-push ed eliminazione.
- Decidere visibilità (pubblico/privato) e licenza del repository (vedi `../05-licenze/analisi-licenze.md` §3) — decisioni del proprietario.

## 6. Rischio

Il lavoro esiste per ora solo nel container di Claude, che è temporaneo
(rischio R-22). Conviene scegliere un'opzione rapidamente.
