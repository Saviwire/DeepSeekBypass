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
    let cloudBrainURL = "wss://deepseek-cloud-brain.jenniferanistonchat1969.workers.dev"
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // 🌉 The JS Bridge: Captures taps and sends them to Swift
        let jsBridge = """
        document.addEventListener('click', function(e) {
            window.webkit.messageHandlers.bridge.postMessage({type: 'click', text: e.target.innerText, tag: e.target.tagName});
        });
        """
        let userScript = WKUserScript(source: jsBridge, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        contentController.addUserScript(userScript)
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        contentController.add(context.coordinator, name: "bridge")
        config.userContentController = contentController
        
        let loadingHTML = "<html><body style='background:#111;color:#fff;display:flex;justify-content:center;align-items:center;height:100vh;font-family:sans-serif;'><h2>Connecting to Cloud Brain...</h2></body></html>"
        webView.loadHTMLString(loadingHTML, baseURL: nil)
        
        context.coordinator.connectToCloudBrain(webView: webView, urlString: cloudBrainURL)
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, WKNavigationDelegate, URLSessionWebSocketDelegate, WKScriptMessageHandler {
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
                        if let data = text.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let type = json["type"] as? String, type == "update",
                           let html = json["html"] as? String {
                            DispatchQueue.main.async {
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
        
        // Send commands to Cloud Brain
        func sendCommand(type: String, data: [String: Any]) {
            let payload = ["type": type].merging(data) { _, new in new }
            if let jsonData = try? JSONSerialization.data(withJSONObject: payload),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                webSocketTask?.send(.string(jsonString)) { error in
                    if let error = error { print("Send error: \(error)") }
                }
            }
        }
        
        // Catch the taps from the webview
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "bridge", let dict = message.body as? [String: Any] {
                print("User tapped: \(dict)")
                // We will send this to the worker later
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
