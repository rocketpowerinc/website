#!/bin/bash

# pwr-html-command-server.sh
# Minimal localhost web UI that runs ONLY whitelisted commands (Linux/macOS with bash)

# --- config ---
PORT=8080
BIND_ADDRESS="127.0.0.1"  # do NOT change unless you know what you're doing
TOKEN=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)  # simple bearer token

# Check if required tools are available
command -v nc >/dev/null 2>&1 || { echo >&2 "netcat (nc) is required but not installed. Aborting."; exit 1; }
command -v openssl >/dev/null 2>&1 || { echo >&2 "openssl is required but not installed. Aborting."; exit 1; }

# Platform-specific commands
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    NET_CMD="ip addr show"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    NET_CMD="ifconfig"
else
    NET_CMD="ip addr show"
fi

# HTML content with all themes
read -r -d '' HTML_CONTENT << 'EOF'
<!doctype html>
<html>
<head>
<meta charset="utf-8"/>
<title>PWR Command System</title>
<style>
@import url('https://fonts.googleapis.com/css2?family=Creepster&family=Nosifer&family=Metal+Mania:wght@400&family=Inter:wght@300;400;500;600&family=Fredoka+One:wght@400&family=Comic+Neue:wght@400;700&display=swap');

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
  
  /* Modern Light theme colors */
  --modern-primary: #2563eb;
  --modern-secondary: #4f46e5;
  --modern-accent: #06b6d4;
  --modern-success: #10b981;
  --modern-bg: #f8fafc;
  --modern-surface: #ffffff;
  --modern-text: #1e293b;
  --modern-text-muted: #64748b;
  --modern-border: #e2e8f0;
  --modern-shadow: rgba(0, 0, 0, 0.1);
  
  /* Modern Dark theme colors */
  --dark-primary: #3b82f6;
  --dark-secondary: #6366f1;
  --dark-accent: #14b8a6;
  --dark-success: #22c55e;
  --dark-bg: #0f172a;
  --dark-surface: #1e293b;
  --dark-text: #f1f5f9;
  --dark-text-muted: #94a3b8;
  --dark-border: #334155;
  --dark-shadow: rgba(0, 0, 0, 0.3);
  
  /* Kids Boy theme colors */
  --kids-boy-primary: #4285f4;
  --kids-boy-secondary: #34a853;
  --kids-boy-accent: #fbbc04;
  --kids-boy-success: #0f9d58;
  --kids-boy-bg: #f0f8ff;
  --kids-boy-surface: #ffffff;
  --kids-boy-text: #1a202c;
  --kids-boy-text-muted: #4a5568;
  --kids-boy-border: #bee3f8;
  --kids-boy-shadow: rgba(0, 0, 0, 0.1);
  
  /* Kids Girl theme colors */
  --kids-girl-primary: #ff69b4;
  --kids-girl-secondary: #da70d6;
  --kids-girl-accent: #ffc0cb;
  --kids-girl-success: #98fb98;
  --kids-girl-bg: #fef7ff;
  --kids-girl-surface: #ffffff;
  --kids-girl-text: #2d3748;
  --kids-girl-text-muted: #718096;
  --kids-girl-border: #f7fafc;
  --kids-girl-shadow: rgba(0, 0, 0, 0.1);
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
  grid-template-columns: repeat(3, 1fr);
  gap: 2rem;
  margin-bottom: 3rem;
}

