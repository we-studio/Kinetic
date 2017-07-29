//
//  Animator.swift
//  Pods
//
//  Created by Nicholas Shipes on 5/14/16.
//
//

import Foundation

public class Interpolator : Subscriber {
	public var id: UInt32 = 0
	public var progress: CGFloat = 0.0 {
		didSet {
			progress = max(0, min(progress, 1.0))
			
			var adjustedProgress: Double = Double(progress)
			
			if let spring = spring {
				spring.proceed(Double(progress))
				adjustedProgress = spring.current
			} else {
				adjustedProgress = timingFunction.solveForTime(Double(progress))
			}
			
			current = from.interpolateTo(to, progress: adjustedProgress)
			apply?(current.toInterpolatable())
		}
	}
	
	var spring: Spring?
	public var finished: Bool {
		if let spring = spring {
			return spring.ended
		}
		return (!reversed && elapsed >= duration) || (reversed && elapsed <= 0)
	}
	
	fileprivate var current: InterpolatableValue
	fileprivate var from: InterpolatableValue
	fileprivate var to: InterpolatableValue
	fileprivate var duration: TimeInterval
	fileprivate var timingFunction: TimingFunctionType
	fileprivate var elapsed: TimeInterval = 0.0
	fileprivate var reversed = false
	fileprivate var apply: ((Interpolatable) -> Void)?
	
	public init<T: Interpolatable>(from: T, to: T, duration: TimeInterval, function: TimingFunctionType, apply: @escaping ((T) -> Void)) {
		self.from = InterpolatableValue(value: from.vectorize())
		self.to = InterpolatableValue(value: to.vectorize())
		self.current = InterpolatableValue(value: self.from)
		self.duration = duration
		self.timingFunction = function
		self.apply = { let _ = ($0 as? T).flatMap(apply) }
	}
	
	public func run() {
		Scheduler.shared.add(self)
	}
	
	public func seek(_ time: TimeInterval) {
		elapsed = time
		advance(0)
	}
	
	public func reset() {
		current = from
		
		if let spring = spring {
			spring.reset()
		}
		
		// only force target presentation update if we've elapsed past 0
		if elapsed > 0 {
			apply?(current.toInterpolatable())
		}
		elapsed = 0
	}
	
	public func onUpdate(closure: @escaping (Interpolatable) -> Void) {
		self.apply = { let _ = ($0 as? Interpolatable).flatMap(closure) }
	}
	
	internal func advance(_ time: TimeInterval) {
		let direction: CGFloat = reversed ? -1.0 : 1.0
		
		elapsed += time
		elapsed = max(0, elapsed)
		reversed = time < 0
		
		progress = CGFloat(elapsed / duration) * direction
		print("progress: \(progress), elapsed: \(elapsed), duration: \(duration)")
		
		if (direction > 0 && progress >= 1.0) || (direction < 0 && progress <= -1.0) {
			
		}
	}
	
	func kill() {
		Scheduler.shared.remove(self)
	}
}

final public class PropertyInterpolator {
	fileprivate (set) public var from: Property
	fileprivate (set) public var to: Property
	fileprivate (set) public var current: Property
	fileprivate var interpolator: Interpolator
	fileprivate var apply: ((Property) -> Void)?
	
	public init<T: Property>(from: T, to: T, duration: TimeInterval, function: TimingFunctionType, apply: @escaping ((T) -> Void)) {
		self.from = from
		self.to = to
		self.current = from
		self.apply = { let _ = ($0 as? T).flatMap(apply) }
		
		let testFrom = X(100.0)
		let testTo = X(50.0)
		
		let fromValue: CGPoint = testFrom.value.toInterpolatable() as! CGPoint
		let toValue: CGPoint = testTo.value.toInterpolatable() as! CGPoint
		
		self.interpolator = Interpolator(from: fromValue, to: toValue, duration: duration, function: function) { (value) in
			
		}
		
		self.interpolator.onUpdate { [weak self] (value) in
			self?.current.apply(value.vectorize())
			if let current = self?.current {
				self?.apply?(current)
			}
		}
	}
	
	public func run() {
		interpolator.run()
	}
}

