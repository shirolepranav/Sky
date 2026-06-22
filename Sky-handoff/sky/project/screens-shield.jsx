// Custom shield — the screen shown when a blocked app is opened.
// Warm invitation: friendly, honest, never a guilt-trip.
// "Nimbus is waiting outside for you."

function ShieldWarm() {
  const t = window.SKY_TOKENS;
  return (
    <div style={{
      width: '100%', height: '100%',
      background: 'linear-gradient(180deg, ' + t.warmCream + ' 0%, #FFFBF2 50%, ' + t.primarySky + '22 100%)',
      fontFamily: t.fontFamily, color: t.ink,
      position: 'relative', overflow: 'hidden',
    }}>
      {/* Soft blurred cloud bg shapes */}
      <div style={{
        position: 'absolute', top: 100, right: -60,
        width: 220, height: 90, background: '#fff',
        borderRadius: '50%', filter: 'blur(20px)', opacity: 0.7,
      }} />
      <div style={{
        position: 'absolute', top: 280, left: -40,
        width: 160, height: 70, background: '#fff',
        borderRadius: '50%', filter: 'blur(16px)', opacity: 0.5,
      }} />

      <div style={{
        position: 'relative', height: '100%',
        paddingTop: 80, paddingBottom: 50,
        display: 'flex', flexDirection: 'column', alignItems: 'center',
      }}>
        {/* Small Sky brand label at top */}
        <div style={{
          fontSize: 11, fontWeight: 800, letterSpacing: 2,
          color: t.cloudGreyDeep, textTransform: 'uppercase',
          padding: '6px 12px', background: 'rgba(255,255,255,0.6)',
          borderRadius: 999, marginBottom: 24,
        }}>☁ Sky</div>

        {/* Hero Nimbus — looking expectantly */}
        <div style={{ marginBottom: 8 }}>
          <Nimbus state="fluffyWhite" size={220} />
        </div>

        {/* Title */}
        <div style={{
          fontSize: 36, fontWeight: 800, letterSpacing: -0.8,
          color: t.ink, marginTop: 16, marginBottom: 12, textAlign: 'center',
        }}>Nimbus is outside.</div>

        {/* Body */}
        <div style={{
          fontSize: 17, fontWeight: 500, color: t.inkSoft,
          textAlign: 'center', lineHeight: 1.45,
          padding: '0 36px', marginBottom: 28,
          textWrap: 'pretty',
        }}>
          Record 30 seconds outside and the apps unlock for the rest of today.
        </div>

        {/* Streak chip — gentle reminder */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 8,
          padding: '8px 14px', borderRadius: 999,
          background: 'rgba(255,255,255,0.7)',
          border: '1px solid rgba(255,138,122,0.2)',
          marginBottom: 'auto',
        }}>
          <FlameIcon color={t.coralStreak} size={16} />
          <span style={{ fontSize: 13, fontWeight: 700, color: t.ink }}>12 days · keep it alive</span>
        </div>

        {/* Buttons */}
        <div style={{
          width: '100%', padding: '0 24px',
          display: 'flex', flexDirection: 'column', gap: 10,
        }}>
          <button style={skyPrimaryBtn()}>Go outside to unlock</button>
          <button style={{
            ...skySecondaryBtn(),
            background: 'transparent', border: 'none',
            color: t.inkSoft, fontWeight: 600,
            padding: '14px 24px', fontSize: 14,
          }}>I can't go outside right now</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { ShieldWarm });
