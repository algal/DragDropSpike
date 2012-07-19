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

  
  UIView * theView = recognizer.view;
  
  if (recognizer.state == UIGestureRecognizerStatePossible) {
    PSLogInfo(@"state = %u. Possible",recognizer.state);
  }

  // PICKUP EVENT
  else if (recognizer.state == UIGestureRecognizerStateBegan) {
    PSLogInfo(@"state = %u. StateBegan => pickup",recognizer.state);

    // cache original frame
    recognizer.initialViewFrame = recognizer.view.frame;
   
    // cache original superview, subview index
    [self saveViewHierarchySlotOfView:recognizer.view toRecognizer:recognizer];

    // tell donor view is about to be detached
    donorView = [self  donorViewOfView:recognizer.view];
    NSAssert(donorView == recognizer.view.superview, @"ERROR");
    [donorDelegate donorView:donorView willBeginDraggingView:recognizer.view];
    
    // move to top of rootVC's view
    [[self class] swapView:recognizer.view
               toSuperview:recognizer.view.window.rootViewController.view];
    
    // apply pickup effects & cache undo function
    [self applyPickupEffectToView:recognizer.view saveUndoToRecognizer:recognizer];

    // tell just-picked-up object's Donor's delegate about the drag
    [donorDelegate donorView:donorView didBeginDraggingView:recognizer.view];
  }

  // MOVE EVENT
  else if (recognizer.state == UIGestureRecognizerStateChanged) {
    PSLogInfo(@"state = %u. StateChanged => movement",recognizer.state);
    
    // move the view to follow the finger's translational motion
    CGPoint translation = [recognizer translationInView:recognizer.view.superview];
    recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                         recognizer.view.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:recognizer.view.superview];
  }

  // DROP EVENT
  else if (recognizer.state == UIGestureRecognizerStateEnded) {
    PSLogInfo(@"state = %u. StateEnded => drop",recognizer.state);
    PSLogInfo(@"theView.frame=%@",NSStringFromCGRect(theView.frame));
    
    UIView * beingDroppedView = recognizer.view;
    absorberView = [self absorberOfView:recognizer.view];
    // will the absorber accept the dropped view?
    const BOOL dropWasAccepted = [absorberDelegate absorberView:absorberView
                                          canAbsorbDraggingView:beingDroppedView];
    // DROP ACCEPTED
    if ( dropWasAccepted ) {
      PSLogInfo(@"absorber accepted the drop");
      [donorDelegate donorView:donorView willDonateDraggingView:beingDroppedView];
      recognizer.undoPickupEffectOnView();
      [[self class] swapView:beingDroppedView toSuperview:absorberView];
      [absorberDelegate absorberView:absorberView didAbsorbDraggingView:beingDroppedView];
      [donorDelegate donorView:donorView didDonateDraggingView:beingDroppedView];
    }
    // DROP REJECTED
    else {
      PSLogInfo(@"absorber rejected the drop");
      
      // animate slide-back to original position ...
      dispatch_block_t UndoPickupEffects = recognizer.undoPickupEffectOnView;
      CGRect restoredFrame = [beingDroppedView.superview convertRect:recognizer.initialViewFrame
                                                            fromView:recognizer.initialViewSuperview];
      [UIView animateWithDuration:0.3f
                       animations:^{
                         // ... restore absolute frame
                         beingDroppedView.frame = restoredFrame;
                       }
                       completion:^(BOOL finished) {
                         // ... then restore appearance
                         UndoPickupEffects();
                         // restore view hierarchy
                         // FIXME not restoring subviewIndex properly
                         [[self class] swapView:beingDroppedView toSuperview:recognizer.initialViewSuperview];
                         [donorDelegate donorView:donorView didReclaimDraggingView:beingDroppedView];
                       }];
    }
  }
  else {
    PSLogInfo(@"state unrecognized");
  }
}

#pragma mark DnD framework helpers

/** moves view within the view hierarchy, preserving absolute frame */
+ (void) swapView:(UIView*)view toSuperview:(UIView*)newSuperview {
  CGRect newFrame = [view.superview convertRect:view.frame toView:newSuperview];
  [newSuperview addSubview:view];
  view.frame = newFrame;
}

// FIXME: enhance to allow view's Donor to be any ancestor
/**
  Finds the donor UIView of the pickedUpView. 

 @param pickedUpView the view just picked up by the user

 The Donor view is the closest ancestor of pickedUpView that is a MCKDnDDonor.
 */
-(UIView*) donorViewOfView:(UIView*)pickedUpView
{
  UIView * retval = pickedUpView;
  while ( (retval = pickedUpView.superview) )
  {
    if ( [self isADonorView:retval] )
      break;
  }
  return retval;
}

/**
  Returns first eligible absorber view beneath the dropped view
 
 @param justDroppedView view being dropped
 
 A view eligible to receive a drop if it conforms to MCKDnDAbsorberView, is
 not hidden, is in its superview's bounds, and has userInteractionEnabled. The
 first eligible view is the view deepest in the view hierarchy. In other words,
 traverses possible dropped on view's using the same traversal rule as
 -(UIView*)[UIView hitTest:withEvent:, searching for the first candidate that
 conforms to MCKDnDAbsorberView.

 */
-(UIView*) absorberOfView:(UIView*)justDroppedView {
  const UIWindow * win = [[UIApplication sharedApplication] keyWindow];
  const CGPoint dropPoint = [win convertPoint:justDroppedView.center
                                     fromView:justDroppedView.superview];

  UIView * retval = nil;
  justDroppedView.hidden = YES; // exclude from search
  const NSMutableArray * viewsToUnhide = [NSMutableArray arrayWithObject:justDroppedView];
   // get the next hitTest winner
  while ( (retval = [win hitTest:dropPoint withEvent:nil]) ) {
    // if it's also an absorber, we're done
    if ([self isAnAbsorberView:retval])
      break;
    else {
      // it was a hitTestWinner, but not an absorber
      retval.hidden=YES; // hide to exclude from the next search
      [viewsToUnhide addObject:retval]; // remember to unhide later
    }
  }
 
  [viewsToUnhide enumerateObjectsUsingBlock:
   ^(id obj, NSUInteger idx, BOOL *stop) { [obj setHidden:NO]; }];
  
  return retval;
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


-(void) saveViewHierarchySlotOfView:(UIView*)v toRecognizer:(MCKPanGestureRecognizer*)recognizer {
  recognizer.initialViewFrame = v.frame;
  recognizer.initialViewSuperview = v.superview;
  recognizer.initialSubviewIndex = [v.superview.subviews indexOfObject:v];
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

-(void) donorView:(UIView*)donor willBeginDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
}

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
 Tells donor that draggingView was animated back into old position.
 */
-(void) donorView:(UIView*)donor didReclaimDraggingView:(UIView*)draggingSubview
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

/* STAGE 4
 this method is repsonsible for taking dragginView into the absorber's VH.
 */
-(void) absorberView:(UIView*)absorber didAbsorbDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  return;
}

-(BOOL)isAnAbsorberView:(UIView *)view
{
  if (view == self.rightContainer || self.leftContainer)
    return YES;
  else
    return NO;
}

-(BOOL)isADonorView:(UIView*)view
{
  if (view == self.rightContainer || self.leftContainer)
    return YES;
  else
    return NO;
}
@end
