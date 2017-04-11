//
//  VerticalOpenSegue.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 4. 10..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit

public class VerticalOpenSegue: UIStoryboardSegue {
    public weak var transition:VerticalOpenTransition?
    
    override public func perform() {
        guard let _ = transition?.presenting else { return }
        transition!.presentVerticalOpenViewController(animated: true)
    }
}
