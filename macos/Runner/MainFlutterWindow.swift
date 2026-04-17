import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Minimum window size — prevents layout breaking
    self.minSize = NSSize(width: 850, height: 580)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}