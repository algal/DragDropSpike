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
 */


@protocol MCKDnDDonorProtocol <NSObject>
// 1. User picks up an object within Donor's view hierarchy (VH).
/** Tells delegate the user has picked up draggingSubview of donor */
-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview;

// 2. Absorber view decides if it accepts or rejects the drop

// 3a. Donor yields the draggingSubview to the Absorber.
/** Tells delegate draggingSubview will soon be 'donated' to absorber view */
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview;
/** Tells delegate draggingSubview has just been 'donated' to absorber view */
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview;

// 3b. Donor re-integrates draggingSubview, which Absorber rejected
/**
  Reclaim draggingSubview into donorView's view hierarchy.
  @param donor
  @param draggingSubview
  Called if an attempted drop was rejected by the absorber. Should probably 
 animate the dropped view back to its original position and restore the state 
 of the donor view to its value before the draggingSubview was picked up.
 */
-(void) donorView:(UIView*)donor reclaimDraggingView:(UIView*)draggingSubview;
@end

@protocol MCKDnDAbsorberProtocol <NSObject>
/** 
  Called to determine if absorber will accept the drop of draggingSubview.
 @param absorber
 @param draggingSubview
 
 Called to determine if absorber will accept the drop of draggingSubview. This
 determines the effective drop zone for draggingSubview
 */
-(BOOL) absorberView:(UIView*)absorber canAbsorbDraggingView:(UIView*)draggingSubview;

/**
 Absorb draggingSubview into absorber's view hierarchy.
 @param absorber
 @param draggingSubview

 Absorber could actually take and integrate the draggingSubview object directly
 into its own view hierarchy, or it could 
 */
-(void) absorberView:(UIView*)absorber absorbDraggingView:(UIView*)draggingSubview;
@end
