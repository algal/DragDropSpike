//
//  MCKDragDropProtocol.h
//  discoveryboard
//
//  Created by Alexis Gallagher on 2012-07-14.
//
//

#import <Foundation/Foundation.h>

/***
 Delegate protocol declaring methods required for drag-and-drop mechanics,
 where a Donor UIView can give up one of its subviews to an Absorber UIView,
 which may accept or reject the draggingSubview.
 
 
 Q:
 Should some of these methods be removed, and instead implementers should
 just override the existing UIView methods:
 – (void) [UIView didAddSubview:(UIView*)subview]
 – (void) [UIView willRemoveSubview:(UIView*)subview]

 */


@protocol MCKDnDDonorProtocol <NSObject>

/** Tells delegate the user will remove the draggingSubview from the donor */
-(void) donorView:(UIView*)donor willBeginDraggingView:(UIView*)draggingSubview;

// 1. User picks up an object within Donor's view hierarchy (VH).
/** Tells delegate the user has removed the draggingSubview from the donor */
-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview;

// 2. Absorber delegate decides if it accepts or rejects the drop

// A.3 Donor yields the draggingSubview to the Absorber.
/** Tells delegate draggingSubview will soon be 'donated' to absorber view */
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview;

// A.5 Donor notified Absorber has received the view
/** Tells delegate draggingSubview has just been 'donated' to absorber view */
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview;

// B.3. Donor re-integrates draggingSubview, which Absorber rejected
/**
  Tells donor draggingSubview was returned after a rejected drop.
  @param donor
  @param draggingSubview
  Called if an attempted drop was rejected by the absorber. Should probably 
 animate the dropped view back to its original position and restore the state 
 of the donor view to its value before the draggingSubview was picked up.
 */
-(void) donorView:(UIView*)donor didReclaimDraggingView:(UIView*)draggingSubview;
@end


@protocol MCKDnDAbsorberProtocol <NSObject>

// 2. Absorber view decides if it accepts or rejects the drop (-> A.3 or B.3)
/**
  Called to determine if absorber will accept the drop of draggingSubview.
 @param absorber
 @param draggingSubview
 
 Called to determine if absorber will accept the drop of draggingSubview. This
 determines the effective drop zone for draggingSubview
 */
-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview;

// A.4 Absorber receives the donated view
/**
 Tells delegate draggingSubview has been inserted into absorber's VH.

 @param absorber
 @param draggingSubview

 Absorber should perform any work necessary after having been given the dropped
 view. Absorber could actually integrate the draggingSubview object directly
 into its own view hierarchy, or it could kill it, replace it with a lookalike,
 etc..
 */
-(void) absorberView:(UIView*)absorber didAbsorbDraggingView:(UIView*)draggingSubview;
@end
