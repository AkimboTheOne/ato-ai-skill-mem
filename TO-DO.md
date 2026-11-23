# TO-DO

## Cierre de la iteración de operaciones y búsqueda

Los flujos de contenido, las plantillas y la búsqueda local están documentados. La CLI asiste la revisión manual de movimientos y retiros; no los aplica automáticamente. Las pruebas existentes cubren operaciones en vaults temporales, rutas, enlaces, trazabilidad y algunos fallos de publicación. Antes de dar por cerrada la iteración:

- Revisar el diff completo, incluidos los archivos nuevos, y contrastar la interfaz con los contratos y las instrucciones de la skill. Decidir SemVer en el gate de integración; no cambiar `VERSION` por anticipado.
- Confirmar que los límites actuales satisfacen el alcance: la CLI protege índices e instrucciones, no edita `domain.yml`, y no mueve registros entre dominios. Documentar o implementar por separado cualquier capacidad adicional que se acuerde.
- Revisar la preservación de contenido, enlaces y referencias de metadatos en los casos no interpretados por la CLI, y ampliar las pruebas donde se detecten riesgos reales. Las referencias ambiguas deben detener la operación para revisión.
- Completar la validación de la skill y la revisión de release pertinente. `quick_validate.py` no se ejecutó en el entorno actual por falta de `PyYAML`; mantener esta dependencia fuera del runtime de la skill.

## Evaluación futura: búsqueda semántica local

Los embeddings están aplazados y `SKILL.md` actualmente los excluye. No implementarlos ni instalar modelos como parte del cierre anterior.

- Reunir consultas reales y evidencia que muestren si la búsqueda léxica falla al usar vocabulario diferente. Definir un conjunto de evaluación con resultados esperados y comparar calidad y coste frente a la búsqueda actual.
- Si existe una mejora que justifique la complejidad, evaluar un modelo multilingüe local: disponibilidad, licencia, tamaño, dependencias, recursos y funcionamiento sin red. Acordar cómo se instala y actualiza.
- Comparar cálculo transitorio con un índice persistente considerando latencia, espacio, reconstrucción, obsolescencia y control humano. Cualquier estado persistente debe ser explícito y confinado a la instalación.
- Antes de implementar, acordar el alcance y actualizar el límite de embeddings de `SKILL.md`, los contratos y las pruebas. La búsqueda seguiría siendo de solo lectura sobre la memoria y los resultados requerirían revisión de la fuente.
