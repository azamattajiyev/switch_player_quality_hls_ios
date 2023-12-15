//
//  Created by Ivano Bilenchi on 24/01/17.
//  Copyright © 2017 Ivano Bilenchi. All rights reserved.
//

import UIKit
import SwiftUI

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: Private properties
    
    let factory = AppFactory()
    
    // MARK: UIApplicationDelegate

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        let window = UIWindow(frame: UIScreen.main.bounds)
        
        factory.proxy.start(withPort: AppConfig.serverPort, bonjourName: nil)
        let contentView = ContentView(factory:factory)
        window.rootViewController = UIHostingController(rootView: contentView)
//        window.rootViewController = factory.rootViewController
        window.makeKeyAndVisible()
        
        self.window = window
        
        return true
    }
}
