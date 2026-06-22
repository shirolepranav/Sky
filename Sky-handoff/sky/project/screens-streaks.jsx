// Streaks tab — current streak hero, stat row, badges grid.

function StreaksScreen() {
  const t = window.SKY_TOKENS;

  const badges = [
    { id: 'firstLight', name: 'First Light', unlocked: true, color: t.sunYellow, hint: 'Your first verification' },
    { id: 'cumulus', name: 'Cumulus', unlocked: true, color: t.primarySky, hint: '3 day streak' },
    { id: 'stratus', name: 'Stratus', unlocked: true, color: t.primarySky, hint: '7 day streak' },
    { id: 'cirrus', name: 'Cirrus', unlocked: true, color: t.primarySky, hint: '14 day streak', justEarned: true },
    { id: 'sunburst', name: 'Sunburst', unlocked: false, color: t.sunYellow, hint: '30 day streak' },
    { id: 'clearsky', name: 'Clear Sky', unlocked: false, color: t.primarySky, hint: '60 day streak' },
    { id: 'boundless', name: 'Boundless', unlocked: false, color: t.coralStreak, hint: '100 day streak' },
    { id: 'earlybird', name: 'Early Bird', unlocked: true, color: t.sunYellow, hint: 'Verify before 8am' },
    { id: 'wanderer', name: 'Wanderer', unlocked: false, color: t.mossGreen, hint: '5 places (3 of 5)' },
    { id: 'comeback', name: 'Comeback', unlocked: false, color: t.coralStreak, hint: 'Recover from emergency' },
  ];

  return (
    <div style={{
      width: '100%', height: '100%',
      background: t.surface,
      fontFamily: t.fontFamily, color: t.ink,
      position: 'relative', overflow: 'hidden',
    }}>
      <div style={{
        height: '100%', paddingTop: 62, paddingBottom: 100,
        overflowY: 'auto',
      }}>
        {/* Header */}
        <div style={{ padding: '4px 20px 16px' }}>
          <h1 style={{ margin: 0, fontSize: 32, fontWeight: 800, letterSpacing: -0.6 }}>Streaks</h1>
        </div>

        {/* Hero current streak */}
        <div style={{
          margin: '0 16px 16px', padding: '24px 20px',
          background: 'linear-gradient(135deg, #FFF6E5 0%, #FFE9DC 100%)',
          borderRadius: 24, position: 'relative', overflow: 'hidden',
        }}>
          {/* Decorative flame */}
          <div style={{
            position: 'absolute', right: -10, top: -10,
            opacity: 0.18,
          }}>
            <FlameIcon color={t.coralStreak} size={140} />
          </div>

          <div style={{
            fontSize: 12, fontWeight: 800, color: t.coralStreakDeep,
            letterSpacing: 1.2, textTransform: 'uppercase',
          }}>Current</div>
          <div style={{
            display: 'flex', alignItems: 'baseline', gap: 10,
            marginTop: 4, marginBottom: 8,
          }}>
            <span style={{
              fontSize: 72, fontWeight: 800, letterSpacing: -3,
              color: t.coralStreakDeep, lineHeight: 1,
            }}>13</span>
            <span style={{
              fontSize: 18, fontWeight: 700, color: t.ink,
            }}>days</span>
          </div>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '5px 10px', borderRadius: 999,
            background: 'rgba(255,255,255,0.7)',
            fontSize: 12, fontWeight: 700, color: t.mossGreenDeep,
          }}>
            <span style={{ fontSize: 14 }}>↑</span> new personal best
          </div>
        </div>

        {/* Stat row */}
        <div style={{
          margin: '0 16px 20px',
          display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
          gap: 10,
        }}>
          {[
            { label: 'Longest', value: '13', sub: 'days' },
            { label: 'Total', value: '34', sub: 'verified' },
            { label: 'Emergency', value: '2', sub: 'unlocks' },
          ].map((s) => (
            <div key={s.label} style={{
              background: '#fff', padding: '14px 12px', borderRadius: 16,
              border: '1px solid ' + t.divider,
            }}>
              <div style={{
                fontSize: 10, fontWeight: 800, color: t.inkMuted,
                textTransform: 'uppercase', letterSpacing: 1,
              }}>{s.label}</div>
              <div style={{ marginTop: 4, display: 'flex', alignItems: 'baseline', gap: 4 }}>
                <span style={{ fontSize: 24, fontWeight: 800, letterSpacing: -0.6, color: t.ink }}>{s.value}</span>
                <span style={{ fontSize: 11, color: t.inkSoft, fontWeight: 600 }}>{s.sub}</span>
              </div>
            </div>
          ))}
        </div>

        {/* Badges section */}
        <div style={{
          display: 'flex', alignItems: 'center', justifyContent: 'space-between',
          padding: '0 20px 12px',
        }}>
          <div style={{ fontSize: 18, fontWeight: 800, letterSpacing: -0.3 }}>Badges</div>
          <div style={{ fontSize: 13, fontWeight: 700, color: t.inkSoft }}>4 / 10</div>
        </div>
        <div style={{
          margin: '0 16px',
          padding: 16, background: '#fff',
          borderRadius: 20, border: '1px solid ' + t.divider,
          display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
          gap: 14,
        }}>
          {badges.map((b) => (
            <BadgeCell key={b.id} badge={b} />
          ))}
        </div>

        <div style={{ height: 24 }} />
      </div>

      <SkyTabBar active="streaks" />
    </div>
  );
}

