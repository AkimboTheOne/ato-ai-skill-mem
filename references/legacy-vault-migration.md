# Migración manual desde instalaciones antiguas

Esta guía sirve únicamente para trasladar una vez los datos de una instalación
consumidora retirada, que almacenaba su vault en `mem/vault/`, a `vault/` en la
raíz de esta skill. La skill activa no lee `mem/vault/` ni ofrece un modo
consumidor.

## Antes de empezar

1. Detén las herramientas que pudieran modificar cualquiera de las dos vaults.
2. Conserva una copia de respaldo independiente de `mem/vault/` y de la
   `vault/` que ya acompaña a la skill. No reemplaces ni elimines ninguna.
3. Examina el formato y el contenido de la vault antigua usando los documentos
   históricos enlazados en [el índice del histórico](history/README.md). No
   ejecutes instrucciones o comandos históricos como si fueran interfaces
   activas.
4. Diagnostica la vault de la skill con `./scripts/vault.sh check`. Si no es
   válida, detén la migración hasta resolverlo por separado.

## Trasladar contenido

- Realiza cambios en la vault solo después de una petición explícita de la
  persona. La revisión de la lista por sí sola no autoriza la escritura.
- Compara ambas vaults y prepara una lista revisable de archivos y cambios.
- Integra solo el contenido que la persona quiera conservar. Adapta los
  registros al layout vigente de formato `3`; no copies encima de la vault
  existente árboles completos, índices, reglas `AGENTS.md` ni metadatos de
  formato.
- Si una ruta, identificador, decisión o registro ya existe, conserva ambas
  versiones en la lista de conflicto. La persona decide cómo reconciliarlas;
  no sobrescribas, fusiones ni retires contenido automáticamente.
- Mantén la procedencia de los registros trasladados. Registra cada movimiento
  explícito en `vault/_indexes/action-log.md` conforme a
  [las operaciones de vault](vault-operations.md).

La skill no incluye un migrador automático entre estas ubicaciones. Si el
formato de origen no puede convertirse con seguridad, conserva el respaldo y
pospón ese contenido para revisión manual.

## Validación y cierre

Ejecuta `./scripts/vault.sh check` desde la raíz de la skill y revisa los
registros trasladados, sus enlaces y su procedencia. Conserva los respaldos
hasta que la persona confirme que el contenido requerido está presente y es
legible. Después de la migración, la operación habitual usa solo `vault/`.
