//
//  TweetViewController.swift
//  Twitter
//
//  Created by Shayin Feng on 2/22/17.
//  Copyright © 2017 Shayin Feng. All rights reserved.
//

import UIKit
import ActiveLabel

class TweetViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIPopoverPresentationControllerDelegate, TweetTableViewDelegate, TweetDetailTableViewCellDelegate,  TweetButtonTableViewCellDelegate {
    
    let transform_start: CGFloat = 25.0
    let image_height: CGFloat = 30.0
    let transform_stop: CGFloat = 55.0
    
    @IBOutlet weak var logo: UIImageView!
    @IBOutlet weak var tweetTableView: UITableView!
    
    var tweet: TweetModel!
    
    var retweet: TweetModel?
    
    let uiHelper = UIhelper()
    
    var delegate: UpdateCellFromTableDelegate?
    
    let client = TwitterClient.sharedInstance!
    
    var indexPath: IndexPath!
    
    var popImage = UIImage()
    
    var postEndpoint = 3
    
    var postTweet: TweetModel?
    
    var postTweetOrg: TweetModel?

    override func viewDidLoad() {
        super.viewDidLoad()

         print(tweet?.dictionary ?? "{}")
        // Do any additional setup after loading the view.
        tweetTableView.delegate = self
        tweetTableView.dataSource = self
        
        tweetTableView.rowHeight = UITableViewAutomaticDimension
        tweetTableView.estimatedRowHeight = 60
    }
    
    override func viewWillAppear(_ animated: Bool) {
        self.automaticallyAdjustsScrollViewInsets = false
        
        self.navigationController?.navigationBar.topItem?.title = ""
        self.navigationController?.title = "Tweet"
        self.navigationItem.backBarButtonItem?.tintColor = UIhelper.UIColorOption.twitterBlue
    }
    
