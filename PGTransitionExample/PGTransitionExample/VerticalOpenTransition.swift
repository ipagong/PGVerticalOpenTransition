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
    
    @objc optional func verticalOpenTransitionPresentUpdated(transition:VerticalOpenTransition, updated:CGFloat) -> Void
    @objc optional func verticalOpenTransitionDismissUpdated(transition:VerticalOpenTransition, updated:CGFloat) -> Void
}

/*
 
 TODO-LIST:
 - 컨텐트뷰 중심인 상태로 펼쳐지게하기
 - 각 뷰의 펼쳐짐 시점이 다르게 동작.
 - 컨텐트 뷰가 여백이 남아있는 경우 오므라들기.
 - 메소드, 필드 네이밍 다듬기.
 */

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
    public var onDragging:Bool      = false //default false.
    public var hasHalfSnapping:Bool = false //default false.
    public var dismissTouchHeight:CGFloat = 200.0
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
    private var canPresent:Bool {
        guard ((raiseViews?.count ?? 0) + (lowerViews?.count ?? 0)) > 0 else { return false }
        return self.openDelegate?.canPresentWith?(transition: self) ?? true
    }
    private var canDismiss:Bool { return self.openDelegate?.canDismissWith?(transition: self) ?? true }
    
    private var maxDistance:CGFloat = 0
    
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
        guard isAnimated == false      else { return }
        guard canPresent == true       else { return }
        guard enablePresent == true    else { return }
        guard isPresented == false     else { return }
        
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
            
            self.openDelegate?.verticalOpenTransitionPresentUpdated?(transition: self, updated: percentage)
            
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
        
        switch gesture.state {
        case .began:
            
            guard location.y > (window.frame.height - self.dismissTouchHeight) else {
                self.beganPanPoint = .zero
                return
            }
            
            self.hasInteraction = true
            
            self.beganPanPoint = location
            self.dismissAction()
            
        case .changed:
            
            guard self.beganPanPoint.equalTo(.zero) == false else { return }
            
            let mY = max(0, self.beganPanPoint.y - location.y)
            let percentage = abs(mY / maxDistance)
            
            self.openDelegate?.verticalOpenTransitionDismissUpdated?(transition: self, updated: percentage)
            
            self.update(percentage)
            
        case .ended:
            guard self.beganPanPoint.equalTo(.zero) == false else { return }
            
            guard hasInteraction == true else {
                self.isAnimated = false
                return
            }
            
            self.isAnimated = true
            
            if (velocity.y < 0) {
                self.finish()
                self.current = self.target
            } else {
                self.cancel()
                self.current = self.presenting!
            }
            
            self.hasInteraction = false
            self.beganPanPoint  = .zero
            
        default:
            break
        }
    }
    
    
    private func presentAnimation(from:UIViewController, to:UIViewController, container:UIView, context: UIViewControllerContextTransitioning) {
        container.addSubview(to.view)
        
        if maxDistance == 0 { updateMaxDistance() }
        
        let raiseSnapshots = self.raiseViews?.flatMap({ $0.addOpenTransitionSnapshotAt(to.view) })
        let lowerSnapshots = self.lowerViews?.flatMap({ $0.addOpenTransitionSnapshotAt(to.view) })
        
        UIView.animate(withDuration: self.transitionDuration(using: context), animations: {
            
            raiseSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0 , y: -$0.maxOpenDistance)) }
            lowerSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0 , y:  $0.maxOpenDistance)) }
            
        }, completion: { _ in
            
            let canceled = context.transitionWasCancelled
            self.isAnimated = false
            to.modalPresentationStyle = self.openPresentationStyle
        
            self.raiseViews?.forEach { $0.alpha = 1 }
            self.lowerViews?.forEach { $0.alpha = 1 }
            
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
        
        let raiseSnapshots = self.raiseViews?.flatMap({ $0.addOpenTransitionSnapshotAt(from.view) })
        let lowerSnapshots = self.lowerViews?.flatMap({ $0.addOpenTransitionSnapshotAt(from.view) })
        
        raiseSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0, y: -$0.maxOpenDistance)) }
        lowerSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0, y:  $0.maxOpenDistance)) }
        
        UIView.animate(withDuration: self.transitionDuration(using: context), animations: {
            
            raiseSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0 , y: 0)) }
            lowerSnapshots?.forEach { $0.transitionAttachAt(nil, CGPoint(x:0 , y: 0)) }
            
        }, completion: { _ in
            
            self.raiseViews?.forEach { $0.alpha = 1 }
            self.lowerViews?.forEach { $0.alpha = 1 }
            
            raiseSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(to.view) }
            lowerSnapshots?.forEach { $0.removeOpenTransitionSnapshotAt(to.view) }
            
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
        guard let _ = presenting    else { return }
        guard canPresent == true    else { return }
        guard enablePresent == true else { return }
        guard percentComplete == 0  else { return }
        
        presenting!.modalPresentationStyle = self.openPresentationStyle
        presenting!.transitioningDelegate  = self
        
        self.target.present(presenting!, animated: true, completion: nil)
    }
    
    private func dismissAction() {
        guard canDismiss == true    else { return }
        guard enableDismiss == true else { return }
        guard percentComplete == 0  else { return }
        
        presenting!.dismiss(animated: true, completion: nil)
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
    fileprivate var maxOpenDistance:CGFloat! {
        get { return objc_getAssociatedObject(self, &maxOpenDistanceAssociatedKey) as? CGFloat }
        set(newValue) { objc_setAssociatedObject(self, &maxOpenDistanceAssociatedKey, newValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN) }
    }
    
    fileprivate func transitionAttachAt(_ willSuperView:UIView?, _ transformPoint:CGPoint? = CGPoint(x:0, y:0)) {
        if let _ = willSuperView { willSuperView!.addSubview(self) }
        self.transform = CGAffineTransform(translationX: transformPoint!.x, y: transformPoint!.y)
    }
    
    fileprivate func addOpenTransitionSnapshotAt(_ willSuperView:UIView) -> UIView? {
        guard self is UINavigationBar == false else {
            willSuperView.addSubview(self)
            return self
        }
        
        guard let snapshot = self.snapshotView(afterScreenUpdates: true) else {
            return nil
        }
        
        if let _ = self.maxOpenDistance { snapshot.maxOpenDistance = self.maxOpenDistance }
        
        let gap = max(0, willSuperView.frame.height - self.superview!.frame.height)
        
        snapshot.frame = self.frame
        snapshot.frame.origin.y += gap
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

class OpenVerticalSegue: UIStoryboardSegue {
    
    public weak var transition:VerticalOpenTransition?
    
    override func perform() {
        guard let transition = self.transition else { return }
        transition.presentVerticalOpenViewController(animated: true)
    }
}

