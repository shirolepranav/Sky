// Nimbus — Sky's cloud mascot. 5 states tied to user behavior.
// Composed from soft overlapping shapes, simple eyes and expression.
// All states share the same cloud silhouette, vary in fill + accessories.

function Nimbus({ state = 'fluffyWhite', size = 180, expressionOverride }) {
  const w = size;
  const h = size * 0.78;

  // State-specific palette
  const cfg = {
    fluffyWhite: {
      fill: '#FFFFFF',
      shadow: '#E8F0F5',
      cheek: 'rgba(255,138,122,0.4)',
      expr: 'happy',
    },
    cloudyGrey: {
      fill: '#B8C5D0',
      shadow: '#9BA9B6',
      cheek: 'rgba(255,138,122,0.25)',
      expr: 'neutral',
    },
    sunny: {
      fill: '#FFFFFF',
      shadow: '#FFF4D6',
      cheek: 'rgba(255,138,122,0.55)',
      expr: 'beaming',
    },
    rainbow: {
      fill: '#FFFFFF',
      shadow: '#F5E8FF',
      cheek: 'rgba(255,138,122,0.55)',
      expr: 'beaming',
    },
    rainy: {
      fill: '#A8B5C2',
      shadow: '#8A98A6',
      cheek: 'rgba(120,140,160,0.3)',
      expr: 'sad',
    },
  };
  const c = cfg[state] || cfg.fluffyWhite;
  const expr = expressionOverride || c.expr;

  return (
    <svg
      width={w}
      height={h}
      viewBox="0 0 200 156"
      style={{ overflow: 'visible', display: 'block' }}
    >
      {/* Sun rays — behind cloud for sunny state */}
      {state === 'sunny' && (
        <g style={{ transformOrigin: '100px 80px' }}>
          <circle cx="100" cy="80" r="62" fill="#FFD66B" opacity="0.35" />
          <circle cx="100" cy="80" r="48" fill="#FFD66B" opacity="0.5" />
          {/* radial rays */}
          {[0, 45, 90, 135, 180, 225, 270, 315].map((deg, i) => (
            <rect
              key={i}
              x="98"
              y="-6"
              width="4"
              height="14"
              rx="2"
              fill="#FFD66B"
              transform={`rotate(${deg} 100 80)`}
              opacity="0.85"
            />
          ))}
        </g>
      )}

      {/* Rainbow arc — behind cloud for rainbow state */}
      {state === 'rainbow' && (
        <g>
          {[
            { c: '#FF8A7A', r: 85 },
            { c: '#FFD66B', r: 75 },
            { c: '#7CB342', r: 65 },
            { c: '#A8D8EA', r: 55 },
          ].map((band, i) => (
            <path
              key={i}
              d={`M ${100 - band.r} 95 A ${band.r} ${band.r} 0 0 1 ${100 + band.r} 95`}
              stroke={band.c}
              strokeWidth="10"
              fill="none"
              strokeLinecap="round"
            />
          ))}
          {/* sparkles */}
          <g fill="#FFD66B">
            <circle cx="25" cy="40" r="2.5" />
            <circle cx="175" cy="50" r="2" />
            <circle cx="15" cy="90" r="1.8" />
            <circle cx="185" cy="100" r="2.2" />
          </g>
        </g>
      )}

      {/* Rain drops — for rainy state */}
      {state === 'rainy' && (
        <g>
          {[
            { x: 55, y: 120, h: 14 },
            { x: 75, y: 130, h: 12 },
            { x: 100, y: 122, h: 16 },
            { x: 125, y: 132, h: 12 },
            { x: 145, y: 118, h: 14 },
          ].map((d, i) => (
            <path
              key={i}
              d={`M ${d.x} ${d.y} Q ${d.x - 3} ${d.y + d.h / 2} ${d.x} ${d.y + d.h} Q ${d.x + 3} ${d.y + d.h / 2} ${d.x} ${d.y}`}
              fill="#7BB3D6"
              opacity="0.85"
            />
          ))}
        </g>
      )}

      {/* Cloud body — soft shadow first */}
      <g transform="translate(0, 2)">
        <ellipse cx="100" cy="92" rx="78" ry="28" fill={c.shadow} opacity="0.6" />
        <circle cx="60" cy="75" r="28" fill={c.shadow} opacity="0.6" />
        <circle cx="100" cy="55" r="38" fill={c.shadow} opacity="0.6" />
        <circle cx="140" cy="70" r="32" fill={c.shadow} opacity="0.6" />
      </g>

      {/* Cloud body — main fill */}
      <ellipse cx="100" cy="90" rx="78" ry="28" fill={c.fill} />
      <circle cx="60" cy="73" r="28" fill={c.fill} />
      <circle cx="100" cy="53" r="38" fill={c.fill} />
      <circle cx="140" cy="68" r="32" fill={c.fill} />

      {/* Inner cloud highlight (top-left) */}
      <ellipse cx="78" cy="42" rx="14" ry="6" fill="rgba(255,255,255,0.5)" opacity={state === 'cloudyGrey' || state === 'rainy' ? 0.3 : 0.8} />

      {/* Cheeks */}
      {expr !== 'sad' && (
        <>
          <ellipse cx="74" cy="82" rx="7" ry="4" fill={c.cheek} />
          <ellipse cx="126" cy="82" rx="7" ry="4" fill={c.cheek} />
        </>
      )}
      {expr === 'sad' && (
        <>
          <ellipse cx="76" cy="86" rx="6" ry="3.5" fill={c.cheek} opacity="0.6" />
          <ellipse cx="124" cy="86" rx="6" ry="3.5" fill={c.cheek} opacity="0.6" />
        </>
      )}

      {/* Eyes — vary by expression */}
      {expr === 'happy' && (
        <>
          <circle cx="82" cy="70" r="4" fill="#2D3748" />
          <circle cx="118" cy="70" r="4" fill="#2D3748" />
          {/* eye highlights */}
          <circle cx="83.5" cy="68.5" r="1.3" fill="#fff" />
          <circle cx="119.5" cy="68.5" r="1.3" fill="#fff" />
        </>
      )}
      {expr === 'neutral' && (
        <>
          {/* half-lidded eyes (drowsy) */}
          <path d="M 78 70 Q 82 67 86 70" stroke="#2D3748" strokeWidth="2.5" fill="none" strokeLinecap="round" />
          <path d="M 114 70 Q 118 67 122 70" stroke="#2D3748" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        </>
      )}
      {expr === 'beaming' && (
        <>
          {/* happy closed curves */}
          <path d="M 76 72 Q 82 66 88 72" stroke="#2D3748" strokeWidth="2.8" fill="none" strokeLinecap="round" />
          <path d="M 112 72 Q 118 66 124 72" stroke="#2D3748" strokeWidth="2.8" fill="none" strokeLinecap="round" />
        </>
      )}
      {expr === 'sad' && (
        <>
          {/* downturned closed eyes */}
          <path d="M 76 74 Q 82 78 88 74" stroke="#2D3748" strokeWidth="2.5" fill="none" strokeLinecap="round" />
          <path d="M 112 74 Q 118 78 124 74" stroke="#2D3748" strokeWidth="2.5" fill="none" strokeLinecap="round" />
        </>
      )}

      {/* Mouth — vary by expression */}
      {expr === 'happy' && (
        <path d="M 92 84 Q 100 90 108 84" stroke="#2D3748" strokeWidth="2.5" fill="none" strokeLinecap="round" />
      )}
      {expr === 'neutral' && (
        <path d="M 94 86 Q 100 88 106 86" stroke="#2D3748" strokeWidth="2.2" fill="none" strokeLinecap="round" />
      )}
      {expr === 'beaming' && (
        <path d="M 88 82 Q 100 96 112 82 Q 100 90 88 82 Z" fill="#2D3748" />
      )}
      {expr === 'sad' && (
        <path d="M 92 90 Q 100 84 108 90" stroke="#2D3748" strokeWidth="2.5" fill="none" strokeLinecap="round" />
      )}
    </svg>
  );
}

// Small mascot avatar for inline use (e.g. on buttons, status banners)
function NimbusMini({ state = 'fluffyWhite', size = 40 }) {
  return <Nimbus state={state} size={size} />;
}

Object.assign(window, { Nimbus, NimbusMini });
