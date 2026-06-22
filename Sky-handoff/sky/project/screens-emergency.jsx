// Emergency Unlock — the typed-reason path.
// The most psychologically charged screen in the app.

function EmergencyUnlock() {
  const t = window.SKY_TOKENS;
  const typed = "Family emergency, my mom's been in an accident and I need to coordinate with my siblings on";
  const charCount = typed.length;
  const minChars = 20;
  const countdown = 0; // 0s remaining — button is enabled
  const ready = countdown === 0 && charCount >= minChars;

  return (
    <div style={{
      width: '100%', height: '100%',
      background: '#F3F0EB',
      fontFamily: t.fontFamily, color: t.ink,
      position: 'relative', overflow: 'hidden',
    }}>
      {/* Subtle grey clouds in bg */}
      <div style={{
        position: 'absolute', top: 80, left: -60,
        width: 200, height: 70, background: t.cloudGrey,
        borderRadius: '50%', filter: 'blur(24px)', opacity: 0.4,
      }} />
      <div style={{
        position: 'absolute', top: 140, right: -40,
        width: 180, height: 60, background: t.cloudGrey,
        borderRadius: '50%', filter: 'blur(22px)', opacity: 0.35,
      }} />

      <div style={{
        position: 'relative', height: '100%',
        paddingTop: 70, paddingBottom: 50,
        display: 'flex', flexDirection: 'column',
      }}>
        {/* Top: cancel + countdown chip */}
        <div style={{
          padding: '0 20px', display: 'flex',
          alignItems: 'center', justifyContent: 'space-between',
          marginBottom: 16,
        }}>
          <button style={{
            background: 'transparent', border: 'none',
            color: t.inkSoft, fontSize: 16, fontWeight: 600,
            padding: '6px 10px', cursor: 'pointer',
            fontFamily: t.fontFamily,
          }}>Cancel</button>
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '6px 12px', borderRadius: 999,
            background: 'rgba(255,255,255,0.7)',
            border: '1px solid ' + t.divider,
            fontSize: 12, fontWeight: 700, color: t.inkSoft,
          }}>
            <svg width="12" height="12" viewBox="0 0 12 12" fill="none" stroke="currentColor" strokeWidth="1.5">
              <circle cx="6" cy="6" r="5"/>
              <path d="M6 3v3l2 1.5"/>
            </svg>
            Paste disabled
          </div>
        </div>

        {/* Hero: small sad Nimbus */}
        <div style={{ display: 'flex', justifyContent: 'center', marginBottom: 8 }}>
          <Nimbus state="rainy" size={130} />
        </div>

        {/* Title */}
        <div style={{
          fontSize: 28, fontWeight: 800, letterSpacing: -0.6,
          textAlign: 'center', color: t.ink, padding: '12px 24px 4px',
        }}>Are you sure?</div>

        {/* Body */}
        <div style={{
          fontSize: 15, fontWeight: 500, color: t.inkSoft,
          textAlign: 'center', lineHeight: 1.45,
          padding: '0 32px', marginBottom: 18,
          textWrap: 'pretty',
        }}>
          If you can't go outside right now, type why.
          Nimbus will remember — your streak resets.
        </div>

        {/* Text input area */}
        <div style={{ padding: '0 20px', marginBottom: 12 }}>
          <div style={{
            background: '#fff',
            borderRadius: 18,
            padding: '16px 18px',
            border: '1.5px solid ' + (ready ? t.coralStreak : t.divider),
            boxShadow: ready ? '0 0 0 4px rgba(255,138,122,0.12)' : 'none',
            transition: 'all 0.2s',
            minHeight: 130,
            position: 'relative',
          }}>
            <div style={{
              fontSize: 16, fontWeight: 500, color: t.ink,
              lineHeight: 1.5, fontFamily: t.fontFamily,
            }}>
              {typed}
              <span style={{
                display: 'inline-block', width: 2, height: 18,
                background: t.coralStreak, verticalAlign: 'text-bottom',
                marginLeft: 1, animation: 'none',
              }} />
            </div>
          </div>

          {/* Counter + helper */}
          <div style={{
            display: 'flex', justifyContent: 'space-between', alignItems: 'center',
            padding: '8px 4px', fontSize: 12, fontWeight: 700,
          }}>
            <span style={{ color: t.mossGreenDeep }}>
              {charCount >= minChars ? '✓ ' : ''}
              {charCount >= minChars ? 'Long enough' : `${minChars - charCount} more chars`}
            </span>
            <span style={{ color: t.inkMuted }}>{charCount} / 200</span>
          </div>
        </div>

        {/* Spacer */}
        <div style={{ flex: 1 }} />

        {/* Consequences card */}
        <div style={{
          margin: '0 20px 16px',
          background: 'rgba(255,138,122,0.08)',
          border: '1px solid rgba(255,138,122,0.2)',
          borderRadius: 14,
          padding: '14px 16px',
        }}>
          <div style={{
            fontSize: 11, fontWeight: 800, color: t.coralStreakDeep,
            textTransform: 'uppercase', letterSpacing: 0.8,
            marginBottom: 6,
          }}>If you unlock</div>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
            <ConseqRow text="Your 12 day streak resets to 0" />
            <ConseqRow text="Nimbus turns rainy for the rest of today" />
            <ConseqRow text="Tomorrow is a fresh start at midnight" />
          </div>
        </div>

        {/* Confirm button */}
        <div style={{ padding: '0 20px' }}>
          <button style={ready ? skyCoralBtn() : {
            ...skyCoralBtn(),
            background: t.inkDisabled, color: '#fff',
            boxShadow: 'none', cursor: 'default',
          }}>
            {ready ? 'Unlock anyway' : `Wait ${countdown}s…`}
          </button>
        </div>
      </div>
    </div>
  );
}

function ConseqRow({ text }) {
  const t = window.SKY_TOKENS;
  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
      <span style={{
        width: 4, height: 4, borderRadius: 2,
        background: t.coralStreak, flexShrink: 0,
      }} />
      <span style={{ fontSize: 13, fontWeight: 500, color: t.ink }}>{text}</span>
    </div>
  );
}

Object.assign(window, { EmergencyUnlock, ConseqRow });
