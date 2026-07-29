# API de Notificaciones — Documento para el equipo de automatizaciones

Este documento describe cómo cada bot debe registrar sus notificaciones en el panel de control, en reemplazo del envío de mails.

## Endpoint

```
POST https://TU-DOMINIO/api/notificaciones
```

- Autenticación: header `X-API-Key: <clave provista>`
- Formato: `multipart/form-data` (permite adjuntar archivos). Si no hay adjuntos, igual se usa multipart/form-data con los campos de texto.

## Campos

| Campo | Obligatorio | Descripción |
|---|---|---|
| `automatizacion` | Sí | Nombre del proceso. Ej: `Proceso 8 - Conciliación bancaria` |
| `empresa` | Sí | Ej: `Global Lottery` o `Servigamers` (se pueden agregar más, no hay lista fija) |
| `tipo` | Sí | Uno de: `aviso`, `error`, `resumen` (se acepta también "Resumen de ejecución") |
| `mensaje` | Sí | Texto de la notificación (hasta 20.000 caracteres) |
| `id_ejecucion` | No | Identificador de la corrida del bot, para agrupar notificaciones de una misma ejecución |
| `fecha` | No | Fecha/hora del evento en ISO 8601 (ej: `2026-07-29T10:30:00-03:00`). Si no se envía, se toma la hora de recepción |
| `archivos` | No | Uno o más adjuntos. Repetir el campo por cada archivo |

**Adjuntos permitidos:** xlsx, xls, csv, zip, rar, 7z, png, jpg, jpeg, gif, pdf, txt, log, json, xml, html. Máximo 25 MB por archivo.

## Respuestas

- `201` → `{"ok": true, "id": 123, "adjuntos": ["evidencia.xlsx"]}`
- `400` → campo inválido (el detalle viene en el JSON de respuesta)
- `401` → API key ausente o incorrecta
- `413` → adjunto demasiado grande

## Ejemplo con curl

```bash
curl -X POST https://TU-DOMINIO/api/notificaciones \
  -H "X-API-Key: LA_CLAVE" \
  -F "automatizacion=Proceso 8 - Conciliación" \
  -F "empresa=Global Lottery" \
  -F "tipo=error" \
  -F "mensaje=No se pudo descargar el extracto del banco. Reintentos agotados." \
  -F "id_ejecucion=2026-07-29-0830" \
  -F "archivos=@captura_error.png" \
  -F "archivos=@log_ejecucion.zip"
```

## Ejemplo en PowerShell (UiPath / Power Automate Desktop / tareas Windows)

```powershell
$uri  = "https://TU-DOMINIO/api/notificaciones"
$form = @{
    automatizacion = "Proceso 8 - Conciliación"
    empresa        = "Servigamers"
    tipo           = "resumen"
    mensaje        = "Ejecución finalizada OK. 152 registros procesados, 0 rechazos."
    id_ejecucion   = (Get-Date -Format "yyyy-MM-dd-HHmm")
    archivos       = Get-Item "C:\bots\salidas\resumen.xlsx"
}
Invoke-RestMethod -Uri $uri -Method Post -Form $form -Headers @{ "X-API-Key" = "LA_CLAVE" }
```

(`-Form` requiere PowerShell 6+. En PowerShell 5.1 usar el script `ejemplos/enviar_notificacion_ps5.ps1` incluido en el proyecto.)

## Ejemplo en Python

```python
import requests

r = requests.post(
    "https://TU-DOMINIO/api/notificaciones",
    headers={"X-API-Key": "LA_CLAVE"},
    data={
        "automatizacion": "Proceso 3 - Facturación",
        "empresa": "Global Lottery",
        "tipo": "aviso",
        "mensaje": "Se encontraron 3 comprobantes con diferencias menores. Ver adjunto.",
        "id_ejecucion": "2026-07-29-0830",
    },
    files=[("archivos", open("diferencias.xlsx", "rb"))],
)
print(r.status_code, r.json())
```

## Recomendaciones

- Enviar un `resumen` al final de cada ejecución exitosa (así el panel también confirma que el bot corrió).
- Ante una excepción no controlada, enviar `tipo=error` con el mensaje de la excepción y, si es posible, una captura de pantalla.
- Usar siempre el mismo `automatizacion` y `empresa` (mismo texto exacto) para que los filtros del panel agrupen bien.
