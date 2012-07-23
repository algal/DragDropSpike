//
//  MCKDragDropServer.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-20.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCKDragDropProtocol.h"

/** This class registers views to participate in Drag and Drop (DnD).
 
 It registers which views are draggable, which views can donate their draggable
 descendents, and which views can absorb drops of the draggable views.
 
 In a successful drag-and-drop session, the dragged view will be transferred
 from the view hierarchy of the donor into view hierarchy of the absorber. In
 an unsuccessful session, the dragged view is dropped where there is no 
 potential absorber or on a candidate absorber that rejects the drop, and
 then the dropped view is animated back into its old position within the
 donor's view hierarchy.
 
 The donor's and absorber's delegates will receive callbacks during the DnD session.
 These callbacks provide a way for the donor to pass a data payload to the absorber, 
 for the absorber to reject drops, and for both to update their state and appearance. 
 
 If a view should act as both as a donor and an absorber, register it as both.
 
 All DnDn callback logic can be centralized in a view controller (VC), by registering
 the VC as the delegate for all absorbers and donors. In this way, the VC can attach
 DnD logic to classes which know nothing of the DnD system. Alternatively, a custom
 class can encapsulate its own DnD logic, by designating itself as its own delegate 
 at initialization time.
 
 Donors can be nested. The donor of a given drag is the donor that is the closest 
 ancestor to the dragged view. Absorbers can be nested. The candidate absorber 
 for a given drop is the absorber that is the hit test view at the drop location.
 
 *Warning:* It is an error to assign a donor or an absorber a nil delegate (FIXME)

*/
@interface MCKDragDropServer : NSObject

+(MCKDragDropServer*)sharedServer;

/**
 Make view draggable

 @param draggableView
 
 It is also necessary to make an ancestor view a donor.
 */
-(void) registerDraggableView:(UIView*)draggableView;

/**
 Make view able to donate a descendant view via a drag operation.

 @param view view that will become a designated donor
 @param delegate object to receive callbacks during the DnD session. Must not be nil.

 Views hold only weak references to their delegates.
 */
-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDragDropDonorDelegate>*)delegate;

/**
 Make view able to absorb a dropped view into its view hierarchy.

 @param view view that will become a designated absorber
 @param delegate object to receive callbacks during the DnD session. Must not be nil.

 Views hold only weak references to their delegates.
 */
-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDragDropAbsorberDelegate>*)delegate;

//
// TODO: restrict visibility to MCKPanGestureRecognizer
//

/** Lookup delegate of donor */
-(NSObject<MCKDragDropDonorDelegate>*) delegateForDonorView:(UIView*)view;
-(UIView*) donorViewOfView:(UIView*)pickedUpView;
@end
