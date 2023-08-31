//
//  iOSWidget.swift
//  iOSWidget
//
//  Created by xavier coponet on 22/06/2023.
//  Copyright © 2023 Johan Degraeve. All rights reserved.
//

import WidgetKit
import SwiftUI


extension View {
    func widgetBackground(_ color: Color) -> some View {
        if #available(iOSApplicationExtension 17.0, macOSApplicationExtension 14.0, *) {
            return  containerBackground(color, for: .widget)
        } else {
            return background(color)
        }
    }
}


func glucoseFormatter(glucoses: [Glucose]) -> (UInt16, UInt8)
{
    if(glucoses.count > 0)
    {
        return (glucoses[0].glucose, glucoses[0].trend)
    }
    else
    {
        return (120, 4)
    }
}

func slopeArrow(slopeOrdinal: UInt8) -> String {
    
    switch slopeOrdinal {
        
    case 7:
        return "\u{2193}\u{2193}"
        
    case 6:
        return "\u{2193}"
        
    case 5:
        return "\u{2198}"
        
    case 4:
        return "\u{2192}"
        
    case 3:
        return "\u{2197}"
        
    case 2:
        return "\u{2191}"
        
    case 1:
        return "\u{2191}\u{2191}"
        
    default:
        return ""
        
    }
}

func gluColor(glu: UInt16) -> Color
{
    if(glu < 55 || glu > 250)
    {
        return Color.red
    }
    else if(glu < 70 || glu > 180)
    {
        return Color.orange
    }
    else
    {
        return Color.green
    }
}


struct SimpleTimeLineProvider: TimelineProvider {
    
    typealias Entry = SimpleEntry
    
    func placeholder(in context: Context) -> Entry {
        // This data will be masked
        return SimpleEntry(date: Date(), providerInfo: "placeholder")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> ()) {
        let entry = SimpleEntry(date: Date(), providerInfo: "snapshot")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let entry = SimpleEntry(date: Date(), providerInfo: "timeline")
        
        // Perform any setup necessary in order to update the view.
        
        let xDripClient = XDripClient();
        xDripClient.fetchLast(2, callback:  { (error, glucoseArray) in
            
            if error != nil {
                return
            }
            
            NSLog("xDripWidget got \(String(describing: glucoseArray?.count)) values")
            
            guard let glucoseArray = glucoseArray, glucoseArray.count > 0 else {
                return
            }
            entry.glucoseVars = glucoseArray;
        })
        
        let currentDate = Date()
        let lastGlyDate = (entry.glucoseVars.count > 0 ? entry.glucoseVars[0].timestamp : nil);
        var refreshDate = lastGlyDate != nil ? lastGlyDate : currentDate;
        while(refreshDate! < currentDate)
        {
            refreshDate = Calendar.current.date(byAdding: .minute, value: 1, to: refreshDate!)
        }
        if(lastGlyDate == nil || refreshDate! >= Calendar.current.date(byAdding: .minute, value: 5, to: lastGlyDate!)!)
        {
            entry.updDate = Calendar.current.date(byAdding: .second, value: 30, to: currentDate)!
            NSLog("Timeline will update in 30s \(entry.updDate)")
            let timeline = Timeline(entries: [entry], policy: .after(entry.updDate))
            completion(timeline)
        }
        else
        {
            var entries: [Entry] = []
            
            for minuteOffset in 0..<6 {
                var nextRefreshDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: refreshDate!)!
                if(minuteOffset == 5)
                {
                    nextRefreshDate = Calendar.current.date(byAdding: .second, value: -30, to: nextRefreshDate)!
                }
                if(nextRefreshDate >= Calendar.current.date(byAdding: .minute, value: 5, to: lastGlyDate!)! )
                {
                    break
                }
                let currententry = SimpleEntry(date: nextRefreshDate, providerInfo: "timeline")
                currententry.updDate = Calendar.current.date(byAdding: .minute, value: 1, to: nextRefreshDate)!

                currententry.glucoseVars = entry.glucoseVars
                entries.append(currententry)
            }
            
            NSLog("Timeline will refresh every min and update in 5min \(refreshDate)")
            
            let timeline = Timeline(entries: entries, policy: .atEnd)
            completion(timeline)
        }
    }
}

