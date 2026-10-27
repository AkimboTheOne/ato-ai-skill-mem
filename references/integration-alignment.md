# Alineación del skill y sus integraciones

Esta guía pertenece al repositorio fuente y mantiene alineadas la skill
principal, sus adaptadores y los artefactos empaquetados. No es una skill
independiente, no concede autoridad adicional y no modifica proyectos
consumidores automáticamente.

## Fuente de verdad

La precedencia para una integración es:

1. `SKILL.md` y sus contratos normativos.
2. `references/capability-contract.md` para la homologación portable.
3. `references/change-control-contract.md` para propuestas y cambios
   controlados.
4. El contrato y las instrucciones específicas del adaptador.
5. El empaquetador y sus pruebas.
6. La memoria documental del proyecto como registro de decisiones y límites.

Un adaptador es una proyección subordinada. No puede cambiar la semántica,
autoridad, propiedad de la vault o límites de runtime del skill principal.

## Alineación de versión y artefactos

Antes de aceptar un cambio de integración, comprueba que:

- `VERSION` es la versión declarada del skill en desarrollo.
- `package-metadata.json.skill_version` coincide con `VERSION`.
- `memory_check.skill_version` se materializa desde `VERSION` al empaquetar.
- `VAULT_FORMAT` permanece independiente de la versión del skill.
- `capability-contract.md` y el adaptador describen las mismas capacidades.
- Las pruebas cubren el ZIP y no incluyen `vault/`, `.git/`, `AGENTS.md` ni el
  runtime local salvo que el contrato lo autorice expresamente.

La línea actual de trabajo es `0.7.0`. No debe declararse `0.8.0` hasta que
`0.7.0` haya sido promovida conforme al protocolo de release.

## Homologación de capacidades

El contrato portable define:

| Principal | Portable | Regla de alineación |
| --- | --- | --- |
| `check` | `inspect` | Mantener diagnóstico read-only y alcance resuelto |
| `find`/`retrieve` | `search` | Conservar resultados deterministas y citas |
| lectura citada | `fetch` | Exigir locator, revisión, citation y scope |
| preparación transitoria | `transform` | Procesar solo contenido ya obtenido |

Las fuentes externas se clasifican así:

- `grounding`: SharePoint, OneDrive y conectores de Microsoft 365; sus
  permisos, ranking y citas pertenecen a la superficie anfitriona.
- `tool`: MCP, REST, CLI, Confluence y Azure DevOps Wiki; cada herramienta
  futura debe publicar el contrato portable y limitar su alcance.

Microsoft 365 Copilot, Agent Builder y Copilot Studio no deben confundirse con
GitHub Copilot. La documentación portable no equivale a una validación de
carga o ejecución en un tenant real.

## Flujo de cambio

Cuando una tarea modifique una integración:

1. Actualiza primero el contrato principal o confirma que no cambia.
2. Ajusta la proyección del adaptador y el empaquetador.
3. Actualiza pruebas y la referencia de memoria del proyecto.
4. Ejecuta la suite, `ato-mem check --source .`, `git diff --check` y una
   generación limpia del ZIP.
5. Revisa que no se hayan añadido conectores, MCP servers, RAG, sincronización,
   escrituras o rutas de vault arbitrarias.

El `AGENTS.md` de este repositorio exige consultar esta guía y
`capability-contract.md` para esos cambios. Los consumidores reciben una guía
manual en `references/agents-integration.md`; el bootstrap no edita sus
`AGENTS.md`.

## Release

El release requiere checkout limpio en `master`, el tag inmutable
`v<VERSION>` sobre el commit de release y la verificación posterior del
manifiesto de la vault fuente. No se crea ni mueve el tag para incluir el
commit documental posterior.
