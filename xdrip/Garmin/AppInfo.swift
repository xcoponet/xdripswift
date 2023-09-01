//
//  AppInfo.swift
//  xdrip
//
//  Created by xavier coponet on 31/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import Foundation
import ConnectIQ

class AppInfo: NSObject, ObservableObject {
    
    var name: String = ""
    var app: IQApp = IQApp()
    @Published var status: IQAppStatus?
    
    convenience init(name: String, iqApp app: IQApp) {
        self.init()
        self.name = name
        self.app = app
        self.status = nil
        getStatus()
    }
    
    convenience init(name: String, iqApp app: IQApp, status: IQAppStatus) {
        self.init()
        self.name = name
        self.app = app
        self.status = status
    }
    
    func getStatus() {
        ConnectIQ.sharedInstance().getAppStatus(self.app, completion: { (appStatus: IQAppStatus?) in
            self.status = IQAppStatus()
        })
    }


    func updateStatus(withCompletion completion: @escaping (_ appInfo: AppInfo) -> Void) {
        print("\(app.device.friendlyName) \(app.uuid)");
        ConnectIQ.sharedInstance().getAppStatus(self.app, completion: { (appStatus: IQAppStatus?) in
            self.status = appStatus
            
            print("Status \(String(describing: appStatus))")
            completion(self)
        })
    }
}

