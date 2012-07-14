//
//  ViewController.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-14.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIView *leftContainer;
@property (weak, nonatomic) IBOutlet UIView *rightContainer;
@property (weak, nonatomic) IBOutlet UIButton *draggableButton;

#pragma mark  MCKDnDDonorProtocol delegate

// when view is picked up
-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview;
// if view is absorbed by dropped-on view.
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview;
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview;
// if view is rejected by the dropped-on view
-(void) donorView:(UIView*)donor didReclaimDraggingView:(UIView*)draggingSubview;

#pragma mark MCKDnDAbsorberProtocol delegate

-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview;
-(void) absorberView:(UIView*)absorber absorbDraggingView:(UIView*)draggingSubview;

@end
