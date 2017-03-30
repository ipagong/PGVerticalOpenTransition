//
//  VerticalOpenTransition.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 3. 22..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit
import ObjectiveC

public typealias VerticalOpenVoidBlock = () -> ()

@objc
public protocol VerticalOpenTransitionDelegate : NSObjectProtocol {
    @objc optional func canPresentWith(transition:VerticalOpenTransition) -> Bool
    @objc optional func canDismissWith(transition:VerticalOpenTransition) -> Bool
    
    @objc optional func startPresentProcessWith(transition:VerticalOpenTransition, targetView:UIView) -> Bool
    @objc optional func startDismissProcessWith(transition:VerticalOpenTransition, targetView:UIView) -> Bool
    
    @objc optional func verticalOpenTransitionUpdated(transition:VerticalOpenTransition, updated:CGFloat) -> Void
}

@objc
public class VerticalOpenTransition: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate, UIGestureRecognizerDelegate {
    
    public var raiseViews:Array<UIView>? { didSet { updateMaxDistance() } }
    public var lowerViews:Array<UIView>? { didSet { updateMaxDistance() } }
    
    
    public private(set) var contentView:UIView?
    
    public var presentDuration:TimeInterval = 0.3
    public var dismissDuration:TimeInterval = 0.3
    
    public var onCenterContent:Bool = false //default false.
    public var onDragging:Bool      = false //default false.
    public var hasHalfSnapping:Bool = false //default false.
    public var snapHeight:CGFloat   = 150.0
    
    public weak var openDelegate:VerticalOpenTransitionDelegate?
    
    private var current:UIViewController?
    private weak var target:UIViewController!
    public weak var presenting:UIViewController? {
        willSet {
            guard self.isPresented == false else { return }
            guard self.presenting?.view.gestureRecognizers?.contains(self.dismissGesture) == true else { return }
            self.presenting?.view.removeGestureRecognizer(self.dismissGesture)
        }
        
        didSet {
            guard self.isPresented == false else {
                self.presenting = oldValue
                return
            }
            self.presenting?.view.addGestureRecognizer(self.dismissGesture)
        }
    }
    
    private var isAnimated:Bool     = false
    private var hasInteraction:Bool = false
    private var beganPanPoint:CGPoint = .zero
    private var openPresentationStyle:UIModalPresentationStyle { return .custom }
    private var presentBlock:VerticalOpenVoidBlock?
    private var dismissBlock:VerticalOpenVoidBlock?
    private var canPresent:Bool { return self.openDelegate?.canPresentWith?(transition: self) ?? true }
    private var canDismiss:Bool { return self.openDelegate?.canDismissWith?(transition: self) ?? true }
    private var maxDistance:CGFloat = 0
    
    @objc
    public init(target:UIViewController!) {
        super.init()
        
        self.target = target
        target.view.addGestureRecognizer(self.presentGesture)
    }
    
    @objc
    public init(target:UIViewController!, presenting:UIViewController!) {
        super.init()
        
        self.target = target
        target.view.addGestureRecognizer(self.presentGesture)
        
        self.presenting = presenting
        presenting.view.addGestureRecognizer(self.dismissGesture)
    }
    
