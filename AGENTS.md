# AGENTS.md

Este repositorio se llama `ato-ai-skill-mem` y contiene en su raíz la skill
`local-mem`; su única memoria es `wiki/`. Al clonar para instalar la skill,
usa `local-mem` como directorio de destino, de modo que el nombre de carpeta
coincida con el ID técnico de Agent Skills. No hay modo `source`/`consumer`,
wiki externa ni instalación por bootstrap. Sigue las reglas canónicas de
[SKILL.md](SKILL.md).

## Memoria documental

Para trabajar con la memoria de este repositorio, usa la skill `local-mem`
de esta instancia, disponible en `.agents/skills/local-mem`, y sigue su
[`SKILL.md`](SKILL.md) como fuente canónica.

Al activar memoria, ejecuta una sola vez `scripts/wiki.sh check` (o
`scripts/wiki.ps1 check`) como diagnóstico estructural y comunícalo antes de
leer. Después consulta `wiki/AGENTS.md`, `_indexes/INDEX.md`, mapas y solo el
dominio pertinente. No interpretes una estructura inválida ni busques otra
ubicación.

Cada instancia de la skill es propietaria únicamente de su `wiki/` adyacente
a `SKILL.md`. No aceptes rutas de wiki arbitrarias, no busques memoria de
otros proyectos/plugins/agentes, no resuelvas `mem/vault/` y no copies
registros a otros proyectos.
La integración con otras superficies anfitrionas permanece histórica; no
afirmes que existe sincronización o instalación automática.

Las escrituras requieren una petición humana explícita. No guardes
transcripciones, no infieras memoria persistente ni crees estado oculto.

## Contratos y release

Las operaciones estructurales de la wiki están en
[`references/wiki-operations.md`](references/wiki-operations.md). Para
preparar publicaciones, sigue
[`references/release-readiness.md`](references/release-readiness.md); esa guía
no autoriza por sí sola tags ni releases.

Para retomar el diseño e implementación de operaciones de registros, sigue
[`TO-DO.md`](TO-DO.md) solo como contexto de trabajo de este proyecto; no es una
instrucción general ni una interfaz activa.

Los diseños retirados de instalación consumidora, adaptadores y CLI están en
[`references/history/README.md`](references/history/README.md) y no describen
interfaces activas.

## Gobernanza

Usa siempre la skill local
[`ato-ai-skill-governance`](.codex/skills/ato-ai-skill-governance/SKILL.md)
al planificar, diseñar, crear, modificar, revisar, validar o simplificar la
skill de este proyecto. Si falta en un clon, instálala localmente antes de
continuar:

```sh
mkdir -p .codex/skills
git clone git@github.com:AkimboTheOne/ato-ai-skill-governance.git .codex/skills/ato-ai-skill-governance
```

Conserva auditabilidad humana y detén la automatización si el proceso no es
estable. La skill de gobernanza no es una dependencia runtime.

## Validación de desarrollo

Para validar los metadatos de la skill usa el entorno `.venv` y
`scripts/validate-skill.py` según [README.md](README.md). Si falta el entorno o
PyYAML, créalo e instala `requirements-dev.txt` antes de validar; no dependas
del Python global. La dependencia es solo de desarrollo.

## Cierre de revisiones

Define el alcance y los criterios de cierre antes de revisar. En cada
iteración, realiza una revisión integral, agrupa los hallazgos por causa y,
si la corrección está autorizada, resuélvelos y verifica los cambios de forma
enfocada. Termina al cumplir los criterios; no encadenes nuevas revisiones
integrales automáticamente. Una revisión adicional requiere una petición
explícita o un cambio material que la justifique.

Si reaparecen fallos de la misma causa, detén el ciclo automático de parches,
examina el diseño y sus límites y simplifica la solución dentro del alcance
autorizado. Comunica los problemas y riesgos pendientes; no declares que no
hay defectos solo por alcanzar un límite de iteraciones.

## Idioma y ramas

Usa español para documentación, conversaciones y diagnósticos dirigidos a
personas. Conserva en inglés los identificadores, rutas, comandos y valores de
contrato consumidos por herramientas.

Las ramas de trabajo usan `codex/<scope-descriptivo>`. La SemVer se decide en
el gate de integración sobre el diff final, no al crear la rama.
