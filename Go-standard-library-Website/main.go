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
        
        .video-title {
            position: absolute;
            bottom: 15px;
            left: 15px;
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 5px 10px;
            border-radius: 15px;
            font-size: 0.9rem;
            backdrop-filter: blur(10px);
            max-width: calc(100% - 30px);
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
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
                    <div class="video-container">
                        <video class="video-player" preload="metadata" poster="" muted="false" volume="1.0">
                            <source src="/video/{{.Name}}" type="{{.MimeType}}">
                            <!-- Fallback sources for better browser compatibility -->
                            <source src="/video/{{.Name}}" type="video/mp4">
                            <source src="/video/{{.Name}}" type="video/webm">
                            Your browser does not support the video tag.
                        </video>
                        <div class="play-overlay" onclick="playVideo(this)">
                            <div class="play-button">
                                <div class="play-icon"></div>
                            </div>
                        </div>
                        <div class="video-title">{{.Name}}</div>
                    </div>
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
    
    <script>
        function playVideo(overlay) {
            const videoContainer = overlay.parentElement;
            const video = videoContainer.querySelector('video');
            
            // Ensure audio is enabled
            video.muted = false;
            video.volume = 1.0;
            
            // Hide the overlay
            overlay.classList.add('hidden');
            
            // Add controls to the video and play it
            video.setAttribute('controls', 'controls');
            
            // Try to play the video
            const playPromise = video.play();
            
            if (playPromise !== undefined) {
                playPromise.then(function() {
                    // Playback started successfully
                    console.log('Video playback started');
                }).catch(function(error) {
                    console.log('Playback failed:', error);
                    // Show overlay again if playback fails
                    overlay.classList.remove('hidden');
                    
                    // Try with muted audio as fallback (some browsers require this)
                    video.muted = true;
                    video.play().then(function() {
                        console.log('Video started muted - click to unmute');
                        // Add a click listener to unmute
                        video.addEventListener('click', function() {
                            video.muted = false;
                        }, { once: true });
                    }).catch(function(mutedError) {
                        console.log('Even muted playback failed:', mutedError);
                    });
                });
            }
            
            // Listen for when video is paused or ended to show overlay again
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
            
            // Ensure audio tracks are enabled for MKV files
            video.addEventListener('loadedmetadata', function() {
                // Enable all audio tracks
                if (video.audioTracks) {
                    for (let i = 0; i < video.audioTracks.length; i++) {
                        video.audioTracks[i].enabled = true;
                    }
                }
            });
        }
        
        // Optional: Add keyboard support for play buttons
        document.addEventListener('keydown', function(e) {
            if (e.code === 'Space') {
                const activeElement = document.activeElement;
                if (activeElement.classList.contains('play-overlay')) {
                    e.preventDefault();
                    playVideo(activeElement);
                }
            }
        });
        
        // Add global audio context unlock for mobile browsers
        document.addEventListener('DOMContentLoaded', function() {
            // This helps with audio playback on mobile devices
            document.addEventListener('touchstart', function() {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => {
                    video.load(); // Reload video to ensure audio context
                });
            }, { once: true });
        });
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
        return "video/mp4" // Default fallback
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
    
    // Set appropriate headers for video streaming with audio support
    mimeType := getMimeType(filename)
    w.Header().Set("Content-Type", mimeType)
    w.Header().Set("Accept-Ranges", "bytes")
    w.Header().Set("Cache-Control", "no-cache, no-store, must-revalidate")
    w.Header().Set("Pragma", "no-cache")
    w.Header().Set("Expires", "0")
    
    // Special headers for MKV files to ensure proper codec support
    if strings.HasSuffix(strings.ToLower(filename), ".mkv") {
        w.Header().Set("X-Content-Type-Options", "nosniff")
        w.Header().Set("Content-Type", "video/x-matroska")
    }
    
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