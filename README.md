# Panel de Notificaciones RPA

Reemplaza los mails de los bots por un registro centralizado con panel de control, accesible desde el celular. Los bots envían sus notificaciones (aviso, error o resumen de ejecución) a una API con adjuntos opcionales, y el panel permite filtrar por empresa, automatización y tipo, buscar en los mensajes, descargar evidencias y marcar cada incidencia como atendida.

Sin servicios pagos: Python + SQLite, todo se guarda en la carpeta `data/` del propio servidor.

## 1. Instalación (Windows o Linux)

Requisito: Python 3.10 o superior.

```bash
cd panel-notificaciones
pip install -r requirements.txt
copy .env.example .env        # en Linux: cp .env.example .env
```

Editar `.env` y poner:
- `API_KEY`: la clave que van a usar los bots (larga y aleatoria; generarla p. ej. con `python -c "import secrets; print(secrets.token_urlsafe(32))"`)
- `PANEL_PASSWORD`: la contraseña para entrar al panel desde el navegador

Levantar el servidor:

```bash
python main.py
```

Abrir `http://localhost:8000` → login → panel. Listo para probar en la red local.

## 2. Despliegue con EasyPanel (recomendado si ya lo tenés)

El proyecto incluye un `Dockerfile`, así que EasyPanel lo construye solo.

1. Subir el proyecto a un repositorio de GitHub (puede ser privado). Sin usar git: crear el repo en github.com → "Add file → Upload files" → arrastrar todos los archivos del zip.
2. En EasyPanel: **Create Project** → dentro del proyecto, **+ Service → App**.
3. En **Source**: elegir **GitHub**, conectar la cuenta y seleccionar el repo (rama `main`). En **Build** dejar **Dockerfile**.
4. En **Environment** agregar:
   ```
   API_KEY=una-clave-larga-y-aleatoria
   PANEL_PASSWORD=el-password-del-panel
   ```
5. En **Mounts**: agregar un **Volume** con Mount Path `/app/data` (¡importante! ahí viven la base y los adjuntos; sin esto se pierden en cada redeploy).
6. En **Domains**: EasyPanel ya te crea un dominio con HTTPS; verificar que el **puerto interno sea 8000**. Si querés, agregá tu propio dominio/subdominio apuntando el DNS al VPS.
7. **Deploy**. Abrir el dominio desde el celular → login → listo.

Para actualizar más adelante: subís los cambios al repo y tocás Deploy de nuevo (o activás auto-deploy).

## 2 bis. Alternativa sin EasyPanel: Cloudflare Tunnel (gratis)

Esto le da una URL pública HTTPS al servidor de la empresa, sin abrir puertos ni tocar el router.

1. Crear una cuenta gratis en Cloudflare y (opcional pero recomendado) tener un dominio cargado ahí.
2. Instalar `cloudflared` en la máquina donde corre el panel ([descargas oficiales](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/downloads/)).
3. Prueba rápida sin dominio (la URL cambia en cada arranque):
   ```bash
   cloudflared tunnel --url http://localhost:8000
   ```
   Te imprime una URL tipo `https://algo-aleatorio.trycloudflare.com` que ya funciona desde cualquier celular.
4. Para una URL fija (recomendado para producción): en el dashboard de Cloudflare → Zero Trust → Networks → Tunnels → crear un túnel, asociarle un subdominio (ej. `notificaciones.tuempresa.com` → `http://localhost:8000`) e instalar el conector como servicio. Queda corriendo solo, incluso tras reiniciar la máquina.

Alternativa si no hay servidor propio: un VPS chico (DigitalOcean/Hetzner ~USD 5/mes, u Oracle Cloud Free Tier gratis). Ahí conviene poner el panel detrás de Caddy o Nginx con HTTPS.

## 3. Dejarlo corriendo siempre

**Windows (servicio con NSSM):**
```
nssm install PanelRPA "C:\ruta\a\python.exe" "C:\ruta\panel-notificaciones\main.py"
nssm set PanelRPA AppDirectory "C:\ruta\panel-notificaciones"
nssm start PanelRPA
```
(O una tarea programada "al iniciar el equipo" que ejecute `python main.py`.)

**Linux (systemd):** crear `/etc/systemd/system/panel-rpa.service`:
```ini
[Unit]
Description=Panel de Notificaciones RPA
After=network.target

[Service]
WorkingDirectory=/opt/panel-notificaciones
ExecStart=/usr/bin/python3 main.py
Restart=always

[Install]
WantedBy=multi-user.target
```
```bash
sudo systemctl enable --now panel-rpa
```

## 4. Qué mandarle al equipo de los bots

Pasales el archivo **`docs/API_para_los_bots.md`** (tiene el detalle de campos, ejemplos en curl, PowerShell y Python) junto con la URL pública y la `API_KEY`. En `ejemplos/` hay scripts listos para adaptar.

## 5. Respaldo

Todo vive en la carpeta `data/` (base `notificaciones.db` + adjuntos). Basta con copiar esa carpeta periódicamente (tarea programada con robocopy/rsync a otro disco o nube).

## Estructura

```
panel-notificaciones/
├── main.py                  # API + panel (FastAPI)
├── requirements.txt
├── .env.example             # copiar a .env y completar claves
├── templates/               # panel web y login
├── docs/API_para_los_bots.md# documento para el equipo de automatizaciones
├── ejemplos/                # scripts de envío (Python y PowerShell)
└── data/                    # se crea sola: base SQLite + adjuntos
```
