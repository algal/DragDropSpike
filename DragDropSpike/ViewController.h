//
//  ViewController.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-14.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "MCKDragDropProtocol.h"

@interface ViewController : UIViewController <MCKDnDDonorProtocol, MCKDnDAbsorberProtocol>
@property (weak, nonatomic) IBOutlet UIView *leftContainer;
@property (weak, nonatomic) IBOutlet UIView *rightContainer;
@property (weak, nonatomic) IBOutlet UIButton *draggableButton;

#pragma mark  MCKDnDDonorProtocol delegate

-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview;
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview;
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview;
-(void) donorView:(UIView*)donor reclaimDraggingView:(UIView*)draggingSubview;

#pragma mark MCKDnDAbsorberProtocol delegate

-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview;
-(void) absorberView:(UIView*)absorber absorbDraggingView:(UIView*)draggingSubview;

@end
