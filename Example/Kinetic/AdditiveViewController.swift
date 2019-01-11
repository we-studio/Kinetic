//
//  AdditiveViewController.swift
//  Motion
//
//  Created by Nicholas Shipes on 1/1/16.
//  Copyright © 2016 Urban10 Interactive, LLC. All rights reserved.
//

import UIKit
import Kinetic

class AdditiveViewController: ExampleViewController {
	var square: UIView!
	var timeline: Timeline!
	
	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
		
		title = "Additive"
		showsControls = false
	}
	
	required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		view.backgroundColor = UIColor.white
		hideControls()
		
		square = UIView()
		square.frame = CGRect(x: 50, y: 50, width: 50, height: 50)
		square.backgroundColor = UIColor.red
		view.addSubview(square)
		
		let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(AdditiveViewController.handleTap(_:)))
		view.addGestureRecognizer(tapRecognizer)
		
		timeline = Timeline()
		animation = timeline
	}
	
    @objc func handleTap(_ gestureRecognizer: UITapGestureRecognizer) {
		let point = gestureRecognizer.location(in: view)				
		let move = Kinetic.animate(square).to(Center(point.x, point.y)).duration(1).ease(.quadInOut)
		
		move.play()
	}

}
