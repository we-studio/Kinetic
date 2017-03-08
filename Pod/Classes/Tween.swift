//
//  Tween.swift
//  Kinetic
//
//  Created by Nicholas Shipes on 12/18/15.
//  Copyright © 2015 Urban10 Interactive, LLC. All rights reserved.
//

import UIKit

public enum AnchorPoint {
	case `default`
	case center
	case top
	case topLeft
	case topRight
	case bottom
	case bottomLeft
	case bottomRight
	case left
	case right
	
	public func point() -> CGPoint {
		switch self {
		case .center:
			return CGPoint(x: 0.5, y: 0.5)
		case .top:
			return CGPoint(x: 0.5, y: 0)
		case .topLeft:
			return CGPoint(x: 0, y: 0)
		case .topRight:
			return CGPoint(x: 1, y: 0)
		case .bottom:
			return CGPoint(x: 0.5, y: 1)
		case .bottomLeft:
			return CGPoint(x: 0, y: 1)
		case .bottomRight:
			return CGPoint(x: 1, y: 1)
		case .left:
			return CGPoint(x: 0, y: 0.5)
		case .right:
			return CGPoint(x: 1, y: 0.5)
		default:
			return CGPoint(x: 0.5, y: 0.5)
		}
	}
}

public enum TweenMode {
	case to
	case from
	case fromTo
}

public enum TweenState: Equatable {
	case pending
	case running
	case cancelled
	case completed
}
public func ==(lhs: TweenState, rhs: TweenState) -> Bool {
	switch (lhs, rhs) {
	case (.pending, .pending):
		return true
	case (.running, .running):
		return true
	case (.cancelled, .cancelled):
		return true
	case (.completed, .completed):
		return true
	default:
		return false
	}
}

public protocol Tweener {
	associatedtype TweenType
	
	var antialiasing: Bool { get set }
	weak var timeline: Timeline? { get set }
	
	func from(_ props: TweenProp...) -> TweenType
	func to(_ props: TweenProp...) -> TweenType
	
	func ease(_ easing: Easing.EasingType) -> TweenType
	func spring(tension: Double, friction: Double) -> TweenType
	func perspective(_ value: CGFloat) -> TweenType
	func anchor(_ anchor: AnchorPoint) -> TweenType
	func anchorPoint(_ point: CGPoint) -> TweenType
}

open class Tween: Animation, Tweener {
	public typealias TweenType = Tween
	public typealias AnimationType = Tween
	
	open var state: TweenState = .pending
	open var target: NSObject? {
		get {
			return tweenObject.target
		}
	}
	open var antialiasing: Bool {
		get {
			return tweenObject.antialiasing
		}
		set(newValue) {
			tweenObject.antialiasing = newValue
		}
	}
	override open var duration: CFTimeInterval {
		didSet {
//			for prop in properties {
//				prop.duration = duration
//			}
		}
	}
	override open var totalTime: CFTimeInterval {
		get {
			return (elapsed - delay - staggerDelay)
		}
	}
	open weak var timeline: Timeline?
	
	var properties: [FromToValue] {
		get {
			return [FromToValue](propertiesByType.values)
		}
	}
	fileprivate var propertiesByType: Dictionary<String, FromToValue> = [String: FromToValue]()
	private(set) var animators = [String: Animator]()
	
	var tweenObject: TweenObject
	fileprivate var timingFunction: TimingFunctionType = LinearTimingFunction()
	fileprivate var timeScale: Float = 1
	fileprivate var staggerDelay: CFTimeInterval = 0
	fileprivate var needsPropertyPrep = false
	fileprivate var spring: Spring?
	
	var additive = true;

	
	// MARK: Lifecycle
	
	required public init(target: NSObject) {
//		self.tweenObject = TweenObject(target: target)
		self.tweenObject = Scheduler.sharedInstance.cachedUpdater(ofTarget: target)
		super.init()
		
		Scheduler.sharedInstance.cache(self, target: target)
	}
	
	deinit {
		kill()
		propertiesByType.removeAll()
//		tweenObject.target = nil
	}
	
	// MARK: Animation Overrides
	
	override open func duration(_ duration: CFTimeInterval) -> Tween {
		super.duration(duration)
		
//		for prop in properties {
//			prop.duration = duration
//		}
		return self
	}
	
	override open func delay(_ delay: CFTimeInterval) -> Tween {
		super.delay(delay)
		
		if timeline == nil {
			startTime = delay + staggerDelay
		}
		
		return self
	}
	
	override open func restart(_ includeDelay: Bool = false) {
		super.restart(includeDelay)
		
//		for prop in properties {
//			prop.reset()
//			prop.calc()
//		}
		run()
	}
	
