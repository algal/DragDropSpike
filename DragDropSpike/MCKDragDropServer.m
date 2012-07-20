//
//  MCKDragDropServer.m
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-20.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//


#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#import "MCKDragDropServer.h"
#import "MCKPanGestureRecognizer.h"

#define MCK_RECLAIM_ANIMATION_DURATION 0.3f

// helpers for moving views in the view hierarchy but not onscreen
@implementation UIView (MCKmotionless)
-(void)motionlessAddSubview:(UIView*)view
{
  CGRect newFrame = [view.superview convertRect:view.frame toView:self];
  [self addSubview:view];
  view.frame = newFrame;
}

-(void)motionlessInsertSubview:(UIView*)view atIndex:(NSUInteger)index
{
  CGRect newFrame = [view.superview convertRect:view.frame toView:self];
  [self insertSubview:view atIndex:index];
  view.frame = newFrame;
}
@end

@implementation MCKDragDropServer

#pragma mark - Singleton boilerplate

static MCKDragDropServer* sharedServer = nil;

+(MCKDragDropServer*)sharedServer
{
  @synchronized(self) {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{ sharedServer = [[self alloc] init]; });
  }
  return sharedServer;
}

#pragma mark DnD framework internal methods

/*
 Handle a pan gesture from a MCKPanGestureRecognizer
 
 */
-(void)handlePan:(MCKPanGestureRecognizer*)recognizer
{
  UIView * dragView = recognizer.view;
  
  if (recognizer.state == UIGestureRecognizerStatePossible) {
    PSLogInfo(@"state = %u. Possible",recognizer.state);
  }
  
  // PICKUP EVENT
  else if (recognizer.state == UIGestureRecognizerStateBegan) {
    PSLogInfo(@"state = %u. StateBegan => pickup",recognizer.state);
    
    // tell donor that view is about to be detached
    UIView * donorView = [self donorViewOfView:dragView];
    NSObject <MCKDragDropDonor>  * donorDelegate = [self delegateForDonorView:donorView];
    if ([donorDelegate respondsToSelector:@selector(donorView:willBeginDraggingView:)])
      [donorDelegate donorView:donorView willBeginDraggingView:dragView];
    
    // cache original frame
    recognizer.initialViewFrame = dragView.frame;
    
    // cache original donor view
    recognizer.donorView = donorView;
    
    // cache original superview, subview index
    [MCKDragDropServer saveViewHierarchySlotOfView:dragView toRecognizer:recognizer];
    
    // move to top of rootVC's view
    [dragView.window.rootViewController.view motionlessAddSubview:dragView];
    
    // apply pickup effects & cache undo function
    [MCKDragDropServer applyPickupEffectToView:dragView saveUndoToRecognizer:recognizer];
    
    // tell just-picked-up object's Donor's delegate about the drag
    if ([donorDelegate respondsToSelector:@selector(donorView:didBeginDraggingView:)])
      [donorDelegate donorView:donorView didBeginDraggingView:dragView];
  }
  
  // MOVE EVENT
  else if (recognizer.state == UIGestureRecognizerStateChanged) {
    //PSLogInfo(@"state = %u. StateChanged => movement",recognizer.state);
    
    // move the view to follow the finger's translational motion
    CGPoint translation = [recognizer translationInView:dragView.superview];
    dragView.center = CGPointMake(dragView.center.x + translation.x,
                                  dragView.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:dragView.superview];
  }
  
  // DROP EVENT
  else if (recognizer.state == UIGestureRecognizerStateEnded) {
    PSLogInfo(@"state = %u. StateEnded => drop",recognizer.state);
    PSLogInfo(@"theView.frame=%@",NSStringFromCGRect(dragView.frame));
    
    UIView * absorberView = [self firstAbsorberOfView:dragView];
    NSObject <MCKDragDropAbsorber> * absorberDelegate = [self delegateForAbsorberView:dragView];
    
    UIView * donorView = recognizer.donorView;
    NSObject <MCKDragDropDonor>  * donorDelegate = [self delegateForDonorView:donorView];
    
    BOOL absorberAcceptedDrop = YES; // Absorbers default to absorbing
    if (absorberView &&
        [absorberDelegate respondsToSelector:@selector(absorberView:canAbsorbDraggingView:)]) {
      absorberAcceptedDrop = [absorberDelegate absorberView:absorberView canAbsorbDraggingView:dragView];
    }
    
    const BOOL dropWasAccepted = absorberView && absorberAcceptedDrop;
    
    // DROP EVENT : DROP ACCEPTED
    if ( dropWasAccepted ) {
      PSLogInfo(@"absorber accepted the drop");
      if ([donorDelegate respondsToSelector:@selector(donorView:willDonateDraggingView:)])
        [donorDelegate donorView:donorView willDonateDraggingView:dragView];
      
      recognizer.undoPickupEffectOnView();
      [absorberView motionlessAddSubview:dragView];
      
      if ([absorberDelegate respondsToSelector:@selector(absorberView:didAbsorbDraggingView:)])
        [absorberDelegate absorberView:absorberView didAbsorbDraggingView:dragView];
      
      if ([donorDelegate respondsToSelector:@selector(donorView:didDonateDraggingView:)])
        [donorDelegate donorView:donorView didDonateDraggingView:dragView];
    }
    
    // DROP EVENT : DROP REJECTED
    else {
      PSLogInfo(@"absorber rejected the drop");
      
      // animate slide-back to original position ...
      dispatch_block_t UndoPickupEffects = recognizer.undoPickupEffectOnView;
      CGRect restoredFrame = [dragView.superview convertRect:recognizer.initialViewFrame
                                                    fromView:recognizer.initialViewSuperview];
      NSUInteger restoredIndex = recognizer.initialSubviewIndex;
      
      [UIView animateWithDuration:MCK_RECLAIM_ANIMATION_DURATION
                       animations:^{
                         // ... restore absolute frame
                         dragView.frame = restoredFrame;
                       }
                       completion:^(BOOL finished) {
                         // ... then restore appearance
                         UndoPickupEffects();
                         // restore view hierarchy
                         [recognizer.initialViewSuperview motionlessInsertSubview:dragView
                                                                          atIndex:restoredIndex];
                         
                         if ([donorDelegate respondsToSelector:@selector(donorView:didReclaimDraggingView:)])
                           [donorDelegate donorView:donorView didReclaimDraggingView:dragView];
                       }];
    }
  }
  else {
    PSLogInfo(@"state unrecognized");
  }
}

