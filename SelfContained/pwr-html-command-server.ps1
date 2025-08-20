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
  "say-hello" = @{ File = "pwsh"; Args = @("-NoLogo", "-NoProfile", "-Command", "'PWR-COMMAND SYSTEM v1.0`n`nThis is a secure local web-based command execution interface developed by RocketPowerInc.`n`nFeatures:`n- Dynamic theme switching capabilities (Modern Dark, Modern Light, Cyberpunk, Doomsday, Kids Boy, Kids Girl)`n- Real-time command execution with themed output`n- Whitelisted command system for security`n- Local-only access (127.0.0.1) to prevent external threats`n- Bearer token authentication`n- Self-contained PowerShell script with embedded HTML/CSS/JS`n`nUse the THEMES button (bottom-left) to switch between visual modes.`nUse the buttons above to execute predefined system commands safely.`nAll commands run in a controlled environment with output displayed in this terminal.`n`nDeveloped for local system administration and monitoring tasks.'") }
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
  
  /* Kids theme colors */
  --kids-primary: #ff6b6b;
  --kids-secondary: #4ecdc4;
  --kids-accent: #ffe66d;
  --kids-success: #6bcf7f;
  --kids-bg: #fff0f5;
  --kids-surface: #ffffff;
  --kids-text: #2d3748;
  --kids-text-muted: #718096;
  --kids-border: #e2e8f0;
  --kids-shadow: rgba(0, 0, 0, 0.1);
  
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

/* Modern Professional Theme */
.modern-theme {
  background: var(--modern-bg);
  color: var(--modern-text);
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
  animation: none;
  filter: none;
  background-image: none;
}

.modern-theme .apocalypse-title {
  font-family: 'Inter', sans-serif;
  font-weight: 600;
  color: var(--modern-primary);
  text-shadow: none;
  animation: none;
  font-size: 2.5rem;
  letter-spacing: -0.025em;
}

.modern-theme .subtitle {
  font-family: 'Inter', sans-serif;
  font-weight: 400;
  color: var(--modern-text-muted);
  text-shadow: none;
  letter-spacing: 0;
  font-size: 1.125rem;
}

.modern-theme .cmd-button {
  background: var(--modern-surface);
  border: 1px solid var(--modern-border);
  color: var(--modern-text);
  font-family: 'Inter', sans-serif;
  font-weight: 500;
  font-size: 0.875rem;
  letter-spacing: 0;
  text-transform: none;
  padding: 1rem 1.5rem;
  border-radius: 8px;
  box-shadow: 0 1px 3px var(--modern-shadow);
  transition: all 0.2s ease;
}

.modern-theme .cmd-button::before {
  display: none;
}

.modern-theme .cmd-button:hover {
  background: var(--modern-primary);
  border-color: var(--modern-primary);
  color: white;
  transform: translateY(-1px);
  box-shadow: 0 4px 12px rgba(37, 99, 235, 0.15);
  text-shadow: none;
}

.modern-theme .exit-btn {
  background: var(--modern-surface) !important;
  border-color: #ef4444 !important;
  color: #ef4444 !important;
  box-shadow: 0 1px 3px var(--modern-shadow) !important;
}

.modern-theme .exit-btn:hover {
  background: #ef4444 !important;
  border-color: #ef4444 !important;
  color: white !important;
  box-shadow: 0 4px 12px rgba(239, 68, 68, 0.15) !important;
}

.modern-theme .terminal {
  background: var(--modern-surface);
  border: 1px solid var(--modern-border);
  color: var(--modern-text);
  border-radius: 8px;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 0.875rem;
  box-shadow: 0 4px 6px var(--modern-shadow);
}

.modern-theme .terminal::before {
  content: 'Terminal Output';
  color: var(--modern-text-muted);
  font-family: 'Inter', sans-serif;
  font-weight: 500;
  font-size: 0.75rem;
  background: var(--modern-surface);
  text-shadow: none;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.modern-theme .terminal::-webkit-scrollbar-thumb {
  background: var(--modern-border);
  box-shadow: none;
}

.modern-theme .terminal::-webkit-scrollbar-track {
  background: var(--modern-bg);
}

.modern-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--modern-primary), transparent);
  animation: modern-scan 4s ease-in-out infinite;
  box-shadow: 0 0 8px rgba(37, 99, 235, 0.3);
  height: 2px;
}

@keyframes modern-scan {
  0% { transform: translateX(-100%); opacity: 0; }
  50% { opacity: 1; }
  100% { transform: translateX(100%); opacity: 0; }
}