.command-grid .cmd-button:last-child {
  grid-column: 1 / -1;
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

.exit-button-container {
  position: fixed;
  bottom: 20px;
  right: 20px;
  z-index: 1000;
}

.exit-button-container .cmd-button {
  margin: 0;
  min-width: 120px;
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

/* Modern Dark Theme */
.modern-dark-theme {
  background: var(--dark-bg);
  color: var(--dark-text);
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  animation: none;
  filter: none;
  background-image: none;
}

.modern-dark-theme .apocalypse-title {
  font-family: 'Inter', sans-serif;
  font-weight: 600;
  color: var(--dark-primary);
  text-shadow: none;
  animation: none;
  font-size: 2.5rem;
  letter-spacing: -0.025em;
}

.modern-dark-theme .subtitle {
  font-family: 'Inter', sans-serif;
  font-weight: 400;
  color: var(--dark-text-muted);
  text-shadow: none;
  letter-spacing: 0;
  font-size: 1.125rem;
}

.modern-dark-theme .cmd-button {
  background: var(--dark-surface);
  border: 1px solid var(--dark-border);
  color: var(--dark-text);
  font-family: 'Inter', sans-serif;
  font-weight: 500;
  font-size: 0.875rem;
  letter-spacing: 0;
  text-transform: none;
  padding: 1rem 1.5rem;
  border-radius: 8px;
  box-shadow: 0 1px 3px var(--dark-shadow);
  transition: all 0.2s ease;
}

.modern-dark-theme .cmd-button::before {
  display: none;
}

.modern-dark-theme .cmd-button:hover {
  background: var(--dark-primary);
  border-color: var(--dark-primary);
  color: white;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
  text-shadow: none;
}

.modern-dark-theme .exit-btn {
  background: var(--dark-surface) !important;
  border-color: #ef4444 !important;
  color: #ef4444 !important;
  box-shadow: 0 1px 3px var(--dark-shadow) !important;
}

.modern-dark-theme .exit-btn:hover {
  background: #ef4444 !important;
  border-color: #ef4444 !important;
  color: white !important;
  box-shadow: 0 4px 12px rgba(239, 68, 68, 0.3) !important;
}

.modern-dark-theme .terminal {
  background: var(--dark-surface);
  border: 1px solid var(--dark-border);
  color: var(--dark-text);
  border-radius: 8px;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 0.875rem;
  box-shadow: 0 4px 6px var(--dark-shadow);
}

.modern-dark-theme .terminal::before {
  content: 'Terminal Output';
  color: var(--dark-text-muted);
  font-family: 'Inter', sans-serif;
  font-weight: 500;
  font-size: 0.75rem;
  background: var(--dark-surface);
  text-shadow: none;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.modern-dark-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--dark-primary), transparent);
  animation: modern-scan 4s ease-in-out infinite;
  box-shadow: 0 0 8px rgba(59, 130, 246, 0.4);
  height: 2px;
}

@keyframes modern-scan {
  0% { transform: translateX(-100%); opacity: 0; }
  50% { opacity: 1; }
  100% { transform: translateX(100%); opacity: 0; }
}

.modern-dark-theme .theme-btn {
  background: var(--dark-surface);
  border: 1px solid var(--dark-border);
  color: var(--dark-text);
  font-family: 'Inter', sans-serif;
  font-weight: 500;
  text-transform: none;
  letter-spacing: 0;
  border-radius: 6px;
  box-shadow: 0 1px 3px var(--dark-shadow);
}

.modern-dark-theme .theme-btn:hover {
  border-color: var(--dark-primary);
  color: var(--dark-primary);
  box-shadow: 0 2px 8px rgba(59, 130, 246, 0.3);
}

.modern-dark-theme .theme-options {
  background: var(--dark-surface);
  border: 1px solid var(--dark-border);
  border-radius: 6px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.3);
}

.modern-dark-theme .theme-option {
  border: none;
  color: var(--dark-text);
  font-family: 'Inter', sans-serif;
  font-weight: 400;
  text-transform: none;
  letter-spacing: 0;
  border-radius: 4px;
  margin: 0.25rem;
  padding: 0.75rem 1rem;
}

.modern-dark-theme .theme-option:hover {
  background: var(--dark-bg);
  color: var(--dark-text);
  box-shadow: none;
}
</style>
</head>
<body class="modern-dark-theme">
<div class="container">
  <h1 class="apocalypse-title">PWR Command System</h1>
  <p class="subtitle">Secure Local Command Execution Interface</p>
  
  <div class="apocalypse-line"></div>
  
  <div class="command-grid">
    <button class="cmd-button" onclick="run('say-hello')">
      System Information
    </button>
    <button class="cmd-button" onclick="run('list-home')">
      Home Directory
    </button>
    <button class="cmd-button" onclick="run('network')">
      Network Configuration
    </button>
    <button class="cmd-button" onclick="run('launch-pwr')">
      Launch PWR Script
    </button>
  </div>
  
  <div class="terminal" id="out">Ready for command execution

> System Status: Online
> Authentication: Verified
> Commands: Available
> Environment: Secure Local Network</div>
</div>

<div class="exit-button-container">
  <button class="cmd-button exit-btn" onclick="exitServer()">
    Stop Server
  </button>
