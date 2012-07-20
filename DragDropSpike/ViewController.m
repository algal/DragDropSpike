//
//  ViewController.m
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-14.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "ViewController.h"
#import "MCKDragDropProtocol.h"
#import "MCKDragDropServer.h"

@interface UIView (debug)
- (NSString *)recursiveDescription;
@end

@implementation ViewController

@synthesize leftContainer;
@synthesize rightContainer;
@synthesize draggableItem;

- (void)viewDidLoad
{
  [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.

  MCKDragDropServer * server = [MCKDragDropServer sharedServer];
  [server registerDraggableView:self.draggableItem];
  [server registerDonorView:self.leftContainer delegate:self];
  [server registerDonorView:self.rightContainer delegate:self];
  [server registerAbsorberView:self.leftContainer delegate:self];
  [server registerAbsorberView:self.rightContainer delegate:self];
}

- (void)viewDidUnload
{
  [self setLeftContainer:nil];
  [self setRightContainer:nil];
  [self setDraggableItem:nil];
  [super viewDidUnload];
  // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;
}


#pragma mark MCKDragDropDonor delegate

-(void) donorView:(UIView*)donor willBeginDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
}

/*
 STAGE 1.
 
 The donor could apply its own *specialized* logic here to modify its own
 appearance or state to reflect the fact that part of it has been picked up
 and/or is being dragged away. For instance,

 */
-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
}

/* STAGE 3 */
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
}

/* STAGE 5 */
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
}

/*
 Tells donor that draggingView was animated back into old position.
 */
-(void) donorView:(UIView*)donor didReclaimDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
}

#pragma mark MCKDragDropAbsorber delegate

/* STAGE 2. */
-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  return CGRectContainsPoint(absorber.bounds,
                             [absorber convertPoint:draggingSubview.center
                                           fromView:draggingSubview.superview]);
  return YES;
}

/* STAGE 4
 Tells absorber that draggingView has been added to its VH.
 */
-(void) absorberView:(UIView*)absorber didAbsorbDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  return;
}

@end
