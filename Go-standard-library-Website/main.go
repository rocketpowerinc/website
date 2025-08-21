package main

import (
    "context"
    "fmt"
    "html/template"
    "log"
    "net/http"
    "os"
    "os/signal"
    "path/filepath"
    "strings"
    "syscall"
    "time"
)

const baseVideoDir = `D:\Next New HDD\PrepperOS-Data-Master`

// Global shutdown channel
var shutdownChan = make(chan bool, 1)

type PageData struct {
    Title       string
    CurrentPath string
    ParentPath  string
    Folders     []FolderInfo
    Videos      []VideoInfo
}

type FolderInfo struct {
    Name string
    Path string
}

type VideoInfo struct {
    Name     string
    Path     string
    Size     int64
    MimeType string
}

// HTML template for the video gallery
const htmlTemplate = `
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{{.Title}}</title>
    <style>
        :root {
            /* Dark Theme (Default) */
            --bg-gradient-1: #1e3c72;
            --bg-gradient-2: #2a5298;
            --primary-color: #667eea;
            --secondary-color: #764ba2;
            --text-color: #ffffff;
            --text-secondary: rgba(255, 255, 255, 0.8);
            --card-bg: rgba(255, 255, 255, 0.15);
            --card-border: rgba(255, 255, 255, 0.2);
            --folder-bg: rgba(255, 193, 7, 0.2);
            --folder-border: rgba(255, 193, 7, 0.4);
            --accent-color: #81c784;
            --warning-color: #ffeb3b;
            --overlay-bg: rgba(0, 0, 0, 0.6);
            --shadow-color: rgba(0, 0, 0, 0.3);
        }

        [data-theme="light"] {
            --bg-gradient-1: #f5f7fa;
            --bg-gradient-2: #c3cfe2;
            --primary-color: #3f51b5;
            --secondary-color: #9c27b0;
            --text-color: #2c3e50;
            --text-secondary: rgba(44, 62, 80, 0.7);
            --card-bg: rgba(255, 255, 255, 0.9);
            --card-border: rgba(0, 0, 0, 0.1);
            --folder-bg: rgba(255, 193, 7, 0.3);
            --folder-border: rgba(255, 152, 0, 0.5);
            --accent-color: #4caf50;
            --warning-color: #ff9800;
            --overlay-bg: rgba(255, 255, 255, 0.8);
            --shadow-color: rgba(0, 0, 0, 0.15);
        }

        [data-theme="nuclear"] {
            --bg-gradient-1: #0a0a0a;
            --bg-gradient-2: #1a1a2e;
            --primary-color: #39ff14;
            --secondary-color: #ff073a;
            --text-color: #39ff14;
            --text-secondary: rgba(57, 255, 20, 0.8);
            --card-bg: rgba(57, 255, 20, 0.1);
            --card-border: rgba(255, 7, 58, 0.3);
            --folder-bg: rgba(255, 255, 0, 0.15);
            --folder-border: rgba(255, 215, 0, 0.6);
            --accent-color: #ff073a;
            --warning-color: #ffff00;
            --overlay-bg: rgba(0, 0, 0, 0.8);
            --shadow-color: rgba(57, 255, 20, 0.2);
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, var(--bg-gradient-1) 0%, var(--bg-gradient-2) 100%);
            color: var(--text-color);
            min-height: 100vh;
            padding: 20px;
            transition: all 0.3s ease;
        }

        .theme-switcher {
            position: fixed;
            top: 20px;
            left: 20px;
            z-index: 1000;
            background: var(--card-bg);
            border: 1px solid var(--card-border);
            border-radius: 15px;
            padding: 10px;
            backdrop-filter: blur(10px);
            box-shadow: 0 4px 15px var(--shadow-color);
        }

        .stop-server {
            position: fixed;
            top: 20px;
            right: 20px;
            z-index: 1000;
            background: linear-gradient(45deg, #ff4444, #cc0000);
            border: 2px solid #ff0000;
            border-radius: 15px;
            padding: 12px 16px;
            color: white;
            cursor: pointer;
            font-size: 1rem;
            font-weight: bold;
            transition: all 0.3s ease;
            backdrop-filter: blur(10px);
            box-shadow: 0 4px 15px rgba(255, 0, 0, 0.3);
        }

        .stop-server:hover {
            transform: scale(1.05);
            box-shadow: 0 6px 20px rgba(255, 0, 0, 0.5);
            background: linear-gradient(45deg, #ff6666, #ff0000);
        }

        .stop-server:active {
            transform: scale(0.95);
        }

        [data-theme="nuclear"] .stop-server {
            box-shadow: 0 4px 15px rgba(255, 0, 0, 0.3), 0 0 20px var(--secondary-color);
            animation: dangerPulse 2s ease-in-out infinite alternate;
        }

        @keyframes dangerPulse {
            from { box-shadow: 0 4px 15px rgba(255, 0, 0, 0.3), 0 0 20px var(--secondary-color); }
            to { box-shadow: 0 6px 20px rgba(255, 0, 0, 0.6), 0 0 30px var(--secondary-color); }
        }

        .theme-button {
            background: none;
            border: 2px solid var(--card-border);
            border-radius: 10px;
            padding: 8px 12px;
            margin: 2px;
            color: var(--text-color);
            cursor: pointer;
            font-size: 0.9rem;
            font-weight: bold;
            transition: all 0.3s ease;
            backdrop-filter: blur(5px);
        }

        .theme-button:hover {
            transform: scale(1.05);
            box-shadow: 0 2px 10px var(--shadow-color);
        }

        .theme-button.active {
            background: var(--primary-color);
            border-color: var(--secondary-color);
            color: white;
            box-shadow: 0 0 15px var(--primary-color);
        }

        [data-theme="nuclear"] .theme-button {
            text-shadow: 0 0 5px var(--text-color);
        }

        [data-theme="nuclear"] .theme-button.active {
            background: var(--secondary-color);
            box-shadow: 0 0 20px var(--secondary-color);
            animation: nuclearGlow 2s ease-in-out infinite alternate;
        }

        @keyframes nuclearGlow {
            from { box-shadow: 0 0 20px var(--secondary-color); }
            to { box-shadow: 0 0 30px var(--primary-color), 0 0 40px var(--secondary-color); }
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
            margin-top: 80px; /* Space for theme switcher */
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 20px;
            background: var(--card-bg);
            border-radius: 15px;
            backdrop-filter: blur(10px);
            border: 1px solid var(--card-border);
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px var(--shadow-color);
        }

        [data-theme="nuclear"] .header h1 {
            text-shadow: 0 0 10px var(--primary-color);
            animation: nuclearTitle 3s ease-in-out infinite alternate;
        }

        @keyframes nuclearTitle {
            from { text-shadow: 0 0 10px var(--primary-color); }
            to { text-shadow: 0 0 20px var(--primary-color), 0 0 30px var(--secondary-color); }
        }
        
        .breadcrumb {
            background: var(--card-bg);
            padding: 15px 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            font-size: 1.1rem;
            border: 1px solid var(--card-border);
        }
        
        .breadcrumb a {
            color: var(--accent-color);
            text-decoration: none;
            margin-right: 5px;
        }
        
        .breadcrumb a:hover {
            text-decoration: underline;
        }

        [data-theme="nuclear"] .breadcrumb a {
            text-shadow: 0 0 5px var(--accent-color);
        }
        
        .content-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .folder-card, .video-card {
            background: var(--card-bg);
            border-radius: 20px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid var(--card-border);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            cursor: pointer;
        }
        
        .folder-card:hover, .video-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px var(--shadow-color);
        }

        [data-theme="nuclear"] .folder-card:hover,
        [data-theme="nuclear"] .video-card:hover {
            box-shadow: 0 15px 40px var(--shadow-color), 0 0 20px var(--primary-color);
        }
        
        .folder-card {
            text-align: center;
            background: var(--folder-bg);
            border-color: var(--folder-border);
        }

        [data-theme="nuclear"] .folder-card {
            box-shadow: inset 0 0 10px var(--folder-border);
        }
        
        .folder-icon {
            font-size: 4rem;
            margin-bottom: 15px;
            display: block;
        }

        [data-theme="nuclear"] .folder-icon {
            text-shadow: 0 0 10px var(--warning-color);
            filter: drop-shadow(0 0 5px var(--warning-color));
        }
        
        .folder-name {
            font-size: 1.2rem;
            font-weight: bold;
            word-break: break-word;
        }
        
        .video-card h3 {
            color: var(--text-color);
            margin-bottom: 15px;
            font-size: 1.3rem;
            word-break: break-word;
        }
        
        .video-container {
            position: relative;
            margin-bottom: 15px;
        }
        
        .video-player {
            width: 100%;
            height: 250px;
            border-radius: 10px;
            background: #000;
        }
        
        .play-overlay {
            position: absolute;
            top: 0;
            left: 0;
            width: 100%;
            height: 100%;
            background: var(--overlay-bg);
            display: flex;
            align-items: center;
            justify-content: center;
            border-radius: 10px;
            cursor: pointer;
            transition: all 0.3s ease;
            backdrop-filter: blur(5px);
        }
        
        .play-overlay:hover {
            background: rgba(0, 0, 0, 0.4);
        }
        
        .play-overlay.hidden {
            opacity: 0;
            pointer-events: none;
        }
        
        .play-button {
            width: 80px;
            height: 80px;
            background: linear-gradient(45deg, var(--primary-color) 0%, var(--secondary-color) 100%);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            border: 4px solid rgba(255, 255, 255, 0.3);
            transition: all 0.3s ease;
            box-shadow: 0 8px 25px var(--shadow-color);
        }
        
        .play-button:hover {
            transform: scale(1.1);
            border-color: rgba(255, 255, 255, 0.6);
            box-shadow: 0 12px 35px var(--shadow-color);
        }

        [data-theme="nuclear"] .play-button {
            box-shadow: 0 8px 25px var(--shadow-color), 0 0 15px var(--primary-color);
        }

        [data-theme="nuclear"] .play-button:hover {
            box-shadow: 0 12px 35px var(--shadow-color), 0 0 25px var(--primary-color);
        }
        
        .play-icon {
            width: 0;
            height: 0;
            border-left: 25px solid white;
            border-top: 15px solid transparent;
            border-bottom: 15px solid transparent;
            margin-left: 8px;
        }
        
        .video-info {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 0.9rem;
            opacity: 0.8;
        }
        
        .download-btn {
            background: linear-gradient(45deg, var(--primary-color) 0%, var(--secondary-color) 100%);
            color: white;
            padding: 8px 16px;
            border: none;
            border-radius: 20px;
            cursor: pointer;
            text-decoration: none;
            font-size: 0.9rem;
            transition: transform 0.2s ease;
        }
        
        .download-btn:hover {
            transform: scale(1.05);
        }

        [data-theme="nuclear"] .download-btn {
            box-shadow: 0 0 10px var(--primary-color);
        }
        
        .no-content {
            text-align: center;
            padding: 60px;
            background: var(--card-bg);
            border-radius: 15px;
            margin-top: 40px;
            border: 1px solid var(--card-border);
        }
        
        .no-content h2 {
            font-size: 2rem;
            margin-bottom: 15px;
            color: var(--warning-color);
        }

        [data-theme="nuclear"] .no-content h2 {
            text-shadow: 0 0 10px var(--warning-color);
        }
        
        .file-size {
            color: var(--accent-color);
            font-weight: bold;
        }

        [data-theme="nuclear"] .file-size {
            text-shadow: 0 0 5px var(--accent-color);
        }
        
        @media (max-width: 768px) {
            .content-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2rem;
            }

            .theme-switcher {
                position: relative;
                top: 0;
                left: 0;
                margin-bottom: 20px;
                text-align: center;
            }

            .container {
                margin-top: 20px;
            }
        }

        /* Nuclear theme specific animations */
        [data-theme="nuclear"] {
            animation: nuclearFlicker 0.1s infinite alternate;
        }

        @keyframes nuclearFlicker {
            0% { filter: brightness(1); }
            100% { filter: brightness(1.02); }
        }

        [data-theme="nuclear"] .card-bg,
        [data-theme="nuclear"] .folder-card,
        [data-theme="nuclear"] .video-card {
            box-shadow: inset 0 0 5px var(--card-border);
        }
    </style>
</head>
<body data-theme="dark">
    <div class="theme-switcher">
        <button class="theme-button active" onclick="setTheme('dark')" data-theme="dark">🌙 Dark</button>
        <button class="theme-button" onclick="setTheme('light')" data-theme="light">☀️ Light</button>
        <button class="theme-button" onclick="setTheme('nuclear')" data-theme="nuclear">☢️ Nuclear</button>
    </div>

    <button class="stop-server" onclick="stopServer()">🛑 Stop Server</button>

    <div class="container">
        <div class="header">
            <h1>🎬 {{.Title}}</h1>
            <p>Directory Browser & Video Gallery</p>
        </div>
        
        <div class="breadcrumb">
            📁 Current: {{.CurrentPath}}
            {{if .ParentPath}}
                <a href="/?path={{.ParentPath}}">&larr; Back to Parent</a>
            {{end}}
        </div>
        
        {{if or .Folders .Videos}}
            <div class="content-grid">
                {{range .Folders}}
                <div class="folder-card" onclick="navigateToFolder('{{.Path}}')">
                    <span class="folder-icon">📁</span>
                    <div class="folder-name">{{.Name}}</div>
                </div>
                {{end}}
                
                {{range .Videos}}
                <div class="video-card">
                    <h3>{{.Name}}</h3>
                    <div class="video-container">
                        <video class="video-player" preload="none">
                            <source src="/video?path={{.Path}}" type="{{.MimeType}}">
                            <p>Your browser does not support this video format. 
                               <a href="/download?path={{.Path}}" class="download-btn">📥 Download</a> to play locally.</p>
                        </video>
                        <div class="play-overlay" onclick="playVideo(this)">
                            <div class="play-button">
                                <div class="play-icon"></div>
                            </div>
                        </div>
                    </div>
                    <div class="video-info">
                        <span class="file-size">{{formatFileSize .Size}}</span>
                        <a href="/download?path={{.Path}}" class="download-btn">📥 Download</a>
                    </div>
                </div>
                {{end}}
            </div>
        {{else}}
            <div class="no-content">
                <h2>📁 Empty Directory</h2>
                <p>No folders or videos found in this directory.</p>
            </div>
        {{end}}
    </div>
    
    <script>
        // Theme management
        function setTheme(theme) {
            document.body.setAttribute('data-theme', theme);
            localStorage.setItem('preferred-theme', theme);
            
            // Update active button
            document.querySelectorAll('.theme-button').forEach(btn => {
                btn.classList.remove('active');
            });
            document.querySelector('[data-theme="' + theme + '"]').classList.add('active');
        }

        // Load saved theme on page load
        document.addEventListener('DOMContentLoaded', function() {
            const savedTheme = localStorage.getItem('preferred-theme') || 'dark';
            setTheme(savedTheme);
        });

        function stopServer() {
            if (confirm('Are you sure you want to stop the server? This will close the application.')) {
                fetch('/shutdown', { method: 'POST' })
                    .then(() => {
                        alert('Server is shutting down...');
                        window.close();
                    })
                    .catch(err => {
                        console.log('Server stopped:', err);
                        alert('Server has been stopped.');
                        window.close();
                    });
            }
        }

        function navigateToFolder(path) {
            window.location.href = '/?path=' + encodeURIComponent(path);
        }
        
        function playVideo(overlay) {
            const videoContainer = overlay.parentElement;
            const video = videoContainer.querySelector('video');
            
            // Hide the overlay
            overlay.classList.add('hidden');
            
            // Add controls to the video
            video.setAttribute('controls', 'controls');
            video.muted = false;
            video.volume = 1.0;
            
            // Try to play the video
            const playPromise = video.play();
            
            if (playPromise !== undefined) {
                playPromise.then(function() {
                    console.log('Video playback started successfully');
                }).catch(function(error) {
                    console.log('Playback failed:', error);
                    overlay.classList.remove('hidden');
                    video.removeAttribute('controls');
                });
            }
            
            // Listen for when video is paused or ended
            video.addEventListener('pause', function() {
                if (video.currentTime === 0 || video.ended) {
                    overlay.classList.remove('hidden');
                    video.removeAttribute('controls');
                }
            });
            
            video.addEventListener('ended', function() {
                overlay.classList.remove('hidden');
                video.removeAttribute('controls');
                video.currentTime = 0;
            });
        }
    </script>
</body>
</html>
`

