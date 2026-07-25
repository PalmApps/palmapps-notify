import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { chromium } from 'playwright';

const __dirname = dirname(fileURLToPath(import.meta.url));
const actionPath = process.env.ACTION_PATH
  ? process.env.ACTION_PATH
  : join(__dirname, '..', '..');

const appsPath = join(actionPath, 'templates', 'apps.json');
const themesPath = join(actionPath, 'templates', 'promo-themes.json');
const logoPath = join(actionPath, 'assets', 'palmapps-logo-transparent.png');
const outputDir = join(actionPath, 'output', 'promos', 'images');
const forumLink = process.env.FORUM_LINK || 'https://t.me/palmapps';

const ALL_KEYS = [
  'costify',
  'reservas',
  'viajando',
  'carta-restaurante',
  'rensoli-commerce',
];

const FORMATS = {
  feed: { width: 1080, height: 1080, label: 'Feed' },
  story: { width: 1080, height: 1920, label: 'Story' },
};

function escapeHtml(value) {
  return String(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function getAppProperty(app, name) {
  return app[name] != null ? String(app[name]) : '';
}

function getPromoHook(app) {
  const hook = getAppProperty(app, 'promoHook');
  if (hook.trim()) return hook.trim();
  const summary = getAppProperty(app, 'summary');
  const firstSentence = summary.split('.')[0]?.trim();
  return firstSentence || app.displayName;
}

function getAccessHint(app) {
  if (app.webUrl) return app.webUrl.replace(/^https?:\/\//, '');
  if (app.downloadUrl) return 'APK en la web de PalmApps';
  return 'Detalles en el foro PalmApps';
}

function getTargetKeys(apps) {
  if (process.env.APP) return [process.env.APP];
  if (process.env.ALL === 'true') return ALL_KEYS;

  return ALL_KEYS.filter((key) => {
    const app = apps[key];
    return app && app.promoPriority === true;
  });
}

function getTheme(themes, appKey) {
  return themes[appKey] || themes.default;
}

function buildHtml({ app, theme, format, logoDataUri, version }) {
  const hook = escapeHtml(getPromoHook(app));
  const displayName = escapeHtml(app.displayName);
  const hashtag = escapeHtml(app.hashtag || '');
  const accessHint = escapeHtml(getAccessHint(app));
  const forum = escapeHtml(forumLink.replace(/^https?:\/\//, ''));
  const versionBadge = version
    ? `<span class="badge">Actualizacion v${escapeHtml(version)}</span>`
    : '';

  const isStory = format === 'story';
  const cardPadding = isStory ? '72px 64px' : '56px 52px';
  const hookSize = isStory ? '52px' : '42px';
  const titleSize = isStory ? '34px' : '28px';
  const brandSize = isStory ? '22px' : '18px';

  return `<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="utf-8" />
  <link rel="preconnect" href="https://fonts.googleapis.com" />
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin />
  <link href="https://fonts.googleapis.com/css2?family=DM+Sans:ital,opsz,wght@0,9..40,400;0,9..40,500;0,9..40,700;1,9..40,400&family=Instrument+Serif:ital@0;1&display=swap" rel="stylesheet" />
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    html, body {
      width: ${FORMATS[format].width}px;
      height: ${FORMATS[format].height}px;
      overflow: hidden;
      background: linear-gradient(145deg, ${theme.bgFrom} 0%, ${theme.bgTo} 55%, #05070d 100%);
      font-family: 'DM Sans', system-ui, sans-serif;
      color: #f8fafc;
    }
    .canvas {
      position: relative;
      width: 100%;
      height: 100%;
      padding: ${isStory ? '88px 72px' : '72px 64px'};
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }
    .glow {
      position: absolute;
      width: ${isStory ? '720px' : '560px'};
      height: ${isStory ? '720px' : '560px'};
      border-radius: 50%;
      background: radial-gradient(circle, ${theme.glow} 0%, transparent 68%);
      top: ${isStory ? '-120px' : '-80px'};
      right: ${isStory ? '-160px' : '-120px'};
      pointer-events: none;
    }
    .grid {
      position: absolute;
      inset: 0;
      background-image:
        linear-gradient(rgba(255,255,255,0.03) 1px, transparent 1px),
        linear-gradient(90deg, rgba(255,255,255,0.03) 1px, transparent 1px);
      background-size: 48px 48px;
      mask-image: radial-gradient(circle at 50% 35%, black 20%, transparent 78%);
      pointer-events: none;
    }
    .top {
      position: relative;
      z-index: 1;
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 24px;
    }
    .brand {
      display: flex;
      align-items: center;
      gap: 16px;
    }
    .brand img {
      width: ${isStory ? '64px' : '52px'};
      height: ${isStory ? '64px' : '52px'};
      object-fit: contain;
      filter: drop-shadow(0 8px 24px rgba(0,0,0,0.35));
    }
    .brand-text {
      font-size: ${brandSize};
      letter-spacing: 0.22em;
      text-transform: uppercase;
      color: rgba(248,250,252,0.72);
      font-weight: 500;
    }
    .badge {
      display: inline-flex;
      align-items: center;
      padding: 10px 18px;
      border-radius: 999px;
      background: ${theme.accentSoft};
      border: 1px solid ${theme.accent};
      color: ${theme.accent};
      font-size: ${isStory ? '22px' : '18px'};
      font-weight: 500;
      white-space: nowrap;
    }
    .card {
      position: relative;
      z-index: 1;
      margin: ${isStory ? '48px 0' : '32px 0'};
      padding: ${cardPadding};
      border-radius: ${isStory ? '40px' : '32px'};
      background: rgba(15, 23, 42, 0.55);
      border: 1px solid rgba(255,255,255,0.08);
      backdrop-filter: blur(18px);
      box-shadow:
        0 24px 80px rgba(0,0,0,0.45),
        inset 0 1px 0 rgba(255,255,255,0.06);
    }
    .accent-bar {
      width: 72px;
      height: 6px;
      border-radius: 999px;
      background: linear-gradient(90deg, ${theme.accent}, rgba(255,255,255,0.2));
      margin-bottom: 28px;
    }
    .app-name {
      font-family: 'Instrument Serif', Georgia, serif;
      font-size: ${titleSize};
      line-height: 1.05;
      margin-bottom: 12px;
      color: rgba(248,250,252,0.92);
    }
    .hashtag {
      display: inline-block;
      margin-bottom: 28px;
      font-size: ${isStory ? '24px' : '20px'};
      color: ${theme.accent};
      font-weight: 500;
    }
    .hook {
      font-size: ${hookSize};
      line-height: 1.18;
      font-weight: 700;
      letter-spacing: -0.02em;
      color: #ffffff;
      max-width: ${isStory ? '880px' : '860px'};
    }
    .bottom {
      position: relative;
      z-index: 1;
      display: flex;
      flex-direction: column;
      gap: 14px;
    }
    .cta-row {
      display: flex;
      align-items: center;
      justify-content: space-between;
      gap: 24px;
      padding: ${isStory ? '28px 32px' : '22px 28px'};
      border-radius: 24px;
      background: rgba(2, 6, 23, 0.72);
      border: 1px solid rgba(255,255,255,0.08);
    }
    .cta-label {
      font-size: ${isStory ? '20px' : '17px'};
      color: rgba(248,250,252,0.58);
      text-transform: uppercase;
      letter-spacing: 0.14em;
      margin-bottom: 6px;
    }
    .cta-value {
      font-size: ${isStory ? '30px' : '24px'};
      font-weight: 700;
      color: ${theme.accent};
    }
    .access {
      font-size: ${isStory ? '24px' : '20px'};
      color: rgba(248,250,252,0.72);
      text-align: right;
      line-height: 1.35;
    }
    .footer-note {
      font-size: ${isStory ? '20px' : '17px'};
      color: rgba(248,250,252,0.45);
      text-align: center;
    }
  </style>
</head>
<body>
  <div class="canvas">
    <div class="glow"></div>
    <div class="grid"></div>

    <div class="top">
      <div class="brand">
        <img src="${logoDataUri}" alt="PalmApps" />
        <div class="brand-text">PalmApps</div>
      </div>
      ${versionBadge}
    </div>

    <div class="card">
      <div class="accent-bar"></div>
      <div class="app-name">${displayName}</div>
      <div class="hashtag">${hashtag}</div>
      <div class="hook">${hook}</div>
    </div>

    <div class="bottom">
      <div class="cta-row">
        <div>
          <div class="cta-label">Foro oficial</div>
          <div class="cta-value">${forum}</div>
        </div>
        <div class="access">${accessHint}</div>
      </div>
      <div class="footer-note">Software para negocios · Novedades y actualizaciones</div>
    </div>
  </div>
</body>
</html>`;
}

async function renderImage(browser, html, format) {
  const { width, height } = FORMATS[format];
  const page = await browser.newPage();
  await page.setViewportSize({ width, height });
  await page.setContent(html, { waitUntil: 'networkidle' });
  const buffer = await page.screenshot({ type: 'png' });
  await page.close();
  return buffer;
}

async function main() {
  if (!existsSync(appsPath)) {
    throw new Error(`No se encontro ${appsPath}`);
  }
  if (!existsSync(logoPath)) {
    throw new Error(`No se encontro ${logoPath}`);
  }

  const apps = JSON.parse(readFileSync(appsPath, 'utf8'));
  const themes = JSON.parse(readFileSync(themesPath, 'utf8'));
  const logoDataUri = `data:image/png;base64,${readFileSync(logoPath).toString('base64')}`;
  const targetKeys = getTargetKeys(apps);
  const version = process.env.VERSION || '';

  if (targetKeys.length === 0) {
    throw new Error('No hay apps objetivo. Usa APP=costify o ALL=true');
  }

  mkdirSync(outputDir, { recursive: true });

  const browser = await chromium.launch();
  try {
    for (const appKey of targetKeys) {
      const app = apps[appKey];
      if (!app) {
        console.warn(`App desconocida: ${appKey}`);
        continue;
      }

      const theme = getTheme(themes, appKey);

      for (const format of Object.keys(FORMATS)) {
        const html = buildHtml({
          app,
          theme,
          format,
          logoDataUri,
          version,
        });
        const buffer = await renderImage(browser, html, format);
        const outPath = join(outputDir, `${appKey}-${format}.png`);
        writeFileSync(outPath, buffer);
        console.log(`Generado: ${outPath}`);
      }
    }
  } finally {
    await browser.close();
  }

  console.log(
    `Imagenes en ${outputDir} (${targetKeys.length} apps x ${Object.keys(FORMATS).length} formatos)`,
  );
}

main().catch((error) => {
  console.error(error.message || error);
  process.exit(1);
});
