"""
Panel de Notificaciones de Automatizaciones (RPA)
--------------------------------------------------
API para que los bots registren notificaciones + panel web para seguimiento.

Ejecutar:  uvicorn main:app --host 0.0.0.0 --port 8000
Config:    variables de entorno o archivo .env (ver .env.example)
"""

import hmac
import hashlib
import mimetypes
import os
import re
import sqlite3
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, UploadFile, File, Form, Request, HTTPException, Query
from fastapi.responses import FileResponse, JSONResponse, RedirectResponse

# ----------------------------------------------------------------------------
# Configuración
# ----------------------------------------------------------------------------
BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"
ADJUNTOS_DIR = DATA_DIR / "adjuntos"
DB_PATH = DATA_DIR / "notificaciones.db"

# Carga .env simple (sin dependencias extra)
env_file = BASE_DIR / ".env"
if env_file.exists():
    for line in env_file.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip())

API_KEY = os.environ.get("API_KEY", "cambiar-esta-clave")
PANEL_PASSWORD = os.environ.get("PANEL_PASSWORD", "cambiar-este-password")
SECRET = os.environ.get("SECRET", API_KEY + PANEL_PASSWORD)

MAX_ADJUNTO_MB = int(os.environ.get("MAX_ADJUNTO_MB", "25"))
TIPOS_VALIDOS = {"aviso", "error", "resumen"}
ESTADOS_VALIDOS = {"pendiente", "atendida"}
EXTENSIONES_PERMITIDAS = {
    ".xlsx", ".xls", ".csv", ".zip", ".rar", ".7z",
    ".png", ".jpg", ".jpeg", ".gif", ".pdf", ".txt", ".log", ".json", ".xml", ".html",
}

DATA_DIR.mkdir(exist_ok=True)
ADJUNTOS_DIR.mkdir(exist_ok=True)

# ----------------------------------------------------------------------------
# Base de datos
# ----------------------------------------------------------------------------
def db() -> sqlite3.Connection:
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    con.execute("PRAGMA journal_mode=WAL")
    con.execute("PRAGMA foreign_keys=ON")
    return con


def init_db() -> None:
    with db() as con:
        con.executescript(
            """
            CREATE TABLE IF NOT EXISTS notificaciones (
                id            INTEGER PRIMARY KEY AUTOINCREMENT,
                fecha         TEXT NOT NULL,
                automatizacion TEXT NOT NULL,
                empresa       TEXT NOT NULL,
                tipo          TEXT NOT NULL,
                mensaje       TEXT NOT NULL,
                id_ejecucion  TEXT,
                estado        TEXT NOT NULL DEFAULT 'pendiente'
            );
            CREATE TABLE IF NOT EXISTS adjuntos (
                id              INTEGER PRIMARY KEY AUTOINCREMENT,
                notificacion_id INTEGER NOT NULL REFERENCES notificaciones(id) ON DELETE CASCADE,
                nombre          TEXT NOT NULL,
                tamano          INTEGER NOT NULL,
                mime            TEXT
            );
            CREATE INDEX IF NOT EXISTS idx_notif_fecha ON notificaciones(fecha DESC);
            CREATE INDEX IF NOT EXISTS idx_notif_filtros ON notificaciones(empresa, automatizacion, tipo, estado);
            """
        )


init_db()

# ----------------------------------------------------------------------------
# Utilidades
# ----------------------------------------------------------------------------
def token_sesion() -> str:
    return hmac.new(SECRET.encode(), b"panel-sesion-v1", hashlib.sha256).hexdigest()


def sesion_valida(request: Request) -> bool:
    return hmac.compare_digest(request.cookies.get("sesion", ""), token_sesion())


def requiere_api_key(request: Request) -> None:
    clave = request.headers.get("X-API-Key", "")
    if not hmac.compare_digest(clave, API_KEY):
        raise HTTPException(status_code=401, detail="API key inválida o ausente (header X-API-Key)")


def acceso_lectura(request: Request) -> None:
    """El panel (cookie) o un bot (API key) pueden leer."""
    if sesion_valida(request):
        return
    clave = request.headers.get("X-API-Key", "")
    if clave and hmac.compare_digest(clave, API_KEY):
        return
    raise HTTPException(status_code=401, detail="No autorizado")


