//
//  AppDelegate.swift
//  HandGestureDetection-Ego
//
//  Created by Vasiliy Dumanov on 2/8/19.
//  Copyright © 2019 Distillery. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = RecognitionViewController(nibName: nil, bundle: nil)
        window?.makeKeyAndVisible()
        return true
    }
}

