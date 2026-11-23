# Istruzioni per gli agenti — orwell-updates

## Build, CI e ripartizione dei compiti

Leggere [CI_RESOURCE_POLICY.md](CI_RESOURCE_POLICY.md) prima di cambiare pipeline o avviare build cloud.

- Assegnazione attuale: **Nessun compilatore: riceve i binari già prodotti da Orwell**.
- Distribuzione: ricevere soltanto artefatti destinati al pubblico e la relativa provenienza.
- Sorgenti/build: restano di competenza di Orwell; non trasformare questo archivio in mirror pubblico del codice privato.
- L'agente che modifica il prodotto esegue i controlli pertinenti; chi modifica la CI mantiene comandi, cache e criteri di release coerenti con questa assegnazione.
- Per sole modifiche documentali, verificare il diff e i riferimenti: non ricompilare né ripubblicare il prodotto.
- GitHub resta la sorgente canonica. Non duplicare build su più provider e non attivare runner a pagamento o un fallback automatico quando termina la quota.
