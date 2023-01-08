/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AIRMapFabric.h"

#import <React/RCTBridge.h>
#import <React/RCTUIManager.h>
#import <React/RCTConvert.h>
#import <React/RCTConvert+CoreLocation.h>
#import <React/RCTEventDispatcher.h>
#import <React/RCTViewManager.h>
#import <React/UIView+React.h>
#import "AIRMap.h"
#import "AIRMapMarker.h"
#import "AIRMapPolyline.h"
#import "AIRMapPolygon.h"
#import "AIRMapCircle.h"
#import "SMCalloutView.h"
#import "AIRMapUrlTile.h"
#import "AIRMapWMSTile.h"
#import "AIRMapLocalTile.h"
#import "AIRMapSnapshot.h"
#import "RCTConvert+AirMap.h"
#import "AIRMapOverlay.h"
#import "AIRWeakTimerReference.h"
#import "AIRWeakMapReference.h"
#import <MapKit/MapKit.h>

#import <react/renderer/components/RNMapsComponents/ComponentDescriptors.h>
#import <react/renderer/components/RNMapsComponents/Props.h>
#import <react/renderer/components/RNMapsComponents/RCTComponentViewHelpers.h>
#import <react/renderer/components/RNMapsComponents/ShadowNodes.h>
#import "RCTFabricComponentsPlugins.h"
#import "RCTConvert+AirMapFabric.h"
#import <React/RCTConversions.h>
#import <React/RCTViewComponentView.h>



using namespace facebook::react;



static NSString *const RCTMapViewKey = @"MapView";


@interface AIRMapFabric() <MKMapViewDelegate, UIGestureRecognizerDelegate, RCTAIRMapViewProtocol, RCTComponentViewProtocol>

@property AIRMap *_map;

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;

@end

@implementation AIRMapFabric{
   BOOL _hasObserver;
}



- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        AIRMap *map = [AIRMap new];
        self._map = map;
        map.delegate = self;
        
        static const auto defaultProps = std::make_shared<const AIRMapProps>();
        _props = defaultProps;

        map.isAccessibilityElement = NO;
        map.accessibilityElementsHidden = NO;
        
        // MKMapView doesn't report tap events, so we attach gesture recognizers to it
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapTap:)];
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapDoubleTap:)];
        [doubleTap setNumberOfTapsRequired:2];
        [tap requireGestureRecognizerToFail:doubleTap];
        
        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapLongPress:)];
        UIPanGestureRecognizer *drag = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMapDrag:)];
        [drag setMinimumNumberOfTouches:1];
        // setting this to NO allows the parent MapView to continue receiving marker selection events
        tap.cancelsTouchesInView = NO;
        doubleTap.cancelsTouchesInView = NO;
        longPress.cancelsTouchesInView = NO;
        
        doubleTap.delegate = self;
        
        // disable drag by default
        drag.enabled = NO;
        drag.delegate = self;
      
        [map addGestureRecognizer:tap];
        [map addGestureRecognizer:doubleTap];
        [map addGestureRecognizer:longPress];
        [map addGestureRecognizer:drag];
        self.contentView = map;
       // [self addSubview:map];
    }
    
    return self;
}

- (void)prepareForRecycle
{
 /*   AIRMapShadowNode::ConcreteState::Shared _state;
    _state = std::static_pointer_cast<AIRMapShadowNode::ConcreteState const>(state);
  _state.reset();*/
  [super prepareForRecycle];
}



#pragma mark exported MapView methods

#pragma mark Take Snapshot
- (void)takeMapSnapshot:(AIRMap *)mapView
        snapshotter:(MKMapSnapshotter *) snapshotter
        format:(NSString *)format
        quality:(CGFloat) quality
        result:(NSString *)result
        callback:(RCTResponseSenderBlock) callback {
    NSTimeInterval timeStamp = [[NSDate date] timeIntervalSince1970];
    NSString *pathComponent = [NSString stringWithFormat:@"Documents/snapshot-%.20lf.%@", timeStamp, format];
    NSString *filePath = [NSHomeDirectory() stringByAppendingPathComponent: pathComponent];

    [snapshotter startWithQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
              completionHandler:^(MKMapSnapshot *snapshot, NSError *error) {
                  if (error) {
                      callback(@[error]);
                      return;
                  }
                  MKAnnotationView *pin = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:nil];

                  UIImage *image = snapshot.image;
                  UIGraphicsBeginImageContextWithOptions(image.size, YES, image.scale);
                  {
                      [image drawAtPoint:CGPointMake(0.0f, 0.0f)];

                      CGRect rect = CGRectMake(0.0f, 0.0f, image.size.width, image.size.height);

                      for (id <AIRMapSnapshot> overlay in mapView.overlays) {
                          if ([overlay respondsToSelector:@selector(drawToSnapshot:context:)]) {
                                  [overlay drawToSnapshot:snapshot context:UIGraphicsGetCurrentContext()];
                          }
                      }
                      
                      for (id <MKAnnotation> annotation in mapView.annotations) {
                          CGPoint point = [snapshot pointForCoordinate:annotation.coordinate];
                          
                          MKAnnotationView* anView = [mapView viewForAnnotation: annotation];
                          
                          if (anView){
                              pin = anView;
                          }
                          
                          if (CGRectContainsPoint(rect, point)) {
                              point.x = point.x + pin.centerOffset.x - (pin.bounds.size.width / 2.0f);
                              point.y = point.y + pin.centerOffset.y - (pin.bounds.size.height / 2.0f);
                              if (pin.image) {
                                  [pin.image drawAtPoint:point];
                              } else {
                                  CGRect pinRect = CGRectMake(point.x, point.y, pin.bounds.size.width, pin.bounds.size.height);
                                  [pin drawViewHierarchyInRect:pinRect afterScreenUpdates:NO];
                              }
                          }
                      }

                      UIImage *compositeImage = UIGraphicsGetImageFromCurrentImageContext();

                      NSData *data;
                      if ([format isEqualToString:@"png"]) {
                          data = UIImagePNGRepresentation(compositeImage);
                      }
                      else if([format isEqualToString:@"jpg"]) {
                          data = UIImageJPEGRepresentation(compositeImage, quality);
                      }

                      if ([result isEqualToString:@"file"]) {
                          [data writeToFile:filePath atomically:YES];
                          callback(@[[NSNull null], filePath]);
                      }
                      else if ([result isEqualToString:@"base64"]) {
                          callback(@[[NSNull null], [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]]);
                      }
                      else if ([result isEqualToString:@"legacy"]) {

                          // In the initial (iOS only) implementation of takeSnapshot,
                          // both the uri and the base64 encoded string were returned.
                          // Returning both is rarely useful and in fact causes a
                          // performance penalty when only the file URI is desired.
                          // In that case the base64 encoded string was always marshalled
                          // over the JS-bridge (which is quite slow).
                          // A new more flexible API was created to cover this.
                          // This code should be removed in a future release when the
                          // old API is fully deprecated.
                          [data writeToFile:filePath atomically:YES];
                          NSDictionary *snapshotData = @{
                                                         @"uri": filePath,
                                                         @"data": [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithCarriageReturn]
                                                         };
                          callback(@[[NSNull null], snapshotData]);
                      }
                  }
                  UIGraphicsEndImageContext();
              }];
}

#pragma mark Gesture Recognizer Handlers