</div>

<div class="theme-selector" id="themeSelector">
  <button class="theme-btn" onclick="toggleThemes()">THEMES</button>
  <div class="theme-options" id="themeOptions" style="display: none;">
    <button class="theme-option" onclick="setTheme('modern-dark')">● MODERN DARK ●</button>
    <button class="theme-option" onclick="setTheme('doomsday')">☠ DOOMSDAY ☠</button>
  </div>
</div>

<script>
const TOKEN = "BASH_TOKEN_PLACEHOLDER";

async function run(action){
  const out = document.getElementById("out");
  const isModernDark = document.body.classList.contains('modern-dark-theme');
  
  let symbol = isModernDark ? '●' : '☠';
  let protocol = 'INITIALIZING';
  let endMsg = isModernDark ? 'COMPLETE' : 'END TRANSMISSION';
  
  out.textContent = symbol + " " + protocol + " " + action.toUpperCase() + " PROTOCOL " + symbol + "\n\n> Establishing connection...\n> Authenticating...\n> Executing command...\n\n";
  
  try{
    const r = await fetch("/run", {
      method:"POST",
      headers: {"Content-Type":"application/json","Authorization":"Bearer "+TOKEN},
      body: JSON.stringify({action})
    });
    const t = await r.text();
    out.textContent = symbol + " " + action.toUpperCase() + " PROTOCOL " + endMsg + " " + symbol + "\n\n" + t + "\n\n" + symbol + " " + endMsg + " " + symbol;
  }catch(e){
    const errorMsg = isModernDark ? "ERROR" : "ERROR PROTOCOL";
    const failMsg = isModernDark ? "FAILED" : "TRANSMISSION FAILED";
    out.textContent = symbol + " " + errorMsg + " " + symbol + "\n\n> SYSTEM FAULT: " + e + "\n\n" + symbol + " " + failMsg + " " + symbol;
  }
}

