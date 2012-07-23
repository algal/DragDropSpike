//
//  MCKDragDropProtocol.h
//  discoveryboard
//
//  Created by Alexis Gallagher on 2012-07-14.
//
//

#import <Foundation/Foundation.h>

/**
 Delegate protocol for declaring optional methods to notify Donors and Absorbers
 of the progress of a drag and drop session.

 To make a view drag-and-droppable, or to make it a donor and/or receiver,
 call the registration methods on the MCKDragDropServer singleton instance.
 */

@protocol MCKDragDropDonorDelegate <NSObject>

@optional
/* Asks delegate whether to allow this drag */
-(BOOL) donorView:(UIView*)donor shouldBeginDraggingView:(UIView*)draggingSubview;

/** Tells delegate the user will remove the draggingSubview from the donor 
 @return payload an object that will be retained by the DnD system,
         made available to the asorber via the MCKDragDropAbsorberDelegate, and
         released after the drag is ended
 */
-(id<NSObject>) donorView:(UIView*)donor willBeginDraggingView:(UIView*)draggingSubview;

// 1. User picks up an object, removing it from Donor's view hierarchy (VH).
/** Tells delegate the user has removed draggingSubview from the donor */
-(void) donorView:(UIView*)donor didBeginDraggingView:(UIView*)draggingSubview;

// 2. Absorber delegate decides if it accepts or rejects the drop

// A.3 Donor yields the draggingSubview to the Absorber.
/** Tells delegate draggingSubview will soon enter the absorber's VH */
-(void) donorView:(UIView*)donor willDonateDraggingView:(UIView*)draggingSubview;

// A.5 Donor notified Absorber has received the view
/** Tells delegate draggingSubview has just been 'donated' to absorber view */
-(void) donorView:(UIView*)donor didDonateDraggingView:(UIView*)draggingSubview;

// B.3. Donor re-integrates draggingSubview, which Absorber rejected
/**
  Tells donor draggingSubview was returned after a rejected drop.
  @param donor
  @param draggingSubview
  This will be called after the draggedView is re-inserted back into the donor VH.
 */
-(void) donorView:(UIView*)donor didReclaimDraggingView:(UIView*)draggingSubview;
@end


@protocol MCKDragDropAbsorberDelegate <NSObject>

@optional
// 2. Absorber view decides if it accepts or rejects the drop (-> A.3 or B.3)
/**
 Reports if an absorber will accept the drop of draggingSubview.

 @param absorber a view designated as an absorber, which is the hit test view for
        for a drop event located at the center of the draggingSubview

 @param draggingSubview the view dropped

 @param payload data being transported along with the dragged view
 
 This method can apply logic that limits the effective valid drop zone of the 
 absorber view, that accepts the drop of certain views but not others, or that
 accepts drops only with certain payloads.

 This method will be called on the best candidate absorber view available. The
 best candidate absorber view is whichever view (a) is designated as an absorber 
 view (b) and is the hit-test view for the drop point.
 
 The requirement that the absorber view be the hit test view implies that the 
 absorber view must not be hidden, must have userInteractionEnabled, and must 
 contain the drop point within its bounds. (The drop point is the center of the
 dropped view.)
 
 If this optional method is not implemented, the DnD framework defaults to 
 assuming the absorber CAN accept the view.
 
 */
-(BOOL)       absorberView:(UIView*)absorber
     canAbsorbDraggingView:(UIView*)draggingSubview
                   payload:(id<NSObject>)payload;

// A.4 Absorber receives the donated view
/**
 Tells delegate draggingSubview has been inserted into absorber's VH.

 @param absorber
 @param draggingSubview
 @param payload 

 Absorber should perform any work necessary after having been given the dropped
 view. For example, the absorber could actually integrate the draggingSubview object
 into its own view hierarchy or it could remove it and replace it with a lookalike.
 */
-(void)     absorberView:(UIView*)absorber
   didAbsorbDraggingView:(UIView*)draggingSubview
                 payload:(id<NSObject>)payload;
@end