#define MAX_DISTANCE_PX 10.0f
- (void)handleMapTap:(UITapGestureRecognizer *)recognizer {
    AIRMap *map = (AIRMap *)recognizer.view;

    CGPoint tapPoint = [recognizer locationInView:map];
    CLLocationCoordinate2D tapCoordinate = [map convertPoint:tapPoint toCoordinateFromView:map];
    MKMapPoint mapPoint = MKMapPointForCoordinate(tapCoordinate);
    CGPoint mapPointAsCGP = CGPointMake(mapPoint.x, mapPoint.y);

    double maxMeters = [self metersFromPixel:MAX_DISTANCE_PX atPoint:tapPoint forMap:map];
    float nearestDistance = MAXFLOAT;
    AIRMapPolyline *nearestPolyline = nil;

    for (id<MKOverlay> overlay in map.overlays) {
        if([overlay isKindOfClass:[AIRMapPolygon class]]){
            AIRMapPolygon *polygon = (AIRMapPolygon*) overlay;
            if (polygon.onPress) {
                CGMutablePathRef mpr = CGPathCreateMutable();

                for(int i = 0; i < polygon.coordinates.count; i++) {
                    AIRMapCoordinate *c = polygon.coordinates[i];
                    MKMapPoint mp = MKMapPointForCoordinate(c.coordinate);
                    if (i == 0) {
                        CGPathMoveToPoint(mpr, NULL, mp.x, mp.y);
                    } else {
                        CGPathAddLineToPoint(mpr, NULL, mp.x, mp.y);
                    }
                }

                if (CGPathContainsPoint(mpr, NULL, mapPointAsCGP, FALSE)) {
                    id event = @{
                                @"action": @"polygon-press",
                                @"coordinate": @{
                                    @"latitude": @(tapCoordinate.latitude),
                                    @"longitude": @(tapCoordinate.longitude),
                                },
                            };
                    polygon.onPress(event);
                }

                CGPathRelease(mpr);
            }
        }

        if([overlay isKindOfClass:[AIRMapPolyline class]]){
            AIRMapPolyline *polyline = (AIRMapPolyline*) overlay;
            if (polyline.onPress) {
                float distance = [self distanceOfPoint:MKMapPointForCoordinate(tapCoordinate)
                                          toPoly:polyline];
                if (distance < nearestDistance) {
                    nearestDistance = distance;
                    nearestPolyline = polyline;
                }
            }
        }

        if ([overlay isKindOfClass:[AIRMapOverlay class]]) {
            AIRMapOverlay *imageOverlay = (AIRMapOverlay*) overlay;
            if (MKMapRectContainsPoint(imageOverlay.boundingMapRect, mapPoint)) {
                if (imageOverlay.onPress) {
                    id event = @{
                                 @"action": @"image-overlay-press",
                                 @"name": imageOverlay.name ?: @"unknown",
                                 @"coordinate": @{
                                         @"latitude": @(imageOverlay.coordinate.latitude),
                                         @"longitude": @(imageOverlay.coordinate.longitude)
                                         }
                                 };
                    imageOverlay.onPress(event);
                }
            }
        }

    }

    if (nearestDistance <= maxMeters) {
        AIRMapCoordinate *firstCoord = nearestPolyline.coordinates.firstObject;
        id event = @{
                   @"action": @"polyline-press",
                   @"coordinate": @{
                       @"latitude": @(firstCoord.coordinate.latitude),
                       @"longitude": @(firstCoord.coordinate.longitude)
                   }
                   };
        nearestPolyline.onPress(event);
    }
    
    auto payload = (AIRMapEventEmitter::OnPress){
        (AIRMapEventEmitter::OnPressCoordinate) {tapCoordinate.latitude,tapCoordinate.longitude},
        (AIRMapEventEmitter::OnPressPosition) {tapPoint.x, tapPoint.y},
        std::string(""),
        std::string(""),
    };

    std::static_pointer_cast<AIRMapEventEmitter const>(_eventEmitter)->onPress(payload);

}

- (void)handleMapDrag:(UIPanGestureRecognizer*)recognizer {
    AIRMap *map = (AIRMap *)recognizer.view;
    if (!map.onPanDrag) return;

    CGPoint touchPoint = [recognizer locationInView:map];
    CLLocationCoordinate2D coord = [map convertPoint:touchPoint toCoordinateFromView:map];
    map.onPanDrag(@{
                  @"coordinate": @{
                          @"latitude": @(coord.latitude),
                          @"longitude": @(coord.longitude),
                          },
                  @"position": @{
                          @"x": @(touchPoint.x),
                          @"y": @(touchPoint.y),
                          },
                  });

}

- (void)handleMapDoubleTap:(UIPanGestureRecognizer*)recognizer {
    AIRMap *map = (AIRMap *)recognizer.view;
    if (!map.onDoublePress) return;
    
    CGPoint touchPoint = [recognizer locationInView:map];
    CLLocationCoordinate2D coord = [map convertPoint:touchPoint toCoordinateFromView:map];
    map.onDoublePress(@{
                    @"coordinate": @{
                            @"latitude": @(coord.latitude),
                            @"longitude": @(coord.longitude),
                            },
                    @"position": @{
                            @"x": @(touchPoint.x),
                            @"y": @(touchPoint.y),
                            },
                    });
    
}


- (void)handleMapLongPress:(UITapGestureRecognizer *)recognizer {

    // NOTE: android only does the equivalent of "began", so we only send in this case
    if (recognizer.state != UIGestureRecognizerStateBegan) return;

    AIRMap *map = (AIRMap *)recognizer.view;
    if (!map.onLongPress) return;

    CGPoint touchPoint = [recognizer locationInView:map];
    CLLocationCoordinate2D coord = [map convertPoint:touchPoint toCoordinateFromView:map];

    map.onLongPress(@{
            @"coordinate": @{
                    @"latitude": @(coord.latitude),
                    @"longitude": @(coord.longitude),
            },
            @"position": @{
                    @"x": @(touchPoint.x),
                    @"y": @(touchPoint.y),
            },
    });
}

#pragma mark MKMapViewDelegate

#pragma mark Polyline stuff

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id <MKOverlay>)overlay{
    if ([overlay isKindOfClass:[AIRMapPolyline class]]) {
        return ((AIRMapPolyline *)overlay).renderer;
    } else if ([overlay isKindOfClass:[AIRMapPolygon class]]) {
        return ((AIRMapPolygon *)overlay).renderer;
    } else if ([overlay isKindOfClass:[AIRMapCircle class]]) {
        return ((AIRMapCircle *)overlay).renderer;
    } else if ([overlay isKindOfClass:[AIRMapUrlTile class]]) {
        return ((AIRMapUrlTile *)overlay).renderer;
    } else if ([overlay isKindOfClass:[AIRMapWMSTile class]]) {
        return ((AIRMapWMSTile *)overlay).renderer;
    } else if ([overlay isKindOfClass:[AIRMapLocalTile class]]) {
        return ((AIRMapLocalTile *)overlay).renderer;
    } else if ([overlay isKindOfClass:[AIRMapOverlay class]]) {
        return ((AIRMapOverlay *)overlay).renderer;
    } else if([overlay isKindOfClass:[MKTileOverlay class]]) {
        return [[MKTileOverlayRenderer alloc] initWithTileOverlay:overlay];
    } else {
        return nil;
    }
}


#pragma mark Annotation Stuff

