# Búsqueda local

Usa la búsqueda para localizar evidencia. Selecciona `--domain` si el contexto corresponde a un dominio; sin él, la consulta abarca la vault.

```sh
python3 scripts/search.py 'decisión de arquitectura' --mode text
python3 scripts/search.py 'decisi[oó]n.*arquitectura' --mode regex --domain project-context
python3 scripts/search.py 'cómo se organiza la memoria local' --mode language
python3 scripts/search.py 'routing' --scope indexes
python3 scripts/search.py 'status: active' --scope headers
```

`text` busca una frase literal por línea sin distinguir mayúsculas ni tildes. `regex` aplica expresiones regulares de Python por línea y sin distinguir mayúsculas. `language` divide la consulta en palabras, busca coincidencias léxicas sin distinguir mayúsculas ni tildes y ordena por cantidad de términos distintos encontrados. No interpreta intención, sinónimos ni similitud semántica.

`--scope content` busca en Markdown y YAML; `indexes` limita a archivos `INDEX.md` y `_indexes/`; `headers` busca en front matter, encabezados Markdown y archivos YAML. `--limit` admite 1 a 100 documentos y por defecto devuelve 20. La salida JSON incluye ruta relativa a la vault, puntuación y hasta cinco líneas con su número por documento; las puntuaciones describen coincidencias, no confianza. Una búsqueda sin resultados devuelve una lista vacía. Un patrón inválido, archivo ilegible, dominio inexistente o symlink encontrado detiene la búsqueda con error.

La búsqueda lee archivos durante cada ejecución; no crea índices ni cachés, no modifica la vault y no accede a red. Los embeddings quedan aplazados. La CLI no sustituye el diagnóstico estructural ni habilita clasificación o escritura automática.
