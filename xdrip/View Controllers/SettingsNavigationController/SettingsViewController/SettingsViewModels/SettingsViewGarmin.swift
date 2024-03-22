//
//  SettingsViewGarmin.swift
//  xdrip
//
//  Created by xavier coponet on 31/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import UIKit
import os
import Foundation
import ConnectIQ

fileprivate enum Setting:Int, CaseIterable {
    
    ///should garmin devices recived data
    case garminEnabled = 0
    
    /// button to find the devices
    case devices = 1
    
    /// button to force send a glucose value now
    case forceSendGlucose = 2;
    
    /// button to see logs
    case logs = 3;
    
}

class SettingsViewGarminSettingsViewModel {
    
    // MARK: - properties
    
    /// in case info message or errors occur like credential check error, then this closure will be called with title and message
    /// - parameters:
    ///     - first parameter is title
    ///     - second parameter is the message
    ///
    /// the viewcontroller sets it by calling storeMessageHandler
    private var messageHandler: ((String, String) -> Void)?
    
    /// for trace
    private let log = OSLog(subsystem: ConstantsLog.subSystem, category: ConstantsLog.categoryWatchManager)
    
    // MARK: - private functions
    
    
    
    private func callMessageHandlerInMainThread(title: String, message: String) {
        
        // unwrap messageHandler
        guard let messageHandler = messageHandler else {return}
        
        DispatchQueue.main.async {
            messageHandler(title, message)
        }
        
    }
    
}

/// conforms to SettingsViewModelProtocol for all nightscout settings in the first sections screen
extension SettingsViewGarminSettingsViewModel: SettingsViewModelProtocol {
    
    func storeRowReloadClosure(rowReloadClosure: ((Int) -> Void)) {}
    
    func storeUIViewController(uIViewController: UIViewController) {}
    
    func storeMessageHandler(messageHandler: @escaping ((String, String) -> Void)) {
        self.messageHandler = messageHandler
    }
    
    func completeSettingsViewRefreshNeeded(index: Int) -> Bool {
        return false
    }
    
    func isEnabled(index: Int) -> Bool {
        return true
    }
    
    func onRowSelect(index: Int) -> SettingsSelectedRowAction {
        
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .garminEnabled:
            return SettingsSelectedRowAction.nothing
            
        case .devices:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToGarminDevices.rawValue, sender: nil);
        case .forceSendGlucose:
            return .callFunction(function: {
                NSLog("Force send glucose")
                let deviceManager = DeviceManager.sharedInstance
                
                for deviceInfo in deviceManager.devices
                {
                    if(deviceInfo.status == .connected)
                    {
                        for appInfo in deviceInfo.appInfos.values
                        {
                            if appInfo.status?.isInstalled ?? false
                            {
                                deviceInfo.sendGlucose(appInfo.app);
                            }
                        }
                    }
                }
            })
            
        case .logs:
            return .performSegue(withIdentifier: SettingsViewController.SegueIdentifiers.settingsToGarminLogs.rawValue, sender: nil);
            
        }
    }
    
    func sectionTitle() -> String? {
        return Texts_SettingsView.sectionTitleGarmin
    }
    
    func numberOfRows() -> Int {
        
        // if nightscout upload not enabled then only first row is shown
        if UserDefaults.standard.garminEnabled {
            
            return Setting.allCases.count
            
        } else {
            return 1
        }
    }
    
    func settingsRowText(index: Int) -> String {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .garminEnabled:
            return Texts_SettingsView.labelGarminEnabled
            
        case .devices:
            return "Devices"// todo settings
        case .forceSendGlucose:
            return "Force Send Glycemia"
        case .logs:
            return "Logs"
        }
    }
    
    func accessoryType(index: Int) -> UITableViewCell.AccessoryType {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .garminEnabled:
            return UITableViewCell.AccessoryType.none
        case .devices:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .forceSendGlucose:
            return UITableViewCell.AccessoryType.disclosureIndicator
        case .logs:
            return UITableViewCell.AccessoryType.disclosureIndicator
        }
    }
    
    func detailedText(index: Int) -> String? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
        case .garminEnabled:
            return nil
        case .devices:
            return nil;
        case .forceSendGlucose:
            return nil;
        case .logs:
            return nil;
        }
    }
    
    func uiView(index: Int) -> UIView? {
        guard let setting = Setting(rawValue: index) else { fatalError("Unexpected Section") }
        
        switch setting {
            
        case .garminEnabled:
            return UISwitch(isOn: UserDefaults.standard.garminEnabled, action: {(isOn:Bool) in UserDefaults.standard.garminEnabled = isOn})
            
        case .devices:
            return nil
        case .forceSendGlucose:
            return nil
        case .logs:
            return nil
            
            
        }
    }
}
