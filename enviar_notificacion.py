"""Ejemplo de envío de una notificación desde un bot en Python."""
import requests

URL = "http://localhost:8000/api/notificaciones"   # cambiar por la URL real
API_KEY = "cambiar-esta-clave"                     # la misma del .env del servidor

r = requests.post(
    URL,
    headers={"X-API-Key": API_KEY},
    data={
        "automatizacion": "Proceso 8 - Conciliación",
        "empresa": "Global Lottery",
        "tipo": "error",
        "mensaje": "No se pudo descargar el extracto del banco. Reintentos agotados.",
        "id_ejecucion": "2026-07-29-0830",
    },
    # files=[("archivos", open("evidencia.xlsx", "rb"))],   # opcional
)
print(r.status_code, r.json())
