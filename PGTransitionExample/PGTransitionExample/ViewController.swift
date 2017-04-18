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
        
        innerVc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Inner") as? InnerViewController
        
        updateTransitionViews()
    }
    
    @IBAction func onClickButton(_ sender: Any) {
        button.backgroundColor = (button.backgroundColor == .red ? .blue : .red)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let openSegue = segue as? VerticalOpenSegue {
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
    
    func initialCenterViewWith(transition:VerticalOpenTransition) -> UIView! {
        return self.mapView
    }
    
    func destinationCnterViewWith(transition:VerticalOpenTransition) -> UIView! {
        return self.innerVc!.mapview
    }
    
    func lockPresentWith(transition:VerticalOpenTransition, distance:CGFloat, velocity:CGPoint, state:UIGestureRecognizerState) -> Bool {
        return false
    }
    
    func lockDismissWith(transition:VerticalOpenTransition, distance:CGFloat, velocity:CGPoint, state:UIGestureRecognizerState) -> Bool {
        return false
    }
    
    func startPresentProcessWith(transition:VerticalOpenTransition, targetView:UIView?) -> Double {
        if (targetView == self.navigationController?.navigationBar) { return 0.6 }
        if (targetView == self.bottomMenu) { return 0.6 }
        return 0
    }
    
    func startDismissProcessWith(transition:VerticalOpenTransition, targetView:UIView?) -> Double {
        if (targetView == self.navigationController?.navigationBar) { return 0.4 }
        if (targetView == self.bottomMenu) { return 0.4 }
        return 0
    }
}

