//
//  ViewController.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 3. 22..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit

class ViewController: UIViewController, VerticalOpenTransitionDelegate {

    private var openTransition:VerticalOpenTransition?
    private var innerVc:InnerViewController?
    
    @IBOutlet weak var bottomMenu: UIView!
    @IBOutlet weak var bottomContents: UIView!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var tableview: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        innerVc = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Detail") as? InnerViewController
        
        openTransition = VerticalOpenTransition(target: self, presenting: innerVc)
        openTransition!.openDelegate = self
        
        if let naviBar = self.navigationController?.navigationBar {
            openTransition!.raiseViews = [naviBar]
        }
        openTransition!.lowerViews = [bottomContents, bottomMenu]
        
        tableview.alwaysBounceVertical = false
    }
    
    @IBAction func onClickButton(_ sender: Any) {
        button.backgroundColor = (button.backgroundColor == .red ? .blue : .red)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let openSegue = segue as? OpenVerticalSegue {
            openSegue.transition = self.openTransition
        }
    }
}

