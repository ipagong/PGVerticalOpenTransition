//
//  InnerViewController.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 3. 28..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit
import MapKit

class InnerViewController: UIViewController, MKMapViewDelegate {
    
    @IBOutlet weak var mapview: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    public func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        debugPrint(mapView)
    }
    
    public func mapViewDidFailLoadingMap(_ mapView: MKMapView, withError error: Error) {
        debugPrint(error)
    }

    public func mapViewWillStartRenderingMap(_ mapView: MKMapView) {
        debugPrint(mapView)
    }
}
