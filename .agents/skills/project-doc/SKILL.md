---
name: project-doc
description: Busca, consulta y mantiene documentos Markdown de este repositorio bajo doc/. Úsalo para tareas documentales del proyecto; excluye wiki/ y los archivos fuente de la raíz.
---

# Documentación del proyecto

## Ámbito y raíz

Esta skill administra únicamente la documentación de `doc/` en el repositorio
`ato-ai-skill-mem`. No administra la memoria de instalación ni el código,
contratos o instrucciones fuente de la raíz.

Resuelve la raíz del repositorio desde la carpeta de esta skill, ubicada en
`.agents/skills/project-doc`: sube tres niveles (`../../../`). No la deduzcas
por el directorio de trabajo, el repositorio Git activo ni una búsqueda de
ancestros. Antes de operar, confirma que en esa raíz:

- `AGENTS.md` identifica el repositorio `ato-ai-skill-mem`;
- existen `doc/` y `doc/README.md`;
- `doc/README.md` identifica la documentación de este proyecto.

Si alguna comprobación falla, detente. No busques otra raíz ni elijas un
`doc/` alternativo.

Todas las rutas de contenido se resuelven desde esa raíz y deben permanecer
dentro de `doc/`. La raíz solo aporta `AGENTS.md` y el índice de `doc/` como
contexto; no es un destino de escritura. Los cambios a la propia skill u otros
archivos fuente se atienden con `skill-creator` y la gobernanza indicada en
`AGENTS.md`.

`wiki/` es el layout base vacío de `local-mem`, no documentación del proyecto.
No lo leas, busques, valides ni modifiques. No ejecutes `scripts/content.py`,
`scripts/search.py`, `scripts/wiki.sh` ni `scripts/wiki.ps1`: esas interfaces
operan sobre `wiki/`.

## Consulta y búsqueda

- Lee primero `AGENTS.md` y `doc/README.md`; consulta después solo la página o
  categoría pertinente de `doc/`.
- Ejecuta búsquedas con la raíz del repositorio como directorio de trabajo y
  limita siempre la ruta a `doc/`, por ejemplo:

  ```sh
  rg --files doc/
  rg -n --fixed-strings 'término' doc/
  ```

- Lee los documentos encontrados selectivamente. No recorras otros archivos
  de la raíz ni cargues todo el historial por defecto.

## Creación y actualización

Las consultas son de solo lectura. Crea o edita documentos únicamente cuando
la persona lo pida explícitamente.

- Busca documentos existentes antes de crear uno para evitar duplicados.
- Conserva la organización vigente: `doc/project/`, `doc/memory/` y
  `doc/skill/`. El material en `doc/memory/history/` es histórico, no memoria
  activa; no lo actualices como contexto vigente ni lo mezcles con documentos
  activos.
- Usa Markdown y sigue el estilo y los nombres existentes. No impongas
  front matter, metadatos ni un esquema de registros a los documentos nuevos.
  Conserva el front matter existente en el historial migrado.
- Mantén la documentación concisa y enlaza a `SKILL.md`, `references/` o al
  código fuente cuando esos archivos sean la autoridad; evita copiar su
  contenido a `doc/`.
- Añade o corrige enlaces desde el `README.md` de la categoría pertinente. Si
  cambia la navegación de primer nivel o las categorías, actualiza también
  `doc/README.md`.

## Movimiento, archivo y revisión

Mover, archivar o retirar requiere una petición explícita. Antes de mover,
localiza dentro de `doc/` los enlaces entrantes y referencias afectadas;
conserva el documento y su procedencia salvo que la persona pida retirarlo.
Actualiza los enlaces relativos y los índices pertinentes como parte de la
operación autorizada.

Después de cualquier cambio, vuelve a leer los documentos afectados, revisa
el diff limitado a `doc/` y comprueba manualmente que los enlaces modificados
apuntan a destinos existentes y que los índices siguen siendo correctos. No
hay un validador estructural de `doc/`; no uses los validadores de la wiki
como sustituto.

Escribe prosa dirigida a personas en español. Conserva en inglés las rutas,
comandos, identificadores y claves de contrato. Si la raíz o el destino son
ambiguos, detente y pide una aclaración concreta.
