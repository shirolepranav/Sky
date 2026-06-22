// Sky design tokens — single source of truth for color, type, spacing.
// Mirrors AppBranding.swift from the PRD §11.

const SKY_TOKENS = {
  // Brand palette
  primarySky: '#A8D8EA',
  primarySkyDeep: '#7AB8D0',    // hover/active state
  warmCream: '#FFF6E5',
  warmCreamDeep: '#F5EAD0',
  mossGreen: '#7CB342',
  mossGreenDeep: '#5C8A2E',
  // Button fill — deeper so white label clears WCAG AA (4.6:1).
  // Keep mossGreen above for tints, nav, checkmarks on light bg.
  mossGreenAction: '#52822A',
  mossGreenActionDeep: '#3D6420',  // pressed / drop-shadow
  coralStreak: '#FF8A7A',
  coralStreakDeep: '#E5685A',
  cloudGrey: '#B8C5D0',
  cloudGreyDeep: '#9BA9B6',
  sunYellow: '#FFD66B',
  sunYellowDeep: '#E5B843',

  // Text
  ink: '#2D3748',          // primary text
  inkSoft: '#5A6373',      // secondary text
  inkMuted: '#9CA3AF',     // tertiary / captions
  inkDisabled: '#CBD5E0',

  // Surfaces
  surface: '#FFFBF2',      // warmer than warmCream — main bg
  surfaceCard: '#FFFFFF',
  surfaceElev: '#FFFEFB',
  divider: 'rgba(45,55,72,0.08)',

  // Dark mode (used by the dark hero variant)
  darkBg: '#15171F',       // deep night sky
  darkBgElev: '#1F2230',
  darkInk: '#F0F4F8',
  darkInkSoft: '#A8B3C2',
  darkDivider: 'rgba(255,255,255,0.08)',

  // Type
  fontFamily: 'Nunito, -apple-system, BlinkMacSystemFont, system-ui, sans-serif',

  // Radii
  rCard: 24,
  rBtn: 18,
  rChip: 14,
};

// Reusable button styles (functions return inline-style objects so each
// caller gets its own — no shared mutation).
function skyPrimaryBtn(opts = {}) {
  const { dark = false, disabled = false } = opts;
  return {
    background: disabled ? SKY_TOKENS.inkDisabled : SKY_TOKENS.mossGreenAction,
    color: '#fff',
    border: 'none',
    borderRadius: SKY_TOKENS.rBtn,
    padding: '18px 24px',
    fontFamily: SKY_TOKENS.fontFamily,
    fontSize: 17,
    fontWeight: 800,
    letterSpacing: -0.2,
    cursor: disabled ? 'default' : 'pointer',
    width: '100%',
    boxShadow: disabled ? 'none' : '0 2px 0 ' + SKY_TOKENS.mossGreenActionDeep,
  };
}
function skySecondaryBtn(opts = {}) {
  const { dark = false } = opts;
  return {
    background: 'transparent',
    color: dark ? SKY_TOKENS.darkInk : SKY_TOKENS.inkSoft,
    border: `1.5px solid ${dark ? SKY_TOKENS.darkDivider : 'rgba(45,55,72,0.12)'}`,
    borderRadius: SKY_TOKENS.rBtn,
    padding: '16px 24px',
    fontFamily: SKY_TOKENS.fontFamily,
    fontSize: 16,
    fontWeight: 700,
    letterSpacing: -0.2,
    cursor: 'pointer',
    width: '100%',
  };
}
function skyCoralBtn() {
  return {
    background: SKY_TOKENS.coralStreak,
    color: '#fff',
    border: 'none',
    borderRadius: SKY_TOKENS.rBtn,
    padding: '18px 24px',
    fontFamily: SKY_TOKENS.fontFamily,
    fontSize: 17,
    fontWeight: 800,
    cursor: 'pointer',
    width: '100%',
    boxShadow: '0 2px 0 ' + SKY_TOKENS.coralStreakDeep,
  };
}

Object.assign(window, { SKY_TOKENS, skyPrimaryBtn, skySecondaryBtn, skyCoralBtn });
