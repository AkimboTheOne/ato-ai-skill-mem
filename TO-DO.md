# TO-DO: operaciones de registros

## Objetivo

Diseñar e implementar operaciones explícitas para crear, leer, actualizar y
retirar registros Markdown en la única `vault/` junto a la skill. El modo
actual no ofrece comandos CRUD de registros: usa plantillas para crear y deja
las ediciones autorizadas como trabajo manual. `migration-plan` y
`migration-apply` solo trasladan registros heredados desde `records/` de la
vault activa.

## Alcance y límites

- Limitar las operaciones a `vault/20_domains/<id>/records/`; conservar el
  modo único, sin rutas externas, roles, bootstrap ni `ato-mem`.
- Definir qué constituye la identidad de un registro y cómo se selecciona el
  dominio. Mantener nombres `YYYY-MM-DD--slug.md` y el front matter vigente.
- Resolver el significado de `delete`: el contrato conserva registros
  retirados y sucesores enlazados. No implementar borrado físico hasta decidir
  explícitamente si existe un caso válido y qué protección requiere.
- Toda escritura debe requerir petición humana explícita, fallar ante
  colisiones y preservar contenido, enlaces, procedencia e historial.

## Trabajo para la siguiente iteración

- Usar el commit previo al refactor
  `473e761e3b36cd9be65a75db574b07f7411cada2`, en especial su `SKILL.md` y
  `references/vault-operations.md`, como fuente para ingeniería inversa. Ese
  commit documenta flujos de creación y actualización manuales y migración de
  registros; no asumir que ya tenía un CLI CRUD completo. Separar el
  comportamiento existente que convenga recuperar de las operaciones que aún
  deban diseñarse. Se puede consultar con `git show
  473e761e3b36cd9be65a75db574b07f7411cada2:SKILL.md`.
- Revisar los contratos activos, plantillas y scripts Bash/PowerShell; usar
  los documentos de `references/history/` solo como antecedentes, no como
  interfaces para restaurar.
- Acordar las operaciones y su interfaz mínima, incluidos resultados,
  errores, validación de metadatos y comportamiento ante registros ausentes o
  nombres duplicados.
- Implementar operaciones equivalentes en Bash y PowerShell, confinadas a la
  vault de la raíz del skill. Mantener la lectura de registros disponible sin
  añadir búsqueda externa ni otro almacén.
- Para cambios persistentes, conservar una traza auditable en
  `vault/_indexes/action-log.md` y actualizar el índice del dominio cuando
  corresponda. No sobrescribir datos ni resolver conflictos automáticamente.
- Documentar la interfaz activa en `references/vault-operations.md` y
  actualizar las instrucciones relacionadas; no añadir el detalle operativo
  a `SKILL.md` salvo que cambie su flujo esencial.
- Añadir pruebas para cada operación, errores y límites de ruta, no colisión,
  trazabilidad, preservación del historial y paridad Bash/PowerShell.

## Criterios de cierre

- Las operaciones de registros quedan definidas e implementadas de forma
  consistente en Bash y PowerShell, sin aceptar rutas o ámbitos alternativos.
- El comportamiento de borrado o retiro está explícito y respeta la
  conservación de registros y la autoridad humana.
- Las operaciones y sus efectos están documentados; las pruebas cubren los
  caminos exitosos y los fallos relevantes.
- El diagnóstico estructural y las pruebas pertinentes pasan. La clasificación
  SemVer se realiza en el gate sobre el diff completo.
