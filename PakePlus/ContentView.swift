import SwiftUI
import WebKit
import AVFoundation

// 🎧 Silent Audio Hack (Keeps app alive in background)
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
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        
        // 1️⃣ THE CHROME API SHIM (Makes iOS WebView act like Google Chrome)
        let chromeShim = """
        window.chrome = {
            runtime: {
                sendMessage: function(msg, cb) { if(cb) cb({}); },
                onMessage: { addListener: function() {} },
                getURL: function(path) { return path; }
            },
            storage: {
                local: {
                    get: function(keys, cb) { if(cb) cb({}); },
                    set: function(items, cb) { if(cb) cb(); }
                }
            },
            sidePanel: {
                setPanelBehavior: function() {},
                setOptions: function() {}
            }
        };
        """
        
        // 2️⃣ PASTE YOUR EXTENSION CODE HERE (Between the triple quotes)
        let extensionCode = """
        // PASTE THE CONTENT FROM content-scripts/content.js HERE
        """
        
        // Inject the shim first, then the extension
        let script1 = WKUserScript(source: chromeShim, injectionTime: .atDocumentStart, forMainFrameOnly: false)
        let script2 = WKUserScript(source: extensionCode, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        
        userContentController.addUserScript(script1)
        userContentController.addUserScript(script2)
        
        config.userContentController = userContentController
        
        let webView = WKWebView(frame: .zero, configuration: config)
        if let url = URL(string: "https://chat.deepseek.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        WebView()
            .edgesIgnoringSafeArea(.all)
            .onAppear { AudioManager.shared.startBackgroundAudio() }
    }
}
