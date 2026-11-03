import '../core/design_system/palette.dart';

// Compatibility aliases. Screens should use AppPalette or context.colors.
// The theme itself lives in core/design_system/theme.dart.
export '../core/design_system/theme.dart';

const ink = AppPalette.ink;
const aqua = AppPalette.teal;
const aquaDark = AppPalette.tealDeep;
const paper = AppPalette.paper;
const line = AppPalette.hairline;
const mint = AppPalette.mint;
const yellow = AppPalette.amber;
// Darkened from the brand coral so error text meets WCAG AA (4.5:1) on white.
const coral = AppPalette.coral;
