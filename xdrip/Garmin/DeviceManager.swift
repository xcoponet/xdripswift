//
//  DeviceManager.swift
//  xdrip
//
//  Created by xavier coponet on 31/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import ConnectIQ
import UIKit

let kDevicesFileName = "devices"

protocol DeviceManagerDelegate {
    func devicesChanged()
}


func status2string(_ status: IQDeviceStatus) -> String
{
    switch status{
    case .invalidDevice:
        return "Invalid Device"
    case .bluetoothNotReady:
        return "Bluetooth Off"
    case .notFound:
        return "Not Found"
    case .notConnected:
        return "Not Connected"
    case .connected:
        return "Connected"
    }
}

func deviceStatus(_ device: IQDevice) -> String {
    let status = ConnectIQ.sharedInstance().getDeviceStatus(device)
    return status2string(status);
}

class DeviceManager: NSObject, ObservableObject, IQDeviceEventDelegate {
    
    @Published var devices = [DeviceInfo]()
    var delegate: DeviceManagerDelegate?
    
    static let sharedInstance = DeviceManager()
    
    @Published var triggerRedraw: Bool = false;
    
    var coreDataManager:CoreDataManager? = nil;
   
    private override init() {
        // no op
    }
    
    func handleOpenURL(_ url: URL) -> Bool {
        if !url.absoluteString.contains(IQGCMBundle) {
            print("\(IQGCMBundle) not found in URL, disregarind open request, likely not for us.")
            return false
        }
        if (url.scheme! == ReturnURLScheme)
        {
            let devices = ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url)
            dump(devices)
            if let devices = devices, devices.count > 0 {
                print("Forgetting \(Int(self.devices.count)) known devices.")
                self.devices.removeAll()
                for (index, device) in devices.enumerated() {
                    guard let device = device as? IQDevice else { continue }
                    print("Received device (\(index+1) of \(devices.count): [\(device.uuid), \(device.modelName), \(device.friendlyName)]")
                    self.devices.append(DeviceInfo(device, coreDataManager!))
                    print("status>>> \(ConnectIQ.sharedInstance().getDeviceStatus(device).rawValue)")
                }
                self.saveDevicesToFileSystem()
                self.delegate?.devicesChanged()
                
                for deviceInfo in self.devices {
                    print("Registering for device events from '\(deviceInfo.device.friendlyName)'")
                    ConnectIQ.sharedInstance().register(forDeviceEvents: deviceInfo.device, delegate: self)
                }
                return true
            }
        }
        return false
    }
    
    func saveDevicesToFileSystem() {
        do {
            var devices2save = [IQDevice]();
            for(dev) in devices
            {
                devices2save.append(dev.device)
            }
            let data = try NSKeyedArchiver.archivedData(withRootObject: devices2save, requiringSecureCoding: false)
            let url = URL(fileURLWithPath: self.devicesFilePath())
            try data.write(to: url)
        } catch {
            print("Failed to save devices file: \(error)")
        }
    }
    
    func restoreDevicesFromFileSystem() {
        do {
            let filePath = self.devicesFilePath()
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            guard let restoredDevices = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSArray.self, IQDevice.self], from: data) as? [IQDevice] else {
                print("Failed to unarchive devices, or no devices found.")
                return
            }
            // use `restoredDevices`
            if restoredDevices.count > 0 {
                print("Restored saved devices:")
                for device in restoredDevices {
                    print("\(device)")
                    self.devices.append(DeviceInfo(device, coreDataManager!))
                }
                
                for deviceinfo in self.devices {
                    print("Registering for device events from '\(deviceinfo.device.friendlyName)'")
                    ConnectIQ.sharedInstance().register(forDeviceEvents: deviceinfo.device, delegate: self)
                }
            }
            else {
                print("No saved devices to restore.")
                self.devices.removeAll()
            }
            self.delegate?.devicesChanged()
        } catch {
            print("Failed to read or unarchive devices: \(error)")
        }
    }
    
    func devicesFilePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let appSupportDirectory = URL(fileURLWithPath: paths[0])
        let dirExists = (try? appSupportDirectory.checkResourceIsReachable()) ?? false
        if !dirExists {
            print("DeviceManager.devicesFilePath appSupportDirectory \(appSupportDirectory) does not exist, creating... ")
            do {
                try FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true, attributes: nil)
            }
            catch let error {
                print("There was an error creating the directory \(appSupportDirectory) with error: \(error)")
            }
        }
        print("deviceFilePath \(appSupportDirectory.appendingPathComponent(kDevicesFileName).path)");
        print("dirExists \(dirExists)")
        return appSupportDirectory.appendingPathComponent(kDevicesFileName).path
    }

    // --------------------------------------------------------------------------------
    // MARK: - METHODS (IQDeviceEventDelegate)
    // --------------------------------------------------------------------------------
    func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        print("Device Status changed: \(device): \(status2string(status))");
        self.triggerRedraw.toggle();
        
        if let index = self.devices.firstIndex(where: { $0.device.uuid == device.uuid }) {
            print("Found at index:", index)
            self.devices[index].updateStatus()
            if(self.devices[index].status == .connected)
            {
                // run in background to allow for sleep. otherwise, update info cannot gather the apps status
                DispatchQueue.global(qos: .background).async {
                    // This code will be executed on a background thread
                    sleep(1)
                    self.devices[index].updateAppInfos()
                }
            }
            
        } else {
            print("Not found")
        }
    }
    
    
}


