# Agent integration

El bootstrap no modifica instrucciones de agentes. Copia este bloque de forma
manual al AGENTS.md del proyecto consumidor cuando quieras activar la memoria
del proyecto:

~~~md
## Project memory

When a task depends on project decisions, conventions, lessons, or durable
context, read mem/SKILL.md, then mem/workspace/INDEX.md, and open only the
records relevant to the task. Do not write, retire, or replace project memory
unless a human explicitly asks for that change. Do not store secrets,
credentials, sensitive data, or full conversation transcripts in the workspace.
~~~

## Migration from managed integration

If an earlier instance contains the markers ato-ai-skill-mem:start and
ato-ai-skill-mem:end, manually replace that entire marked block with the
snippet above. Do not rerun bootstrap to migrate; it intentionally leaves
AGENTS.md unchanged.
