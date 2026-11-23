# Reglas generales de la memoria

Esta carpeta es el layout base de la memoria local. En el repositorio fuente
se conserva vacía de datos: las decisiones e historia de `ato-ai-skill-mem`
viven en `doc/`. Una instalación activa usa únicamente el `wiki/` adyacente a
su propio `SKILL.md`. Ese `SKILL.md` define activación, autoridad y
precedencia. Lee primero `_indexes/INDEX.md`, mapas pertinentes y después solo
el dominio necesario.

## Reglas

- Cada `domain.yml` declara `routing.rules: []`; no hay routing automático.
- No clasifiques por similitud, confianza ni historial de decisiones.
- Registra cada movimiento explícito en `_indexes/action-log.md`.
- Conserva contenido y enlaces; no sobrescribas ni borres datos para resolver
  conflictos.
- Si no hay dominio inequívoco, usa `00_inbox/decisions-pending/` cuando la
  persona haya pedido persistir la propuesta.

Los `AGENTS.md` de dominio pueden añadir contexto local o restricciones, pero
no relajan estas reglas ni las de `SKILL.md`. El diagnóstico estructural es
`scripts/wiki.sh check`; no crea estado de contextualización ni modifica
contenido. Los dominios y registros se crean solo para una instancia cuando
una persona lo solicita explícitamente.
