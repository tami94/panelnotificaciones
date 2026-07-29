# Ejemplo para PowerShell 5.1 (Windows viejo, sin -Form). Envía campos y un adjunto opcional.
$uri     = "http://localhost:8000/api/notificaciones"   # cambiar por la URL real
$apiKey  = "cambiar-esta-clave"
$campos  = @{
    automatizacion = "Proceso 8 - Conciliación"
    empresa        = "Servigamers"
    tipo           = "aviso"
    mensaje        = "Se detectaron 3 registros con diferencias menores."
    id_ejecucion   = (Get-Date -Format "yyyy-MM-dd-HHmm")
}
$adjunto = ""   # ej: "C:\bots\salidas\evidencia.xlsx"  (dejar vacío si no hay)

$limite = [System.Guid]::NewGuid().ToString()
$LF = "`r`n"
$cuerpo = New-Object System.Collections.ArrayList
foreach ($k in $campos.Keys) {
    [void]$cuerpo.Add("--$limite$LF" + "Content-Disposition: form-data; name=`"$k`"$LF$LF" + $campos[$k] + $LF)
}
$texto = ($cuerpo -join "")
if ($adjunto -and (Test-Path $adjunto)) {
    $nombre = Split-Path $adjunto -Leaf
    $bytes  = [System.IO.File]::ReadAllBytes($adjunto)
    $texto += "--$limite$LF" + "Content-Disposition: form-data; name=`"archivos`"; filename=`"$nombre`"$LF" +
              "Content-Type: application/octet-stream$LF$LF"
    $inicio = [System.Text.Encoding]::UTF8.GetBytes($texto)
    $fin    = [System.Text.Encoding]::UTF8.GetBytes("$LF--$limite--$LF")
    $total  = New-Object byte[] ($inicio.Length + $bytes.Length + $fin.Length)
    [Array]::Copy($inicio, 0, $total, 0, $inicio.Length)
    [Array]::Copy($bytes, 0, $total, $inicio.Length, $bytes.Length)
    [Array]::Copy($fin, 0, $total, $inicio.Length + $bytes.Length, $fin.Length)
    Invoke-RestMethod -Uri $uri -Method Post -Body $total -ContentType "multipart/form-data; boundary=$limite" -Headers @{ "X-API-Key" = $apiKey }
} else {
    $texto += "--$limite--$LF"
    Invoke-RestMethod -Uri $uri -Method Post -Body ([System.Text.Encoding]::UTF8.GetBytes($texto)) -ContentType "multipart/form-data; boundary=$limite" -Headers @{ "X-API-Key" = $apiKey }
}
