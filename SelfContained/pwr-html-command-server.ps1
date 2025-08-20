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
  "say-hello" = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "'PWR-COMMAND SYSTEM v1.0`n`nThis is a secure local web-based command execution interface developed by RocketPowerInc.`n`nFeatures:`n- Dual-theme UI with cyberpunk and doomsday visual modes`n- Dynamic theme switching with animated transitions`n- Real-time command execution with themed output`n- Whitelisted command system for security`n- Local-only access (127.0.0.1) to prevent external threats`n- Bearer token authentication`n- Self-contained PowerShell script with embedded HTML/CSS/JS`n`nUse the THEMES button (bottom-left) to switch between visual modes.`nUse the buttons above to execute predefined system commands safely.`nAll commands run in a controlled environment with output displayed in this terminal.`n`nDeveloped for local system administration and monitoring tasks.'") }
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
@import url('https://fonts.googleapis.com/css2?family=Creepster&family=Nosifer&family=Metal+Mania:wght@400&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

:root {
  --blood-red: #8B0000;
  --fire-orange: #FF4500;
  --ash-gray: #696969;
  --bone-white: #F5F5DC;
  --void-black: #0D0D0D;
  --deep-black: #000000;
  --rust-brown: #A0522D;
  --decay-green: #556B2F;
}

body {
  font-family: 'Metal Mania', cursive;
  background: var(--void-black);
  color: var(--bone-white);
  min-height: 100vh;
  background-image: 
    radial-gradient(circle at 20% 80%, rgba(139,0,0,0.1) 0%, transparent 50%),
    radial-gradient(circle at 80% 20%, rgba(255,69,0,0.1) 0%, transparent 50%),
    linear-gradient(rgba(105,105,105,0.02) 1px, transparent 1px),
    linear-gradient(90deg, rgba(105,105,105,0.02) 1px, transparent 1px);
  background-size: 100% 100%, 100% 100%, 30px 30px, 30px 30px;
  animation: apocalypse-flicker 15s linear infinite;
  overflow-x: hidden;
}

@keyframes apocalypse-flicker {
  0% { filter: brightness(1) contrast(1); }
  10% { filter: brightness(0.9) contrast(1.1); }
  20% { filter: brightness(1.1) contrast(0.9); }
  30% { filter: brightness(0.95) contrast(1); }
  40% { filter: brightness(1.05) contrast(1.1); }
  50% { filter: brightness(0.8) contrast(1.2); }
  60% { filter: brightness(1.2) contrast(0.8); }
  70% { filter: brightness(0.9) contrast(1.1); }
  80% { filter: brightness(1.1) contrast(0.9); }
  90% { filter: brightness(0.95) contrast(1.05); }
  100% { filter: brightness(1) contrast(1); }
}

.container {
  max-width: 1200px;
  margin: 0 auto;
  padding: 2rem;
  position: relative;
}

.apocalypse-title {
  position: relative;
  font-family: 'Nosifer', cursive;
  font-size: 3.5rem;
  font-weight: 400;
  text-align: center;
  margin-bottom: 1rem;
  color: var(--blood-red);
  text-shadow: 
    0 0 10px var(--fire-orange),
    0 0 20px var(--blood-red),
    0 0 30px var(--blood-red),
    2px 2px 0px var(--void-black);
  animation: doomsday-glow 3s ease-in-out infinite alternate;
}

@keyframes doomsday-glow {
  0% { 
    text-shadow: 
      0 0 10px var(--fire-orange),
      0 0 20px var(--blood-red),
      0 0 30px var(--blood-red),
      2px 2px 0px var(--void-black);
  }
  100% { 
    text-shadow: 
      0 0 20px var(--fire-orange),
      0 0 40px var(--blood-red),
      0 0 60px var(--blood-red),
      2px 2px 0px var(--void-black);
  }
}

.subtitle {
  text-align: center;
  font-size: 1.3rem;
  margin-bottom: 3rem;
  color: var(--ash-gray);
  text-shadow: 
    0 0 10px var(--rust-brown),
    1px 1px 2px var(--void-black);
  font-family: 'Creepster', cursive;
  letter-spacing: 2px;
}

.command-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 2rem;
  margin-bottom: 3rem;
}

