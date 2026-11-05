import puppeteer from "@cloudflare/puppeteer";

export default {
  async fetch(request, env) {
    const upgradeHeader = request.headers.get("Upgrade");
    if (upgradeHeader === "websocket") {
      return handleWebSocket(request, env);
    }
    return new Response("Cloud Brain is running. Connect via WebSocket.", { status: 200 });
  },
};

async function handleWebSocket(request, env) {
  const webSocketPair = new WebSocketPair();
  const [client, server] = Object.values(webSocketPair);
  
  server.accept();
  
  try {
    const browser = await puppeteer.launch(env.MYBROWSER);
    const page = await browser.newPage();
    
    await page.goto("https://chat.deepseek.com", { waitUntil: "networkidle2" });
    
    const injectScript = await fetch("https://raw.githubusercontent.com/Saviwire/DeepSeekBypass/refs/heads/main/inject.js").then(r => r.text());
    await page.evaluate(injectScript);
    
    server.send(JSON.stringify({ type: "status", message: "DeepSeek++ Cloud Brain Active!" }));

    server.addEventListener("message", async (event) => {
      const data = JSON.parse(event.data);
      try {
        if (data.type === "type") {
          await page.type(data.selector, data.text);
        } else if (data.type === "click") {
          await page.click(data.selector);
        }
        const content = await page.content();
        server.send(JSON.stringify({ type: "update", html: content }));
      } catch (err) {
        server.send(JSON.stringify({ type: "error", message: err.message }));
      }
    });
  } catch (error) {
    server.send(JSON.stringify({ type: "error", message: "Browser failed to launch: " + error.message }));
  }

  return new Response(null, { status: 101, webSocket: client });
}

