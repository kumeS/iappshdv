import UIKit
import SnapKit
import Alamofire

class MainViewController: UIViewController {
    
    private let tableView = UITableView()
    private var posts: [Post] = []
    private let refreshControl = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Feed"
        setupViews()
        fetchPosts()
    }
    
    private func setupViews() {
        view.backgroundColor = .white
        
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PostCell.self, forCellReuseIdentifier: "PostCell")
        
        refreshControl.addTarget(self, action: #selector(refreshData), for: .valueChanged)
        tableView.refreshControl = refreshControl
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewPost))
    }
    
    @objc private func refreshData() {
        fetchPosts()
    }
    
    @objc private func addNewPost() {
        let newPostVC = NewPostViewController()
        newPostVC.delegate = self
        let navController = UINavigationController(rootViewController: newPostVC)
        present(navController, animated: true)
    }
    
    // Intentionally inefficient API call for testing
    private func fetchPosts() {
        refreshControl.beginRefreshing()
        
        // Dummy API URL
        let url = "https://api.example.com/posts"
        
        AF.request(url).responseDecodable(of: [Post].self) { [weak self] response in
            guard let self = self else { return }
            
            self.refreshControl.endRefreshing()
            
            switch response.result {
            case .success(let posts):
                self.posts = posts
                self.tableView.reloadData()
            case .failure(let error):
                print("Error fetching posts: \(error)")
                // TODO: Show error alert
            }
        }
    }
}

// MARK: - UITableViewDelegate & UITableViewDataSource
extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "PostCell", for: indexPath) as? PostCell else {
            return UITableViewCell()
        }
        
        let post = posts[indexPath.row]
        cell.configure(with: post)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let post = posts[indexPath.row]
        let detailVC = PostDetailViewController(post: post)
        navigationController?.pushViewController(detailVC, animated: true)
    }
}

// MARK: - NewPostDelegate
extension MainViewController: NewPostDelegate {
    func didCreateNewPost(_ post: Post) {
        posts.insert(post, at: 0)
        tableView.reloadData()
    }
} 