.cmd-button {
  background: linear-gradient(145deg, var(--deep-black), var(--void-black));
  border: 3px solid var(--blood-red);
  color: var(--bone-white);
  padding: 1.8rem;
  font-family: 'Metal Mania', cursive;
  font-size: 1.2rem;
  font-weight: 400;
  cursor: pointer;
  transition: all 0.4s ease;
  position: relative;
  overflow: hidden;
  text-transform: uppercase;
  letter-spacing: 3px;
  box-shadow: 
    0 0 15px rgba(139,0,0,0.3),
    inset 0 0 15px rgba(0,0,0,0.8);
}

.cmd-button::before {
  content: '';
  position: absolute;
  top: 0;
  left: -100%;
  width: 100%;
  height: 100%;
  background: linear-gradient(90deg, transparent, rgba(255,69,0,0.3), transparent);
  transition: left 0.6s;
}

.cmd-button:hover {
  border-color: var(--fire-orange);
  color: var(--fire-orange);
  box-shadow: 
    0 0 30px var(--fire-orange),
    0 0 60px rgba(255,69,0,0.3),
    inset 0 0 20px rgba(255,69,0,0.1);
  transform: translateY(-3px);
  text-shadow: 0 0 10px var(--fire-orange);
}

.cmd-button:hover::before {
  left: 100%;
}

.cmd-button:active {
  transform: translateY(0);
  box-shadow: 
    0 0 15px var(--fire-orange),
    inset 0 0 15px rgba(255,69,0,0.2);
}

.exit-btn {
  border-color: #DC143C !important;
  color: #DC143C !important;
  box-shadow: 
    0 0 15px rgba(220,20,60,0.4),
    inset 0 0 15px rgba(0,0,0,0.8);
}

.exit-btn:hover {
  border-color: #FF6347 !important;
  color: #FF6347 !important;
  box-shadow: 
    0 0 30px #FF6347,
    0 0 60px rgba(255,99,71,0.4),
    inset 0 0 20px rgba(255,99,71,0.1);
}

.terminal {
  background: linear-gradient(145deg, var(--deep-black), var(--void-black));
  border: 3px solid var(--decay-green);
  border-radius: 8px;
  padding: 2rem;
  font-family: 'Courier New', monospace;
  font-size: 1rem;
  color: var(--bone-white);
  min-height: 350px;
  max-height: 60vh;
  overflow-y: auto;
  white-space: pre-wrap;
  position: relative;
  box-shadow: 
    0 0 25px rgba(85,107,47,0.4),
    inset 0 0 25px rgba(0,0,0,0.8);
}

.terminal::before {
  content: '☠ DOOMSDAY TERMINAL ☠';
  position: absolute;
  top: -15px;
  left: 25px;
  background: var(--deep-black);
  padding: 0 15px;
  color: var(--decay-green);
  font-family: 'Creepster', cursive;
  font-size: 0.9rem;
  font-weight: 400;
  text-shadow: 0 0 10px var(--decay-green);
}

.terminal::-webkit-scrollbar {
  width: 10px;
}

.terminal::-webkit-scrollbar-track {
  background: var(--deep-black);
}

.terminal::-webkit-scrollbar-thumb {
  background: var(--decay-green);
  border-radius: 5px;
  box-shadow: 0 0 5px var(--decay-green);
}

.apocalypse-line {
  height: 3px;
  background: linear-gradient(90deg, transparent, var(--blood-red), var(--fire-orange), var(--blood-red), transparent);
  margin: 2.5rem 0;
  animation: end-times 4s infinite;
  box-shadow: 0 0 15px var(--blood-red);
}

@keyframes end-times {
  0% { transform: translateX(-100%) scaleX(0.8); opacity: 0.7; }
  50% { transform: translateX(0%) scaleX(1.2); opacity: 1; }
  100% { transform: translateX(100%) scaleX(0.8); opacity: 0.7; }
}

.theme-selector {
  position: fixed;
  bottom: 20px;
  left: 20px;
  z-index: 1000;
}

