//
//  GarminDevicesViewController.swift
//  xdrip
//
//  Created by xavier coponet on 31/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//
import UIKit
import ConnectIQ


import SwiftUI


extension DeviceInfo: Identifiable {
    public var id: String { return self.device.friendlyName } // assuming friendlyName is unique
}


struct DeviceListView: View {
    @StateObject private var deviceManager = DeviceManager.sharedInstance
    @State private var selectedDevice: DeviceInfo?
    
    @State private var navigateToNextView = false
    
    var body: some View {
        VStack {
            List(deviceManager.devices, id: \.id) { deviceInfo in
                    Button(action: {
                        self.selectedDevice = deviceInfo
                        let status = ConnectIQ.sharedInstance().getDeviceStatus(deviceInfo.device)
                        if status == .connected
                        {
                            deviceInfo.updateAppInfos();
                            navigateToNextView = true;
                        }
                        
                    })
                    {
                        DeviceRowView(device: deviceInfo.device, deviceManager: deviceManager)
                    }
            }
                .padding(EdgeInsets())
            
            Button(action: {
                ConnectIQ.sharedInstance().showDeviceSelection()
            }) {
                Text("Find Devices")
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .font(.system(size: 20))
            }
        }
        
    }
}

struct DeviceRowView: View {
    var device: IQDevice
    @ObservedObject var deviceManager: DeviceManager;

    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(device.friendlyName)
                        .font(.system(size: 23))
                        .minimumScaleFactor(0.01)
                        .foregroundColor(Color(.darkText))
                        .frame(width: (geometry.size.width * 2 / 3), alignment: .leading)
                    Spacer()
                    Text(deviceStatus(device))
                        .font(.system(size: 18))
                        .padding(.trailing, 4.0)
                        .minimumScaleFactor(0.01)
                        .foregroundColor(Color(.darkText))
                        .frame(width: (geometry.size.width / 3),alignment: .trailing)
                    
                }
                Text(device.modelName)
                    .font(.system(size: 17))
                    .padding(.leading, 4.0)
                    .minimumScaleFactor(0.01)
                    .foregroundColor(Color(red: 0.666, green: 0.666, blue: 0.666))
                    .frame(alignment: .leading)
            }
        }
    }
}



class GarminDevicesViewController: UIViewController {
    
    // MARK: - Properties
        private var deviceListViewHostingController: UIHostingController<DeviceListView>?

    
    // MARK: - Private Properties

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        NSLog("Hello world")
        super.viewDidLoad()
        
        title = "Garmin Devices"
        
        // Initialize DeviceListView and its hosting controller
            let deviceListView = DeviceListView()
            deviceListViewHostingController = UIHostingController(rootView: deviceListView)

            // Add as a child of the current view controller.
            if let controller = deviceListViewHostingController {
                addChild(controller)
                controller.view.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(controller.view)

                // Set up constraints for the hosting view
                NSLayoutConstraint.activate([
                    controller.view.topAnchor.constraint(equalTo: view.topAnchor),
                    controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                    controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                    controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
                ])

                controller.didMove(toParent: self)
            }
    }
}

