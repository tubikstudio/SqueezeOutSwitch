//
//  BlowOutSwitcher.swift
//  BlowOutSwitch
//
//  Created by Tubik Studio on 8/30/16.
//  Copyright © 2016 Tubik Studio. All rights reserved.
//

import UIKit

@IBDesignable
class SqueezeOutSwitch: UIView {
  
  //MARK: vars
  
  @IBInspectable
  var on:Bool = true {
    didSet {
      imageView.image = on ? onImage : offImage
      imageView.center.x = on ? onX : offX
      shapeLayer.path = shapeZeroPath()
    }
  }
  
  @IBInspectable
  var onColor:UIColor = UIColor(red: 0.15, green: 0.76, blue: 0.51, alpha: 1.0)
  
  @IBInspectable
  var offColor:UIColor = UIColor(red: 0.89, green: 0.27, blue: 0.25, alpha: 1.0)
  
  @IBInspectable
  var onImage:UIImage? = UIImage(named: "Circle_Ok", inBundle: NSBundle(forClass: SqueezeOutSwitch.self), compatibleWithTraitCollection: UITraitCollection())
  
  @IBInspectable
  var offImage:UIImage? = UIImage(named: "Circle_No", inBundle: NSBundle(forClass: SqueezeOutSwitch.self), compatibleWithTraitCollection: UITraitCollection())
  
  private var displayLink : CADisplayLink?
  private var onX: CGFloat = 0
  private var offX: CGFloat = 0
  private var maxOffset: CGFloat?
  private var goalState = false
  
  private let defaultBackgroundColor = UIColor(red: 0.81, green: 0.88, blue: 0.94, alpha: 1.0)
  private var imageView = UIImageView()
  private var shapeLayer = CAShapeLayer()
  
  private var panGestureRecognizer: UIPanGestureRecognizer!
  
  private var imageSize: CGFloat! {
    didSet {
      imageOffset = (frame.height - imageSize)/2.0
      minMidX = (bounds.width - imageOffset - imageSize)/2.0
      maxMidX = (bounds.width + imageOffset + imageSize)/2.0
      onX = imageOffset + imageSize/2.0
      offX = frame.width - imageOffset - imageSize/2.0
    }
  }
  private var imageOffset: CGFloat = 0
  private var middleOffset: CGFloat = 0
  private var minMidX: CGFloat = 0
  private var maxMidX: CGFloat = 0
  
