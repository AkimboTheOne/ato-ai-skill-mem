# Contrato read-only de conexión

Este archivo describe la capacidad externa que puede conectar un agente de
Microsoft 365 Copilot con una vault. El ZIP no implementa la capacidad ni
concede acceso a una vault por sí mismo.

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
  "skill_version": "0.7.0",
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
