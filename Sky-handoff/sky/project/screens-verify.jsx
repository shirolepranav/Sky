// Verification flow — Recording + Success.

// ─────────────────────────────────────────────────────────────
// Recording — camera viewfinder with countdown ring and prompt
// ─────────────────────────────────────────────────────────────
function VerificationRecording() {
  const t = window.SKY_TOKENS;
  const progress = 0.46; // 14s of 30s elapsed
  return (
    <div style={{
      width: '100%', height: '100%',
      background: '#0F0F12', position: 'relative', overflow: 'hidden',
      fontFamily: t.fontFamily,
    }}>
      {/* Fake camera viewfinder — sky-ish gradient with horizon */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'linear-gradient(180deg, #5BB0DC 0%, #8FCAE2 35%, #BFDDED 55%, #D4C9A8 75%, #8FA37A 100%)',
      }} />
      {/* Soft cloud streaks */}
      <div style={{
        position: 'absolute', top: '20%', left: '10%', width: '60%', height: 24,
        background: '#fff', borderRadius: '50%', filter: 'blur(14px)', opacity: 0.55,
      }} />
      <div style={{
        position: 'absolute', top: '32%', right: '15%', width: '40%', height: 20,
        background: '#fff', borderRadius: '50%', filter: 'blur(12px)', opacity: 0.5,
      }} />
      <div style={{
        position: 'absolute', top: '12%', left: '40%', width: '30%', height: 18,
        background: '#fff', borderRadius: '50%', filter: 'blur(10px)', opacity: 0.65,
      }} />
      {/* Soft sun */}
      <div style={{
        position: 'absolute', top: '22%', right: '12%',
        width: 70, height: 70, borderRadius: '50%',
        background: 'radial-gradient(circle, rgba(255,232,180,1) 0%, rgba(255,214,107,0.4) 50%, transparent 70%)',
      }} />
      {/* Subtle film grain */}
      <div style={{
        position: 'absolute', inset: 0,
        background: 'radial-gradient(circle at center, transparent 50%, rgba(0,0,0,0.25) 100%)',
      }} />

      {/* Top chrome — close + prompt + sensor indicators */}
      <div style={{
        position: 'absolute', top: 0, left: 0, right: 0,
        paddingTop: 60, paddingLeft: 16, paddingRight: 16,
        display: 'flex', flexDirection: 'column', gap: 12,
        zIndex: 5,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          {/* Cancel button */}
          <div style={{
            width: 38, height: 38, borderRadius: 19,
            background: 'rgba(0,0,0,0.4)', backdropFilter: 'blur(8px)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
            color: '#fff', fontSize: 20, fontWeight: 600,
          }}>×</div>
          {/* Recording indicator */}
          <div style={{
            display: 'inline-flex', alignItems: 'center', gap: 8,
            padding: '8px 14px', borderRadius: 999,
            background: 'rgba(0,0,0,0.45)', backdropFilter: 'blur(8px)',
            color: '#fff',
          }}>
            <span style={{
              width: 8, height: 8, borderRadius: 4,
              background: t.coralStreak,
              boxShadow: '0 0 8px ' + t.coralStreak,
            }} />
            <span style={{ fontSize: 13, fontWeight: 700, letterSpacing: 0.5 }}>REC · 14s / 30s</span>
          </div>
        </div>

        {/* Prompt card */}
        <div style={{
          margin: '12px auto 0', maxWidth: 320,
          padding: '14px 18px', borderRadius: 18,
          background: 'rgba(255,255,255,0.92)',
          backdropFilter: 'blur(12px)',
          border: '1px solid rgba(255,255,255,0.5)',
          textAlign: 'center',
          boxShadow: '0 8px 24px rgba(0,0,0,0.15)',
        }}>
          <div style={{ fontSize: 11, fontWeight: 800, color: t.cloudGreyDeep, textTransform: 'uppercase', letterSpacing: 1, marginBottom: 4 }}>Now</div>
          <div style={{ fontSize: 18, fontWeight: 800, color: t.ink, letterSpacing: -0.3 }}>
            Point at the sky for 5 seconds
          </div>
        </div>
      </div>

      {/* Center cross-hair for framing */}
      <div style={{
        position: 'absolute', top: '50%', left: '50%',
        transform: 'translate(-50%, -50%)',
        width: 56, height: 56,
        border: '1.5px solid rgba(255,255,255,0.7)',
        borderRadius: 8,
      }}>
        <div style={{
          position: 'absolute', top: '50%', left: '50%', transform: 'translate(-50%,-50%)',
          width: 6, height: 6, borderRadius: 3, background: 'rgba(255,255,255,0.8)',
        }} />
      </div>

      {/* Bottom — sensor checks + countdown ring */}
      <div style={{
        position: 'absolute', bottom: 0, left: 0, right: 0,
        paddingBottom: 40, paddingTop: 20,
        background: 'linear-gradient(180deg, transparent 0%, rgba(0,0,0,0.45) 50%, rgba(0,0,0,0.65) 100%)',
        display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 20,
        zIndex: 5,
      }}>
        {/* Sensor checks row */}
        <div style={{ display: 'flex', gap: 8, padding: '0 20px', flexWrap: 'wrap', justifyContent: 'center' }}>
          {[
            { label: 'Daylight', ok: true },
            { label: 'GPS', ok: true },
            { label: 'Moving', ok: true },
            { label: 'Sky visible', ok: 'progress' },
          ].map((s) => (
            <div key={s.label} style={{
              display: 'inline-flex', alignItems: 'center', gap: 6,
              padding: '6px 10px', borderRadius: 999,
              background: 'rgba(0,0,0,0.35)',
              backdropFilter: 'blur(8px)',
              border: '1px solid rgba(255,255,255,0.15)',
              color: '#fff', fontSize: 11, fontWeight: 700,
            }}>
              {s.ok === true && (
                <svg width="12" height="12" viewBox="0 0 12 12">
                  <path d="M2 6.5L4.5 9 10 3" stroke={t.mossGreen} strokeWidth="2.2" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
                </svg>
              )}
              {s.ok === 'progress' && (
                <svg width="12" height="12" viewBox="0 0 12 12">
                  <circle cx="6" cy="6" r="4" stroke={t.sunYellow} strokeWidth="2" fill="none" strokeDasharray="6 4"/>
                </svg>
              )}
              {s.label}
            </div>
          ))}
        </div>

        {/* Big countdown ring */}
        <div style={{ position: 'relative' }}>
          <ProgressRing progress={progress} size={120} stroke={6}
            color="#fff" trackColor="rgba(255,255,255,0.3)">
            <div style={{ fontSize: 32, fontWeight: 800, color: '#fff', letterSpacing: -0.8 }}>16</div>
            <div style={{ fontSize: 11, fontWeight: 700, color: 'rgba(255,255,255,0.7)', letterSpacing: 1.2, textTransform: 'uppercase' }}>seconds</div>
          </ProgressRing>
        </div>
      </div>
    </div>
  );
}

// ─────────────────────────────────────────────────────────────
// Success — rainbow Nimbus, streak counter, apps unlocked
// ─────────────────────────────────────────────────────────────
function VerificationSuccess() {
  const t = window.SKY_TOKENS;
  return (
    <div style={{
      width: '100%', height: '100%',
      background: 'linear-gradient(180deg, #FFFBF2 0%, ' + t.warmCream + ' 50%, #FFE9DC 100%)',
      fontFamily: t.fontFamily, color: t.ink,
      position: 'relative', overflow: 'hidden',
    }}>
      {/* Confetti dots */}
      {[
        { x: 40, y: 120, c: '#FF8A7A', s: 6 },
        { x: 300, y: 110, c: '#FFD66B', s: 8 },
        { x: 60, y: 200, c: '#7CB342', s: 5 },
        { x: 340, y: 220, c: '#A8D8EA', s: 7 },
        { x: 100, y: 80, c: '#FFD66B', s: 4 },
        { x: 280, y: 280, c: '#FF8A7A', s: 6 },
        { x: 30, y: 320, c: '#A8D8EA', s: 5 },
        { x: 360, y: 350, c: '#7CB342', s: 6 },
      ].map((d, i) => (
        <div key={i} style={{
          position: 'absolute', top: d.y, left: d.x,
          width: d.s, height: d.s, borderRadius: '50%',
          background: d.c, opacity: 0.7,
        }} />
      ))}

      <div style={{
        position: 'relative', height: '100%',
        paddingTop: 70, paddingBottom: 40,
        display: 'flex', flexDirection: 'column', alignItems: 'center',
      }}>
        {/* VERIFIED chip */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 6,
          padding: '8px 16px', borderRadius: 999,
          background: '#fff',
          border: '1.5px solid ' + t.mossGreen,
          color: t.mossGreenDeep, fontSize: 12, fontWeight: 800,
          letterSpacing: 1.2, textTransform: 'uppercase',
          marginBottom: 16,
        }}>
          <svg width="14" height="14" viewBox="0 0 14 14">
            <circle cx="7" cy="7" r="6" fill={t.mossGreen}/>
            <path d="M3.5 7.2L6 9.5 10.5 4.5" stroke="#fff" strokeWidth="1.8" fill="none" strokeLinecap="round" strokeLinejoin="round"/>
          </svg>
          Verified
        </div>

        {/* Hero — rainbow Nimbus */}
        <div style={{ marginBottom: 16 }}>
          <Nimbus state="rainbow" size={240} />
        </div>

        {/* Big title */}
        <div style={{
          fontSize: 40, fontWeight: 800, letterSpacing: -1.2,
          color: t.ink, textAlign: 'center', lineHeight: 1.05,
        }}>That's the stuff.</div>

        <div style={{
          fontSize: 16, fontWeight: 500, color: t.inkSoft,
          textAlign: 'center', lineHeight: 1.45,
          padding: '12px 36px', marginBottom: 24,
          textWrap: 'pretty',
        }}>
          Apps are unlocked until midnight. Take your time.
        </div>

        {/* Streak hero — animated tick */}
        <div style={{
          background: '#fff', padding: '20px 28px',
          borderRadius: 20, border: '1px solid ' + t.divider,
          boxShadow: '0 4px 20px rgba(255,138,122,0.15)',
          display: 'flex', alignItems: 'center', gap: 18,
          marginBottom: 18,
        }}>
          <div style={{
            position: 'relative',
            width: 56, height: 56, borderRadius: 28,
            background: 'rgba(255,138,122,0.15)',
            display: 'flex', alignItems: 'center', justifyContent: 'center',
          }}>
            <FlameIcon color={t.coralStreak} size={32} />
          </div>
          <div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
              <span style={{ fontSize: 36, fontWeight: 800, letterSpacing: -1, color: t.coralStreakDeep }}>13</span>
              <span style={{ fontSize: 15, fontWeight: 700, color: t.inkSoft }}>day streak</span>
            </div>
            <div style={{ fontSize: 12, fontWeight: 700, color: t.mossGreenDeep, marginTop: 2 }}>
              ↑ new personal best
            </div>
          </div>
        </div>

        {/* Badge unlocked */}
        <div style={{
          display: 'inline-flex', alignItems: 'center', gap: 10,
          padding: '8px 14px', borderRadius: 999,
          background: 'rgba(255,214,107,0.25)',
          border: '1px solid rgba(255,214,107,0.5)',
          marginBottom: 'auto',
        }}>
          <span style={{ fontSize: 16 }}>✨</span>
          <span style={{ fontSize: 13, fontWeight: 800, color: t.ink }}>Badge unlocked · Cirrus</span>
        </div>

        {/* Button */}
        <div style={{ width: '100%', padding: '0 24px' }}>
          <button style={skyPrimaryBtn()}>Done</button>
        </div>
      </div>
    </div>
  );
}

Object.assign(window, { VerificationRecording, VerificationSuccess });
