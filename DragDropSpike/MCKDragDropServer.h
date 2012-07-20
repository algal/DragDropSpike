//
//  MCKDragDropServer.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-20.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MCKDragDropProtocol.h"

/**
 Use the DnD server to register which views can be dragged, which views might
 donate views that are dragged away, and which views can absorb dropped views.
 
 In a successful drag-and-drop session, the dragged view will be transferred
 from the view subhierarchy of the donor into view hierarchy of the absorber. In
 an unsuccessful session, the dragged view is dropped where there is no 
 potential absorber, or on a candidate absorber that rejects the drop, and 
 then the dropped view is animated back into its old position within the
 donor's view hierarchy.

 In any session, the donor's and absorber's delegates will receive a sequence of
 callbacks informing them of the progress of the session, and giving them the 
 opportunity to update their state and appearance. For instance, by default,
 the dropped view is added to the absorber's view hierarchy while maintining
 its current onscreen location. But the absorber's delegate might want to 
 implement callback logic that will further animate the dropped view into
 a more appropriate home position.
 
 If a view should be designated both as a donor and an absorber, register it 
 as a donor and also as an absorber.
 
 All DnDn callback logic can be centralized in a view controller, by registering
 it as the delegate for all absorbers and donors. Or a custom view can be 
 defined which encapsualtes its own DnD logic, by designating itself as its
 delegate at initialization time.
 
 Multiple designated donors can be nested. The donor of a given drag is
 the donor that is the closest ancestor to the dragged view. Multiple designated
 absorbers can be nested. The candidate absorber for a given drop is the 
 absorber that is the hit test view at the drop location.

 It is an error to make a view draggable without also defining one of its
 ancestor views as a donor.
*/
@interface MCKDragDropServer : NSObject

+(MCKDragDropServer*)sharedServer;

/** Make view draggable
 @param draggableView
 */
-(void) registerDraggableView:(UIView*)draggableView;

/**
 Make view able to donate (i.e., lose) a descendant, draggable view via DnD.
 @param view view that will become a designated donor
 @param delegate object to receive callbacks during the DnD session
 */
-(void) registerDonorView:(UIView*)view delegate:(NSObject<MCKDragDropDonor>*)delegate;

/**
 Make view able to absorb a dropped view into its view hierarchy.
 @param view view that will become a designated absorber
 @param delegate object to receive callbacks during the DnD session
 */
-(void) registerAbsorberView:(UIView*)view delegate:(NSObject<MCKDragDropAbsorber>*)delegate;

@end
