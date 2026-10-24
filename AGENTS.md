# AGENTS.md

Este repositorio usa `workspace/` para su memoria local. Sigue las reglas
canónicas de [SKILL.md](SKILL.md); este archivo no las duplica.

## Versionado del skill y del workspace

Al cargar el skill, lee `VERSION`, `WORKSPACE_FORMAT` y, si existe,
`workspace/.ato-ai-skill-mem-version.yml`. Comunica el diagnóstico de estado,
versión, formato, compatibilidad y modo antes de operar memoria. Aplica los
modos, su orden de prioridad y las condiciones de actualización definidos en
[SKILL.md](SKILL.md); no los reinterpretes ni los dupliques aquí.

## Idioma

Usa español para el razonamiento comunicado, las conversaciones, la
documentación, los ejemplos y los diagnósticos dirigidos a personas. Conserva
en inglés los identificadores de programación, nombres de archivos, comandos,
claves de contratos, valores consumidos por herramientas y términos técnicos
establecidos. Un implementador puede cambiar el idioma de un proyecto
consumidor cuando lo documente expresamente en sus instrucciones locales.