async function exitServer(){
  const out = document.getElementById("out");
  const isModernDark = document.body.classList.contains('modern-dark-theme');
  
  let symbol = isModernDark ? '●' : '☠';
  let confirmMsg = isModernDark ? 
    "Confirm Server Shutdown\n\nThis will stop the command server. Continue?" :
    "☠ CONFIRM SERVER TERMINATION ☠\n\nThis will bring about the end of the command server. Proceed with apocalypse?";
  let shutdownMsg = isModernDark ?
    symbol + " SHUTDOWN INITIATED " + symbol + "\n\n> Closing connections...\n> Stopping server...\n> Goodbye!\n\n" + symbol + " SERVER STOPPED " + symbol :
    symbol + " DOOMSDAY PROTOCOL INITIATED " + symbol + "\n\n> Terminating all connections...\n> Shutting down server...\n> The end is near...\n\n" + symbol + " SERVER TERMINATED " + symbol;
  
  if(!confirm(confirmMsg)){
    return;
  }
  
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
  const buttons = document.querySelectorAll('.command-grid .cmd-button');
  const exitButton = document.querySelector('.exit-button-container .cmd-button');
  
  body.classList.remove('modern-dark-theme');
  
  if (theme === 'modern-dark') {
    body.classList.add('modern-dark-theme');
    title.innerHTML = 'PWR Command System';
    subtitle.innerHTML = 'Secure Local Command Execution Interface';
    terminal.innerHTML = 'Ready for command execution\n\n> System Status: Online\n> Authentication: Verified\n> Commands: Available\n> Environment: Secure Local Network';
    
    buttons[0].innerHTML = 'System Information';
    buttons[1].innerHTML = 'Home Directory';
    buttons[2].innerHTML = 'Network Configuration';
    buttons[3].innerHTML = 'Launch PWR Script';
    exitButton.innerHTML = 'Stop Server';
    
    document.querySelector('.apocalypse-line').style.animation = 'modern-scan 4s ease-in-out infinite';
    
  } else {
    // Doomsday theme (default fallback)
    title.innerHTML = '☠ PWR-COMMAND ☠';
    subtitle.innerHTML = '☠ SECURE LOCAL COMMAND EXECUTIONS ☠';
    terminal.innerHTML = '☠ AWAITING COMMAND EXECUTION ☠\n\n> System Status: OPERATIONAL\n> Authentication: VERIFIED\n> Commands: LOADED\n> Status: READY FOR DOOMSDAY';
    
    buttons[0].innerHTML = '☠ HELLO PROTOCOL ☠';
    buttons[1].innerHTML = '☠ HOME DIRECTORY ☠';
    buttons[2].innerHTML = '☠ NETWORK STATUS ☠';
    buttons[3].innerHTML = '☠ LAUNCH PWR ☠';
    exitButton.innerHTML = '☠ TERMINATE SERVER ☠';
    
    document.querySelector('.apocalypse-line').style.animation = 'end-times 4s infinite';
  }
  
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
EOF

# Function to URL decode
urldecode() {
    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

# Function to parse HTTP headers
parse_request() {
    local line
    while IFS= read -r line; do
        line=${line%$'\r'}
        if [[ -z "$line" ]]; then
            break
        fi
        echo "$line"
    done
}

# Function to execute whitelisted commands
execute_command() {
    local action="$1"
    
    case "$action" in
        "say-hello")
            cat << 'HELLO_EOF'
PWR-COMMAND SYSTEM v1.0 (Linux/Bash)

This is a secure local web-based command execution interface developed by RocketPowerInc.

Features:
- Dynamic theme switching capabilities (Modern Dark, Doomsday)
- Real-time command execution with themed output
- Whitelisted command system for security
- Local-only access (127.0.0.1) to prevent external threats
- Bearer token authentication
- Self-contained bash script with embedded HTML/CSS/JS

Use the THEMES button (bottom-left) to switch between visual modes.
Use the buttons above to execute predefined system commands safely.
All commands run in a controlled environment with output displayed in this terminal.

Developed for local system administration and monitoring tasks.
HELLO_EOF
            ;;
        "list-home")
            ls -la "$HOME" 2>&1
            ;;
        "network")
            echo "Network Configuration:"
            echo "===================="
            eval "$NET_CMD" 2>&1
            ;;
        "launch-pwr")
            if command -v go-pwr >/dev/null 2>&1; then
                echo "Launching Go-PWR in new terminal..."
                if command -v gnome-terminal >/dev/null 2>&1; then
                    gnome-terminal -- go-pwr
                elif command -v xterm >/dev/null 2>&1; then
                    xterm -e go-pwr &
                elif command -v open >/dev/null 2>&1; then  # macOS
                    open -a Terminal go-pwr
                else
                    echo "Go-PWR found but no suitable terminal emulator available."
                    echo "Available terminal emulators: gnome-terminal, xterm, open (macOS)"
                fi
                echo "Go-PWR launch attempted."
            else
                echo "Go-PWR not found in PATH."
                echo "Please install go-pwr or add it to your PATH."
            fi
            ;;
        "exit-server")
            echo "Server shutdown initiated..."
            return 1
            ;;
        *)
            echo "Unknown command: $action"
            return 1
            ;;
    esac
}

# Function to send HTTP response
send_response() {
    local status="$1"
    local content_type="${2:-text/plain; charset=utf-8}"
    local body="$3"
    
    local content_length=${#body}
    
    cat << EOF
HTTP/1.1 $status
Content-Type: $content_type
Content-Length: $content_length
Cache-Control: no-store
Access-Control-Allow-Origin: *
Access-Control-Allow-Headers: Content-Type,Authorization
Access-Control-Allow-Methods: GET,POST,OPTIONS
Connection: close

$body
EOF
}

# Function to handle HTTP requests
handle_request() {
    local method path headers body auth_header action
    
    # Read the first line (request line)
    read -r method path protocol
    path=${path%% *}
    
    # Read headers
    headers=$(parse_request)
    
    # Extract Content-Length if present
    local content_length=0
    if [[ "$headers" =~ Content-Length:[[:space:]]*([0-9]+) ]]; then
        content_length=${BASH_REMATCH[1]}
    fi
    
    # Extract Authorization header
    if [[ "$headers" =~ Authorization:[[:space:]]*Bearer[[:space:]]+([^[:space:]]+) ]]; then
        auth_header=${BASH_REMATCH[1]}
    fi
    
    # Read body if present
    if [[ $content_length -gt 0 ]]; then
        body=$(head -c "$content_length")
    fi
    
    # Handle CORS preflight
    if [[ "$method" == "OPTIONS" ]]; then
        send_response "204 No Content"
        return
    fi
    
    # Route handling
    case "$path" in
        "/")
            local html_with_token="${HTML_CONTENT//BASH_TOKEN_PLACEHOLDER/$TOKEN}"
            send_response "200 OK" "text/html; charset=utf-8" "$html_with_token"
            ;;
        "/run")
            # Check authentication
            if [[ "$auth_header" != "$TOKEN" ]]; then
                send_response "403 Forbidden" "text/plain" "Bad token."
                return
            fi
            
            # Parse JSON body to extract action
            if [[ "$body" =~ \"action\":[[:space:]]*\"([^\"]+)\" ]]; then
                action=${BASH_REMATCH[1]}
            else
                send_response "400 Bad Request" "text/plain" "Missing or invalid action."
                return
            fi
            
            # Execute command
            local output
            output=$(execute_command "$action" 2>&1)
            local exit_code=$?
            
            if [[ $exit_code -eq 1 && "$action" == "exit-server" ]]; then
                send_response "200 OK" "text/plain" "$output"
                return 1  # Signal to exit server
            elif [[ $exit_code -ne 0 ]]; then
                send_response "500 Internal Server Error" "text/plain" "Execution error: Command failed"
            else
                send_response "200 OK" "text/plain" "$output"
            fi
            ;;
        *)
            send_response "404 Not Found" "text/plain" "Not found."
            ;;
    esac
}

