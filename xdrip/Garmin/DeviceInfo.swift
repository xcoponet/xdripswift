//
//  Device.swift
//  xDripGarminCompanion
//
//  Created by xavier coponet on 10/08/2023.
//

import ConnectIQ
import UIKit

extension BgReading {
    
    /// dictionary representation for upload to Dexcom Share
   public var dictionaryRepresentationForGarminUpload: [String: Any] {
    
    // date as expected by garmin apps
    let date = Int64(floor(timeStamp.toMillisecondsAsDouble() / 1000))
    
    let newReading: [String : Any] = [
        "trend" : slopeOrdinal(),
        "timestamp" : date,
        "glucose" : Int64(calculatedValue),
        ]
    
    return newReading
    
    }
     
}

class DeviceInfo: NSObject , IQAppMessageDelegate
{
    var device: IQDevice = IQDevice();
    var status: IQDeviceStatus = IQDeviceStatus.invalidDevice;
    
    var appInfos: [UUID: AppInfo] = [:]
    
    var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    
    /// reference to coreDataManager
    private var coreDataManager:CoreDataManager

    init(_ coreDataManager:CoreDataManager)
    {
        self.coreDataManager = coreDataManager;
    }
    
    convenience init( _ device: IQDevice, _ coreDataManager:CoreDataManager)
    {
        self.init(coreDataManager)
        self.device = device
        self.updateStatus()
        
        // let xDripWidget = IQApp(uuid: UUID(uuidString: "3cb003ff-cc4b-439a-8129-eec629b18d28"), store: UUID(), device: self.device)
        let xDripWatchFace = IQApp(uuid: UUID(uuidString: "072d1d77-05ce-43b6-b889-c32169598401"), store: UUID(), device: self.device)
        let xDripDataField = IQApp(uuid: UUID(uuidString: "14cbe159-40d2-413c-8374-87a9dbc9739a"), store: UUID(), device: self.device)

        // self.appInfos[xDripWidget!.uuid] = AppInfo(name: "xDrip Widget", iqApp: xDripWidget!)
        self.appInfos[xDripWatchFace!.uuid] = AppInfo(name: "xDrip Watchface", iqApp: xDripWatchFace!)
        self.appInfos[xDripDataField!.uuid] = AppInfo(name: "xDrip Data Field", iqApp: xDripDataField!)
        
        // for test
        // let stringApp = IQApp(uuid: UUID(uuidString: "a3421fee-d289-106a-538c-b9547ab12095"), store: UUID(), device: device)
        // self.appInfos[stringApp!.uuid] = AppInfo(name: "String App", iqApp: stringApp!)
        
        self.updateAppInfos()
    }
    
    func updateStatus() {
        self.status = ConnectIQ.sharedInstance().getDeviceStatus(self.device)
    }
    
    func updateAppInfos()
    {
        if(self.status == .connected)
        {
            for appInfo: AppInfo in self.appInfos.values {
                appInfo.updateStatus(withCompletion: {(appInfo: AppInfo) -> Void in
                    print("\(self.device.friendlyName): \(appInfo.name) \(String(describing: appInfo.status?.isInstalled))")
                    if(appInfo.status?.isInstalled ?? false)
                    {
                        ConnectIQ.sharedInstance().register(forAppMessages: appInfo.app, delegate: self)
                    }
                    else
                    {
                        ConnectIQ.sharedInstance().unregister(forAppMessages: appInfo.app, delegate: self);
                    }
                })
            }
        }
    }
    
        
    
    // --------------------------------------------------------------------------------
    // MARK: - METHODS (IQAppMessageDelegate)
    // --------------------------------------------------------------------------------
    func receivedMessage(_ message: Any, from app: IQApp) {
        customLog("received: \(message)");

        if let data = message as? String
        {
            if(data == "getData" || data == "forceGetData")
            {
                self.sendGlucose(app);
            }
        }
    }
    
    func sendGlucose(_ app: IQApp)
    {
        let bgReadingsAccessor = BgReadingsAccessor(coreDataManager: coreDataManager)
        // get last readings with calculated value
        // reduce timeStampLatestLoopSharedBgReading with 30 minutes. Because maybe Loop wasn't running for a while and so missed one or more readings. By adding 30 minutes of readings, we fill up a gap of maximum 30 minutes in Loop
        let lastReadings = bgReadingsAccessor.getLatestBgReadings(limit: 2, fromDate: Date().addingTimeInterval(-TimeInterval(minutes: 30)), forSensor: nil, ignoreRawData: true, ignoreCalculatedValue: false)
        
        if lastReadings.count == 0 {
            // this is the case where loopdelay = 0 and lastReadings is empty
            return
        }
        
        var msg = [lastReadings[0].dictionaryRepresentationForGarminUpload];
        
        if lastReadings.count > 1
        {
            msg.append(lastReadings[1].dictionaryRepresentationForGarminUpload)
        }
        customLog("Sending message to \(appInfos[app.uuid]?.name) on \(device.friendlyName ?? ""): \(msg)")
        ConnectIQ.sharedInstance().sendMessage(msg, to: app, progress: {(sentBytes: UInt32, totalBytes: UInt32) -> Void in
            let percent: Double = 100.0 * Double(sentBytes / totalBytes)
            print("Progress: \(percent)% sent \(sentBytes) bytes of \(totalBytes)")
        }, completion: {(result: IQSendMessageResult) -> Void in
            customLog("Send message finished with result: \(NSStringFromSendMessageResult(result))")
            
            sleep(5);
            ConnectIQ.sharedInstance().sendMessage(msg, to: app, progress: {(sentBytes: UInt32, totalBytes: UInt32) -> Void in
                let percent: Double = 100.0 * Double(sentBytes / totalBytes)
                print("Progress: \(percent)% sent \(sentBytes) bytes of \(totalBytes)")
            }, completion: {(result: IQSendMessageResult) -> Void in
                customLog("Send message finished with result: \(NSStringFromSendMessageResult(result))\n")
            })
        })
    }
    
    func endBackgroundTask() {
        customLog("End background task");
        UIApplication.shared.endBackgroundTask(backgroundTask)
        backgroundTask = .invalid
      }
}

