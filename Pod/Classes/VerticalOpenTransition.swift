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
    @objc optional
    func canPresentWith(transition:VerticalOpenTransition) -> Bool
    @objc optional
    func canDismissWith(transition:VerticalOpenTransition) -> Bool
    
    @objc optional
    func startPresentProcessWith(transition:VerticalOpenTransition, targetView:UIView?) -> Double
    @objc optional
    func startDismissProcessWith(transition:VerticalOpenTransition, targetView:UIView?) -> Double
    
    @objc optional
    func lockPresentVerticalOpenWith(transition:VerticalOpenTransition, distance:CGFloat, velocity:CGPoint, state:UIGestureRecognizerState) -> Bool
    @objc optional
    func lockDismissVerticalOpenWith(transition:VerticalOpenTransition, distance:CGFloat, velocity:CGPoint, state:UIGestureRecognizerState) -> Bool
    
    @objc optional
    func initialCenterViewWithVerticalOpen(transition:VerticalOpenTransition) -> UIView!
    @objc optional
    func destinationCnterViewWithVerticalOpen(transition:VerticalOpenTransition) -> UIView!
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
    private var canDismiss:Bool { return self.openDelegate?.canDismissWith?(transition: self) ?? true }
    
    private var raiseMaxDistance:CGFloat = 0
    private var lowerMaxDistance:CGFloat = 0
    private var maxDistance:CGFloat { return raiseMaxDistance > lowerMaxDistance ? raiseMaxDistance : lowerMaxDistance }
    private var initialCenterView:UIView? { return self.openDelegate?.initialCenterViewWithVerticalOpen?(transition: self) }
    private var destinationCenterView:UIView? { return self.openDelegate?.destinationCnterViewWithVerticalOpen?(transition: self) }
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
        
        raiseMaxDistance = 0
        lowerMaxDistance = 0
        
        raiseViews?.forEach {
            $0.maxOpenDistance = $0.convert(CGPoint(x:0, y:$0.frame.height), to: window).y
            if raiseMaxDistance < $0.maxOpenDistance { raiseMaxDistance = $0.maxOpenDistance }
        }
        
        lowerViews?.forEach {
            $0.maxOpenDistance = window.frame.height - $0.convert(CGPoint.zero, to: window).y
            if lowerMaxDistance < $0.maxOpenDistance { lowerMaxDistance = $0.maxOpenDistance }
        }
    }
    
    public func onPresentWith(gesture:UIPanGestureRecognizer) {
        guard let _ = self.presenting  else { return }
        guard isAnimated == false      else { return }
        guard canPresent == true       else { return }
        guard enablePresent == true    else { return }
        guard isPresented == false     else { return }
        
        guard let window = target.view.window else { return }
        
        let location = gesture.location(in: window)
        let velocity = gesture.velocity(in: window)

        didLocked = self.openDelegate?.lockPresentVerticalOpenWith?(transition: self,
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
            
        case .changed:
            self.presentOpenAction()
            
            let percentage = ((location.y - self.beganPanPoint.y) / maxDistance)
            
            self.update(percentage)
            
        case .ended:
            guard self.hasInteraction == true else {
                self.isAnimated = false
                return
            }
            
            self.isAnimated = true
            
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
        guard isAnimated == false   else { return }
        guard canDismiss == true    else { return }
        guard enableDismiss == true else { return }
        guard isPresented == true   else { return }
        
        guard let window = presenting!.view.window else { return }
        
        let location = gesture.location(in: window)
        let velocity = gesture.velocity(in: window)
        
        didLocked = self.openDelegate?.lockDismissVerticalOpenWith?(transition: self,
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
            
        case .changed:
            
            self.dismissAction()
            
            guard self.beganPanPoint.equalTo(.zero) == false else { return }
            
            let percentage = (self.beganPanPoint.y - location.y) / maxDistance
            
            self.update(percentage)
            
        case .ended:
            guard self.beganPanPoint.equalTo(.zero) == false else { return }
            
            guard hasInteraction == true else {
                self.isAnimated = false
                return
            }
            
            self.isAnimated = true
            
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

        let initCenterSnapShot = (self.onCenterFadeMode == true ? self.initialCenterView?.addOpenTransitionSnapshotAt(to.view, contentMode: .scaleAspectFill) : nil)
        
        let lowerSnapshots = self.lowerViews?.flatMap({ $0.addOpenTransitionSnapshotAt(to.view) })
        let raiseSnapshots = self.raiseViews?.flatMap({ $0.addOpenTransitionSnapshotAt(to.view) })
        
        let originToCenterFrame:CGRect?  = self.destinationCenterView?.frame
        let originToCenterBounds:CGRect? = self.destinationCenterView?.bounds
        
        if self.onCenterContentMode == true {
            self.destinationCenterView!.frame = self.initialCenterView!.frame
        }
        
        UIView.animateKeyframes(withDuration: self.transitionDuration(using: context), delay: 0, options: [], animations: {
            
            if (self.onCenterFadeMode == true) {
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.5, animations: { initCenterSnapShot!.alpha = 0 })
            }
            
            raiseSnapshots?.forEach {
                self.presentTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: -$0.maxOpenDistance) })
            }

            lowerSnapshots?.forEach {
                self.presentTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: $0.maxOpenDistance) })
            }
            
            if self.onCenterContentMode == true {
                if (self.onCenterFadeMode == true) { initCenterSnapShot!.frame = originToCenterFrame! }
                
                self.destinationCenterView!.frame  = originToCenterFrame!
                self.destinationCenterView!.bounds = originToCenterBounds!
            }
            
        }, completion: { _ in
            
            let canceled = context.transitionWasCancelled
            self.isAnimated = false
            to.modalPresentationStyle = self.openPresentationStyle

            self.raiseViews?.forEach { $0.alpha = 1 }
            self.lowerViews?.forEach { $0.alpha = 1 }
            self.initialCenterView?.alpha     = 1
            self.destinationCenterView?.alpha = 1
            
            initCenterSnapShot?.removeFromSuperview()
            raiseSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(from.view) }
            lowerSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(from.view) }
            
            if self.onCenterContentMode == true {
                self.destinationCenterView!.frame  = originToCenterFrame!
                self.destinationCenterView!.bounds = originToCenterBounds!
            }
            
            if canceled == true {
                self.current = self.target
                context.completeTransition(false)
            } else {
                self.current = self.presenting
                context.completeTransition(true)
                self.presentBlock?()
            }
            
            self.didActionStart = false
        })
    }
    
    private func dismissAnimation(from:UIViewController, to:UIViewController, container:UIView, context: UIViewControllerContextTransitioning) {
        
        let destCenterSnapShot = self.destinationCenterView?.addOpenTransitionSnapshotAt(from.view)
        let initCenterSnapshot = self.initialCenterView?.addOpenTransitionSnapshotAt(from.view, contentMode: .scaleAspectFill)
        let lowerSnapshots = self.lowerViews?.flatMap({ $0.addOpenTransitionSnapshotAt(from.view) })
        let raiseSnapshots = self.raiseViews?.flatMap({ $0.addOpenTransitionSnapshotAt(from.view) })
        
        raiseSnapshots?.forEach { $0.transform = CGAffineTransform(translationX: 0, y: -$0.maxOpenDistance) }
        lowerSnapshots?.forEach { $0.transform = CGAffineTransform(translationX: 0, y:  $0.maxOpenDistance) }
        
        if self.onCenterContentMode == true {
            initCenterSnapshot!.frame = destCenterSnapShot!.frame
            initCenterSnapshot?.alpha = 0
        }
        
        UIView.animateKeyframes(withDuration: self.transitionDuration(using: context), delay: 0, options: [], animations: {
            
            if (self.onCenterFadeMode == true) {
                UIView.addKeyframe(withRelativeStartTime: 0.8, relativeDuration: 1, animations: { initCenterSnapshot?.alpha = 1 })
            }
            
            raiseSnapshots?.forEach {
                self.dismissTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: 0) })
            }
            
            lowerSnapshots?.forEach {
                self.dismissTransform(view: $0, viewTransform: { $0.transform = CGAffineTransform(translationX: 0, y: 0) })
            }
            
            if self.onCenterContentMode == true {
                initCenterSnapshot!.frame  = self.initialCenterView!.frame
                destCenterSnapShot!.frame  = self.initialCenterView!.frame
                destCenterSnapShot!.bounds = self.initialCenterView!.frame
                destCenterSnapShot!.bounds.origin = CGPoint(x: self.destinationCenterView!.bounds.width/2  - self.initialCenterView!.frame.width/2,
                                                            y: self.destinationCenterView!.bounds.height/2 - self.initialCenterView!.frame.height/2)
            }
            
        }, completion: { _ in
            
            self.raiseViews?.forEach { $0.alpha = 1 }
            self.lowerViews?.forEach { $0.alpha = 1 }
            self.initialCenterView?.alpha = 1
            self.destinationCenterView?.alpha = 1
            
            raiseSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(to.view) }
            lowerSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(to.view) }
            destCenterSnapShot?.removeFromSuperview()
            initCenterSnapshot?.removeFromSuperview()
            
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
        super.update(max(0+0.0001, min(1-0.0001, percentComplete)))
    }
    
    private func presentTransform(view:UIView, viewTransform:@escaping (UIView) -> (Void)) {
        var startTime:Double = 0
        
        if let snapshot = view as? VerticalOpenSnapshotView {
            startTime = self.openDelegate?.startPresentProcessWith?(transition: self, targetView: snapshot.targetView) ?? 0
        } else {
            startTime = self.openDelegate?.startPresentProcessWith?(transition: self, targetView: view) ?? 0
        }
        
        UIView.addKeyframe(withRelativeStartTime: startTime, relativeDuration: 1, animations: {
            viewTransform(view)
        })
    }
    
    
    private func dismissTransform(view:UIView, viewTransform:@escaping (UIView) -> (Void)) {
        var startTime:Double = 0
        
        if let snapshot = view as? VerticalOpenSnapshotView {
            startTime = self.openDelegate?.startDismissProcessWith?(transition: self, targetView: snapshot.targetView) ?? 0
        } else {
            startTime = self.openDelegate?.startDismissProcessWith?(transition: self, targetView: view) ?? 0
        }
        
        UIView.addKeyframe(withRelativeStartTime: startTime, relativeDuration: 1, animations: {
            viewTransform(view)
        })
    }

    //MARK: - UIVieControllerTransitioningDelegate methods
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return self
    }
    
    public func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard self.hasInteraction == true else { return nil }
        return self
    }
    
    public func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        guard self.hasInteraction == true else { return nil }
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
        guard isAnimated == false     else { return }
        guard enablePresent == true   else { return }
        guard isPresented == false    else { return }
        guard percentComplete == 0    else { return }
        
        self.isAnimated = true
        
        presenting!.modalPresentationStyle = self.openPresentationStyle
        presenting!.transitioningDelegate  = self
        
        self.target.present(presenting!, animated: animated) { completion?() }
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
        guard isAnimated == false     else { return }
        guard enableDismiss == true   else { return }
        guard isPresented == true     else { return }
        guard percentComplete == 0    else { return }
        
        presenting!.modalPresentationStyle = self.openPresentationStyle
        presenting!.transitioningDelegate  = self
        
        self.isAnimated = true
        
        presenting!.dismiss(animated: animated) { completion?() }
    }
    
    @objc public func setPresentCompletion(block:VerticalOpenVoidBlock?) { self.presentBlock = block }
    @objc public func setDismissCompletion(block:VerticalOpenVoidBlock?) { self.dismissBlock = block }
}

