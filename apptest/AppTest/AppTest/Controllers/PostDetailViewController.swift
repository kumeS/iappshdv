import UIKit
import SnapKit
import Kingfisher

class PostDetailViewController: UIViewController {
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    
    private let titleLabel = UILabel()
    private let authorImageView = UIImageView()
    private let authorNameLabel = UILabel()
    private let dateLabel = UILabel()
    private let contentLabel = UILabel()
    private let likeButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    
    private let post: Post
    
    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Post"
        view.backgroundColor = .white
        
        setupViews()
        configureWithPost()
    }
    
    private func setupViews() {
        // Scroll view
        view.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        // Content view
        scrollView.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(view)
        }
        
        // Title
        contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        titleLabel.font = UIFont.boldSystemFont(ofSize: 22)
        titleLabel.numberOfLines = 0
        
        // Author image
        contentView.addSubview(authorImageView)
        authorImageView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.width.height.equalTo(40)
        }
        authorImageView.layer.cornerRadius = 20
        authorImageView.layer.masksToBounds = true
        authorImageView.backgroundColor = .lightGray
        
        // Author name
        contentView.addSubview(authorNameLabel)
        authorNameLabel.snp.makeConstraints { make in
            make.top.equalTo(authorImageView)
            make.leading.equalTo(authorImageView.snp.trailing).offset(10)
        }
        authorNameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        
        // Date label
        contentView.addSubview(dateLabel)
        dateLabel.snp.makeConstraints { make in
            make.top.equalTo(authorNameLabel.snp.bottom).offset(4)
            make.leading.equalTo(authorNameLabel)
        }
        dateLabel.font = UIFont.systemFont(ofSize: 14)
        dateLabel.textColor = .gray
        
        // Content label
        contentView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.top.equalTo(authorImageView.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
        }
        contentLabel.font = UIFont.systemFont(ofSize: 16)
        contentLabel.numberOfLines = 0
        
        // Button stack
        let stackView = UIStackView()
        contentView.addSubview(stackView)
        stackView.snp.makeConstraints { make in
            make.top.equalTo(contentLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().inset(20)
        }
        stackView.axis = .horizontal
        stackView.spacing = 20
        
        // Like button
        likeButton.setTitle("Like", for: .normal)
        likeButton.setImage(UIImage(systemName: "heart"), for: .normal)
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        
        // Comment button
        commentButton.setTitle("Comment", for: .normal)
        commentButton.setImage(UIImage(systemName: "message"), for: .normal)
        commentButton.addTarget(self, action: #selector(commentTapped), for: .touchUpInside)
        
        // Share button
        shareButton.setTitle("Share", for: .normal)
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        
        stackView.addArrangedSubview(likeButton)
        stackView.addArrangedSubview(commentButton)
        stackView.addArrangedSubview(shareButton)
    }
    
    private func configureWithPost() {
        titleLabel.text = post.title
        contentLabel.text = post.content
        dateLabel.text = DateFormatterHelper.formatDate(post.createdAt, format: .medium)
        
        // Dummy data
        authorNameLabel.text = "User \(post.authorId)"
        likeButton.setTitle("Like (\(post.likes))", for: .normal)
        commentButton.setTitle("Comment (\(post.comments))", for: .normal)
        
        // Dummy author image URL
        let authorImageURL = URL(string: "https://example.com/users/\(post.authorId)/avatar")
        authorImageView.kf.setImage(with: authorImageURL, placeholder: UIImage(systemName: "person.circle"))
    }
    
    @objc private func likeTapped() {
        // TODO: Implement like functionality
        print("Like tapped for post: \(post.id)")
    }
    
    @objc private func commentTapped() {
        // TODO: Implement comment functionality
        print("Comment tapped for post: \(post.id)")
    }
    
    @objc private func shareTapped() {
        // TODO: Implement share functionality
        print("Share tapped for post: \(post.id)")
    }
} 