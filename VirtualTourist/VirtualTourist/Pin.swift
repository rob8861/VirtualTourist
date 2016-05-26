//
//  Pin.swift
//  VirtualTourist
//
//  Created by Rob Fazio on 5/25/16.
//  Copyright © 2016 Rob Fazio. All rights reserved.
//

import UIKit
import CoreData

class Pin: NSManagedObject {
    
    struct Keys {
        static let Lat = "Lat"
        static let long = "Long"
    }
    
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var photos: [Photo]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String:AnyObject], context: NSManagedObjectContext) {
        
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        self.latitude = dictionary[Keys.Lat] as! Double
        self.longitude = dictionary[Keys.long] as! Double
    }
    
}