private var maxOpenDistanceAssociatedKey: UInt8 = 0

extension UIView {
    public var maxOpenDistance:CGFloat! {
        get { return objc_getAssociatedObject(self, &maxOpenDistanceAssociatedKey) as? CGFloat }
        set(newValue) { objc_setAssociatedObject(self, &maxOpenDistanceAssociatedKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN) }
    }
    
    fileprivate func addOpenTransitionSnapshotAt(_ willSuperView:UIView, contentMode:UIViewContentMode? = .center) -> UIView? {
        guard self is UINavigationBar == false else {
            willSuperView.addSubview(self)
            return self
        }
        
        guard let snapshot = VerticalOpenSnapshotView.createWith(self) else { return nil }
        
        if let _ = self.maxOpenDistance { snapshot.maxOpenDistance = self.maxOpenDistance }
        
        let gap = max(0, willSuperView.frame.height - self.superview!.frame.height)
        
        snapshot.frame = self.frame
        snapshot.frame.origin.y += gap
        snapshot.contentMode = contentMode!
        willSuperView.addSubview(snapshot)
        self.alpha = 0
        return snapshot
    }
    
    fileprivate func removeOpenTransitionSnapshotAt(_ willSuperView:UIView) {
        guard self is UINavigationBar == false else {
            willSuperView.addSubview(self)
            return
        }
        self.removeFromSuperview()
    }
}