.theme-btn {
  background: linear-gradient(145deg, var(--deep-black), var(--void-black));
  border: 2px solid var(--ash-gray);
  color: var(--bone-white);
  padding: 0.8rem 1.2rem;
  font-family: 'Metal Mania', cursive;
  font-size: 0.9rem;
  cursor: pointer;
  border-radius: 4px;
  transition: all 0.3s ease;
  text-transform: uppercase;
  letter-spacing: 1px;
}

.theme-btn:hover {
  border-color: var(--fire-orange);
  color: var(--fire-orange);
  box-shadow: 0 0 15px rgba(255,69,0,0.3);
}

.theme-options {
  position: absolute;
  bottom: 100%;
  left: 0;
  margin-bottom: 10px;
  background: linear-gradient(145deg, var(--deep-black), var(--void-black));
  border: 2px solid var(--ash-gray);
  border-radius: 4px;
  padding: 0.5rem;
  min-width: 200px;
  box-shadow: 0 0 20px rgba(0,0,0,0.8);
}

.theme-option {
  display: block;
  width: 100%;
  background: transparent;
  border: 1px solid var(--rust-brown);
  color: var(--bone-white);
  padding: 0.8rem 1rem;
  margin: 0.2rem 0;
  font-family: 'Metal Mania', cursive;
  font-size: 0.85rem;
  cursor: pointer;
  border-radius: 3px;
  transition: all 0.3s ease;
  text-transform: uppercase;
  letter-spacing: 1px;
  white-space: nowrap;
}

.theme-option:hover {
  background: var(--rust-brown);
  color: var(--bone-white);
  box-shadow: 0 0 10px rgba(160,82,45,0.3);
}

.cyberpunk-option {
  font-family: 'Orbitron', monospace !important;
  color: #00ffff !important;
  border-color: #00ffff !important;
  text-shadow: 0 0 5px #00ffff;
}

.cyberpunk-option:hover {
  background: rgba(0,255,255,0.1) !important;
  color: #00ffff !important;
  box-shadow: 0 0 15px rgba(0,255,255,0.3) !important;
}

.doomsday-option {
  font-family: 'Creepster', cursive !important;
  color: #8B0000 !important;
  border-color: #8B0000 !important;
  text-shadow: 0 0 5px #8B0000;
}

.doomsday-option:hover {
  background: rgba(139,0,0,0.1) !important;
  color: #8B0000 !important;
  box-shadow: 0 0 15px rgba(139,0,0,0.3) !important;
}

