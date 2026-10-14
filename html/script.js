(() => {
  'use strict';

  const $ = (id) => document.getElementById(id);
  const hud = $('hud');
  const slotEls = Array.from(document.querySelectorAll('.slot'));

  /* ---------- Barras com "dano fantasma" ---------- */
  // Quando a barra diminui, uma faixa clara fica um instante no lugar do que foi
  // perdido e depois encolhe. Quando aumenta, a faixa acompanha na hora.
  function setBar(fillEl, ghostEl, pct) {
    const prev = parseFloat(fillEl.dataset.v || '0');
    fillEl.dataset.v = String(pct);
    fillEl.style.width = `${pct}%`;

    if (pct < prev) {
      ghostEl.style.transition = 'width .7s ease .35s';
    } else {
      ghostEl.style.transition = 'none';
    }
    ghostEl.style.width = `${pct}%`;
  }

  /* ---------- Slots de arma e municao ---------- */
  function renderSlot(el, data) {
    const icon = el.querySelector('.icon');
    const ammo = el.querySelector('.ammo');

    el.classList.toggle('empty', !data);
    el.classList.toggle('selected', !!(data && data.selected));

    const wanted = data ? data.icon : '';
    if (icon.dataset.icon !== wanted) {
      icon.dataset.icon = wanted;
      icon.innerHTML = wanted ? (window.ICONS[wanted] || window.ICONS.pistol) : '';
    }

    // slot que nao esta na mao mostra o total; o da mao aparece grande ao lado
    ammo.textContent = data && !data.selected && data.ammo !== undefined ? String(data.ammo) : '';
  }

  const ammoBox = $('ammoBox');
  const clipEl = $('clip');
  const reserveEl = $('reserve');

  function renderAmmo(slots) {
    const sel = slots.find((s) => s && s.selected);

    if (sel && sel.ammo !== undefined) {
      const hasClip = sel.clip !== undefined;
      clipEl.textContent = String(hasClip ? sel.clip : sel.ammo);
      reserveEl.textContent = hasClip ? `/ ${Math.max(0, sel.ammo - sel.clip)}` : '';
      ammoBox.classList.remove('idle');
      ammoBox.classList.toggle('low', hasClip && sel.clip <= 3);
    } else {
      // arma branca ou sem arma na mao
      clipEl.textContent = '–';
      reserveEl.textContent = '';
      ammoBox.classList.add('idle');
      ammoBox.classList.remove('low');
    }
  }

  /* ---------- Kills e tiro na cabeca ---------- */
  const killsEl = $('kills');
  const hsPctEl = $('hsPct');
  const hsRing = $('hsRing');
  const killsBox = $('killsBox');
  const hsBox = $('hsBox');
  const statRow = $('statRow');
  const killfx = $('killfx');
  const RING = 113.1;   // circunferencia do anel (2 * pi * 18)

  function setStats(kills, hs) {
    killsEl.textContent = kills;
    hsPctEl.textContent = hs + '%';
    hsRing.style.strokeDashoffset = String(RING * (1 - Math.min(100, hs) / 100));
  }

  function replay(el, cls) {
    el.classList.remove(cls);
    void el.offsetWidth;          // reinicia a animacao
    el.classList.add(cls);
  }

  function killEffect(head) {
    replay(killsBox, 'pop');
    if (head) replay(hsBox, 'pop');
    killfx.classList.toggle('head', !!head);
    $('k1').textContent = head ? 'HEADSHOT' : 'KILL';
    $('k2').textContent = head ? '+1 KILL' : '+1';
    replay(killfx, 'show');
  }

  /* ---------- HUD ---------- */
  function setHud(d) {
    hud.classList.toggle('hidden', !d.visible);
    if (!d.visible) return;

    if (d.kills !== undefined) setStats(d.kills, d.hs || 0);

    setBar($('health'), $('healthGhost'), d.health);
    $('healthN').textContent = d.health;

    // Nivel e XP
    if (d.level !== undefined) {
      const maxed = !d.xpMax;
      $('level').textContent = d.level;
      $('xp').style.width = maxed ? '100%' : `${Math.min(100, (d.xp || 0) * 100 / d.xpMax)}%`;
      $('xpN').textContent = maxed ? 'MAX' : `${d.xp || 0}/${d.xpMax}`;
    }

    const low = d.health <= 25;
    $('healthRow').classList.toggle('low', low);
    $('vignette').classList.toggle('low', low && d.health > 0);

    const slots = d.slots || [];
    slots.forEach((s, i) => renderSlot(slotEls[i], s));
    renderAmmo(slots);

    // Velocimetro
    $('speedo').classList.toggle('hidden', !d.inVeh);
    if (d.inVeh) {
      $('spd').textContent = d.speed;
      $('unit').textContent = d.unit;
      const hasFuel = d.fuel !== undefined && d.fuel !== null;
      $('fuelWrap').classList.toggle('hidden', !hasFuel);
      if (hasFuel) {
        $('fuel').style.width = `${d.fuel}%`;
        $('fuelWrap').classList.toggle('low', d.fuel <= 15);
      }
    }
  }

  /* ---------- Atalhos ---------- */
  const HK_ICONS = {
    team:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9 11a3.5 3.5 0 1 0 0-7 3.5 3.5 0 0 0 0 7zm7 0a3 3 0 1 0 0-6 3 3 0 0 0 0 6zM9 13c-3 0-7 1.5-7 4.2V20h14v-2.8C16 14.5 12 13 9 13zm7.2.1c1.9.5 5.8 1.6 5.8 4.1V20h-4v-2.8c0-1.700-.7-3.100-1.800-4.100z"/></svg>',
    weapon: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="6.5"/><path d="M12 2v5M12 17v5M2 12h5M17 12h5"/></svg>',
    skin:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M6 3h12l4 6-10 12L2 9z"/></svg>',
    car:    '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M5 11l1.6-4.4A2 2 0 0 1 8.5 5h7a2 2 0 0 1 1.9 1.6L19 11a2 2 0 0 1 2 2v4a1 1 0 0 1-1 1h-1.5a2 2 0 0 1-4 0h-5a2 2 0 0 1-4 0H4a1 1 0 0 1-1-1v-4a2 2 0 0 1 2-2zm2.2 0h9.6l-1.1-3.2H8.3zM7 14.5a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4zm10 0a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4z"/></svg>'
  };
  const hotkeysEl = $('hotkeys');

  function setHotkeys(list) {
    hotkeysEl.innerHTML = '';
    hotkeysEl.classList.toggle('hidden', !list || !list.length);
    (list || []).forEach((h) => {
      const el = document.createElement('div');
      el.className = 'hk';
      el.innerHTML = `<span class="hk-ico">${HK_ICONS[h.icon] || HK_ICONS.team}</span>` +
        '<span class="hk-label"></span><kbd class="hk-key"></kbd>';
      el.querySelector('.hk-label').textContent = h.label || '';
      el.querySelector('.hk-key').textContent = h.key || '';
      hotkeysEl.appendChild(el);
    });
  }

  function setConfig(c) {
    setHotkeys(c.hotkeys);
    statRow.classList.toggle('hidden', c.showStats === false);

    document.body.dataset.logo = c.logoPosition === 'center' ? 'center' : 'top';

    const logo = $('logo');
    const name = $('cityName');
    name.textContent = c.name || '';
    name.style.display = c.name ? 'block' : 'none';

    if (c.logo) {
      logo.style.height = `${c.logoHeight || 34}px`;
      logo.onload = () => { logo.style.display = 'block'; name.style.display = 'none'; };
      logo.onerror = () => { logo.style.display = 'none'; name.style.display = c.name ? 'block' : 'none'; };
      logo.src = c.logo;
    }
  }

  /* ---------- Avisos ---------- */
  const NOTIF_ICONS = {
    safe:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l8 3v6c0 5-3.4 9.3-8 11-4.6-1.7-8-6-8-11V5z"/></svg>',
    danger: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="6.5"/><path d="M12 2v5M12 17v5M2 12h5M17 12h5"/></svg>',
    warn:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2L1 21h22zm1 15h-2v-2h2zm0-4h-2V9h2z"/></svg>',
    level:  '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.9 6.3 6.9.8-5.1 4.7 1.4 6.8L12 17.2 5.9 20.6l1.4-6.8L2.2 9.1l6.9-.8z"/></svg>',
    info:   '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 1 0 0 20 10 10 0 0 0 0-20zm1 15h-2v-6h2zm0-8h-2V7h2z"/></svg>'
  };
  const notifsEl = $('notifs');

  function addNotify(d) {
    const kind = NOTIF_ICONS[d.kind] ? d.kind : 'info';
    const dur = d.duration || 5000;

    const el = document.createElement('div');
    el.className = `notif ${kind}`;
    el.innerHTML = `<div class="ic">${NOTIF_ICONS[kind]}</div>` +
      '<div class="nt"><div class="tt"></div><div class="tx"></div></div><i class="life"></i>';
    el.querySelector('.tt').textContent = d.title || '';
    const tx = el.querySelector('.tx');
    if (d.text) tx.textContent = d.text; else tx.remove();
    el.querySelector('.life').style.animationDuration = `${dur}ms`;

    notifsEl.appendChild(el);
    while (notifsEl.children.length > 3) notifsEl.firstElementChild.remove();

    setTimeout(() => {
      el.classList.add('out');
      setTimeout(() => el.remove(), 300);
    }, dur);
  }

  window.addEventListener('message', (e) => {
    const d = e.data || {};

    if (d.action === 'hud') setHud(d);
    if (d.action === 'config') setConfig(d);
    if (d.action === 'notify') addNotify(d);
    if (d.action === 'kill') killEffect(d.headshot);

    if (d.action === 'info') {
      $('info').classList.toggle('hidden', !d.show);
      $('pid').textContent = d.id;
      $('online').textContent = d.online;
      $('ping').textContent = d.ping + ' ms';
      const chip = $('pingChip');
      chip.classList.remove('good', 'mid', 'bad');
      chip.classList.add(d.ping < 80 ? 'good' : d.ping < 150 ? 'mid' : 'bad');
    }
  });

  // Avisa o jogo que a interface carregou (ele manda a logo e o nome da cidade)
  fetch(`https://${GetParentResourceName()}/ready`, { method: 'POST', body: '{}' }).catch(() => {});
})();