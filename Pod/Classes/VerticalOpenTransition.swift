//
//  VerticalOpenTransition.swift
//  PGTransitionExample
//
//  Created by ipagong on 2017. 3. 22..
//  Copyright © 2017년 ipagong. All rights reserved.
//

import UIKit
import ObjectiveC

public typealias VerticalOpenVoidBlock = (Bool) -> ()

@objc
public protocol VerticalOpenTransitionDelegate : NSObjectProtocol {
    @objc optional
    func canPresentWith(transition:VerticalOpenTransition) -> Bool
    @objc optional
    func canDismissWith(transition:VerticalOpenTransition) -> Bool
    
    @objc optional
    func startPresentProcessWith(transition:VerticalOpenTransition, targetView:UIView?) -> Double
    @objc optional
    func startDismissProcessWith(transition:VerticalOpenTransition, targetView:UIView?) -> Double
    
    @objc optional
    func lockPresentWith(transition:VerticalOpenTransition, distance:CGFloat, velocity:CGPoint, state:UIGestureRecognizerState) -> Bool
    @objc optional
    func lockDismissWith(transition:VerticalOpenTransition, distance:CGFloat, velocity:CGPoint, state:UIGestureRecognizerState) -> Bool
    
    @objc optional
    func initialCenterViewWith(transition:VerticalOpenTransition) -> UIView!
    @objc optional
    func destinationCnterViewWith(transition:VerticalOpenTransition) -> UIView!
    
    
    @objc optional
    func customAnimationSetupWith(transition:VerticalOpenTransition, type:VerticalOpenTransition.TransitionType, time:VerticalOpenTransition.AnimationTime, from:UIView, to:UIView)
}

@objc
public class VerticalOpenTransition: UIPercentDrivenInteractiveTransition, UIViewControllerAnimatedTransitioning, UIViewControllerTransitioningDelegate, UIGestureRecognizerDelegate {
    
    public var raiseViews:Array<UIView>? { didSet { updateMaxDistance() } }
    public var lowerViews:Array<UIView>? { didSet { updateMaxDistance() } }
    
    public private(set) var contentView:UIView?
    
    public var enablePresent:Bool = true
    public var enableDismiss:Bool = true
    
    public var presentDuration:TimeInterval = 0.3
    public var dismissDuration:TimeInterval = 0.3
    
    public var onCenterContent:Bool = false //default false.
    public var onCenterFade:Bool    = true //default true.
    public var dismissTouchHeight:CGFloat = 200.0
    
    public weak var openDelegate:VerticalOpenTransitionDelegate?
    
    public weak var target:UIViewController!
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

    private var current:UIViewController?
    private var hasInteraction:Bool = false
    private var didActionStart:Bool = false
    private var didLocked:Bool? {
        willSet {
            if newValue == true && didLocked == false { self.cancel() }
        }
    }
    
    private var beganPanPoint:CGPoint = .zero
    private var openPresentationStyle:UIModalPresentationStyle { return .custom }
    private var presentBlock:VerticalOpenVoidBlock?
    private var dismissBlock:VerticalOpenVoidBlock?
    
    private var canPresent:Bool {
        guard ((raiseViews?.count ?? 0) + (lowerViews?.count ?? 0)) > 0 else { return false }
        return self.openDelegate?.canPresentWith?(transition: self) ?? true
    }
    
    private var canDismiss:Bool {
        return self.openDelegate?.canDismissWith?(transition: self) ?? true
    }
    
    
    private var maxDistance:CGFloat = 0
    private var initialCenterView:UIView? { return self.openDelegate?.initialCenterViewWith?(transition: self) }
    private var initialCenterViewFrame:CGRect?
    private var initialCenterViewBounds:CGRect?
    
    private var destinationCenterView:UIView? { return self.openDelegate?.destinationCnterViewWith?(transition: self) }
    private var destinationCenterViewFrame:CGRect?
    private var destinationCenterViewBounds:CGRect?
    
    private var raiseSnapshots:Array<VerticalOpenSnapshotView>?
    private var lowerSnapshots:Array<VerticalOpenSnapshotView>?
    private var initialCenterSnapshot:VerticalOpenSnapshotView?
    private var destinationCenterSnapshot:VerticalOpenSnapshotView?
    
    
    private var onCenterContentMode:Bool {
        guard self.onCenterContent == true else { return false }
        guard let _ = self.initialCenterView  else { return false }
        guard let _ = self.destinationCenterView    else { return false }
        return true
    }
    
