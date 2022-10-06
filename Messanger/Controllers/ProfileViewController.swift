//
//  ProfileViewController.swift
//  Messanger
//
//  Created by Alex on 28/09/2022.
//

import UIKit
import FirebaseAuth
import FBSDKLoginKit
import GoogleSignIn
import JGProgressHUD
import SDWebImage

final class ProfileViewController: UIViewController {
    @IBOutlet var tableView: UITableView!
    private let spinner = JGProgressHUD(style: .dark)
    var data = [ProfileViewModel]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(ProfileTableViewCell.self, forCellReuseIdentifier: ProfileTableViewCell.identifier)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        tableView.tableHeaderView = createTableheader()
        data.removeAll()
        data.append(ProfileViewModel(viewModelType: .info, title: "Name: \(UserDefaults.standard.value(forKey: "name") as? String ?? "No Name")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .info, title: "Email: \(UserDefaults.standard.value(forKey: "email") as? String ?? "No Email")", handler: nil))
        data.append(ProfileViewModel(viewModelType: .logout, title: "Log Out", handler: { [weak self] in
            guard let strongSelf = self else {
                return
            }
            let alert = UIAlertController(title: "Confirmation", message: "Do you really want to log out?", preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Log Out", style: .destructive, handler: { _ in
                FBSDKLoginKit.LoginManager().logOut()
                GIDSignIn.sharedInstance.signOut()
                do {
                    try FirebaseAuth.Auth.auth().signOut()
                    let vc = LoginViewController()
                    let nav = UINavigationController(rootViewController: vc)
                    nav.modalPresentationStyle = .fullScreen
                    if #available(iOS 15, *) {
                        let appearance = UINavigationBarAppearance()
                        appearance.titleTextAttributes = [
                            .foregroundColor : UIColor.label]
                        nav.navigationBar.standardAppearance = appearance;
                        nav.navigationBar.scrollEdgeAppearance = appearance
                    }
                    strongSelf.present(nav, animated: true)
                }catch {
                    print("Failed to log out \(error)")
                }
            }))
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            strongSelf.present(alert, animated: true)
        }))
        tableView.reloadData()
    }

    func createTableheader() -> UIView? {
        guard let email = UserDefaults.standard.value(forKey: "email") as? String else {
            return nil
        }
        let safeEmail = DatabaseManager.safeEmail(emailAddress: email)
        let fileName = safeEmail + "_profile_picture.png"
        let path = "images/" + fileName
        let headerView = UIView(frame: CGRect(x: 0, y: 0, width: self.view.width, height: 300))
        headerView.backgroundColor = .link
        let imageView = UIImageView(frame: CGRect(x: (headerView.width - 150) / 2, y: 75, width: 150, height: 150))
        imageView.backgroundColor = .white
        imageView.contentMode = .scaleAspectFill
        imageView.layer.borderColor = UIColor.white.cgColor
        imageView.layer.borderWidth = 3
        imageView.layer.masksToBounds = true
        imageView.layer.cornerRadius = imageView.width / 2
        headerView.addSubview(imageView)
        spinner.show(in: imageView)
        StorageManager.shared.downoadURL(for: path) { [weak self] result in
            switch result {
            case .success(let url):
                imageView.sd_setImage(with: url) { _, _, _, _ in
                    self?.spinner.dismiss(animated: true)
                }
            case .failure(let error):
                self?.spinner.dismiss(animated: true)
                print("Failed to get dowload url \(error)")
            }
        }
        return headerView
    }
}


extension ProfileViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ProfileTableViewCell.identifier, for: indexPath) as! ProfileTableViewCell
        let viewModel = data[indexPath.row]
        cell.setUp(with: viewModel)
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        data[indexPath.row].handler?()
    }
}

class ProfileTableViewCell: UITableViewCell {
    static let identifier = "ProfileTableViewCell"
    public func setUp(with viewModel: ProfileViewModel) {
        textLabel?.text = viewModel.title
        switch viewModel.viewModelType {
        case .info:
            textLabel?.textAlignment = .left
            isUserInteractionEnabled = false
        case .logout:
            textLabel?.textColor = .red
            textLabel?.textAlignment = .center
        }
    }
}
