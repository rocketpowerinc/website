package main

import (
    "fmt"
    "html/template"
    "io/fs"
    "log"
    "net/http"
    "path/filepath"
    "strings"
)

const videoDir = `C:\Users\rocket\Downloads\Test`

type PageData struct {
    Title  string
    Videos []VideoInfo
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
        
        .header p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
        
        .video-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 30px;
            margin-top: 30px;
        }
        
        .video-card {
            background: rgba(255, 255, 255, 0.15);
            border-radius: 20px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.2);
            transition: transform 0.3s ease, box-shadow 0.3s ease;
        }
        
        .video-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 15px 40px rgba(0, 0, 0, 0.3);
        }
        
        .video-card h3 {
            color: #fff;
            margin-bottom: 15px;
            font-size: 1.3rem;
            word-break: break-word;
        }
        
        .video-player {
            width: 100%;
            height: 250px;
            border-radius: 10px;
            margin-bottom: 15px;
            background: #000;
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
        
        .no-videos {
            text-align: center;
            padding: 60px;
            background: rgba(255, 255, 255, 0.1);
            border-radius: 15px;
            margin-top: 40px;
        }
        
        .no-videos h2 {
            font-size: 2rem;
            margin-bottom: 15px;
            color: #ffeb3b;
        }
        
        .file-size {
            color: #81c784;
            font-weight: bold;
        }
        
        @media (max-width: 768px) {
            .video-grid {
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
            <p>Your Personal Video Gallery</p>
        </div>
        
        {{if .Videos}}
            <div class="video-grid">
                {{range .Videos}}
                <div class="video-card">
                    <h3>{{.Name}}</h3>
                    <video class="video-player" controls preload="metadata">
                        <source src="/video/{{.Name}}" type="{{.MimeType}}">
                        Your browser does not support the video tag.
                    </video>
                    <div class="video-info">
                        <span class="file-size">{{formatFileSize .Size}}</span>
                        <a href="/download/{{.Name}}" class="download-btn">📥 Download</a>
                    </div>
                </div>
                {{end}}
            </div>
        {{else}}
            <div class="no-videos">
                <h2>📁 No Videos Found</h2>
                <p>Add some video files to the directory to see them here!</p>
                <p><small>Looking in: {{.VideoDir}}</small></p>
            </div>
        {{end}}
    </div>
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
    default:
        return "video/mp4" // Default fallback
    }
}

// Check if file is a video based on extension
func isVideoFile(filename string) bool {
    ext := strings.ToLower(filepath.Ext(filename))
    videoExts := []string{".mp4", ".webm", ".ogg", ".avi", ".mov", ".wmv", ".flv", ".mkv", ".m4v", ".3gp"}
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

// Scan directory for video files
func getVideoFiles() ([]VideoInfo, error) {
    var videos []VideoInfo
    
    err := filepath.WalkDir(videoDir, func(path string, d fs.DirEntry, err error) error {
        if err != nil {
            return nil // Skip files that can't be accessed
        }
        
        if !d.IsDir() && isVideoFile(d.Name()) {
            info, err := d.Info()
            if err != nil {
                return nil // Skip files that can't be accessed
            }
            
            video := VideoInfo{
                Name:     d.Name(),
                Path:     path,
                Size:     info.Size(),
                MimeType: getMimeType(d.Name()),
            }
            videos = append(videos, video)
        }
        return nil
    })
    
    return videos, err
}

// Home page handler
func homeHandler(w http.ResponseWriter, r *http.Request) {
    videos, err := getVideoFiles()
    if err != nil {
        log.Printf("Error scanning video directory: %v", err)
        videos = []VideoInfo{} // Show empty gallery on error
    }
    
    data := PageData{
        Title:  "Video Gallery",
        Videos: videos,
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
    filename := r.URL.Path[len("/video/"):]
    if filename == "" {
        http.Error(w, "Video not specified", http.StatusBadRequest)
        return
    }
    
    videoPath := filepath.Join(videoDir, filename)
    
    // Set appropriate headers for video streaming
    w.Header().Set("Content-Type", getMimeType(filename))
    w.Header().Set("Accept-Ranges", "bytes")
    
    http.ServeFile(w, r, videoPath)
}

// Download handler
func downloadHandler(w http.ResponseWriter, r *http.Request) {
    filename := r.URL.Path[len("/download/"):]
    if filename == "" {
        http.Error(w, "File not specified", http.StatusBadRequest)
        return
    }
    
    videoPath := filepath.Join(videoDir, filename)
    
    // Set headers for download
    w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s\"", filename))
    w.Header().Set("Content-Type", "application/octet-stream")
    
    http.ServeFile(w, r, videoPath)
}

func main() {
    // Set up routes
    http.HandleFunc("/", homeHandler)
    http.HandleFunc("/video/", videoHandler)
    http.HandleFunc("/download/", downloadHandler)
    
    fmt.Printf("🎬 Video Gallery Server starting...\n")
    fmt.Printf("📁 Serving videos from: %s\n", videoDir)
    fmt.Printf("🌐 Open your browser to: http://localhost:8080\n")
    fmt.Printf("⏹️  Press Ctrl+C to stop the server\n\n")
    
    log.Fatal(http.ListenAndServe(":8080", nil))
}