//
//  ViewController.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 3. 22..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit
import MapKit

class ViewController: UIViewController, VerticalOpenTransitionDelegate {

    private var openTransition:VerticalOpenTransition?
    private var innerVc:InnerViewController?
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var bottomMenu: UIView!
    @IBOutlet weak var bottomContents: UIView!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var tableview: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableview.alwaysBounceVertical = false
        
        innerVc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Detail") as? InnerViewController
        updateTransitionViews()
    }
    
    @IBAction func onClickButton(_ sender: Any) {
        button.backgroundColor = (button.backgroundColor == .red ? .blue : .red)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let openSegue = segue as? OpenVerticalSegue {
            openSegue.transition = self.openTransition
        }
    }
    
    func updateTransitionViews() {
        
        openTransition = VerticalOpenTransition(target: self, presenting: innerVc)
        openTransition!.openDelegate = self
        openTransition!.onCenterContent = true
        openTransition!.onCenterFade = true
        
        openTransition!.lowerViews = [bottomContents, bottomMenu]
        guard let _ = navigationController?.navigationBar else { return }
        openTransition!.raiseViews = [navigationController!.navigationBar]
    }
    
    func initialCenterViewWithVerticalOpen(transition:VerticalOpenTransition) -> UIView! {
        return self.mapView
    }
    
    func destinationCnterViewWithVerticalOpen(transition:VerticalOpenTransition) -> UIView! {
        return self.innerVc!.mapview
    }
}

