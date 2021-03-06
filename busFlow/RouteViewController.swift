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
import QuartzCore

class RouteViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    let urlBusses = "http://flowbus.eu-gb.mybluemix.net/api/busses"
    let urlBusStations = "http://flowbus.eu-gb.mybluemix.net/api/stations"
    
    @IBOutlet weak var busOfInterestImageView: UIImageView!
    @IBOutlet weak var travelDetailsView: UIView!
    @IBOutlet weak var startingStationLabel: UILabel!
    @IBOutlet weak var destinationStationLabel: UILabel!
    @IBOutlet weak var firstBusArrivalLabel: UILabel!
    @IBOutlet weak var nextBusArrivalLabel: UILabel!
    @IBOutlet weak var mapView: MKMapView!
    
    @IBAction func closeTravelDetailsViewbutton(sender: UIButton) {
        travelDetailsView.hidden = true
    }
    
    var routeCoordinates:[CLLocationCoordinate2D] = []
    // Create the actions
    
    var stations:[PathObject] = []
    var busses:[PathObject] = []
    
    var annotations:[CustomPointAnnotation]=[]
    let locationManager = CLLocationManager()
    var markerAnnotation:CustomPointAnnotation?
    
    var userLocation:CLLocation?
    var userAnnotation:CustomPointAnnotation?
    
    var userNearestStation:PathObject?
    var userNearestStationAnnotation:CustomPointAnnotation?
    
    var destinationStation:PathObject?
    var destinationNearestStationAnnotation:CustomPointAnnotation?
    
    var busOfInterest:PathObject?
    var busOfInterestAnnotation:CustomPointAnnotation?
    
    var missedBus:PathObject?
    var missedBusAnnotation:CustomPointAnnotation?
    
    var estimatedTimeToDestination:Int?
    var estimatedBusTimeArrival:Int?
    
    var destination:CLLocation?
    var destinationAnotation: CustomPointAnnotation?
    
    var routOverlay: MKPolyline?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tabBarItem.image = UIImage(named: "mapWhiteIcon")
        
        self.travelDetailsView.layer.cornerRadius = 10.0
        self.travelDetailsView.layer.masksToBounds = true
        
        self.travelDetailsView.layer.shadowColor = UIColor.blackColor().CGColor
        self.travelDetailsView.layer.shadowOffset = CGSizeMake(10 , 10)
        self.travelDetailsView.layer.shadowRadius = 5
        self.travelDetailsView.layer.shadowOpacity = 1.0
      
       

        mapView.addSubview(travelDetailsView)
        mapView.bringSubviewToFront(travelDetailsView)
        self.travelDetailsView.hidden = true
        
        //just for presentation, user tracking implemented below
      //  userLocation = CLLocation(latitude: 43.8470823, longitude: 18.3741403)
        
       
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
        
        parseRouteCoordinates()
        
        // Add route polyline
        var route = MKPolyline(coordinates: &self.routeCoordinates, count:  self.routeCoordinates.count)
        route.title = "sss"
        mapView.addOverlay(route)
        
        
        NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "refresh", userInfo: nil, repeats: true)
        getBusStations()
    }
    
    func parseRouteCoordinates(){
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
    }
    
    
    //functions for distance calculations and time estmations
    func findNearestStationFromLocation(location:CLLocationCoordinate2D)->(PathObject, CLLocationDistance){
        
        return findNearestFromLocation(location, pathObjects: self.stations)
    }
    
    func estimatedArrivelTime(pathObject1:PathObject,pathObject2:PathObject)->Int{
        return (pathObject2.pathIndex! - pathObject1.pathIndex!)*3
    }
    
    func findNearestApproachingBusFromStation(busStation:PathObject)->(PathObject, Int){
        var approachingBussses = self.busses.filter({s in s.pathIndex < busStation.pathIndex})
        
        var resultBus: PathObject?
        var pathIndex: Int?

        
        if(approachingBussses.count == 0){
            resultBus = findPathObjectWithMaxPathIndex(self.busses)
            pathIndex = resultBus!.pathIndex
            return (resultBus!, (self.routeCoordinates.count - 1 - pathIndex! + busStation.pathIndex!)*3)
        }else{
            resultBus = findPathObjectWithMaxPathIndex(approachingBussses)
            pathIndex = resultBus!.pathIndex
            return (resultBus!, (busStation.pathIndex! - pathIndex!)*3)
        }
    }
    
    func findPathObjectWithMaxPathIndex(pathObjects: [PathObject])-> (PathObject){
        var result = pathObjects[0]
        for i in pathObjects{
            if(result.pathIndex < i.pathIndex){
                result = i
            }
        }
        return result
    }
    
    func findNearestFromLocation(location:CLLocationCoordinate2D, pathObjects:[PathObject]) -> (PathObject, CLLocationDistance) {
        
        var locationOfInterest = CLLocation(latitude: location.latitude, longitude: location.longitude)
        
        var busStationLocation = CLLocation(latitude: pathObjects[0].coordinates!.latitude, longitude: pathObjects[0].coordinates!.longitude)
        var minDistance = locationOfInterest.distanceFromLocation(busStationLocation)
        var nearestIndex = 0
        
        for i in 1..<pathObjects.count {
            busStationLocation = CLLocation(latitude: pathObjects[i].coordinates!.latitude, longitude:  pathObjects[i].coordinates!.longitude)
            
            var distance = locationOfInterest.distanceFromLocation(busStationLocation)
            
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
        
        var location:CLLocation = locations[0] as CLLocation
        self.userLocation = CLLocation(latitude: location.coordinate.longitude, longitude: location.coordinate.latitude)
        println(self.userLocation)
        let spanX = 0.01
        let spanY = 0.01
        var newRegion = MKCoordinateRegion(center: userLocation!.coordinate, span: MKCoordinateSpanMake(spanX, spanY))
        var annotation = CustomPointAnnotation(imageName: "user")
        mapView.addAnnotation(annotation)
        annotation.coordinate = userLocation!.coordinate
        mapView.setRegion(newRegion, animated: true)
        updatePOIS()
    }
    
    func longPressToGetLocation(gestureRecognizer:UILongPressGestureRecognizer){
        if(gestureRecognizer.state != UIGestureRecognizerState.Began){
            var pressPoint:CGPoint = gestureRecognizer.locationInView(self.mapView)
            var chosenLocation:CLLocationCoordinate2D = self.mapView.convertPoint(pressPoint, toCoordinateFromView: self.mapView)
            self.destination = CLLocation(latitude: chosenLocation.latitude, longitude: chosenLocation.longitude)
            self.mapView.removeAnnotation(self.markerAnnotation)
            var annotation = CustomPointAnnotation(imageName: "destination")
            annotation.coordinate = chosenLocation
            self.mapView.addAnnotation(annotation)
            self.markerAnnotation = annotation
            
            updatePOIS()
            self.firstBusArrivalLabel.text = "First bus in \(self.estimatedBusTimeArrival!/60) min \(self.estimatedBusTimeArrival!%60) s"
             self.travelDetailsView.hidden = false
        }
    }
    
    func updatePOIS(){
        if( self.destination != nil && self.userLocation != nil){
            self.destinationStation = self.findNearestStationFromLocation(self.destination!.coordinate).0
            var resTouple = self.findNearestApproachingBusFromStation(self.userNearestStation!)
            
            (self.busOfInterest, self.estimatedBusTimeArrival) = (resTouple.0, resTouple.1)
        
            if(self.userNearestStationAnnotation != nil){
                self.userNearestStationAnnotation?.coordinate = self.userNearestStation!.coordinates!
            }else {
                self.userNearestStationAnnotation = CustomPointAnnotation(imageName: "nearest-destination-station-icon")
                mapView.addAnnotation(self.userNearestStationAnnotation)
            }
            
            if(self.destinationAnotation != nil){
                self.destinationAnotation?.coordinate = self.destinationStation!.coordinates!
            }else {
                self.destinationAnotation = CustomPointAnnotation(imageName: "nearestStation")
                mapView.addAnnotation(self.destinationAnotation)
            }

            self.estimatedTimeToDestination = estimatedArrivelTime(self.busOfInterest!, pathObject2: self.destinationStation!)
            
            var coord = [CLLocationCoordinate2D]()
            coord.append(self.userLocation!.coordinate)
            for i in 0..<self.routeCoordinates.count{
                if(i >= self.userNearestStation!.pathIndex! && i <= self.destinationStation!.pathIndex!){
                    coord.append(self.routeCoordinates[i])
                }
            }
            coord.append(self.markerAnnotation!.coordinate)
            if(self.routOverlay != nil){
                mapView.removeOverlay(self.routOverlay)
            }
            self.routOverlay = MKPolyline(coordinates: &coord, count:  coord.count)
            self.routOverlay?.title = "travelRoute"
            mapView.addOverlay(self.routOverlay)
        } else{
            
        }
    }
    
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            
            if (overlay.title != nil && overlay.title == "travelRoute"){
                polylineRenderer.strokeColor = UIColor(red: 255/256, green: 255/256, blue: 10/256, alpha: 0.6)
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
                        self.stations.append(PathObject(pathObject:i))
                    }
                    
                    for index in 0..<self.stations.count{
                        var annotation = CustomPointAnnotation(imageName: "station")
                        annotation.coordinate = self.stations[index].coordinates!
                        self.mapView.addAnnotation(annotation)
                    }
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
                            var annotation = CustomPointAnnotation(imageName: "bus")
                            self.mapView.addAnnotation(annotation)
                            self.annotations.append(annotation)
                            annotation.coordinate =  self.busses[index].coordinates!
                            UIView.animateWithDuration(3.0, animations: { () -> Void in
                                annotation.coordinate = self.routeCoordinates[(self.busses[index].pathIndex! + 1)%620]
                            })
                        }
                    }
                    else{
                        for index in 0..<self.busses.count{
                            if(self.busOfInterest != nil && self.busses[index].id == self.busOfInterest!.id){
                                self.annotations[index].imageName = "bus-of-interest-icon"
                            }else{
                                self.annotations[index].imageName = "bus"
                            }
                            if (self.busses[index].pathIndex >= self.userNearestStation!.pathIndex){
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


