# Guía maestra de la vault

Esta vault es un módulo contextual portable. Lee primero `_indexes/INDEX.md`,
los mapas o áreas relevantes y después abre únicamente el dominio necesario.

## Reglas no anulables

- Escribe, mueve, archiva o exporta contenido solo por petición explícita.
- El baseline actual no ejecuta reglas de routing automáticas:
  `domain.yml` declara `routing.rules: []`. Cualquier extensión futura debe
  ser determinista, basarse exclusivamente en metadata explícita y quedar
  cubierta por el contrato, la CLI y las pruebas antes de habilitarse.
- No clasifiques por similitud semántica, confianza ni historial de decisiones.
- Registra cada movimiento en `_indexes/action-log.md`.
- Conserva contenido y enlaces; no sobrescribas ni borres datos para resolver
  un conflicto.
- Envía los casos sin regla aplicable a `00_inbox/decisions-pending/`.

Los `AGENTS.md` de dominio pueden añadir contexto local, pero no relajan estas
reglas.
