//
//  ViewController.swift
//  VirtualTourist
//
//  Created by Rob Fazio on 5/24/16.
//  Copyright © 2016 Rob Fazio. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {

    var pins: [Pin]?
    
    @IBOutlet weak var mapView: MKMapView!
    
    // returns the file path to store the map zoom level and location
    var mapRegionfilePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    // returns the shared context of the application
    lazy var sharedContext: NSManagedObjectContext = {
       return CoreDataStackManager.sharedInstance().managedObjectContext
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        restoreMapRegion(true)
        pins = fetchAllPins()
        restoreMapPins()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    // responds to a long press and creates a new pin annotation
    @IBAction func mapPressed(sender: UILongPressGestureRecognizer) {
        
        if sender.state != .Began {
            return
        }
        
        let touchPoint = sender.locationInView(mapView)
        let coordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
        
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "loc"
        mapView.addAnnotation(annotation)
        
        // persist the pin
        let dic : [String:AnyObject] = [
            Pin.Keys.Lat : coordinate.latitude,
            Pin.Keys.long : coordinate.longitude
        ]
        let pin = Pin(dictionary: dic, context: self.sharedContext)
        pins?.append(pin)
        CoreDataStackManager.sharedInstance().saveContext()
    }

    // MARK : MapKit Delegate Methods
    
    // ask the delegate to render the pins
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = false
            pinView!.animatesDrop = true
            pinView!.pinTintColor = UIColor.redColor()
        }
        else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    // ask the delegate to respond to pin tapped event
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        
        print("pin was tapped")
        let pin = getPinForCoordinates((view.annotation?.coordinate.latitude)!, lon: (view.annotation?.coordinate.longitude)!)
        performSegueWithIdentifier("toAlbum", sender: pin)
        
        mapView.deselectAnnotation(view.annotation, animated: false)
    }
    
    // find the pin which was tapped based on its latitude and longitude
    private func getPinForCoordinates(lat: Double, lon: Double) -> Pin {
        
        for pin in pins! {
            
            if (pin.latitude == lat) && (pin.longitude == lon) {
                return pin
            }
        }
        return Pin()
    }
    
    // ask the delegate to respond to map zoom and location changes.
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    
    // MARK: segue 
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        
        // TODO: segue over to the photo album controller
        if segue.identifier == "toAlbum" {
            let controller = segue.destinationViewController as! PhotoAlbumViewController
            let pin = sender as! Pin
            controller.pin = pin
            
        }
    }
    
    // MARK: MapView regions and Zoom level
    
    func saveMapRegion() {
        
        // Place the "center" and "span" of the map into a dictionary
        // The "span" is the width and height of the map in degrees.
        // It represents the zoom level of the map.
        
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        // Archive the dictionary into the filePath
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: mapRegionfilePath)
    }
    
    func restoreMapRegion(animated: Bool) {
        
        // if we can unarchive a dictionary, we will use it to set the map back to its
        // previous center and span
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(mapRegionfilePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
        }
    }
    
    // MARK: Fetch Pins from CoreData
    func fetchAllPins() -> [Pin] {
        let request = NSFetchRequest(entityName: "Pin")
        do {
            return try sharedContext.executeFetchRequest(request) as! [Pin]
        } catch let error as NSError {
            print("Fetching pins failed with error \(error.localizedDescription)")
            return [Pin]()
        }
    }
    
    func restoreMapPins() {
        
        if let pins = pins {
            
            var annotations = [MKPointAnnotation]()
            
            for pin in pins {
                
                let annotation = MKPointAnnotation()
                annotation.coordinate.latitude = pin.latitude
                annotation.coordinate.longitude = pin.longitude
                annotations.append(annotation)
            }
            
            if annotations.count > 0 {
                mapView.addAnnotations(annotations)
            }
        }
    }
}

