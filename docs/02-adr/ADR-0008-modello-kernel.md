# ADR-0008 — Modello del kernel OMNI

- **Stato:** Proposto — richiede decisione
- **Data:** 2026-11-10
- **Decisioni approvate correlate:** 1, 14, 51, 53

## Contesto

Bisogna scegliere fra un kernel monolitico, un microkernel e un kernel ibrido. Il
compromesso è fra sicurezza (isolamento dei driver) e semplicità o prestazioni.

## Opzioni considerate

1. Monolitico: tutti i driver nel kernel.
2. Microkernel puro: solo memoria, scheduler e IPC nel kernel.
3. **Ibrido orientato al microkernel, con capability:**
   - driver di avvio nel kernel fino a K3;
   - da K4 driver, filesystem, rete e grafica in servizi utente;
   - accesso alle risorse solo tramite capability.

## Proposta

Opzione 3.

## Conseguenze

- **Positive:** un driver difettoso, da K4 in poi, non compromette il kernel; il modello
  dei permessi è uniforme (capability).
- **Negative:** il costo dell'IPC va ottimizzato (memoria condivisa per i dati grandi); la
  progettazione dell'IPC è un punto critico di K4.
- **Rischi:** RK-01, RK-07.

## Verifiche richieste

- **K4:** prove di isolamento. L'arresto di un servizio driver non ferma il kernel, e il
  servizio viene riavviato.
- **K6:** misura del costo dell'IPC sul percorso input → compositore.

## Decisione del proprietario

—