// Get MIME type based on file extension
func getMimeType(filename string) string {
    ext := strings.ToLower(filepath.Ext(filename))
    switch ext {
    case ".mp4":
        return "video/mp4"
    case ".webm":
        return "video/webm"
    case ".ogg":
        return "video/ogg"
    case ".avi":
        return "video/x-msvideo"
    case ".mov":
        return "video/quicktime"
    case ".wmv":
        return "video/x-ms-wmv"
    case ".flv":
        return "video/x-flv"
    case ".mkv":
        return "video/x-matroska"
    case ".m4v":
        return "video/mp4"
    case ".3gp":
        return "video/3gpp"
    case ".ts":
        return "video/mp2t"
    default:
        return "video/mp4"
    }
}

// Check if file is a video based on extension
func isVideoFile(filename string) bool {
    ext := strings.ToLower(filepath.Ext(filename))
    videoExts := []string{".mp4", ".webm", ".ogg", ".avi", ".mov", ".wmv", ".flv", ".mkv", ".m4v", ".3gp", ".ts"}
    for _, videoExt := range videoExts {
        if ext == videoExt {
            return true
        }
    }
    return false
}

// Format file size in human readable format
func formatFileSize(size int64) string {
    const unit = 1024
    if size < unit {
        return fmt.Sprintf("%d B", size)
    }
    div, exp := int64(unit), 0
    for n := size / unit; n >= unit; n /= unit {
        div *= unit
        exp++
    }
    return fmt.Sprintf("%.1f %cB", float64(size)/float64(div), "KMGTPE"[exp])
}

