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

class RouteViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapView: MKMapView!
    var routeCoordinates:[CLLocationCoordinate2D] = []
    var busses:[PathObject] = []
    var currentLocation:CLLocation?
    let urlBusses = "http://flowbus.eu-gb.mybluemix.net/api/busses"
    let urlBusStations = "http://flowbus.eu-gb.mybluemix.net/api/stations"
    var busStations:[PathObject] = []
    var annotations:[CustomPointAnnotation]=[]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        mapView.mapType = MKMapType.Hybrid
        
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
        var polygon: MKPolygon = MKPolygon(coordinates: &self.routeCoordinates, count:  self.routeCoordinates.count)
        var route = MKPolyline(coordinates: &self.routeCoordinates, count:  self.routeCoordinates.count)
        mapView.addOverlay(route)
        
        UIView.animateWithDuration(1.5, animations: { () -> Void in
            self.mapView.setVisibleMapRect(polygon.boundingMapRect, edgePadding: UIEdgeInsetsMake(20.0, 20.0, 20.0, 230.0), animated: true)
        })
        //send calls every 2 sec
        var helloWorldTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: "refresh", userInfo: nil, repeats: true)
        getBusStations()
    }
    
    //custom anotation
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
    
    func mapView(mapView: MKMapView!, rendererForOverlay overlay: MKOverlay!) -> MKOverlayRenderer! {
        if overlay is MKPolyline {
            var polylineRenderer = MKPolylineRenderer(overlay: overlay)
            polylineRenderer.strokeColor = UIColor(red: 71/256, green: 191/256, blue: 209/256, alpha: 1)
            polylineRenderer.lineWidth = 1
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
                    NSLog("Success: \(self.urlBusStations)")
                    var jsonBusStations = JSON(json!).arrayValue
                    for i in jsonBusStations {
                        self.busStations.append(PathObject(pathObject:i))
                    }
                    
                    for index in 0..<self.busStations.count{
                        var annotation = MKPointAnnotation()
                        annotation.coordinate = self.routeCoordinates[self.busStations[index].pathIndex!]
                        self.mapView.addAnnotation(annotation)
                        //annotation.imageName = "busIcon"
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
                    NSLog("Success: \(self.urlBusses)")
                    var jsonBusses = JSON(json!).arrayValue
                    self.busses.removeAll(keepCapacity: true)
                    for i in jsonBusses {
                        self.busses.append(PathObject(pathObject:i))
                    }
                    
                    if(self.annotations.count != self.busses.count){
                        for index in 0..<self.busses.count{
                            var annotation = CustomPointAnnotation()
                            self.mapView.addAnnotation(annotation)
                            annotation.imageName = "busIcon"
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


