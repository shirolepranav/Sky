// Today tab — the canonical blocked state.
// Cozy warm: Nimbus front and centre, generous space, soft cream.

const TODAY_STATE = {
  usedMin: 107,        // 1h 47m
  budgetMin: 120,      // 2h
  streak: 12,
};

// Reusable: progress ring SVG
function ProgressRing({ progress = 0.5, size = 200, stroke = 14, color, trackColor, children }) {
  const t = window.SKY_TOKENS;
  const c = color || t.coralStreak;
  const tc = trackColor || 'rgba(255,138,122,0.18)';
  const r = (size - stroke) / 2;
  const cir = 2 * Math.PI * r;
  const off = cir * (1 - Math.min(1, Math.max(0, progress)));
  return (
    <div style={{ width: size, height: size, position: 'relative' }}>
      <svg width={size} height={size} style={{ display: 'block', transform: 'rotate(-90deg)' }}>
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={tc} strokeWidth={stroke} />
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={c} strokeWidth={stroke}
          strokeDasharray={cir} strokeDashoffset={off} strokeLinecap="round" />
      </svg>
      <div style={{
        position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column',
        alignItems: 'center', justifyContent: 'center',
      }}>{children}</div>
    </div>
  );
}

// Reusable: bottom tab bar
function SkyTabBar({ active = 'today' }) {
  const t = window.SKY_TOKENS;
  const tabs = [
    { id: 'today', label: 'Today', icon: <SunIcon color={active === 'today' ? t.mossGreen : t.inkMuted} size={22}/> },
    { id: 'streaks', label: 'Streaks', icon: <FlameIcon color={active === 'streaks' ? t.mossGreen : t.inkMuted} size={22}/> },
    { id: 'settings', label: 'Settings', icon: <GearIcon color={active === 'settings' ? t.mossGreen : t.inkMuted} size={22}/> },
  ];
  return (
    <div style={{
      position: 'absolute', bottom: 0, left: 0, right: 0,
      paddingBottom: 34, paddingTop: 8,
      background: 'rgba(255,251,242,0.92)',
      backdropFilter: 'blur(20px) saturate(160%)',
      WebkitBackdropFilter: 'blur(20px) saturate(160%)',
      borderTop: '1px solid ' + t.divider,
      display: 'flex', justifyContent: 'space-around', zIndex: 5,
    }}>
      {tabs.map((tb) => (
        <div key={tb.id} style={{
          display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
          padding: '4px 16px', flex: 1,
        }}>
          {tb.icon}
          <span style={{
            fontSize: 10, fontWeight: 700, letterSpacing: 0.3,
            color: active === tb.id ? t.mossGreen : t.inkMuted,
            fontFamily: t.fontFamily,
          }}>{tb.label}</span>
        </div>
      ))}
    </div>
  );
}

function GearIcon({ color = '#9CA3AF', size = 22 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="12" r="3" fill={color} fillOpacity="0.2"/>
      <path d="M12 1v3M12 20v3M4.2 4.2l2.1 2.1M17.7 17.7l2.1 2.1M1 12h3M20 12h3M4.2 19.8l2.1-2.1M17.7 6.3l2.1-2.1"/>
    </svg>
  );
}

// ─────────────────────────────────────────────────────────────
// Cozy warm — Nimbus hero, generous space, soft cream
// ─────────────────────────────────────────────────────────────
function TodayCozy() {
  const t = window.SKY_TOKENS;
  const pct = TODAY_STATE.usedMin / TODAY_STATE.budgetMin;
  return (
    <div style={{
      width: '100%', height: '100%', background: t.surface,
      fontFamily: t.fontFamily, color: t.ink,
      position: 'relative', overflow: 'hidden',
    }}>
      {/* Soft cloud background drift */}
      <div style={{
        position: 'absolute', top: 60, right: -40, width: 200, height: 80,
        background: t.warmCream, borderRadius: '50%',
        filter: 'blur(20px)', opacity: 0.7,
      }} />
      <div style={{
        position: 'absolute', bottom: 180, left: -60, width: 180, height: 70,
        background: t.primarySky, borderRadius: '50%',
        filter: 'blur(30px)', opacity: 0.25,
      }} />

      <div style={{
        position: 'relative', height: '100%',
        paddingTop: 62, paddingBottom: 116,
        display: 'flex', flexDirection: 'column',
        alignItems: 'center',
      }}>
        {/* Greeting */}
        <div style={{
          width: '100%', padding: '8px 24px 0', textAlign: 'left',
        }}>
          <div style={{
            fontSize: 13, fontWeight: 700, color: t.inkMuted,
            textTransform: 'uppercase', letterSpacing: 1.2,
          }}>Tuesday · today</div>
          <div style={{
            fontSize: 28, fontWeight: 800, letterSpacing: -0.6,
            color: t.ink, marginTop: 2,
          }}>Time's up.</div>
        </div>

        {/* Hero Nimbus */}
        <div style={{ marginTop: 20, marginBottom: 12 }}>
          <Nimbus state="cloudyGrey" size={220} />
        </div>

        {/* Status pill */}
        <div style={{
          background: t.warmCream, padding: '10px 18px',
          borderRadius: 999, fontSize: 14, fontWeight: 700,
          color: t.coralStreakDeep, marginBottom: 18,
          display: 'inline-flex', alignItems: 'center', gap: 8,
        }}>
          <span style={{ width: 8, height: 8, borderRadius: 4, background: t.coralStreak }} />
          Apps are paused
        </div>

        {/* Body copy */}
        <div style={{
          fontSize: 16, fontWeight: 500, color: t.inkSoft,
          textAlign: 'center', lineHeight: 1.45,
          padding: '0 36px', marginBottom: 20,
        }}>
          You used <span style={{ fontWeight: 800, color: t.ink }}>1h 47m</span> of your 2h today.
          Verify outside to unlock for the rest of the night.
        </div>

        {/* Spacer pushes buttons down */}
        <div style={{ flex: 1 }} />

        {/* Streak chip */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          background: '#fff', padding: '10px 16px', borderRadius: 999,
          border: '1px solid ' + t.divider, marginBottom: 16,
          boxShadow: '0 2px 8px rgba(45,55,72,0.04)',
        }}>
          <FlameIcon color={t.coralStreak} size={18} />
          <span style={{ fontSize: 14, fontWeight: 700, color: t.ink }}>{TODAY_STATE.streak} day streak</span>
          <span style={{ fontSize: 13, color: t.inkSoft }}>· don't break it</span>
        </div>

        {/* Buttons */}
        <div style={{ width: '100%', padding: '0 24px', display: 'flex', flexDirection: 'column', gap: 10 }}>
          <button style={skyPrimaryBtn()}>Verify outside</button>
          <button style={skySecondaryBtn()}>I can't go outside right now</button>
        </div>
      </div>

      <SkyTabBar active="today" />
    </div>
  );
}

Object.assign(window, {
  TodayCozy,
  ProgressRing, SkyTabBar, GearIcon,
});