class SimpleEntry: TimelineEntry {
    let date: Date
    var updDate: Date
    let providerInfo: String
    
    var glucoseVars:[Glucose]
    
    init(date: Date, providerInfo: String)
    {
        self.date = date
        self.providerInfo = providerInfo
        self.glucoseVars = [
            Glucose(glucose:120,trend: 4, timestamp: Date(), collector: ""),
            Glucose(glucose:110,trend: 4, timestamp: Calendar.current.date(byAdding: .minute, value: -5, to: Date()) ?? Date(), collector: "")
        ]
        self.updDate = Date()
    }
}

struct SimpleWidgetView : View {
    
    let entry: SimpleEntry
    
    // Obtain the widget family value
    @Environment(\.widgetFamily)
    var family
    
    var body: some View {
        switch family {
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
            
        default:
            // UI for Home Screen widget
            HomeScreenWidgetView(entry: entry, type: family)
        }
    }
}

@main
struct SimpleWidget: Widget {
    let kind: String = "xDripWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SimpleTimeLineProvider()) { entry in
            SimpleWidgetView(entry: entry)
        }
        .configurationDisplayName("View Size Widget")
        .description("This is a demo widget.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            
            // Add Support to Lock Screen widgets
            .accessoryCircular,
            .accessoryRectangular,
        ])
    }
}


/// Widget view for home screen
struct HomeScreenWidgetView: View {
    
    let entry: SimpleEntry
    let type: WidgetFamily
    
    var body: some View {
        GeometryReader { geometry in
            HStack
            {
                VStack {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .center, spacing: 10) {
                        let timestamp = entry.glucoseVars[0].timestamp
//                        let timeDiff = Calendar.current.dateComponents([.minute], from: timestamp, to: entry.date).minute ?? 0
                        let diff = Float(entry.date.timeIntervalSince1970 - timestamp.timeIntervalSince1970)

                        let minutes = Int(round(diff / 60.0))
                       
                        let timeDiffTxt = Text("\(minutes) min ago")
                        if(type == .systemMedium)
                        {
                            timeDiffTxt.font(.system(size: 10)).padding(.top).padding(.leading)
                        }
                        else
                        {
                            timeDiffTxt.font(.system(size: 10)).padding(.top).padding(.leading)
                        }
                        
                        if(entry.glucoseVars.count > 1)
                        {
                            let glyDiff: Int16 = Int16(entry.glucoseVars[0].glucose) - Int16(entry.glucoseVars[1].glucose)
                            let diffStr = (glyDiff > 0 ? "+" : "") + "\(glyDiff)"
                            Text(diffStr).font(.system(size: 10))
                                .padding(.trailing)
                                .padding(.top)
                        }
                    }
                    Spacer()
                    
                    VStack
                    {
                        let current = glucoseFormatter(glucoses: entry.glucoseVars).0
                        let slope = glucoseFormatter(glucoses: entry.glucoseVars).1
                        
                        Text(slopeArrow(slopeOrdinal:slope)).foregroundColor(gluColor(glu:current)).font(.system(size: 50))
                        let timestamp = entry.glucoseVars[0].timestamp
                        
                        HStack{
                            let shouldStrikethrough = Float(entry.date.timeIntervalSince1970 - timestamp.timeIntervalSince1970) / 60 > 10;
                            Text("\(current)").foregroundColor(gluColor(glu:current)).font(.system(size: 35))
                                .padding(.bottom)
                                .modifier(ConditionalStrikethrough(shouldApply: shouldStrikethrough))
                            Text("mg/dL").foregroundColor(gluColor(glu:current))
                        }
                    }
                    
                }.foregroundColor(.white).background(.black)
                
                
                if(type != .systemSmall)
                { Spacer()
                    VStack
                    {
                        Text("gly date: \(entry.glucoseVars.count > 0 ? dateFmt( entry.glucoseVars[0].timestamp) : "-1")").font(.footnote)
                        Text("nxt update: \(dateFmt(entry.updDate))").font(.footnote)
                    }
                    .frame(width: geometry.size.width / 2, height: geometry.size.height)
                    .background(.white)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height).widgetBackground(.black) // hstack
        }
    }
    