	override open func kill() {
		super.kill()
		
		Scheduler.sharedInstance.remove(self)
		if let target = target {
			Scheduler.sharedInstance.removeFromCache(self, target: target)
		}
	}
	
	// MARK: Tweenable
	
	open func fromTest(_ props: TweenProp...) -> Tween {
		for prop in props {
			var value = propertiesByType[prop.key]
			if value == nil {
				value = FromToValue()
			}
			value?.from = prop
			propertiesByType[prop.key] = value
		}
		return self
	}
	
	open func toTest(_ props: TweenProp...) -> Tween {
		for prop in props {
			var value = propertiesByType[prop.key]
			if value == nil {
				value = FromToValue()
			}
			value?.to = prop
			propertiesByType[prop.key] = value
		}
		return self
	}
	
	open func from(_ props: TweenProp...) -> Tween {
		return from(props)
	}
	
	open func to(_ props: TweenProp...) -> Tween {
		return to(props)
	}
	
	// internal `from` and `to` methods that support a single array of Property types since we can't forward variadic arguments
	func from(_ props: [TweenProp]) -> Tween {
		for prop in props {
			add(prop, mode: .from)
		}
		return self
	}
	
	func to(_ props: [TweenProp]) -> Tween {
//		prepare(from: nil, to: props, mode: .To)
		for prop in props {
			add(prop, mode: .to)
		}
		return self
	}
	
	open func ease(_ easing: Easing.EasingType) -> Tween {
		timingFunction = Easing(easing)
//		for prop in properties {
//			prop.easing = easing
//		}
		return self
	}
	
	open func spring(tension: Double, friction: Double = 3) -> Tween {
		spring = Spring(tension: tension, friction: friction)
//		for prop in properties {
//			prop.spring = Spring(tension: tension, friction: friction)
//		}
		return self
	}
	
	open func perspective(_ value: CGFloat) -> Tween {
		tweenObject.perspective = value
		return self
	}
	
	open func anchor(_ anchor: AnchorPoint) -> Tween {
		return anchorPoint(anchor.point())
	}
	
	open func anchorPoint(_ point: CGPoint) -> Tween {
		tweenObject.anchorPoint = point
		return self
	}
	
	open func stagger(_ offset: CFTimeInterval) -> Tween {
		staggerDelay = offset
		
		if timeline == nil {
			startTime = delay + staggerDelay
		}
		
		return self
	}
	
	open func timeScale(_ scale: Float) -> Tween {
		timeScale = scale
		return self
	}
	
	override open func play() -> Tween {
		guard !active else { return self }
		
		super.play()
		
		if let target = target {
			Scheduler.sharedInstance.cache(self, target: target)
		}
		
		for (key, animator) in animators {
			animator.reset()
		}
		
		// properties must be sorted so that the first in the array is the transform property, if exists
		// so that each property afterwards isn't set with a transform in place
//		for prop in TweenUtils.sortProperties(properties).reverse() {
//			prop.reset()
//			prop.calc()
//			
//			if prop.mode == .From || prop.mode == .FromTo {
//				prop.seek(0)
//			}
//		}
		run()
		
		return self
	}
	
	override open func resume() {
		super.resume()
		if !running {
			run()
		}
	}
	
	override open func reverse() -> Tween {
		super.reverse()
		run()
		
		return self
	}
	
	override open func forward() -> Tween {
		super.forward()
		run()
		
		return self
	}
	
	override open func seek(_ time: CFTimeInterval) -> Tween {
		super.seek(time)
		
		let elapsedTime = elapsedTimeFromSeekTime(time)
		elapsed = delay + staggerDelay + elapsedTime
		
		setupAnimatorsIfNeeded()
		
		for (key, animator) in animators {
			animator.seek(elapsedTime)
		}
		
		return self
	}
	
//	public func updateTo(options: [Property], restart: Bool = false) {
//		
//	}
	
	// MARK: Private Methods
	
	fileprivate func add(_ prop: TweenProp, mode: TweenMode) {
		var value = propertiesByType[prop.key] ?? FromToValue()
		
		if mode == .from {
			value.from = prop
		} else {
			value.to = prop
		}
		
		propertiesByType[prop.key] = value
	}
	
