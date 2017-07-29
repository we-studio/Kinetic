//
//  Tweenable.swift
//  Pods
//
//  Created by Nicholas Shipes on 2/5/17.
//
//

import UIKit

public protocol Tweenable: class {
	func apply(_ prop: Property)
	func currentProperty(for prop: Property) -> Property?
}

public protocol KeyPathTweenable : Tweenable {}
extension Tweenable where Self: KeyPathTweenable {
	
	public func apply(_ prop: Property) {
		if let keyPath = prop as? KeyPath, let target = self as? NSObject, target.responds(to:Selector(keyPath.key)) {
			target.setValue(prop.value.toInterpolatable(), forKey: keyPath.key)
		}
	}
	
	public func currentProperty(for prop: Property) -> Property? {
		print("getting current property for object - prop: \(prop)")
		if prop is KeyPath {
			if let target = self as? NSObject, let value = target.value(forKey: prop.key) as? Interpolatable {
				return KeyPath(prop.key, value)
			}
		}
		
		return nil
	}
}

extension UIView : Tweenable {}
extension Tweenable where Self == UIView {
	
	public func apply(_ prop: Property) {
		if let transform = prop as? Transform {
			transform.applyTo(self)
		} else if let value = prop.value.toInterpolatable() as? CGFloat {
			if prop is X {
				frame.origin.x = value
			} else if prop is Y {
				frame.origin.y = value
			} else if prop is Alpha {
				alpha = value
			}
		} else if let value = prop.value.toInterpolatable() as? CGPoint {
			if prop is Position {
				frame.origin = value
			} else if prop is Center {
				center = value
			}
		} else if let value = prop.value.toInterpolatable() as? CGSize {
			if prop is Size {
				frame.size = value
			}
		} else if let value = prop.value.toInterpolatable() as? UIColor {
			if prop is BackgroundColor {
				backgroundColor = value
			}
		}
	}
	
	public func currentProperty(for prop: Property) -> Property? {
		var vectorValue: Property?
		
		if prop is X || prop is Y {
			if prop is X {
				vectorValue = X(frame.origin.x)
			} else {
				vectorValue = Y(frame.origin.y)
			}
		} else if prop is Position {
			vectorValue = Position(frame.origin)
		} else if prop is Center {
			vectorValue = Center(center)
		} else if prop is Size {
			vectorValue = Size(frame.size)
		} else if prop is Alpha {
			vectorValue = Alpha(alpha)
		} else if prop is BackgroundColor {
			if let color = backgroundColor {
				vectorValue = BackgroundColor(color)
			} else {
				vectorValue = BackgroundColor(UIColor.clear)
			}
		} else if prop is Scale {
			vectorValue = layer.transform.scale()
		} else if prop is Rotation {
			vectorValue = layer.transform.rotation()
		} else if prop is Translation {
			vectorValue = layer.transform.translation()
		}
		
		return vectorValue
	}
}

extension CALayer : Tweenable {}
extension Tweenable where Self == CALayer {
	
	public func apply(_ prop: Property) {
		if let transform = prop as? Transform {
			transform.applyTo(self)
		} else if let value = prop.value.toInterpolatable() as? CGFloat {
			if prop is X {
				frame.origin.x = value
			} else if prop is Y {
				frame.origin.y = value
			} else if prop is Alpha {
				opacity = Float(value)
			}
		} else if let value = prop.value.toInterpolatable() as? CGPoint {
			if prop is Position {
				frame.origin = value
			} else if prop is Center {
				position = value
			}
		} else if let value = prop.value.toInterpolatable() as? CGSize {
			if prop is Size {
				frame.size = value
			}
		} else if let value = prop.value.toInterpolatable() as? UIColor {
			if prop is BackgroundColor {
				backgroundColor = value.cgColor
			}
		}
	}
	
	public func currentProperty(for prop: Property) -> Property? {
		var vectorValue: Property?
		print("getting currentProperty for CAShapeLayer: \(prop)")
		
		if prop is X || prop is Y {
			if prop is X {
				vectorValue = X(frame.origin.x)
			} else {
				vectorValue = Y(frame.origin.y)
			}
		} else if prop is Position {
			vectorValue = Position(frame.origin)
		} else if prop is Center {
			vectorValue = Center(position)
		} else if prop is Size {
			vectorValue = Size(frame.size)
		} else if prop is Alpha {
			vectorValue = Alpha(CGFloat(opacity))
		} else if prop is BackgroundColor {
			if let color = backgroundColor {
				vectorValue = BackgroundColor(UIColor(cgColor: color))
			} else {
				vectorValue = BackgroundColor(UIColor.clear)
			}
		} else if prop is Scale {
			vectorValue = transform.scale()
		} else if prop is Rotation {
			vectorValue = transform.rotation()
		} else if prop is Translation {
			vectorValue = transform.translation()
		}
		
		return vectorValue
	}
}

extension Tweenable where Self == CAShapeLayer {
	
	public func apply(_ prop: Property) {
		if let value = prop.value.toInterpolatable() as? UIColor {
			if prop is FillColor {
				fillColor = value.cgColor
			}
		}
	}
	
	public func currentProperty(for prop: Property) -> Property? {
		print("getting currentProperty for CAShapeLayer: \(prop)")
		if prop is FillColor {
			if let color = fillColor {
				return FillColor(UIColor(cgColor: color))
			}
		}
		
		return nil
	}
}

public protocol ViewType {
	var anchorPoint: CGPoint { get set }
	var perspective: CGFloat { get set }
	var antialiasing: Bool { get set }
	var transform3d: CATransform3D { get set }
}

extension UIView : ViewType {}
extension ViewType where Self: UIView {
	
	public var anchorPoint: CGPoint {
		get {
			return layer.anchorPoint
		}
		set {
			layer.anchorPoint = newValue
		}
	}
	
	public var perspective: CGFloat {
		get {
			if let superlayer = layer.superlayer {
				return superlayer.sublayerTransform.m34
			}
			return 0
		}
		set {
			if let superlayer = layer.superlayer {
				superlayer.sublayerTransform.m34 = newValue
			}
		}
	}
	
	public var antialiasing: Bool {
		get {
			return layer.allowsEdgeAntialiasing
		}
		set {
			layer.allowsEdgeAntialiasing = newValue
		}
	}
	
	public var transform3d: CATransform3D {
		get {
			return layer.transform
		}
		set {
			layer.transform = newValue
		}
	}
}

extension CALayer : ViewType {}
extension ViewType where Self: CALayer {
	
	public var perspective: CGFloat {
		get {
			if let superlayer = superlayer {
				return superlayer.sublayerTransform.m34
			}
			return 0
		}
		set {
			if let superlayer = superlayer {
				superlayer.sublayerTransform.m34 = newValue
			}
		}
	}
	
	public var antialiasing: Bool {
		get {
			return allowsEdgeAntialiasing
		}
		set {
			allowsEdgeAntialiasing = newValue
		}
	}
	
	public var transform3d: CATransform3D {
		get {
			return transform
		}
		set {
			transform = newValue
		}
	}
}