    init(entry: SimpleEntry, type: WidgetFamily)
    {
        self.entry = entry
        self.type = type
    }
    
    func dateFmt(_ date: Date) -> String
    {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct ConditionalStrikethrough: ViewModifier {
    var shouldApply: Bool
    
    func body(content: Content) -> some View {
        if shouldApply {
            return content
                .strikethrough(true)
        } else {
            return content
                .strikethrough(false)
        }
    }
}

/// Widget view for `accessoryRectangular`
struct RectangularWidgetView: View {
    let entry: SimpleEntry
    
    init(entry: SimpleEntry)
    {
        self.entry = entry
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AccessoryWidgetBackground()
                HStack {
                    GeometryReader { geometry in
                        HStack(spacing: 0) { // HStack to center in the widget
                            
                            VStack
                            {
                                let current = glucoseFormatter(glucoses: entry.glucoseVars).0
                                let slope = glucoseFormatter(glucoses: entry.glucoseVars).1
                                let arrowTxt = Text(slopeArrow(slopeOrdinal:slope)).foregroundColor(gluColor(glu:current))
                                //                        Text("\(current)").foregroundColor(gluColor(glu:current))
                                let timestamp = entry.glucoseVars[0].timestamp
                                let shouldStrikethrough = Float(entry.date.timeIntervalSince1970 - timestamp.timeIntervalSince1970) / 60 > 10;
                                let currenTxt = Text("\(current)").foregroundColor(gluColor(glu:current))
                                    .modifier(ConditionalStrikethrough(shouldApply: shouldStrikethrough))
                                
                                arrowTxt.font(.system(size: 25))
                                currenTxt.font(.headline)
                            }
                        }.frame(maxWidth: .infinity, maxHeight: .infinity) // center in the widget
                    }
                    
                    
                    VStack
                    {
                        if(entry.glucoseVars.count > 0)
                        {
                            let timestamp = entry.glucoseVars[0].timestamp
                            let timeDiff = Calendar.current.dateComponents([.minute], from: timestamp, to: entry.date).minute ?? 0
                            Text("\(timeDiff)min ago").font(.footnote)
                            
                            if(entry.glucoseVars.count > 1)
                            {
                                let glyDiff: Int16 = Int16(entry.glucoseVars[0].glucose) - Int16(entry.glucoseVars[1].glucose)
                                let diffStr = (glyDiff > 0 ? "+" : "") + "\(glyDiff) mg/dL"
                                Text(diffStr).font(.footnote)
                            }
                        }
                        else
                        {
                            // Trade view with the full description on bigger screens.
                            Text("\(Date(), style: .relative) ago")
                                .monospacedDigit().font(.footnote)
                        }
                    }.padding(5)
                }
            }
        }.widgetBackground(.black)
    }
}


/// Widget view for `accessoryCircular`
///

struct CircularWidgetView: View {
    let entry: SimpleEntry
    
    init(entry: SimpleEntry)
    {
        self.entry = entry
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) { // HStack to center in the widget
                
                VStack
                {
                    let current = glucoseFormatter(glucoses: entry.glucoseVars).0
                    let slope = glucoseFormatter(glucoses: entry.glucoseVars).1
                    let arrowTxt = Text(slopeArrow(slopeOrdinal:slope)).foregroundColor(gluColor(glu:current))
                    //                        Text("\(current)").foregroundColor(gluColor(glu:current))
                    let currenTxt = Text("\(current)").foregroundColor(gluColor(glu:current))
                    
                    arrowTxt.font(.system(size: 25))
                    currenTxt.font(.headline)
                }
                .background(Color.clear)
                .edgesIgnoringSafeArea(.all)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)// center in the widget
                .widgetBackground(.black)
        }
    }
}


struct SimpleWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        SimpleWidgetView(entry: SimpleEntry(date: Date(), providerInfo: "preview"))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
        
        SimpleWidgetView(entry: SimpleEntry(date: Date(), providerInfo: "preview"))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
        
        
        SimpleWidgetView(entry: SimpleEntry(date: Date(), providerInfo: "preview"))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
        
        SimpleWidgetView(entry: SimpleEntry(date: Date(), providerInfo: "preview"))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
        
        
    }
}
