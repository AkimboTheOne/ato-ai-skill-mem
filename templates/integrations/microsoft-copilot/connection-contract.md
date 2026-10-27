# Contrato read-only de conexión

Este archivo describe la capacidad externa que puede conectar un agente de
Microsoft 365 Copilot con una vault. El ZIP no implementa la capacidad ni
concede acceso a una vault por sí mismo.

La homologación portable está en `capability-contract.md`. Este contrato
conserva las operaciones `memory_*` del MVP y las relaciona con las
capacidades semánticas del skill principal:

| Operación de conexión | Capacidad portable |
| --- | --- |
| `memory_check` | `inspect` |
| `memory_retrieve` | `search` |
| recuperación de un resultado citado | `fetch` |
| procesamiento temporal de contenido recuperado | `transform` |

`transform` no se implementa en este ZIP. Cuando esté disponible, Copilot
puede ejecutarla mediante su Code Interpreter sobre contenido previamente
obtenido; no debe usarse para seleccionar otra vault ni para persistir cambios.

## Modos de conexión

- Con `grounding`, SharePoint, OneDrive o un conector de Microsoft 365
  proporciona la evidencia bajo sus permisos. Las citas y el ranking son
  responsabilidad de esa superficie.
- Con `tool`, un MCP, REST o CLI futuro expone operaciones explícitas y debe
  respetar `capability-contract.md`.

El contrato es portable entre Microsoft 365 Copilot/Agent Builder y Copilot
Studio. No es GitHub Copilot ni un servidor MCP.

El marcador `__SKILL_VERSION__` se sustituye por `VERSION` al empaquetar. No
debe editarse manualmente en el ZIP.

## `memory_check`

Entrada:

```json
{}
```

Salida mínima:

```json
{
  "schema": 1,
  "status": "ok|findings|error",
  "skill_version": "__SKILL_VERSION__",
  "vault_format": 3,
  "role": "source|consumer",
  "scope": "descripción legible del alcance autorizado",
  "citations": []
}
```

La capacidad debe resolver un único alcance autorizado. No debe aceptar una
ruta de vault elegida libremente por el agente.

## `memory_retrieve`

Entrada:

```json
{
  "query": "texto de la consulta",
  "limit": 5
}
```

Restricciones:

- `query` es obligatoria y debe ser concreta.
- `limit` debe estar entre `1` y `50`; el valor predeterminado es `5`.
- La operación es read-only.
- No crea índices persistentes ni modifica la vault.

Salida mínima:

```json
{
  "schema": 1,
  "status": "ok|findings|error",
  "results": [
    {
      "path": "ruta relativa",
      "line_start": 1,
      "line_end": 4,
      "citation": "ruta relativa:L1-L4",
      "snippet": "texto recuperado",
      "matched_terms": []
    }
  ],
  "scope": "descripción legible del alcance autorizado"
}
```

El agente no debe presentar resultados sin `citation` y `scope`. Las
operaciones de escritura, migración, release, sincronización y exportación
quedan fuera de este MVP.