// Validate path is within base directory (security check)
func isValidPath(requestedPath string) bool {
    // Clean the path to resolve any .. or . components
    cleanPath := filepath.Clean(requestedPath)
    
    // Get absolute paths for comparison
    absBase, err := filepath.Abs(baseVideoDir)
    if err != nil {
        return false
    }
    
    absRequested, err := filepath.Abs(cleanPath)
    if err != nil {
        return false
    }
    
    // Check if requested path is within the base directory
    rel, err := filepath.Rel(absBase, absRequested)
    if err != nil {
        return false
    }
    
    // Path is valid if it doesn't start with .. (meaning it's not outside base)
    return !strings.HasPrefix(rel, "..")
}

// Get directory contents (folders and videos)
func getDirectoryContents(dirPath string) ([]FolderInfo, []VideoInfo, error) {
    var folders []FolderInfo
    var videos []VideoInfo
    
    // Validate path
    if !isValidPath(dirPath) {
        return folders, videos, fmt.Errorf("invalid path: outside base directory")
    }
    
    entries, err := os.ReadDir(dirPath)
    if err != nil {
        return folders, videos, err
    }
    
    for _, entry := range entries {
        if entry.IsDir() {
            // Add folder
            folders = append(folders, FolderInfo{
                Name: entry.Name(),
                Path: filepath.Join(dirPath, entry.Name()),
            })
        } else if isVideoFile(entry.Name()) {
            // Add video file
            info, err := entry.Info()
            if err != nil {
                continue // Skip files that can't be accessed
            }
            
            videos = append(videos, VideoInfo{
                Name:     entry.Name(),
                Path:     filepath.Join(dirPath, entry.Name()),
                Size:     info.Size(),
                MimeType: getMimeType(entry.Name()),
            })
        }
    }
    
    return folders, videos, nil
}

