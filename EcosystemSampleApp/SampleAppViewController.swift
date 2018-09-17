//  ViewController.swift
//  EcosystemSampleApp
//
//  Created by Elazar Yifrach on 14/02/2018.
//  Copyright © 2018 Kik Interactive. All rights reserved.
//

import UIKit
import KinDevPlatform
import JWT

class SampleAppViewController: UIViewController, UITextFieldDelegate {
    
    
    @IBOutlet weak var continueButton: UIButton!
    @IBOutlet weak var currentUserLabel: UILabel!
    @IBOutlet weak var newUserButton: UIButton!
    @IBOutlet weak var spendIndicator: UIActivityIndicatorView!
    @IBOutlet weak var buyStickerButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    
    let environment: Environment = .playground
    let localIp : String = "10.4.58.21"
    
    var appKey: String? {
        return configValue(for: "appKey", of: String.self)
    }
    
    var appId: String? {
        return configValue(for: "appId", of: String.self)
    }
    
    var useJWT: Bool {
        return configValue(for: "IS_JWT_REGISTRATION", of: Bool.self) ?? false
    }
    
    var privateKey: String? {
        return configValue(for: "RS512_PRIVATE_KEY", of: String.self)
    }
    
    var lastUser: String {
        get {
            if let user = UserDefaults.standard.string(forKey: "SALastUser") {
                return user
            }
            let first = "user_\(arc4random_uniform(99999))_0"
            UserDefaults.standard.set(first, forKey: "SALastUser")
            return first
        }
    }
    
    func configValue<T>(for key: String, of type: T.Type) -> T? {
        if  let path = Bundle.main.path(forResource: "defaultConfig", ofType: "plist"),
            let value = NSDictionary(contentsOfFile: path)?[key] as? T {
            return value
        }
        return nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        currentUserLabel.text = lastUser
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        titleLabel.text = "\(version) (\(build))"
    }
    
