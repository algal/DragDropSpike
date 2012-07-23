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
    PSLogInfo(@"1. state = %u. Possible",recognizer.state);
  }
  
  // PICKUP EVENT
  else if (recognizer.state == UIGestureRecognizerStateBegan) {
    PSLogInfo(@"2. state = %u. StateBegan => pickup",recognizer.state);
    
    /* 
     Assert:
     recgonizer.donorView has already been initialized in the GR itself.
     
     Assert:
     If defined, [MCKDragDropDonor donorView:shouldBeginDraggingView:] has already returned YES.

     */
   
    UIView * donorView = recognizer.donorView;
    NSObject <MCKDragDropDonorDelegate>  * donorDelegate = [self delegateForDonorView:donorView];

    PSLogInfo(@"3. dragView.frame = %@",NSStringFromCGRect(dragView.frame));

    NSObject * payload;
    // tell donor that view is about to be detached
    if ([donorDelegate respondsToSelector:@selector(donorView:willBeginDraggingView:)])
      payload = [donorDelegate donorView:donorView willBeginDraggingView:dragView];
    
    // cache payload
    recognizer.payload = payload;
   
    // cache original frame, donor, superview, etc.
    recognizer.initialViewFrame = dragView.frame;
    recognizer.donorView = donorView;
    [MCKDragDropServer saveViewHierarchySlotOfView:dragView toRecognizer:recognizer];
    
    PSLogInfo(@"5. dragView.frame = %@",NSStringFromCGRect(dragView.frame));

    // move to top of rootVC's view
    [dragView.window.rootViewController.view motionlessAddSubview:dragView];
    
    PSLogInfo(@"6. dragView.frame = %@",NSStringFromCGRect(dragView.frame));

    // apply pickup effects & cache undo function
    [MCKDragDropServer applyPickupEffectToView:dragView saveUndoToRecognizer:recognizer];
    
    PSLogInfo(@"7. dragView.frame = %@",NSStringFromCGRect(dragView.frame));
    
    // tell just-picked-up object's Donor's delegate about the drag
    if ([donorDelegate respondsToSelector:@selector(donorView:didBeginDraggingView:)])
      [donorDelegate donorView:donorView didBeginDraggingView:dragView];
    
    PSLogInfo(@"8. dragView.frame = %@",NSStringFromCGRect(dragView.frame));
  }
  
  // MOVE EVENT
  else if (recognizer.state == UIGestureRecognizerStateChanged) {
    PSLogInfo(@"9. state = %u. StateChanged => movement",recognizer.state);
    PSLogInfo(@"10. dragView.frame = %@",NSStringFromCGRect(dragView.frame));
    
    // move the view to follow the finger's translational motion
    CGPoint translation = [recognizer translationInView:dragView.superview];
    dragView.center = CGPointMake(dragView.center.x + translation.x,
                                  dragView.center.y + translation.y);
    [recognizer setTranslation:CGPointMake(0, 0) inView:dragView.superview];
    PSLogInfo(@"11. dragView.frame = %@",NSStringFromCGRect(dragView.frame));
    
  }
  
  // DROP EVENT
  else if (recognizer.state == UIGestureRecognizerStateEnded) {
    PSLogInfo(@"state = %u. StateEnded => drop",recognizer.state);
    PSLogInfo(@"theView.frame=%@",NSStringFromCGRect(dragView.frame));
    
    UIView * absorberView = [self firstAbsorberOfView:dragView];
    NSObject <MCKDragDropAbsorberDelegate> * absorberDelegate = [self delegateForAbsorberView:absorberView];
    UIView * donorView = recognizer.donorView;
    NSObject <MCKDragDropDonorDelegate>  * donorDelegate = [self delegateForDonorView:donorView];
    id<NSObject> payload = recognizer.payload;

    BOOL dropWasAccepted = NO;
    if (!absorberView)
    {
      dropWasAccepted = NO; // it is required to have an absorber
      PSLogError(@"no absorberView found for dropped view=%@",dragView);
    }
    else {
      dropWasAccepted = YES; // absorbers default to accepting drops. their delegate can veto it.
      
      if (absorberDelegate &&
          [absorberDelegate respondsToSelector:@selector(absorberView:canAbsorbDraggingView:payload:)]) {
        dropWasAccepted = [absorberDelegate absorberView:absorberView
                                   canAbsorbDraggingView:dragView
                                                 payload:payload];
      }
    }
    
    // DROP EVENT : DROP ACCEPTED
    if ( dropWasAccepted ) {
      PSLogInfo(@"absorber accepted the drop");
      if ([donorDelegate respondsToSelector:@selector(donorView:willDonateDraggingView:)])
        [donorDelegate donorView:donorView willDonateDraggingView:dragView];
      
      recognizer.undoPickupEffectOnView();
      [absorberView motionlessAddSubview:dragView];
      
      if ([absorberDelegate respondsToSelector:@selector(absorberView:didAbsorbDraggingView:payload:)])
        [absorberDelegate absorberView:absorberView
                 didAbsorbDraggingView:dragView
                               payload:payload];
      
      if ([donorDelegate respondsToSelector:@selector(donorView:didDonateDraggingView:)])
        [donorDelegate donorView:donorView didDonateDraggingView:dragView];
    }
    
    // DROP EVENT : DROP REJECTED
    else {
      PSLogInfo(@"absorber rejected the drop, or there was no absorber.");
      
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
    PSLogInfo(@"UIGestureRecognizerState unrecognized=%u",recognizer.state);
  }
}