def nombre_seguro(nombre: str) -> str:
    nombre = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    nombre = os.path.basename(nombre.replace("\\", "/"))
    nombre = re.sub(r"[^A-Za-z0-9._ -]", "_", nombre).strip(" .")
    return nombre or "archivo"


def ahora_utc() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


# ----------------------------------------------------------------------------
# App
# ----------------------------------------------------------------------------
app = FastAPI(title="Panel de Notificaciones RPA", docs_url=None, redoc_url=None)


# --------------------------- API para los bots ------------------------------
@app.post("/api/notificaciones")
async def crear_notificacion(
    request: Request,
    automatizacion: str = Form(..., min_length=1, max_length=200),
    empresa: str = Form(..., min_length=1, max_length=200),
    tipo: str = Form(...),
    mensaje: str = Form(..., min_length=1, max_length=20000),
    id_ejecucion: str = Form(None),
    fecha: str = Form(None),
    archivos: list[UploadFile] = File(default=[]),
):
    requiere_api_key(request)

    tipo_norm = tipo.strip().lower()
    # tolera "resumen de ejecución", "ERROR", etc.
    if tipo_norm.startswith("resumen"):
        tipo_norm = "resumen"
    if tipo_norm not in TIPOS_VALIDOS:
        raise HTTPException(400, f"tipo debe ser uno de: {sorted(TIPOS_VALIDOS)}")

    if fecha:
        try:
            fecha = datetime.fromisoformat(fecha.replace("Z", "+00:00")).astimezone(timezone.utc).isoformat(timespec="seconds")
        except ValueError:
            raise HTTPException(400, "fecha inválida, usar formato ISO 8601 (ej: 2026-07-29T10:30:00-03:00)")
    else:
        fecha = ahora_utc()

    with db() as con:
        cur = con.execute(
            "INSERT INTO notificaciones (fecha, automatizacion, empresa, tipo, mensaje, id_ejecucion) "
            "VALUES (?, ?, ?, ?, ?, ?)",
            (fecha, automatizacion.strip(), empresa.strip(), tipo_norm, mensaje.strip(),
             (id_ejecucion or "").strip() or None),
        )
        notif_id = cur.lastrowid

        guardados = []
        carpeta = ADJUNTOS_DIR / str(notif_id)
        for arch in archivos:
            if not arch.filename:
                continue
            nombre = nombre_seguro(arch.filename)
            ext = Path(nombre).suffix.lower()
            if ext not in EXTENSIONES_PERMITIDAS:
                raise HTTPException(400, f"Extensión no permitida: {ext} ({nombre})")
            contenido = await arch.read()
            if len(contenido) > MAX_ADJUNTO_MB * 1024 * 1024:
                raise HTTPException(413, f"El adjunto {nombre} supera el máximo de {MAX_ADJUNTO_MB} MB")
            carpeta.mkdir(parents=True, exist_ok=True)
            # evita pisar archivos con el mismo nombre
            destino, i = carpeta / nombre, 1
            while destino.exists():
                destino = carpeta / f"{Path(nombre).stem}_{i}{ext}"
                i += 1
            destino.write_bytes(contenido)
            mime = arch.content_type or mimetypes.guess_type(destino.name)[0]
            con.execute(
                "INSERT INTO adjuntos (notificacion_id, nombre, tamano, mime) VALUES (?, ?, ?, ?)",
                (notif_id, destino.name, len(contenido), mime),
            )
            guardados.append(destino.name)

    return JSONResponse(status_code=201, content={"ok": True, "id": notif_id, "adjuntos": guardados})


