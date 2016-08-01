//
//  ViewController.h
//  LIGNUM iOS Driver
//
//  Created by Matteo Pisani on 01/08/16.
//  Copyright © 2016 Remoria VR. All rights reserved.
//

#import <UIKit/UIKit.h>
extern NSString *kAppErrorDomain;
@interface ViewController : UIViewController {
    IBOutlet UILabel *LIGNUM_PACKET_LABEL;
}
- (IBAction)changeText;
@end

