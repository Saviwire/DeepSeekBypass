import SwiftUI
import WebKit
import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?
    func startBackgroundAudio() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            let audioData = Data(count: 44100) 
            audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileType.wav.rawValue)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
        } catch { print("Audio hack failed: \(error)") }
    }
}

struct WebView: UIViewRepresentable {
    // 🚨 YOUR CLOUD BRAIN URL (Note the wss://) 🚨
    let cloudBrainURL = "wss://deepseek-cloud-brain.jenniferanistonchat1969.workers.dev"
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.navigationDelegate = context.coordinator
        
        // Show a loading screen while connecting to the cloud
        let loadingHTML = "<html><body style='background:#111;color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;'><h2>Connecting to Cloud Brain...</h2></body></html>"
        webView.loadHTMLString(loadingHTML, baseURL: nil)
        
        // Connect to the Cloud Brain
        context.coordinator.connectToCloudBrain(webView: webView, urlString: cloudBrainURL)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, WKNavigationDelegate, URLSessionWebSocketDelegate {
        var parent: WebView
        var webSocketTask: URLSessionWebSocketTask?
        
        init(_ parent: WebView) { self.parent = parent }
        
        func connectToCloudBrain(webView: WKWebView, urlString: String) {
            guard let url = URL(string: urlString) else { return }
            let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue.main)
            webSocketTask = session.webSocketTask(with: url)
            webSocketTask?.resume()
            receiveMessage(webView: webView)
        }
        
        func receiveMessage(webView: WKWebView) {
            webSocketTask?.receive { [weak self] result in
                switch result {
                case .success(let message):
                    if case .string(let text) = message {
                        // Parse JSON from Cloudflare (e.g., {"type": "update", "html": "..."})
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let type = json["type"] as? String, type == "update",
                           let html = json["html"] as? String {
                            DispatchQueue.main.async {
                                // Load the HTML streamed from the Cloud Brain
                                webView.loadHTMLString(html, baseURL: URL(string: "https://chat.deepseek.com"))
                            }
                        }
                    }
                    self?.receiveMessage(webView: webView)
                case .failure(let error):
                    print("WebSocket Error: \(error)")
                }
            }
        }
        
        // Send commands to Cloud Brain (You can call this from your SwiftUI buttons later)
        func sendCommand(type: String, data: [String: Any]) {
            let payload = ["type": type].merging(data) { _, new in new }
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error { print("Send error: \(error)") }
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        WebView()
            .edgesIgnoringSafeArea(.all)
            .onAppear { AudioManager.shared.startBackgroundAudio() }
    }
}
