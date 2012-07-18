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

@implementation ViewController

@synthesize leftContainer;
@synthesize rightContainer;
@synthesize draggableItem;

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


/*
 
  // should compute (and cache?) donorView at pick-up time

  // should assign (potential) absorberView at drop time
  // at drop time, need to know donorView to order a reclaim.
  // so how to remember donorView?
  // => Q: does this mean this info needs to be cached in a drag session object?
  
 */
-(void)handleDraggablePan:(UIPanGestureRecognizer*)theRecognizer
{
  MCKPanGestureRecognizer * recognizer = (MCKPanGestureRecognizer*)theRecognizer;
  
  UIView * donorView;
  UIView * absorberView;
  NSObject <MCKDnDAbsorberProtocol> * absorberDelegate = self;
  NSObject <MCKDnDDonorProtocol>    * donorDelegate = self;

  if (recognizer.state == UIGestureRecognizerStatePossible) {
    PSLogInfo(@"state = %u. Possible",recognizer.state);
  }
  else if (recognizer.state == UIGestureRecognizerStateBegan) {
    // PICKUP EVENT
    PSLogInfo(@"state = %u. StateBegan => pickup",recognizer.state);

    // cache original position
    recognizer.initialViewFrameOrigin = recognizer.view.frame.origin;
    PSLogInfo(@"caching initial view center of %@",NSStringFromCGPoint(recognizer.initialViewFrameOrigin));

    // apply pickup effects & cache undo function
    [self applyPickupEffectToView:recognizer.view saveUndoToRecognizer:recognizer];

    // tell just-picked-up object's Donor's delegate about the drag
    donorView = [[self class] donorOfView:recognizer.view];
    [donorDelegate donorView:donorView didBeginDraggingView:recognizer.view];
  }
  else if (recognizer.state == UIGestureRecognizerStateChanged) {
    // MOVE EVENT
    PSLogInfo(@"state = %u. StateChanged => movement",recognizer.state);
    
    // move the view to follow the finger's translational motion
    CGPoint translation = [recognizer translationInView:recognizer.view.superview];
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:recognizer.view.superview];
  }
  else if (recognizer.state == UIGestureRecognizerStateEnded) {
    // DROP EVENT
    PSLogInfo(@"state = %u. StateEnded => drop",recognizer.state);

    UIView * beingDroppedView = recognizer.view;
    absorberView = [self absorberOfView:recognizer.view];
    // will the absorber accept the dropped view?
    const BOOL dropWasAccepted = [absorberDelegate absorberView:absorberView
                                          canAbsorbDraggingView:beingDroppedView];
    if ( dropWasAccepted ) {
      PSLogInfo(@"absorber accepted the drop");
      [donorDelegate donorView:donorView willDonateDraggingView:beingDroppedView];
      recognizer.undoPickupEffectOnView();
      [absorberDelegate absorberView:absorberView absorbDraggingView:beingDroppedView];
      [donorDelegate donorView:donorView didDonateDraggingView:beingDroppedView];
    }
    else {
      PSLogInfo(@"absorber rejected the drop");
      // animate slide-back to original position ...
      UIView * draggingSubview = recognizer.view;

      CGRect restoredFrame = draggingSubview.frame;
      restoredFrame.origin = recognizer.initialViewFrameOrigin;

      dispatch_block_t UndoPickupEffects = recognizer.undoPickupEffectOnView;
      [UIView animateWithDuration:0.3f
                       animations:^{
                         draggingSubview.frame = restoredFrame;
                       }
                       completion:^(BOOL finished) {
                         // ... then restore appearance
                         UndoPickupEffects();
                       }];

      [donorDelegate donorView:donorView reclaimDraggingView:beingDroppedView];
    }
  }
  else {
    PSLogInfo(@"state unrecognized");
  }
}

#pragma mark DnD framework helpers

// FIXME: enhance to allow view's Donor to be any ancestor
+(UIView*) donorOfView:(UIView*)pickedUpView {
  return pickedUpView.superview;
}

// FIXME: add hit testing to compute aborber from droppedView's location
-(UIView*) absorberOfView:(UIView*)justDroppedView {
  /*
   Need an algorithm here for identifying an appropriately-marked view given
   a location for the drop.
   
   The hit-test algorithm already defines a traversal order for views based
   on a given location. Perhaps just traverse like that, and use the first
   view that conforms to a protocol?
   */
  return self.rightContainer;
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
  // Q: do we also need to cache the donating view (in case it's not self)?
  
  // Attach a UIGestureRecognizer to the draggableView to make it draggable.
  MCKPanGestureRecognizer * panGestureRecognizer =
  [[MCKPanGestureRecognizer alloc] initWithTarget:self
                                          action:@selector(handleDraggablePan:)];
  
  [self.draggableItem addGestureRecognizer:panGestureRecognizer];
  
}

-(void) applyPickupEffectToView:(UIView*)v
           saveUndoToRecognizer:(MCKPanGestureRecognizer*)recognizer {
  PSLogInfo(@"");
  // cache original values in restorer function
  CGSize  theInitialShadowOffset  = v.layer.shadowOffset;
  CGFloat theInitialShadowRadius  = v.layer.shadowRadius;
  CGFloat theInitialShadowOpacity = v.layer.shadowOpacity;
  UIColor * theInitialColor = v.backgroundColor;
  
  recognizer.undoPickupEffectOnView = ^ {
    // block now holds strong reference to UIVIew, so it will keep the view
    // alive until its own owning recognizer is dealloced.
    v.layer.shadowOffset = theInitialShadowOffset;
    v.layer.shadowRadius = theInitialShadowRadius;
    v.layer.shadowOpacity = theInitialShadowOpacity;
    v.backgroundColor = theInitialColor;
  };
  
  // apply a generic pickup animation
  v.layer.shadowOffset = CGSizeMake(0, 10);
  v.layer.shadowRadius = 25;
  v.layer.shadowOpacity = 1.0;
  v.backgroundColor = [UIColor greenColor]; // for debugging
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
}

/*
 Should this slide-back animation be the responsibility of the DnD framework or the donor?
 */
-(void) donorView:(UIView*)donor reclaimDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
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