/**
 Finds the donor UIView of the pickedUpView.
 
 @param pickedUpView the view just picked up by the user
 @return the pickedUpView's donor, or nil if there is none.
 
 The Donor view for a DnD session is the closest ancestor of pickedUpView which 
 has has been designated as a donor via a call to registerDonorView:delegate:.
 */
-(UIView*) donorViewOfView:(UIView*)pickedUpView
{
  UIView * retval = pickedUpView;
  while ( (retval = pickedUpView.superview) )
  {
    if ( [self isDesignatedDonorView:retval] )
      break;
  }

  if (retval)
    PSLogInfo(@"search found donor = %@",retval);
  else
    PSLogError(@"did not find a donor for view=%@",pickedUpView);
  
  return retval;
}

/**
 Returns any eligible absorber view beneath the dropped view
 
 @param justDroppedView view being dropped
 @return the eligible absorber view for the drop, or nil if none was found.

 The eligible absorber view, for a given drop, is just the first hit test view 
 under the center of the dropped view that is also a designated absorber. A 
 view is designated as an absorber if it has been registered as such via a
 call to registerAbsorberView:delegate:.
 
 A hit test view must be unhidden, in its superview's bounds, and have
 userInteractionEnabled. The first hit test view is the view meeting those criteria
 that is deepest in view hierarchy. In short, this function traverses possible 
 dropped-on views using the same traversal rule as
 -(UIView*)[UIView hitTest:withEvent:, searching for the first candidate that
 has also been designated as an absorber.
 
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
  
  if (retval)
    PSLogInfo(@"search found absorber = %@",retval);
  else
    PSLogError(@"could not find an absorber for dropped view = %@",justDroppedView);

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


/* The following three methods implement a dictionary from views to their delegates. I'm using 
 associated objects rather than dictionary to avoid implementing housekeeping on the dictionary
 for when keys going invalid when views disappear.
 */
static char donorKey;
-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDragDropDonorDelegate>*)delegate
{
  if ( view )
    objc_setAssociatedObject(view, &donorKey, delegate, OBJC_ASSOCIATION_ASSIGN);
}

-(NSObject<MCKDragDropDonorDelegate>*) delegateForDonorView:(UIView*)view
{
  return objc_getAssociatedObject(view, &donorKey);
}

-(BOOL)isDesignatedDonorView:(UIView*)view
{
  return ([self delegateForDonorView:view] != nil );
}


static char absorberKey;
-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDragDropAbsorberDelegate>*)delegate
{
  if ( view )
    objc_setAssociatedObject(view, &absorberKey, delegate, OBJC_ASSOCIATION_ASSIGN);
}

-(NSObject<MCKDragDropAbsorberDelegate>*) delegateForAbsorberView:(UIView*)view {
  return objc_getAssociatedObject(view, &absorberKey);
}

-(BOOL)isDesignatedAbsorberView:(UIView *)view {
  return ([self delegateForAbsorberView:view] != nil );
}

@end
