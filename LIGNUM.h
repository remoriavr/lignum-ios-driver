//  LIGNUM.h
//  Created by Matteo Pisani on 15/03/16.
//  Copyright © 2016 Remoria VR. All rights reserved.
#import <objc/runtime.h>
#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#define LIGNUM_SERVICE_UUID   "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define LIGNUM_CHAR_TX_UUID   "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"
#define LIGNUM_CHAR_RX_UUID   "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
extern NSString *LIGNUM_PACKET;
static char BTS_ADVERTISING_IDENTIFER;
static char BTS_ADVERTISEMENT_RSSI_IDENTIFER;
@protocol BLEDelegate
@optional
-(void) bleDidConnect;
-(void) bleDidDisconnect;
-(void) bleDidUpdateRSSI:(NSNumber *) rssi;
-(void) bleDidReceiveData:(unsigned char *) data length:(int) length;
@required
@end
@interface LIGNUM : NSObject <CBCentralManagerDelegate, CBPeripheralDelegate> {}
@property (nonatomic,assign) id <BLEDelegate> delegate;
@property (strong, nonatomic) NSMutableArray *peripherals;
@property (strong, nonatomic) CBCentralManager *CM;
@property (strong, nonatomic) CBPeripheral *activePeripheral;
-(void) enableReadNotification:(CBPeripheral *)p;
-(void) read;
-(void) writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data;
-(BOOL) isConnected;
-(void) write:(NSData *)d;
-(void) readRSSI;
-(void) controlSetup;
-(int) findBLEPeripherals:(int) timeout;
-(void) connectPeripheral:(CBPeripheral *)peripheral;
-(UInt16) swap:(UInt16) s;
-(const char *) centralManagerStateToString:(int)state;
-(void) scanTimer:(NSTimer *)timer;
-(void) checkPeripherals;
-(void) getAllServicesFromPeripheral:(CBPeripheral *)p;
-(void) getAllCharacteristicsFromPeripheral:(CBPeripheral *)p;
-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p;
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service;
-(NSString *) CBUUIDToString:(CBUUID *) UUID;
-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2;
-(int) compareCBUUIDToInt:(CBUUID *) UUID1 UUID2:(UInt16)UUID2;
-(UInt16) CBUUIDToInt:(CBUUID *) UUID;
-(BOOL) UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUID2;
@end

@interface CBPeripheral(com_megster_bluetoothserial_extension)
@property (nonatomic, retain) NSString *btsAdvertising;
@property (nonatomic, retain) NSNumber *btsAdvertisementRSSI;
-(void)bts_setAdvertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber*)rssi;
@end
@interface BLE_UART : NSObject <BLEDelegate>
{
    LIGNUM *_bleShield;
    NSString* _connectCallbackId;
    NSString* _subscribeCallbackId;
    NSString* _subscribeBytesCallbackId;
    NSString* _rssiCallbackId;
    NSMutableString *_buffer;
    NSString *_delimiter;
}
- (void)setup;
- (void)connect:(NSString *)uuid;
- (void)disconnect;
- (void)subscribe:(NSString *)delimiter;
- (void)unsubscribe;
- (void)write:(NSData *)data;
- (void)list;
- (void)isEnabled;
- (void)clear;
- (void)readRSSI;
@end
