import Foundation

struct User: Codable {
    let id: Int
    let username: String
    let email: String
    var isActive: Bool
    let createdAt: Date
    
    private var _profileImageURL: URL?
    var profileImageURL: URL? {
        get { return _profileImageURL }
        set { _profileImageURL = newValue }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, username, email
        case isActive = "is_active"
        case createdAt = "created_at"
        case _profileImageURL = "profile_image_url"
    }
    
    // Intentionally poor code style for testing
    func isValidEmail()->Bool{
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    func getDisplayName()-> String {
      return username
    }
    
    // Unused method for testing
    func formatCreationDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    // TODO: Add user permission handling
} 