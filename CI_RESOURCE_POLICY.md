# CI e risorse di build — orwell-updates

Assegnazione del 23 novembre 2026, basata sul repository al commit `508332cfc3e7`.
Tipo di progetto: Distribuzione pubblica degli artefatti Orwell.

## Assegnazione operativa

| Compito | Esecuzione |
| --- | --- |
| Provider attuale | Nessun compilatore: riceve i binari già prodotti da Orwell |
| Controlli di sviluppo | Verificare versione, commit di origine e hash dell'artefatto da distribuire. |
| Build e pacchetti | Si svolge nel repository sorgente Orwell, mai duplicata qui. |
| Pubblicazione | Usare tools/publish-updates.ps1 e tools/update-from-main.ps1 secondo il flusso esistente. |
| Azure / altri CI aggiuntivi | Non attivati e non assegnati a questo progetto in questa fase. |

## Responsabilità degli agenti

- Distribuzione: ricevere soltanto artefatti destinati al pubblico e la relativa provenienza.
- Sorgenti/build: restano di competenza di Orwell; non trasformare questo archivio in mirror pubblico del codice privato.
- Lavorare sullo stato corrente del branch e conservare modifiche concorrenti; aggiornare questa assegnazione se l'architettura cambia davvero.
- Riutilizzare i controlli esistenti senza ridurre test di sicurezza o affidabilità per risparmiare minuti. Eseguire soltanto le verifiche pertinenti alla modifica; il gate di release rimane completo quando richiesto.

## Verifiche e riferimenti

Non è richiesta una compilazione cloud. Usare le verifiche applicabili indicate sopra e nei documenti del progetto.

Riferimenti: `README.md`, `tools/publish-updates.ps1`, `tools/update-from-main.ps1`.

## Consumo e decisioni

- Repository pubblico senza workflow: la quota compute assegnata è zero.
- Non caricare configurazioni, credenziali, database o log applicativi con i pacchetti.
- Le quote GitHub sono condivise dall'account proprietario; eventuali quote Azure sono condivise dall'organizzazione DevOps, non rinnovate per ogni repository.
- Microsoft sarà collegato separatamente. Questo documento non attiva pipeline, abbonamenti o consumo cloud aggiuntivo.
- Se la quota non basta, riportare il blocco e il job necessario; non spostare automaticamente il lavoro su un altro provider o su runner a pagamento.
