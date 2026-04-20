import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(
    _ sender: NSApplication
  ) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
  
  override func applicationShouldTerminate(
    _ sender: NSApplication
  ) -> NSApplication.TerminateReply {
    showClosingOverlay()
    // Give Flutter 1.2s to show the animation, then force kill
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
      exit(0)
    }
    return .terminateLater
  }

  private func showClosingOverlay() {
    guard let window = NSApplication.shared.windows.first else { return }

    let overlay = NSView(frame: window.contentView?.bounds ?? .zero)
    overlay.wantsLayer = true

    // Match system appearance
    let isDark = window.effectiveAppearance.name == .darkAqua ||
                 window.effectiveAppearance.name == .vibrantDark ||
                 window.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

    overlay.layer?.backgroundColor = isDark
      ? NSColor(white: 0.1, alpha: 1.0).cgColor
      : NSColor(white: 0.95, alpha: 1.0).cgColor

    // Spinner
    let spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
    spinner.style = .spinning
    spinner.controlSize = .regular
    spinner.isIndeterminate = true
    spinner.appearance = isDark
      ? NSAppearance(named: .darkAqua)
      : NSAppearance(named: .aqua)

    // "Closing" label
    let label = NSTextField(labelWithString: "Closing...")
    label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
    label.textColor = isDark ? .white : NSColor(white: 0.2, alpha: 1.0)
    label.sizeToFit()

    // Center both in window
    let cx = (overlay.bounds.width  - 32) / 2
    let cy = (overlay.bounds.height + 48) / 2
    spinner.frame.origin = NSPoint(x: cx, y: cy)

    let lx = (overlay.bounds.width - label.bounds.width) / 2
    label.frame.origin = NSPoint(x: lx, y: cy - 36)

    overlay.addSubview(spinner)
    overlay.addSubview(label)
    window.contentView?.addSubview(overlay)

    spinner.startAnimation(nil)

    // Fade in
    overlay.alphaValue = 0
    NSAnimationContext.runAnimationGroup { ctx in
      ctx.duration = 0.2
      overlay.animator().alphaValue = 1.0
    }
  }
}