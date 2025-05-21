import Foundation

// This class has high cyclomatic complexity intentionally
class DateFormatterHelper {
    
    enum DateFormat {
        case short
        case medium
        case long
        case iso8601
        case custom(String)
    }
    
    enum TimeZoneOption {
        case local
        case utc
        case custom(TimeZone)
    }
    
    static func formatDate(_ date: Date?, format: DateFormat, includeTime: Bool = true, timeZone: TimeZoneOption = .local, locale: Locale = .current) -> String {
        guard let date = date else { return "N/A" }
        
        let formatter = DateFormatter()
        formatter.locale = locale
        
        // Set time zone
        switch timeZone {
        case .local:
            formatter.timeZone = TimeZone.current
        case .utc:
            formatter.timeZone = TimeZone(abbreviation: "UTC")
        case .custom(let customTimeZone):
            formatter.timeZone = customTimeZone
        }
        
        // Set date format
        switch format {
        case .short:
            formatter.dateStyle = .short
            if includeTime {
                formatter.timeStyle = .short
            } else {
                formatter.timeStyle = .none
            }
        case .medium:
            formatter.dateStyle = .medium
            if includeTime {
                formatter.timeStyle = .medium
            } else {
                formatter.timeStyle = .none
            }
        case .long:
            formatter.dateStyle = .long
            if includeTime {
                formatter.timeStyle = .long
            } else {
                formatter.timeStyle = .none
            }
        case .iso8601:
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
            formatter.timeZone = TimeZone(abbreviation: "UTC")
        case .custom(let customFormat):
            formatter.dateFormat = customFormat
        }
        
        return formatter.string(from: date)
    }
    
    // Intentionally complex and long method for testing cyclomatic complexity
    static func differenceFromToday(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            if years == 1 {
                return "1 year ago"
            } else {
                return "\(years) years ago"
            }
        }
        
        if let months = components.month, months > 0 {
            if months == 1 {
                return "1 month ago"
            } else {
                return "\(months) months ago"
            }
        }
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "Yesterday"
            } else if days < 7 {
                return "\(days) days ago"
            } else {
                let weeks = days / 7
                if weeks == 1 {
                    return "1 week ago"
                } else {
                    return "\(weeks) weeks ago"
                }
            }
        }
        
        if let hours = components.hour, hours > 0 {
            if hours == 1 {
                return "1 hour ago"
            } else {
                return "\(hours) hours ago"
            }
        }
        
        if let minutes = components.minute, minutes > 0 {
            if minutes == 1 {
                return "1 minute ago"
            } else {
                return "\(minutes) minutes ago"
            }
        }
        
        return "Just now"
    }
    
    // TODO: Add timezone conversion utilities
} 