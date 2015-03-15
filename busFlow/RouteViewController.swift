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
    var pressedLocation:CLLocation?
    var busses:[PathObject] = []
    var currentLocation:CLLocation?
    let urlBusses = "http://flowbus.eu-gb.mybluemix.net/api/busses"
    let urlBusStations = "http://flowbus.eu-gb.mybluemix.net/api/stations"
    var busStations:[PathObject] = []
    var annotations:[CustomPointAnnotation]=[]
    let locationManager = CLLocationManager()
    var distanceFromUserToNearestStation:CLLocationDistance?
    var distanceFromDestinationToNearestStation:CLLocationDistance?
    var userLocations:[CLLocation] = []
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(false)
        self.navigationController?.setNavigationBarHidden(true, animated: false)
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //just for presentation, hardcoded user location  because we cant update user location
        let spanX = 0.01
        let spanY = 0.01
        var hardcodedLocation:CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 43.8470823, longitude: 18.3741403)
        var newRegion = MKCoordinateRegion(center: hardcodedLocation, span: MKCoordinateSpanMake(spanX, spanY))
        var annotation = MKPointAnnotation()
        mapView.addAnnotation(annotation)
        annotation.coordinate = hardcodedLocation

        
    
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
        println(arrayOfCoordinates)
        
        for index in 0..<arrayOfCoordinates.count{
            var longlat = arrayOfCoordinates[index].componentsSeparatedByString(",")
            var latitude = (longlat[0] as NSString).doubleValue
            var longitude = (longlat[1] as NSString).doubleValue
            self.routeCoordinates.append(CLLocationCoordinate2D(latitude: longitude, longitude: latitude))
        }
        
        //setting mapView to match route
        var route = MKPolyline(coordinates: &self.routeCoordinates, count:  self.routeCoordinates.count)
        mapView.addOverlay(route)
        
        
        //send calls every 2 sec
        var helloWorldTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "refresh", userInfo: nil, repeats: true)
        getBusStations()
    }
    func mapView(mapView: MKMapView!, viewForAnnotation annotation: MKAnnotation!) -> MKAnnotationView! {
        if !(annotation is CustomPointAnnotation) {
            return nil
        }
        
        let reuseIconId = "busIcon"
        var annotationView = self.mapView.dequeueReusableAnnotationViewWithIdentifier(reuseIconId)
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseIconId)
            annotationView.canShowCallout = true
        }
        else {
            annotationView.annotation = annotation
        }
        let busAnnotation = annotation as CustomPointAnnotation
        annotationView.image = UIImage(named:busAnnotation.imageName!)
        return annotationView
    }

    
    func locationManager(manager:CLLocationManager, didUpdateLocations locations:[AnyObject]) {
        
        self.userLocations.append(locations[0] as CLLocation)
        let spanX = 0.007
        let spanY = 0.007
        if( self.userLocations.count == 1){
        var newRegion = MKCoordinateRegion(center: mapView.userLocation.coordinate, span: MKCoordinateSpanMake(spanX, spanY))
        mapView.setRegion(newRegion, animated: true)
        }
    }


    
    func longPressToGetLocation(gestureRecognizer:UILongPressGestureRecognizer){
        if(gestureRecognizer.state != UIGestureRecognizerState.Began){
            var pressPoint:CGPoint = gestureRecognizer.locationInView(self.mapView)
            var chosenLocation:CLLocationCoordinate2D = self.mapView.convertPoint(pressPoint, toCoordinateFromView: self.mapView)
            self.pressedLocation = CLLocation(latitude: chosenLocation.latitude, longitude: chosenLocation.latitude)
            var annotation = CustomPointAnnotation()
            annotation.coordinate = chosenLocation
            self.mapView.addAnnotation(annotation)
            annotation.imageName = "busStop"

                    }
    }
    
    

    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor(red: 71/256, green: 191/256, blue: 209/256, alpha: 1)
            polylineRenderer.lineWidth = 4
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
                        UIView.animateWithDuration(0.0, animations: { () -> Void in
                        })
                    }
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
                            self.annotations[index].coordinate =  self.routeCoordinates[self.busses[index].pathIndex!]
                            UIView.animateWithDuration(3.0, animations: { () -> Void in
                                self.annotations[index].coordinate = self.routeCoordinates[(self.busses[index].pathIndex! + 1)%620]
                            })
                        }
                    }
                }
        }
    }
}


