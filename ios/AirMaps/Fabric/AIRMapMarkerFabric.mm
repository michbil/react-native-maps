/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AIRMapMarkerFabric.h"

#import <React/RCTConvert+CoreLocation.h>
#import <React/RCTUIManager.h>
#import <React/UIView+React.h>
#import "AIRMapMarker.h"

#import <React/RCTViewComponentView.h>
#import <react/renderer/components/RNMapsComponents/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsComponents/Props.h>
#import <react/renderer/components/RNMapsComponents/RCTComponentViewHelpers.h>
#import <react/renderer/components/RNMapsComponents/ShadowNodes.h>
#import "RCTFabricComponentsPlugins.h"
#import "RCTConvert+AirMapFabric.h"
#import <React/RCTImageResponseDelegate.h>
#import <React/RCTImageResponseObserverProxy.h>
#import <React/RCTImageLoader.h>
#import <React/RCTConversions.h>

using namespace facebook::react;

@interface AIRMapMarkerFabric () <MKMapViewDelegate, RCTAIRMapMarkerViewProtocol>

@end

@implementation AIRMapMarkerFabric {
    AIRMapMarker *_marker;
   
}



- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        AIRMapMarker *marker = [AIRMapMarker new];
        [marker addTapGestureRecognizer];
       // marker.bridge = self.bridge;
        marker.isAccessibilityElement = YES;
        marker.accessibilityElementsHidden = NO;
        
        static const auto defaultProps = std::make_shared<const AIRMapMarkerProps>();
        _props = defaultProps;
        
        _marker = marker;
        self.contentView = marker;
    }
    return self;
}


+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<AIRMapMarkerComponentDescriptor>();
}


- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    // override with null ptr if it's inital render, and oldProps are not defined
    const auto &oldViewProps = *std::static_pointer_cast<AIRMapMarkerProps const>(_props);
    const auto &newViewProps = *std::static_pointer_cast<AIRMapMarkerProps const>(props);

    NSLog(@"updateProps");
    
    
    if (oldViewProps.coordinate.longitude != newViewProps.coordinate.longitude || oldViewProps.coordinate.latitude != newViewProps.coordinate.latitude) {
        _marker.coordinate = (CLLocationCoordinate2D) {
            newViewProps.coordinate.latitude, newViewProps.coordinate.longitude
        };
    }
    
    if (oldViewProps.identifier != newViewProps.identifier) {
        _marker.identifier = RCTNSStringFromStringNilIfEmpty(newViewProps.identifier);
    }
    
    if (oldViewProps.title != newViewProps.title) {
        _marker.title = RCTNSStringFromStringNilIfEmpty(newViewProps.title);
    }
    
    if (oldViewProps.description != newViewProps.description) {
        _marker.subtitle = RCTNSStringFromStringNilIfEmpty(newViewProps.description);
    }
    
    if (oldViewProps.draggable != newViewProps.draggable) {
        _marker.draggable = newViewProps.draggable;
    }
    
    if (oldViewProps.opacity != newViewProps.opacity) {
        _marker.opacity = newViewProps.opacity;
    }
    
    if (oldViewProps.zIndex != newViewProps.zIndex) {
        if (newViewProps.zIndex.has_value()) {
            _marker.zIndex = newViewProps.zIndex.value();
        }
    }
    
    // lets handle image as React subview ATM, later will get back to custom component maybe
    // if (oldViewProps.image != newViewProps.image) {
     //   _marker.imageSrc = RCTNSStringFromStringNilIfEmpty(newViewProps.image.uri);
    // }
    
    if (oldViewProps.pinColor != newViewProps.pinColor) {
        _marker.pinColor = RCTUIColorFromSharedColor(newViewProps.pinColor);
    }
    
    if (oldViewProps.centerOffset.x != newViewProps.centerOffset.x || oldViewProps.centerOffset.x != newViewProps.centerOffset.x) {
        _marker.centerOffset = (CGPoint) {newViewProps.centerOffset.x, newViewProps.centerOffset.y};
    }
    
    if (oldViewProps.anchor.x != newViewProps.anchor.x || oldViewProps.anchor.y != newViewProps.anchor.y) {
        // Unimplemented on iOS?
       // _marker.centerXAnchor = newViewProps.anchor.x;
       //  _maker.centerYAnchor = newViewProps.anchor.y;
    }
    
    [super updateProps: props oldProps:oldProps];
}


- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
    NSLog(@"mount marker child");
    [_marker insertReactSubview: childComponentView atIndex: index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
    [_marker removeReactSubview: childComponentView];
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
    RCTAIRMapMarkerHandleCommand(self, commandName, args);
}



- (void) showCallout
{
    [_marker showCalloutView];
}

RCT_EXPORT_METHOD(hideCallout:(nonnull NSNumber *)reactTag)
{
    [_marker hideCalloutView];
}

RCT_EXPORT_METHOD(redrawCallout:(nonnull NSNumber *)reactTag)
{
  
}

@end


extern "C" {
    Class<RCTComponentViewProtocol> AIRMapMarkerCls(void)
    {
        return AIRMapMarkerFabric.class;
    }
}
