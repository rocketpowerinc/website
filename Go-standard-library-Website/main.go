package main

import (
    "fmt"
    "html/template"
    "io/fs"
    "log"
    "net/http"
    "net/url"
    "os"
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
        
        /* Custom video progress indicator for better visibility */
        .video-progress-overlay {
            position: absolute;
            bottom: 10px;
            left: 10px;
            right: 10px;
            height: 6px;
            background: rgba(255, 255, 255, 0.3);
            border-radius: 3px;
            opacity: 0;
            transition: opacity 0.3s ease;
            pointer-events: none;
            z-index: 10;
            cursor: pointer;
        }
        
        .video-progress-overlay.visible {
            opacity: 1;
            pointer-events: all;
        }
        
        .video-progress-bar {
            height: 100%;
            background: linear-gradient(90deg, #667eea 0%, #764ba2 100%);
            border-radius: 3px;
            width: 0%;
            transition: width 0.1s ease;
            position: relative;
        }
        
        .video-scrubber-handle {
            position: absolute;
            top: -6px;
            right: -8px;
            width: 16px;
            height: 16px;
            background: linear-gradient(45deg, #667eea 0%, #764ba2 100%);
            border: 2px solid white;
            border-radius: 50%;
            cursor: grab;
            box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3);
            transition: all 0.2s ease;
            z-index: 20;
        }
        
        .video-scrubber-handle:hover {
            transform: scale(1.2);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        
        .video-scrubber-handle:active,
        .video-scrubber-handle.dragging {
            cursor: grabbing;
            transform: scale(1.3);
            box-shadow: 0 6px 16px rgba(102, 126, 234, 0.6);
        }
        
        .video-time-tooltip {
            position: absolute;
            bottom: 25px;
            left: 50%;
            transform: translateX(-50%);
            background: rgba(0, 0, 0, 0.8);
            color: white;
            padding: 4px 8px;
            border-radius: 4px;
            font-size: 12px;
            white-space: nowrap;
            opacity: 0;
            transition: opacity 0.2s ease;
            pointer-events: none;
            z-index: 25;
        }
        
        .video-time-tooltip.visible {
            opacity: 1;
        }
        
        .video-container:hover .video-progress-overlay {
            opacity: 1;
            pointer-events: all;
        }
        
        .video-player {
            width: 100%;
            height: 250px;
            border-radius: 10px;
            background: #000;
        }
        
        /* Enhanced video controls styling */
        .video-player::-webkit-media-controls {
            background: rgba(0, 0, 0, 0.8);
            border-radius: 0 0 10px 10px;
        }
        
        .video-player::-webkit-media-controls-panel {
            background: linear-gradient(to top, rgba(0, 0, 0, 0.9), rgba(0, 0, 0, 0.7));
            border-radius: 0 0 10px 10px;
            height: 50px;
        }
        
        .video-player::-webkit-media-controls-timeline {
            background: rgba(255, 255, 255, 0.3);
            border-radius: 25px;
            margin-left: 10px;
            margin-right: 10px;
            height: 8px;
        }
        
        .video-player::-webkit-media-controls-time-remaining-display,
        .video-player::-webkit-media-controls-current-time-display {
            color: white;
            text-shadow: 1px 1px 2px rgba(0, 0, 0, 0.8);
            font-size: 14px;
            font-weight: bold;
        }
        
        .video-player::-webkit-media-controls-play-button,
        .video-player::-webkit-media-controls-mute-button,
        .video-player::-webkit-media-controls-fullscreen-button {
            background-color: rgba(255, 255, 255, 0.9);
            border-radius: 50%;
            margin: 5px;
        }
        
        .video-player::-webkit-media-controls-play-button:hover,
        .video-player::-webkit-media-controls-mute-button:hover,
        .video-player::-webkit-media-controls-fullscreen-button:hover {
            background-color: white;
            transform: scale(1.1);
        }
        
        .video-player::-webkit-media-controls-volume-slider {
            background: rgba(255, 255, 255, 0.3);
            border-radius: 25px;
            height: 6px;
        }
        
        /* Firefox video controls */
        .video-player::-moz-video-controls {
            background: rgba(0, 0, 0, 0.8);
        }
        
        /* General video control enhancements */
        .video-player {
            outline: none;
        }
        
        .video-player:focus {
            box-shadow: 0 0 0 3px rgba(66, 165, 245, 0.5);
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
                        <video class="video-player" preload="none" poster="" muted="false" volume="1.0">
                            <source src="/video/{{.Name}}" type="{{.MimeType}}">
                            <p>Your browser does not support this video format. 
                               <a href="/download/{{.Name}}" class="download-btn">📥 Download</a> to play locally.</p>
                        </video>
                        <div class="video-progress-overlay">
                            <div class="video-progress-bar">
                                <div class="video-scrubber-handle"></div>
                            </div>
                            <div class="video-time-tooltip"></div>
                        </div>
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
            const videoSrc = video.querySelector('source').src;
            const fileName = videoSrc.split('/').pop(); // Extract just the filename
            const isUnsupportedFormat = fileName.toLowerCase().endsWith('.mkv') || 
                                      fileName.toLowerCase().endsWith('.avi') ||
                                      fileName.toLowerCase().endsWith('.wmv');
            
            // For unsupported formats, show message immediately
            if (isUnsupportedFormat) {
                showFormatNotSupportedMessage(videoContainer, fileName);
                return;
            }
            
            // Ensure audio is enabled
            video.muted = false;
            video.volume = 1.0;
            
            // Hide the overlay
            overlay.classList.add('hidden');
            
            // Add controls to the video
            video.setAttribute('controls', 'controls');
            
            // Set loading timeout for stuck videos
            const loadingTimeout = setTimeout(function() {
                console.log('Video loading timeout - likely unsupported format');
                overlay.classList.remove('hidden');
                video.removeAttribute('controls');
                showFormatNotSupportedMessage(videoContainer, fileName);
            }, 10000); // 10 second timeout
            
            // Clear timeout when video starts playing
            video.addEventListener('loadstart', function() {
                console.log('Video loading started');
            });
            
            video.addEventListener('loadeddata', function() {
                console.log('Video data loaded');
                clearTimeout(loadingTimeout);
            });
            
            video.addEventListener('canplay', function() {
                console.log('Video can start playing');
                clearTimeout(loadingTimeout);
            });
            
            // Try to play the video
            const playPromise = video.play();
            
            if (playPromise !== undefined) {
                playPromise.then(function() {
                    console.log('Video playback started successfully');
                    clearTimeout(loadingTimeout);
                    setupProgressTracking(video, videoContainer);
                }).catch(function(error) {
                    console.log('Playback failed:', error);
                    clearTimeout(loadingTimeout);
                    overlay.classList.remove('hidden');
                    video.removeAttribute('controls');
                    
                    // Show format not supported message
                    showFormatNotSupportedMessage(videoContainer, fileName);
                });
            }
            
            // Enhanced error handling
            video.addEventListener('error', function(e) {
                console.log('Video error:', e);
                clearTimeout(loadingTimeout);
                overlay.classList.remove('hidden');
                video.removeAttribute('controls');
                showFormatNotSupportedMessage(videoContainer, fileName);
            });
            
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
        }
        
        function showFormatNotSupportedMessage(container, fileName) {
            // Remove any existing error messages
            const existingMessages = container.querySelectorAll('.format-error-message');
            existingMessages.forEach(msg => msg.remove());
            
            const errorMsg = document.createElement('div');
            errorMsg.className = 'format-error-message';
            errorMsg.style.cssText = 
                'position: absolute; top: 50%; left: 50%; transform: translate(-50%, -50%);' +
                'background: rgba(255, 165, 0, 0.95); color: white; padding: 20px;' +
                'border-radius: 12px; text-align: center; z-index: 1000; max-width: 90%;' +
                'box-shadow: 0 4px 20px rgba(0,0,0,0.3); font-family: Arial, sans-serif;';
            
            const isWindows = navigator.platform.indexOf('Win') > -1;
            
            // Clean the filename and create proper download URL
            const cleanFileName = fileName.includes('/') ? fileName.split('/').pop() : fileName;
            const downloadLink = '/download/' + encodeURIComponent(cleanFileName);
            
            console.log('Download link created:', downloadLink); // Debug log
            
            errorMsg.innerHTML = 
                '<div style="font-size: 18px; margin-bottom: 10px;">⚠ Format Not Supported</div>' +
                '<div style="font-size: 14px; margin-bottom: 15px;">Your browser cannot play this video format directly.</div>' +
                '<div style="font-size: 12px; margin-bottom: 15px;">' +
                '<strong>Recommended options:</strong><br>' +
                '• Download and use VLC Media Player<br>' +
                '• Try a different browser (Chrome/Firefox)<br>' +
                (isWindows ? '• Use Windows Media Player<br>' : '') +
                '</div>' +
                '<a href="' + downloadLink + '" style="background: #4CAF50; color: white; padding: 8px 16px; text-decoration: none; border-radius: 6px; display: inline-block; margin-top: 5px;">📥 Download Video</a>';
            
            container.appendChild(errorMsg);
            
            // Auto-remove message after 15 seconds
            setTimeout(function() {
                if (errorMsg.parentNode) {
                    errorMsg.parentNode.removeChild(errorMsg);
                }
            }, 15000);
        }
        
        function setupProgressTracking(video, container) {
            const progressOverlay = container.querySelector('.video-progress-overlay');
            const progressBar = container.querySelector('.video-progress-bar');
            const scrubberHandle = container.querySelector('.video-scrubber-handle');
            const timeTooltip = container.querySelector('.video-time-tooltip');
            
            if (!progressOverlay || !progressBar || !scrubberHandle) return;
            
            let isDragging = false;
            let dragStartX = 0;
            let dragStartTime = 0;
            
            // Format time for display
            function formatTime(seconds) {
                const mins = Math.floor(seconds / 60);
                const secs = Math.floor(seconds % 60);
                return mins + ':' + (secs < 10 ? '0' : '') + secs;
            }
            
            // Update progress bar and handle position
            function updateProgress() {
                if (video.duration && !isDragging) {
                    const progress = (video.currentTime / video.duration) * 100;
                    progressBar.style.width = progress + '%';
                }
            }
            
            // Set video time based on progress percentage
            function setVideoTime(percentage) {
                if (video.duration) {
                    const newTime = (percentage / 100) * video.duration;
                    video.currentTime = newTime;
                    const progress = percentage;
                    progressBar.style.width = progress + '%';
                }
            }
            
            // Get percentage from mouse position
            function getPercentageFromMouse(event) {
                const rect = progressOverlay.getBoundingClientRect();
                const x = event.clientX - rect.left;
                const percentage = Math.max(0, Math.min(100, (x / rect.width) * 100));
                return percentage;
            }
            
            // Update tooltip with time
            function updateTooltip(event, percentage) {
                if (video.duration && timeTooltip) {
                    const time = (percentage / 100) * video.duration;
                    timeTooltip.textContent = formatTime(time);
                    timeTooltip.classList.add('visible');
                    
                    // Position tooltip at mouse
                    const rect = progressOverlay.getBoundingClientRect();
                    const x = event.clientX - rect.left;
                    timeTooltip.style.left = x + 'px';
                    timeTooltip.style.transform = 'translateX(-50%)';
                }
            }
            
            // Mouse down on scrubber handle
            scrubberHandle.addEventListener('mousedown', function(e) {
                e.preventDefault();
                e.stopPropagation();
                isDragging = true;
                dragStartX = e.clientX;
                dragStartTime = video.currentTime;
                scrubberHandle.classList.add('dragging');
                document.body.style.userSelect = 'none';
            });
            
            // Mouse down on progress bar (direct seeking)
            progressOverlay.addEventListener('mousedown', function(e) {
                if (e.target === scrubberHandle) return;
                
                const percentage = getPercentageFromMouse(e);
                setVideoTime(percentage);
                updateTooltip(e, percentage);
            });
            
            // Mouse move for dragging and tooltip
            progressOverlay.addEventListener('mousemove', function(e) {
                const percentage = getPercentageFromMouse(e);
                updateTooltip(e, percentage);
                
                if (isDragging) {
                    setVideoTime(percentage);
                }
            });
            
            // Mouse leave - hide tooltip
            progressOverlay.addEventListener('mouseleave', function() {
                if (timeTooltip) {
                    timeTooltip.classList.remove('visible');
                }
            });
            
            // Global mouse move for dragging
            document.addEventListener('mousemove', function(e) {
                if (isDragging) {
                    const rect = progressOverlay.getBoundingClientRect();
                    const x = e.clientX - rect.left;
                    const percentage = Math.max(0, Math.min(100, (x / rect.width) * 100));
                    setVideoTime(percentage);
                }
            });
            
            // Global mouse up - stop dragging
            document.addEventListener('mouseup', function() {
                if (isDragging) {
                    isDragging = false;
                    scrubberHandle.classList.remove('dragging');
                    document.body.style.userSelect = '';
                    if (timeTooltip) {
                        timeTooltip.classList.remove('visible');
                    }
                }
            });
            
            // Update progress during playback
            video.addEventListener('timeupdate', updateProgress);
            
            // Show/hide progress overlay
            video.addEventListener('play', function() {
                progressOverlay.classList.add('visible');
            });
            
            video.addEventListener('pause', function() {
                progressOverlay.classList.remove('visible');
            });
            
            video.addEventListener('ended', function() {
                progressOverlay.classList.remove('visible');
                progressBar.style.width = '0%';
            });
            
            // Enhanced controls visibility on hover
            let controlsTimer;
            container.addEventListener('mouseenter', function() {
                clearTimeout(controlsTimer);
                progressOverlay.classList.add('visible');
                video.setAttribute('controls', 'controls');
            });
            
            container.addEventListener('mouseleave', function() {
                if (!video.paused && !isDragging) {
                    controlsTimer = setTimeout(function() {
                        progressOverlay.classList.remove('visible');
                    }, 2000);
                }
            });
        }
        
        // Global styles for better video control visibility
        document.addEventListener('DOMContentLoaded', function() {
            // Add global styles for video controls
            const style = document.createElement('style');
            style.textContent = 
                'video::-webkit-media-controls-timeline {' +
                    'background: rgba(255, 255, 255, 0.4) !important;' +
                    'height: 10px !important;' +
                    'border-radius: 5px !important;' +
                '}' +
                'video::-webkit-media-controls-timeline::-webkit-slider-thumb {' +
                    'background: #667eea !important;' +
                    'border-radius: 50% !important;' +
                    'width: 18px !important;' +
                    'height: 18px !important;' +
                '}' +
                'video::-webkit-media-controls-panel {' +
                    'background: linear-gradient(to top, rgba(0, 0, 0, 0.9), transparent) !important;' +
                    'height: 60px !important;' +
                '}';
            document.head.appendChild(style);
        });
        
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
        return "video/x-matroska" // Use proper MKV MIME type
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
    w.Header().Set("Cache-Control", "public, max-age=3600") // Allow caching for better performance
    
    // Add CORS headers for better browser compatibility
    w.Header().Set("Access-Control-Allow-Origin", "*")
    w.Header().Set("Access-Control-Allow-Methods", "GET, HEAD, OPTIONS")
    w.Header().Set("Access-Control-Allow-Headers", "Range")
    
    http.ServeFile(w, r, videoPath)
}

// Download handler
func downloadHandler(w http.ResponseWriter, r *http.Request) {
    encodedFilename := r.URL.Path[len("/download/"):]
    if encodedFilename == "" {
        http.Error(w, "File not specified", http.StatusBadRequest)
        return
    }
    
    // Decode the URL-encoded filename
    filename, err := url.QueryUnescape(encodedFilename)
    if err != nil {
        log.Printf("Error decoding filename '%s': %v", encodedFilename, err)
        // Try with the original filename if decoding fails
        filename = encodedFilename
    }
    
    log.Printf("Download request - Original: '%s', Decoded: '%s'", encodedFilename, filename)
    
    videoPath := filepath.Join(videoDir, filename)
    
    // Check if file exists
    if _, err := os.Stat(videoPath); os.IsNotExist(err) {
        log.Printf("File not found: %s", videoPath)
        http.Error(w, "File not found", http.StatusNotFound)
        return
    }
    
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