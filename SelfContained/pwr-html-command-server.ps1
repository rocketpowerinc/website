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
  "say-hello" = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "'PWR-COMMAND SYSTEM v1.0`n`nThis is a secure local web-based command execution interface developed by RocketPowerInc.`n`nFeatures:`n- Cyberpunk-themed UI with real-time command execution`n- Whitelisted command system for security`n- Local-only access (127.0.0.1) to prevent external threats`n- Bearer token authentication`n- Self-contained PowerShell script with embedded HTML/CSS/JS`n`nUse the buttons above to execute predefined system commands safely.`nAll commands run in a controlled environment with output displayed in this terminal.`n`nDeveloped for local system administration and monitoring tasks.'") }
  "list-home" = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "Get-ChildItem ~ | Select-Object Name,Length | Format-Table -Auto | Out-String") }
  "ipconfig"  = @{ File = $NetCmd; Args = @() }
  "go-pwr"    = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "Start-Process pwsh -ArgumentList '-NoExit', '-Command', '& `$env:USERPROFILE\go\bin\go-pwr.exe'; 'Running Go-PWR in new terminal window...'") }
  "exit-server" = @{ File = "internal"; Args = @() }  # Special internal command to stop server
}

# --- tiny HTTP server ---
Add-Type -AssemblyName System.Net
$listener = [System.Net.HttpListener]::new()
$prefix = "http://$BindAddress`:$Port/"
$listener.Prefixes.Add($prefix)

# Cyberpunk-themed HTML UI (buttons call /run via fetch)
$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>◢ PWR-COMMAND TERMINAL ◤</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Orbitron:wght@400;700;900&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

:root {
  --neon-cyan: #00ffff;
  --neon-pink: #ff0080;
  --neon-purple: #8000ff;
  --neon-green: #00ff41;
  --dark-bg: #0a0a0a;
  --darker-bg: #050505;
  --grid-color: #1a1a2e;
}

body {
  font-family: 'Orbitron', monospace;
  background: var(--dark-bg);
  color: var(--neon-cyan);
  min-height: 100vh;
  background-image: 
    linear-gradient(rgba(0,255,255,0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,255,255,0.03) 1px, transparent 1px);
  background-size: 20px 20px;
  animation: grid-move 20s linear infinite;
  overflow-x: hidden;
}

@keyframes grid-move {
  0% { background-position: 0 0; }
  100% { background-position: 20px 20px; }
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  position: relative;
}

.glitch {
  position: relative;
  font-size: 3rem;
  font-weight: 900;
  text-align: center;
  margin-bottom: 1rem;
  text-shadow: 
    0 0 5px var(--neon-cyan),
    0 0 10px var(--neon-cyan),
    0 0 15px var(--neon-cyan);
}

.glitch::before,
.glitch::after {
  content: attr(data-text);
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.glitch::before {
  animation: glitch-anim 2s infinite linear alternate-reverse;
  color: var(--neon-pink);
  z-index: -1;
}

.glitch::after {
  animation: glitch-anim2 1s infinite linear alternate-reverse;
  color: var(--neon-purple);
  z-index: -2;
}

@keyframes glitch-anim {
  0% { clip: rect(31px, 9999px, 94px, 0); }
  20% { clip: rect(70px, 9999px, 36px, 0); }
  40% { clip: rect(43px, 9999px, 1px, 0); }
  60% { clip: rect(5px, 9999px, 90px, 0); }
  80% { clip: rect(79px, 9999px, 65px, 0); }
  100% { clip: rect(31px, 9999px, 94px, 0); }
}

@keyframes glitch-anim2 {
  0% { clip: rect(26px, 9999px, 99px, 0); }
  20% { clip: rect(85px, 9999px, 15px, 0); }
  40% { clip: rect(91px, 9999px, 46px, 0); }
  60% { clip: rect(6px, 9999px, 88px, 0); }
  80% { clip: rect(95px, 9999px, 2px, 0); }
  100% { clip: rect(26px, 9999px, 99px, 0); }
}

.subtitle {
  text-align: center;
  font-size: 1.2rem;
  margin-bottom: 3rem;
  color: var(--neon-green);
  text-shadow: 0 0 10px var(--neon-green);
}

.command-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
  gap: 1.5rem;
  margin-bottom: 3rem;
}

.cmd-button {
  background: linear-gradient(45deg, var(--darker-bg), var(--dark-bg));
  border: 2px solid var(--neon-cyan);
  color: var(--neon-cyan);
  padding: 1.5rem;
  font-family: 'Orbitron', monospace;
  font-size: 1.1rem;
  font-weight: 700;
  cursor: pointer;
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
  text-transform: uppercase;
  letter-spacing: 2px;
}

.cmd-button::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(0,255,255,0.2), transparent);
  transition: left 0.5s;
}

.cmd-button:hover {
  border-color: var(--neon-pink);
  color: var(--neon-pink);
  box-shadow: 
    0 0 20px var(--neon-pink),
    inset 0 0 20px rgba(255,0,128,0.1);
  transform: translateY(-2px);
}

.cmd-button:hover::before {
  left: 100%;
}

.cmd-button:active {
  transform: translateY(0);
  box-shadow: 
    0 0 10px var(--neon-pink),
    inset 0 0 10px rgba(255,0,128,0.2);
}

.exit-btn {
  border-color: var(--neon-pink) !important;
  color: var(--neon-pink) !important;
}

.exit-btn:hover {
  border-color: #ff4444 !important;
  color: #ff4444 !important;
  box-shadow: 
    0 0 20px #ff4444,
    inset 0 0 20px rgba(255,68,68,0.1);
}

