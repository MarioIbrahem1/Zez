import UIKit
import Foundation
import MessageUI

/// iOS implementation for SMS sending functionality
/// Provides emergency SMS capabilities for the SOS system
class IOSSMSService: NSObject {
    
    // MARK: - Properties
    private var completionHandler: ((Bool) -> Void)?
    
    // MARK: - Public Methods
    
    /// Send emergency SMS to multiple recipients
    /// - Parameters:
    ///   - phoneNumbers: Array of phone numbers to send SMS to
    ///   - message: Emergency message content
    ///   - completion: Completion handler with success status
    func sendEmergencySMS(phoneNumbers: [String], message: String, completion: @escaping (Bool) -> Void) {
        self.completionHandler = completion
        
        print("iOS SMS: Attempting to send emergency SMS to \(phoneNumbers.count) recipients")
        
        // Check if device can send SMS
        guard MFMessageComposeViewController.canSendText() else {
            print("iOS SMS: Device cannot send SMS")
            completion(false)
            return
        }
        
        // Create message composer
        let messageComposer = MFMessageComposeViewController()
        messageComposer.messageComposeDelegate = self
        
        // Set recipients
        messageComposer.recipients = phoneNumbers
        
        // Set message body
        messageComposer.body = message
        
        // Present message composer
        DispatchQueue.main.async {
            if let topViewController = self.getTopViewController() {
                topViewController.present(messageComposer, animated: true) {
                    print("iOS SMS: Message composer presented")
                }
            } else {
                print("iOS SMS: Could not find top view controller")
                completion(false)
            }
        }
    }
    
    /// Send SMS using URL scheme (alternative method)
    /// - Parameters:
    ///   - phoneNumbers: Array of phone numbers
    ///   - message: Message content
    ///   - completion: Completion handler
    func sendSMSViaURLScheme(phoneNumbers: [String], message: String, completion: @escaping (Bool) -> Void) {
        print("iOS SMS: Sending SMS via URL scheme")
        
        var urlComponents = URLComponents(string: "sms:")
        urlComponents?.queryItems = [
            URLQueryItem(name: "body", value: message)
        ]
        
        // Handle single or multiple recipients
        if phoneNumbers.count == 1 {
            urlComponents?.path = phoneNumbers[0]
        } else {
            // For multiple recipients, join with comma
            urlComponents?.path = phoneNumbers.joined(separator: ",")
        }
        
        guard let smsURL = urlComponents?.url else {
            print("iOS SMS: Could not create SMS URL")
            completion(false)
            return
        }
        
        // Check if SMS URL can be opened
        if UIApplication.shared.canOpenURL(smsURL) {
            UIApplication.shared.open(smsURL) { success in
                print("iOS SMS: SMS URL opened with success: \(success)")
                completion(success)
            }
        } else {
            print("iOS SMS: Cannot open SMS URL")
            completion(false)
        }
    }
    
    /// Format phone number for SMS
    /// - Parameter phoneNumber: Raw phone number
    /// - Returns: Formatted phone number
    private func formatPhoneNumber(_ phoneNumber: String) -> String {
        // Remove any non-digit characters except +
        var formatted = phoneNumber.replacingOccurrences(of: "[^\\d+]", with: "", options: .regularExpression)
        
        // Add country code if needed (assuming Egyptian numbers)
        if !formatted.hasPrefix("+") {
            // Remove leading zero if present
            if formatted.hasPrefix("0") {
                formatted = String(formatted.dropFirst())
            }
            // Add Egypt country code
            formatted = "+20" + formatted
        }
        
        return formatted
    }
    
    /// Get the top view controller for presenting SMS composer
    /// - Returns: Top view controller or nil
    private func getTopViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }

        var topViewController = window.rootViewController

        while let presentedViewController = topViewController?.presentedViewController {
            topViewController = presentedViewController
        }

        return topViewController
    }
    
    /// Create emergency message with location and timestamp
    /// - Parameters:
    ///   - baseMessage: Base emergency message
    ///   - location: Optional location coordinates
    /// - Returns: Enhanced emergency message
    func createEmergencyMessage(baseMessage: String, location: (latitude: Double, longitude: Double)? = nil) -> String {
        var message = baseMessage
        
        // Add timestamp
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        let timestamp = formatter.string(from: Date())
        
        message += "\n\nTime: \(timestamp)"
        
        // Add location if available
        if let location = location {
            message += "\nLocation: https://maps.google.com/?q=\(location.latitude),\(location.longitude)"
        }
        
        // Add app identifier
        message += "\n\nSent via Road Helper Emergency System"
        
        return message
    }
}

// MARK: - MFMessageComposeViewControllerDelegate
extension IOSSMSService: MFMessageComposeViewControllerDelegate {
    func messageComposeViewController(_ controller: MFMessageComposeViewController, didFinishWith result: MessageComposeResult) {
        print("iOS SMS: Message compose finished with result: \(result.rawValue)")
        
        // Dismiss the message composer
        controller.dismiss(animated: true) {
            // Call completion handler based on result
            switch result {
            case .sent:
                print("iOS SMS: Message sent successfully")
                self.completionHandler?(true)
            case .cancelled:
                print("iOS SMS: Message sending cancelled")
                self.completionHandler?(false)
            case .failed:
                print("iOS SMS: Message sending failed")
                self.completionHandler?(false)
            @unknown default:
                print("iOS SMS: Unknown message result")
                self.completionHandler?(false)
            }
            
            // Clear completion handler
            self.completionHandler = nil
        }
    }
}

// MARK: - Emergency SMS Templates
extension IOSSMSService {
    
    /// Get default emergency message template
    /// - Returns: Default emergency message
    static func getDefaultEmergencyMessage() -> String {
        return """
        🚨 EMERGENCY ALERT 🚨
        
        This is an automated emergency message from Road Helper app.
        
        I need immediate assistance. Please contact me or emergency services.
        
        This message was sent automatically due to emergency trigger.
        """
    }
    
    /// Get help request message template
    /// - Returns: Help request message
    static func getHelpRequestMessage() -> String {
        return """
        🆘 HELP REQUEST 🆘
        
        I need assistance with my vehicle or situation.
        
        Please contact me when you receive this message.
        
        Sent via Road Helper app.
        """
    }
    
    /// Get location sharing message template
    /// - Parameters:
    ///   - latitude: Location latitude
    ///   - longitude: Location longitude
    /// - Returns: Location sharing message
    static func getLocationSharingMessage(latitude: Double, longitude: Double) -> String {
        return """
        📍 LOCATION SHARING 📍
        
        I'm sharing my current location with you for safety.
        
        Location: https://maps.google.com/?q=\(latitude),\(longitude)
        
        Sent via Road Helper app.
        """
    }
}

// MARK: - SMS Validation
extension IOSSMSService {
    
    /// Validate phone number format
    /// - Parameter phoneNumber: Phone number to validate
    /// - Returns: True if valid, false otherwise
    static func isValidPhoneNumber(_ phoneNumber: String) -> Bool {
        let phoneRegex = "^[+]?[0-9]{10,15}$"
        let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        return phoneTest.evaluate(with: phoneNumber.replacingOccurrences(of: "[^\\d+]", with: "", options: .regularExpression))
    }
    
    /// Validate message content
    /// - Parameter message: Message to validate
    /// - Returns: True if valid, false otherwise
    static func isValidMessage(_ message: String) -> Bool {
        return !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && message.count <= 1600
    }
}
