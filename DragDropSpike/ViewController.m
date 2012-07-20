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

// helpers for moving views in the view hierarchy but not onscreen
@implementation UIView (MCKmotionless)
// TODO: move these two into DnD internal
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

// TODO: refactor into DnD
@interface ViewController ()
@property (strong) NSMutableDictionary * donorViews;
@property (strong) NSMutableDictionary * absorberViews;
@end


@implementation ViewController

@synthesize leftContainer;
@synthesize rightContainer;
@synthesize draggableItem;

// TODO: refactor into DnD
@synthesize donorViews,absorberViews;



- (void)viewDidLoad
{
  [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
  
  self.donorViews = [NSMutableDictionary dictionary];
  self.absorberViews = [NSMutableDictionary dictionary];
  
  [self registerDraggableView:draggableItem];
  [self registerDonorView:self.leftContainer delegate:self];
  [self registerDonorView:self.rightContainer delegate:self];
  [self registerAbsorberView:self.leftContainer delegate:self];
  [self registerAbsorberView:self.rightContainer delegate:self];
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


#pragma mark DnD framework public API

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
                                           action:@selector(handlePan:)];
  
  [self.draggableItem addGestureRecognizer:panGestureRecognizer];
}

-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDnDDonorProtocol>*)delegate
{
  PSLogInfo(@"");
  BOOL conforms = [[NSValue valueWithNonretainedObject:view] conformsToProtocol:@protocol(NSCopying)];
  PSLogInfo(@"key is valid: %@", conforms ? @"YES" : @"NON");
  [self.donorViews setObject:delegate forKey:[NSValue valueWithNonretainedObject:view]];
  PSLogInfo(@"");
}

-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDnDAbsorberProtocol>*)delegate
{
  [self.absorberViews setObject:delegate forKey:[NSValue valueWithNonretainedObject:view]];
}

#pragma mark DnD framework internal methods

/*
 Handle a pan gesture from a MCKPanGestureRecognizer
 
 */
-(void)handlePan:(MCKPanGestureRecognizer*)recognizer
{
  UIView * theView = recognizer.view;
  
  if (recognizer.state == UIGestureRecognizerStatePossible) {
    PSLogInfo(@"state = %u. Possible",recognizer.state);
  }
  
  // PICKUP EVENT
  else if (recognizer.state == UIGestureRecognizerStateBegan) {
    PSLogInfo(@"state = %u. StateBegan => pickup",recognizer.state);
    
    // tell donor that view is about to be detached
    UIView * donorView = [self donorViewOfView:recognizer.view];
    NSObject <MCKDnDDonorProtocol>  * donorDelegate = [self delegateForDonorView:donorView];
    if ([donorDelegate respondsToSelector:@selector(donorView:willBeginDraggingView:)])
      [donorDelegate donorView:donorView willBeginDraggingView:recognizer.view];
    
    // cache original frame
    recognizer.initialViewFrame = recognizer.view.frame;
    
    // cache original donor view
    recognizer.donorView = donorView;
    
    // cache original superview, subview index
    [self saveViewHierarchySlotOfView:recognizer.view toRecognizer:recognizer];

    // move to top of rootVC's view
    [recognizer.view.window.rootViewController.view motionlessAddSubview:recognizer.view];
    
    // apply pickup effects & cache undo function
    [self applyPickupEffectToView:recognizer.view saveUndoToRecognizer:recognizer];
    
    // tell just-picked-up object's Donor's delegate about the drag
    if ([donorDelegate respondsToSelector:@selector(donorView:didBeginDraggingView:)])
      [donorDelegate donorView:donorView didBeginDraggingView:recognizer.view];
  }
  
  // MOVE EVENT
  else if (recognizer.state == UIGestureRecognizerStateChanged) {
    //PSLogInfo(@"state = %u. StateChanged => movement",recognizer.state);
    
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
    UIView * absorberView = [self firstAbsorberOfView:recognizer.view];
    NSObject <MCKDnDAbsorberProtocol> * absorberDelegate = [self delegateForAbsorberView:recognizer.view];
    
    UIView * donorView = recognizer.donorView;
    NSObject <MCKDnDDonorProtocol>  * donorDelegate = [self delegateForDonorView:donorView];
    
    BOOL absorberAcceptedDrop = YES; // Absorbers default to absorbing
    if (absorberView &&
        [absorberDelegate respondsToSelector:@selector(absorberView:canAbsorbDraggingView:)]) {
      absorberAcceptedDrop = [absorberDelegate absorberView:absorberView canAbsorbDraggingView:beingDroppedView];
    }
    
    const BOOL dropWasAccepted = absorberView && absorberAcceptedDrop;
                                                 
    // DROP EVENT : DROP ACCEPTED
    if ( dropWasAccepted ) {
      PSLogInfo(@"absorber accepted the drop");
      if ([donorDelegate respondsToSelector:@selector(donorView:willDonateDraggingView:)])
        [donorDelegate donorView:donorView willDonateDraggingView:beingDroppedView];

      recognizer.undoPickupEffectOnView();
      [absorberView motionlessAddSubview:beingDroppedView];

      if ([absorberDelegate respondsToSelector:@selector(absorberView:didAbsorbDraggingView:)])
        [absorberDelegate absorberView:absorberView didAbsorbDraggingView:beingDroppedView];

      if ([donorDelegate respondsToSelector:@selector(donorView:didDonateDraggingView:)])
        [donorDelegate donorView:donorView didDonateDraggingView:beingDroppedView];
    }
    
    // DROP EVENT : DROP REJECTED
    else {
      PSLogInfo(@"absorber rejected the drop");
      
      // animate slide-back to original position ...
      dispatch_block_t UndoPickupEffects = recognizer.undoPickupEffectOnView;
      CGRect restoredFrame = [beingDroppedView.superview convertRect:recognizer.initialViewFrame
                                                            fromView:recognizer.initialViewSuperview];
      NSUInteger restoredIndex = recognizer.initialSubviewIndex;
      
      [UIView animateWithDuration:0.3f
                       animations:^{
                         // ... restore absolute frame
                         beingDroppedView.frame = restoredFrame;
                       }
                       completion:^(BOOL finished) {
                         // ... then restore appearance
                         UndoPickupEffects();
                         // restore view hierarchy
                         [recognizer.initialViewSuperview motionlessInsertSubview:beingDroppedView
                                                                          atIndex:restoredIndex];
                         
                         if ([donorDelegate respondsToSelector:@selector(donorView:didReclaimDraggingView:)])
                           [donorDelegate donorView:donorView didReclaimDraggingView:beingDroppedView];
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

-(NSObject<MCKDnDDonorProtocol>*) delegateForDonorView:(UIView*)view {
  return [self.donorViews objectForKey:[NSValue valueWithNonretainedObject:view]];
  }

-(NSObject<MCKDnDAbsorberProtocol>*) delegateForAbsorberView:(UIView*)view {
  return [self.absorberViews objectForKey:[NSValue valueWithNonretainedObject:view]];
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
 Tells absorber that draggingView has been added to its VH.
 */
-(void) absorberView:(UIView*)absorber didAbsorbDraggingView:(UIView*)draggingSubview
{
  PSLogInfo(@"");
  return;
}

@end