    lazy private var presentGesture:UIPanGestureRecognizer = {
        let gesutre = UIPanGestureRecognizer(target: self, action: #selector(onPresentWith(gesture:)))
        gesutre.delegate = self
        return gesutre
    }()
    
    lazy private var dismissGesture:UIPanGestureRecognizer = {
        let gesutre = UIPanGestureRecognizer(target: self, action: #selector(onDismissWith(gesture:)))
        gesutre.delegate = self
        return gesutre
    }()
    
    private var isPresented:Bool {
//        guard let currentVc = self.current, currentVc != target else { return false }
        return true
    }
    
    public func updateMaxDistance() {
        
        guard let window = target.view.window else { return }
        
        maxDistance = 0
        
        for raise in raiseViews! {
            let viewMax = raise.convert(CGPoint(x:0, y:raise.frame.height), to: window).y
            raise.maxOpenDistance = viewMax
            if maxDistance < viewMax { maxDistance = viewMax }
        }
        
        for lower in lowerViews! {
            let viewMax = window.frame.height - lower.convert(CGPoint.zero, to: window).y
            lower.maxOpenDistance = viewMax
            if maxDistance < viewMax { maxDistance = viewMax }
        }
    }
    
    public func onPresentWith(gesture:UIPanGestureRecognizer) {

        guard isAnimated  == false else { return }
        guard canPresent  == true  else { return }
        guard isPresented == true  else { return }
        
        guard let window = target.view.window else { return }
        
        let location = gesture.location(in: window)
        let velocity = gesture.velocity(in: window)
        
        switch gesture.state {
        case .began:
            
            if maxDistance == 0 { updateMaxDistance() }
            
            self.beganPanPoint = location
            self.hasInteraction = true
            self.presentOpenAction()
            
        case .changed:
            
            let mY = self.beganPanPoint.y - location.y
            let percentage = abs(max(0,-mY) / maxDistance)
            
            self.openDelegate?.verticalOpenTransitionUpdated?(transition: self, updated: percentage)
            
            self.update(percentage)
            
        case .ended:
            guard self.hasInteraction == true else {
                self.isAnimated = false
                return
            }
            
            self.isAnimated = true
            
            if (velocity.y > 0) {
                self.finish()
            } else {
                self.cancel()
            }

            self.hasInteraction = false
            
        default:
            break
        }
        
    }
    
    public func onDismissWith(gesture:UIPanGestureRecognizer) {

    }
    
    
    private func presentAnimation(from:UIViewController, to:UIViewController, container:UIView, context: UIViewControllerContextTransitioning) {
        container.addSubview(to.view)
        container.frame = from.view.frame
        
        let raiseSnapshots = self.raiseViews?.flatMap({ $0.addOpenTransitionSnapshotAt(to.view) })
        let lowerSnapshots = self.lowerViews?.flatMap({ $0.addOpenTransitionSnapshotAt(to.view) })
        
        
        UIView.animate(withDuration: self.transitionDuration(using: context), animations: {
            
            raiseSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0 , y: -$0.maxOpenDistance)) }
            lowerSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0 , y:  $0.maxOpenDistance)) }
            
        }, completion: { _ in
            
            let canceled = context.transitionWasCancelled
            self.isAnimated = false
            to.modalPresentationStyle = self.openPresentationStyle
        
            self.raiseViews?.forEach { $0.isHidden = false }
            self.lowerViews?.forEach { $0.isHidden = false }
            
            raiseSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(from.view) }
            lowerSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(from.view) }
            
            if canceled == true {
                self.current = self.target
                context.completeTransition(false)
            } else {
                self.current = self.presenting
                context.completeTransition(true)
                self.presentBlock?()
            }
            
            
        })
    }
    
    private func dismissAnimation(from:UIViewController, to:UIViewController, container:UIView, context: UIViewControllerContextTransitioning) {

        UIView.animate(withDuration: self.transitionDuration(using: context), animations: {
            
        }, completion: { _ in
            
            let canceled = context.transitionWasCancelled
            self.isAnimated = false
            to.modalPresentationStyle = self.openPresentationStyle
            
            if canceled == true {
                self.current = self.presenting
                context.completeTransition(false)
            } else {
                self.current = self.target
                context.completeTransition(true)
                self.dismissBlock?()
            }
            
        })
    }
    
    private func presentOpenAction() {
        guard let presenting = self.presenting else { return }
//        guard canPresent == true       else { return }
//        guard enablePresent == true    else { return }
        guard percentComplete == 0     else { return }
        
        presenting.modalPresentationStyle = self.openPresentationStyle
        presenting.transitioningDelegate  = self
        
        self.target.present(presenting, animated: true, completion: nil)
    }
    
    //MARK: - UIVieControllerTransitioningDelegate methods
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
//        guard self.hasInteraction == true else { return nil }
        return self
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
//        guard self.hasInteraction == true else { return nil }
        return self
    }
    
    //MARK: - UIViewControllerAnimatedTransitioning methods
    
    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPresented ? dismissDuration : presentDuration
    }
    
    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        guard let fromVc = transitionContext.viewController(forKey: .from) else { return }
        guard let toVc   = transitionContext.viewController(forKey: .to)   else { return }
        
        if (toVc === self.presenting) {
            self.presentAnimation(from: fromVc, to: toVc, container: transitionContext.containerView, context: transitionContext)
        } else {
            self.dismissAnimation(from: fromVc, to: toVc, container: transitionContext.containerView, context: transitionContext)
        }
    }
    
    //MARK: - public methods
    
    @objc public func setPresentCompletion(block:VerticalOpenVoidBlock?) { self.presentBlock = block }
    @objc public func setDismissCompletion(block:VerticalOpenVoidBlock?) { self.dismissBlock = block }
}

private var maxOpenDistanceAssociatedKey: UInt8 = 0

extension UIView {
    var maxOpenDistance:CGFloat! {
        get {
            return objc_getAssociatedObject(self, &maxOpenDistanceAssociatedKey) as? CGFloat
        }
        set(newValue) {
            objc_setAssociatedObject(self, &maxOpenDistanceAssociatedKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func transitionAttachAt(_ willSuperView:UIView?, _ transformPoint:CGPoint? = CGPoint(x:0, y:0)) {
        if let _ = willSuperView { willSuperView!.addSubview(self) }
        self.transform = CGAffineTransform(translationX: transformPoint!.x, y: transformPoint!.y)
    }
    
    func addOpenTransitionSnapshotAt(_ willSuperView:UIView) -> UIView? {
        if self is UINavigationBar {
            willSuperView.addSubview(self)
            return self
        }
        
        guard let snapshot = self.snapshotView(afterScreenUpdates: true) else { return nil }
        
        if let _ = self.maxOpenDistance { snapshot.maxOpenDistance = self.maxOpenDistance }
        
        snapshot.frame = self.frame
        willSuperView.addSubview(snapshot)
        self.isHidden = true
        return snapshot
    }
    
    func removeOpenTransitionSnapshotAt(_ willSuperView:UIView) {
        if self is UINavigationBar {
            willSuperView.addSubview(self)
            return
        }
        self.removeFromSuperview()
    }
}

