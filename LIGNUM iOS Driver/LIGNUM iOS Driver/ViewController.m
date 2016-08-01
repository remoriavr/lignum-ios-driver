//
//  ViewController.m
//  LIGNUM iOS Driver
//
//  Created by Matteo Pisani on 01/08/16.
//  Copyright © 2016 Remoria VR. All rights reserved.
//

#import "ViewController.h"
#import "LIGNUM.h"
@interface ViewController ()

@end

@implementation ViewController

- (IBAction)changeText{
    LIGNUM_PACKET_LABEL.text = LIGNUM_PACKET;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    BLE_UART *LIGNUM_OBJECT = [BLE_UART new];
    [LIGNUM_OBJECT setup];
    [LIGNUM_OBJECT list];
    
    [NSTimer scheduledTimerWithTimeInterval:0.025f
                                     target:self selector:@selector(setLabel:) userInfo:nil repeats:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) setLabel:(NSTimer *)timer
{
    [self changeText];
}

@end