- (void)mapView:(AIRMap *)mapView didAddAnnotationViews:(NSArray<MKAnnotationView *> *)views
{
    if(!mapView.userLocationCalloutEnabled){
        for(MKAnnotationView* view in views){
            if ([view.annotation isKindOfClass:[MKUserLocation class]]){
                [view setEnabled:NO];
                [view setCanShowCallout:NO];
                break;
            }
        }
    }
}


- (void)mapView:(AIRMap *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if ([view.annotation isKindOfClass:[AIRMapMarker class]]) {
        [(AIRMapMarker *)view.annotation showCalloutView];
    } else if ([view.annotation isKindOfClass:[MKUserLocation class]] && mapView.userLocationAnnotationTitle != nil && view.annotation.title != mapView.userLocationAnnotationTitle) {
        [(MKUserLocation*)view.annotation setTitle: mapView.userLocationAnnotationTitle];
    }

}

- (void)mapView:(AIRMap *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
    if ([view.annotation isKindOfClass:[AIRMapMarker class]]) {
        [(AIRMapMarker *)view.annotation hideCalloutView];
    }
}

- (MKAnnotationView *)mapView:(__unused AIRMap *)mapView viewForAnnotation:(AIRMapMarker *)marker
{
    if (![marker isKindOfClass:[AIRMapMarker class]]) {
        if ([marker isKindOfClass:[MKUserLocation class]] && mapView.userLocationAnnotationTitle != nil) {
            [(MKUserLocation*)marker setTitle: mapView.userLocationAnnotationTitle];
            return nil;
        }
        return nil;
    }

    marker.map = mapView;
    return [marker getAnnotationView];
}

static int kDragCenterContext;

