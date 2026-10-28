// ==UserScript==
// @name            Hot Reload m3owtugen.css
// @description     Re-applies chrome/m3owtugen.css (matugen output) on save, no restart
// @include         chrome://browser/content/browser.xhtml
// ==/UserScript==

(function () {
  "use strict";

  const POLL_MS = 100;
  const SETTLE_MS = 50;
  const ACTIVE_PREF = "m3owtugen.hotreload.active";
  const SCHEME_PREF = "zen.view.window.scheme";
  const SCHEMES = { dark: 0, light: 1 };

  const PATH = PathUtils.join(PathUtils.profileDir, "chrome", "m3owtugen.css");
  const sss = Cc["@mozilla.org/content/style-sheet-service;1"].getService(Ci.nsIStyleSheetService);
  const wu = window.windowUtils;
  const dataUri = css => "data:text/css;charset=utf-8," + encodeURIComponent(css);

  function retireStartupSheet() {
    const uri = Services.io.newURI(PathUtils.toFileURI(PATH));

    for (const type of [sss.USER_SHEET, sss.AGENT_SHEET]) {
      if (sss.sheetRegistered(uri, type)) {
        sss.unregisterSheet(uri, type);
      }
    }

    Services.prefs.getDefaultBranch("").setBoolPref(ACTIVE_PREF, true);
  }

  // follow matugen's --mode instead of the system color scheme
  function applyScheme(css) {
    const scheme = SCHEMES[/--m3owtugen-scheme:\s*(\w+)/.exec(css)?.[1]];
    if (scheme !== undefined && Services.prefs.getIntPref(SCHEME_PREF, 2) !== scheme) {
      Services.prefs.setIntPref(SCHEME_PREF, scheme);
    }
  }

  let prev = null;
  async function reload() {
    try {
      const css = await IOUtils.readUTF8(PATH);
      applyScheme(css);
      const uri = dataUri(css);

      if (uri === prev) {
        return;
      }

      wu.loadSheetUsingURIString(uri, wu.USER_SHEET);
      if (prev) {
        wu.removeSheetUsingURIString(prev, wu.USER_SHEET);
      }

      prev = uri;
      retireStartupSheet();

      console.log(`[m3owtugen hot-reload]: applied`);
    } catch (e) {
      console.error(`[m3owtugen hot-reload]: ${e}`);
    }
  }

  async function fingerprint() {
    try {
      const st = await IOUtils.stat(PATH);
      return `${st.lastModified}:${st.size}`;
    } catch (_e) {
      return null;
    }
  }

  let lastFp = null;
  let pendingFp = null;
  let settleAt = 0;
  let stopped = false;
  let timer = null;

  async function tick() {
    const fp = await fingerprint();
    if (fp === null || fp === lastFp) {
      pendingFp = null;
      return;
    }

    if (fp !== pendingFp) {
      pendingFp = fp;
      settleAt = Date.now() + SETTLE_MS;

      return;
    }

    if (Date.now() < settleAt) {
      return;
    }

    lastFp = fp;
    pendingFp = null;

    await reload();
  }

  async function loop() {
    if (stopped) {
      return;
    }

    try {
      await tick();
    } catch (e) {
      console.error(`[m3owtugen hot-reload]: ${e}`);
    }

    if (!stopped) {
      timer = setTimeout(loop, POLL_MS);
    }
  }

  async function init() {
    window.addEventListener(
      "unload",
      () => {
        stopped = true;
        clearTimeout(timer);
      },
      { once: true }
    );

    lastFp = await fingerprint();
    if (Services.prefs.getBoolPref(ACTIVE_PREF, false)) {
      await reload();
    } else {
      // the startup sheet covers the colors, but the mode may have changed while zen was closed
      try {
        applyScheme(await IOUtils.readUTF8(PATH));
      } catch (e) {
        console.error(`[m3owtugen hot-reload]: ${e}`);
      }
    }

    loop();
  }

  if (gBrowserInit.delayedStartupFinished) {
    init();
  } else {
    const observer = (subject, topic) => {
      if (topic === "browser-delayed-startup-finished" && subject === window) {
        Services.obs.removeObserver(observer, topic);
        init();
      }
    };

    Services.obs.addObserver(observer, "browser-delayed-startup-finished");
  }
})();
