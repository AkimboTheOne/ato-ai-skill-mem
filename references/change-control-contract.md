# Perfil portable de cambios controlados

Este perfil extiende el contrato read-only con una forma portable de proponer,
validar y aplicar cambios sobre una Vault Documental Agenéntica. Es un contrato
de capacidades; no implementa filesystem, Git, MCP, Power Automate, Graph ni
ningún conector.

El perfil es experimental en `0.7.0`. El modo predeterminado sigue siendo
`none`: lectura y propuestas sin persistencia. Un host solo puede aplicar
cambios si declara `controlled` y aporta una confirmación externa.

## Perfiles del host

```json
{
  "capabilities": {
    "read": ["inspect", "search", "fetch", "transform"],
    "change": ["draft_change", "validate_change"],
    "apply": false
  },
  "write_mode": "none|proposal|controlled"
}
```

- `none`: solo lectura.
- `proposal`: permite crear y validar propuestas, pero no persistirlas.
- `controlled`: permite aplicar una propuesta validada con confirmación externa.

El modelo no puede inventar ni autoaprobar la confirmación. El host debe
proporcionar la señal de autorización y conservar su auditoría.

## `draft_change`

Genera una propuesta sin modificar archivos.

Entrada mínima:

```json
{
  "source": "identificador de la fuente",
  "scope": "alcance autorizado",
  "operations": [
    {
      "kind": "create|update|retire|relate",
      "locator": "recurso estable o locator nuevo",
      "expected_revision": "revisión esperada o null",
      "content": "contenido propuesto",
      "reason": "motivo verificable"
    }
  ],
  "citations": []
}
```

Salida mínima:

```json
{
  "schema": 1,
  "status": "drafted|forbidden|incompatible",
  "change_id": "identificador estable de la propuesta",
  "source": "identificador de la fuente",
  "scope": "alcance autorizado",
  "operations": [],
  "citations": [],
  "requires_confirmation": true
}
```

`create`, `update`, `retire` y `relate` deben conservar la semántica y el
ciclo de vida del skill principal. `locator`, `source` y `scope` no pueden ser
seleccionados para escapar de la Vault autorizada.

## `validate_change`

Recibe una propuesta y no escribe. Debe comprobar, como mínimo:

- front matter, Markdown y layout;
- tipo, ID, fecha, estado y relaciones;
- índices y destinos relacionados;
- `source`, `scope` y locators;
- `expected_revision` para evitar sobrescrituras concurrentes;
- compatibilidad de `VERSION` y `VAULT_FORMAT`;
- ausencia de operaciones de release, exportación o sincronización.

Salida mínima:

```json
{
  "schema": 1,
  "status": "valid|invalid|forbidden|incompatible",
  "change_id": "identificador estable de la propuesta",
  "safe_to_apply": true,
  "diagnostics": [],
  "validated_revision": "revisión de la Vault"
}
```

`safe_to_apply` solo puede ser `true` cuando no existan diagnósticos de error,
el alcance esté autorizado y las revisiones esperadas coincidan.

## `apply_change`

Persiste únicamente una propuesta validada. No se expone en el perfil `none` o
`proposal`.

Entrada mínima:

```json
{
  "change_id": "identificador estable de la propuesta",
  "validated_revision": "revisión devuelta por validate_change",
  "approval": {
    "source": "host|human",
    "token": "afirmación opaca del host"
  }
}
```

La aprobación es una afirmación externa al modelo. El token no debe ser
fabricado por el agente ni sustituye la validación.

Salida mínima:

```json
{
  "schema": 1,
  "status": "applied|rejected|conflict|forbidden|unavailable",
  "change_id": "identificador estable de la propuesta",
  "source": "identificador de la fuente",
  "scope": "alcance autorizado",
  "affected_locators": [],
  "new_revisions": [],
  "audit": {
    "actor": "host o persona",
    "timestamp": "timestamp del host"
  }
}
```

Un conflicto de revisión debe detener la aplicación y exigir una nueva
propuesta. `apply_change` no crea commits, tags, releases ni manifests de
release.

## Mapeo de hosts

- Codex puede mapear `draft_change` a un patch, `validate_change` a `check` y
  `apply_change` a una edición local autorizada.
- Un repositorio Vault Documental Agenéntico necesita exponer lectura,
  escritura acotada, validación, confirmación y auditoría para declarar
  `controlled`.
- Microsoft 365 Copilot y Copilot Studio permanecen en `none` o `proposal`
  salvo que una acción, MCP, REST, Graph, Power Automate o custom connector
  publique explícitamente el perfil y sus permisos. Grounding de SharePoint o
  OneDrive no concede `apply_change`.

`release` queda siempre fuera de este adaptador y requiere el protocolo del
repositorio propietario.