/**
 Finds the donor UIView of the pickedUpView.
 
 @param pickedUpView the view just picked up by the user
 
 The Donor view for a DnD session is the closest ancestor of pickedUpView that 
 has been designated as a donor via a call to registerDonorView:delegate:
 */
-(UIView*) donorViewOfView:(UIView*)pickedUpView
{
  UIView * retval = pickedUpView;
  while ( (retval = pickedUpView.superview) )
  {
    if ( [self isDesignatedDonorView:retval] )
      break;
  }
  PSLogInfo(@"search found donor = %@",retval);
  return retval;
}

/**
 Returns any eligible absorber view beneath the dropped view
 
 @param justDroppedView view being dropped

 A view is designated as an absorber if it has been registered as such via a
 call to registerAbsorberView:delegate:. The eligible absorber view, for a given
 drop, is just the first hit test view under the center of the dropped view
 that is also a designated absorber.
 
 A hit test view must be not hidden, in its superview's bounds, and have 
 userInteractionEnabled. The first hit test view is view meeting those criteria
 that is deepest in view hierarchy. In short, this function traverses possible 
 dropped-on viewss using the same traversal rule as
 -(UIView*)[UIView hitTest:withEvent:, searching for the first candidate that
 has also been designated as a donor.
 
 */
-(UIView*) firstAbsorberOfView:(UIView*)justDroppedView {
  const UIWindow * win = justDroppedView.window;
  const CGPoint dropPoint = [win convertPoint:justDroppedView.center
                                     fromView:justDroppedView.superview];
  UIView * retval = nil;
  justDroppedView.hidden = YES; // exclude from search
  const NSMutableArray * viewsToUnhide = [NSMutableArray arrayWithObject:justDroppedView];
  // get the next hitTest winner
  while ( (retval = [win hitTest:dropPoint withEvent:nil]) ) {
    // if it's an absorber, we're done
    if ([self isDesignatedAbsorberView:retval])
      break;
    else {
      // it was a hitTestWinner, but not an absorber
      retval.hidden=YES; // hide to exclude from the next search
      [viewsToUnhide addObject:retval]; // remember to unhide later
    }
  }
  
  [viewsToUnhide enumerateObjectsUsingBlock:
   ^(id obj, NSUInteger idx, BOOL *stop) { [obj setHidden:NO]; }];
  
  PSLogInfo(@"search found absorber = %@",retval);
  return retval;
}

+(void) saveViewHierarchySlotOfView:(UIView*)v toRecognizer:(MCKPanGestureRecognizer*)recognizer {
  recognizer.initialViewFrame = v.frame;
  recognizer.initialViewSuperview = v.superview;
  recognizer.initialSubviewIndex = [v.superview.subviews indexOfObject:v];
}


+(void) applyPickupEffectToView:(UIView*)v
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

/*
 Registers a view as draggable.
 */
-(void) registerDraggableView:(UIView*)draggableView
{
  PSLogInfo(@"");
  MCKPanGestureRecognizer * panGestureRecognizer =
  [[MCKPanGestureRecognizer alloc] initWithTarget:self
                                           action:@selector(handlePan:)];
  
  [draggableView addGestureRecognizer:panGestureRecognizer];
}


/* The following three methods implement a dictionary from views to their 
 delegates. Using associated objects, rather than dictionary, so that we don't 
 need to do housekeeping on the dictionary to handle keys
 going invalid when views disappear.
 */
static char donorKey;
-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDragDropDonor>*)delegate
{
  objc_setAssociatedObject(view, &donorKey, delegate, OBJC_ASSOCIATION_ASSIGN);
}

-(NSObject<MCKDragDropDonor>*) delegateForDonorView:(UIView*)view {
  return objc_getAssociatedObject(view, &donorKey);
}

-(BOOL)isDesignatedDonorView:(UIView*)view
{
  return ([self delegateForDonorView:view] != nil );
}


static char absorberKey;
-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDragDropAbsorber>*)delegate
{
  objc_setAssociatedObject(view, &absorberKey, delegate, OBJC_ASSOCIATION_ASSIGN);
}

-(NSObject<MCKDragDropAbsorber>*) delegateForAbsorberView:(UIView*)view {
  return objc_getAssociatedObject(view, &absorberKey);
}

-(BOOL)isDesignatedAbsorberView:(UIView *)view
{
  return ([self delegateForAbsorberView:view] != nil );
}

@end