  //MARK: init
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    baseInit()
  }
  
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    baseInit()
  }
  
  func baseInit() {
    
    if panGestureRecognizer == nil {
      panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(SqueezeOutSwitch.handlePan))
      addGestureRecognizer(panGestureRecognizer)
    }
    
  }
  
  //MARK: Display Link
  
  @objc
  private func updateShapePath() {
    guard let layer = self.imageView.layer.presentationLayer() else { return }
    shapeLayer.path = shapePathForImageCenterX(CGRectGetMidX(layer.frame), fromState:  on)
  }
  
  @objc
  private func bouncingPath() {
    guard let layer = self.imageView.layer.presentationLayer() else { return }
    
    let rightPosition = on ? offX : onX
    let offset = rightPosition - layer.position.x
    if maxOffset == nil {
      maxOffset = abs(offset)
    }
    let percent = offset/maxOffset!
    if abs(percent) > 1 {
      shapeLayer.path = shapeZeroPath()
      return
    }
    
    let pointX = bounds.width/2.0 + ((offset > 0) ? imageOffset/2.0 : -imageOffset/2.0)
    let imageCenterX = pointX + (percent * (1 * imageSize))
    
    CATransaction.begin()
    CATransaction.setValue(true, forKey: kCATransactionDisableActions)
    shapeLayer.fillColor = imageCenterX > bounds.width/2.0 ? offColor.CGColor : onColor.CGColor
    shapeLayer.path = shapePathForX(imageCenterX)
    CATransaction.commit()
  }
  
  private func startDisplayLink(selector sel: Selector) {
    stopDisplayLink()
    displayLink = CADisplayLink(target: self, selector: sel)
    displayLink?.frameInterval = 1
    displayLink?.addToRunLoop(NSRunLoop.mainRunLoop(), forMode: NSRunLoopCommonModes)
  }
  
  private func stopDisplayLink() {
    displayLink?.invalidate()
    displayLink = nil
  }
  
  //MARK: animation
  
  private func animateWithMiddlePause(duration duration: CFTimeInterval) {
    //correct state, if previous was enterapted
    on = imageView.center.x < bounds.width/2.0
    goalState = !on
    
    let midPosition = CGPoint(x: on ? maxMidX : minMidX, y: CGRectGetMidY(self.bounds))
    shapeLayer.fillColor = on ? offColor.CGColor : onColor.CGColor
    
    //start drawing path, which covers circle image view
    startDisplayLink(selector: #selector(SqueezeOutSwitch.updateShapePath))
    
    //animate circle movement
    UIView.animateWithDuration(duration, delay: 0, options: .BeginFromCurrentState, animations: {
      self.imageView.center.x = midPosition.x
    }) { done in
      print("move")
      guard done else { return }
      //change image for circle
      self.imageView.image = self.goalState ? self.onImage : self.offImage
      //start drawing path, which bouncing
      self.startDisplayLink(selector: #selector(SqueezeOutSwitch.bouncingPath))
      UIView.animateWithDuration(1, delay: 0.0, usingSpringWithDamping: 0.2, initialSpringVelocity: 0, options: .BeginFromCurrentState, animations: {
        self.imageView.center.x = self.goalState ? self.onX : self.offX
        }, completion: { done in
          self.stopDisplayLink()
          guard done else { return }
          //change state if not already changed
          if self.goalState != self.on {
            print("done")
            self.on = self.goalState ?? !self.on
          }
      })
    }
  }
  
  //MARK: shape path
  
  private func shapeZeroPath() -> CGPath {
    let path = UIBezierPath()
    let xValue = bounds.width/2.0 + ( on ? middleOffset/2.0 : -middleOffset/2.0 )
    path.moveToPoint(CGPoint(x: xValue, y: 0))
    path.addLineToPoint(CGPoint(x: xValue, y: bounds.height))
    return path.CGPath
  }
  
  private func shapePathForX(x: CGFloat) -> CGPath {
    let path = UIBezierPath()
    
    //detects convexity direction : sign == 1 if convexity on right side
    let sign:CGFloat = x >= bounds.width/2.0 ? 1 : -1
    
    //x for point1
    let xValue = (bounds.width + sign * middleOffset)/2.0
    
    path.moveToPoint(CGPoint(x: xValue, y: 0))
    
    //range for point2
    let minMiddlePointX = minMidX - imageSize/2.0
    let maxMiddlePointX = maxMidX  + imageSize/2.0
    
    //correct point2 to range
    let correctMiddlePointX = min(max(minMiddlePointX, x), maxMiddlePointX)
    
    //distance from middle point to control points
    let controlPointOffset = abs(x - bounds.width/2.0)/imageSize * imageSize/2.0
    let midY = CGRectGetMidY(bounds)
    
    // control points
    let firstControlPoint = CGPoint(x: correctMiddlePointX, y: midY - controlPointOffset)
    let secondControlPoint = CGPoint(x: correctMiddlePointX, y: midY + controlPointOffset)
    
    path.addQuadCurveToPoint(CGPoint(x: x, y: midY), controlPoint: firstControlPoint)
    path.addQuadCurveToPoint(CGPoint(x: xValue, y: bounds.height), controlPoint: secondControlPoint)
    path.closePath()
    
    return path.CGPath
  }
  
  
  private func shapePathForImageCenterX(xCenterValue: CGFloat, fromState on: Bool) -> CGPath {
    let maxX = xCenterValue + imageSize/2.0
    let minX = xCenterValue - imageSize/2.0
    let controlPointX = on ? maxX + 2 : minX - 2
    
    if (maxX < ((bounds.width - middleOffset)/2.0) && on) ||
      (minX > ((bounds.width + middleOffset)/2.0) && !on) {
      return shapeZeroPath()
    }
    
    return shapePathForX(controlPointX)
  }
  
  
  //MARK: touches
  
  @objc
  private func handlePan(gestureRecognizer: UIPanGestureRecognizer) {
    let touchLocation = gestureRecognizer.locationInView(self)
    
    //range for circle image view position
    let maxX = on ? maxMidX : offX
    let minX = on ? onX : minMidX
    let correctPositionX = max(min(touchLocation.x, maxX), minX)
    
    if gestureRecognizer.state == .Began || gestureRecognizer.state == .Changed {
      imageView.center = CGPointMake(correctPositionX, CGRectGetMidY(bounds))
      //draw path which covers image view, state helps recognize if which
      //convexity direction possible - on right or left side
      shapeLayer.path = shapePathForImageCenterX(CGRectGetMidX(imageView.frame), fromState: on)
      shapeLayer.fillColor = on ? offColor.CGColor : onColor.CGColor
    }
    
    if gestureRecognizer.state == .Ended  {
      goalState = correctPositionX < bounds.width/2.0
      if on != goalState {
        //start drawing path, which bouncing
        startDisplayLink(selector: #selector(SqueezeOutSwitch.bouncingPath))
      } else {
        shapeLayer.path = shapeZeroPath()
      }
      
      imageView.image = goalState == true ? onImage : offImage
      UIView.animateWithDuration(1, delay: 0, usingSpringWithDamping: 0.2, initialSpringVelocity: 0.0, options: .BeginFromCurrentState, animations: {
        self.imageView.center.x = self.goalState ? self.onX : self.offX
        }, completion: { _ in
          self.stopDisplayLink()
          self.on = self.goalState ?? !self.on
      })
    }
    
  }
  
  override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
    animateWithMiddlePause(duration: 0.3)
  }
  
  //MARK: draw rect
  
  override func drawRect(rect: CGRect) {
    
    middleOffset = 0.1*frame.width
    imageSize = 0.7*frame.height
    
    let leftRect = CGRectMake(0, 0, (frame.width - middleOffset)/2.0, frame.height)
    let leftAreaPath = UIBezierPath(roundedRect: leftRect,
                                    byRoundingCorners: [.TopLeft, .BottomLeft],
                                    cornerRadii: CGSize(width: frame.height/2.0, height: frame.height/2.0))
    let rightRect = CGRectMake((frame.width + middleOffset)/2.0, 0, (frame.width - middleOffset)/2.0, frame.height)
    let rightAreaPath = UIBezierPath(roundedRect: rightRect,
                                     byRoundingCorners: [.TopRight, .BottomRight],
                                     cornerRadii: CGSize(width: frame.height/2.0, height: frame.height/2.0))
    leftAreaPath.appendPath(rightAreaPath)
    
    let mask = CAShapeLayer()
    mask.path = leftAreaPath.CGPath
    layer.mask = mask
    
    
    
    imageView.frame = CGRect(x: on ? imageOffset : bounds.width - imageOffset - imageSize, y: imageOffset, width: imageSize, height: imageSize)
    imageView.image = on ? onImage : offImage
    if imageView.superview == nil {
      addSubview(imageView)
    }
    
    if shapeLayer.superlayer == nil {
      shapeLayer.path = shapeZeroPath()
      layer.addSublayer(shapeLayer)
    }
    
  }
  
  
}
