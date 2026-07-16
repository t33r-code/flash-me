// Shared responsive breakpoint for the app's adaptive layouts.
//
// At/above this width the app uses desktop-style chrome — the left navigation
// rail (#230) and, later, the multi-pane set view (#236). Below it, mobile
// chrome (bottom navigation, push navigation).
//
// 600 is Material 3's "medium" threshold. It also flips landscape phones to the
// rail, which frees vertical space that a bottom bar would otherwise eat.
const double kWideLayoutBreakpoint = 600;

// Whether [width] (typically a LayoutBuilder's maxWidth) is a wide layout.
bool isWideWidth(double width) => width >= kWideLayoutBreakpoint;

// Minimum width the set-detail pane needs before the inline "add existing
// cards" library drawer (#234) may dock beside the card list. Below this the
// 320px drawer would squeeze the list so narrow that card rows overflow, so the
// drawer tucks away and the list goes full-width until the pane widens again.
const double kLibraryDrawerMinPaneWidth = 620;

// Below this pane width the set-detail toolbar can't fit all its icon actions,
// so the set-management ones (market/export/delete/edit) collapse into a single
// overflow (⋮) menu. Keeps the builder actions (+, library, study) visible.
const double kSetToolbarOverflowWidth = 520;

// Master-detail (My Sets) column sizing. The set list takes [kSetListWidth] when
// there's room but shrinks toward [kMinSetListWidth] first, so the detail pane
// keeps at least [kMinDetailPaneWidth] even at the narrow end of a wide layout.
// This lets master-detail engage on the same window-width breakpoint as the nav
// rail (no "rail present but single-column" middle state) without cramping the
// pane so hard that its card rows overflow.
const double kSetListWidth = 340;
const double kMinSetListWidth = 260;
const double kMinDetailPaneWidth = 300;
