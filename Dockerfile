<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="theme-color" content="#0D1321">
<title>Notificaciones RPA</title>
<style>
  :root{
    --bg:#0D1321; --surface:#161D2E; --surface2:#1C2438; --border:#242E45;
    --text:#E7ECF6; --muted:#8B96AD;
    --error:#FF6161; --aviso:#FFB84D; --resumen:#46D39A; --accion:#6FA8FF;
    --radio:12px;
  }
  *{box-sizing:border-box; margin:0}
  html{-webkit-text-size-adjust:100%}
  body{
    background:var(--bg); color:var(--text);
    font:15px/1.5 system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;
    min-height:100dvh; padding-bottom:40px;
  }
  .mono{font-family:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; font-size:.82em; color:var(--muted)}
  a{color:var(--accion)}
  button{font:inherit; cursor:pointer}
  :focus-visible{outline:2px solid var(--accion); outline-offset:2px; border-radius:6px}

  header{
    position:sticky; top:0; z-index:10; background:rgba(13,19,33,.92);
    backdrop-filter:blur(8px); border-bottom:1px solid var(--border);
    padding:14px 16px calc(0px + 12px);
  }
  .fila-titulo{display:flex; align-items:baseline; gap:10px}
  h1{font-size:17px; font-weight:700; letter-spacing:-.01em}
  h1 small{font-weight:500; color:var(--muted); font-size:12px; margin-left:6px}
  .fila-titulo a{margin-left:auto; font-size:13px; text-decoration:none; color:var(--muted)}

  /* Semáforo: contadores que también filtran */
  .semaforo{display:grid; grid-template-columns:repeat(3,1fr); gap:8px; margin-top:12px}
  .semaforo button{
    background:var(--surface); border:1px solid var(--border); border-radius:var(--radio);
    padding:10px 6px 8px; color:var(--text); text-align:center; position:relative;
  }
  .semaforo button::before{
    content:""; position:absolute; inset:0 auto 0 0; width:4px;
    border-radius:var(--radio) 0 0 var(--radio); background:var(--c);
  }
  .semaforo .num{display:block; font-size:24px; font-weight:700; font-variant-numeric:tabular-nums}
  .semaforo .rot{display:block; font-size:11px; color:var(--muted); text-transform:uppercase; letter-spacing:.06em}
  .semaforo button[aria-pressed="true"]{background:var(--surface2); border-color:var(--c)}
  .semaforo .b-error{--c:var(--error)} .semaforo .b-aviso{--c:var(--aviso)} .semaforo .b-resumen{--c:var(--resumen)}

  .filtros{display:flex; gap:8px; margin-top:10px; overflow-x:auto; padding-bottom:2px; scrollbar-width:none}
  .filtros::-webkit-scrollbar{display:none}
  .filtros select,.filtros input{
    background:var(--surface); border:1px solid var(--border); color:var(--text);
    border-radius:999px; padding:7px 12px; font-size:13px; flex:0 0 auto; max-width:46vw;
  }
  .filtros input{flex:1 1 140px; min-width:120px}

  main{padding:14px 16px; max-width:760px; margin:0 auto}
  .barra-estado{display:flex; align-items:center; gap:8px; font-size:13px; color:var(--muted); margin-bottom:10px}
  .barra-estado .punto{width:8px; height:8px; border-radius:50%; background:var(--resumen)}
  .barra-estado .pend{margin-left:auto}
  .barra-estado .pend b{color:var(--aviso)}

  .tarjeta{
    background:var(--surface); border:1px solid var(--border); border-radius:var(--radio);
    padding:12px 14px 12px 18px; margin-bottom:10px; position:relative;
  }
  .tarjeta::before{
    content:""; position:absolute; inset:0 auto 0 0; width:4px;
    border-radius:var(--radio) 0 0 var(--radio); background:var(--c,var(--muted));
  }
  .tarjeta.t-error{--c:var(--error)} .tarjeta.t-aviso{--c:var(--aviso)} .tarjeta.t-resumen{--c:var(--resumen)}
  .tarjeta.atendida{opacity:.55}
  .t-cab{display:flex; align-items:center; gap:8px; flex-wrap:wrap}
  .etiqueta{font-size:11px; font-weight:700; text-transform:uppercase; letter-spacing:.05em; color:var(--c,var(--muted))}
  .t-cab .cuando{margin-left:auto}
  .t-origen{font-size:13px; color:var(--muted); margin-top:2px}
  .t-origen b{color:var(--text); font-weight:600}
  .t-msj{margin-top:8px; white-space:pre-wrap; word-break:break-word;
    display:-webkit-box; -webkit-line-clamp:3; -webkit-box-orient:vertical; overflow:hidden}
  .tarjeta.abierta .t-msj{display:block; -webkit-line-clamp:unset}
  .t-adj{display:flex; flex-wrap:wrap; gap:6px; margin-top:10px}
  .t-adj a{
    background:var(--surface2); border:1px solid var(--border); border-radius:999px;
    padding:4px 10px; font-size:12px; text-decoration:none; color:var(--text);
    max-width:100%; overflow:hidden; text-overflow:ellipsis; white-space:nowrap;
  }
  .t-pie{display:flex; align-items:center; gap:10px; margin-top:10px}
  .t-pie .ver-mas{background:none; border:none; color:var(--muted); font-size:13px; padding:0}
  .t-pie .marcar{
    margin-left:auto; background:none; border:1px solid var(--border); color:var(--muted);
    border-radius:999px; padding:4px 12px; font-size:12px;
  }
  .t-pie .marcar:hover{border-color:var(--accion); color:var(--accion)}

  .cargar-mas{
    display:block; width:100%; margin-top:6px; padding:12px;
    background:var(--surface); color:var(--text); border:1px solid var(--border); border-radius:var(--radio);
  }
  .vacio{color:var(--muted); text-align:center; padding:48px 20px; border:1px dashed var(--border); border-radius:var(--radio)}
  @media (prefers-reduced-motion:no-preference){
    .tarjeta{animation:aparecer .25s ease both}
    @keyframes aparecer{from{opacity:0; transform:translateY(4px)}}
  }
