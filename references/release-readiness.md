# Checklist de preparación de release

Este checklist prepara un candidato de release sin crear tags ni actualizar
manifests. La SemVer se decide sobre el diff final en el gate de merge, no por
la feature o la rama que la contiene.

## Protocolo canónico de ejecución

El release se divide en un gate de publicación y una operación documental
posterior:

1. Preparar el candidato en una rama `codex/<scope>` y ejecutar todas las
   validaciones sin crear tags ni actualizar el manifiesto fuente.
2. Comparar el diff completo con el último tag promovido, clasificar SemVer y
   actualizar `VERSION` si corresponde.
3. Mergear el candidato a `master` con checkout limpio y sincronizar el
   `master` local con `origin/master`.
4. Crear el tag inmutable `v<VERSION>` sobre el commit mergeado.
5. Con `master`, checkout limpio y `HEAD == v<VERSION>`, ejecutar
   `scripts/bootstrap.sh --update-source-vault` (o `-UpdateSourceVault`).
   Esta operación escribe únicamente el manifiesto fuente; no crea commits ni
   tags.
6. Revisar y confirmar por separado el commit documental posterior. Ese
   commit deja normalmente `source.state: not-release-aligned`, porque
   `master` avanza después del tag; no se debe mover ni forzar el tag público.
7. Ejecutar `--source-status` y comprobar `vault.state: aligned`,
   `skill_version`, `source_revision` y `source_tag`, además de que el tag
   siga apuntando al commit de release y `master` local coincida con
   `origin/master`.

El preflight read-only equivalente es:

```sh
./scripts/release-check.sh --format json
```

Después de `--update-source-vault`, añade `--post-release` para verificar el
manifiesto. En PowerShell usa `scripts/release-check.ps1 -Format json` y
`-PostRelease`. Estos scripts no crean tags, commits, pushes ni cambios de
vault; la decisión de SemVer, el merge y la publicación siguen siendo
humanos.

## Estado del candidato

- [ ] `scripts/bootstrap.sh --source-status` ejecutado y comunicado.
- [ ] `scripts/release-check.sh --format json` devuelve `ready: true` antes
      del tag.
- [ ] `VERSION` y `VAULT_FORMAT` comprobados.
- [ ] El candidato está en una rama `codex/<scope>` sin interpretar el nombre
      como versión final.
- [ ] El árbol de trabajo está limpio después de consolidar los cambios.
- [ ] No existen tags nuevos ni cambios en el manifiesto de release.

## Validación funcional

- [ ] `python -m unittest discover -s tests -p 'test_*.py'` pasa.
- [ ] `python tests/retrieval/evaluate.py` mantiene el gate documentado.
- [ ] `sh tests/test-install.sh` pasa.
- [ ] `./tests/test-bootstrap.sh` pasa.
- [ ] `./scripts/vault.sh check --source` pasa.
- [ ] `./tests/test-bootstrap.ps1` y `./scripts/vault.ps1 check -Source` pasan
      en un host PowerShell disponible.
- [ ] `PYTHONPATH=src python3 -m ato_ai_mem check --source . --format json`
      devuelve `status: ok`.
- [ ] `git diff --check` pasa.

## Validación del skill y del adaptador

- [ ] `skill-creator/scripts/quick_validate.py` pasa en un entorno con
      `PyYAML`, sin añadir `PyYAML` al runtime del proyecto.
- [ ] El ZIP se genera en una ruta temporal nueva.
- [ ] El ZIP contiene `SKILL.md`, `capability-contract.md`,
      `change-control-contract.md`, `connection-contract.md` y
      `package-metadata.json`.
- [ ] `package-metadata.json.skill_version` coincide con `VERSION`.
- [ ] Los ejemplos materializados de `skill_version` coinciden con `VERSION`.
- [ ] El ZIP no contiene `vault/`, `.git/`, `AGENTS.md` ni el CLI local.
- [ ] Microsoft 365 Copilot/Agent Builder se identifica explícitamente y no
      se confunde con GitHub Copilot.
- [ ] Copilot Studio se presenta como superficie documental compatible solo
      hasta el nivel realmente validado.

## Gate de merge y publicación

- [ ] Comparar el diff final contra el último tag promovido.
- [ ] Clasificar `major`, `minor` o `patch` en ese momento.
- [ ] Actualizar `VERSION` en el commit candidato.
- [ ] Regenerar el ZIP y repetir las validaciones.
- [ ] Mergear a `master` con checkout limpio.
- [ ] Crear `v<VERSION>` sobre el commit mergeado.
- [ ] Ejecutar la operación canónica de actualización del manifiesto fuente.
- [ ] Verificar `vault.state: aligned`, `skill_version`, `source_revision` y
      `source_tag`.
- [ ] Confirmar que `v<VERSION>` permanece sobre el commit de release y que
      `master` local coincide con `origin/master` después del commit
      documental.
- [ ] `scripts/release-check.sh --post-release --format json` devuelve
      `ready: true` después de actualizar el manifiesto.

## Fuera de este release

- Implementación real de `apply_change`.
- Conectores de SharePoint, OneDrive, MCP, Confluence o Azure DevOps Wiki.
- RAG, índices persistentes, sincronización o ejecución autónoma.
- Tags o publicación desde un adaptador de Copilot.
