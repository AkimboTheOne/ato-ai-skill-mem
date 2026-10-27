# Dominio: Project Context

## Propósito

Conserva decisiones, cambios de contrato y evolución relevante de
`ato-ai-skill-mem` para recontextualizar futuras iteraciones del proyecto.
Incluye únicamente conocimiento estable y trazable del producto.

## Vocabulario y fuentes

`vault/` es la memoria fuente. `mem/vault/` identifica memorias de proyectos
consumidores. `VAULT_FORMAT=3` y `VERSION=0.5.1` son el contrato de desarrollo
actual de la fuente. Las fuentes principales son `SKILL.md`, contratos, guías operativas,
scripts, pruebas y decisiones explícitas de la conversación.

## Reglas locales

Prioriza decisiones de arquitectura, migraciones, gobierno, activación,
memoria y límites de runtime. No guardes transcripciones completas: resume
decisiones, motivos, efectos y pendientes. Las reglas locales pueden acotar la
operación del dominio, pero no habilitan inferencia adaptativa, sincronización
automática, sobrescritura ni movimientos sin trazabilidad. Prevalecen
`SKILL.md`, `vault/AGENTS.md` y la autorización humana explícita.
