//
//  VerticalOpenSnapshotView.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 4. 10..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit

class VerticalOpenSnapshotView: UIImageView {
    
    public weak var targetView:UIView?
    
    static func createWith(_ view:UIView!) -> VerticalOpenSnapshotView? {
        guard let image = view.snapshotImage() else { return nil }
        
        let snapShotview = VerticalOpenSnapshotView(image:image)
        snapShotview.targetView = view
        
        return snapShotview
    }
    
}

extension UIView {
    fileprivate func snapshotImage() -> UIImage? {
        let size = CGSize(width:  floor(self.frame.size.width),
                          height: floor(self.frame.size.height))
        UIGraphicsBeginImageContextWithOptions(size, true, 0.0)
        if let context = UIGraphicsGetCurrentContext() { self.layer.render(in: context) }
        let snapshot = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return snapshot
    }
}