// Home page handler
func homeHandler(w http.ResponseWriter, r *http.Request) {
    // Get the requested path from query parameter
    requestedPath := r.URL.Query().Get("path")
    if requestedPath == "" {
        requestedPath = baseVideoDir
    }
    
    // Validate and get directory contents
    folders, videos, err := getDirectoryContents(requestedPath)
    if err != nil {
        log.Printf("Error reading directory %s: %v", requestedPath, err)
        // Fall back to base directory
        requestedPath = baseVideoDir
        folders, videos, _ = getDirectoryContents(requestedPath)
    }
    
    // Calculate parent path for breadcrumb
    var parentPath string
    if requestedPath != baseVideoDir {
        parentPath = filepath.Dir(requestedPath)
        // Don't allow going above base directory
        if !isValidPath(parentPath) {
            parentPath = ""
        }
    }
    
    // Get relative path for display
    relPath, err := filepath.Rel(baseVideoDir, requestedPath)
    if err != nil || relPath == "." {
        relPath = "Root"
    }
    
    data := PageData{
        Title:       "Video Gallery",
        CurrentPath: relPath,
        ParentPath:  parentPath,
        Folders:     folders,
        Videos:      videos,
    }
    
    // Create template with custom functions
    tmpl := template.Must(template.New("gallery").Funcs(template.FuncMap{
        "formatFileSize": formatFileSize,
    }).Parse(htmlTemplate))
    
    w.Header().Set("Content-Type", "text/html")
    if err := tmpl.Execute(w, data); err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    }
}