@app.get("/api/notificaciones")
def listar_notificaciones(
    request: Request,
    empresa: str = Query(None),
    automatizacion: str = Query(None),
    tipo: str = Query(None),
    estado: str = Query(None),
    q: str = Query(None, description="búsqueda en el mensaje"),
    limit: int = Query(30, ge=1, le=200),
    offset: int = Query(0, ge=0),
):
    acceso_lectura(request)

    condiciones, params = [], []
    for campo, valor in (("empresa", empresa), ("automatizacion", automatizacion),
                         ("tipo", tipo), ("estado", estado)):
        if valor:
            condiciones.append(f"{campo} = ?")
            params.append(valor)
    if q:
        condiciones.append("mensaje LIKE ?")
        params.append(f"%{q}%")
    where = ("WHERE " + " AND ".join(condiciones)) if condiciones else ""

    with db() as con:
        total = con.execute(f"SELECT COUNT(*) c FROM notificaciones {where}", params).fetchone()["c"]
        filas = con.execute(
            f"SELECT * FROM notificaciones {where} ORDER BY fecha DESC, id DESC LIMIT ? OFFSET ?",
            (*params, limit, offset),
        ).fetchall()
        ids = [f["id"] for f in filas]
        adjuntos_por_notif: dict[int, list] = {i: [] for i in ids}
        if ids:
            marcas = ",".join("?" * len(ids))
            for a in con.execute(
                f"SELECT * FROM adjuntos WHERE notificacion_id IN ({marcas})", ids
            ):
                adjuntos_por_notif[a["notificacion_id"]].append(
                    {"nombre": a["nombre"], "tamano": a["tamano"], "mime": a["mime"]}
                )
        # datos para armar filtros y el resumen del encabezado
        empresas = [r["empresa"] for r in con.execute(
            "SELECT DISTINCT empresa FROM notificaciones ORDER BY empresa")]
        automatizaciones = [r["automatizacion"] for r in con.execute(
            "SELECT DISTINCT automatizacion FROM notificaciones ORDER BY automatizacion")]
        resumen = {r["tipo"]: r["c"] for r in con.execute(
            f"SELECT tipo, COUNT(*) c FROM notificaciones {where} GROUP BY tipo", params)}
        pendientes = con.execute(
            f"SELECT COUNT(*) c FROM notificaciones {where}{' AND ' if where else ' WHERE '}estado='pendiente'"
            if where else "SELECT COUNT(*) c FROM notificaciones WHERE estado='pendiente'",
            params,
        ).fetchone()["c"]

    return {
        "total": total,
        "pendientes": pendientes,
        "resumen": resumen,
        "empresas": empresas,
        "automatizaciones": automatizaciones,
        "items": [dict(f) | {"adjuntos": adjuntos_por_notif.get(f["id"], [])} for f in filas],
    }


@app.patch("/api/notificaciones/{notif_id}/estado")
async def cambiar_estado(notif_id: int, request: Request):
    acceso_lectura(request)
    cuerpo = await request.json()
    estado = str(cuerpo.get("estado", "")).lower()
    if estado not in ESTADOS_VALIDOS:
        raise HTTPException(400, f"estado debe ser uno de: {sorted(ESTADOS_VALIDOS)}")
    with db() as con:
        cur = con.execute("UPDATE notificaciones SET estado = ? WHERE id = ?", (estado, notif_id))
        if cur.rowcount == 0:
            raise HTTPException(404, "Notificación inexistente")
    return {"ok": True, "id": notif_id, "estado": estado}


@app.get("/adjuntos/{notif_id}/{nombre}")
def descargar_adjunto(notif_id: int, nombre: str, request: Request):
    acceso_lectura(request)
    nombre = nombre_seguro(nombre)
    ruta = (ADJUNTOS_DIR / str(notif_id) / nombre).resolve()
    if not str(ruta).startswith(str(ADJUNTOS_DIR.resolve())) or not ruta.is_file():
        raise HTTPException(404, "Adjunto inexistente")
    return FileResponse(ruta, filename=nombre)


# ------------------------------- Panel web ----------------------------------
@app.get("/")
def panel(request: Request):
    if not sesion_valida(request):
        return RedirectResponse("/login")
    return FileResponse(BASE_DIR / "templates" / "index.html")


@app.get("/login")
def login_form():
    return FileResponse(BASE_DIR / "templates" / "login.html")


@app.post("/login")
async def login(request: Request):
    form = await request.form()
    if hmac.compare_digest(str(form.get("password", "")), PANEL_PASSWORD):
        resp = RedirectResponse("/", status_code=303)
        resp.set_cookie("sesion", token_sesion(), httponly=True, samesite="lax",
                        max_age=60 * 60 * 24 * 90)  # 90 días
        return resp
    return RedirectResponse("/login?error=1", status_code=303)


@app.get("/logout")
def logout():
    resp = RedirectResponse("/login", status_code=303)
    resp.delete_cookie("sesion")
    return resp


@app.get("/salud")
def salud():
    return {"ok": True, "hora": ahora_utc()}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
