# Dominio: Engineering Optimization Prompts

## Propósito

Este dominio contiene prompts reutilizables para revisar y optimizar ingeniería
de skills, memoria, documentación y flujos operativos. Su audiencia son los
agentes y las personas que mantienen este repositorio.

## Vocabulario y fuentes

`optimization cycle` designa el ciclo `Question → Eliminate → Simplify →
Bound Scope → Check Stability`. La fuente normativa de gobernanza es
`ato-ai-skill-governance`; la fuente de memoria del producto es el `SKILL.md`
canónico y su vault.

## Reglas locales

Cuando una persona diga “Ejecuta un ciclo de optimización”, carga el registro
activo del ciclo y úsalo sobre el objetivo actual o el objetivo explícito de la
petición. El contexto puede incluir la conversación, archivos inspeccionados,
restricciones y decisiones relevantes de la vault, pero el agente debe
declarar qué utilizó.

El ciclo ejecuta análisis y produce un resultado accionable; no autoriza por sí
solo cambios persistentes. Las fases de aceleración o automatización quedan
fuera del ciclo y solo pueden proponerse después de comprobar estabilidad.

Las reglas locales pueden acotar la operación del dominio, pero no habilitan
inferencia adaptativa, sincronización automática, sobrescritura ni movimientos
sin trazabilidad. Prevalecen `SKILL.md`, `vault/AGENTS.md` y la autorización
humana explícita.