final public class Animator: Equatable {
	fileprivate (set) public var from: Property
	fileprivate (set) public var to: Property
	fileprivate (set) public var duration: Double
	fileprivate (set) public var key: String
	public var timingFunction: TimingFunctionType = LinearTimingFunction()
	public var additive: Bool = true
	public var changed: ((Animator, Property) -> Void)?
	public var finished: Bool {
		if let spring = spring {
			return spring.ended
		}
		return (!reversed && elapsed >= duration) || (reversed && elapsed <= 0)
	}
	
	internal var spring: Spring?
	
	fileprivate (set) public var current: Property
	fileprivate var additiveCurrent: Property
	fileprivate var elapsed: Double = 0.0
	fileprivate var reversed = false
	fileprivate var presentation: ((Property) -> Property?)?
	
	public init(from: Property, to: Property, duration: Double, timingFunction: TimingFunctionType) {
		self.from = from
		self.to = to
		self.duration = duration
		self.timingFunction = timingFunction
		self.current = from
		self.additiveCurrent = from
		self.key = from.key
	}
	
	// MARK: Public Methods
	
	public func seek(_ time: Double) {
		elapsed = time
		advance(0)
	}
	
	public func reset() {
		current = from
		if let spring = spring {
			spring.reset()
		}
		
		// only force target presentation update if we've elapsed past 0
		if elapsed > 0 {
			changed?(self, current)
		}
		elapsed = 0
	}
	
	public func advance(_ time: Double) {
		elapsed += time
		elapsed = max(0, elapsed)
		reversed = time < 0
		
		var progress = elapsed / duration
		progress = max(progress, 0.0)
		progress = min(progress, 1.0)
//		print("Animator.advance - elapsed: \(elapsed)")
		
		
		var adjustedProgress = progress
		if let spring = spring {
			spring.proceed(time / duration)
			adjustedProgress = spring.current
		} else {
			adjustedProgress = timingFunction.solveForTime(progress)
		}
		
		var presentationValue: Property = current
		
		if let from = from as? Transform, let to = to as? Transform, var value = current as? Transform {
			let scale = from.scale.value.interpolateTo(to.scale.value, progress: adjustedProgress)
			let rotation = from.rotation.value.interpolateTo(to.rotation.value, progress: adjustedProgress)
			let translation = from.translation.value.interpolateTo(to.translation.value, progress: adjustedProgress)
			
			value.scale.apply(scale)
			value.rotation.apply(rotation)
			value.translation.apply(translation)
			self.current = value
			
		} else {
			var interpolatedValue = from.value.interpolateTo(to.value, progress: adjustedProgress)
			current.apply(interpolatedValue)
			
			if additive {
				// when an animation is additive, its presentation value needs to be adjusted so the transition is smooth
				presentationValue = adjustForAdditive(prop: presentationValue, interpolatable: interpolatedValue)
			} else {
				presentationValue = current
			}
		}
		
//		print("animator \(key) - progress: \(progress), current: \(current.value.vectors), presentation: \(presentationValue.value.vectors), from: \(from.value.vectors), to: \(to.value.vectors)")
//		print("Animator.advance() - elapsed: \(elapsed), progress: \(progress), from: \(from.value), to: \(to.value)")
		changed?(self, presentationValue)
	}
	
	public func onChange(_ block: ((Animator, Property) -> Void)?) {
		changed = block
	}
	
	public func setPresentation(_ block: ((Property) -> Property?)?) {
		presentation = block
	}
	
	/*
	An additive animation requires the linearly-interpolated value (LERP) to be updated to equal the sum of the display object's current presentation value
	and the delta between the animation's current and previous interpolated values. This should only be applied to the display object, *not* to the animation's 
	current interpolated value.
	
	presentation = presentation + (current - previous)
	*/
	private func adjustForAdditive(prop: Property, interpolatable: InterpolatableValue) -> Property {
		if let pres = presentation?(prop) {
			var adjustedValue = prop
			
			var vectors = interpolatable.vectors
			let current = prop.value.vectors
			let pcurrent = pres.value.vectors
			
			for i in 0..<vectors.count {
				let delta = vectors[i] - current[i]
				vectors[i] = pcurrent[i] + delta
			}
			
			let intepolatable = InterpolatableValue(type: interpolatable.type, vectors: vectors)
			adjustedValue.apply(intepolatable)
			
			return adjustedValue
		}
		
		return prop
	}
}
public func ==(lhs: Animator, rhs: Animator) -> Bool {
	return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
}