    private var onCenterFadeMode:Bool {
        guard onCenterContentMode == true else { return false }
        return onCenterFade
    }
    
    @objc
    override init() { super.init() }
    
    @objc
    public init(target:UIViewController!) {
        super.init()
        
        self.target  = target
        target.view.addGestureRecognizer(self.presentGesture)
        self.current = target
    }
    
    @objc
    public init(target:UIViewController!, presenting:UIViewController!) {
        super.init()
        
        self.target = target
        target.view.addGestureRecognizer(self.presentGesture)
        
        self.presenting = presenting
        presenting.view.addGestureRecognizer(self.dismissGesture)
        
        self.current = target
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
    
    private var isPresented:Bool { return current != target }
    
    private func updateMaxDistance() {
        
        guard let window = target.view.window else { return }
        
        maxDistance = 0
        
        raiseViews?.forEach {
            $0.maxOpenDistance = $0.convert(CGPoint(x:0, y:$0.frame.height), to: window).y
            if maxDistance < $0.maxOpenDistance { maxDistance = $0.maxOpenDistance }
        }
        
        lowerViews?.forEach {
            $0.maxOpenDistance = window.frame.height - $0.convert(CGPoint.zero, to: window).y
            if maxDistance < $0.maxOpenDistance { maxDistance = $0.maxOpenDistance }
        }
    }
    
    public func onPresentWith(gesture:UIPanGestureRecognizer) {
        guard let _ = self.presenting  else { return }
        guard canPresent == true       else { return }
        guard enablePresent == true    else { return }
        guard isPresented == false     else { return }
        
        guard let window = target.view.window else { return }
        
        let location = gesture.location(in: window)
        let velocity = gesture.velocity(in: window)

        didLocked = self.openDelegate?.lockPresentWith?(transition: self,
                                                        distance: location.y - self.beganPanPoint.y,
                                                        velocity: velocity,
                                                        state: gesture.state)
        
        if gesture.state != .began && didLocked == true { return }
        
        switch gesture.state {
        case .began:
            
            if maxDistance == 0 { updateMaxDistance() }
            
            self.beganPanPoint = location
            self.didLocked = nil
            
            self.hasInteraction = true
            
            updateSnapshots()
            
        case .changed:
            let percentage = ((location.y - self.beganPanPoint.y) / maxDistance)
            
            if (percentage > 0) {
                self.presentOpenAction()
                
            }
            
            self.update(percentage)
            
        case .ended:
            guard self.hasInteraction == true else {
                return
            }
            
            if (self.didLocked == true) {
                self.cancel()
            } else if (velocity.y > 0) {
                self.finish()
            } else {
                self.cancel()
            }

            self.hasInteraction = false
            self.beganPanPoint  = .zero
        default:
            break
        }
    }
    
    public func onDismissWith(gesture:UIPanGestureRecognizer) {
        guard let _ = presenting    else { return }
        guard canDismiss == true    else { return }
        guard enableDismiss == true else { return }
        guard isPresented == true   else { return }
        
        guard let window = presenting!.view.window else { return }
        
        let location = gesture.location(in: window)
        let velocity = gesture.velocity(in: window)
        
        didLocked = self.openDelegate?.lockDismissWith?(transition: self,
                                                        distance: self.beganPanPoint.y - location.y,
                                                        velocity: velocity,
                                                        state: gesture.state)
        
        if gesture.state != .began && didLocked == true { return }
        
        switch gesture.state {
        case .began:
            
            guard location.y > (window.frame.height - self.dismissTouchHeight) else {
                self.beganPanPoint = .zero
                return
            }
            
            self.hasInteraction = true
            
            self.beganPanPoint = location
            self.didLocked = nil
            
            updateSnapshots()
            
        case .changed:
            
            guard self.beganPanPoint.equalTo(.zero) == false else { return }
            
            
            let percentage = (self.beganPanPoint.y - location.y) / maxDistance
            
            if (percentage > 0) { self.dismissAction() }
            
            self.update(percentage)
            
        case .ended:
            guard self.beganPanPoint.equalTo(.zero) == false else { return }
            
            guard hasInteraction == true else {
                return
            }
            
            if (self.didLocked == true) {
                self.cancel()
            } else if (velocity.y < 0) {
                self.finish()
            } else {
                self.cancel()
            }
            
            self.hasInteraction = false
            self.beganPanPoint  = .zero
            
        default:
            break
        }
    }
    
    private func presentAnimation(from:UIViewController, to:UIViewController, container:UIView, context: UIViewControllerContextTransitioning) {
        
        container.addSubview(to.view)
        
        to.view.setNeedsLayout()
        to.view.layoutIfNeeded()
        
        if maxDistance == 0 { updateMaxDistance() }

        if (self.onCenterFadeMode == true) {
            self.initialCenterSnapshot?.addOpenTransitionAt(to.view, contentMode: .scaleAspectFill)
        }
        
        if self.onCenterContentMode == true {
            self.destinationCenterView!.frame  = self.initialCenterViewFrame!
            self.destinationCenterView!.bounds = self.initialCenterViewBounds!
        }
        
        self.lowerSnapshots?.forEach({ $0.addOpenTransitionAt(to.view) })
        self.raiseSnapshots?.forEach({ $0.addOpenTransitionAt(to.view) })
        
        self.raiseViews?.forEach { $0.alpha = 0 }
        self.lowerViews?.forEach { $0.alpha = 0 }
        self.initialCenterView?.alpha = 0
        
        self.openDelegate?.customAnimationSetupWith?(transition: self, type: .present, time: .previous, from: from.view, to: to.view)

        UIView.animateKeyframes(withDuration: self.transitionDuration(using: context), delay: 0, options: [], animations: {

            if (self.onCenterFadeMode == true) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: { self.initialCenterSnapshot!.alpha = 0 })
            }
            
            self.raiseSnapshots?.forEach {
                self.presentTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: -$0.maxOpenDistance) })
            }

            self.lowerSnapshots?.forEach {
                self.presentTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: $0.maxOpenDistance) })
            }
            
            if (self.onCenterFadeMode == true) {
                self.initialCenterSnapshot!.frame = self.destinationCenterViewFrame!
            }
            
            if self.onCenterContentMode == true {
                self.destinationCenterView!.bounds = self.destinationCenterViewBounds!
                self.destinationCenterView!.frame  = self.destinationCenterViewFrame!
            }
            
            self.initialCenterSnapshot?.alpha = 0
            
            self.openDelegate?.customAnimationSetupWith?(transition: self, type: .present, time: .animated, from: from.view, to: to.view)

        }, completion: { _ in
            
            let canceled = context.transitionWasCancelled
            
            self.openDelegate?.customAnimationSetupWith?(transition: self, type: .present, time: canceled ? .canceled : .completed, from: from.view, to: to.view)
            
            self.raiseViews?.forEach { $0.alpha = 1 }
            self.lowerViews?.forEach { $0.alpha = 1 }
            self.initialCenterView?.alpha = 1
            
            if self.onCenterContentMode == true {
                self.destinationCenterView!.bounds = self.destinationCenterViewBounds!
                self.destinationCenterView!.frame  = self.destinationCenterViewFrame!
            }
            
            to.modalPresentationStyle = self.openPresentationStyle

            self.initialCenterSnapshot?.removeFromSuperview()
            self.destinationCenterSnapshot?.removeFromSuperview()
            self.raiseSnapshots?.forEach { $0.removeFromSuperview() }
            self.lowerSnapshots?.forEach { $0.removeFromSuperview() }

            if canceled == true {
                self.current = self.target
                context.completeTransition(false)
            } else {
                self.current = self.presenting
                context.completeTransition(true)
            }

            self.presentBlock?(!canceled)
            self.didActionStart = false
        })
    }
    
    private func dismissAnimation(from:UIViewController, to:UIViewController, container:UIView, context: UIViewControllerContextTransitioning) {
        
        to.view.setNeedsLayout()
        to.view.layoutIfNeeded()
        
        self.destinationCenterSnapshot?.addOpenTransitionAt(from.view)
        self.initialCenterSnapshot?.addOpenTransitionAt(from.view, contentMode: .scaleAspectFill)
        
        self.lowerSnapshots?.forEach{
            $0.addOpenTransitionAt(from.view)
            $0.transform = CGAffineTransform(translationX: 0, y:  $0.maxOpenDistance)
        }
        self.raiseSnapshots?.forEach{
            $0.addOpenTransitionAt(from.view)
            $0.transform = CGAffineTransform(translationX: 0, y: -$0.maxOpenDistance)
        }
        
        if self.onCenterContentMode == true {
            initialCenterSnapshot!.frame = destinationCenterView!.frame
            initialCenterSnapshot?.alpha = 0
        }
        
        self.raiseViews?.forEach { $0.alpha = 0 }
        self.lowerViews?.forEach { $0.alpha = 0 }
        self.destinationCenterView?.alpha = 0
        
        self.openDelegate?.customAnimationSetupWith?(transition: self, type: .dismiss, time: .previous, from: from.view, to: to.view)
        
        UIView.animateKeyframes(withDuration: self.transitionDuration(using: context), delay: 0, options: [], animations: {
            
            if (self.onCenterFadeMode == true) {
                UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 1, animations: { self.initialCenterSnapshot?.alpha = 1 })
            }
            
            self.raiseSnapshots?.forEach {
                self.dismissTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: 0) })
            }
            
            self.lowerSnapshots?.forEach {
                self.dismissTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: 0) })
            }
            
            if self.onCenterContentMode == true {
                self.initialCenterSnapshot!.frame      = self.initialCenterView!.frame
                self.destinationCenterSnapshot!.frame  = self.initialCenterView!.frame
                self.destinationCenterSnapshot!.bounds = self.initialCenterView!.frame
                self.destinationCenterSnapshot!.bounds.origin = CGPoint(x: self.destinationCenterView!.bounds.width/2  - self.initialCenterView!.frame.width/2,
                                                                        y: self.destinationCenterView!.bounds.height/2 - self.initialCenterView!.frame.height/2)
            }
            
            self.openDelegate?.customAnimationSetupWith?(transition: self, type: .dismiss, time: .animated, from: from.view, to: to.view)
            
        }, completion: { _ in
            
            let canceled = context.transitionWasCancelled
            
            self.openDelegate?.customAnimationSetupWith?(transition: self, type: .dismiss, time: canceled ? .canceled : .completed, from: from.view, to: to.view)
            
            self.raiseViews?.forEach { $0.alpha = 1 }
            self.lowerViews?.forEach { $0.alpha = 1 }
            self.destinationCenterView?.alpha = 1
            
            self.raiseSnapshots?.forEach { $0.removeFromSuperview() }
            self.lowerSnapshots?.forEach { $0.removeFromSuperview() }
            self.destinationCenterSnapshot?.removeFromSuperview()
            self.initialCenterSnapshot?.removeFromSuperview()
            
            to.modalPresentationStyle = self.openPresentationStyle
            
            if canceled == true {
                self.current = self.presenting
                context.completeTransition(false)
            } else {
                self.current = self.target
                context.completeTransition(true)
            }
            
            self.dismissBlock?(!canceled)
            self.didActionStart = false
        })
    }
    
    private func presentOpenAction() {
        guard let _ = presenting      else { return }
        guard canPresent == true      else { return }
        guard enablePresent == true   else { return }
        guard percentComplete == 0    else { return }
        guard didActionStart == false else { return }
        
        self.didActionStart = true
        
        presenting!.modalPresentationStyle = self.openPresentationStyle
        presenting!.transitioningDelegate  = self
        
        self.target.present(presenting!, animated: true, completion: nil)
    }
    
    private func dismissAction() {
        guard canDismiss == true    else { return }
        guard enableDismiss == true else { return }
        guard percentComplete == 0  else { return }
        guard didActionStart == false else { return }
        
        self.didActionStart = true
        
        presenting!.dismiss(animated: true, completion: nil)
    }
    
    override public func finish() {
        guard didActionStart else { return }
        super.finish()
    }
    
    override public func cancel() {
        guard didActionStart else { return }
        super.cancel()
    }
    
    override public func update(_ percentComplete: CGFloat) {
        guard percentComplete > 0 else { return }
        guard percentComplete < 1 else { return }
        super.update(percentComplete)
    }
    
    private func presentTransform(view:VerticalOpenSnapshotView, viewTransform:@escaping (UIView) -> (Void)) {
        let startTime = self.openDelegate?.startPresentProcessWith?(transition: self, targetView: view.targetView ) ?? 0.0
        UIView.addKeyframe(withRelativeStartTime: startTime, relativeDuration: 1, animations: { viewTransform(view) })
    }

    private func dismissTransform(view:VerticalOpenSnapshotView, viewTransform:@escaping (UIView) -> (Void)) {
        let startTime = self.openDelegate?.startDismissProcessWith?(transition: self, targetView: view.targetView) ?? 0.0
        UIView.addKeyframe(withRelativeStartTime: startTime, relativeDuration: 1, animations: { viewTransform(view) })
    }
    
    private func createTransitionSnapshot(_ targetView:UIView?, afterScreenUpdates update:Bool? = false) -> VerticalOpenSnapshotView? {
        guard let  _  = targetView else { return nil }
        
        guard let snapshot = VerticalOpenSnapshotView.createWith(targetView!, afterScreenUpdates: update) else { return nil }
        
        snapshot.maxOpenDistance = targetView!.maxOpenDistance
        
        return snapshot
    }
    
    private func updateSnapshots() {
        destinationCenterSnapshot = self.createTransitionSnapshot(self.destinationCenterView)
        destinationCenterViewFrame = self.destinationCenterView?.frame
        destinationCenterViewBounds = self.destinationCenterView?.bounds
        
        initialCenterSnapshot = self.createTransitionSnapshot(self.initialCenterView)
        initialCenterViewFrame = self.initialCenterView?.frame
        initialCenterViewBounds = self.initialCenterView?.bounds
        
        lowerSnapshots = self.lowerViews?.flatMap({ self.createTransitionSnapshot($0) })
        raiseSnapshots = self.raiseViews?.flatMap({ self.createTransitionSnapshot($0) })
    }

    //MARK: - UIVieControllerTransitioningDelegate methods
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return (self.hasInteraction == true ? self : nil)
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return (self.hasInteraction == true ? self : nil)
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
    
    @objc
    public func presentVerticalOpenViewController() {
        self.presentVerticalOpenViewController(animated: true, completion: nil)
    }
    
    @objc
    public func presentVerticalOpenViewController(animated:Bool) {
        self.presentVerticalOpenViewController(animated: animated, completion: nil)
    }
    
    @objc
    public func presentVerticalOpenViewController(animated:Bool, completion:VerticalOpenVoidBlock?) {
        guard let _ = self.presenting else { return }
        guard canPresent == true      else { return }
        guard enablePresent == true   else { return }
        guard isPresented == false    else { return }
        guard percentComplete == 0    else { return }
        
        updateSnapshots()
        
        presenting!.modalPresentationStyle = self.openPresentationStyle
        presenting!.transitioningDelegate  = self
        
        self.target.present(presenting!, animated: animated) { completion?(true) }
    }
    
    @objc
    public func dismissVerticalOpenViewController() {
        self.dismissVerticalOpenViewController(animated: true, completion: nil)
    }
    
    @objc
    public func dismissVerticalOpenViewController(animated:Bool) {
        self.dismissVerticalOpenViewController(animated: animated, completion: nil)
    }
    
    @objc
    public func dismissVerticalOpenViewController(animated:Bool, completion:VerticalOpenVoidBlock?) {
        guard let _ = self.presenting else { return }
        guard canDismiss == true      else { return }
        guard enableDismiss == true   else { return }
        guard isPresented == true     else { return }
        guard percentComplete == 0    else { return }
        
        updateSnapshots()
        
        presenting!.modalPresentationStyle = self.openPresentationStyle
        presenting!.transitioningDelegate  = self
    
        presenting!.dismiss(animated: animated) { completion?(true) }
    }
    
    @objc public func setPresentCompletion(block:VerticalOpenVoidBlock?) { self.presentBlock = block }
    @objc public func setDismissCompletion(block:VerticalOpenVoidBlock?) { self.dismissBlock = block }
}

private var maxOpenDistanceAssociatedKey: UInt8 = 0

extension UIView {
    public var maxOpenDistance:CGFloat {
        get { return objc_getAssociatedObject(self, &maxOpenDistanceAssociatedKey) as? CGFloat ?? 0 }
        set(newValue) { objc_setAssociatedObject(self, &maxOpenDistanceAssociatedKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN) }
    }
}

extension VerticalOpenTransition {
    @objc
    public enum TransitionType : NSInteger {
        case present
        case dismiss
    }
    
    @objc
    public enum AnimationTime : NSInteger {
        case previous
        case animated
        case completed
        case canceled
    }
}
