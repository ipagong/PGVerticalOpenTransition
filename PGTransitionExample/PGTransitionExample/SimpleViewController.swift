//
//  SimpleViewController.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 4. 10..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit

class SimpleViewController: UIViewController, VerticalOpenTransitionDelegate {

    private var openTransition:VerticalOpenTransition?
    private var detailVc:DetailViewController?
    
    @IBOutlet weak var top: UIView!
    @IBOutlet weak var bottom: UIView!
    @IBOutlet weak var open: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        detailVc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "SimpleDetail") as? DetailViewController

        openTransition = VerticalOpenTransition(target: self, presenting: detailVc)
        
        openTransition!.raiseViews = [top, open]
        openTransition!.lowerViews = [bottom]
        openTransition!.openDelegate = self
    
    }
    
    @IBAction func onClickDismiss(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let openSegue = segue as? VerticalOpenSegue {
            openSegue.transition = self.openTransition
        }
    }
    
    func destinationCnterViewWithVerticalOpen(transition: VerticalOpenTransition) -> UIView! {
        return detailVc?.imageView!
    }
    
}
