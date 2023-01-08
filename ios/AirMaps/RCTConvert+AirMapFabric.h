//
// Created by Leland Richardson on 12/27/15.
// Copyright (c) 2015 Facebook. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>
#import <MapKit/MapKit.h>
#import <React/RCTConvert.h>
#import <react/renderer/components/RNMapsComponents/Props.h>

@interface RCTConvert (AirMapFabric)

+ (MKCoordinateRegion)MKCoordinateRegionFabric: (facebook::react::AIRMapRegionStruct) region;
+ (MKCoordinateRegion)MKCoordinateInitalRegionFabric:(facebook::react::AIRMapInitialRegionStruct) region;
@end
