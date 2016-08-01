//  LIGNUM.m
//  Created by Matteo Pisani on 15/03/16.
//  Copyright © 2016 Remoria VR. All rights reserved.
#import "LIGNUM.h"
BLE_UART *LIGNUM_OBJECT = nil;
NSString * LIGNUM_PACKET = @"WAITING FOR LIGNUM";
static void _setup()
{
    LIGNUM_OBJECT = [BLE_UART new];
    [LIGNUM_OBJECT setup];
}
void _list()
{
    [LIGNUM_OBJECT list];
}
void _connect(NSString *uuid)
{
    [LIGNUM_OBJECT connect:uuid];
}
void _disconnect()
{
    [LIGNUM_OBJECT disconnect];
}
@implementation CBPeripheral(com_megster_bluetoothserial_extension)
-(void)bts_setAdvertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)rssi
{
    if (advertisementData)
    {
        id manufacturerData = [advertisementData objectForKey:CBAdvertisementDataManufacturerDataKey];
        if (manufacturerData)
        {
            const uint8_t *bytes = [manufacturerData bytes];
            long len = [manufacturerData length];
            NSData *data = [NSData dataWithBytes:bytes+2 length:len-2];
            [self setBtsAdvertising: [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
    }
    [self setBtsAdvertisementRSSI: rssi];
}
-(void)setBtsAdvertising:(NSString *)newAdvertisingValue
{
    objc_setAssociatedObject(self, &BTS_ADVERTISING_IDENTIFER, newAdvertisingValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSString*)btsAdvertising
{
    return objc_getAssociatedObject(self, &BTS_ADVERTISING_IDENTIFER);
}
-(void)setBtsAdvertisementRSSI:(NSNumber *)newAdvertisementRSSIValue
{
    objc_setAssociatedObject(self, &BTS_ADVERTISEMENT_RSSI_IDENTIFER, newAdvertisementRSSIValue, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
-(NSString*)btsAdvertisementRSSI
{
    return objc_getAssociatedObject(self, &BTS_ADVERTISEMENT_RSSI_IDENTIFER);
}
@end
@implementation LIGNUM

@synthesize delegate;
@synthesize CM;
@synthesize peripherals;
@synthesize activePeripheral;
static bool isConnected = false;
static int rssi = 0;
CBUUID *LIGNUM_ServiceUUID;
CBUUID *serialServiceUUID;
CBUUID *readCharacteristicUUID;
CBUUID *writeCharacteristicUUID;
-(void) readRSSI
{
    [activePeripheral readRSSI];
}
-(BOOL) isConnected
{
    return isConnected;
}
-(void) read
{
    [self readValue:serialServiceUUID characteristicUUID:readCharacteristicUUID p:activePeripheral];
}
-(void) write:(NSData *)d
{
    [self writeValue:serialServiceUUID characteristicUUID:writeCharacteristicUUID p:activePeripheral data:d];
}
-(void) enableReadNotification:(CBPeripheral *)p
{
    [self notification:serialServiceUUID characteristicUUID:readCharacteristicUUID p:p on:YES];
}
-(void) notification:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p on:(BOOL)on
{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    if (!service)
    {
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if (!characteristic)
    {
        return;
    }
    [p setNotifyValue:on forCharacteristic:characteristic];
}
-(NSString *) CBUUIDToString:(CBUUID *) cbuuid;
{
    NSData *data = cbuuid.data;
    if ([data length] == 2)
    {
        const unsigned char *tokenBytes = [data bytes];
        return [NSString stringWithFormat:@"%02x%02x", tokenBytes[0], tokenBytes[1]];
    }
    else if ([data length] == 16)
    {
        NSUUID* nsuuid = [[NSUUID alloc] initWithUUIDBytes:[data bytes]];
        return [nsuuid UUIDString];
    }
    return [cbuuid description];
}
-(void) readValue: (CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p
{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    if (!service)
    {
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if (!characteristic)
    {
        return;
    }
    [p readValueForCharacteristic:characteristic];
}
-(void) writeValue:(CBUUID *)serviceUUID characteristicUUID:(CBUUID *)characteristicUUID p:(CBPeripheral *)p data:(NSData *)data
{
    CBService *service = [self findServiceFromUUID:serviceUUID p:p];
    if (!service)
    {
        return;
    }
    CBCharacteristic *characteristic = [self findCharacteristicFromUUID:characteristicUUID service:service];
    if (!characteristic)
    {
        return;
    }
    if ((characteristic.properties & CBCharacteristicPropertyWrite) == CBCharacteristicPropertyWrite) {
        [p writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
    }
    else if ((characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) == CBCharacteristicPropertyWriteWithoutResponse) {
        [p writeValue:data forCharacteristic:characteristic type:CBCharacteristicWriteWithoutResponse];
    }
}
-(UInt16) swap:(UInt16)s
{
    UInt16 temp = s << 8;
    temp |= (s >> 8);
    return temp;
}
- (void) controlSetup
{
    self.CM = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}
- (int) findBLEPeripherals:(int) timeout
{
    if (self.CM.state != CBCentralManagerStatePoweredOn)
    {
        return -1;
    }
    [NSTimer scheduledTimerWithTimeInterval:(float)timeout target:self selector:@selector(scanTimer:) userInfo:nil repeats:NO];
#if TARGET_OS_IPHONE
    LIGNUM_ServiceUUID = [CBUUID UUIDWithString:@LIGNUM_SERVICE_UUID];
    NSArray *services = @[LIGNUM_ServiceUUID];
    [self.CM scanForPeripheralsWithServices:services options: nil];
#else
    [self.CM scanForPeripheralsWithServices:nil options:nil];
#endif
    return 0;
}
- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error;
{
    done = false;
    [[self delegate] bleDidDisconnect];
    isConnected = false;
}
- (void) connectPeripheral:(CBPeripheral *)peripheral
{
    self.activePeripheral = peripheral;
    self.activePeripheral.delegate = self;
    [self.CM connectPeripheral:self.activePeripheral
                       options:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:CBConnectPeripheralOptionNotifyOnDisconnectionKey]];
}
- (const char *) centralManagerStateToString: (int)state
{
    switch(state)
    {
        case CBCentralManagerStateUnknown:
            return "State unknown (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateResetting:
            return "State resetting (CBCentralManagerStateUnknown)";
        case CBCentralManagerStateUnsupported:
            return "State BLE unsupported (CBCentralManagerStateResetting)";
        case CBCentralManagerStateUnauthorized:
            return "State unauthorized (CBCentralManagerStateUnauthorized)";
        case CBCentralManagerStatePoweredOff:
            return "State BLE powered off (CBCentralManagerStatePoweredOff)";
        case CBCentralManagerStatePoweredOn:
            return "State powered up and ready (CBCentralManagerStatePoweredOn)";
        default:
            return "State unknown";
    }
    return "Unknown state";
}
- (void) scanTimer:(NSTimer *)timer
{
    [self.CM stopScan];
    [self checkPeripherals];
}
- (void) checkPeripherals
{
    for (int i = 0; i < self.peripherals.count; i++)
    {
        CBPeripheral *p = [self.peripherals objectAtIndex:i];
        if([p.name isEqual: @"LIGNUM"])
        {
            [self connectPeripheral:p];
        }
    }
}
- (BOOL) UUIDSAreEqual:(NSUUID *)UUID1 UUID2:(NSUUID *)UUID2
{
    if ([UUID1.UUIDString isEqualToString:UUID2.UUIDString])
        return TRUE;
    else
        return FALSE;
}
-(void) getAllServicesFromPeripheral:(CBPeripheral *)p
{
    [p discoverServices:nil];
}
-(void) getAllCharacteristicsFromPeripheral:(CBPeripheral *)p
{
    for (int i=0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        [p discoverCharacteristics:nil forService:s];
    }
}
-(int) compareCBUUID:(CBUUID *) UUID1 UUID2:(CBUUID *)UUID2
{
    char b1[16];
    char b2[16];
    [UUID1.data getBytes:b1];
    [UUID2.data getBytes:b2];
    if (memcmp(b1, b2, UUID1.data.length) == 0)
        return 1;
    else
        return 0;
}
-(int) compareCBUUIDToInt:(CBUUID *)UUID1 UUID2:(UInt16)UUID2
{
    char b1[16];
    [UUID1.data getBytes:b1];
    UInt16 b2 = [self swap:UUID2];
    if (memcmp(b1, (char *)&b2, 2) == 0)
        return 1;
    else
        return 0;
}
-(UInt16) CBUUIDToInt:(CBUUID *) UUID
{
    char b1[16];
    [UUID.data getBytes:b1];
    return ((b1[0] << 8) | b1[1]);
}
-(CBUUID *) IntToCBUUID:(UInt16)UUID
{
    char t[16];
    t[0] = ((UUID >> 8) & 0xff); t[1] = (UUID & 0xff);
    NSData *data = [[NSData alloc] initWithBytes:t length:16];
    return [CBUUID UUIDWithData:data];
}
-(CBService *) findServiceFromUUID:(CBUUID *)UUID p:(CBPeripheral *)p
{
    for(int i = 0; i < p.services.count; i++)
    {
        CBService *s = [p.services objectAtIndex:i];
        if ([self compareCBUUID:s.UUID UUID2:UUID])
            return s;
    }
    return nil;
}
-(CBCharacteristic *) findCharacteristicFromUUID:(CBUUID *)UUID service:(CBService*)service
{
    for(int i=0; i < service.characteristics.count; i++)
    {
        CBCharacteristic *c = [service.characteristics objectAtIndex:i];
        if ([self compareCBUUID:c.UUID UUID2:UUID]) return c;
    }
    return nil;
}
#if TARGET_OS_IPHONE
//-- no need for iOS
#else
- (BOOL) isLECapableHardware
{
    NSString * state = nil;
    switch ([CM state])
    {
        case CBCentralManagerStateUnsupported:
            state = @"The platform/hardware doesn't support Bluetooth Low Energy.";
            break;
        case CBCentralManagerStateUnauthorized:
            state = @"The app is not authorized to use Bluetooth Low Energy.";
            break;
        case CBCentralManagerStatePoweredOff:
            state = @"Bluetooth is currently powered off.";
            break;
        case CBCentralManagerStatePoweredOn:
            return TRUE;
        case CBCentralManagerStateUnknown:
        default:
            return FALSE;
    }
    return FALSE;
}
#endif
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
#if TARGET_OS_IPHONE
#else
    [self isLECapableHardware];
#endif
}
- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    if (!self.peripherals)
        self.peripherals = [[NSMutableArray alloc] initWithObjects:peripheral,nil];
    else
    {
        for(int i = 0; i < self.peripherals.count; i++)
        {
            CBPeripheral *p = [self.peripherals objectAtIndex:i];
            [p bts_setAdvertisementData:advertisementData RSSI:RSSI];
            if ((p.identifier == NULL) || (peripheral.identifier == NULL))
                continue;
            if ([self UUIDSAreEqual:p.identifier UUID2:peripheral.identifier])
            {
                [self.peripherals replaceObjectAtIndex:i withObject:peripheral];
                return;
            }
        }
        [self.peripherals addObject:peripheral];
    }
}
- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    self.activePeripheral = peripheral;
    [self.activePeripheral discoverServices:nil];
    [self getAllServicesFromPeripheral:peripheral];
}
static bool done = false;
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    if (!error)
    {
        for (int i=0; i < service.characteristics.count; i++)
        {
            CBService *s = [peripheral.services objectAtIndex:(peripheral.services.count - 1)];
            
            if ([service.UUID isEqual:s.UUID])
            {
                if (!done)
                {
                    [self enableReadNotification:activePeripheral];
                    [[self delegate] bleDidConnect];
                    isConnected = true;
                    done = true;
                }
                break;
            }
        }
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    if (!error)
    {
        for (CBService *service in peripheral.services)
        {
            if ([service.UUID isEqual:LIGNUM_ServiceUUID])
            {
                serialServiceUUID = LIGNUM_ServiceUUID;
                readCharacteristicUUID = [CBUUID UUIDWithString:@LIGNUM_CHAR_TX_UUID];
                writeCharacteristicUUID = [CBUUID UUIDWithString:@LIGNUM_CHAR_RX_UUID];
                break;
            }
        }
        [self getAllCharacteristicsFromPeripheral:peripheral];
    }
}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {}
- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    unsigned char data[20];
    static unsigned char buf[512];
    static int len = 0;
    NSInteger data_len;
    if (!error)
    {
        if ([characteristic.UUID isEqual:readCharacteristicUUID])
        {
            data_len = characteristic.value.length;
            [characteristic.value getBytes:data length:data_len];
            
            if (data_len == 20)
            {
                memcpy(&buf[len], data, 20);
                len += data_len;
                
                if (len >= 64)
                {
                    [[self delegate] bleDidReceiveData:buf length:len];
                    len = 0;
                }
            }
            else if (data_len < 20)
            {
                memcpy(&buf[len], data, data_len);
                len += data_len;
                
                [[self delegate] bleDidReceiveData:buf length:len];
                len = 0;
            }
        }
    }
}
- (void)peripheralDidUpdateRSSI:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (!isConnected)
        return;
    if (rssi != peripheral.RSSI.intValue)
    {
        rssi = peripheral.RSSI.intValue;
        [[self delegate] bleDidUpdateRSSI:activePeripheral.RSSI];
    }
}
@end
@interface BLE_UART()
- (NSString *)readUntilDelimiter:(NSString *)delimiter;
- (NSMutableArray *)getPeripheralList;
- (void)sendDataToSubscriber;
- (CBPeripheral *)findPeripheralByUUID:(NSString *)uuid;
- (void)connectToUUID:(NSString *)uuid;
- (void)listPeripheralsTimer:(NSTimer *)timer;
- (void)connectFirstDeviceTimer:(NSTimer *)timer;
- (void)connectUuidTimer:(NSTimer *)timer;
@end
@implementation BLE_UART
- (void)setup
{
    NSLog(@"method:setup");
    _bleShield = [[LIGNUM alloc] init];
    [_bleShield controlSetup];
    [_bleShield setDelegate:self];
    _buffer = [[NSMutableString alloc] init];
}
#pragma mark - Unity Methods
- (void)connect:(NSString *)uuid
{
    NSLog(@"method:connect");
    if (uuid == (NSString*)[NSNull null])
    {
        [self connectToFirstDevice];
    }
    else if ([uuid isEqualToString:@""])
    {
        [self connectToFirstDevice];
    }
    else
    {
        [self connectToUUID:uuid];
    }
}
- (void)disconnect
{
    NSLog(@"method:disconnect");
    if (_bleShield.activePeripheral)
    {
        if(_bleShield.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[_bleShield CM] cancelPeripheralConnection:[_bleShield activePeripheral]];
        }
    }
}
- (void)subscribe:(NSString *)delimiter
{
    if (delimiter != nil)
    {
        _delimiter = [delimiter copy];
    }
}
- (void)unsubscribe
{
    _delimiter = nil;
    _subscribeCallbackId = nil;
}
- (void)write:(NSData*)data
{
    if (data != nil)
    {
        [_bleShield write:data];
    }
}
- (void)list
{
    NSLog(@"method:list");
    [self scanForBLEPeripherals:3];
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0
                                     target:self
                                   selector:@selector(listPeripheralsTimer:)
                                   userInfo:nil
                                    repeats:YES];
}
- (void)isEnabled
{
    [NSTimer scheduledTimerWithTimeInterval:(float)0.2
                                     target:self
                                   selector:@selector(bluetoothStateTimer:)
                                   userInfo:nil
                                    repeats:NO];
}
- (void)clear
{
    long end = [_buffer length] - 1;
    NSRange truncate = NSMakeRange(0, end);
    [_buffer deleteCharactersInRange:truncate];
}
- (void)readRSSI
{
    [_bleShield readRSSI];
}
#pragma mark - BLEDelegate
- (void)bleDidReceiveData:(unsigned char *)data length:(int)length
{
    NSData *d = [NSData dataWithBytes:data length:length];
    NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
    NSLog(@"LIGNUM %@", s);
    LIGNUM_PACKET = s;
    if (s)
    {
        [_buffer appendString:s];
        if (_subscribeCallbackId)
        {
            [self sendDataToSubscriber];
        }
    }
}
- (void)bleDidConnect {}
- (void)bleDidDisconnect {}
- (void)bleDidUpdateRSSI:(NSNumber *)rssi
{
    NSLog(@"%f",[rssi doubleValue]);
}
#pragma mark - timers
-(void)listPeripheralsTimer:(NSTimer *)timer
{
    [_bleShield findBLEPeripherals:3];
}
-(void)connectFirstDeviceTimer:(NSTimer *)timer
{
    if(_bleShield.peripherals.count > 0)
    {
        [_bleShield connectPeripheral:[_bleShield.peripherals objectAtIndex:0]];
    }
}
-(void)connectUuidTimer:(NSTimer *)timer
{
    NSString *uuid = [timer userInfo];
    CBPeripheral *peripheral = [self findPeripheralByUUID:uuid];
    if (peripheral)
    {
        [_bleShield connectPeripheral:peripheral];
    }
}
- (void)bluetoothStateTimer:(NSTimer *)timer{ }
#pragma mark - internal implemetation
- (NSString*)readUntilDelimiter: (NSString*) delimiter
{
    NSRange range = [_buffer rangeOfString: delimiter];
    NSString *message = @"";
    if (range.location != NSNotFound)
    {
        long end = range.location + range.length;
        message = [_buffer substringToIndex:end];
        
        NSRange truncate = NSMakeRange(0, end);
        [_buffer deleteCharactersInRange:truncate];
    }
    return message;
}
- (NSMutableArray*) getPeripheralList
{
    NSMutableArray *peripherals = [NSMutableArray array];
    for (int i = 0; i < _bleShield.peripherals.count; i++)
    {
        NSMutableDictionary *peripheral = [NSMutableDictionary dictionary];
        CBPeripheral *p = [_bleShield.peripherals objectAtIndex:i];
        NSString *uuid = p.identifier.UUIDString;
        [peripheral setObject: uuid forKey: @"uuid"];
        [peripheral setObject: uuid forKey: @"id"];
        NSString *name = [p name];
        if (!name)
        {
            name = [peripheral objectForKey:@"uuid"];
        }
        [peripheral setObject: name forKey: @"name"];
        NSNumber *rssi = [p btsAdvertisementRSSI];
        if (rssi)
        {
            [peripheral setObject: rssi forKey:@"rssi"];
        }
        [peripherals addObject:peripheral];
    }
    return peripherals;
}
- (void) sendDataToSubscriber
{
    NSString *message = [self readUntilDelimiter:_delimiter];
    if ([message length] > 0)
    {
        [self sendDataToSubscriber];
    }
}
- (void)scanForBLEPeripherals:(int)timeout
{
    if (_bleShield.activePeripheral)
    {
        if(_bleShield.activePeripheral.state == CBPeripheralStateConnected)
        {
            [[_bleShield CM] cancelPeripheralConnection:[_bleShield activePeripheral]];
            return;
        }
    }
    if (_bleShield.peripherals)
    {
        _bleShield.peripherals = nil;
    }
    [_bleShield findBLEPeripherals:timeout];
}
- (void)connectToFirstDevice
{
    [self scanForBLEPeripherals:3];
    [NSTimer scheduledTimerWithTimeInterval:(float)3.0
                                     target:self
                                   selector:@selector(connectFirstDeviceTimer:)
                                   userInfo:nil
                                    repeats:NO];
}
- (void)connectToUUID:(NSString *)uuid
{
    int interval = 0;
    if (_bleShield.peripherals.count < 1)
    {
        interval = 3;
        [self scanForBLEPeripherals:interval];
    }
    [NSTimer scheduledTimerWithTimeInterval:interval
                                     target:self
                                   selector:@selector(connectUuidTimer:)
                                   userInfo:uuid
                                    repeats:NO];
}
- (CBPeripheral*)findPeripheralByUUID:(NSString*)uuid
{
    NSMutableArray *peripherals = [_bleShield peripherals];
    CBPeripheral *peripheral = nil;
    for (CBPeripheral *p in peripherals)
    {
        NSString *other = p.identifier.UUIDString;
        if ([uuid isEqualToString:other])
        {
            peripheral = p;
            break;
        }
    }
    return peripheral;
}
@end