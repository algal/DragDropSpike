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
#import "MCKPanGestureRecognizer.h"

@interface ViewController ()

@property (assign) CGPoint initialDraggableViewOrigin;

@property (assign) CGSize initialShadowOffset;
@property (assign) CGFloat initialShadowRadius;
@property (assign) CGFloat initialShadowOpacity;

@end


@implementation ViewController

@synthesize leftContainer;
@synthesize rightContainer;
@synthesize draggableItem;

@synthesize initialDraggableViewOrigin;

- (void)viewDidLoad
{
  [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
  [self registerDraggableView:draggableItem];
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

-(void)handleDraggablePan:(UIPanGestureRecognizer*)theRecognizer
{
  UIView * donorView = self.leftContainer;
  UIView * absorberView = self.rightContainer;
  NSObject <MCKDnDAbsorberProtocol> * absorberDelegate = self;
  NSObject <MCKDnDDonorProtocol>    * donorDelegate = self;
  
  MCKPanGestureRecognizer * recognizer = (MCKPanGestureRecognizer*)theRecognizer;

  CGPoint recognizerViewOrigin = recognizer.view.frame.origin;
  PSLogInfo(@"started. recognizer.view.frame.origin={%f,%f} and state=%u",
            recognizerViewOrigin.x,recognizerViewOrigin.y,recognizer.state);
  
  // should compute (and cache?) donorView at pick-up time

  // should assign (potential) absorberView at drop time
  // at drop time, need to know donorView to order a reclaim.
  // so how to remember donorView?
  // => Q: does this mean this info needs to be cached in a drag session object?
  
  // move the view to follow the finger's translational motion
  CGPoint translation = [recognizer translationInView:recognizer.view.superview];
  recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                       recognizer.view.center.y + translation.y);
  [recognizer setTranslation:CGPointMake(0, 0) inView:recognizer.view.superview];
  
  if (recognizer.state == UIGestureRecognizerStatePossible) {
    PSLogInfo(@"state = %u. Possible",recognizer.state);
  }
  else if (recognizer.state == UIGestureRecognizerStateBegan) {
    // PICKUP EVENT
    PSLogInfo(@"state = %u. StateBegan => pickup",recognizer.state);
    // find the just-pickup-up object's Donor's delegate
    donorView = [[self class] donorOfView:recognizer.view];
     
    [self animatePickingUpView:recognizer.view];
    [donorDelegate donorView:donorView didBeginDraggingView:recognizer.view];
  }
  else if (recognizer.state == UIGestureRecognizerStateChanged) {
    PSLogInfo(@"state = %u. StateChanged => movement",recognizer.state);
  }
  else if (recognizer.state == UIGestureRecognizerStateEnded) {
    // DROP EVENT
    PSLogInfo(@"state = %u. StateEnded => drop",recognizer.state);
    // find the candidate Absorber
    // will the absorber accept the dropped view?
    UIView * draggableView = recognizer.view;
    const BOOL dropWasReceived = [absorberDelegate absorberView:absorberView
                                          canAbsorbDraggingView:draggableView];
    if ( dropWasReceived ) {
      PSLogInfo(@"absorber accepted the drop");
      [donorDelegate donorView:donorView willDonateDraggingView:draggableView];
      [self animateDroppingView:draggableView];
      [absorberDelegate absorberView:absorberView absorbDraggingView:draggableView];
      [donorDelegate donorView:donorView didDonateDraggingView:draggableView];
    }
    else {
      PSLogInfo(@"absorber rejected the drop");
      [donorDelegate donorView:donorView reclaimDraggingView:draggableView];
    }
  }
}

#pragma mark DnD framework helpers

+(UIView*) donorOfView:(UIView*)pickedUpView {
  /* 
   TODO: can beef this up to allow the picked-up view to be not merely the
   subview of the Donor, but some further ancestor.
   */
  return pickedUpView.superview;
}

+(UIView*) absorberOfView:(UIView*)justDroppedView {
  /*
   TODO: can beef this up to allow the just-dropped view to be not merely the
   subview of the Donor, but some further ancestor.
   */
  return justDroppedView.superview;
}

/*
 STAGE 0.
 
 Cache info and do any setup necessary to support the view being dragged later.
 
 This is now implemented in this VC, but maybe this should be part of the DnD
 framework.
 */
-(void) registerDraggableView:(UIView*)descendantView
{
  PSLogInfo(@"");
  // Save its original position, for slide-back if the donor must reclaim it.
  // (This is probably so common a requirement we want it to be generic
  // to the DnD framework.)
  self.initialDraggableViewOrigin = self.draggableItem.frame.origin;
  PSLogInfo(@"initial origin of draggable view = %@",NSStringFromCGPoint(self.initialDraggableViewOrigin));
  // Q: do we also need to cache the donating view (in case it's not self)?
  
  // Attach a UIGestureRecognizer to the draggableView to make it draggable.
  MCKPanGestureRecognizer * panGestureRecognizer =
  [[MCKPanGestureRecognizer alloc] initWithTarget:self
                                          action:@selector(handleDraggablePan:)];
  
  [self.draggableItem addGestureRecognizer:panGestureRecognizer];
  
  //  UIGestureRecognizer * tapRecognizer =
  //  [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
}

-(void)animatePickingUpView:(UIView*)v {
  PSLogInfo(@"");
  // cache old values
  self.initialShadowOffset  = v.layer.shadowOffset;
  self.initialShadowRadius  = v.layer.shadowRadius;
  self.initialShadowOpacity = v.layer.shadowOpacity;
  
  // apply a generic pickup animation
  v.layer.shadowOffset = CGSizeMake(0, 10);
  v.layer.shadowRadius = 25;
  v.layer.shadowOpacity = 1.0;
  v.backgroundColor = [UIColor greenColor]; // for debugging
}

-(void)animateDroppingView:(UIView*)v {
  PSLogInfo(@"");
  // apply a generic drop animation
  v.layer.shadowOffset  = self.initialShadowOffset;
  v.layer.shadowRadius  = self.initialShadowRadius;
  v.layer.shadowOpacity = self.initialShadowOpacity;
  v.backgroundColor = [UIColor whiteColor];
}

#pragma mark  MCKDnDDonorProtocol delegate

/*
 STAGE 1.
 
 The donor could apply its own *specialized* logic here to modify its own
 appearance or state to reflect the fact that part of it has been picked up
 and/or is being dragged away. For instance,
 
 This could also be the place to apply *generic* logic, that all donors would
 want, such as applying a "visual pickup" animation. However, perhaps such
 generic logic should be handled by the DnD framework.
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
  // clear the saved information about its original position
  self.initialDraggableViewOrigin = CGPointZero;
}

/*
 Should this slide-back animation be the responsibility of the DnD framework or the donor?
 */
-(void) donorView:(UIView*)donor reclaimDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  CGRect restoredFrame = draggingSubview.frame;
  restoredFrame.origin = self.initialDraggableViewOrigin;
  [UIView animateWithDuration:0.3f
                   animations:^{
                     draggingSubview.frame = restoredFrame;
                   }
                   completion:^(BOOL finished) {
                     [self animateDroppingView:draggingSubview];
                   }];
}

#pragma mark MCKDnDAbsorberProtocol delegate

/* STAGE 2. */
-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  return CGRectContainsPoint(absorber.bounds,
                             [absorber convertPoint:draggingSubview.center
                                           fromView:draggingSubview.superview]);
  return YES;
}

/* STAGE 4 */
-(void) absorberView:(UIView*)absorber absorbDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  UIView *oldSuperview = draggingSubview.superview;
  PSLogInfo(@"moving dropped view into absorber VH");
  draggingSubview.frame = [absorber convertRect:draggingSubview.frame
                                       fromView:oldSuperview];
  [absorber addSubview:draggingSubview];
  return;
}


@end
