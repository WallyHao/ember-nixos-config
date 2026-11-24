const { app, BrowserWindow, nativeTheme, net, protocol, shell } = require('electron');
const { mkdirSync } = require('node:fs');
const path = require('node:path');
const { pathToFileURL } = require('node:url');
const { colors, polarity } = require('./ember-theme.json');

// Keep the origin and profile stable across Nix store paths and upgrades.
const scheme = 'qwerty';
const host = 'learner';
const site = path.join(__dirname, 'site');
const profile = path.join(app.getPath('home'), '.local/share/qwerty-learner');
mkdirSync(profile, { recursive: true, mode: 0o700 });
app.setName('Qwerty Learner');
app.setDesktopName('io.github.realkai42.QwertyLearner.desktop');
app.setPath('userData', profile);
app.setPath('sessionData', profile);
nativeTheme.themeSource = polarity === 'either' ? 'system' : polarity;

protocol.registerSchemesAsPrivileged([
  { scheme, privileges: { standard: true, secure: true, supportFetchAPI: true, stream: true } },
]);

function serveSite(request) {
  const url = new URL(request.url);
  if (url.host !== host) return new Response(null, { status: 404 });

  let filename;
  try {
    filename = path.resolve(site, `.${decodeURIComponent(url.pathname)}`);
  } catch {
    return new Response(null, { status: 400 });
  }
  if (filename !== site && !filename.startsWith(`${site}${path.sep}`)) {
    return new Response(null, { status: 404 });
  }

  // BrowserRouter uses extensionless paths for pages such as /gallery.
  if (filename === site || !path.extname(filename)) {
    filename = path.join(site, 'index.html');
  }
  return net.fetch(pathToFileURL(filename).href);
}

function openExternal(url) {
  if (/^https?:\/\//i.test(url)) void shell.openExternal(url).catch(console.error);
}

if (!app.requestSingleInstanceLock()) {
  app.quit();
} else {
  app.whenReady()
    .then(() => {
      protocol.handle(scheme, serveSite);
      const window = new BrowserWindow({
        width: 1200,
        height: 850,
        backgroundColor: nativeTheme.shouldUseDarkColors ? colors.base00 : colors.base07,
      });
      window.removeMenu();
      window.webContents.on('will-navigate', (event) => {
        const target = new URL(event.url);
        if (target.protocol === `${scheme}:` && target.host === host) return;
        event.preventDefault();
        openExternal(event.url);
      });
      window.webContents.setWindowOpenHandler(({ url }) => {
        openExternal(url);
        return { action: 'deny' };
      });
      app.on('second-instance', () => {
        if (window.isMinimized()) window.restore();
        window.focus();
      });
      return window.loadURL(`${scheme}://${host}/`);
    })
    .catch((error) => {
      console.error(error);
      app.exit(1);
    });
  app.on('window-all-closed', () => app.quit());
}
