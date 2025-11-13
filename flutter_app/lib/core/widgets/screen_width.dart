// flutter_app/lib/core/widgets/screen_width.dart

// Determine screen width breakpoint for responsive design
enum Breakpoint { phone, tablet, desktop }

Breakpoint getBreakpoint(double width) {
  if (width < 600) return Breakpoint.phone;
  if (width < 1024) return Breakpoint.tablet;
  return Breakpoint.desktop;
}