/* AutoCajon - dialog.js - Compatible IE11 / Trident */
/* Puente con Ruby vía window.location = 'skp:callback@params' o sketchup.callback() */
/* SketchUp 2017 soporta sketchup.<nombre>(json) si se registran los callbacks con add_action_callback */

var BASE = null;   /* { largo: Number, ancho: Number } detectado del clic */
var FILA_SEL = null;

/* ---------- helpers ---------- */
function $(id) { return document.getElementById(id); }

function getEspesor() {
  if ($('esp18').checked) return 18;
  if ($('esp15').checked) return 15;
  return null;
}
function getCorredera() {
  if ($('corrTel').checked) return 'telescopica';
  if ($('corrOcu').checked) return 'oculta';
  return null;
}
function getLadoAncho() {
  if ($('ladoLargo').checked) return 'largo';
  if ($('ladoAncho').checked) return 'ancho';
  return null;
}
function anchoElegido() {
  if (!BASE) return null;
  var lado = getLadoAncho();
  if (!lado) return null;
  return lado === 'largo' ? BASE.largo : BASE.ancho;
}

/* ---------- llamada a Ruby ---------- */
/* Usa sketchup.<callback> si existe (SU2017+), si no cae a skp: url */
function callRuby(name, payloadObj) {
  var json = payloadObj ? JSON.stringify(payloadObj) : "";
  if (window.sketchup && typeof window.sketchup[name] === "function") {
    window.sketchup[name](json);
  } else {
    var q = json ? encodeURIComponent(json) : "";
    window.location = "skp:" + name + "@" + q;
  }
}

