// Foundations card — palette + type + Nimbus states + components.
// This is the design system reference card.

function FoundationsCard() {
  const t = window.SKY_TOKENS;
  const swatch = (name, hex, hint) => (
    <div key={name} style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{
        width: '100%', height: 88, background: hex,
        borderRadius: 14,
        border: '1px solid rgba(0,0,0,0.04)',
      }} />
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'baseline' }}>
        <span style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>{name}</span>
        <span style={{ fontSize: 11, color: t.inkMuted, fontFeatureSettings: '"tnum"', letterSpacing: 0.3 }}>{hex}</span>
      </div>
      {hint && <span style={{ fontSize: 11, color: t.inkSoft, lineHeight: 1.4 }}>{hint}</span>}
    </div>
  );

  return (
    <div style={{
      width: '100%', height: '100%', background: t.surface,
      padding: '40px 44px', boxSizing: 'border-box',
      fontFamily: t.fontFamily, color: t.ink, overflow: 'auto',
    }}>
      {/* Header */}
      <div style={{ marginBottom: 32 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 16, marginBottom: 4 }}>
          <Nimbus state="fluffyWhite" size={64} />
          <div>
            <h1 style={{
              margin: 0, fontSize: 36, fontWeight: 800,
              letterSpacing: -0.8, color: t.ink, lineHeight: 1.05,
            }}>Sky · design foundations</h1>
            <p style={{
              margin: '6px 0 0', fontSize: 15, color: t.inkSoft,
              letterSpacing: -0.1,
            }}>Touch grass for people who actually want to quit.</p>
          </div>
        </div>
      </div>

      {/* Section: Palette */}
      <SectionTitle>Palette</SectionTitle>
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)',
        gap: 16, marginBottom: 36,
      }}>
        {swatch('Primary sky', t.primarySky, 'Hero, calm backgrounds')}
        {swatch('Warm cream', t.warmCream, 'Surfaces, shield')}
        {swatch('Moss green', t.mossGreen, 'Tints · nav active · success')}
        {swatch('Coral streak', t.coralStreak, 'Streak, alerts')}
        {swatch('Cloud grey', t.cloudGrey, 'Indoor Nimbus, paused')}
        {swatch('Sun yellow', t.sunYellow, 'Verified, milestones')}
      </div>

      {/* Section: Nimbus states */}
      <SectionTitle>Nimbus — the 5 states</SectionTitle>
      <div style={{
        display: 'grid', gridTemplateColumns: 'repeat(5, 1fr)',
        gap: 12, marginBottom: 36, background: '#fff',
        padding: 24, borderRadius: 20,
        border: '1px solid ' + t.divider,
      }}>
        {[
          ['cloudyGrey', 'Cloudy', 'Default · not yet verified'],
          ['fluffyWhite', 'Fluffy', 'Idle · under budget'],
          ['sunny', 'Sunny', 'After verification'],
          ['rainbow', 'Rainbow', 'Streak milestone'],
          ['rainy', 'Rainy', 'Emergency unlock'],
        ].map(([state, label, hint]) => (
          <div key={state} style={{ textAlign: 'center' }}>
            <div style={{
              height: 110, display: 'flex',
              alignItems: 'center', justifyContent: 'center',
              marginBottom: 8,
            }}>
              <Nimbus state={state} size={110} />
            </div>
            <div style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>{label}</div>
            <div style={{ fontSize: 11, color: t.inkSoft, marginTop: 2, lineHeight: 1.3 }}>{hint}</div>
          </div>
        ))}
      </div>

      {/* Section: Type */}
      <SectionTitle>Type · Nunito</SectionTitle>
      <div style={{
        background: '#fff', padding: '24px 28px', borderRadius: 20,
        border: '1px solid ' + t.divider, marginBottom: 36,
      }}>
        <div style={{ fontSize: 40, fontWeight: 800, letterSpacing: -1, lineHeight: 1.05, color: t.ink }}>Time's up.</div>
        <div style={{ fontSize: 22, fontWeight: 700, letterSpacing: -0.4, marginTop: 12, color: t.ink }}>Title · 22 / 700</div>
        <div style={{ fontSize: 17, fontWeight: 500, lineHeight: 1.45, color: t.ink, marginTop: 8 }}>
          Body · 17 / 500 · Nimbus is waiting outside for you.
        </div>
        <div style={{ fontSize: 13, fontWeight: 600, color: t.inkMuted, marginTop: 8, textTransform: 'uppercase', letterSpacing: 0.6 }}>
          Caption · 13 / 600
        </div>
      </div>

      {/* Section: Components */}
      <SectionTitle>Components</SectionTitle>
      <div style={{
        background: '#fff', padding: 24, borderRadius: 20,
        border: '1px solid ' + t.divider,
        display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16,
      }}>
        <button style={skyPrimaryBtn()}>Verify now</button>
        <button style={skySecondaryBtn()}>I can't go outside</button>
        <button style={skyCoralBtn()}>Unlock anyway</button>
        <div style={{
          background: t.warmCream, borderRadius: 14, padding: '12px 14px',
          display: 'flex', alignItems: 'center', gap: 8,
        }}>
          <FlameIcon color={t.coralStreak} size={20} />
          <span style={{ fontSize: 16, fontWeight: 700, color: t.ink }}>12 day streak</span>
        </div>
        <div style={{
          gridColumn: '1 / -1', display: 'flex', alignItems: 'center', gap: 10,
          paddingTop: 4, fontSize: 12, color: t.inkSoft, lineHeight: 1.4,
        }}>
          <span style={{ width: 16, height: 16, borderRadius: 5, background: t.mossGreenAction, flexShrink: 0 }} />
          Primary button fill is <strong style={{ color: t.ink, fontWeight: 800 }}>&nbsp;{t.mossGreenAction}</strong>&nbsp;— a deeper moss than the
          {' '}{t.mossGreen} tint so the white label clears WCAG AA (4.6:1).
        </div>
      </div>

      {/* Footer note */}
      <div style={{
        marginTop: 28, fontSize: 12, color: t.inkMuted, lineHeight: 1.5,
      }}>
        Calm, cute, soft. Never pure white or pure black. Mascot front and center across the app.
        Subtle motion only — Nimbus has a 2-second idle bob and 0.5s transitions between states.
      </div>
    </div>
  );
}

function SectionTitle({ children }) {
  const t = window.SKY_TOKENS;
  return (
    <div style={{
      fontSize: 12, fontWeight: 800, color: t.inkMuted,
      textTransform: 'uppercase', letterSpacing: 1.2,
      marginBottom: 14,
    }}>{children}</div>
  );
}

// SVG icons used across screens
function FlameIcon({ color = '#FF8A7A', size = 24 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <path d="M12 2c0 4-5 5-5 10a5 5 0 0010 0c0-2-1-3-1-5 2 1 3 3 3 5a7 7 0 11-14 0c0-5 7-6 7-10z" fill={color}/>
    </svg>
  );
}

function SunIcon({ color = '#FFD66B', size = 20 }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none">
      <circle cx="12" cy="12" r="4.5" fill={color}/>
      {[0,45,90,135,180,225,270,315].map((d) => (
        <rect key={d} x="11" y="1.5" width="2" height="3.5" rx="1" fill={color} transform={`rotate(${d} 12 12)`}/>
      ))}
    </svg>
  );
}

Object.assign(window, { FoundationsCard, SectionTitle, FlameIcon, SunIcon });
