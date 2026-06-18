import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.isReleasedWhenClosed = false

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Register idle monitor
    IdleMonitor.shared.register(with: flutterViewController.engine.binaryMessenger)

    // Регистрируем MethodChannel для главного окна через IpcRouter
    if let appDelegate = NSApp.delegate as? AppDelegate {
        IpcRouter.shared.register(messenger: flutterViewController.engine.binaryMessenger, role: "main") { (call, result) in
            // Делегируем нативные команды (например, updateTray) в appDelegate
            appDelegate.handleNativeCommand(call: call, result: result)
        }
    }

    super.awakeFromNib()
  }
}