- (void)mapView:(AIRMap *)mapView
    annotationView:(MKAnnotationView *)view
    didChangeDragState:(MKAnnotationViewDragState)newState
    fromOldState:(MKAnnotationViewDragState)oldState
{
    if (![view.annotation isKindOfClass:[AIRMapMarker class]]) return;
    AIRMapMarker *marker = (AIRMapMarker *)view.annotation;

    BOOL isPinView = [view isKindOfClass:[MKPinAnnotationView class]];

    id event = @{
                 @"id": marker.identifier ?: @"unknown",
                 @"coordinate": @{
                         @"latitude": @(marker.coordinate.latitude),
                         @"longitude": @(marker.coordinate.longitude)
                         }
                 };

    if (newState == MKAnnotationViewDragStateEnding || newState == MKAnnotationViewDragStateCanceling) {
        if (!isPinView) {
            [view setDragState:MKAnnotationViewDragStateNone animated:NO];
        }
        if (mapView.onMarkerDragEnd) mapView.onMarkerDragEnd(event);
        if (marker.onDragEnd) marker.onDragEnd(event);

       if(_hasObserver) [view removeObserver:self forKeyPath:@"center"];
        _hasObserver = NO;
    } else if (newState == MKAnnotationViewDragStateStarting) {
        // MapKit doesn't emit continuous drag events. To get around this, we are going to use KVO.
        [view addObserver:self forKeyPath:@"center" options:NSKeyValueObservingOptionNew context:&kDragCenterContext];
        _hasObserver = YES;
        if (mapView.onMarkerDragStart) mapView.onMarkerDragStart(event);
        if (marker.onDragStart) marker.onDragStart(event);
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([keyPath isEqualToString:@"center"] && [object isKindOfClass:[MKAnnotationView class]]) {
        MKAnnotationView *view = (MKAnnotationView *)object;
        AIRMapMarker *marker = (AIRMapMarker *)view.annotation;

        // a marker we don't control might be getting dragged. Check just in case.
        if (!marker) return;

        AIRMap *map = marker.map;

        // don't waste time calculating if there are no events to listen to it
        if (!map.onMarkerDrag && !marker.onDrag) return;

        CGPoint position = CGPointMake(view.center.x - view.centerOffset.x, view.center.y - view.centerOffset.y);
        CLLocationCoordinate2D coordinate = [map convertPoint:position toCoordinateFromView:map];

        id event = @{
                @"id": marker.identifier ?: @"unknown",
                @"position": @{
                        @"x": @(position.x),
                        @"y": @(position.y),
                },
                @"coordinate": @{
                        @"latitude": @(coordinate.latitude),
                        @"longitude": @(coordinate.longitude),
                }
        };

        if (map.onMarkerDrag) map.onMarkerDrag(event);
        if (marker.onDrag) marker.onDrag(event);

    } else {
        // This message is not for me; pass it on to super.
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)mapView:(AIRMap *)mapView didUpdateUserLocation:(MKUserLocation *)location
{
    id event = @{@"coordinate": @{
                         @"latitude": @(location.coordinate.latitude),
                         @"longitude": @(location.coordinate.longitude),
                         @"altitude": @(location.location.altitude),
                         @"timestamp": @(location.location.timestamp.timeIntervalSinceReferenceDate * 1000),
                         @"accuracy": @(location.location.horizontalAccuracy),
                         @"altitudeAccuracy": @(location.location.verticalAccuracy),
                         @"speed": @(location.location.speed),
                         @"heading": @(location.location.course),
                         }
                 };
    
    if (mapView.onUserLocationChange) {
        mapView.onUserLocationChange(event);
    }
    
    if (mapView.followUserLocation) {
        MKCoordinateRegion region;
        region.span.latitudeDelta = AIRMapDefaultSpan;
        region.span.longitudeDelta = AIRMapDefaultSpan;
        region.center = location.coordinate;
        [mapView setRegion:region animated:YES];

        // Move to user location only for the first time it loads up.
        // mapView.followUserLocation = NO;
    }
    
}

- (void)mapView:(AIRMap *)mapView regionWillChangeAnimated:(__unused BOOL)animated
{
    // Don't send region did change events until map has
    // started rendering, as these won't represent the final location
    if(mapView.hasStartedRendering){
        [self _regionChanged:mapView];
    }

    AIRWeakTimerReference *weakTarget = [[AIRWeakTimerReference alloc] initWithTarget:self andSelector:@selector(_onTick:)];
    
    mapView.regionChangeObserveTimer = [NSTimer timerWithTimeInterval:AIRMapRegionChangeObserveInterval
                                                               target:weakTarget
                                                             selector:@selector(timerDidFire:)
                                                             userInfo:@{ RCTMapViewKey: [[AIRWeakMapReference alloc] initWithMapView: mapView] }
                                                              repeats:YES];

    [[NSRunLoop mainRunLoop] addTimer:mapView.regionChangeObserveTimer forMode:NSRunLoopCommonModes];
}

- (void)mapView:(AIRMap *)mapView regionDidChangeAnimated:(__unused BOOL)animated
{
    CGFloat zoomLevel = [self zoomLevel:mapView];
    [mapView.regionChangeObserveTimer invalidate];
    mapView.regionChangeObserveTimer = nil;

    // Don't send region did change events until map has
    // started rendering, as these won't represent the final location
    if(mapView.hasStartedRendering){
        [self _regionChanged:mapView];
    }

    if (zoomLevel < mapView.minZoomLevel) {
      [self setCenterCoordinate:[mapView centerCoordinate] zoomLevel:mapView.minZoomLevel animated:TRUE mapView:mapView];
    }
    else if (zoomLevel > mapView.maxZoomLevel) {
      [self setCenterCoordinate:[mapView centerCoordinate] zoomLevel:mapView.maxZoomLevel animated:TRUE mapView:mapView];
    }

    // Don't send region did change events until map has
    // started rendering, as these won't represent the final location
    if (mapView.hasStartedRendering) {
        [self _emitRegionChangeEvent:mapView continuous:NO];
    };

    mapView.pendingCenter = mapView.region.center;
    mapView.pendingSpan = mapView.region.span;
}

- (void)mapViewWillStartRenderingMap:(AIRMap *)mapView
{
    if (!mapView.hasStartedRendering) {
      std::static_pointer_cast<AIRMapEventEmitter const>(_eventEmitter)->onMapReady((AIRMapEventEmitter::OnMapReady){});
      mapView.hasStartedRendering = YES;
    }
    [mapView beginLoading];
    [self _emitRegionChangeEvent:mapView continuous:NO];
}

- (void)mapViewDidFinishRenderingMap:(AIRMap *)mapView fullyRendered:(BOOL)fullyRendered
{
    [mapView finishLoading];
}

#pragma mark Private

- (void)_onTick:(NSTimer *)timer
{
    AIRWeakMapReference *weakRef = timer.userInfo[RCTMapViewKey];
    [self _regionChanged:weakRef.mapView];
}

- (void)_regionChanged:(AIRMap *)mapView
{
    BOOL needZoom = NO;
    CGFloat newLongitudeDelta = 0.0f;
    MKCoordinateRegion region = mapView.region;
    // On iOS 7, it's possible that we observe invalid locations during initialization of the map.
    // Filter those out.
    if (!CLLocationCoordinate2DIsValid(region.center)) {
        return;
    }
    // Calculation on float is not 100% accurate. If user zoom to max/min and then move, it's likely the map will auto zoom to max/min from time to time.
    // So let's try to make map zoom back to 99% max or 101% min so that there are some buffer that moving the map won't constantly hitting the max/min bound.
    if (mapView.maxDelta > FLT_EPSILON && region.span.longitudeDelta > mapView.maxDelta) {
        needZoom = YES;
        newLongitudeDelta = mapView.maxDelta * (1 - AIRMapZoomBoundBuffer);
    } else if (mapView.minDelta > FLT_EPSILON && region.span.longitudeDelta < mapView.minDelta) {
        needZoom = YES;
        newLongitudeDelta = mapView.minDelta * (1 + AIRMapZoomBoundBuffer);
    }
    if (needZoom) {
        region.span.latitudeDelta = region.span.latitudeDelta / region.span.longitudeDelta * newLongitudeDelta;
        region.span.longitudeDelta = newLongitudeDelta;
        mapView.region = region;
    }

    // Continuously observe region changes
    [self _emitRegionChangeEvent:mapView continuous:YES];
}

- (void)_emitRegionChangeEvent:(AIRMap *)mapView continuous:(BOOL)continuous
{
    if (!mapView.ignoreRegionChanges && mapView.onChange) {
        MKCoordinateRegion region = mapView.region;
        if (!CLLocationCoordinate2DIsValid(region.center)) {
            return;
        }

#define FLUSH_NAN(value) (isnan(value) ? 0 : value)
        mapView.onChange(@{
                @"continuous": @(continuous),
                @"region": @{
                        @"latitude": @(FLUSH_NAN(region.center.latitude)),
                        @"longitude": @(FLUSH_NAN(region.center.longitude)),
                        @"latitudeDelta": @(FLUSH_NAN(region.span.latitudeDelta)),
                        @"longitudeDelta": @(FLUSH_NAN(region.span.longitudeDelta)),
                }
        });
    }
}

/** Returns the distance of |pt| to |poly| in meters
 *
 *
 */
- (double)distanceOfPoint:(MKMapPoint)pt toPoly:(AIRMapPolyline *)poly
{
    double distance = MAXFLOAT;
    for (int n = 0; n < poly.coordinates.count - 1; n++) {

        MKMapPoint ptA = MKMapPointForCoordinate(poly.coordinates[n].coordinate);
        MKMapPoint ptB = MKMapPointForCoordinate(poly.coordinates[n + 1].coordinate);

        double xDelta = ptB.x - ptA.x;
        double yDelta = ptB.y - ptA.y;

        if (xDelta == 0.0 && yDelta == 0.0) {
            continue;
        }

        double u = ((pt.x - ptA.x) * xDelta + (pt.y - ptA.y) * yDelta) / (xDelta * xDelta + yDelta * yDelta);
        MKMapPoint ptClosest;
        if (u < 0.0) {
            ptClosest = ptA;
        }
        else if (u > 1.0) {
            ptClosest = ptB;
        }
        else {
            ptClosest = MKMapPointMake(ptA.x + u * xDelta, ptA.y + u * yDelta);
        }

        distance = MIN(distance, MKMetersBetweenMapPoints(ptClosest, pt));
    }

    return distance;
}


/** Converts |px| to meters at location |pt| */
- (double)metersFromPixel:(NSUInteger)px atPoint:(CGPoint)pt forMap:(AIRMap *)mapView
{
    CGPoint ptB = CGPointMake(pt.x + px, pt.y);

    CLLocationCoordinate2D coordA = [mapView convertPoint:pt toCoordinateFromView:mapView];
    CLLocationCoordinate2D coordB = [mapView convertPoint:ptB toCoordinateFromView:mapView];

    return MKMetersBetweenMapPoints(MKMapPointForCoordinate(coordA), MKMapPointForCoordinate(coordB));
}

+ (double)longitudeToPixelSpaceX:(double)longitude
{
    return round(MERCATOR_OFFSET + MERCATOR_RADIUS * longitude * M_PI / 180.0);
}

+ (double)latitudeToPixelSpaceY:(double)latitude
{
	if (latitude == 90.0) {
		return 0;
	} else if (latitude == -90.0) {
		return MERCATOR_OFFSET * 2;
	} else {
		return round(MERCATOR_OFFSET - MERCATOR_RADIUS * logf((1 + sinf(latitude * M_PI / 180.0)) / (1 - sinf(latitude * M_PI / 180.0))) / 2.0);
	}
}

+ (double)pixelSpaceXToLongitude:(double)pixelX
{
    return ((round(pixelX) - MERCATOR_OFFSET) / MERCATOR_RADIUS) * 180.0 / M_PI;
}

+ (double)pixelSpaceYToLatitude:(double)pixelY
{
    return (M_PI / 2.0 - 2.0 * atan(exp((round(pixelY) - MERCATOR_OFFSET) / MERCATOR_RADIUS))) * 180.0 / M_PI;
}

#pragma mark -
#pragma mark Helper methods

- (MKCoordinateSpan)coordinateSpanWithMapView:(AIRMap *)mapView
                             centerCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                 andZoomLevel:(double)zoomLevel
{
    // convert center coordiate to pixel space
    double centerPixelX = [AIRMapFabric longitudeToPixelSpaceX:centerCoordinate.longitude];
    double centerPixelY = [AIRMapFabric latitudeToPixelSpaceY:centerCoordinate.latitude];

    // determine the scale value from the zoom level
    double zoomExponent = AIRMapMaxZoomLevel - zoomLevel;
    double zoomScale = pow(2, zoomExponent);

    // scale the map’s size in pixel space
    CGSize mapSizeInPixels = mapView.bounds.size;
    double scaledMapWidth = mapSizeInPixels.width * zoomScale;
    double scaledMapHeight = mapSizeInPixels.height * zoomScale;

    // figure out the position of the top-left pixel
    double topLeftPixelX = centerPixelX - (scaledMapWidth / 2);
    double topLeftPixelY = centerPixelY - (scaledMapHeight / 2);

    // find delta between left and right longitudes
    CLLocationDegrees minLng = [AIRMapFabric pixelSpaceXToLongitude:topLeftPixelX];
    CLLocationDegrees maxLng = [AIRMapFabric pixelSpaceXToLongitude:topLeftPixelX + scaledMapWidth];
    CLLocationDegrees longitudeDelta = maxLng - minLng;

    // find delta between top and bottom latitudes
    CLLocationDegrees minLat = [AIRMapFabric pixelSpaceYToLatitude:topLeftPixelY];
    CLLocationDegrees maxLat = [AIRMapFabric pixelSpaceYToLatitude:topLeftPixelY + scaledMapHeight];
    CLLocationDegrees latitudeDelta = -1 * (maxLat - minLat);

    // create and return the lat/lng span
    MKCoordinateSpan span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta);
    return span;
}

#pragma mark -
#pragma mark Public methods

- (void)setCenterCoordinate:(CLLocationCoordinate2D)centerCoordinate
                  zoomLevel:(double)zoomLevel
                   animated:(BOOL)animated
                    mapView:(AIRMap *)mapView
{
    // clamp large numbers to 28
    zoomLevel = MIN(zoomLevel, AIRMapMaxZoomLevel);

    // use the zoom level to compute the region
    MKCoordinateSpan span = [self coordinateSpanWithMapView:mapView centerCoordinate:centerCoordinate andZoomLevel:zoomLevel];
    MKCoordinateRegion region = MKCoordinateRegionMake(centerCoordinate, span);

    // set the region like normal
    [mapView setRegion:region animated:animated];
}

//KMapView cannot display tiles that cross the pole (as these would involve wrapping the map from top to bottom, something that a Mercator projection just cannot do).
-(MKCoordinateRegion)coordinateRegionWithMapView:(AIRMap *)mapView
                                centerCoordinate:(CLLocationCoordinate2D)centerCoordinate
                                    andZoomLevel:(double)zoomLevel
{
	// clamp lat/long values to appropriate ranges
	centerCoordinate.latitude = MIN(MAX(-90.0, centerCoordinate.latitude), 90.0);
	centerCoordinate.longitude = fmod(centerCoordinate.longitude, 180.0);

	// convert center coordiate to pixel space
	double centerPixelX = [AIRMapFabric longitudeToPixelSpaceX:centerCoordinate.longitude];
	double centerPixelY = [AIRMapFabric latitudeToPixelSpaceY:centerCoordinate.latitude];

	// determine the scale value from the zoom level
	double zoomExponent = AIRMapMaxZoomLevel - zoomLevel;
	double zoomScale = pow(2, zoomExponent);

	// scale the map’s size in pixel space
	CGSize mapSizeInPixels = mapView.bounds.size;
	double scaledMapWidth = mapSizeInPixels.width * zoomScale;
	double scaledMapHeight = mapSizeInPixels.height * zoomScale;

	// figure out the position of the left pixel
	double topLeftPixelX = centerPixelX - (scaledMapWidth / 2);

	// find delta between left and right longitudes
	CLLocationDegrees minLng = [AIRMapFabric pixelSpaceXToLongitude:topLeftPixelX];
	CLLocationDegrees maxLng = [AIRMapFabric pixelSpaceXToLongitude:topLeftPixelX + scaledMapWidth];
	CLLocationDegrees longitudeDelta = maxLng - minLng;

	// if we’re at a pole then calculate the distance from the pole towards the equator
	// as MKMapView doesn’t like drawing boxes over the poles
	double topPixelY = centerPixelY - (scaledMapHeight / 2);
	double bottomPixelY = centerPixelY + (scaledMapHeight / 2);
	BOOL adjustedCenterPoint = NO;
	if (topPixelY > MERCATOR_OFFSET * 2) {
		topPixelY = centerPixelY - scaledMapHeight;
		bottomPixelY = MERCATOR_OFFSET * 2;
		adjustedCenterPoint = YES;
	}

	// find delta between top and bottom latitudes
	CLLocationDegrees minLat = [AIRMapFabric pixelSpaceYToLatitude:topPixelY];
	CLLocationDegrees maxLat = [AIRMapFabric pixelSpaceYToLatitude:bottomPixelY];
	CLLocationDegrees latitudeDelta = -1 * (maxLat - minLat);

	// create and return the lat/lng span
	MKCoordinateSpan span = MKCoordinateSpanMake(latitudeDelta, longitudeDelta);
	MKCoordinateRegion region = MKCoordinateRegionMake(centerCoordinate, span);
	// once again, MKMapView doesn’t like drawing boxes over the poles
	// so adjust the center coordinate to the center of the resulting region
	if (adjustedCenterPoint) {
		region.center.latitude = [AIRMapFabric pixelSpaceYToLatitude:((bottomPixelY + topPixelY) / 2.0)];
	}

	return region;
}

- (double) zoomLevel:(AIRMap *)mapView {
    MKCoordinateRegion region = mapView.region;

    double centerPixelX = [AIRMapFabric longitudeToPixelSpaceX: region.center.longitude];
    double topLeftPixelX = [AIRMapFabric longitudeToPixelSpaceX: region.center.longitude - region.span.longitudeDelta / 2];

    double scaledMapWidth = (centerPixelX - topLeftPixelX) * 2;
    CGSize mapSizeInPixels = mapView.bounds.size;
    double zoomScale = scaledMapWidth / mapSizeInPixels.width;
    double zoomExponent = log(zoomScale) / log(2);
    double zoomLevel = AIRMapMaxZoomLevel - zoomExponent;

    return zoomLevel;
}

#pragma mark MKMapViewDelegate - Tracking the User Location

- (void)mapView:(AIRMap *)mapView didFailToLocateUserWithError:(NSError *)error {
    id event = @{@"error": @{ @"message": error.localizedDescription }};
    if (mapView.onUserLocationChange) {
        mapView.onUserLocationChange(event);
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

// Fabric related stuff


+ (ComponentDescriptorProvider)componentDescriptorProvider
{
    return concreteComponentDescriptorProvider<AIRMapComponentDescriptor>();
}

- (void)updateProps:(Props::Shared const &)props oldProps:(Props::Shared const &)oldProps
{
    // override with null ptr if it's inital render, and oldProps are not defined
    const auto &oldViewProps =  *std::static_pointer_cast<AIRMapProps const>(_props);
    const auto &newViewProps = *std::static_pointer_cast<AIRMapProps const>(props);

    NSLog(@"updateProps");
    
    
    if (oldViewProps.initialRegion.latitude != newViewProps.initialRegion.latitude ||
        oldViewProps.initialRegion.longitude != newViewProps.initialRegion.longitude ||
        oldViewProps.initialRegion.latitudeDelta != newViewProps.initialRegion.latitudeDelta || oldViewProps.initialRegion.longitudeDelta != newViewProps.initialRegion.longitudeDelta) {
       
        BOOL originalIgnore = self._map.ignoreRegionChanges;
        self._map.ignoreRegionChanges = YES;
        [self._map setInitialRegion: [RCTConvert MKCoordinateInitalRegionFabric:newViewProps.initialRegion]];
        self._map.ignoreRegionChanges = originalIgnore;
    }
    
    if (oldViewProps.region.latitude != newViewProps.region.latitude ||
        oldViewProps.region.longitude != newViewProps.region.longitude ||
        oldViewProps.region.latitudeDelta != newViewProps.region.latitudeDelta || oldViewProps.region.longitudeDelta != newViewProps.region.longitudeDelta) {
       
        BOOL originalIgnore = self._map.ignoreRegionChanges;
        self._map.ignoreRegionChanges = YES;
        [self._map setRegion:[RCTConvert MKCoordinateRegionFabric:newViewProps.region] animated:NO];
        self._map.ignoreRegionChanges = originalIgnore;
    }
    //RCT_EXPORT_VIEW_PROPERTY(isAccessibilityElement, BOOL)
   
    //RCT_REMAP_VIEW_PROPERTY(testID, accessibilityIdentifier, NSString)
    if (oldViewProps.testId != newViewProps.testId) {
        self._map.accessibilityIdentifier = RCTNSStringFromStringNilIfEmpty(newViewProps.testId);
    }
    //RCT_EXPORT_VIEW_PROPERTY(showsUserLocation, BOOL)
    if (oldViewProps.showsUserLocation != newViewProps.showsUserLocation) {
        self._map.showsUserLocation = newViewProps.showsUserLocation;
    }
    // RCT_EXPORT_VIEW_PROPERTY(tintColor, UIColor)
    if (oldViewProps.tintColor != newViewProps.tintColor) {
        self._map.tintColor = RCTUIColorFromSharedColor(newViewProps.tintColor);
    }
    // RCT_EXPORT_VIEW_PROPERTY(userLocationAnnotationTitle, NSString)
    if (oldViewProps.userLocationAnnotationTitle != newViewProps.userLocationAnnotationTitle) {
        self._map.userLocationAnnotationTitle = RCTNSStringFromStringNilIfEmpty(newViewProps.userLocationAnnotationTitle);
    }
    // RCT_EXPORT_VIEW_PROPERTY(userInterfaceStyle, NSString)
    if (oldViewProps.userInterfaceStyle != newViewProps.userInterfaceStyle) {
        
        [self._map setUserInterfaceStyle: RCTNSStringFromStringNilIfEmpty(newViewProps.userInterfaceStyle)];
    }
    // RCT_EXPORT_VIEW_PROPERTY(followsUserLocation, BOOL)
    if (oldViewProps.followsUserLocation != newViewProps.followsUserLocation) {
       // self._map.followsUserLocation = newViewProps.followsUserLocation;
    }
    // RCT_EXPORT_VIEW_PROPERTY(userLocationCalloutEnabled, BOOL)
    if (oldViewProps.userLocationCalloutEnabled != newViewProps.userLocationCalloutEnabled) {
        self._map.userLocationCalloutEnabled = newViewProps.userLocationCalloutEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(showsPointsOfInterest, BOOL)
    if (oldViewProps.showsPointsOfInterest != newViewProps.showsPointsOfInterest) {
        self._map.showsPointsOfInterest = newViewProps.showsPointsOfInterest;
    }
    // RCT_EXPORT_VIEW_PROPERTY(showsBuildings, BOOL)
    if (oldViewProps.showsBuildings != newViewProps.showsBuildings) {
        self._map.showsBuildings = newViewProps.showsBuildings;
    }
    // RCT_EXPORT_VIEW_PROPERTY(showsCompass, BOOL)
    if (oldViewProps.showsCompass != newViewProps.showsCompass) {
        self._map.showsCompass = newViewProps.showsCompass;
    }
    // RCT_EXPORT_VIEW_PROPERTY(showsScale, BOOL)
    if (oldViewProps.showsScale != newViewProps.showsScale) {
        self._map.showsScale = newViewProps.showsScale;
    }
    // RCT_EXPORT_VIEW_PROPERTY(showsTraffic, BOOL)
    if (oldViewProps.showsTraffic != newViewProps.showsTraffic) {
        self._map.showsTraffic = newViewProps.showsTraffic;
    }
    // RCT_EXPORT_VIEW_PROPERTY(zoomEnabled, BOOL)
    if (oldViewProps.zoomEnabled != newViewProps.zoomEnabled) {
        self._map.zoomEnabled = newViewProps.zoomEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(kmlSrc, NSString)
    if (oldViewProps.kmlSrc != newViewProps.kmlSrc) {
        // TODO not found, is it used????
        // self.kmlSrc = RCTNSStringFromStringNilIfEmpty(newViewProps.kmlSrc);
    }
    // RCT_EXPORT_VIEW_PROPERTY(rotateEnabled, BOOL)
    if (oldViewProps.rotateEnabled != newViewProps.rotateEnabled) {
        self._map.rotateEnabled = newViewProps.rotateEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(scrollEnabled, BOOL)
    if (oldViewProps.scrollEnabled != newViewProps.scrollEnabled) {
        self._map.scrollEnabled = newViewProps.scrollEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(pitchEnabled, BOOL)
    if (oldViewProps.pitchEnabled != newViewProps.pitchEnabled) {
        self._map.pitchEnabled = newViewProps.pitchEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(cacheEnabled, BOOL)
    if (oldViewProps.cacheEnabled != newViewProps.cacheEnabled) {
        self._map.cacheEnabled = newViewProps.cacheEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(loadingEnabled, BOOL)
    if (oldViewProps.loadingEnabled != newViewProps.loadingEnabled) {
        self._map.loadingEnabled = newViewProps.loadingEnabled;
    }
    // RCT_EXPORT_VIEW_PROPERTY(loadingBackgroundColor, UIColor)
    if (oldViewProps.loadingBackgroundColor != newViewProps.loadingBackgroundColor) {
        self._map.loadingBackgroundColor = RCTUIColorFromSharedColor(newViewProps.loadingBackgroundColor);
    }
    // RCT_EXPORT_VIEW_PROPERTY(loadingIndicatorColor, UIColor)
    if (oldViewProps.loadingIndicatorColor != newViewProps.loadingIndicatorColor) {
        self._map.loadingIndicatorColor = RCTUIColorFromSharedColor(newViewProps.loadingIndicatorColor);
    }
    // RCT_EXPORT_VIEW_PROPERTY(handlePanDrag, BOOL)
    if (oldViewProps.handlePanDrag != newViewProps.handlePanDrag) {
      //  self._map.handlePanDrag = newViewProps.handlePanDrag;
    }
    // RCT_EXPORT_VIEW_PROPERTY(maxDelta, CGFloat)
    if (oldViewProps.maxDelta != newViewProps.maxDelta) {
        self._map.maxDelta = newViewProps.maxDelta;
    }
    // RCT_EXPORT_VIEW_PROPERTY(minDelta, CGFloat)
    if (oldViewProps.minDelta != newViewProps.minDelta) {
        self._map.minDelta = newViewProps.minDelta;
    }
    // RCT_EXPORT_VIEW_PROPERTY(compassOffset, CGPoint)
    if (oldViewProps.compassOffset.x != newViewProps.compassOffset.x || oldViewProps.compassOffset.y != newViewProps.compassOffset.y) {
        self._map.compassOffset = (CGPoint) {newViewProps.compassOffset.x, newViewProps.compassOffset.y};
    }
    // RCT_EXPORT_VIEW_PROPERTY(legalLabelInsets, UIEdgeInsets)
    // RCT_EXPORT_VIEW_PROPERTY(mapPadding, UIEdgeInsets)
    // RCT_EXPORT_VIEW_PROPERTY(mapType, MKMapType)
    if (oldViewProps.mapType != newViewProps.mapType) {
        id mapStr = RCTNSStringFromStringNilIfEmpty(newViewProps.mapType);
        if (mapStr) {
            self._map.mapType = [RCTConvert MKMapType:mapStr];
        }
    }
   
    [super updateProps:props oldProps:oldProps];
}


- (void)mountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
    [self._map insertReactSubview: childComponentView atIndex: index];
}

- (void)unmountChildComponentView:(UIView<RCTComponentViewProtocol> *)childComponentView index:(NSInteger)index
{
    [self._map removeReactSubview: childComponentView];
}

- (void) sendResponseForCommand: (NSString*) uuid withJson: (NSDictionary*) json {
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:json
                                                       options:NSJSONWritingPrettyPrinted // Pass 0 if you don't care about the readability of the generated string
                                                         error:&error];

    if (! jsonData) {
        NSLog(@"Got an error: %@", error);
    } else {
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        auto value = (AIRMapEventEmitter::OnCommandResponse) {
            std::string([uuid UTF8String]), std::string([jsonString UTF8String])
        };
        std::static_pointer_cast<AIRMapEventEmitter const>(_eventEmitter)->onCommandResponse(value);
        
    }
}

- (id) jsonToDict: (NSString*) s {
    NSData * data = [s dataUsingEncoding:NSUTF8StringEncoding];
    NSError * error=nil;
    id parsedThing = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    return parsedThing;
}


- (void)getCamera:(NSString *)commandUUID {
    MKMapCamera * camera = [self._map camera];
    NSDictionary * json = @{
        @"center": @{
                @"latitude": @(camera.centerCoordinate.latitude),
                @"longitude": @(camera.centerCoordinate.longitude),
        },
        @"pitch": @(camera.pitch),
        @"heading": @(camera.heading),
        @"altitude": @(camera.altitude),
    };
    
    [self sendResponseForCommand:commandUUID withJson: json];
}

- (void)setCamera:(NSString *)commandUUID camera:(NSString *)cameraJSON {
    
    // Merge the changes given with the current camera
    AIRMap * mapView = (AIRMap *)self.contentView;
    MKMapCamera *camera = [RCTConvert MKMapCameraWithDefaults:[self jsonToDict:cameraJSON] existingCamera:[mapView camera]];

    // don't emit region change events when we are setting the camera
    BOOL originalIgnore = mapView.ignoreRegionChanges;
    mapView.ignoreRegionChanges = YES;
    [mapView setCamera:camera animated:NO];
    mapView.ignoreRegionChanges = originalIgnore;
}

- (void)animateCamera:(NSString *)commandUUID camera:(NSString *)cameraJSON duration:(float)duration {
    AIRMap *mapView = (AIRMap *)self.contentView;

    // Merge the changes given with the current camera
    MKMapCamera *camera = [RCTConvert MKMapCameraWithDefaults:[self jsonToDict:cameraJSON] existingCamera:[mapView camera]];

    // don't emit region change events when we are setting the camera
    BOOL originalIgnore = mapView.ignoreRegionChanges;
    mapView.ignoreRegionChanges = YES;
    [AIRMap animateWithDuration:duration/1000 animations:^{
        [mapView setCamera:camera animated:YES];
    } completion:^(BOOL finished){
        mapView.ignoreRegionChanges = originalIgnore;
    }];
}
- (void)animateToNavigation:(NSString *)commandUUID location:(NSString *)regionJSON bearing:(float)bearing angle:(float)angle duration:(float)duration {
    AIRMap *mapView = (AIRMap *)self.contentView;
    MKMapCamera *mapCamera = [[mapView camera] copy];
     [mapCamera setPitch:angle];
     [mapCamera setHeading:bearing];
    
    NSDictionary * dict = [self jsonToDict:regionJSON];
    MKCoordinateRegion region = [RCTConvert MKCoordinateRegion: dict];

    [AIRMap animateWithDuration:duration/1000 animations:^{
        [mapView setRegion: region animated:YES];
        [mapView setCamera:mapCamera animated:YES];
    }];
}
- (void)animateToRegion:(NSString *)commandUUID region:(NSString *)regionJSON duration:(float)duration {
    AIRMap *mapView = (AIRMap *)self.contentView;
    MKCoordinateRegion region = [RCTConvert MKCoordinateRegion: [self jsonToDict:regionJSON]];
    [AIRMap animateWithDuration:duration/1000 animations:^{
        [mapView setRegion:region animated:YES];
    }];
}

- (void)animateToCoordinate:(NSString *)commandUUID latLngJSON:(NSString *)latLng duration:(float)duration {
    AIRMap *mapView = (AIRMap *)self.contentView;
    MKCoordinateRegion region;
    NSDictionary * latLngDict = [self jsonToDict:latLng];
    
    region.span = mapView.region.span;
    region.center = [RCTConvert CLLocationCoordinate2D: latLngDict];
    [AIRMap animateWithDuration:duration/1000 animations:^{
        [mapView setRegion:region animated:YES];
    }];
}
- (void)animateToBearing:(NSString *)commandUUID bearing:(float)bearing duration:(float)duration {
    AIRMap *mapView = (AIRMap *)self.contentView;

    MKMapCamera *mapCamera = [[mapView camera] copy];
    [mapCamera setHeading:bearing];

    [AIRMap animateWithDuration:duration/1000 animations:^{
        [mapView setCamera:mapCamera animated:YES];
    }];
}
- (void)animateToViewingAngle:(NSString *)commandUUID angle:(float)angle duration:(float)duration {
    AIRMap *mapView = (AIRMap *)self.contentView;

    MKMapCamera *mapCamera = [[mapView camera] copy];
    [mapCamera setPitch:angle];

    [AIRMap animateWithDuration:duration/1000 animations:^{
        [mapView setCamera:mapCamera animated:YES];
    }];
}
- (void)fitToElements:(NSString *)commandUUID edgePadding:(NSString *)edgePadding duration:(float)duration animated:(BOOL)animated {
    AIRMap *mapView = (AIRMap *)self.contentView;
    // TODO(lmr): we potentially want to include overlays here... and could concat the two arrays together.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [mapView showAnnotations:mapView.annotations animated:animated];
    });
}
- (void)fitToSuppliedMarkers:(NSString *)commandUUID markers:(NSString *)markersJSON edgePadding:(NSString *)edgePaddingJSON animated:(BOOL)animated {
    AIRMap *mapView = (AIRMap *)self.contentView;
    // TODO(lmr): we potentially want to include overlays here... and could concat the two arrays together.
    // id annotations = mapView.annotations;
    
    NSArray * markers= [self jsonToDict:markersJSON];

    NSPredicate *filterMarkers = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        AIRMapMarker *marker = (AIRMapMarker *)evaluatedObject;
        return [marker isKindOfClass:[AIRMapMarker class]] && [markers containsObject:marker.identifier];
    }];

    NSArray *filteredMarkers = [mapView.annotations filteredArrayUsingPredicate:filterMarkers];

    [mapView showAnnotations:filteredMarkers animated:animated];
}
- (void)fitToCoordinates:(NSString *)commandUUID coordinates:(NSString *)coordinatesJSON edgePadding:(NSString *)edgePaddingJSON animated:(BOOL)animated {
    AIRMap *mapView = (AIRMap *)self.contentView;
    
    NSDictionary* edgePadding = [self jsonToDict:edgePaddingJSON];
    NSArray* coordinates = [self jsonToDict:coordinatesJSON];

    // Create Polyline with coordinates
    CLLocationCoordinate2D coords[coordinates.count];
    for(int i = 0; i < coordinates.count; i++)
    {
        // TODO fix that
        // coords[i] = coordinates[i].coordinate;
    }
    MKPolyline *polyline = [MKPolyline polylineWithCoordinates:coords count:coordinates.count];

    // Set Map viewport
    CGFloat top = [RCTConvert CGFloat:edgePadding[@"top"]];
    CGFloat right = [RCTConvert CGFloat:edgePadding[@"right"]];
    CGFloat bottom = [RCTConvert CGFloat:edgePadding[@"bottom"]];
    CGFloat left = [RCTConvert CGFloat:edgePadding[@"left"]];

    [mapView setVisibleMapRect:[polyline boundingMapRect] edgePadding:UIEdgeInsetsMake(top, left, bottom, right) animated:animated];
}
- (void)getMapBoundaries:(NSString *)commandUUID {
    AIRMap *mapView = (AIRMap *)self.contentView;
    NSArray *boundingBox = [mapView getMapBoundaries];

    NSDictionary * response =@{
        @"northEast" : @{
            @"longitude" : boundingBox[0][0],
            @"latitude" : boundingBox[0][1]
        },
        @"southWest" : @{
            @"longitude" : boundingBox[1][0],
            @"latitude" : boundingBox[1][1]
        }
    };
    [self sendResponseForCommand:commandUUID withJson: response];
}
- (void)setMapBoundaries:(NSString *)commandUUID northEast:(NSString *)northEast southWest:(NSString *)southWest {
    NSLog(@"setMapBoundaries is unimplemented on AIRMap");
}
- (void)setIndoorActiveLevelIndex:(NSString *)commandUUID activeLevelIndex:(float)activeLevelIndex {
    NSLog(@"setIndoorActiveLevelIndex is unimplemented on AIRMap");
}
/*
- (void)takeSnapshot:(NSString *)commandUUID width:(float)width height:(float)height region:(NSString *)regionJSON format:(NSString *)format quality:(NSInteger)quality result:(NSString *)result {
    AIRMap *mapView = (AIRMap *)self.contentView;
    MKCoordinateRegion region = [RCTConvert MKCoordinateRegion:  [self jsonToDict:regionJSON]];
    MKMapSnapshotOptions *options = [[MKMapSnapshotOptions alloc] init];

    options.mapType = mapView.mapType;
    options.region = (region.center.latitude && region.center.longitude) ? region : mapView.region;
    options.size = CGSizeMake(
      (width == 0) ? mapView.bounds.size.width : width,
      (height == 0) ? mapView.bounds.size.height : height
    );
    options.scale = [[UIScreen mainScreen] scale];

    MKMapSnapshotter *snapshotter = [[MKMapSnapshotter alloc] initWithOptions:options];

    [self takeMapSnapshot:mapView
        snapshotter:snapshotter
        format:format
        quality:quality
        result:result
        callback:callback];
}*/

- (void)getAddressFromCoordinates:(NSString *)commandUUID coordinate:(NSString *)coordinateJSON {
    AIRMap *view = (AIRMap *)self.contentView;
    
    NSDictionary* coordinate = [self jsonToDict:coordinateJSON];
   
        if (coordinate == nil ||
            ![[coordinate allKeys] containsObject:@"latitude"] ||
            ![[coordinate allKeys] containsObject:@"longitude"]) {
            // reject(@"Invalid argument", [NSString stringWithFormat:@"Invalid coordinate format"], NULL);
        }
        CLLocation *location = [[CLLocation alloc] initWithLatitude:[coordinate[@"latitude"] doubleValue]
                                                          longitude:[coordinate[@"longitude"] doubleValue]];
        CLGeocoder *geoCoder = [[CLGeocoder alloc] init];
        [geoCoder reverseGeocodeLocation:location
                       completionHandler:^(NSArray *placemarks, NSError *error) {
                if (error == nil && [placemarks count] > 0){
                    CLPlacemark *placemark = placemarks[0];
                    NSDictionary * response = @{
                        @"name" : [NSString stringWithFormat:@"%@", placemark.name],
                        @"thoroughfare" : [NSString stringWithFormat:@"%@", placemark.thoroughfare],
                        @"subThoroughfare" : [NSString stringWithFormat:@"%@", placemark.subThoroughfare],
                        @"locality" : [NSString stringWithFormat:@"%@", placemark.locality],
                        @"subLocality" : [NSString stringWithFormat:@"%@", placemark.subLocality],
                        @"administrativeArea" : [NSString stringWithFormat:@"%@", placemark.administrativeArea],
                        @"subAdministrativeArea" : [NSString stringWithFormat:@"%@", placemark.subAdministrativeArea],
                        @"postalCode" : [NSString stringWithFormat:@"%@", placemark.postalCode],
                        @"countryCode" : [NSString stringWithFormat:@"%@", placemark.ISOcountryCode],
                        @"country" : [NSString stringWithFormat:@"%@", placemark.country],
                    };
                    [self sendResponseForCommand:commandUUID withJson: response];
                } else {
                    // reject(@"Invalid argument", [NSString stringWithFormat:@"Can not get address location"], NULL);
                }
        }];
}
- (void)pointForCoordinate:(NSString *)commandUUID coordinate:(NSString *)coordinateJSON {
    AIRMap *mapView = (AIRMap *)self._map;
    NSDictionary* coordinate = [self jsonToDict:coordinateJSON];
   
    CGPoint touchPoint = [mapView convertCoordinate:
                          CLLocationCoordinate2DMake(
                                                     [coordinate[@"latitude"] doubleValue],
                                                     [coordinate[@"longitude"] doubleValue]
                                                     )
                                      toPointToView:mapView];
    NSDictionary* response =@{
              @"x": @(touchPoint.x),
              @"y": @(touchPoint.y),
              };
    
    [self sendResponseForCommand:commandUUID withJson: response];
}
- (void)coordinateForPoint:(NSString *)commandUUID coordinate:(NSString *)pointJSON {
    AIRMap *mapView = (AIRMap *)self.contentView;
    NSDictionary* point = [self jsonToDict:pointJSON];
   
    CLLocationCoordinate2D coordinate = [mapView convertPoint:
                                         CGPointMake(
                                                     [point[@"x"] doubleValue],
                                                     [point[@"y"] doubleValue]
                                                     )
                                         toCoordinateFromView:mapView];

    NSDictionary* response  =@{
              @"latitude": @(coordinate.latitude),
              @"longitude": @(coordinate.longitude),
              };
    [self sendResponseForCommand:commandUUID withJson: response];
    
}
- (void)getMarkersFrames:(NSString *)commandUUID onlyVisible:(BOOL)onlyVisible {
    AIRMap *mapView = (AIRMap *)self.contentView;
    NSDictionary* response = [mapView getMarkersFramesWithOnlyVisible:onlyVisible];
    [self sendResponseForCommand:commandUUID withJson: response];
}

- (void)handleCommand:(const NSString *)commandName args:(const NSArray *)args
{
    RCTAIRMapHandleCommand(self, commandName, args);
}



@end

extern "C" {
    Class<RCTComponentViewProtocol> AIRMapCls(void)
    {
        return AIRMapFabric.class;
    }
}
