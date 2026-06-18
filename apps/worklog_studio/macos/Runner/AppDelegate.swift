import Cocoa
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate {
    private var updaterController: SPUStandardUpdaterController!
    private var popoverEngine: FlutterEngine?
    private var popoverPanel: PopoverPanel?
    private var statusItem: NSStatusItem!

    private var popupLastCloseTime: Date = Date.distantPast
    
    override func applicationDidFinishLaunching(_ notification: Notification) {
        // 1. Инициализируем Sparkle
        setupUpdater()
        
        // 2. Инициализируем отдельный движок для поповера (tray role)
        popoverEngine = FlutterEngine(name: "PopoverEngine", project: nil)
        
        if let engine = popoverEngine {
            RegisterGeneratedPlugins(registry: engine)
            
            // Register idle monitor
            IdleMonitor.shared.register(with: engine.binaryMessenger)
            
            // Настраиваем MethodChannel через IpcRouter ДО запуска движка
            IpcRouter.shared.register(messenger: engine.binaryMessenger, role: "tray") { [weak self] (call, result) in
                self?.handleNativeCommand(call: call, result: result)
            }
            
            // Запускаем движок стандартно
            engine.run(withEntrypoint: nil)
            NSLog("AppDelegate: popoverEngine (tray) started")
            
            // 3. Создаем контроллер и панель для поповера
            let flutterViewController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
            flutterViewController.backgroundColor = .clear // Убираем черный фон у Flutter
            
            popoverPanel = PopoverPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 650),
                flutterViewController: flutterViewController
            )
            
            // НАБЛЮДАТЕЛЬ ЗА ПОТЕРЕЙ ФОКУСА (закрывает поповер при клике вне него)
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: popoverPanel,
                queue: .main
            ) { [weak self] _ in
                self?.hidePopover()
            }
            
            // Дублирующий наблюдатель: если потерял фокус весь App (переключились на другую программу)
            NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.hidePopover()
            }
        }
        
        // 4. Настраиваем Tray Icon (NSStatusItem)
        setupStatusItem()
        
        // 5. Вызываем super, чтобы Flutter показал главное окно (MainFlutterWindow)
        super.applicationDidFinishLaunching(notification)
    }

    private func setupUpdater() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(named: "AppIcon")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        if let panel = popoverPanel, panel.isVisible {
            hidePopover()
        } else {
            if Date().timeIntervalSince(popupLastCloseTime) < 0.2 {
                return
            }
            showPopover()
        }
    }

    func showPopover() {
        guard let panel = popoverPanel else { return }
        
        let width: CGFloat = 360
        let newHeight: CGFloat = 650
        
        let mouseLoc = NSEvent.mouseLocation
        let currentScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main
        
        if let screen = currentScreen {
            let x = mouseLoc.x - (width / 2)
            let y = screen.visibleFrame.maxY - newHeight - 8
            panel.setFrame(NSRect(x: x, y: y, width: width, height: newHeight), display: true)
        }
        
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.level = .popUpMenu 
        panel.makeKeyAndOrderFront(nil)
    }

    func hidePopover() {
        if let panel = popoverPanel, panel.isVisible {
             // Посылаем сигнал follower'у (tray) о том что окно закрыто
             IpcRouter.shared.routeMessage(from: "native", target: "role:tray", method: "miniClosed_native", payload: nil)
        }
        popoverPanel?.orderOut(nil)
        popupLastCloseTime = Date()
    }

    // Обработчик нативных команд, не покрываемых подписками (show, hide, updateTray)
    func handleNativeCommand(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "show":
            self.showPopover()
            result(nil)
        case "hide":
            self.hidePopover()
            result(nil)
        case "toggle":
            self.togglePopover(nil)
            result(nil)
        case "checkForUpdates":
            self.updaterController?.checkForUpdates(nil)
            result(nil)
        case "focusMainWindow":
            self.focusMainWindow()
            result(nil)
        case "updateTray":
            if let args = call.arguments as? [String: Any] {
                if let title = args["title"] as? String {
                    if title.isEmpty {
                        self.statusItem.length = NSStatusItem.variableLength
                        self.statusItem.button?.title = ""
                    } else {
                        let parts = title.components(separatedBy: " - ")
                        var displayTitle: String
                        if parts.count >= 2 {
                            let projectName = parts[0].trimmingCharacters(in: .whitespaces)
                            let taskName = parts.dropFirst().joined(separator: " - ").trimmingCharacters(in: .whitespaces)
                            
                            if !projectName.isEmpty && !taskName.isEmpty {
                                displayTitle = " \(taskName) • \(projectName)"
                            } else if !taskName.isEmpty {
                                displayTitle = " \(taskName)"
                            } else if !projectName.isEmpty {
                                displayTitle = " \(projectName)"
                            } else {
                                displayTitle = " Session Active"
                            }
                        } else {
                            let trimmed = title.trimmingCharacters(in: .whitespaces)
                            displayTitle = trimmed.isEmpty ? " Session Active" : " \(trimmed)"
                        }
                        
                        self.statusItem.button?.title = displayTitle
                        self.statusItem.button?.lineBreakMode = .byTruncatingTail
                        
                        let font = self.statusItem.button?.font ?? NSFont.systemFont(ofSize: 13)
                        let size = (displayTitle as NSString).size(withAttributes: [.font: font])
                        let requiredWidth = size.width + 34 // 18 for icon + ~16 for padding/margins
                        
                        if requiredWidth > 160 {
                            self.statusItem.length = 160
                        } else {
                            self.statusItem.length = NSStatusItem.variableLength
                        }
                    }
                }
                if let iconName = args["icon"] as? String {
                    if iconName == "AppIconRunning" || iconName == "AppIconRunningDev" {
                        let pngName = iconName == "AppIconRunningDev" ? "app_icon_running_dev" : "app_icon_running"
                        if let imagePath = Bundle.main.path(forResource: pngName, ofType: "png", inDirectory: "flutter_assets/assets") {
                            self.statusItem.button?.image = NSImage(contentsOfFile: imagePath)
                        } else {
                            if #available(macOS 11.0, *) {
                                let img = NSImage(systemSymbolName: "record.circle.fill", accessibilityDescription: "Recording")
                                // Do NOT set isTemplate to true, otherwise it loses its color (red)
                                self.statusItem.button?.image = img
                            } else {
                                self.statusItem.button?.image = NSImage(named: "AppIcon")
                            }
                        }
                    } else {
                        self.statusItem.button?.image = NSImage(named: iconName)
                    }
                    self.statusItem.button?.image?.size = NSSize(width: 18, height: 18)
                }
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    func focusMainWindow() {
        if let window = NSApplication.shared.windows.first(where: { $0 is MainFlutterWindow }) {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate(ignoringOtherApps: true)
        }
    }

    override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    override func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            focusMainWindow()
        }
        return true
    }
}

