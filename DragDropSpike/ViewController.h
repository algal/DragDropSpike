//
//  ViewController.h
//  DragDropSpike
//
//  Created by Alexis Gallagher on 2012-07-14.
//  Copyright (c) 2012 McKinsey. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
@property (weak, nonatomic) IBOutlet UIView *leftContainer;
@property (weak, nonatomic) IBOutlet UIView *rightContainer;

@property (weak, nonatomic) IBOutlet UIButton *draggableButton;
@end
