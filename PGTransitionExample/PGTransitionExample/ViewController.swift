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
    private var innerViewcontroller:InnerViewController?
    
    @IBOutlet weak var bottomMenu: UIView!
    @IBOutlet weak var bottomContents: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        innerViewcontroller = InnerViewController()
        
        openTransition = VerticalOpenTransition(target: self, presenting: innerViewcontroller)
        openTransition!.openDelegate = self
        openTransition!.lowerViews = [bottomContents, bottomMenu]
        if let naviBar = self.navigationController?.navigationBar { openTransition!.raiseViews = [naviBar] }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        openTransition!.updateMaxDistance()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func raiseViewsWith(transition:VerticalOpenTransition) -> Array<UIView>? {
        if let naviBar = self.navigationController?.navigationBar {
            return [naviBar]
        }
        return nil
    }
    
    func lowerViewsWith(transition:VerticalOpenTransition) -> Array<UIView>? {
        var views = [UIView]()
        views.append(bottomContents)
        views.append(bottomMenu)
        return views
    }

}