class IdleMonitor {
    static let shared = IdleMonitor()

    private var channels: [FlutterMethodChannel] = []
    private var timer: Timer?
    private var isMonitoring = false
    private var idleThreshold: TimeInterval = 600 // 10 minutes default
    private var thresholdReached = false

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "worklog_studio/idle_monitor", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "start":
                if let args = call.arguments as? [String: Any] {
                    if let threshold = args["thresholdSeconds"] as? NSNumber {
                        self?.idleThreshold = threshold.doubleValue
                    } else if let threshold = args["thresholdSeconds"] as? Double {
                        self?.idleThreshold = threshold
                    }
                }
                self?.startMonitoring()
                result(nil)
            case "stop":
                self?.stopMonitoring()
                result(nil)
            case "getIdleTime":
                result(self?.getIdleTime() ?? 0)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        channels.append(channel)
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        thresholdReached = false
        
        timer?.invalidate()
        
        let newTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.checkIdleTime()
        }
        RunLoop.main.add(newTimer, forMode: .common)
        self.timer = newTimer
    }

    private func stopMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        thresholdReached = false
    }

    private func checkIdleTime() {
        let idleTime = getIdleTime()
        
        if idleTime >= idleThreshold {
            if !thresholdReached {
                thresholdReached = true
                for channel in channels {
                    channel.invokeMethod("onIdleThresholdReached", arguments: [
                        "idleSeconds": idleTime,
                        "timestamp": Int(Date().timeIntervalSince1970 * 1000)
                    ])
                }
                print("IdleMonitor: threshold reached (\(idleTime)s)")
            }
        } else {
            if thresholdReached {
                thresholdReached = false
                print("IdleMonitor: user returned")
            }
        }
    }

    private func getIdleTime() -> TimeInterval {
        let mouseIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .mouseMoved
        )

        let keyboardIdle = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: .keyDown
        )

        return min(mouseIdle, keyboardIdle)
    }
}

