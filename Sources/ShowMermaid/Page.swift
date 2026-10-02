enum Page {
    static let html = #"""
    <!doctype html>
    <html>
    <head>
    <meta charset="utf-8">
    <style>
      :root { color-scheme: light dark; }
      html, body { margin: 0; background: Canvas; color: CanvasText; font: 13px -apple-system, system-ui, sans-serif; }
      body { padding: 24px; }
      .diagram { display: flex; justify-content: center; }
      .diagram + .diagram { margin-top: 32px; padding-top: 32px; border-top: 1px solid color-mix(in srgb, CanvasText 15%, transparent); }
      .diagram svg { max-width: 100%; height: auto; }
      .error { justify-content: flex-start; white-space: pre-wrap; font: 12px ui-monospace, monospace; color: #d33; }
      .empty { position: fixed; inset: 0; display: flex; align-items: center; justify-content: center; font-size: 20px; opacity: 0.6; }
    </style>
    </head>
    <body>
    <main></main>
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

        for (const [index, source] of diagrams.entries()) {
          const container = document.createElement("div");
          container.className = "diagram";
          document.querySelector("main").append(container);
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
      })();
    </script>
    </body>
    </html>
    """#
}
