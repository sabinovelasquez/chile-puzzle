// Email templates for Zoom-In Chile admin panel.
// Uses the visual language of the Astro landing page (zoominchile/landing):
//   - primary #1565C0 / #1976D2 gradient
//   - background #F5F7FA, text #1A1A1A, muted #6B7280
//   - Space Grotesk (headings) + Plus Jakarta Sans (body), with system fallbacks
//   - card layout 560px, radius 16px, shadow 0 12px 32px rgba(0,0,0,0.1)
//
// Email HTML is <table>-based and uses inline styles only, so it renders in
// Outlook (which strips <style> and ignores flex/grid) as well as Gmail/Apple.

const DOWNLOAD_URL = 'https://play.google.com/apps/internaltest/4700433915880246135';
const LANDING_URL = 'https://games.sabino.cl/zoominchile';
const LOGO_URL = 'https://games.sabino.cl/zoominchile/icon.png';

function escapeHtml(str) {
  return String(str == null ? '' : str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

// Parse "- item\n- item" (or "* item", or plain lines) into a clean array.
function parseNotes(text) {
  if (!text) return [];
  return String(text)
    .split('\n')
    .map(l => l.replace(/^\s*[-*]\s*/, '').trim())
    .filter(Boolean);
}

function renderLayout({ lang, title, bodyHtml, optOutUrl }) {
  const footerCopy = lang === 'en'
    ? 'Thanks for being an early tester.'
    : 'Gracias por ser parte de los primeros testers.';
  const optOutCopy = lang === 'en'
    ? 'No longer want these emails?'
    : '¿Ya no quieres recibir estos correos?';
  const optOutLabel = lang === 'en' ? 'Unsubscribe' : 'Cancelar suscripción';

  const optOutBlock = optOutUrl
    ? `<p style="margin:10px 0 0;font-size:11px;color:#9CA3AF;line-height:1.5;">
${optOutCopy} <a href="${optOutUrl}" style="color:#6B7280;text-decoration:underline;">${optOutLabel}</a>
</p>`
    : '';

  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>${escapeHtml(title)}</title>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@600;700&family=Plus+Jakarta+Sans:wght@400;500;600&display=swap" rel="stylesheet">
</head>
<body style="margin:0;padding:0;background:#F5F7FA;font-family:'Plus Jakarta Sans',-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#1A1A1A;line-height:1.6;-webkit-font-smoothing:antialiased;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#F5F7FA;">
<tr><td align="center" style="padding:32px 16px;">

<table role="presentation" width="560" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;width:100%;background:#FFFFFF;border-radius:16px;box-shadow:0 12px 32px rgba(0,0,0,0.10),0 4px 8px rgba(0,0,0,0.06);overflow:hidden;">

<tr><td style="background:#1565C0;background-image:linear-gradient(135deg,#1565C0 0%,#1976D2 100%);padding:32px 32px 28px;text-align:center;">
<img src="${LOGO_URL}" width="72" height="72" alt="Zoom-In Chile" style="display:block;margin:0 auto 14px;border-radius:16px;border:0;outline:none;text-decoration:none;">
<h1 style="margin:0;font-family:'Space Grotesk','Plus Jakarta Sans',sans-serif;font-size:22px;font-weight:700;color:#FFFFFF;letter-spacing:-0.01em;">Zoom-In Chile</h1>
<p style="margin:6px 0 0;font-size:13px;color:rgba(255,255,255,0.85);font-weight:500;">${lang === 'en' ? 'Discover Chile through puzzles' : 'Descubre Chile a través de puzzles'}</p>
</td></tr>

<tr><td style="padding:36px 32px 28px;">
${bodyHtml}
</td></tr>

<tr><td style="padding:20px 32px 28px;border-top:1px solid #E5E7EB;background:#FAFBFC;text-align:center;">
<p style="margin:0 0 6px;font-size:12px;color:#6B7280;">${footerCopy}</p>
<p style="margin:0;font-size:11px;color:#9CA3AF;">
<a href="${LANDING_URL}" style="color:#1565C0;text-decoration:none;">games.sabino.cl/zoominchile</a>
</p>
${optOutBlock}
</td></tr>

</table>

</td></tr>
</table>
</body>
</html>`;
}

function ctaButton({ href, label }) {
  return `<table role="presentation" cellpadding="0" cellspacing="0" border="0" align="center" style="margin:8px auto 4px;">
<tr><td align="center" style="border-radius:12px;background:#1565C0;">
<a href="${href}" style="display:inline-block;padding:14px 32px;font-family:'Plus Jakarta Sans',-apple-system,sans-serif;font-size:15px;font-weight:600;color:#FFFFFF;text-decoration:none;border-radius:12px;letter-spacing:0.01em;">${escapeHtml(label)}</a>
</td></tr>
</table>`;
}

function renderDownloadEmail({ name, lang, optOutUrl }) {
  const isEn = lang === 'en';
  const subject = 'Zoom-In Chile - Early Access';
  const greeting = isEn ? 'Hi' : 'Hola';
  const intro = isEn
    ? 'The app is now available for testing on Android.'
    : 'La app ya está disponible para testing en Android.';
  const ctaCopy = isEn
    ? 'Tap the button below to download it from Google Play (early access).'
    : 'Toca el botón para descargarla desde Google Play (acceso anticipado).';
  const ctaLabel = isEn ? 'Download the app' : 'Descargar la app';
  const tipCopy = isEn
    ? 'First time testers may see a "Download from testing" notice — that\'s expected.'
    : 'La primera vez puede aparecer un aviso de "versión de prueba" — es normal.';

  const safeName = escapeHtml(name);
  const bodyHtml = `
<p style="margin:0 0 16px;font-size:17px;font-weight:600;color:#1A1A1A;">${greeting} ${safeName},</p>
<p style="margin:0 0 12px;font-size:15px;color:#374151;">${intro}</p>
<p style="margin:0 0 24px;font-size:15px;color:#374151;">${ctaCopy}</p>
${ctaButton({ href: DOWNLOAD_URL, label: ctaLabel })}
<p style="margin:24px 0 0;font-size:13px;color:#6B7280;line-height:1.55;">${tipCopy}</p>
`;

  return {
    subject,
    html: renderLayout({ lang: isEn ? 'en' : 'es', title: subject, bodyHtml, optOutUrl }),
  };
}

function renderReleaseEmail({ name, lang, release, optOutUrl }) {
  const isEn = lang === 'en';
  const version = release.version || '';
  const subject = isEn
    ? `Zoom-In Chile v${version} - New version available`
    : `Zoom-In Chile v${version} - Nueva versión disponible`;

  // Lang-specific notes with fallback to the other language if empty.
  let notes = parseNotes(isEn ? release.notesEn : release.notesEs);
  if (notes.length === 0) {
    notes = parseNotes(isEn ? release.notesEs : release.notesEn);
  }

  const greeting = isEn ? 'Hi' : 'Hola';
  const intro = isEn
    ? 'A new version of the app is out. Here\'s what\'s new:'
    : 'Hay una nueva versión de la app. Esto es lo nuevo:';
  const ctaLabel = isEn ? 'Update the app' : 'Actualizar la app';
  const noNotesCopy = isEn
    ? 'This release includes small fixes and improvements.'
    : 'Esta versión incluye mejoras y correcciones.';

  const safeName = escapeHtml(name);
  const safeVersion = escapeHtml(version);

  const notesHtml = notes.length > 0
    ? `<ul style="margin:20px 0 28px;padding:0 0 0 22px;font-size:15px;color:#1A1A1A;">
${notes.map(item => `  <li style="margin:0 0 10px;line-height:1.55;">${escapeHtml(item)}</li>`).join('\n')}
</ul>`
    : `<p style="margin:20px 0 28px;font-size:15px;color:#374151;">${noNotesCopy}</p>`;

  const bodyHtml = `
<p style="margin:0 0 16px;font-size:17px;font-weight:600;color:#1A1A1A;">${greeting} ${safeName},</p>
<p style="margin:0 0 20px;font-size:15px;color:#374151;">${intro}</p>

<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 0 4px;"><tr>
<td style="background:#E3F2FD;color:#1565C0;font-weight:700;font-size:13px;padding:6px 14px;border-radius:999px;font-family:'Space Grotesk','Plus Jakarta Sans',sans-serif;letter-spacing:0.01em;">
v${safeVersion}
</td>
</tr></table>

${notesHtml}

${ctaButton({ href: DOWNLOAD_URL, label: ctaLabel })}
`;

  return {
    subject,
    html: renderLayout({ lang: isEn ? 'en' : 'es', title: subject, bodyHtml, optOutUrl }),
  };
}

module.exports = {
  renderDownloadEmail,
  renderReleaseEmail,
  escapeHtml,
  parseNotes,
};
