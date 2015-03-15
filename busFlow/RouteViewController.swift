//
//  RouteViewController.swift
//  busFlow
//
//  Created by Academy387 on 3/13/15.
//  Copyright (c) 2015 busFlow. All rights reserved.
//

import UIKit
import MapKit
import Alamofire
import SwiftyJSON


class RouteViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    var routeCoordinates:[CLLocationCoordinate2D] = []
    
    var busses:[PathObject] = []
    let urlBusses = "http://flowbus.eu-gb.mybluemix.net/api/busses"
    let urlBusStations = "http://flowbus.eu-gb.mybluemix.net/api/stations"
    var busStations:[PathObject] = []
    var annotations:[CustomPointAnnotation]=[]
    let locationManager = CLLocationManager()
    var markerAnnotation:CustomPointAnnotation?
    
    var userLocation:CLLocation?
    
    var userNearestStation:PathObject?
    var destinationNearestStation:PathObject?
    
    var busOfInterest:PathObject?
    
    var estimatedTimeToDestination:Int?
    var estimatedBusTimeArrival:Int?
    
    var destination:CLLocation?
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(false)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //just for presentation, hardcoded user location  because we cant update user location
        let spanX = 0.01
        let spanY = 0.01
        let hardcodedLocation:CLLocation = CLLocation(latitude: 43.8470823, longitude: 18.3741403)
        self.userLocation = hardcodedLocation
        var newRegion = MKCoordinateRegion(center: hardcodedLocation.coordinate, span: MKCoordinateSpanMake(spanX, spanY))
        var annotation = MKPointAnnotation()
        mapView.addAnnotation(annotation)
        annotation.coordinate = hardcodedLocation.coordinate
        
        mapView.setRegion(newRegion, animated: true)
        
        mapView.delegate = self
        mapView.mapType = MKMapType.Hybrid
        if (CLLocationManager.locationServicesEnabled()){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
        }
        
        var longPress:UILongPressGestureRecognizer = UILongPressGestureRecognizer()
        longPress.minimumPressDuration = 1.0
        self.mapView.addGestureRecognizer(longPress)
        longPress.addTarget(self, action: "longPressToGetLocation:")
        
        //parsing route coordinates from file
        let bundle = NSBundle.mainBundle()
        let path = bundle.pathForResource("Komercijala", ofType: "txt")
        let content = String(contentsOfFile: path!, encoding: NSUTF8StringEncoding, error: nil)
        let filteredContent = content!.stringByReplacingOccurrencesOfString(",0.0", withString: "", options: nil, range: nil)
        let arrayOfCoordinates = filteredContent.componentsSeparatedByString(" ")
        
        for index in 0..<arrayOfCoordinates.count{
            var longlat = arrayOfCoordinates[index].componentsSeparatedByString(",")
            var latitude = (longlat[0] as NSString).doubleValue
            var longitude = (longlat[1] as NSString).doubleValue
            self.routeCoordinates.append(CLLocationCoordinate2D(latitude: longitude, longitude: latitude))
        }
        
        //setting mapView to match route
        var route = MKPolyline(coordinates: &self.routeCoordinates, count:  self.routeCoordinates.count)
        route.title = "sss"
        mapView.addOverlay(route)
        
        
        //send calls every 2 sec
        var helloWorldTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "refresh", userInfo: nil, repeats: true)
        getBusStations()
    }
    
    
    //functions for distance calculations and time estmations
    func findNearestStationFromLocation(location:CLLocationCoordinate2D)->(PathObject, CLLocationDistance){
        
        return findNearestFromLocation(location, pathObjects: self.busStations)
    }
    
    func estimatedArrivelTime(pathObject1:PathObject,pathObject2:PathObject)->Int{
        return (pathObject2.pathIndex! - pathObject1.pathIndex!)*3
    }
    
    func findNearestBusFromStation(busStation:PathObject)->(PathObject, CLLocationDistance, Int){
        var buses = self.busses.filter({s in s.pathIndex < busStation.pathIndex})
        println(busStation)
        var resultTuple  = findNearestFromLocation(busStation.coordinates!,  pathObjects: self.busses)
        return (resultTuple.0,resultTuple.1, (busStation.pathIndex! - resultTuple.0.pathIndex!)*3)
    }
    
    func findNearestFromLocation(location:CLLocationCoordinate2D, pathObjects:[PathObject]) -> (PathObject, CLLocationDistance) {
        
        var locationOfInterest = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        println(locationOfInterest)
        
        var busStationLocation = CLLocation(latitude: pathObjects[0].coordinates!.latitude, longitude: pathObjects[0].coordinates!.longitude)
        var minDistance = locationOfInterest.distanceFromLocation(busStationLocation)
        var nearestIndex = 0
        
        for i in 1..<pathObjects.count {
            busStationLocation = CLLocation(latitude: pathObjects[i].coordinates!.latitude, longitude:  pathObjects[i].coordinates!.longitude)
            
            var distance = locationOfInterest.distanceFromLocation(busStationLocation)
            
            println(distance)
            
            if (distance < minDistance) {
                nearestIndex = i
                minDistance = distance
            }
        }
        
        return(pathObjects[nearestIndex], minDistance)
    }
    
    
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if !(annotation is CustomPointAnnotation) {
            return nil
        }
        
        let reuseIconId = "bus"
        var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseIconId)
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIconId)
            annotationView.canShowCallout = true
        }
        else {
            annotationView.annotation = annotation
        }
        let busAnnotation = annotation as CustomPointAnnotation
        if(busAnnotation.imageName != nil){
            annotationView.image = UIImage(named:busAnnotation.imageName!)
        }else{
            annotationView.image = UIImage(named:"bus")
        }
        
        return annotationView
    }

    
    func locationManager(manager:CLLocationManager, didUpdateLocations locations:[AnyObject]) {
        
        //self.userLocation = locations[0] as? CLLocation
             updatePOIS()
    }
    
    func longPressToGetLocation(gestureRecognizer:UILongPressGestureRecognizer){
        if(gestureRecognizer.state != UIGestureRecognizerState.Began){
            
            var pressPoint:CGPoint = gestureRecognizer .locationInView(self.mapView)
            var chosenLocation:CLLocationCoordinate2D = self.mapView.convertPoint(pressPoint, toCoordinateFromView: self.mapView)
            self.destination = CLLocation(latitude: chosenLocation.latitude, longitude: chosenLocation.longitude)
            self.mapView.removeAnnotation(self.markerAnnotation)
            var annotation = CustomPointAnnotation()
            annotation.coordinate = chosenLocation
            annotation.imageName = "destination"
            self.mapView.addAnnotation(annotation)
            self.markerAnnotation = annotation
            updatePOIS()
     
            
        }
    }
    
    func updatePOIS(){
        if( self.destination != nil && self.userLocation != nil){
            println(self.destination)
            self.destinationNearestStation = self.findNearestStationFromLocation(self.destination!.coordinate).0
            var resTouple = self.findNearestBusFromStation(self.userNearestStation!)
            (self.busOfInterest, self.estimatedBusTimeArrival) = (resTouple.0,resTouple.2)
            self.estimatedTimeToDestination = estimatedArrivelTime(self.busOfInterest!, pathObject2: self.destinationNearestStation!)
            var coord = [CLLocationCoordinate2D]()
            coord.append(self.userNearestStation!.coordinates!)
            coord.append(self.destinationNearestStation!.coordinates!)
            
            
            var route = MKPolyline(coordinates: &coord, count:  coord.count)
            route.title = "rt"
            mapView.addOverlay(route)
            
        } else{
            
        }
    }
    
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)

            if (overlay.title != nil && overlay.title == "rt"){
                polylineRenderer.strokeColor = UIColor(red: 134/256, green: 191/256, blue: 209/256, alpha: 0.5)
                polylineRenderer.lineWidth = 8
                
            }else {
                polylineRenderer.strokeColor = UIColor(red: 71/256, green: 191/256, blue: 209/256, alpha: 1)
                polylineRenderer.lineWidth = 5

            }

                        return polylineRenderer
        }
        return nil
        }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func getBusStations(){
        Alamofire.request(.GET, urlBusStations, parameters: nil)
            .responseJSON { (req, res, json, error) in
                if(error != nil) {
                    NSLog("Error: \(error)")
                }
                else {
                    // NSLog("Success: \(self.urlBusStations)")
                    var jsonBusStations = JSON(json!).arrayValue
                    
                    for i in jsonBusStations {
                        self.busStations.append(PathObject(pathObject:i))
                    }
                    
                    for index in 0..<self.busStations.count{
                        var annotation = CustomPointAnnotation()
                        annotation.coordinate = self.routeCoordinates[self.busStations[index].pathIndex!]
                        self.mapView.addAnnotation(annotation)
                        annotation.imageName = "station"
                    }
                    println(self.userLocation)
                    self.userNearestStation = self.findNearestStationFromLocation(self.userLocation!.coordinate).0
                }
                
        }
    }
    
    func refresh(){
        Alamofire.request(.GET, urlBusses, parameters: nil)
            .responseJSON { (req, res, json, error) in
                if(error != nil) {
                    NSLog("Error: \(error)")
                }
                else {
                    // NSLog("Success: \(self.urlBusses)")
                    var jsonBusses = JSON(json!).arrayValue
                    self.busses.removeAll(keepCapacity: true)
                    for i in jsonBusses {
                        self.busses.append(PathObject(pathObject:i))
                    }
                    
                    if(self.annotations.count != self.busses.count){
                        for index in 0..<self.busses.count{
                            var annotation = CustomPointAnnotation()
                            self.mapView.addAnnotation(annotation)
                            annotation.imageName = "bus"
                            self.annotations.append(annotation)
                            annotation.coordinate =  self.routeCoordinates[self.busses[index].pathIndex!]
                            UIView.animateWithDuration(3.0, animations: { () -> Void in
                                annotation.coordinate = self.routeCoordinates[(self.busses[index].pathIndex! + 1)%620]
                            })
                        }
                    }
                    else{
                        for index in 0..<self.busses.count{
                            
                            if(self.busses[index].id == self.busOfInterest?.id){
                                self.annotations[index].imageName = "bus-of-interest-icon"
                            }else{
                                self.annotations[index].imageName = "bus"
                            }
                            
                            self.annotations[index].coordinate =  self.routeCoordinates[self.busses[index].pathIndex!]
                            UIView.animateWithDuration(3.0, animations: { () -> Void in
                                self.annotations[index].coordinate = self.routeCoordinates[(self.busses[index].pathIndex! + 1)%620]
                            })
                        }
                        self.updatePOIS()
                    }
                }
        }
    }
}


