import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController

    // Open at an iPhone's logical size so the desktop build looks like the
    // phone app. The window stays resizable; widening it past 840 points
    // switches the app to its tablet/desktop layout.
    let phone = NSSize(width: 390, height: 844)
    self.setContentSize(phone)
    self.contentMinSize = NSSize(width: 320, height: 480)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
