// Turnos Osvaldo: aviso por Gmail para los pedidos de cambio de turno.
// 1) Entrá a https://script.google.com con la cuenta que recibe los avisos → Nuevo proyecto.
// 2) Borrá lo que hay, pegá todo este código y guardá.
// 3) Implementar → Nueva implementación → tipo "Aplicación web".
//    Ejecutar como: Yo. Quién tiene acceso: Cualquier usuario. → Implementar → Autorizar acceso.
// 4) Copiá la "URL de la aplicación web" y pegala en la app, en Aprobación de cambios → Aviso por mail.
// El mail siempre llega a la cuenta dueña de este script; nadie puede usarlo para escribirle a otra dirección.

function doPost(e) {
  var d = JSON.parse((e && e.postData && e.postData.contents) || "{}");
  var asunto = String(d._subject || "Aviso de Turnos Osvaldo").slice(0, 200);
  var filas = Object.keys(d).filter(function (k) { return k.charAt(0) !== "_"; }).map(function (k) {
    return "<tr><td style='padding:6px 10px;font-weight:bold;vertical-align:top'>" + esc(k) +
           "</td><td style='padding:6px 10px'>" + esc(String(d[k]).slice(0, 1000)) + "</td></tr>";
  }).join("");
  MailApp.sendEmail({ to: Session.getEffectiveUser().getEmail(), subject: asunto, htmlBody: "<table>" + filas + "</table>" });
  return ContentService.createTextOutput("ok");
}

function esc(s) {
  return String(s).replace(/[&<>"]/g, function (c) { return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]; });
}
