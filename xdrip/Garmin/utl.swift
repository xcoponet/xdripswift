//
//  utl.swift
//  xdrip
//
//  Created by xavier coponet on 31/08/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

func customLog(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    let currentDate = Date();
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    let formattedString = formatter.string(from: Date())
    let logMessage = "\(formattedString): \(message)"
    
    // Write to stderr (Debug console)
    NSLog("\(logMessage)")
    
    // Write to log file
    let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0]
    let logPath = documentsDirectory.appending("/console.log")
    
    if let outputStream = OutputStream(toFileAtPath: logPath, append: true) {
        outputStream.open()
        let data = "\(logMessage)\n".data(using: .utf8)!
        _ = data.withUnsafeBytes { outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count) }
        outputStream.close()
    }
}


func reading2dict(_ value: Dictionary<String, Any>) -> Dictionary<String, Any>
{
        return [
            "glucose": Int64(value["Value"] as! Double),
            "trend": value["Trend"] as! Int,
            "timestamp": parseDate(value["ST"] as! String),
        ]
}


func parseDate(_ wt: String) -> Int64 {
    // wt looks like "/Date(1462404576000)/"
    do {
        let re = try NSRegularExpression(pattern: "\\((.*)\\)")
        if let match = re.firstMatch(in: wt, range: NSMakeRange(0, wt.count)) {
            #if swift(>=4)
            let matchRange = match.range(at: 1)
            #else
            let matchRange = match.rangeAt(1)
            #endif
            let epoch = Double((wt as NSString).substring(with: matchRange))! / 1000
            return Int64(epoch)
        } else {
            return -1
        }
    } catch let error as NSError {
        // Handle the error
        print("Failed to create regex: \(error.localizedDescription)")
        return -1
    }
}