function BadgeCell({ badge }) {
  const t = window.SKY_TOKENS;
  const u = badge.unlocked;
  return (
    <div style={{
      display: 'flex', flexDirection: 'column',
      alignItems: 'center', gap: 6, position: 'relative',
    }}>
      <div style={{
        width: 56, height: 56, borderRadius: 18,
        background: u
          ? `linear-gradient(135deg, ${badge.color} 0%, ${badge.color}DD 100%)`
          : '#F0EDE5',
        border: u ? 'none' : '1px dashed ' + t.divider,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        position: 'relative',
        boxShadow: u ? '0 4px 12px ' + badge.color + '40' : 'none',
      }}>
        {/* Inner mark — varies by badge */}
        {u ? <BadgeGlyph id={badge.id} /> : (
          <svg width="16" height="20" viewBox="0 0 16 20" fill="none" stroke={t.inkMuted} strokeWidth="1.8">
            <rect x="2" y="9" width="12" height="9" rx="1.5"/>
            <path d="M5 9V6a3 3 0 016 0v3"/>
          </svg>
        )}
        {badge.justEarned && (
          <div style={{
            position: 'absolute', top: -3, right: -3,
            width: 14, height: 14, borderRadius: 7,
            background: t.coralStreak,
            border: '2px solid #fff',
          }} />
        )}
      </div>
      <div style={{
        fontSize: 10, fontWeight: 700, color: u ? t.ink : t.inkMuted,
        textAlign: 'center', lineHeight: 1.1,
      }}>{badge.name}</div>
    </div>
  );
}

function BadgeGlyph({ id }) {
  // Distinct simple glyph per badge
  const glyphs = {
    firstLight: <svg width="28" height="28" viewBox="0 0 28 28"><circle cx="14" cy="14" r="5" fill="#fff"/>{[0,45,90,135,180,225,270,315].map(d=>(<rect key={d} x="13" y="3" width="2" height="4" rx="1" fill="#fff" transform={`rotate(${d} 14 14)`}/>))}</svg>,
    cumulus: <svg width="32" height="22" viewBox="0 0 32 22"><ellipse cx="16" cy="14" rx="12" ry="5" fill="#fff"/><circle cx="10" cy="11" r="5" fill="#fff"/><circle cx="16" cy="8" r="6" fill="#fff"/><circle cx="22" cy="11" r="5" fill="#fff"/></svg>,
    stratus: <svg width="32" height="24" viewBox="0 0 32 24"><rect x="3" y="6" width="26" height="3" rx="1.5" fill="#fff"/><rect x="6" y="11" width="20" height="3" rx="1.5" fill="#fff"/><rect x="3" y="16" width="26" height="3" rx="1.5" fill="#fff"/></svg>,
    cirrus: <svg width="32" height="20" viewBox="0 0 32 20"><path d="M3 10 Q 8 4 16 8 T 29 10" stroke="#fff" strokeWidth="2.5" fill="none" strokeLinecap="round"/><path d="M5 16 Q 10 12 16 14 T 27 16" stroke="#fff" strokeWidth="2.2" fill="none" strokeLinecap="round" opacity="0.7"/></svg>,
    sunburst: <svg width="28" height="28" viewBox="0 0 28 28"><circle cx="14" cy="14" r="6" fill="#fff"/>{[0,30,60,90,120,150,180,210,240,270,300,330].map(d=>(<rect key={d} x="13" y="1" width="2" height="5" rx="1" fill="#fff" transform={`rotate(${d} 14 14)`}/>))}</svg>,
    clearsky: <svg width="28" height="28" viewBox="0 0 28 28"><circle cx="14" cy="14" r="11" fill="none" stroke="#fff" strokeWidth="2"/><circle cx="14" cy="14" r="3" fill="#fff"/></svg>,
    boundless: <svg width="32" height="20" viewBox="0 0 32 20"><path d="M8 10 A 5 5 0 1 1 16 10 A 5 5 0 1 0 24 10" stroke="#fff" strokeWidth="2.5" fill="none" strokeLinecap="round"/></svg>,
    earlybird: <svg width="28" height="24" viewBox="0 0 28 24"><circle cx="14" cy="6" r="4" fill="#fff"/>{[0,45,90,135,180,225,270,315].map(d=>(<rect key={d} x="13" y="0" width="2" height="3" rx="1" fill="#fff" transform={`rotate(${d} 14 6)`}/>))}<path d="M5 20 Q 14 14 23 20" stroke="#fff" strokeWidth="2" fill="none" strokeLinecap="round"/></svg>,
    wanderer: <svg width="28" height="28" viewBox="0 0 28 28"><path d="M14 4 C 9 4 6 8 6 12 C 6 18 14 24 14 24 C 14 24 22 18 22 12 C 22 8 19 4 14 4 Z" fill="#fff"/><circle cx="14" cy="12" r="3" fill="#7CB342"/></svg>,
    comeback: <svg width="28" height="24" viewBox="0 0 28 24"><path d="M5 12 A 9 9 0 1 1 14 21" stroke="#fff" strokeWidth="2.5" fill="none" strokeLinecap="round"/><path d="M2 9 L 5 12 L 8 9" stroke="#fff" strokeWidth="2.5" fill="none" strokeLinecap="round" strokeLinejoin="round"/></svg>,
  };
  return glyphs[id] || null;
}

Object.assign(window, { StreaksScreen, BadgeCell, BadgeGlyph });
