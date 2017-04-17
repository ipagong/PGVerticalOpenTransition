//
//  VerticalOpenSnapshotView.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 4. 10..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit

public class VerticalOpenSnapshotView: UIImageView {
    
    public weak var targetView:UIView?
    
    public static func createWith(_ view:UIView!) -> VerticalOpenSnapshotView? {
        guard let image = self.snapshotImage(view) else { return nil }
        
        let snapShotview = VerticalOpenSnapshotView(image:image)
        snapShotview.targetView = view
        snapShotview.frame = view.frame
        
        return snapShotview
    }
    
    fileprivate static func snapshotImage(_ view:UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0)
        view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
        let snapshotImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return snapshotImage
    }
    
}
