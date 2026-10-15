enum Page {
    static let html = #"""
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
      :root { color-scheme: light dark; }
      html, body { height: 100%; margin: 0; background: Canvas; color: CanvasText; font: 13px -apple-system, system-ui, sans-serif; }
      body { box-sizing: border-box; padding: 24px; }
      .viewport { height: 100%; overflow: hidden; }
      main { transform-origin: top center; }
      .diagram { display: flex; justify-content: center; }
      .diagram + .diagram { margin-top: 32px; padding-top: 32px; border-top: 1px solid color-mix(in srgb, CanvasText 15%, transparent); }
      .diagram svg { max-width: 100%; height: auto; }
      .error { justify-content: flex-start; white-space: pre-wrap; font: 12px ui-monospace, monospace; color: #d33; }
      .empty { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 20px; opacity: 0.6; }
    </style>
    </head>
    <body>
    <div class="viewport"><main></main></div>
    <script>
      (async () => {
        const diagrams = window.diagrams || [];
        if (diagrams.length === 0) {
          const empty = document.createElement("div");
          empty.className = "empty";
          empty.textContent = "No Mermaid is there.";
          document.body.append(empty);
          return;
        }

        const dark = matchMedia("(prefers-color-scheme: dark)").matches;
        mermaid.initialize({ startOnLoad: false, securityLevel: "strict", theme: dark ? "dark" : "default" });

        const main = document.querySelector("main");
        const viewport = document.querySelector(".viewport");
        function fitDiagrams() {
          // Native magnification changes the visual viewport. Preserve the
          // fitted layout while zooming, and refit when back at the default.
          if (window.visualViewport && visualViewport.scale !== 1) return;
          const scale = Math.min(1,
            viewport.clientWidth / Math.max(1, main.scrollWidth),
            viewport.clientHeight / Math.max(1, main.offsetHeight));
          main.style.transform = `scale(${scale})`;
        }
        addEventListener("resize", fitDiagrams);

        for (const [index, source] of diagrams.entries()) {
          const container = document.createElement("div");
          container.className = "diagram";
          main.append(container);
          try {
            await mermaid.parse(source);
            const { svg, bindFunctions } = await mermaid.render(`diagram-${index}`, source);
            container.innerHTML = svg;
            bindFunctions?.(container);
          } catch (error) {
            container.classList.add("error");
            container.textContent = String(error?.message ?? error);
          }
        }
        fitDiagrams();
      })();
    </script>
    </body>
    </html>
    """#
}
