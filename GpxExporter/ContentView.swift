import SwiftUI
import HealthKit

private var dateFormatter : DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd hh:mm:ss"
    return formatter
}()

private var fileDateFormatter : DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd_hh-mm-ss"
    return formatter
}()

private var intervalFormater : DateComponentsFormatter = {
    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .abbreviated
    formatter.maximumUnitCount = 2
    return formatter
}()

private func writeFile(workout: HKWorkout, store: Store, completion: @escaping (URL?) -> Swift.Void) {
    DispatchQueue.main.async {
        let name: String = {
            switch workout.workoutActivityType {
                case .cycling: return "Cycle"
                case .running: return "Run"
                case .walking: return "Walk"
                default: return "Workout"
            }
        }()

        let title = "\(name) - \(dateFormatter.string(from: workout.startDate))"
        let filename = "\(fileDateFormatter.string(from: workout.startDate))_\(name)"

        let targetURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(filename)
            .appendingPathExtension("gpx")

        let file: FileHandle

        do {
            let manager = FileManager.default;
            if manager.fileExists(atPath: targetURL.path) {
                try manager.removeItem(atPath: targetURL.path)
            }
            manager.createFile(atPath: targetURL.path, contents: Data())
            file = try FileHandle(forWritingTo: targetURL);
        } catch let err {
            print(err)
            completion(nil)
            return
        }
        
        let iso_formatter = ISO8601DateFormatter()
        
        file.write("""
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1"
    creator="Apple Workouts"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xmlns="http://www.topografix.com/GPX/1/1"
    xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd"
    xmlns:gpxtpx="http://www.garmin.com/xmlschemas/TrackPointExtension/v1">
    <trk>
        <name><![CDATA[\(title)]]></name>
        <time>\(iso_formatter.string(from: workout.startDate))</time>
        <trkseg>
"""
                    .data(using: .utf8)!)
        
        store.route(for: workout) {
            (maybe_locations, error) in

            guard let locations = maybe_locations, error == nil else {
                print(error as Any);
                
                file.closeFile()
                
                completion(nil)
                
                return
            }

            for location in locations {
                file.write("""
            <trkpt
                lat="\(location.coordinate.latitude)"
                lon="\(location.coordinate.longitude)">
                <ele>\(location.altitude.magnitude)</ele>
                <time>\(iso_formatter.string(from: location.timestamp))</time>
            </trkpt>
"""
                            .data(using: .utf8)!
                )
            }

            file.write("""
            </trkseg>
        </trk>
    </gpx>
    """
                        .data(using: .utf8)!)
            file.closeFile()
        
            completion(targetURL)
        }

    }
}

struct ListItemView: View {
    var workout: HKWorkout
    var store: Store
    
    @State var creating = false
    @State var showingSheet = false
    @State var url : URL? = nil
    
    var startDate: String {
        get {
            dateFormatter.string(from: workout.startDate)
        }
    }
    
    var duration: String {
        get {
            intervalFormater.string(from: workout.duration) ?? "-"
        }
    }
    
    var name: String {
        get {
            switch workout.workoutActivityType {
                case .cycling: return "Cycle"
                case .running: return "Run"
                case .walking: return "Walk"
                default: return "Workout"
            }
        }
    }
    
    var body: some View {
        HStack {
            if (creating) {
                ProgressView("Creating file")
            } else {
                Text(name).frame(width: 50, height: 42, alignment: .leading)
                Text(startDate).frame(minWidth: /*@START_MENU_TOKEN@*/0/*@END_MENU_TOKEN@*/, idealWidth: 200, maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, minHeight: 42, idealHeight: 42, maxHeight: 42, alignment: .leading)
                Text(duration).frame(width: /*@START_MENU_TOKEN@*/100/*@END_MENU_TOKEN@*/, height: 42, alignment: .trailing)
            }
        }.onTapGesture {
            creating = true
            
            writeFile(workout: workout, store: store) {
                (fileUrl) in
                
                print ("\(String(describing: fileUrl?.absoluteString))")

                url = fileUrl
                
                if (url != nil) {
                    showingSheet = true
                }
                
                creating = false
            }
        }.sheet(isPresented: $showingSheet,
                content: {
                 ActivityView(activityItems: [url!] as [Any], applicationActivities: nil) })
    }
}

struct ContentView: View {
    @State var authorized = false
    @State var message = "Authorization required"
    
    @State var store : Store? = nil
    @State var workoutList : [HKWorkout] = []
    
    var body: some View {
        VStack {
            Text(message).padding()

            if (authorized) {
                List(workoutList, id: \.uuid) { workout in
                    ListItemView(workout: workout, store: store!)
                }
            }
            
            Spacer()
        }.onAppear().onAppear {
            authorize()
        }
    }
    

    private func authorize() {
        Authorization.authorize { (success, error) in
            authorized = success;
            
            if let error = error {
                message = error.localizedDescription
            } else {
                store = Store()
                store!.loadWorkouts { (workouts, error) in
                    if let error = error {
                        message = error.localizedDescription
                    } else {
                        if let workouts = workouts {
                            message = "\(workouts.count) workouts"
                            workoutList = workouts
                        } else {
                            message = "No workouts found"
                        }
                    }
                }
            }
        }
    }
}
