//
// Created by Leland Richardson on 12/27/15.
// Copyright (c) 2015 Facebook. All rights reserved.
//

#import "RCTConvert+AirMapFabric.h"

#import <React/RCTConvert+CoreLocation.h>
#import "AIRMapCoordinate.h"
#import <react/renderer/components/RNMapsComponents/Props.h>

@implementation RCTConvert (AirMap)

+ (MKCoordinateRegion)MKCoordinateRegionFabric:(facebook::react::AIRMapRegionStruct) region
{
  return (MKCoordinateRegion){
      (CLLocationCoordinate2D) {
          region.latitude, region.longitude
      },
      (MKCoordinateSpan){
          region.latitudeDelta, region.longitudeDelta
      }
  };
}

+ (MKCoordinateRegion)MKCoordinateInitalRegionFabric:(facebook::react::AIRMapInitialRegionStruct) region
{
  return (MKCoordinateRegion){
      (CLLocationCoordinate2D) {
          region.latitude, region.longitude
      },
      (MKCoordinateSpan){
          region.latitudeDelta, region.longitudeDelta
      }
  };
}


@end
