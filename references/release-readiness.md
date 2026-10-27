# Checklist de preparación de release

Este checklist prepara un candidato de release sin crear tags ni actualizar
manifests. La SemVer se decide sobre el diff final en el gate de merge, no por
la feature o la rama que la contiene.

## Estado del candidato

- [ ] `scripts/bootstrap.sh --source-status` ejecutado y comunicado.
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

## Fuera de este release

- Implementación real de `apply_change`.
- Conectores de SharePoint, OneDrive, MCP, Confluence o Azure DevOps Wiki.
- RAG, índices persistentes, sincronización o ejecución autónoma.
- Tags o publicación desde un adaptador de Copilot.