    override func viewWillDisappear(_ animated: Bool) {
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if indexPath.row == 0 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell0") as! TweetDetailTableViewCell
            cell.tweet = self.tweet
            if self.retweet != nil {
                print("retweet_status!")
                cell.retweet = retweet
            }
            
            /// in order to get image tapped gesture
            cell.popDelegate = self
            cell.delegate = self
            
            return cell
        }
        else if indexPath.row == 1 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell1") as! TweetCountTableViewCell
            cell.tweet = self.tweet
            return cell
        }
        else if indexPath.row == 2 {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell2") as! TweetButtonTableViewCell
            cell.tweet = self.tweet
            cell.delegate = self
            
            let diff = tweetTableView.frame.height - tweetTableView.contentSize.height
            // print("didEndEditingRowAt: \(diff)")
            if diff >= 75 {
                let footerPositionY = tweetTableView.frame.height - diff + 70
            }
            
            return cell
        }
        else {
            let cell = tableView.dequeueReusableCell(withIdentifier: "reviewCell") as! TweetTableViewCell
            cell.layoutMargins = UIEdgeInsets.zero
            cell.viewModel.tweet = self.tweet
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }
    
    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0
    }
    
    func tweetCellRetweetTapped(cell: TweetButtonTableViewCell, isRetweeted: Bool) {
        var endpoint : String?
        
        // pop up menu
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        cell.retweetButton.isEnabled = false

        let tweetid = self.tweet.id!
        var title = "Retweet"
        var style = UIAlertActionStyle.default
        
        if cell.tweet.isUserRetweeted! {
            title = "Unretweet"
            style = UIAlertActionStyle.destructive
            endpoint = TwitterClient.APIScheme.UnretweetStatusEndpoint
        } else {
            endpoint = TwitterClient.APIScheme.RetweetStatusEndpoint
        }
        
        if let range = endpoint?.range(of: ":id") {
            endpoint = endpoint?.replacingCharacters(in: range, with: "\(tweetid)")
        }
        
        let retweetAction = UIAlertAction(title: title, style: style) { (action) in
            
            cell.retweetButton.setImage(#imageLiteral(resourceName: "retweet-icon-blue"), for: .normal)
            
            self.client.post(endpoint!, parameters: nil, progress: nil, success: { (task, response) in
                print("retweet: success")
                
                var count = cell.tweet.retweetCount!
                
                if cell.tweet.isUserRetweeted! {
                    cell.retweetButton.setImage(#imageLiteral(resourceName: "retweet-icon-dark"), for: .normal)
                    count -= 1
                    cell.tweet.isUserRetweeted = false
                } else {
                    cell.retweetButton.setImage(#imageLiteral(resourceName: "retweet-icon-green"), for: .normal)
                    cell.tweet.isUserRetweeted = true
                    count += 1
                }
                cell.tweet.retweetCount = count
                self.delegate?.updateNumber(tweet: self.tweet, indexPath: self.indexPath)
                self.tweetTableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)
                
            }) { (task, error) in
                print(error)
                print("retweet: Error >>> \(error.localizedDescription)")
                cell.retweetButton.setImage(#imageLiteral(resourceName: "retweet-icon-yellow"), for: .normal)
            }
        }
        alertController.addAction(retweetAction)
        
        if !isRetweeted {
            let quoteTweetAction = UIAlertAction(title: "Quote Tweet(Unavailable)", style: .default) { (action) in
                /// handle case of quote tweet
            }
            alertController.addAction(quoteTweetAction)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        cell.retweetButton.isEnabled = true
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func tweetCellFavoritedTapped(cell: TweetButtonTableViewCell, isFavorited: Bool) {
        var endpoint : String?
        
        cell.favoriteButton.isEnabled = false
        
        cell.favoriteButton.setImage(#imageLiteral(resourceName: "favorited-icon-blue"), for: .normal)
        
        if cell.tweet.isUserFavorited! {
            endpoint = TwitterClient.APIScheme.FavoriteDestroyEndpoint
        } else {
            endpoint = TwitterClient.APIScheme.FavoriteCreateEndpoint
        }
        
        client.post(endpoint!, parameters: ["id" : cell.tweet.id!], progress: nil, success: { (task, response) in
            print("retweet: success")
            
            var count = cell.tweet.favoriteCount!
            
            if cell.tweet.isUserFavorited! {
                cell.favoriteButton.setImage(#imageLiteral(resourceName: "favorited-icon-dark"), for: .normal)
                cell.tweet.isUserFavorited = false
                count -= 1
            } else {
                cell.favoriteButton.setImage(#imageLiteral(resourceName: "favor-icon-red"), for: .normal)
                cell.tweet.isUserFavorited = true
                count += 1
            }
            
            cell.tweet.favoriteCount = count
            
            self.delegate?.updateNumber(tweet: self.tweet, indexPath: self.indexPath)
            self.tweetTableView.reloadRows(at: [IndexPath(row: 1, section: 0)], with: .none)

        }) { (task, error) in
            print("retweet: Error >>> \(error.localizedDescription)")
            cell.favoriteButton.setImage(#imageLiteral(resourceName: "favorited-icon-yellow"), for: .normal)
        }
        
        cell.favoriteButton.isEnabled = true
    }
    
    func tweetCellMenuTapped(cell: TweetDetailTableViewCell, withId id: Int) {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete Tweet", style: .destructive) { (action) in
            
            UIhelper.alertMessageWithAction("Delete Tweet", userMessage: "Are you sure you want to delete this Tweet?", left: "Cancel", right: "Delete", leftAction: nil, rightAction: { (action) in
                var endpoint = TwitterClient.APIScheme.TweetStatusDestroyEndpoint
                if let range = endpoint.range(of: ":id") {
                    endpoint = endpoint.replacingCharacters(in: range, with: "\(cell.tweet.id!)")
                }
                
                cell.client.post(endpoint, parameters: nil, progress: nil, success: { (task, response) in
                    print("Delete tweet: Success")
                    
                    /// move to previous view controller
                    self.delegate?.removeCell(indexPath: self.indexPath)
                    self.navigationController!.popToRootViewController(animated: true)
                    
                    
                }, failure: { (task, error) in
                    print("\(error.localizedDescription)")
                })
            }, sender: (UIApplication.shared.keyWindow?.rootViewController)!)
        }
        if cell.tweet.user?.id == UserModel.currentUser?.id {
            alertController.addAction(deleteAction)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        
        self.present(alertController, animated: true, completion: nil)
    }
    
    func tweetCellReplyTapped(cell: TweetButtonTableViewCell) {
        print("Reply Tapped")
        postEndpoint = 3
        postTweet = cell.tweet
        if self.retweet != nil {
            postTweetOrg = self.retweet
        }
        performSegue(withIdentifier: "toReply", sender: self)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // popover segue
        if segue.identifier == "toReply" {
            let postViewController = segue.destination as! PostViewController
            postViewController.delegate = self
            postViewController.popoverPresentationController?.delegate = self
            postViewController.endpoint = postEndpoint
            if self.postTweetOrg != nil {
                postViewController.tweetOrg = self.postTweetOrg
            }
            postViewController.tweet = self.postTweet
        }
        if segue.identifier == "detailShowImage" {
            let previewViewController = segue.destination as! PreviewViewController
            previewViewController.delegate = self
            previewViewController.popoverPresentationController?.delegate = self
            previewViewController.image = self.popImage
        }
    }
    
    func getNewTweet(data: TweetModel?) {
        postEndpoint = 3
        postTweet = nil
        postTweetOrg = nil
    }

    func getPopoverImage(imageView: UIImageView) {
        print("Pop over!")
        popImage = imageView.image!
        performSegue(withIdentifier: "detailShowImage", sender: self)
    }
}
