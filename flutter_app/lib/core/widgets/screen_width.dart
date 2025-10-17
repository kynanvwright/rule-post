enum Breakpoint { phone, tablet, desktop }

Breakpoint getBreakpoint(double width) {
  if (width < 600) return Breakpoint.phone;
  if (width < 1024) return Breakpoint.tablet;
  return Breakpoint.desktop;
}
