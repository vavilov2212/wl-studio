import Foundation
import CoreGraphics
import FlutterMacOS

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
        
        // Use main RunLoop for timer
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
                // User came back (future feature: userReturned)
                thresholdReached = false
                print("IdleMonitor: user returned")
            }
        }
    }

    private func getIdleTime() -> TimeInterval {
        return CGEventSourceSecondsSinceLastEventType(.hidSystemState, .anyInput)
    }
}
