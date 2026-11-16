# Auditoría preliminar del ZIP recibido

## Alcance y resultado

Se inspeccionaron **69 archivos de código/documentación** de `pset2_codigo_para_revision.zip` (revisión estática, sin ejecutar SQL ni llamar a la red municipal). Se inspeccionaron referencias a secretos, claves, rutas y direcciones internas; no se detectaron archivos `.env` con valores, `.env.kestra.secrets`, claves privadas o datos tabulares de contribuyentes **en este ZIP**. **No equivale a una certificación de ausencia de secretos** y no garantiza que el directorio original o los archivos no incluidos estén libres de ellos.

**No publicar todavía como repositorio abierto.** El código original contiene:

1. Una dirección IP y puerto internos de SQL Server en `ingesta/Start-Worker.ps1` y `docs/ingesta_raw.md`, además del nombre de usuario técnico del SQL Server. No hay contraseña embebida ahí, pero se revela topología interna.
2. El identificador de la cuenta Snowflake y usuario/rol de servicio en scripts y documentación. No son claves secretas, pero conviene restringir su difusión.
3. El UUID de un lote real de pruebas en `README.md` y registros de evidencia, que no es un identificador personal directo pero puede correlacionarse con observaciones internas.
4. El `README.md` anterior indicaba que los Flows de backfill/retries aún no habían sido importados; se agregó una aclaración final acorde con la validación informada por el responsable.
5. El PDF final **no estaba incluido en el ZIP que recibimos** (fue excluido por el proceso de preparación). Debe añadirse separadamente al repositorio, verificando que no contenga información identificativa o sensible.

La demostración agregada en esta revisión:

- Usa únicamente **datos inventados**, sin copiar ni muestrear registros de la fuente municipal.
- Genera ids por SHA-256 sobre etiquetas públicas y ficticias; **no son seudónimos HMAC de personas reales**.
- Requiere una cuenta Snowflake separada y propia del docente.
- No ha sido ejecutada en Kestra ni en Snowflake, así que su funcionamiento completo **sigue pendiente de validación**.
- No sustituye el origen SQL Server real; solo permite probar Kestra → Raw → dbt → Spark → OBT desde una fuente sintética SQL.

## Antes del commit/push

1. Mantener GitHub **Private** hasta obtener autorización para difundir estructura municipal y sanitizar las referencias anteriores.
2. Revisar cada archivo que `git add --dry-run .` incluiría; el `.gitignore` no detecta secretos escritos como cadenas literales.
3. Asegurar que no haya `.env`, `.env.kestra.secrets`, claves `.p8`, ficheros DPAPI, `.runtime`, registros de pagos ni capturas sensibles en el índice de Git.
4. Conservar el PDF `PSet2_memo_Farinango_Andrango.pdf` de máximo seis páginas y documentar que la ingesta original y la demostración son experimentos separados.
5. Probar el Flow sintético antes de afirmar reproducibilidad completa: su validación estática no garantiza que el SQL y los drivers funcionen en el Snowflake del profesor.

**No se ejecutaron las pruebas de Snowflake, dbt, Spark ni SQL Server para esta auditoría.**
