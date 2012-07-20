//
//  MCKDragDropServer.m
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-20.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//


#import <QuartzCore/QuartzCore.h>

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

@interface MCKDragDropServer ()
@property (strong) NSMutableDictionary * donorViews;
@property (strong) NSMutableDictionary * absorberViews;
@end

@implementation MCKDragDropServer
@synthesize donorViews = _donorViews;
@synthesize absorberViews = _absorberViews;

#pragma mark - Singleton boilerplate

// singleton implementation
static MCKDragDropServer* sharedServer = nil;

+(MCKDragDropServer*)sharedServer
{
  @synchronized(self) {
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{ sharedServer = [[self alloc] init]; });
  }
  return sharedServer;
}

-(id)init
{
  self = [super init];
  if (self) {
    _donorViews = [NSMutableDictionary dictionary];
    _absorberViews = [NSMutableDictionary dictionary];
  }
  return self;
}



#pragma mark DnD framework public API

/*
 STAGE 0.
 
 Cache info and do any setup necessary to support the view being dragged later.
 
 This is now implemented in this VC, but maybe this should be part of the DnD
 framework.
 */
-(void) registerDraggableView:(UIView*)draggableView
{
  PSLogInfo(@"");
  MCKPanGestureRecognizer * panGestureRecognizer =
  [[MCKPanGestureRecognizer alloc] initWithTarget:self
                                           action:@selector(handlePan:)];
  
  [draggableView addGestureRecognizer:panGestureRecognizer];
}

// FIXME: Must handle clearing this dictionary as views are removed.
/*
 Otherwise we could have a collsion where a NEW view happens to have the same
 memory location as a removed view, and the dictionary is still holding on to
 that view (via the NSValue-wrapped pointer) thinking it has its delegate when
 in fact it has the delegate to the removed/dealloced view. 
 
 Is there some way to register for notifications when a view is dealloced? Then
 we could clear the corresponding dictionary entries when the view disappears.
 
 If not, is there a way to create a mutable dictionary whose keys are zeroing
 weak references, so that they go to nil (disappear) as soon as their 
 referenced object does?
 
 If not, instead of dictionaries we could use associated references on the views
 themselves.
 */

-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDragDropDonor>*)delegate
{
  [self.donorViews setObject:delegate forKey:[NSValue valueWithNonretainedObject:view]];
}

-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDragDropAbsorber>*)delegate
{
  [self.absorberViews setObject:delegate forKey:[NSValue valueWithNonretainedObject:view]];
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
    [self saveViewHierarchySlotOfView:dragView toRecognizer:recognizer];
    
    // move to top of rootVC's view
    [dragView.window.rootViewController.view motionlessAddSubview:dragView];
    
    // apply pickup effects & cache undo function
    [self applyPickupEffectToView:dragView saveUndoToRecognizer:recognizer];
    
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
 
 The Donor view is the closest ancestor of pickedUpView that is a MCKDnDDonor.
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
 Returns first eligible absorber view beneath the dropped view
 
 @param justDroppedView view being dropped
 
 A view eligible to receive a drop if it is designated an absorber, is
 not hidden, is in its superview's bounds, and has userInteractionEnabled. The
 first eligible view is the view deepest in the view hierarchy. In other words,
 traverses possible dropped on view's using the same traversal rule as
 -(UIView*)[UIView hitTest:withEvent:, searching for the first candidate that
 conforms to MCKDnDAbsorberView.
 
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

-(BOOL)isDesignatedAbsorberView:(UIView *)view
{
  return ([self.absorberViews objectForKey:[NSValue valueWithNonretainedObject:view]] != nil );
}

-(BOOL)isDesignatedDonorView:(UIView*)view
{
  return ([self.donorViews objectForKey:[NSValue valueWithNonretainedObject:view]] != nil );
}

-(NSObject<MCKDragDropDonor>*) delegateForDonorView:(UIView*)view {
  return [self.donorViews objectForKey:[NSValue valueWithNonretainedObject:view]];
}

-(NSObject<MCKDragDropAbsorber>*) delegateForAbsorberView:(UIView*)view {
  return [self.absorberViews objectForKey:[NSValue valueWithNonretainedObject:view]];
}



@end
