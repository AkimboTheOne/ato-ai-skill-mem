# Guía maestra de la wiki

Esta es la única memoria de la skill y vive en `wiki/`. `SKILL.md` define
activación, autoridad y precedencia. Lee primero `_indexes/INDEX.md`, los
mapas pertinentes y después únicamente el dominio necesario.

## Reglas

- `domain.yml` declara `routing.rules: []`; no hay routing automático.
- No clasifiques por similitud, confianza ni historial de decisiones.
- Registra cada movimiento explícito en `_indexes/action-log.md`.
- Conserva contenido y enlaces; no sobrescribas ni borres datos para resolver
  conflictos.
- Si no hay dominio inequívoco, usa `00_inbox/decisions-pending/` cuando la
  persona haya pedido persistir la propuesta.

Los `AGENTS.md` de dominio pueden añadir contexto local o restricciones, pero
no relajan estas reglas ni las de `SKILL.md`. El diagnóstico estructural es
`scripts/wiki.sh check`; no crea estado de contextualización ni modifica
contenido.
