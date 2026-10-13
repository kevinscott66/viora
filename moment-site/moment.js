'use strict';
function parseMoment(hash, allowReply = true) {
  if (!hash) return null;
  if (hash.length > 12000) throw new Error('Too long');
  const m = JSON.parse(decodeURIComponent(hash.replace(/^#/, '')));
  if ((m.lyric !== undefined && (typeof m.lyric !== 'string' || m.lyric.length > 150)) || m.v !== 1 || typeof m.title !== 'string' || !m.title.trim() || m.title.length > 300 ||
      !Array.isArray(m.artists) || m.artists.length > 30 ||
      m.artists.some(a => typeof a !== 'string' || a.length > 200) ||
      !Number.isInteger(m.seconds) || m.seconds < 0 || m.seconds > 86400 ||
      typeof m.note !== 'string' || m.note.length > 500) throw new Error('Invalid moment');
  if (m.replyTo !== undefined) {
    if (!allowReply || !m.replyTo || typeof m.replyTo !== 'object') throw new Error('Invalid reply');
    m.replyTo = parseMoment('#' + encodeURIComponent(JSON.stringify(m.replyTo)), false);
  }
  if (m.source) {
    const u = new URL(m.source);
    const allowed = ['open.spotify.com', 'www.deezer.com', 'deezer.com', 'music.apple.com', 'music.yandex.ru', 'music.yandex.com', 'soundcloud.com', 'www.youtube.com', 'youtu.be'];
    if (u.protocol !== 'https:' || u.username || u.password || !allowed.includes(u.hostname)) m.source = null;
  }
  return m;
}
function parseCard(value) {
  if (!value || value.v !== 1 || typeof value.name !== 'string' || !value.name.trim() || value.name.length > 50 ||
    typeof value.lyric !== 'string' || value.lyric.length > 150 || !['rose','ocean','violet'].includes(value.theme) ||
    !Array.isArray(value.tracks) || value.tracks.length !== 3) throw new Error('Invalid card');
  const tracks = value.tracks.map(t => parseMoment('#' + encodeURIComponent(JSON.stringify(t))));
  if (tracks.some(t => !t || !t.artists.length) || new Set(tracks.map(t => JSON.stringify([t.title.trim().toLowerCase(),t.artists.map(a => a.toLowerCase())]))).size !== 3) throw new Error('Duplicate tracks');
  return {v:1,name:value.name,lyric:value.lyric,theme:value.theme,tracks};
}
if (typeof module !== 'undefined') module.exports = {parseMoment, parseCard};
async function renderMoment() {
  document.getElementById('error').hidden = true;
  document.getElementById('source').hidden = true;
  try {
    const cardRoute = location.pathname.match(/^\/p\/([A-Za-z0-9_-]{16})$/);
    if (cardRoute) {
      const response = await fetch('/api/cards/' + cardRoute[1], {cache: 'no-store'});
      if (!response.ok) throw new Error('Unavailable');
      const card = parseCard(await response.json());
      document.title = card.name + ' · viora';
      document.querySelector('.card').classList.add('theme-' + card.theme);
      document.querySelector('.eyebrow').textContent = 'ТРИ ТРЕКА ОБО МНЕ';
      document.getElementById('title').textContent = card.name;
      document.getElementById('artists').textContent = 'Музыкальная визитка';
      const lyric = document.getElementById('lyric'); lyric.textContent = card.lyric; lyric.hidden = !card.lyric;
      const list = document.getElementById('card-tracks'); list.hidden = false;
      card.tracks.forEach((track, index) => {
        const link = document.createElement('a');
        link.href = 'viora://moment#' + encodeURIComponent(JSON.stringify(track));
        link.textContent = '0' + (index + 1) + ' · ' + track.title;
        const artists = document.createElement('small'); artists.textContent = track.artists.join(' · ') + ' · Открыть в viora';
        link.appendChild(artists); list.appendChild(link);
      });
      const app = document.getElementById('app'); app.href = 'viora://card?id=' + cardRoute[1]; app.hidden = false;
      document.getElementById('hint').textContent = 'Нажми на трек, чтобы открыть его в viora. Для прослушивания нужен трек в твоей библиотеке. Аудио на этой странице не передаётся.';
      return;
    }
    const invite = location.pathname.match(/^\/c\/([A-Za-z0-9_-]{32})$/);
    if (invite) {
      document.getElementById('title').textContent = 'Вас приглашают в диалог';
      document.getElementById('artists').textContent = 'Обменивайтесь музыкой внутри viora';
      const app = document.getElementById('app');
      app.href = 'viora://chat?invite=' + invite[1]; app.hidden = false;
      document.getElementById('hint').textContent = 'Приглашение для одного человека, действует 7 дней. Откройте его в приложении.';
      return;
    }
    const short = location.pathname.match(/^\/m\/([A-Za-z0-9_-]{16})$/);
    let m;
    if (short) {
      const response = await fetch('/api/moments/' + short[1], {cache: 'no-store'});
      if (!response.ok) throw new Error('Unavailable');
      m = parseMoment('#' + encodeURIComponent(JSON.stringify(await response.json())));
    } else { m = parseMoment(location.hash); }
    if (m) {
      const app = document.getElementById('app');
      app.href = 'viora://moment#' + encodeURIComponent(JSON.stringify(m)); app.hidden = false;
      document.getElementById('app-hint').hidden = false;
      const reply = document.getElementById('reply');
      reply.href = 'viora://moment?reply=1#' + encodeURIComponent(JSON.stringify(m)); reply.hidden = false;
      const parent = document.getElementById('parent');
      parent.textContent = m.replyTo ? 'В ответ на «' + m.replyTo.title + '» · ' + m.replyTo.artists.join(' · ') : '';
      parent.hidden = !m.replyTo;
      document.getElementById('title').textContent = m.title;
      document.getElementById('artists').textContent = m.artists.join(' · ');
      const time = document.getElementById('time');
      time.textContent = '↗ ' + String(Math.floor(m.seconds / 60)).padStart(2, '0') + ':' + String(m.seconds % 60).padStart(2, '0'); time.hidden = false;
      const lyric = document.getElementById('lyric'); lyric.textContent = m.lyric ? '«' + m.lyric + '»' : ''; lyric.hidden = !m.lyric;
      const note = document.getElementById('note'); note.textContent = m.note; note.hidden = !m.note;
      const source = document.getElementById('source');
      if (m.source) { source.href = m.source; source.hidden = false; }
      document.getElementById('hint').textContent = m.source ? 'Открой трек и перейди к указанной секунде. Автоматическая перемотка зависит от музыкальной платформы.' : 'Найди этот трек в своей музыкальной библиотеке и перейди к указанной секунде.';
    }
  } catch (_) { const error = document.getElementById('error'); error.textContent = 'Страница недоступна или ссылка отключена. Попроси отправить действующую ссылку.'; error.hidden = false; }
}

if (typeof document !== 'undefined') { renderMoment(); window.addEventListener('hashchange', () => location.reload()); }
