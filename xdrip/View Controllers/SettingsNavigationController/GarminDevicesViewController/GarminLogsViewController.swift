//
//  GarminLogsViewController.swift
//  xdrip
//
//  Created by xavier coponet on 15/03/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//
import UIKit
import ConnectIQ


import SwiftUI
import SwiftUI
import Combine

// Global variable to store logs
 var globalLogs = "" {
     didSet {
        logPublisher.send(globalLogs)
     }
}

let logPublisher = PassthroughSubject<String, Never>()

struct LogView: View {
    @State private var logs = globalLogs
    private var cancellable: AnyCancellable?
    @State private var scrollProxy: ScrollViewProxy?

    init() {
        // Subscribe to changes in globalLogs
        self.cancellable = logPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: \.logs, on: self)
    }

    var body: some View {
        // Use ScrollViewReader for managing the scroll position
        ScrollViewReader { scrollProxy in
            ScrollView {
                Text(logs)
                    .font(.system(size: 20))
                    .multilineTextAlignment(.leading)
                    .padding()
                    .id("logsText")
                    .onChange(of: logs) { _ in
                        // Scroll to the bottom when logs change
                        withAnimation {
                            scrollProxy.scrollTo("logsText", anchor: .bottom)
                        }
                    }
            }
            .onAppear {
                // Explicitly scroll to the bottom as the view appears
                DispatchQueue.main.async {
                    withAnimation {
                        scrollProxy.scrollTo("logsText", anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Public Methods
extension LogView {
    public func appendLog(_ log: String) {
        globalLogs += log + "\n"
    }
}


class GarminLogsViewController: UIViewController {
    
    // MARK: - Properties
    private var logViewHostingController: UIHostingController<LogView>?

    
    // MARK: - Private Properties

    // MARK: - View Life Cycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Garmin Log"
        
        // Initialize LogView and its hosting controller
            let logView = LogView()
            logViewHostingController = UIHostingController(rootView: logView)

            // Add as a child of the current view controller.
            if let controller = logViewHostingController {
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