</style>
</head>
<body>
<header>
  <div class="fila-titulo">
    <h1>Notificaciones RPA<small id="total"></small></h1>
    <a href="/logout">Cerrar sesión</a>
  </div>
  <div class="semaforo" role="group" aria-label="Filtrar por tipo de incidencia">
    <button class="b-error"   data-tipo="error"   aria-pressed="false"><span class="num" id="n-error">–</span><span class="rot">Errores</span></button>
    <button class="b-aviso"   data-tipo="aviso"   aria-pressed="false"><span class="num" id="n-aviso">–</span><span class="rot">Avisos</span></button>
    <button class="b-resumen" data-tipo="resumen" aria-pressed="false"><span class="num" id="n-resumen">–</span><span class="rot">Resúmenes</span></button>
  </div>
  <div class="filtros">
    <select id="f-empresa"><option value="">Todas las empresas</option></select>
    <select id="f-auto"><option value="">Todas las automatizaciones</option></select>
    <select id="f-estado">
      <option value="">Pendientes y atendidas</option>
      <option value="pendiente">Solo pendientes</option>
      <option value="atendida">Solo atendidas</option>
    </select>
    <input id="f-q" type="search" placeholder="Buscar en mensajes…" autocomplete="off">
  </div>
</header>

<main>
  <div class="barra-estado">
    <span class="punto" id="punto"></span><span id="actualizado">Cargando…</span>
    <span class="pend" id="pendientes"></span>
  </div>
  <div id="lista"></div>
  <button class="cargar-mas" id="cargar-mas" hidden>Cargar más</button>
</main>

<script>
const LIMITE = 30;
let offset = 0, tipoActivo = "", cargando = false;

const $ = id => document.getElementById(id);
const lista = $("lista");

function filtros(){
  const p = new URLSearchParams({limit: LIMITE, offset});
  if (tipoActivo) p.set("tipo", tipoActivo);
  if ($("f-empresa").value) p.set("empresa", $("f-empresa").value);
  if ($("f-auto").value) p.set("automatizacion", $("f-auto").value);
  if ($("f-estado").value) p.set("estado", $("f-estado").value);
  if ($("f-q").value.trim()) p.set("q", $("f-q").value.trim());
  return p;
}

function escapar(t){ const d=document.createElement("div"); d.textContent=t; return d.innerHTML; }

function fechaLegible(iso){
  const f = new Date(iso), hoy = new Date();
  const opciones = {hour:"2-digit", minute:"2-digit"};
  if (f.toDateString() === hoy.toDateString()) return "hoy " + f.toLocaleTimeString("es-AR", opciones);
  return f.toLocaleDateString("es-AR", {day:"2-digit", month:"2-digit"}) + " " + f.toLocaleTimeString("es-AR", opciones);
}

function tamanoLegible(b){
  if (b < 1024) return b + " B";
  if (b < 1048576) return (b/1024).toFixed(0) + " KB";
  return (b/1048576).toFixed(1) + " MB";
}