.modern-theme .theme-btn {
  background: var(--modern-surface);
  border: 1px solid var(--modern-border);
  color: var(--modern-text);
  font-family: 'Inter', sans-serif;
  font-weight: 500;
  text-transform: none;
  letter-spacing: 0;
  border-radius: 6px;
  box-shadow: 0 1px 3px var(--modern-shadow);
}

.modern-theme .theme-btn:hover {
  border-color: var(--modern-primary);
  color: var(--modern-primary);
  box-shadow: 0 2px 8px rgba(37, 99, 235, 0.15);
}

.modern-theme .theme-options {
  background: var(--modern-surface);
  border: 1px solid var(--modern-border);
  border-radius: 6px;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.1);
}

.modern-theme .theme-option {
  border: none;
  color: var(--modern-text);
  font-family: 'Inter', sans-serif;
  font-weight: 400;
  text-transform: none;
  letter-spacing: 0;
  border-radius: 4px;
  margin: 0.25rem;
  padding: 0.75rem 1rem;
}

.modern-theme .theme-option:hover {
  background: var(--modern-bg);
  color: var(--modern-text);
  box-shadow: none;
}

.modern-option {
  font-family: 'Inter', sans-serif !important;
  color: var(--modern-primary) !important;
  font-weight: 500 !important;
}

.modern-option:hover {
  background: rgba(37, 99, 235, 0.1) !important;
  color: var(--modern-primary) !important;
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

.modern-dark-theme .terminal::-webkit-scrollbar-thumb {
  background: var(--dark-border);
  box-shadow: none;
}

.modern-dark-theme .terminal::-webkit-scrollbar-track {
  background: var(--dark-bg);
}

.modern-dark-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--dark-primary), transparent);
  animation: modern-scan 4s ease-in-out infinite;
  box-shadow: 0 0 8px rgba(59, 130, 246, 0.4);
  height: 2px;
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

.modern-dark-option {
  font-family: 'Inter', sans-serif !important;
  color: var(--dark-primary) !important;
  font-weight: 500 !important;
}

.modern-dark-option:hover {
  background: rgba(59, 130, 246, 0.1) !important;
  color: var(--dark-primary) !important;
}

