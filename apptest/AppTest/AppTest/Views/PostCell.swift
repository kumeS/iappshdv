import UIKit
import SnapKit
import Kingfisher

class PostCell: UITableViewCell {
    
    private let titleLabel = UILabel()
    private let contentLabel = UILabel()
    private let dateLabel = UILabel()
    private let authorImageView = UIImageView()
    private let likesLabel = UILabel()
    private let commentsLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Author image
        contentView.addSubview(authorImageView)
        authorImageView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(12)
            make.width.height.equalTo(40)
        }
        authorImageView.layer.cornerRadius = 20
        authorImageView.layer.masksToBounds = true
        authorImageView.backgroundColor = .lightGray
        
        // Title
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(authorImageView.snp.trailing).offset(12)
            make.trailing.equalToSuperview().inset(12)
        }
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        // Content
        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(8)
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().inset(12)
        }
        contentLabel.numberOfLines = 3
        contentLabel.font = UIFont.systemFont(ofSize: 14)
        
        // Date
        contentView.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(8)
            make.leading.equalTo(titleLabel)
        }
        dateLabel.font = UIFont.systemFont(ofSize: 12)
        dateLabel.textColor = .gray
        
        // Likes
        contentView.addSubview(likesLabel)
        likesLabel.snp.makeConstraints { make in
            make.top.equalTo(dateLabel)
            make.leading.equalTo(dateLabel.snp.trailing).offset(12)
        }
        likesLabel.font = UIFont.systemFont(ofSize: 12)
        likesLabel.textColor = .gray
        
        // Comments
        contentView.addSubview(commentsLabel)
        commentsLabel.snp.makeConstraints { make in
            make.top.equalTo(dateLabel)
            make.leading.equalTo(likesLabel.snp.trailing).offset(12)
            make.bottom.equalToSuperview().inset(12)
        }
        commentsLabel.font = UIFont.systemFont(ofSize: 12)
        commentsLabel.textColor = .gray
    }
    
    func configure(with post: Post) {
        titleLabel.text = post.title
        contentLabel.text = post.content
        dateLabel.text = DateFormatterHelper.formatDate(post.createdAt, format: .short)
        likesLabel.text = "❤️ \(post.likes)"
        commentsLabel.text = "💬 \(post.comments)"
        
        // Dummy author image URL for testing
        let authorImageURL = URL(string: "https://example.com/users/\(post.authorId)/avatar")
        authorImageView.kf.setImage(with: authorImageURL, placeholder: UIImage(systemName: "person.circle"))
    }
} 