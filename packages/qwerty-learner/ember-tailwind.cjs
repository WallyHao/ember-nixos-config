const { colors } = require('./ember-theme.json');

function channels(hex) {
  return [1, 3, 5].map((offset) => parseInt(hex.slice(offset, offset + 2), 16));
}

function mix(color, surface, weight) {
  const base = channels(surface);
  const result = channels(color).map((value, index) => Math.round(value * weight + base[index] * (1 - weight)));
  return '#' + result.map((value) => value.toString(16).padStart(2, '0')).join('');
}

const { base00, base01, base02, base03, base04, base05, base06, base07, base08, base09, base0A, base0B, base0C, base0D, base0E, base0F } = colors;
const neutral = {
  50: base07, 100: base06, 200: base05, 300: mix(base05, base04, 0.65), 400: base04,
  500: mix(base04, base03, 0.7), 600: base03, 700: base02, 800: base01, 900: base00, 950: base00,
};

// Midtones for filled controls carry light labels. Foreground utilities
// get their own accents so that links and practice feedback stay legible.
function ramp(color, midtone) {
  return {
    50: mix(color, base07, 0.08), 100: mix(color, base07, 0.16), 200: mix(color, base07, 0.35),
    300: mix(color, base07, 0.67), 400: mix(base07, midtone, 0.06), 500: midtone, 600: mix(midtone, base00, 0.90),
    700: mix(midtone, base00, 0.75), 800: mix(midtone, base00, 0.55), 900: mix(midtone, base00, 0.38),
  };
}

const accent = ramp(base08, mix(base08, base0F, 0.25));
const accentRoles = { indigo: base0A, blue: base0D, sky: base0C, green: base0B, red: base08, orange: base09, amber: base0A, yellow: base0A, purple: base0E };
const foreground = Object.fromEntries(Object.keys(accentRoles).map((name) => {
  const value = `rgb(var(--ember-${name}-text) / <alpha-value>)`;
  return [name, { 400: value, 500: value, 600: value, 700: value }];
}));

function accentsFor(dark) {
  return Object.fromEntries(Object.entries(accentRoles).map(([name, color]) => {
    const adjusted = name === 'indigo' ? (dark ? color : base0F)
      : dark ? mix(color, base07, 0.78) : mix(color, base00, 0.57);
    return [`--ember-${name}-text`, channels(adjusted).join(' ')];
  }));
}

module.exports = {
  theme: {
    extend: {
      colors: {
        white: base07, black: base00,
        gray: neutral, slate: neutral, zinc: neutral, neutral, stone: neutral,
        ...Object.fromEntries(Object.entries(accentRoles).map(([name, color]) =>
          [name, ramp(color, mix(color, base00, 0.62))])),
        indigo: accent,
        primary: accent[500],
      },
      textColor: { ...foreground, primary: foreground.indigo[500] },
    },
  },
  plugins: [({ addBase }) => addBase({
    ':root': {
      '--ember-background': base07, '--ember-foreground': base00, '--ember-highlight': base0F,
      '--ember-shadow': channels(base0F).join(', '), ...accentsFor(false),
    },
    'html.dark': {
      '--ember-background': base00, '--ember-foreground': base06, '--ember-highlight': base0A,
      ...accentsFor(true),
    },
  })],
};