    func alertConfigIssue() {
        let alert = UIAlertController(title: "Config Missing", message: "an app id and app key (or a jwt) is required in order to use the sample app. Please refer to the readme in the sample app repo for more information", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { [weak alert] action in
            alert?.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func newUserTapped(_ sender: Any) {
        
        let numberIndex = lastUser.index(after: lastUser.range(of: "_", options: [.backwards])!.lowerBound)
        let plusone = Int(lastUser.suffix(from: numberIndex))! + 1
        let newUser = String(lastUser.prefix(upTo: numberIndex) + "\(plusone)")
        UserDefaults.standard.set(newUser, forKey: "SALastUser")
        currentUserLabel.text = lastUser
        let alert = UIAlertController(title: "Please Restart", message: "A new user was created.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { action in
            exit(0)
        }))
        self.present(alert, animated: true, completion: nil)
        
    }
    
    @IBAction func continueTapped(_ sender: Any) {
        guard let id = appId else {
            alertConfigIssue()
            return
        }
        
        if useJWT {
            do {
                try jwtLoginWith(lastUser, id: id)
            } catch {
                alertStartError(error)
            }
        } else {
            guard let key = appKey else {
                alertConfigIssue()
                return
            }
            do {
                try Kin.shared.start(userId: lastUser, apiKey: key, appId: id, environment: environment)
            } catch {
                alertStartError(error)
            }
            
        }
        
        let offer = NativeOffer(id: "wowowo12345",
                                title: "Renovate!",
                                description: "Your new home",
                                amount: 1000,
                                image: "https://www.makorrishon.co.il/nrg/images/archive/300x225/270/557.jpg",
                                isModal: true)
        do {
            try Kin.shared.add(nativeOffer: offer)
        } catch {
            print("failed to add native offer, error: \(error)")
        }
        Kin.shared.nativeOfferHandler = { offer in
            DispatchQueue.main.async {
                let alert = UIAlertController(title: "Native Offer", message: "You tapped a native offer and the handler was invoked.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                    alert?.dismiss(animated: true, completion: nil)
                }))
                
                let presentor = self.presentedViewController ?? self
                presentor.present(alert, animated: true, completion: nil)
            }
        }
        Kin.shared.launchMarketplace(from: self)
    }
    
    fileprivate func requestJWT(_ user: String, request : String, completion: @escaping (_ jwt : String) -> ()) {
        let url = URL(string: "http://\(localIp):3002\(request)")!
        
        let task = URLSession.shared.dataTask(with: url) {(data, response, error) in
            guard let data = data else { return }
            print(String(data: data, encoding: .utf8)!)
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: String]
                if let jwt = json["jwt"] as? String {
                    print("generated jwt = " + jwt)
                    completion(jwt)
                }
            } catch {
                print(error)
            }
        }
        
        task.resume()
    }
    
    func jwtLoginWith(_ user: String, id: String) throws {
        
        guard  let jwtPKey = privateKey else {
            alertConfigIssue()
            return
        }
        
        requestJWT(user, request : "/register/token?user_id=\(user)") { jwt in
            do {
                try Kin.shared.start(userId: user, jwt: jwt, environment: self.environment)
            }
            catch {
                print (error)
            }
        }
    }
    
    fileprivate func alertStartError(_ error: Error) {
        let alert = UIAlertController(title: "Start failed", message: "Error: \(error)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Oh ok", style: .cancel, handler: { [weak alert] action in
            alert?.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    fileprivate func jsonToData(json : Any) -> Data? {
        if JSONSerialization.isValidJSONObject(json) { // True
            do {
                return try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            } catch {
                print("spend JSONSerialization error" + "\(error)")
            }
        }
        return nil
    }
    
    fileprivate func signJWT(_ signData : Data,completion: @escaping (_ jwt : String) -> ()) {
        let endpoint = URL(string: "http://\(localIp):3002/sign")
        var request = URLRequest(url: endpoint!)
        request.httpMethod = "POST"
        request.httpBody = signData
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        let task = URLSession.shared.dataTask(with: request) {(data, response, error) in
            guard let data = data else { return }
            print(String(data: data, encoding: .utf8)!)
            
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: String]
                if let jwt = json["jwt"] as? String {
                    print("generated jwt = " + jwt)
                    completion(jwt)
                }
            } catch {
                print(error)
            }
        }
        task.resume()
    }
    
    @IBAction func buyStickerTapped(_ sender: Any) {
        
        guard   let id = appId,
            let jwtPKey = privateKey else {
                alertConfigIssue()
                return
        }
        do {
            try jwtLoginWith(lastUser, id: id)
        } catch {
            alertStartError(error)
        }
        let offerID = "WOWOMGCRAZY"+"\(arc4random_uniform(999999))"
        
        let spendOffer = [
            "subject" : "spend",
            "payload" : [
                "offer" : [
                    "id" : offerID,
                    "amount" : 10
                ],
                "sender" : [
                    "user_id" : lastUser,
                    "title" : "Native Spend",
                    "description" : "A native spend example"
                ]
            ],
            ] as [String : Any]
        
        self.buyStickerButton.isEnabled = false
        self.spendIndicator.startAnimating()
        
        let requestData = jsonToData(json: spendOffer)
        if (requestData != nil) {
            signJWT(requestData!){ jwt in
                _ = Kin.shared.purchase(offerJWT: jwt) { jwtConfirmation, error in
                    DispatchQueue.main.async { [weak self] in
                        self?.buyStickerButton.isEnabled = true
                        self?.spendIndicator.stopAnimating()
                        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                        if let confirm = jwtConfirmation {
                            alert.title = "Success"
                            alert.message = "Purchase complete. You can view the confirmation on jwt.io"
                            alert.addAction(UIAlertAction(title: "View on jwt.io", style: .default, handler: { [weak alert] action in
                                UIApplication.shared.openURL(URL(string:"https://jwt.io/#debugger-io?token=\(confirm)")!)
                                alert?.dismiss(animated: true, completion: nil)
                            }))
                        } else if let e = error {
                            alert.title = "Failure"
                            alert.message = "Purchase failed (\(e.localizedDescription))"
                        }
                        
                        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                            alert?.dismiss(animated: true, completion: nil)
                        }))
                        
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
    
    @IBAction func payToUserTapped(_ sender: Any) {
        
        let receipientUserId = "03b9f2e5-3783-49a9-a793-5a44fcaf90da"
        let amount = 10
        
        guard let appId = appId, let jwtPKey = privateKey else {
            alertConfigIssue()
            return
        }
        
        do {
            try jwtLoginWith(lastUser, id: appId)
        } catch {
            alertStartError(error)
        }
        
        let offerID = "WOWOMGCRAZY"+"\(arc4random_uniform(999999))"
        
        let payToUserOffer = [
            "subject" : "pay_to_user",
            "payload" : [
                "offer" : [
                    "id" : offerID,
                    "amount" : amount
                ],
                "sender" : [
                    "user_id" : lastUser,
                    "title" : "Pay To User",
                    "description" : "A P2P example"
                ],
                "recipient": [
                    "user_id": receipientUserId,
                    "title": "Received Kin",
                    "description": "A P2P example"
                ]
            ],
            ] as [String : Any]
        
        spendIndicator.startAnimating()
        
        let requestData = jsonToData(json: payToUserOffer)
        if (requestData != nil) {
            signJWT(requestData!){ jwt in
                _ = Kin.shared.payToUser(offerJWT: jwt) { jwtConfirmation, error in
                    DispatchQueue.main.async { [weak self] in
                        self?.buyStickerButton.isEnabled = true
                        self?.spendIndicator.stopAnimating()
                        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                        if let confirm = jwtConfirmation {
                            alert.title = "Pay To User - Success"
                            alert.message = "You sent to: \(receipientUserId)\nAmount: \(amount)\nYou can view the confirmation on jwt.io"
                            alert.addAction(UIAlertAction(title: "View on jwt.io", style: .default, handler: { [weak alert] action in
                                UIApplication.shared.openURL(URL(string:"https://jwt.io/#debugger-io?token=\(confirm)")!)
                                alert?.dismiss(animated: true, completion: nil)
                            }))
                        } else if let e = error {
                            alert.title = "Failure"
                            alert.message = "Pay To User failed: (\(e.localizedDescription))"
                        }
                        
                        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                            alert?.dismiss(animated: true, completion: nil)
                        }))
                        
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
        
    }
    
    @IBAction func nativeEarnTapped(_ sender: Any) {
        
        let amount = 10
        let offerID = "WOWOMGCRAZY"+"\(arc4random_uniform(999999))"
        
        guard let appId = appId, let jwtPKey = privateKey else {
            alertConfigIssue()
            return
        }
        
        do {
            try jwtLoginWith(lastUser, id: appId)
        } catch {
            alertStartError(error)
        }
        
        let earnOffer = [
            "subject" : "earn",
            "payload" : [
                "offer" : [
                    "id" : offerID,
                    "amount" : amount
                ],
                "recipient": [
                    "user_id": lastUser,
                    "title": "Received Kin",
                    "description": "Native Earn example"
                ]
            ],
            ] as [String : Any]
        
        
        spendIndicator.startAnimating()
        
        let requestData = jsonToData(json: earnOffer)
        if (requestData != nil) {
            signJWT(requestData!){ jwt in
                _ = Kin.shared.requestPayment(offerJWT: jwt) { jwtConfirmation, error in
                    DispatchQueue.main.async { [weak self] in
                        self?.buyStickerButton.isEnabled = true
                        self?.spendIndicator.stopAnimating()
                        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .alert)
                        if let confirm = jwtConfirmation {
                            alert.title = "Native Earn - Success"
                            alert.message = "Amount: \(amount)\nYou can view the confirmation on jwt.io"
                            alert.addAction(UIAlertAction(title: "View on jwt.io", style: .default, handler: { [weak alert] action in
                                UIApplication.shared.openURL(URL(string:"https://jwt.io/#debugger-io?token=\(confirm)")!)
                                alert?.dismiss(animated: true, completion: nil)
                            }))
                        } else if let e = error {
                            alert.title = "Failure"
                            alert.message = "Native Earn failed: (\(e.localizedDescription))"
                        }
                        
                        alert.addAction(UIAlertAction(title: "Close", style: .cancel, handler: { [weak alert] action in
                            alert?.dismiss(animated: true, completion: nil)
                        }))
                        
                        self?.present(alert, animated: true, completion: nil)
                    }
                }
            }
        }
    }
}