// Video streaming handler
func videoHandler(w http.ResponseWriter, r *http.Request) {
    videoPath := r.URL.Query().Get("path")
    if videoPath == "" {
        http.Error(w, "Video path not specified", http.StatusBadRequest)
        return
    }
    
    // Validate path
    if !isValidPath(videoPath) {
        http.Error(w, "Invalid video path", http.StatusBadRequest)
        return
    }
    
    // Check if file exists
    if _, err := os.Stat(videoPath); os.IsNotExist(err) {
        http.Error(w, "Video not found", http.StatusNotFound)
        return
    }
    
    // Set appropriate headers for video streaming
    mimeType := getMimeType(filepath.Base(videoPath))
    w.Header().Set("Content-Type", mimeType)
    w.Header().Set("Accept-Ranges", "bytes")
    w.Header().Set("Cache-Control", "public, max-age=3600")
    w.Header().Set("Access-Control-Allow-Origin", "*")
    w.Header().Set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
    w.Header().Set("Access-Control-Allow-Headers", "Range")
    
    http.ServeFile(w, r, videoPath)
}

// Shutdown handler
func shutdownHandler(w http.ResponseWriter, r *http.Request) {
    if r.Method != "POST" {
        http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
        return
    }
    
    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusOK)
    w.Write([]byte(`{"message": "Server shutting down..."}`))
    
    log.Println("🛑 Server shutdown requested via web interface")
    
    // Signal shutdown through channel
    go func() {
        time.Sleep(500 * time.Millisecond) // Give response time to be sent
        select {
        case shutdownChan <- true:
        default:
        }
    }()
}

