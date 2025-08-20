# Run-LocalWebCmd.ps1
# Minimal localhost web UI that runs ONLY whitelisted commands (Windows/macOS/Linux with PowerShell 7)

# --- config ---
$Port = 8080
$BindAddress = "127.0.0.1"  # do NOT change unless you know what you're doing
$Token = [Convert]::ToBase64String([Guid]::NewGuid().ToByteArray())  # simple bearer token

# Pre-compute platform-specific commands (avoid 'if' inside hashtables)
$NetCmd = if ($IsWindows) { "ipconfig" } else { "ifconfig" }

# Map button "actions" -> commands to run (edit these!)
$AllowList = @{
  "say-hello" = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "'Hello from PowerShell'") }
  "list-home" = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "Get-ChildItem ~ | Select-Object Name,Length | Format-Table -Auto | Out-String") }
  "ipconfig"  = @{ File = $NetCmd; Args = @() }
  "go-pwr"    = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "Start-Process pwsh -ArgumentList '-NoExit', '-Command', '& `$env:USERPROFILE\go\bin\go-pwr.exe'; 'Running Go-PWR in new terminal window...'") }
}

# --- tiny HTTP server ---
Add-Type -AssemblyName System.Net.HttpListener
$listener = [System.Net.HttpListener]::new()
$prefix = "http://$BindAddress`:$Port/"
$listener.Prefixes.Add($prefix)

# Simple HTML UI (buttons call /run via fetch)
$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>Local Command Panel</title>
<style>
 body{font-family:system-ui,Segoe UI,Helvetica,Arial,sans-serif;margin:2rem;max-width:900px}
 button{padding:.6rem 1rem;margin:.3rem;cursor:pointer}
 pre{background:#111;color:#eee;padding:1rem;overflow:auto;max-height:50vh}
 .row{margin:.6rem 0}
</style>
</head>
<body>
<h2>Local Command Panel</h2>
<p>These buttons run predefined, safe commands on <code>localhost</code>.</p>
<div class="row">
  <button onclick="run('say-hello')">Say Hello</button>
  <button onclick="run('list-home')">List Home</button>
  <button onclick="run('ipconfig')">IP Config</button>
  <button onclick="run('go-pwr')">Go PWR</button>
</div>
<pre id="out">Click a button…</pre>
<script>
const TOKEN = "$Token";
async function run(action){
  const out = document.getElementById("out");
  out.textContent = "Running " + action + "…";
  try{
    const r = await fetch("/run", {
      method:"POST",
      headers: {"Content-Type":"application/json","Authorization":"Bearer "+TOKEN},
      body: JSON.stringify({action})
    });
    const t = await r.text();
    out.textContent = t;
  }catch(e){
    out.textContent = "Error: " + e;
  }
}
</script>
</body>
</html>
"@

function Write-Response($ctx, [int]$status, $body, $contentType = "text/plain; charset=utf-8") {
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  $ctx.Response.StatusCode = $status
  $ctx.Response.ContentType = $contentType
  $ctx.Response.ContentLength64 = $bytes.Length
  $ctx.Response.Headers.Add("Cache-Control", "no-store")
  $ctx.Response.Headers.Add("Access-Control-Allow-Origin", "*")
  $ctx.Response.Headers.Add("Access-Control-Allow-Headers", "Content-Type,Authorization")
  $ctx.Response.Headers.Add("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
  $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
  $ctx.Response.OutputStream.Close()
}

# Try to start and give a helpful hint if URL ACL is missing
try {
  $listener.Start()
}
catch {
  if ($IsWindows -and $_.Exception.Message -match "Access is denied") {
    Write-Warning "Access denied starting HttpListener on $prefix"
    Write-Host "Fix (run once, elevated PowerShell):" -ForegroundColor Yellow
    Write-Host ('  netsh http add urlacl url="{0}" user="{1}" listen=yes' -f $prefix, $env:USERNAME) -ForegroundColor Yellow
    Write-Host "Then re-run this script (no elevation required)." -ForegroundColor Yellow
    throw
  }
  else {
    throw
  }
}

Write-Host ("Open {0}  (token: {1})" -f $prefix, $Token) -ForegroundColor Green

# Router loop
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()

    # CORS/Preflight (simple)
    if ($ctx.Request.HttpMethod -eq "OPTIONS") {
      $ctx.Response.AddHeader("Access-Control-Allow-Origin", "null")
      $ctx.Response.AddHeader("Access-Control-Allow-Headers", "Content-Type,Authorization")
      $ctx.Response.AddHeader("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
      Write-Response $ctx 204 ""
      continue
    }

    switch ($ctx.Request.Url.AbsolutePath) {
      "/" { Write-Response $ctx 200 $html "text/html; charset=utf-8" }
      "/run" {
        $auth = $ctx.Request.Headers["Authorization"]
        if (-not $auth -or -not $auth.StartsWith("Bearer ")) { Write-Response $ctx 401 "Missing auth." ; continue }
        if ($auth.Substring(7) -ne $Token) { Write-Response $ctx 403 "Bad token." ; continue }

        $sr = New-Object IO.StreamReader($ctx.Request.InputStream, [Text.Encoding]::UTF8)
        $raw = $sr.ReadToEnd(); $sr.Close()
        try { 
          $json = $raw | ConvertFrom-Json 
          $action = $json.action
        }
        catch { 
          $json = $null 
          $action = $null
        }

        if (-not $action -or -not $AllowList.ContainsKey($action)) {
          Write-Host "DEBUG: Received action='$action', raw='$raw'" -ForegroundColor Yellow
          Write-Response $ctx 400 "Unknown or missing action: '$action'" ; continue
        }

        $cmd = $AllowList[$action]
        try {
          $p = New-Object System.Diagnostics.Process
          $p.StartInfo = New-Object System.Diagnostics.ProcessStartInfo
          $p.StartInfo.FileName = $cmd.File
          $p.StartInfo.Arguments = ($cmd.Args -join " ")
          $p.StartInfo.RedirectStandardOutput = $true
          $p.StartInfo.RedirectStandardError = $true
          $p.StartInfo.UseShellExecute = $false
          $p.StartInfo.CreateNoWindow = $true
          $null = $p.Start()
          $out = $p.StandardOutput.ReadToEnd()
          $err = $p.StandardError.ReadToEnd()
          $p.WaitForExit()

          $text = if ($err.Trim()) { "$out`n--- STDERR ---`n$err" } else { $out }
          if (-not $text.Trim()) { $text = "(no output)" }
          Write-Response $ctx 200 $text
        }
        catch {
          Write-Response $ctx 500 ("Execution error: " + $_.Exception.Message)
        }
      }
      Default { Write-Response $ctx 404 "Not found." }
    }
  }
}
finally {
  if ($listener -and $listener.IsListening) {
    try { $listener.Stop() } catch {}
  }
  try { $listener.Close() } catch {}
}
