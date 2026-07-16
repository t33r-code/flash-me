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