function tarjeta(n){
  const div = document.createElement("article");
  div.className = `tarjeta t-${n.tipo}` + (n.estado === "atendida" ? " atendida" : "");
  const adjuntos = n.adjuntos.map(a =>
    `<a href="/adjuntos/${n.id}/${encodeURIComponent(a.nombre)}" download>📎 ${escapar(a.nombre)} · ${tamanoLegible(a.tamano)}</a>`
  ).join("");
  const idEj = n.id_ejecucion ? ` · ej. ${escapar(n.id_ejecucion)}` : "";
  div.innerHTML = `
    <div class="t-cab">
      <span class="etiqueta">${n.tipo === "resumen" ? "Resumen de ejecución" : n.tipo}</span>
      <span class="mono cuando">${fechaLegible(n.fecha)}${idEj}</span>
    </div>
    <div class="t-origen"><b>${escapar(n.automatizacion)}</b> · ${escapar(n.empresa)}</div>
    <div class="t-msj">${escapar(n.mensaje)}</div>
    ${adjuntos ? `<div class="t-adj">${adjuntos}</div>` : ""}
    <div class="t-pie">
      <button class="ver-mas" hidden>Ver completo</button>
      <button class="marcar">${n.estado === "pendiente" ? "Marcar atendida" : "Volver a pendiente"}</button>
    </div>`;

  const msj = div.querySelector(".t-msj"), verMas = div.querySelector(".ver-mas");
  requestAnimationFrame(() => { if (msj.scrollHeight > msj.clientHeight + 2) verMas.hidden = false; });
  verMas.onclick = () => {
    div.classList.toggle("abierta");
    verMas.textContent = div.classList.contains("abierta") ? "Ver menos" : "Ver completo";
  };
  div.querySelector(".marcar").onclick = async () => {
    const nuevo = n.estado === "pendiente" ? "atendida" : "pendiente";
    const r = await fetch(`/api/notificaciones/${n.id}/estado`, {
      method:"PATCH", headers:{"Content-Type":"application/json"},
      body: JSON.stringify({estado: nuevo})
    });
    if (r.ok) cargar(true);
  };
  return div;
}

function llenarSelect(sel, valores){
  const actual = sel.value;
  while (sel.options.length > 1) sel.remove(1);
  for (const v of valores){
    const o = document.createElement("option"); o.value = o.textContent = v; sel.add(o);
  }
  sel.value = valores.includes(actual) ? actual : "";
}

async function cargar(reiniciar){
  if (cargando) return; cargando = true;
  if (reiniciar) offset = 0;
  try{
    const r = await fetch("/api/notificaciones?" + filtros());
    if (r.status === 401) return location.href = "/login";
    const d = await r.json();

    $("n-error").textContent   = d.resumen.error   ?? 0;
    $("n-aviso").textContent   = d.resumen.aviso   ?? 0;
    $("n-resumen").textContent = d.resumen.resumen ?? 0;
    $("total").textContent = d.total ? `${d.total} en total` : "";
    $("pendientes").innerHTML = `<b>${d.pendientes}</b> pendiente${d.pendientes === 1 ? "" : "s"}`;
    llenarSelect($("f-empresa"), d.empresas);
    llenarSelect($("f-auto"), d.automatizaciones);

    if (reiniciar) lista.innerHTML = "";
    if (!d.items.length && offset === 0){
      lista.innerHTML = `<div class="vacio">Sin notificaciones con estos filtros.<br>
        Cuando un bot envíe algo a la API, va a aparecer acá.</div>`;
    } else {
      for (const n of d.items) lista.appendChild(tarjeta(n));
    }
    offset += d.items.length;
    $("cargar-mas").hidden = offset >= d.total;
    $("actualizado").textContent = "Actualizado " + new Date().toLocaleTimeString("es-AR",{hour:"2-digit",minute:"2-digit"});
    $("punto").style.background = "var(--resumen)";
  } catch (e){
    $("actualizado").textContent = "Sin conexión con el servidor";
    $("punto").style.background = "var(--error)";
  } finally { cargando = false; }
}

document.querySelectorAll(".semaforo button").forEach(b => {
  b.onclick = () => {
    tipoActivo = (tipoActivo === b.dataset.tipo) ? "" : b.dataset.tipo;
    document.querySelectorAll(".semaforo button").forEach(x =>
      x.setAttribute("aria-pressed", x.dataset.tipo === tipoActivo));
    cargar(true);
  };
});
for (const id of ["f-empresa","f-auto","f-estado"]) $(id).onchange = () => cargar(true);
let tempo; $("f-q").oninput = () => { clearTimeout(tempo); tempo = setTimeout(() => cargar(true), 350); };
$("cargar-mas").onclick = () => cargar(false);

cargar(true);
setInterval(() => { if (offset <= LIMITE) cargar(true); }, 60000); // refresco cada 60 s en la primera página
</script>
</body>
</html>