.cyberpunk-theme .theme-btn {
  font-family: 'Orbitron', monospace;
  border-color: #00ffff;
  color: #00ffff;
  background: linear-gradient(145deg, #050505, #0a0a0a);
}

.cyberpunk-theme .theme-btn:hover {
  border-color: #ff0080;
  color: #ff0080;
  box-shadow: 0 0 15px rgba(255,0,128,0.3);
}

.cyberpunk-theme .theme-options {
  background: linear-gradient(145deg, #050505, #0a0a0a);
  border-color: #00ffff;
}

/* Cyberpunk theme styles */
.cyberpunk-theme {
  --primary-color: #00ffff;
  --secondary-color: #ff0080;
  --accent-color: #8000ff;
  --success-color: #00ff41;
  --bg-dark: #0a0a0a;
  --bg-darker: #050505;
}

.cyberpunk-theme {
  background: var(--bg-dark);
  background-image: 
    linear-gradient(rgba(0,255,255,0.03) 1px, transparent 1px),
    linear-gradient(90deg, rgba(0,255,255,0.03) 1px, transparent 1px);
  background-size: 20px 20px;
  animation: cyber-grid-move 20s linear infinite;
  filter: none;
}

@keyframes cyber-grid-move {
  0% { background-position: 0 0; }
  100% { background-position: 20px 20px; }
}

.cyberpunk-theme .apocalypse-title {
  font-family: 'Orbitron', monospace;
  color: var(--primary-color);
  text-shadow: 
    0 0 5px var(--primary-color),
    0 0 10px var(--primary-color),
    0 0 15px var(--primary-color);
  animation: none;
}

.cyberpunk-theme .subtitle {
  font-family: 'Orbitron', monospace;
  color: var(--success-color);
  text-shadow: 0 0 10px var(--success-color);
}

.cyberpunk-theme .cmd-button {
  border-color: var(--primary-color);
  color: var(--primary-color);
  font-family: 'Orbitron', monospace;
  background: linear-gradient(45deg, var(--bg-darker), var(--bg-dark));
  box-shadow: none;
}

.cyberpunk-theme .cmd-button:hover {
  border-color: var(--secondary-color);
  color: var(--secondary-color);
  box-shadow: 
    0 0 20px var(--secondary-color),
    inset 0 0 20px rgba(255,0,128,0.1);
}

.cyberpunk-theme .cmd-button::before {
  background: linear-gradient(90deg, transparent, rgba(0,255,255,0.2), transparent);
}

.cyberpunk-theme .exit-btn {
  border-color: var(--secondary-color) !important;
  color: var(--secondary-color) !important;
}

.cyberpunk-theme .exit-btn:hover {
  border-color: #ff4444 !important;
  color: #ff4444 !important;
  box-shadow: 
    0 0 20px #ff4444,
    inset 0 0 20px rgba(255,68,68,0.1);
}

.cyberpunk-theme .terminal {
  border-color: var(--success-color);
  color: var(--success-color);
  background: var(--bg-darker);
  box-shadow: 
    0 0 20px rgba(0,255,65,0.3),
    inset 0 0 20px rgba(0,255,65,0.05);
}

.cyberpunk-theme .terminal::before {
  content: '◢ TERMINAL OUTPUT ◤';
  color: var(--success-color);
  font-family: 'Orbitron', monospace;
  background: var(--bg-darker);
}

.cyberpunk-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--primary-color), transparent);
  animation: cyber-scan 3s infinite;
  box-shadow: 0 0 15px var(--primary-color);
}

@keyframes cyber-scan {
  0% { transform: translateX(-100%); }
  100% { transform: translateX(100%); }
}
</style>
</head>
<body class="cyberpunk-theme">
<div class="container">
  <h1 class="apocalypse-title">◢ PWR-COMMAND ◤</h1>
  <p class="subtitle">◢ SECURE LOCAL COMMAND EXECUTIONS ◤</p>
  
  <div class="apocalypse-line"></div>
  
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

<div class="theme-selector" id="themeSelector">
  <button class="theme-btn" onclick="toggleThemes()">THEMES</button>
  <div class="theme-options" id="themeOptions" style="display: none;">
    <button class="theme-option cyberpunk-option" onclick="setTheme('cyberpunk')">◢ CYBERPUNK ◤</button>
    <button class="theme-option doomsday-option" onclick="setTheme('doomsday')">☠ DOOMSDAY ☠</button>
  </div>
</div>

<script>
const TOKEN = "$Token";

async function run(action){
  const out = document.getElementById("out");
  const isCyberpunk = document.body.classList.contains('cyberpunk-theme');
  const symbol = isCyberpunk ? '◢' : '☠';
  
  out.textContent = symbol + " INITIALIZING " + action.toUpperCase() + " PROTOCOL " + symbol + "\n\n> Establishing connection...\n> Authenticating...\n> Executing command...\n\n";
  
  try{
    const r = await fetch("/run", {
      method:"POST",
      headers: {"Content-Type":"application/json","Authorization":"Bearer "+TOKEN},
      body: JSON.stringify({action})
    });
    const t = await r.text();
    out.textContent = symbol + " " + action.toUpperCase() + " PROTOCOL COMPLETE " + symbol + "\n\n" + t + "\n\n" + symbol + " END TRANSMISSION " + symbol;
  }catch(e){
    const errorMsg = "ERROR PROTOCOL";
    const endMsg = isCyberpunk ? "END TRANSMISSION" : "TRANSMISSION FAILED";
    out.textContent = symbol + " " + errorMsg + " " + symbol + "\n\n> SYSTEM FAULT: " + e + "\n\n" + symbol + " " + endMsg + " " + symbol;
  }
}

