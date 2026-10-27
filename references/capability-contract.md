# Contrato de capacidades portables

Este contrato homologa las capacidades del skill principal con runtimes
externos, incluido Microsoft 365 Copilot, Agent Builder y Copilot Studio. No
es un protocolo de red ni una implementación de conectores.

## Capacidades

Las capacidades son semánticas y read-only:

- `inspect`: comprueba versión, formato, rol, alcance y disponibilidad.
- `search`: localiza candidatos relevantes a partir de una consulta concreta.
- `fetch`: recupera contenido exacto mediante un `locator` estable.
- `transform`: procesa temporalmente contenido ya recuperado y conserva su
  procedencia. El runtime que la ejecute puede ser externo.

Una capacidad no debe aceptar una ruta de vault elegida libremente por el
agente. La fuente y el alcance autorizado los determina el adaptador anfitrión.

## Resultado común

Cuando aplique, una operación devuelve estos campos:

```json
{
  "schema": 1,
  "status": "supported|unavailable|forbidden|incompatible",
  "source": "identificador de la fuente",
  "locator": "identificador estable del recurso",
  "revision": "versión, etag, commit o timestamp",
  "citation": "referencia verificable",
  "scope": "alcance autorizado",
  "content": "contenido o resultado"
}
```

`citation`, `scope` y `source` son obligatorios cuando se presenta contenido
recuperado. `revision` debe conservarse si la fuente lo proporciona. Los
adaptadores deben devolver `forbidden` cuando el recurso existe pero el
alcance o los permisos no permiten consultarlo; no deben probar otra fuente
silenciosamente.

## Interfaces por operación

Todas las operaciones reciben un objeto JSON y devuelven un objeto JSON con
`schema` y `status`. Los estados `unavailable`, `forbidden` e `incompatible`
terminan la operación y deben explicar el motivo sin revelar contenido fuera
del alcance autorizado.

### `inspect`

Entrada mínima:

```json
{}
```

Salida mínima:

```json
{
  "schema": 1,
  "status": "supported",
  "source": "identificador de la fuente",
  "scope": "alcance autorizado",
  "content": {
    "skill_version": "0.8.0",
    "vault_format": 3,
    "role": "source|consumer"
  }
}
```

### `search`

Entrada mínima:

```json
{
  "query": "texto concreto",
  "limit": 5
}
```

`query` es obligatoria y `limit` debe estar entre `1` y `50`, con valor
predeterminado `5`.

Salida mínima:

```json
{
  "schema": 1,
  "status": "supported",
  "source": "identificador de la fuente",
  "scope": "alcance autorizado",
  "content": {
    "results": [
      {
        "locator": "ruta o identificador estable",
        "revision": "versión o timestamp",
        "citation": "referencia verificable",
        "snippet": "fragmento",
        "matched_terms": []
      }
    ]
  }
}
```

### `fetch`

Entrada mínima:

```json
{
  "locator": "identificador estable del recurso"
}
```

`locator` es obligatorio y debe pertenecer al `source` y `scope` resueltos;
no puede seleccionar una ruta de vault arbitraria.

Salida mínima:

```json
{
  "schema": 1,
  "status": "supported",
  "source": "identificador de la fuente",
  "locator": "identificador estable del recurso",
  "revision": "versión o timestamp",
  "citation": "referencia verificable",
  "scope": "alcance autorizado",
  "content": "contenido exacto"
}
```

### `transform`

Entrada mínima:

```json
{
  "content": "contenido ya recuperado",
  "operation": "transformación solicitada",
  "provenance": {
    "source": "identificador de la fuente",
    "locator": "identificador estable del recurso",
    "revision": "versión o timestamp",
    "citation": "referencia verificable"
  }
}
```

`content` y `operation` son obligatorios. La salida conserva la procedencia y
no persiste el contenido ni ejecuta acciones externas.

```json
{
  "schema": 1,
  "status": "supported",
  "source": "identificador de la fuente",
  "locator": "identificador estable del recurso",
  "revision": "versión o timestamp",
  "citation": "referencia verificable",
  "scope": "alcance autorizado",
  "content": "resultado temporal"
}
```

## Mapeo del skill principal

| Capacidad portable | Primitivas actuales | Comportamiento |
| --- | --- | --- |
| `inspect` | `check` | Auditoría read-only y estado de la vault |
| `search` | `find`, `retrieve` | Búsqueda léxica con resultados citables |
| `fetch` | resultado citado de `build`/`retrieve` | Lectura exacta dentro del alcance resuelto |
| `transform` | preparación transitoria de `build` | Procesamiento sobre datos ya obtenidos |

El contrato no introduce nuevas escrituras ni sustituye el CLI Python. El
adaptador local debe reutilizar los límites existentes de `--source` y
`--target`, sin aceptar `--vault` ni rutas arbitrarias.

## Perfiles de Microsoft 365 Copilot

La conexión puede representar una capacidad de dos formas:

- `grounding`: SharePoint, OneDrive o un conector de Microsoft 365 aporta
  contenido según sus permisos y citas. El skill no controla su ranking ni
  puede prometer el mismo resultado que `ato-mem`.
- `tool`: MCP, REST o CLI expone operaciones explícitas que el agente puede
  invocar. El servidor o herramienta debe publicar el contrato y limitar el
  alcance por configuración.

Agent Builder y Copilot Studio pueden consumir esta proyección documental,
pero sus permisos, disponibilidad de fuentes, citas y modelos son propios de
cada superficie. Esta integración es para Microsoft 365 Copilot; no es una
integración de GitHub Copilot.

Confluence y Azure DevOps Wiki son perfiles futuros: podrían implementar
`search` y `fetch` mediante sus APIs, pero no forman parte del MVP ni se
convierten en dependencias del skill principal.

## Reglas de seguridad y procedencia

- No fusionar resultados de fuentes distintas sin identificarlas.
- No crear índices, sincronizaciones, embeddings ni memoria persistente.
- No realizar escrituras, migraciones, releases ni exportaciones.
- No presentar contenido sin `citation` y `scope` verificables.
- Si una capacidad no está conectada, devolver `unavailable` y no simularla.