/* Kids Fun Theme */
.kids-theme {
  background: linear-gradient(135deg, var(--kids-bg) 0%, #ffeef8 100%);
  color: var(--kids-text);
  font-family: 'Comic Neue', cursive;
  animation: kids-float 6s ease-in-out infinite;
  filter: none;
  background-attachment: fixed;
}

@keyframes kids-float {
  0%, 100% { transform: translateY(0px); }
  50% { transform: translateY(-2px); }
}

.kids-theme .apocalypse-title {
  font-family: 'Fredoka One', cursive;
  font-weight: 400;
  color: var(--kids-primary);
  text-shadow: 2px 2px 4px rgba(255, 107, 107, 0.3);
  animation: kids-bounce 2s ease-in-out infinite;
  font-size: 2.8rem;
  letter-spacing: 0.02em;
}

@keyframes kids-bounce {
  0%, 100% { transform: scale(1); }
  50% { transform: scale(1.02); }
}

.kids-theme .subtitle {
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  color: var(--kids-secondary);
  text-shadow: 1px 1px 2px rgba(78, 205, 196, 0.3);
  letter-spacing: 0.5px;
  font-size: 1.2rem;
}

.kids-theme .cmd-button {
  background: linear-gradient(145deg, var(--kids-surface), #f7fafc);
  border: 2px solid var(--kids-primary);
  color: var(--kids-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  font-size: 1rem;
  letter-spacing: 0.5px;
  text-transform: none;
  padding: 1.2rem 1.5rem;
  border-radius: 20px;
  box-shadow: 0 4px 8px var(--kids-shadow);
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.kids-theme .cmd-button::before {
  content: '✨';
  position: absolute;
  top: -20px;
  left: -20px;
  opacity: 0;
  transition: all 0.3s ease;
  font-size: 1.5rem;
}

.kids-theme .cmd-button:hover {
  background: linear-gradient(145deg, var(--kids-accent), #fff4d6);
  border-color: var(--kids-secondary);
  color: var(--kids-text);
  transform: translateY(-3px) scale(1.02);
  box-shadow: 0 8px 16px rgba(255, 230, 109, 0.4);
  text-shadow: none;
}

.kids-theme .cmd-button:hover::before {
  top: 10px;
  left: 10px;
  opacity: 1;
  animation: kids-sparkle 1s infinite;
}

@keyframes kids-sparkle {
  0%, 100% { transform: rotate(0deg) scale(1); }
  50% { transform: rotate(180deg) scale(1.2); }
}

.kids-theme .exit-btn {
  background: linear-gradient(145deg, #fed7d7, #fbb6ce) !important;
  border-color: #e53e3e !important;
  color: #e53e3e !important;
  box-shadow: 0 4px 8px rgba(229, 62, 62, 0.2) !important;
}

.kids-theme .exit-btn:hover {
  background: linear-gradient(145deg, #fc8181, #f687b3) !important;
  border-color: #c53030 !important;
  color: #c53030 !important;
  box-shadow: 0 8px 16px rgba(197, 48, 48, 0.3) !important;
}

.kids-theme .terminal {
  background: var(--kids-surface);
  border: 2px solid var(--kids-success);
  color: var(--kids-text);
  border-radius: 15px;
  font-family: 'Comic Neue', cursive;
  font-size: 0.9rem;
  box-shadow: 0 6px 12px var(--kids-shadow);
  position: relative;
}

.kids-theme .terminal::before {
  content: '🖥️ Fun Terminal 🖥️';
  color: var(--kids-success);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  font-size: 0.8rem;
  background: var(--kids-surface);
  text-shadow: none;
  text-transform: none;
  letter-spacing: 0.5px;
}

.kids-theme .terminal::-webkit-scrollbar-thumb {
  background: var(--kids-secondary);
  border-radius: 10px;
  box-shadow: none;
}

.kids-theme .terminal::-webkit-scrollbar-track {
  background: var(--kids-bg);
  border-radius: 10px;
}

.kids-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--kids-primary), var(--kids-accent), var(--kids-secondary), transparent);
  animation: kids-rainbow 3s ease-in-out infinite;
  box-shadow: 0 0 10px rgba(255, 107, 107, 0.5);
  height: 4px;
  border-radius: 2px;
}

@keyframes kids-rainbow {
  0% { transform: translateX(-100%); filter: hue-rotate(0deg); }
  50% { filter: hue-rotate(180deg); }
  100% { transform: translateX(100%); filter: hue-rotate(360deg); }
}

.kids-theme .theme-btn {
  background: linear-gradient(145deg, var(--kids-surface), #f7fafc);
  border: 2px solid var(--kids-accent);
  color: var(--kids-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  text-transform: none;
  letter-spacing: 0.5px;
  border-radius: 15px;
  box-shadow: 0 3px 6px var(--kids-shadow);
}

.kids-theme .theme-btn:hover {
  border-color: var(--kids-primary);
  color: var(--kids-primary);
  box-shadow: 0 4px 8px rgba(255, 107, 107, 0.3);
  transform: scale(1.05);
}

.kids-theme .theme-options {
  background: var(--kids-surface);
  border: 2px solid var(--kids-border);
  border-radius: 15px;
  box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
}

.kids-theme .theme-option {
  border: 1px solid var(--kids-border);
  color: var(--kids-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  text-transform: none;
  letter-spacing: 0.5px;
  border-radius: 10px;
  margin: 0.3rem;
  padding: 0.8rem 1rem;
}

.kids-theme .theme-option:hover {
  background: linear-gradient(145deg, var(--kids-accent), #fff4d6);
  color: var(--kids-text);
  box-shadow: 0 2px 4px var(--kids-shadow);
  transform: scale(1.02);
}

.kids-option {
  font-family: 'Comic Neue', cursive !important;
  color: var(--kids-primary) !important;
  font-weight: 700 !important;
}

.kids-option:hover {
  background: linear-gradient(145deg, #ffe4e1, #ffd6cc) !important;
  color: var(--kids-primary) !important;
}

/* Kids Boy Theme */
.kids-boy-theme {
  background: linear-gradient(135deg, var(--kids-boy-bg) 0%, #e6f3ff 100%);
  color: var(--kids-boy-text);
  font-family: 'Comic Neue', cursive;
  animation: kids-float 6s ease-in-out infinite;
  filter: none;
  background-attachment: fixed;
}

.kids-boy-theme .apocalypse-title {
  font-family: 'Fredoka One', cursive;
  font-weight: 400;
  color: var(--kids-boy-primary);
  text-shadow: 2px 2px 4px rgba(66, 133, 244, 0.3);
  animation: kids-bounce 2s ease-in-out infinite;
  font-size: 2.8rem;
  letter-spacing: 0.02em;
}

.kids-boy-theme .subtitle {
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  color: var(--kids-boy-secondary);
  text-shadow: 1px 1px 2px rgba(52, 168, 83, 0.3);
  letter-spacing: 0.5px;
  font-size: 1.2rem;
}

.kids-boy-theme .cmd-button {
  background: linear-gradient(145deg, var(--kids-boy-surface), #f0f8ff);
  border: 2px solid var(--kids-boy-primary);
  color: var(--kids-boy-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  font-size: 1rem;
  letter-spacing: 0.5px;
  text-transform: none;
  padding: 1.2rem 1.5rem;
  border-radius: 20px;
  box-shadow: 0 4px 8px var(--kids-boy-shadow);
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.kids-boy-theme .cmd-button::before {
  content: '⚡';
  position: absolute;
  top: -20px;
  left: -20px;
  opacity: 0;
  transition: all 0.3s ease;
  font-size: 1.5rem;
}

.kids-boy-theme .cmd-button:hover {
  background: linear-gradient(145deg, var(--kids-boy-accent), #fff8dc);
  border-color: var(--kids-boy-secondary);
  color: var(--kids-boy-text);
  transform: translateY(-3px) scale(1.02);
  box-shadow: 0 8px 16px rgba(251, 188, 4, 0.4);
  text-shadow: none;
}

.kids-boy-theme .cmd-button:hover::before {
  top: 10px;
  left: 10px;
  opacity: 1;
  animation: kids-sparkle 1s infinite;
}

.kids-boy-theme .exit-btn {
  background: linear-gradient(145deg, #fed7d7, #fbb6ce) !important;
  border-color: #e53e3e !important;
  color: #e53e3e !important;
  box-shadow: 0 4px 8px rgba(229, 62, 62, 0.2) !important;
}

.kids-boy-theme .exit-btn:hover {
  background: linear-gradient(145deg, #fc8181, #f687b3) !important;
  border-color: #c53030 !important;
  color: #c53030 !important;
  box-shadow: 0 8px 16px rgba(197, 48, 48, 0.3) !important;
}

.kids-boy-theme .terminal {
  background: var(--kids-boy-surface);
  border: 2px solid var(--kids-boy-success);
  color: var(--kids-boy-text);
  border-radius: 15px;
  font-family: 'Comic Neue', cursive;
  font-size: 0.9rem;
  box-shadow: 0 6px 12px var(--kids-boy-shadow);
  position: relative;
}

.kids-boy-theme .terminal::before {
  content: '🖥️ Cool Terminal 🖥️';
  color: var(--kids-boy-success);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  font-size: 0.8rem;
  background: var(--kids-boy-surface);
  text-shadow: none;
  text-transform: none;
  letter-spacing: 0.5px;
}

.kids-boy-theme .terminal::-webkit-scrollbar-thumb {
  background: var(--kids-boy-secondary);
  border-radius: 10px;
  box-shadow: none;
}

.kids-boy-theme .terminal::-webkit-scrollbar-track {
  background: var(--kids-boy-bg);
  border-radius: 10px;
}

.kids-boy-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--kids-boy-primary), var(--kids-boy-accent), var(--kids-boy-secondary), transparent);
  animation: kids-rainbow 3s ease-in-out infinite;
  box-shadow: 0 0 10px rgba(66, 133, 244, 0.5);
  height: 4px;
  border-radius: 2px;
}

.kids-boy-theme .theme-btn {
  background: linear-gradient(145deg, var(--kids-boy-surface), #f0f8ff);
  border: 2px solid var(--kids-boy-accent);
  color: var(--kids-boy-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  text-transform: none;
  letter-spacing: 0.5px;
  border-radius: 15px;
  box-shadow: 0 3px 6px var(--kids-boy-shadow);
}

.kids-boy-theme .theme-btn:hover {
  border-color: var(--kids-boy-primary);
  color: var(--kids-boy-primary);
  box-shadow: 0 4px 8px rgba(66, 133, 244, 0.3);
  transform: scale(1.05);
}

.kids-boy-theme .theme-options {
  background: var(--kids-boy-surface);
  border: 2px solid var(--kids-boy-border);
  border-radius: 15px;
  box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
}

.kids-boy-theme .theme-option {
  border: 1px solid var(--kids-boy-border);
  color: var(--kids-boy-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  text-transform: none;
  letter-spacing: 0.5px;
  border-radius: 10px;
  margin: 0.3rem;
  padding: 0.8rem 1rem;
}

.kids-boy-theme .theme-option:hover {
  background: linear-gradient(145deg, var(--kids-boy-accent), #fff8dc);
  color: var(--kids-boy-text);
  box-shadow: 0 2px 4px var(--kids-boy-shadow);
  transform: scale(1.02);
}

.kids-boy-option {
  font-family: 'Comic Neue', cursive !important;
  color: var(--kids-boy-primary) !important;
  font-weight: 700 !important;
}

.kids-boy-option:hover {
  background: linear-gradient(145deg, #e6f3ff, #cce7ff) !important;
  color: var(--kids-boy-primary) !important;
}

/* Kids Girl Theme */
.kids-girl-theme {
  background: linear-gradient(135deg, var(--kids-girl-bg) 0%, #ffe6f7 100%);
  color: var(--kids-girl-text);
  font-family: 'Comic Neue', cursive;
  animation: kids-float 6s ease-in-out infinite;
  filter: none;
  background-attachment: fixed;
}

.kids-girl-theme .apocalypse-title {
  font-family: 'Fredoka One', cursive;
  font-weight: 400;
  color: var(--kids-girl-primary);
  text-shadow: 2px 2px 4px rgba(255, 105, 180, 0.3);
  animation: kids-bounce 2s ease-in-out infinite;
  font-size: 2.8rem;
  letter-spacing: 0.02em;
}

.kids-girl-theme .subtitle {
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  color: var(--kids-girl-secondary);
  text-shadow: 1px 1px 2px rgba(218, 112, 214, 0.3);
  letter-spacing: 0.5px;
  font-size: 1.2rem;
}

.kids-girl-theme .cmd-button {
  background: linear-gradient(145deg, var(--kids-girl-surface), #fef7ff);
  border: 2px solid var(--kids-girl-primary);
  color: var(--kids-girl-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  font-size: 1rem;
  letter-spacing: 0.5px;
  text-transform: none;
  padding: 1.2rem 1.5rem;
  border-radius: 20px;
  box-shadow: 0 4px 8px var(--kids-girl-shadow);
  transition: all 0.3s ease;
  position: relative;
  overflow: hidden;
}

.kids-girl-theme .cmd-button::before {
  content: '💖';
  position: absolute;
  top: -20px;
  left: -20px;
  opacity: 0;
  transition: all 0.3s ease;
  font-size: 1.5rem;
}

.kids-girl-theme .cmd-button:hover {
  background: linear-gradient(145deg, var(--kids-girl-accent), #fff0f5);
  border-color: var(--kids-girl-secondary);
  color: var(--kids-girl-text);
  transform: translateY(-3px) scale(1.02);
  box-shadow: 0 8px 16px rgba(255, 192, 203, 0.4);
  text-shadow: none;
}

.kids-girl-theme .cmd-button:hover::before {
  top: 10px;
  left: 10px;
  opacity: 1;
  animation: kids-sparkle 1s infinite;
}

.kids-girl-theme .exit-btn {
  background: linear-gradient(145deg, #fed7d7, #fbb6ce) !important;
  border-color: #e53e3e !important;
  color: #e53e3e !important;
  box-shadow: 0 4px 8px rgba(229, 62, 62, 0.2) !important;
}

.kids-girl-theme .exit-btn:hover {
  background: linear-gradient(145deg, #fc8181, #f687b3) !important;
  border-color: #c53030 !important;
  color: #c53030 !important;
  box-shadow: 0 8px 16px rgba(197, 48, 48, 0.3) !important;
}

.kids-girl-theme .terminal {
  background: var(--kids-girl-surface);
  border: 2px solid var(--kids-girl-success);
  color: var(--kids-girl-text);
  border-radius: 15px;
  font-family: 'Comic Neue', cursive;
  font-size: 0.9rem;
  box-shadow: 0 6px 12px var(--kids-girl-shadow);
  position: relative;
}

.kids-girl-theme .terminal::before {
  content: '🌸 Pretty Terminal 🌸';
  color: var(--kids-girl-success);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  font-size: 0.8rem;
  background: var(--kids-girl-surface);
  text-shadow: none;
  text-transform: none;
  letter-spacing: 0.5px;
}

.kids-girl-theme .terminal::-webkit-scrollbar-thumb {
  background: var(--kids-girl-secondary);
  border-radius: 10px;
  box-shadow: none;
}

.kids-girl-theme .terminal::-webkit-scrollbar-track {
  background: var(--kids-girl-bg);
  border-radius: 10px;
}

.kids-girl-theme .apocalypse-line {
  background: linear-gradient(90deg, transparent, var(--kids-girl-primary), var(--kids-girl-accent), var(--kids-girl-secondary), transparent);
  animation: kids-rainbow 3s ease-in-out infinite;
  box-shadow: 0 0 10px rgba(255, 105, 180, 0.5);
  height: 4px;
  border-radius: 2px;
}

.kids-girl-theme .theme-btn {
  background: linear-gradient(145deg, var(--kids-girl-surface), #fef7ff);
  border: 2px solid var(--kids-girl-accent);
  color: var(--kids-girl-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  text-transform: none;
  letter-spacing: 0.5px;
  border-radius: 15px;
  box-shadow: 0 3px 6px var(--kids-girl-shadow);
}

.kids-girl-theme .theme-btn:hover {
  border-color: var(--kids-girl-primary);
  color: var(--kids-girl-primary);
  box-shadow: 0 4px 8px rgba(255, 105, 180, 0.3);
  transform: scale(1.05);
}

.kids-girl-theme .theme-options {
  background: var(--kids-girl-surface);
  border: 2px solid var(--kids-girl-border);
  border-radius: 15px;
  box-shadow: 0 10px 20px rgba(0, 0, 0, 0.1);
}

.kids-girl-theme .theme-option {
  border: 1px solid var(--kids-girl-border);
  color: var(--kids-girl-text);
  font-family: 'Comic Neue', cursive;
  font-weight: 700;
  text-transform: none;
  letter-spacing: 0.5px;
  border-radius: 10px;
  margin: 0.3rem;
  padding: 0.8rem 1rem;
}

.kids-girl-theme .theme-option:hover {
  background: linear-gradient(145deg, var(--kids-girl-accent), #fff0f5);
  color: var(--kids-girl-text);
  box-shadow: 0 2px 4px var(--kids-girl-shadow);
  transform: scale(1.02);
}

.kids-girl-option {
  font-family: 'Comic Neue', cursive !important;
  color: var(--kids-girl-primary) !important;
  font-weight: 700 !important;
}

.kids-girl-option:hover {
  background: linear-gradient(145deg, #ffe6f7, #ffcce6) !important;
  color: var(--kids-girl-primary) !important;
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
    <button class="cmd-button" onclick="run('ipconfig')">
      Network Configuration
    </button>
    <button class="cmd-button" onclick="run('go-pwr')">
      Launch Go-PWR
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
    <button class="theme-option modern-dark-option" onclick="setTheme('modern-dark')">● MODERN DARK ●</button>
    <button class="theme-option modern-option" onclick="setTheme('modern-light')">● MODERN LIGHT ●</button>
    <button class="theme-option cyberpunk-option" onclick="setTheme('cyberpunk')">◢ CYBERPUNK ◤</button>
    <button class="theme-option doomsday-option" onclick="setTheme('doomsday')">☠ DOOMSDAY ☠</button>
    <button class="theme-option kids-boy-option" onclick="setTheme('kids-boy')">🚀 KIDS BOY 🚀</button>
    <button class="theme-option kids-girl-option" onclick="setTheme('kids-girl')">🦄 KIDS GIRL 🦄</button>
  </div>
</div>

<script>
const TOKEN = "$Token";

async function run(action){
  const out = document.getElementById("out");
  const isModernLight = document.body.classList.contains('modern-theme');
  const isModernDark = document.body.classList.contains('modern-dark-theme');
  const isKidsBoy = document.body.classList.contains('kids-boy-theme');
  const isKidsGirl = document.body.classList.contains('kids-girl-theme');
  const isKids = document.body.classList.contains('kids-theme');
  const isCyberpunk = document.body.classList.contains('cyberpunk-theme');
  
  let symbol, protocol, endMsg;
  if (isKidsBoy) {
    symbol = '🚀';
    protocol = 'STARTING';
    endMsg = 'DONE';
  } else if (isKidsGirl) {
    symbol = '🦄';
    protocol = 'STARTING';
    endMsg = 'DONE';
  } else if (isKids) {
    symbol = '🎮';
    protocol = 'STARTING';
    endMsg = 'DONE';
  } else if (isModernLight || isModernDark) {
    symbol = '●';
    protocol = 'INITIALIZING';
    endMsg = 'COMPLETE';
  } else if (isCyberpunk) {
    symbol = '◢';
    protocol = 'INITIALIZING';
    endMsg = 'END TRANSMISSION';
  } else {
    symbol = '☠';
    protocol = 'INITIALIZING';
    endMsg = 'END TRANSMISSION';
  }
  
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
    const errorMsg = (isModernLight || isModernDark) ? "ERROR" : ((isKidsBoy || isKidsGirl || isKids) ? "OOPS" : "ERROR PROTOCOL");
    const failMsg = (isKidsBoy || isKidsGirl || isKids) ? "TRY AGAIN" : ((isModernLight || isModernDark) ? "FAILED" : (isCyberpunk ? "END TRANSMISSION" : "TRANSMISSION FAILED"));
    out.textContent = symbol + " " + errorMsg + " " + symbol + "\n\n> SYSTEM FAULT: " + e + "\n\n" + symbol + " " + failMsg + " " + symbol;
  }
}

async function exitServer(){
  const out = document.getElementById("out");
  const isModernLight = document.body.classList.contains('modern-theme');
  const isModernDark = document.body.classList.contains('modern-dark-theme');
  const isKidsBoy = document.body.classList.contains('kids-boy-theme');
  const isKidsGirl = document.body.classList.contains('kids-girl-theme');
  const isKids = document.body.classList.contains('kids-theme');
  const isCyberpunk = document.body.classList.contains('cyberpunk-theme');
  
  let symbol, confirmMsg, shutdownMsg;
  
  if (isKidsBoy) {
    symbol = '🚀';
    confirmMsg = "🛑 Ready to Land the Rocket? 🛑\n\nThis will close the awesome command center. Are you sure, captain?";
    shutdownMsg = symbol + " SHUTTING DOWN " + symbol + "\n\n> Landing the rocket...\n> Storing cool stuff...\n> See you later, captain! 👋\n\n" + symbol + " MISSION COMPLETE " + symbol;
  } else if (isKidsGirl) {
    symbol = '🦄';
    confirmMsg = "🛑 Time to Close the Magic Portal? 🛑\n\nThis will end our magical command adventure. Are you sure, princess?";
    shutdownMsg = symbol + " SHUTTING DOWN " + symbol + "\n\n> Closing magic portal...\n> Storing sparkles...\n> See you later, princess! 👋\n\n" + symbol + " MAGIC COMPLETE " + symbol;
  } else if (isKids) {
    symbol = '🎮';
    confirmMsg = "🛑 Time to Stop Playing? 🛑\n\nThis will close the fun command center. Are you sure?";
    shutdownMsg = symbol + " SHUTTING DOWN " + symbol + "\n\n> Saving your progress...\n> Cleaning up toys...\n> See you later! 👋\n\n" + symbol + " GOODBYE " + symbol;
  } else if (isModernLight || isModernDark) {
    symbol = '●';
    confirmMsg = "Confirm Server Shutdown\n\nThis will stop the command server. Continue?";
    shutdownMsg = symbol + " SHUTDOWN INITIATED " + symbol + "\n\n> Closing connections...\n> Stopping server...\n> Goodbye!\n\n" + symbol + " SERVER STOPPED " + symbol;
  } else if (isCyberpunk) {
    symbol = '◢';
    confirmMsg = "◢ CONFIRM SERVER SHUTDOWN ◤\n\nThis will terminate the command server. Continue?";
    shutdownMsg = symbol + " SHUTDOWN PROTOCOL INITIATED " + symbol + "\n\n> Terminating connections...\n> Shutting down server...\n> Goodbye!\n\n" + symbol + " SERVER OFFLINE " + symbol;
  } else {
    symbol = '☠';
    confirmMsg = "☠ CONFIRM SERVER TERMINATION ☠\n\nThis will bring about the end of the command server. Proceed with apocalypse?";
    shutdownMsg = symbol + " DOOMSDAY PROTOCOL INITIATED " + symbol + "\n\n> Terminating all connections...\n> Shutting down server...\n> The end is near...\n\n" + symbol + " SERVER TERMINATED " + symbol;
  }
  
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
  
  // Remove all theme classes
  body.classList.remove('cyberpunk-theme', 'modern-theme', 'modern-dark-theme', 'kids-theme', 'kids-boy-theme', 'kids-girl-theme');
  
  if (theme === 'modern-dark') {
    body.classList.add('modern-dark-theme');
    title.innerHTML = 'PWR Command System';
    subtitle.innerHTML = 'Secure Local Command Execution Interface';
    terminal.innerHTML = 'Ready for command execution\n\n> System Status: Online\n> Authentication: Verified\n> Commands: Available\n> Environment: Secure Local Network';
    
    buttons[0].innerHTML = 'System Information';
    buttons[1].innerHTML = 'Home Directory';
    buttons[2].innerHTML = 'Network Configuration';
    buttons[3].innerHTML = 'Launch Go-PWR';
    exitButton.innerHTML = 'Stop Server';
    
    document.querySelector('.apocalypse-line').style.animation = 'modern-scan 4s ease-in-out infinite';
    
  } else if (theme === 'modern-light') {
    body.classList.add('modern-theme');
    title.innerHTML = 'PWR Command System';
    subtitle.innerHTML = 'Secure Local Command Execution Interface';
    terminal.innerHTML = 'Ready for command execution\n\n> System Status: Online\n> Authentication: Verified\n> Commands: Available\n> Environment: Secure Local Network';
    
    buttons[0].innerHTML = 'System Information';
    buttons[1].innerHTML = 'Home Directory';
    buttons[2].innerHTML = 'Network Configuration';
    buttons[3].innerHTML = 'Launch Go-PWR';
    exitButton.innerHTML = 'Stop Server';
    
    document.querySelector('.apocalypse-line').style.animation = 'modern-scan 4s ease-in-out infinite';
    
  } else if (theme === 'cyberpunk') {
    body.classList.add('cyberpunk-theme');
    title.innerHTML = '◢ PWR-COMMAND ◤';
    subtitle.innerHTML = '◢ SECURE LOCAL COMMAND EXECUTIONS ◤';
    terminal.innerHTML = '◢ AWAITING COMMAND EXECUTION ◤\n\n> System Ready\n> Authentication: VERIFIED\n> Commands: LOADED\n> Status: STANDBY';
    
    buttons[0].innerHTML = '◢ HELLO PROTOCOL ◤';
    buttons[1].innerHTML = '◢ HOME DIRECTORY ◤';
    buttons[2].innerHTML = '◢ NETWORK STATUS ◤';
    buttons[3].innerHTML = '◢ LAUNCH GO-PWR ◤';
    exitButton.innerHTML = '◢ SHUTDOWN SERVER ◤';
    
    document.querySelector('.apocalypse-line').style.animation = 'cyber-scan 3s infinite';
    
  } else if (theme === 'kids-boy') {
    body.classList.add('kids-boy-theme');
    title.innerHTML = '🚀 Super Cool Command Center 🚀';
    subtitle.innerHTML = '🎮 Awesome Computer Adventures 🎮';
    terminal.innerHTML = '🎉 Ready for Cool Commands! 🎉\n\n> Status: Super Ready! 😎\n> Safety: All Good! 🛡️\n> Commands: Loaded! 📦\n> Adventure Mode: ON! 🚀';
    
    buttons[0].innerHTML = '👋 Say Hello!';
    buttons[1].innerHTML = '🏠 Show My Folder';
    buttons[2].innerHTML = '🌐 Check Network';
    buttons[3].innerHTML = '🚀 Launch Go-PWR';
    exitButton.innerHTML = '👋 Stop & Exit';
    
    document.querySelector('.apocalypse-line').style.animation = 'kids-rainbow 3s ease-in-out infinite';
    
  } else if (theme === 'kids-girl') {
    body.classList.add('kids-girl-theme');
    title.innerHTML = '🦄 Magical Command Palace 🦄';
    subtitle.innerHTML = '🌸 Sparkly Computer Adventures 🌸';
    terminal.innerHTML = '🎉 Ready for Magical Commands! 🎉\n\n> Status: Super Ready! 💖\n> Safety: All Good! 🛡️\n> Commands: Loaded! 📦\n> Magic Mode: ON! 🦄';
    
    buttons[0].innerHTML = '👋 Say Hello!';
    buttons[1].innerHTML = '🏠 Show My Folder';
    buttons[2].innerHTML = '🌐 Check Network';
    buttons[3].innerHTML = '🚀 Launch Go-PWR';
    exitButton.innerHTML = '👋 Stop & Exit';
    
    document.querySelector('.apocalypse-line').style.animation = 'kids-rainbow 3s ease-in-out infinite';
    
  } else if (theme === 'kids') {
    body.classList.add('kids-theme');
    title.innerHTML = '🚀 Super Fun Command Center 🚀';
    subtitle.innerHTML = '🎮 Safe Computer Adventures 🎮';
    terminal.innerHTML = '🎉 Ready for Fun Commands! 🎉\n\n> Status: Super Ready! 😊\n> Safety: All Good! 🛡️\n> Commands: Loaded! 📦\n> Adventure Mode: ON! 🎮';
    
    buttons[0].innerHTML = '👋 Say Hello!';
    buttons[1].innerHTML = '🏠 Show My Folder';
    buttons[2].innerHTML = '🌐 Check Network';
    buttons[3].innerHTML = '🚀 Launch Go-PWR';
    exitButton.innerHTML = '👋 Stop & Exit';
    
    document.querySelector('.apocalypse-line').style.animation = 'kids-rainbow 3s ease-in-out infinite';
    
  } else {
    // Doomsday theme (default fallback)
    title.innerHTML = '☠ PWR-COMMAND ☠';
    subtitle.innerHTML = '☠ SECURE LOCAL COMMAND EXECUTIONS ☠';
    terminal.innerHTML = '☠ AWAITING COMMAND EXECUTION ☠\n\n> System Status: OPERATIONAL\n> Authentication: VERIFIED\n> Commands: LOADED\n> Status: READY FOR DOOMSDAY';
    
    buttons[0].innerHTML = '☠ HELLO PROTOCOL ☠';
    buttons[1].innerHTML = '☠ HOME DIRECTORY ☠';
    buttons[2].innerHTML = '☠ NETWORK STATUS ☠';
    buttons[3].innerHTML = '☠ LAUNCH GO-PWR ☠';
    exitButton.innerHTML = '☠ TERMINATE SERVER ☠';
    
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