async function exitServer(){
  const out = document.getElementById("out");
  const isCyberpunk = document.body.classList.contains('cyberpunk-theme');
  const symbol = isCyberpunk ? '◢' : '☠';
  const confirmMsg = isCyberpunk ? 
    "◢ CONFIRM SERVER SHUTDOWN ◤\n\nThis will terminate the command server. Continue?" :
    "☠ CONFIRM SERVER TERMINATION ☠\n\nThis will bring about the end of the command server. Proceed with apocalypse?";
  
  if(!confirm(confirmMsg)){
    return;
  }
  
  const shutdownMsg = isCyberpunk ?
    symbol + " SHUTDOWN PROTOCOL INITIATED " + symbol + "\n\n> Terminating connections...\n> Shutting down server...\n> Goodbye!\n\n" + symbol + " SERVER OFFLINE " + symbol :
    symbol + " DOOMSDAY PROTOCOL INITIATED " + symbol + "\n\n> Terminating all connections...\n> Shutting down server...\n> The end is near...\n\n" + symbol + " SERVER TERMINATED " + symbol;
  
  out.textContent = shutdownMsg;
  
  try{
    await fetch("/run", {
      method:"POST",
      headers: {"Content-Type":"application/json","Authorization":"Bearer "+TOKEN},
      body: JSON.stringify({action: "exit-server"})
    });
  }catch(e){
    // Expected - server will close connection
  }
  
  document.body.style.opacity = "0.3";
  document.body.style.filter = "blur(2px)";
  setTimeout(() => {
    window.close();
  }, 2000);
}

function toggleThemes() {
  const options = document.getElementById("themeOptions");
  options.style.display = options.style.display === "none" ? "block" : "none";
}

function setTheme(theme) {
  const body = document.body;
  const title = document.querySelector('.apocalypse-title');
  const subtitle = document.querySelector('.subtitle');
  const terminal = document.getElementById('out');
  const buttons = document.querySelectorAll('.cmd-button');
  
  if (theme === 'cyberpunk') {
    body.classList.add('cyberpunk-theme');
    title.innerHTML = '◢ PWR-COMMAND ◤';
    subtitle.innerHTML = '◢ SECURE LOCAL COMMAND EXECUTIONS ◤';
    terminal.innerHTML = '◢ AWAITING COMMAND EXECUTION ◤\n\n> System Ready\n> Authentication: VERIFIED\n> Commands: LOADED\n> Status: STANDBY';
    
    buttons[0].innerHTML = '◢ HELLO PROTOCOL ◤';
    buttons[1].innerHTML = '◢ HOME DIRECTORY ◤';
    buttons[2].innerHTML = '◢ NETWORK STATUS ◤';
    buttons[3].innerHTML = '◢ LAUNCH GO-PWR ◤';
    buttons[4].innerHTML = '◢ SHUTDOWN SERVER ◤';
    
    // Update animation class
    document.querySelector('.apocalypse-line').style.animation = 'cyber-scan 3s infinite';
    
  } else {
    body.classList.remove('cyberpunk-theme');
    title.innerHTML = '☠ PWR-COMMAND ☠';
    subtitle.innerHTML = '☠ SECURE LOCAL COMMAND EXECUTIONS ☠';
    terminal.innerHTML = '☠ AWAITING COMMAND EXECUTION ☠\n\n> System Status: OPERATIONAL\n> Authentication: VERIFIED\n> Commands: LOADED\n> Status: READY FOR DOOMSDAY';
    
    buttons[0].innerHTML = '☠ HELLO PROTOCOL ☠';
    buttons[1].innerHTML = '☠ HOME DIRECTORY ☠';
    buttons[2].innerHTML = '☠ NETWORK STATUS ☠';
    buttons[3].innerHTML = '☠ LAUNCH GO-PWR ☠';
    buttons[4].innerHTML = '☠ TERMINATE SERVER ☠';
    
    // Reset animation
    document.querySelector('.apocalypse-line').style.animation = 'end-times 4s infinite';
  }
  
  // Hide theme options after selection
  document.getElementById("themeOptions").style.display = "none";
}

// Close theme selector when clicking outside
document.addEventListener('click', function(event) {
  const selector = document.getElementById('themeSelector');
  const options = document.getElementById('themeOptions');
  if (!selector.contains(event.target)) {
    options.style.display = 'none';
  }
});
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
