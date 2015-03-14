//
//  Bus.swift
//  busFlow
//
//  Created by Academy387 on 3/14/15.
//  Copyright (c) 2015 busFlow. All rights reserved.
//

import UIKit
import MapKit
import SwiftyJSON

class PathObject: NSObject {
    var id:Int?
    var pathIndex:Int?
    var coordinates:CLLocationCoordinate2D?
    
    init(pathObject:JSON) {
        self.id = pathObject["id"].intValue
        self.pathIndex = pathObject["pathIndex"].intValue
        self.coordinates = CLLocationCoordinate2D(latitude: pathObject["geo"]["lng"].doubleValue, longitude: pathObject["geo"]["lat"].doubleValue)
    }
}