.terminal {
  background: var(--darker-bg);
  border: 2px solid var(--neon-green);
  border-radius: 8px;
  padding: 1.5rem;
  font-family: 'Courier New', monospace;
  font-size: 0.9rem;
  color: var(--neon-green);
  min-height: 300px;
  max-height: 60vh;
  overflow-y: auto;
  white-space: pre-wrap;
  position: relative;
  box-shadow: 
    0 0 20px rgba(0,255,65,0.3),
    inset 0 0 20px rgba(0,255,65,0.05);
}

.terminal::before {
  content: '◢ TERMINAL OUTPUT ◤';
  position: absolute;
  top: -12px;
  left: 20px;
  background: var(--darker-bg);
  padding: 0 10px;
  color: var(--neon-green);
  font-family: 'Orbitron', monospace;
  font-size: 0.8rem;
  font-weight: 700;
}

.terminal::-webkit-scrollbar {
  width: 8px;
}

.terminal::-webkit-scrollbar-track {
  background: var(--darker-bg);
}

.terminal::-webkit-scrollbar-thumb {
  background: var(--neon-green);
  border-radius: 4px;
}

.status {
  position: fixed;
  top: 20px;
  right: 20px;
  background: rgba(0,0,0,0.8);
  border: 1px solid var(--neon-cyan);
  padding: 0.5rem 1rem;
  font-family: 'Orbitron', monospace;
  font-size: 0.8rem;
  color: var(--neon-cyan);
  border-radius: 4px;
}

.loading {
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0% { opacity: 1; }
  50% { opacity: 0.5; }
  100% { opacity: 1; }
}

.cyber-line {
  height: 2px;
  background: linear-gradient(90deg, transparent, var(--neon-cyan), transparent);
  margin: 2rem 0;
  animation: scan 3s infinite;
}

@keyframes scan {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(100%); }
}
</style>
</head>
<body>
<div class="container">
  <h1 class="glitch" data-text="◢ PWR-COMMAND ◤">◢ PWR-COMMAND ◤</h1>
  <p class="subtitle">◢ SECURE LOCAL COMMAND EXECUTIONS ◤</p>
  
  <div class="cyber-line"></div>
  
  <div class="command-grid">
    <button class="cmd-button" onclick="run('say-hello')">
      ◢ HELLO PROTOCOL ◤
    </button>
    <button class="cmd-button" onclick="run('list-home')">
      ◢ HOME DIRECTORY ◤
    </button>
    <button class="cmd-button" onclick="run('ipconfig')">
      ◢ NETWORK STATUS ◤
    </button>
    <button class="cmd-button" onclick="run('go-pwr')">
      ◢ LAUNCH GO-PWR ◤
    </button>
    <button class="cmd-button exit-btn" onclick="exitServer()">
      ◢ SHUTDOWN SERVER ◤
    </button>
  </div>
  
  <div class="terminal" id="out">◢ AWAITING COMMAND EXECUTION ◤
  
> System Ready
> Authentication: VERIFIED
> Commands: LOADED
> Status: STANDBY</div>
</div>

<script>
const TOKEN = "$Token";

async function run(action){
  const out = document.getElementById("out");
  
  out.textContent = "◢ INITIALIZING " + action.toUpperCase() + " PROTOCOL ◤\n\n> Establishing connection...\n> Authenticating...\n> Executing command...\n\n";
  
  try{
    const r = await fetch("/run", {
      method:"POST",
      headers: {"Content-Type":"application/json","Authorization":"Bearer "+TOKEN},
      body: JSON.stringify({action})
    });
    const t = await r.text();
    out.textContent = "◢ " + action.toUpperCase() + " PROTOCOL COMPLETE ◤\n\n" + t + "\n\n◢ END TRANSMISSION ◤";
  }catch(e){
    out.textContent = "◢ ERROR PROTOCOL ◤\n\n> SYSTEM FAULT: " + e + "\n\n◢ END TRANSMISSION ◤";
  }
}

async function exitServer(){
  const out = document.getElementById("out");
  
  if(!confirm("◢ CONFIRM SERVER SHUTDOWN ◤\n\nThis will terminate the command server. Continue?")){
    return;
  }
  
  out.textContent = "◢ SHUTDOWN PROTOCOL INITIATED ◤\n\n> Terminating connections...\n> Shutting down server...\n> Goodbye!\n\n◢ SERVER OFFLINE ◤";
  
  try{
    await fetch("/run", {
      method:"POST",
      headers: {"Content-Type":"application/json","Authorization":"Bearer "+TOKEN},
      body: JSON.stringify({action: "exit-server"})
    });
  }catch(e){
    // Expected - server will close connection
  }
  
  document.body.style.opacity = "0.5";
  setTimeout(() => {
    window.close();
  }, 2000);
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

# Auto-open browser
try {
  Start-Process $prefix
  Write-Host "Browser opened automatically" -ForegroundColor Cyan
}
catch {
  Write-Host "Could not auto-open browser. Please navigate to $prefix manually" -ForegroundColor Yellow
}

# Router loop
$shouldExit = $false
try {
  while ($listener.IsListening -and -not $shouldExit) {
    try {
      $ctx = $listener.GetContext()
    }
    catch {
      # Listener was stopped, exit gracefully
      break
    }

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

        # Handle special exit command
        if ($action -eq "exit-server") {
          Write-Response $ctx 200 "Server shutdown initiated..."
          Write-Host "Exit command received - shutting down server" -ForegroundColor Yellow
          $shouldExit = $true
          break  # Exit the main loop
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

Write-Host "Server stopped. Exiting..." -ForegroundColor Green