# Main server loop
start_server() {
    local should_exit=false
    
    echo "PWR Command Server (Bash) starting..."
    echo "Open http://$BIND_ADDRESS:$PORT  (token: $TOKEN)"
    
    # Try to auto-open browser
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "http://$BIND_ADDRESS:$PORT" 2>/dev/null &
        echo "Browser opened automatically"
    elif command -v open >/dev/null 2>&1; then  # macOS
        open "http://$BIND_ADDRESS:$PORT" 2>/dev/null &
        echo "Browser opened automatically"
    else
        echo "Could not auto-open browser. Please navigate to http://$BIND_ADDRESS:$PORT manually"
    fi
    
    while [[ "$should_exit" == false ]]; do
        # Use netcat to listen for connections
        if command -v nc >/dev/null 2>&1; then
            if handle_request < <(nc -l -p "$PORT" -q 1 2>/dev/null) > >(nc -l -p "$PORT" -q 1 2>/dev/null); then
                :  # Continue
            else
                should_exit=true
            fi
        else
            echo "Error: netcat (nc) is required but not installed."
            exit 1
        fi
    done
    
    echo "Server stopped. Exiting..."
}

# Simple netcat-based server (alternative approach)
run_simple_server() {
    echo "PWR Command Server (Bash) starting on http://$BIND_ADDRESS:$PORT"
    echo "Token: $TOKEN"
    
    # Try to auto-open browser
    if command -v xdg-open >/dev/null 2>&1; then
        xdg-open "http://$BIND_ADDRESS:$PORT" 2>/dev/null &
        echo "Browser opened automatically"
    elif command -v open >/dev/null 2>&1; then  # macOS
        open "http://$BIND_ADDRESS:$PORT" 2>/dev/null &
        echo "Browser opened automatically"
    else
        echo "Could not auto-open browser. Please navigate to http://$BIND_ADDRESS:$PORT manually"
    fi
    
    while true; do
        # Create a named pipe for communication
        local pipe="/tmp/pwr_server_$$"
        mkfifo "$pipe"
        
        # Start netcat listener in background
        (
            while true; do
                {
                    if handle_request; then
                        continue
                    else
                        echo "EXIT" > "$pipe"
                        break
                    fi
                } < <(nc -l "$BIND_ADDRESS" "$PORT" 2>/dev/null)
            done
        ) &
        
        local nc_pid=$!
        
        # Wait for exit signal or netcat to finish
        if read -r line < "$pipe" && [[ "$line" == "EXIT" ]]; then
            kill $nc_pid 2>/dev/null
            rm -f "$pipe"
            break
        fi
        
        rm -f "$pipe"
        wait $nc_pid
    done
    
    echo "Server stopped. Exiting..."
}

# Check if we can bind to the port
if ! nc -z "$BIND_ADDRESS" "$PORT" 2>/dev/null; then
    start_server
else
    echo "Error: Port $PORT is already in use on $BIND_ADDRESS"
    exit 1
fi
