import UIKit
import SnapKit

protocol NewPostDelegate: AnyObject {
    func didCreateNewPost(_ post: Post)
}

class NewPostViewController: UIViewController {
    
    private let titleTextField = UITextField()
    private let contentTextView = UITextView()
    private let submitButton = UIButton(type: .system)
    
    weak var delegate: NewPostDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "New Post"
        setupViews()
        setupNavigation()
    }
    
    private func setupViews() {
        view.backgroundColor = .white
        
        // Title text field
        view.addSubview(titleTextField)
        titleTextField.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(50)
        }
        titleTextField.placeholder = "Title"
        titleTextField.borderStyle = .roundedRect
        
        // Content text view
        view.addSubview(contentTextView)
        contentTextView.snp.makeConstraints { make in
            make.top.equalTo(titleTextField.snp.bottom).offset(20)
            make.leading.trailing.equalToSuperview().inset(20)
            make.height.equalTo(200)
        }
        contentTextView.layer.borderWidth = 0.5
        contentTextView.layer.borderColor = UIColor.lightGray.cgColor
        contentTextView.layer.cornerRadius = 5
        contentTextView.font = UIFont.systemFont(ofSize: 16)
        
        // Submit button
        view.addSubview(submitButton)
        submitButton.snp.makeConstraints { make in
            make.top.equalTo(contentTextView.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
            make.width.equalTo(200)
            make.height.equalTo(50)
        }
        submitButton.setTitle("Submit", for: .normal)
        submitButton.backgroundColor = .systemBlue
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.layer.cornerRadius = 10
        submitButton.addTarget(self, action: #selector(submitPost), for: .touchUpInside)
    }
    
    private func setupNavigation() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    // Intentionally complicated code for testing
    @objc private func submitPost() {
        guard let title = titleTextField.text, !title.isEmpty else {
            showError("Please enter a title")
            return
        }
        
        guard let content = contentTextView.text, !content.isEmpty else {
            showError("Please enter some content")
            return
        }
        
        // Duplicate code block for testing
        if title.count < 3 {
            showError("Title must be at least 3 characters")
            return
        }
        
        if content.count < 10 {
            showError("Content must be at least 10 characters")
            return
        }
        
        // Create a mock post
        let post = Post(
            id: Int.random(in: 1000...9999),
            title: title,
            content: content,
            authorId: 1, // Assuming current user id is 1
            createdAt: Date(),
            updatedAt: nil,
            likes: 0,
            comments: 0
        )
        
        // Simulate network delay
        submitButton.isEnabled = false
        submitButton.setTitle("Submitting...", for: .normal)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self = self else { return }
            
            self.delegate?.didCreateNewPost(post)
            self.dismiss(animated: true)
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
} 