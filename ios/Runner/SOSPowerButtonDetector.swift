import UIKit
import Foundation
import AVFoundation

/// iOS implementation for SOS power button detection
/// Since iOS doesn't allow direct power button monitoring like Android,
/// this implementation uses alternative methods for emergency detection
class SOSPowerButtonDetector: NSObject {
    
    // MARK: - Properties
    private var powerButtonPressCount = 0
    private var resetTimer: Timer?
    private var onTriplePressCallback: (() -> Void)?
    private let triplePressTimeout: TimeInterval = 2.0
    
    // Volume button monitoring (alternative to power button)
    private var volumeView: UIView?
    private var initialVolumeLevel: Float = 0.0
    private var volumeChangeCount = 0
    private var volumeResetTimer: Timer?
    
    // App state monitoring
    private var appStateChangeCount = 0
    private var appStateResetTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupVolumeMonitoring()
        setupAppStateMonitoring()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Public Methods
    func setTriplePressCallback(_ callback: @escaping () -> Void) {
        onTriplePressCallback = callback
    }
    
    func startMonitoring() {
        print("iOS SOS: Starting power button detection monitoring")
        setupVolumeMonitoring()
        setupAppStateMonitoring()
    }
    
    func stopMonitoring() {
        print("iOS SOS: Stopping power button detection monitoring")
        cleanup()
    }
    
    // MARK: - Volume Button Monitoring (Alternative Method)
    private func setupVolumeMonitoring() {
        // Create a hidden volume view to monitor volume changes
        volumeView = UIView(frame: CGRect(x: -1000, y: -1000, width: 1, height: 1))
        
        if let volumeView = volumeView {
            // Add to a window if available
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                window.addSubview(volumeView)
            }
        }
        
        // Monitor volume changes as an alternative to power button
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(volumeChanged),
            name: NSNotification.Name(rawValue: "AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil
        )
        
        // Store initial volume level
        initialVolumeLevel = AVAudioSession.sharedInstance().outputVolume
    }
    
    @objc private func volumeChanged() {
        // Detect rapid volume button presses as emergency trigger
        volumeChangeCount += 1
        
        // Cancel previous reset timer
        volumeResetTimer?.invalidate()
        
        // Set new reset timer
        volumeResetTimer = Timer.scheduledTimer(withTimeInterval: triplePressTimeout, repeats: false) { _ in
            self.volumeChangeCount = 0
        }
        
        print("iOS SOS: Volume change detected, count: \(volumeChangeCount)")
        
        // Check for rapid volume changes (alternative emergency trigger)
        if volumeChangeCount >= 6 { // 3 up + 3 down = 6 changes
            print("iOS SOS: Rapid volume changes detected - triggering emergency!")
            triggerEmergency()
        }
    }
    
    // MARK: - App State Monitoring
    private func setupAppStateMonitoring() {
        // Monitor app state changes (background/foreground transitions)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("iOS SOS: App entered background")
        // Could be used to detect power button press patterns
    }
    
    @objc private func appWillEnterForeground() {
        print("iOS SOS: App will enter foreground")
        
        // Detect rapid app state changes
        appStateChangeCount += 1
        
        // Cancel previous reset timer
        appStateResetTimer?.invalidate()
        
        // Set new reset timer
        appStateResetTimer = Timer.scheduledTimer(withTimeInterval: triplePressTimeout, repeats: false) { _ in
            self.appStateChangeCount = 0
        }
        
        print("iOS SOS: App state change count: \(appStateChangeCount)")
        
        // Check for rapid app state changes (could indicate power button usage)
        if appStateChangeCount >= 3 {
            print("iOS SOS: Rapid app state changes detected - potential emergency trigger!")
            // Note: This is less reliable than Android's direct power button detection
            // Consider this as a secondary trigger method
        }
    }
    
    // MARK: - Emergency Trigger
    private func triggerEmergency() {
        print("iOS SOS: ===== EMERGENCY TRIGGERED! =====")
        
        // Reset counters
        volumeChangeCount = 0
        appStateChangeCount = 0
        
        // Cancel timers
        volumeResetTimer?.invalidate()
        appStateResetTimer?.invalidate()
        
        // Call the emergency callback
        onTriplePressCallback?()
        
        // Provide haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        
        // Show emergency alert
        showEmergencyAlert()
    }
    
    private func showEmergencyAlert() {
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "🚨 Emergency Alert Triggered",
                message: "SOS emergency system has been activated. Emergency contacts will be notified.",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            // Present alert on top view controller
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let topViewController = window.rootViewController {
                var presentingController = topViewController
                while let presented = presentingController.presentedViewController {
                    presentingController = presented
                }
                presentingController.present(alert, animated: true)
            }
        }
    }
    
    // MARK: - Cleanup
    private func cleanup() {
        // Remove observers
        NotificationCenter.default.removeObserver(self)
        
        // Invalidate timers
        resetTimer?.invalidate()
        volumeResetTimer?.invalidate()
        appStateResetTimer?.invalidate()
        
        // Remove volume view
        volumeView?.removeFromSuperview()
        volumeView = nil
        
        // Reset counters
        powerButtonPressCount = 0
        volumeChangeCount = 0
        appStateChangeCount = 0
    }
}

// MARK: - iOS Alternative Emergency Triggers
extension SOSPowerButtonDetector {
    
    /// Setup shake gesture as emergency trigger
    func setupShakeGesture() {
        // This would be implemented in the main view controller
        // to detect device shake as an emergency trigger
        print("iOS SOS: Shake gesture emergency trigger available")
    }
    
    /// Setup long press gesture as emergency trigger
    func setupLongPressGesture() {
        // This would be implemented in the main view controller
        // to detect long press as an emergency trigger
        print("iOS SOS: Long press emergency trigger available")
    }
    
    /// Manual emergency trigger for testing
    func manualTrigger() {
        print("iOS SOS: Manual emergency trigger activated")
        triggerEmergency()
    }
}

// MARK: - AVAudioSession Extension
extension SOSPowerButtonDetector {
    private func getCurrentVolume() -> Float {
        return AVAudioSession.sharedInstance().outputVolume
    }
}
