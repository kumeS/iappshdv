import Foundation

struct Post: Codable {
    let id: Int
    let title: String
    let content: String
    let authorId: Int
    let createdAt: Date
    let updatedAt: Date?
    var likes: Int
    var comments: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, likes, comments
        case authorId = "author_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Intentionally poor code style for testing
    func isLikedByCurrentUser()->Bool{
        // This is a dummy implementation
        return false
    }
    
    // Intentionally duplicate code from User.swift for testing
    func formatCreationDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    func formatLastUpdateDate() -> String {
        guard let date = updatedAt else { return "Never updated" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // TODO: Add content validation logic
    // FIXME: Handle null authorId case
} 