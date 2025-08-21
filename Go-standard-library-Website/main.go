package main

import (
    "fmt"
    "html/template"
    "log"
    "net/http"
    "os"
    "path/filepath"
    "strings"
)

const baseVideoDir = `D:\Next New HDD\PrepperOS-Data-Master`

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
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #1e3c72 0%, #2a5298 100%);
            color: white;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1200px;
            margin: 0 auto;
        }
        
        .header {
            text-align: center;
            margin-bottom: 40px;
            padding: 20px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            backdrop-filter: blur(10px);
        }
        
        .header h1 {
            font-size: 3rem;
            margin-bottom: 10px;
            text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.3);
        }
        
        .breadcrumb {
            background: rgba(255, 255, 255, 0.1);
            padding: 15px 20px;
            border-radius: 10px;
            margin-bottom: 20px;
            font-size: 1.1rem;
        }
        
        .breadcrumb a {
            color: #81c784;
            text-decoration: none;
            margin-right: 5px;
        }
        
        .breadcrumb a:hover {
            text-decoration: underline;
        }
        
        .content-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 30px;
        }
        
        .folder-card, .video-card {
            background: rgba(255, 255, 255, 0.15);
            border-radius: 20px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
            cursor: pointer;
        }
        
        .folder-card:hover, .video-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
        }
        
        .folder-card {
            text-align: center;
            background: rgba(255, 193, 7, 0.2);
            border-color: rgba(255, 193, 7, 0.4);
        }
        
        .folder-icon {
            font-size: 4rem;
            margin-bottom: 15px;
            display: block;
        }
        
        .folder-name {
            font-size: 1.2rem;
            font-weight: bold;
            word-break: break-word;
        }
        
        .video-card h3 {
            color: #fff;
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
            background: rgba(0, 0, 0, 0.6);
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
            background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
            border-radius: 50%;
            display: flex;
            align-items: center;
            justify-content: center;
            border: 4px solid rgba(255, 255, 255, 0.3);
            transition: all 0.3s ease;
            box-shadow: 0 8px 25px rgba(0, 0, 0, 0.3);
        }
        
        .play-button:hover {
            transform: scale(1.1);
            border-color: rgba(255, 255, 255, 0.6);
            box-shadow: 0 12px 35px rgba(0, 0, 0, 0.4);
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
            background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
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
        
        .no-content {
            text-align: center;
            padding: 60px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            margin-top: 40px;
        }
        
        .no-content h2 {
            font-size: 2rem;
            margin-bottom: 15px;
            color: #ffeb3b;
        }
        
        .file-size {
            color: #81c784;
            font-weight: bold;
        }
        
        @media (max-width: 768px) {
            .content-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 2rem;
            }
        }
    </style>
</head>
<body>
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
    
    fmt.Printf("🎬 Video Gallery Server starting...\n")
    fmt.Printf("📁 Base directory: %s\n", baseVideoDir)
    fmt.Printf("🌐 Open your browser to: http://localhost:8080\n")
    fmt.Printf("⏹️  Press Ctrl+C to stop the server\n\n")
    
    log.Fatal(http.ListenAndServe(":8080", nil))
}