/* ---------- acciones (las llama el HTML) ---------- */
function escJsStr(s) {
  return String(s)
    .replace(/\\/g, '\\\\')
    .replace(/'/g, "\\'")
    .replace(/\r/g, '')
    .replace(/\n/g, '');
}

function btnSeleccionarBase() {
  return document.getElementById('btnPickBase');
}

function setPickingState(active) {
  var btn = btnSeleccionarBase();
  if (!btn) return;
  btn.className = active ? 'footer-btn is-picking' : 'footer-btn';
}

function clearBaseUI(statusText) {
  BASE = null;
  $("panelBase").className = 'panel panel-base clearfix';
  if ($('baseIcon')) $('baseIcon').style.display = 'none';
  $('baseStatusText').innerHTML = statusText || 'Sin base seleccionada';
  $('dimLargo').innerHTML = '&mdash;';
  $('dimAncho').innerHTML = '&mdash;';
  $('optLargo').innerHTML = '&mdash;';
  $('optAncho').innerHTML = '&mdash;';
  setPickingState(false);
}

function onSeleccionarBase() {
  setPickingState(true);
  callRuby('pick_base', null);
}

function onGenerar() {
  if (!BASE) { alert('Primero seleccion\u00e1 una base.'); return; }
  if (!getLadoAncho()) { alert('Eleg\u00ed tomar largo o ancho como ancho del caj\u00f3n.'); return; }
  if (!getCorredera()) { alert('Eleg\u00ed el tipo de corredera.'); return; }
  if (!getEspesor()) { alert('Eleg\u00ed el espesor de placa.'); return; }

  var profVal = $('profundidad').value;
  var altoVal = $('alto').value;
  if (profVal === '' || profVal == null) { alert('Ingres\u00e1 la profundidad del caj\u00f3n.'); return; }
  if (altoVal === '' || altoVal == null) { alert('Ingres\u00e1 el alto del caj\u00f3n.'); return; }

  var ancho = anchoElegido();
  var prof = parseInt(profVal, 10);
  var alto = parseInt(altoVal, 10);

  if (isNaN(ancho) || ancho <= 0) { alert('Ancho inv\u00e1lido.'); return; }
  if (isNaN(prof) || prof <= 0) { alert('Profundidad inv\u00e1lida.'); return; }
  if (isNaN(alto) || alto <= 0) { alert('Alto inv\u00e1lido.'); return; }

  callRuby('generar', {
    ancho_vano: ancho,
    profundidad: prof,
    alto: alto,
    espesor: getEspesor(),
    corredera: getCorredera()
  });
}

function onSincronizar() { callRuby("sincronizar", null); }
function onGuardar()     { callRuby("guardar", null); }
function onCerrar()      { callRuby("cerrar", null); }

function onSeleccionarFila(nombre) {
  if (FILA_SEL === nombre) {
    FILA_SEL = null;
    marcarFilaSel();
    callRuby('seleccionar_cajon', { deselect: true });
    return;
  }
  FILA_SEL = nombre;
  marcarFilaSel();
  callRuby('seleccionar_cajon', { nombre: nombre });
}

function applyBaseData(d) {
  BASE = { largo: d.largo, ancho: d.ancho };
  $('panelBase').className = 'panel panel-base clearfix is-selected';
  if ($('baseIcon')) $('baseIcon').style.display = 'inline-block';
  $('baseStatusText').innerHTML = 'Base seleccionada';
  $('dimLargo').innerHTML = d.largo + ' mm';
  $('dimAncho').innerHTML = d.ancho + ' mm';
  $('optLargo').innerHTML = d.largo + ' mm';
  $('optAncho').innerHTML = d.ancho + ' mm';
  setPickingState(false);
}

/* ---------- render que llama Ruby ---------- */
/* Ruby llama: setBase(jsonString)  con {largo, ancho} o null */
function setBase(jsonString) {
  if (jsonString == null || jsonString === '' || jsonString === 'null') {
    clearBaseUI();
    return;
  }
  if (typeof jsonString === 'object') {
    applyBaseData(jsonString);
    return;
  }
  applyBaseData(JSON.parse(jsonString));
}

/* Ruby llama: setLista(jsonString) con array de cajones */
/* cada item: {nombre, ancho, alto, prof, espesor, corredera} */
function setLista(jsonString) {
  var arr = [];
  if (jsonString == null || jsonString === '' || jsonString === 'null') {
    arr = [];
  } else if (typeof jsonString === 'object' && jsonString.length != null) {
    arr = jsonString;
  } else {
    arr = JSON.parse(jsonString);
  }
  var body = $("tablaBody");
  if (!arr.length) {
    body.innerHTML = '<tr><td colspan="6" class="empty-msg">No hay cajones creados</td></tr>';
    return;
  }
  var html = "";
  for (var i = 0; i < arr.length; i++) {
    var c = arr[i];
    var corr = (c.corredera === "telescopica") ? "Telesc\u00f3pica" : "Oculta";
    var selClass = (c.nombre === FILA_SEL) ? " sel" : "";
    html += '<tr class="row' + selClass + '" onclick="onSeleccionarFila(\'' + escJsStr(c.nombre) + '\')">';
    html += '<td class="nombre">' + c.nombre + '</td>';
    html += '<td>' + c.ancho + '</td>';
    html += '<td>' + c.alto + '</td>';
    html += '<td>' + c.prof + '</td>';
    html += '<td>' + c.espesor + '</td>';
    html += '<td>' + corr + '</td>';
    html += '</tr>';
  }
  body.innerHTML = html;
}

function marcarFilaSel() {
  var rows = document.getElementsByClassName('row');
  for (var i = 0; i < rows.length; i++) {
    rows[i].className = 'row';
  }
  if (FILA_SEL == null) return;
  for (var j = 0; j < rows.length; j++) {
    var nom = rows[j].getElementsByClassName('nombre')[0];
    if (nom && nom.innerHTML === FILA_SEL) {
      rows[j].className = 'row sel';
    }
  }
}

function resetFormFull() {
  clearBaseUI();
  $('profundidad').value = '';
  $('alto').value = '';
  $('corrTel').checked = false;
  $('corrOcu').checked = false;
  $('esp18').checked = false;
  $('esp15').checked = false;
  $('ladoLargo').checked = false;
  $('ladoAncho').checked = false;
  FILA_SEL = null;
  marcarFilaSel();
}

function resetForm() {
  clearBaseUI('Caj\u00f3n creado. Seleccion\u00e1 la base del siguiente.');
  $('ladoLargo').checked = false;
  $('ladoAncho').checked = false;
}

window.setPickingState = setPickingState;

/* avisar a Ruby que el dialog cargó, para que mande la lista persistida */
window.onload = function () {
  callRuby("dialog_ready", null);
};