	override func advance(_ time: Double) -> Bool {
//		print("Tween.advance() - id: \(id), running: \(running), paused: \(paused), startTime: \(startTime)")
		if target == nil || !running {
			return false
		}
		if paused {
			return false
		}
		if propertiesByType.count == 0 {
			return true
		}
		
		// if tween belongs to a timeline, don't start animating until the timeline's playhead reaches the tween's startTime
		if let timeline = timeline {
//			print("Tween.advance() - id: \(id), timeline.time: \(timeline.time()), startTime: \(startTime), endTime: \(endTime), reversed: \(timeline.reversed)")
			if timeline.time() < startTime || timeline.time() > endTime {
				return false
			}
		}
		
		let end = delay + duration
		let multiplier: CFTimeInterval = reversed ? -1 : 1
		elapsed = max(0, min(elapsed + (time * multiplier), end))
		runningTime += time
//		print("Tween.advance() - id: \(id), time: \(runningTime), elapsed: \(elapsed), reversed: \(reversed)")
		
		let delayOffset = delay + staggerDelay + repeatDelay
		if timeline == nil {
			if elapsed < delayOffset {
				// if direction is reversed, then don't allow playhead to go below the tween's delay and call completed handler
				if reversed {
					completed()
				} else {
					return false
				}
			}
		}
		
		setupAnimatorsIfNeeded()
		
		// now we can finally animate
		if !animating {
			started()
		}
		
		var done = true
		for (key, animator) in animators {
			animator.advance(time * multiplier)
			if !animator.finished {
				done = false
			}
		}

		updateBlock?(self)
		
		if done {
			return completed()
		}
		return false
	}
	
	override func started() {
		super.started()
		state = .running
	}
	
	override func completed() -> Bool {
		let done = super.completed()
		
		if done {
			state = .completed
			kill()
		}
		
		return done
	}
	
	// MARK: Private Methods
	
	fileprivate func run() {
		running = true
		Scheduler.sharedInstance.add(self)
	}
	
	fileprivate func setupAnimatorsIfNeeded() {
		var transformFrom = Transform.zero
		var transformTo = Transform.zero
		
		if let transform = tweenObject.transform {
			transformFrom = Transform(transform)
			transformTo = Transform(transform)
		}
		
		var tweenedProps = [String: TweenProp]()
		for (key, prop) in propertiesByType {
			var animator = animators[key]
			
			if animator == nil {
				print("--------- tween.id: \(id) ------------")
				var from: TweenProp?
				var to: TweenProp?
				var type = prop.to ?? prop.from
				
				if let type = type, let value = tweenObject.currentValueForTweenProp(type) {
					from = value
					to = value
					
					if let tweenFrom = prop.from {
//						print("applying tweenFrom: \(tweenFrom)")
						from?.apply(tweenFrom)
					} else if let previousTo = tweenedProps[key] {
						from = previousTo
						print("no `from` value, using prevous tweened value \(previousTo)")
					} else if let tweenTo = prop.to, let activeValues = tweenObject.activeTweenValuesForKey(tweenTo.key), activeValues.count > 0 {
						from = activeValues.last?.to
						print("no `from` value, using last active tween value \(activeValues.last?.to)")
					}
					
					if let tweenTo = prop.to {
//						print("applying tweenTo: \(tweenTo)")
						to?.apply(tweenTo)
					}
					
					// need to update axes which are to be animated based on destination value
					if type is Rotation {
						if var _from = from as? Rotation, var _to = to as? Rotation, let tweenTo = prop.to as? Rotation {
							_to.applyAxes(tweenTo)
							_from.applyAxes(tweenTo)
							from = _from
							to = _to
						}
					}
					
					tweenedProps[key] = to
				}
				print(tweenedProps)				
				print("ANIMATE - from: \(from), to: \(to)")
				
				if let from = from, let to = to {
					if let from = from as? TransformType, let to = to as? TransformType {
						transformFrom.apply(from)
						transformTo.apply(to)
						print("updating transform properties...")
					} else {
						let tweenAnimator = Animator(from: from, to: to, duration: duration, timingFunction: timingFunction)
						tweenAnimator.additive = (to is KeyPath == false)
						tweenAnimator.spring = spring
						tweenAnimator.setPresentation({ (prop) -> TweenProp? in
							return self.tweenObject.currentValueForTweenProp(prop)
						})
						tweenAnimator.onChange({ [unowned self] (animator, value) in
							self.tweenObject.update(value)
						})
						animator = tweenAnimator
						animators[key] = tweenAnimator
						print("setting animator for key: \(key)")
					}
				} else {
					print("Could not create animator for property \(prop)")
				}
			}
		}
		
		if transformFrom != Transform.zero || transformTo != Transform.zero {
			let key = "transform"
			if animators[key] == nil {
//				print("ANIMATE - transform - from: \(transformFrom), to: \(transformTo)")
				let animator = Animator(from: transformFrom, to: transformTo, duration: duration, timingFunction: timingFunction)
				animator.spring = spring
				animator.onChange({ [weak self] (animator, value) in
					self?.tweenObject.update(value)
				})
				animators[key] = animator
			}
		}
		
	}
}