// Download handler
func downloadHandler(w http.ResponseWriter, r *http.Request) {
    videoPath := r.URL.Query().Get("path")
    if videoPath == "" {
        http.Error(w, "File path not specified", http.StatusBadRequest)
        return
    }
    
    // Validate path
    if !isValidPath(videoPath) {
        http.Error(w, "Invalid file path", http.StatusBadRequest)
        return
    }
    
    // Check if file exists
    if _, err := os.Stat(videoPath); os.IsNotExist(err) {
        http.Error(w, "File not found", http.StatusNotFound)
        return
    }
    
    filename := filepath.Base(videoPath)
    
    // Set headers for download
    w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
    w.Header().Set("Content-Type", "application/octet-stream")
    
    http.ServeFile(w, r, videoPath)
}

func main() {
    // Set up routes
    http.HandleFunc("/", homeHandler)
    http.HandleFunc("/video", videoHandler)
    http.HandleFunc("/download", downloadHandler)
    http.HandleFunc("/shutdown", shutdownHandler)
    
    // Create server
    server := &http.Server{
        Addr: ":8080",
    }
    
    // Channel to listen for interrupt signal
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
    
    // Start server in a goroutine
    go func() {
        fmt.Printf("🎬 Video Gallery Server starting...\n")
        fmt.Printf("📁 Base directory: %s\n", baseVideoDir)
        fmt.Printf("🌐 Open your browser to: http://localhost:8080\n")
        fmt.Printf("⏹️  Press Ctrl+C or use the Stop Server button to stop\n\n")
        
        if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            log.Fatal("Server failed to start:", err)
        }
    }()
    
    // Wait for interrupt signal or shutdown request
    select {
    case <-quit:
        log.Println("🛑 Shutting down server (Ctrl+C)...")
    case <-shutdownChan:
        log.Println("🛑 Shutting down server (Web interface)...")
    }
    
    // Create context with timeout for graceful shutdown
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    // Attempt graceful shutdown
    if err := server.Shutdown(ctx); err != nil {
        log.Printf("❌ Server forced to shutdown: %v", err)
    } else {
        log.Println("✅ Server gracefully stopped")
    }
}