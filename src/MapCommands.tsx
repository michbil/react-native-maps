import React from 'react';
import { Camera, LatLng, Region } from 'react-native-maps';
import { v4 as uuidv4 } from 'uuid';
import {
  AIRMapCommands,
  CommandResponse,
} from './NativeComponents/AIRMapNativeComponent';

/*
type EmulatedCommandInterface = {
  getCamera: (viewRef: React.ElementRef<any>) => Promise<Camera>;
  setCamera: (viewRef: React.ElementRef<any>, camera: Camera) => void;
  animateCamera: (
    viewRef: React.ElementRef<any>,
    camera: Camera,
    duration?: Float
  ) => void;

  fitToElements: (
    viewRef: React.ElementRef<any>,
    edgePadding: EdgePadding,
    duration?: Float,
    animated?: boolean
  ) => void;
  fitToSuppliedMarkers: (
    viewRef: React.ElementRef<any>,
    markers: string[],
    edgePadding: EdgePadding,
    animated?: boolean
  ) => void;
  fitToCoordinates: (
    viewRef: React.ElementRef<any>,
    coordinates: Coordinate[],
    edgePadding: EdgePadding,
    animated?: boolean
  ) => void;
  getMapBoundaries: (viewRef: React.ElementRef<any>) => void;
  setMapBoundaries: (
    viewRef: React.ElementRef<any>,
    northEast: Coordinate,
    southWest: Coordinate
  ) => void;
  setIndoorActiveLevelIndex: (
    viewRef: React.ElementRef<any>,
    activeLevelIndex: Float
  ) => void;
  takeSnapshot: (
    viewRef: React.ElementRef<any>,
    width: Float,
    height: Float,
    region: Region | {},
    format: string,
    quality: Int32,
    result: string,
    callback: (err: any, snapshot: string) => void
  ) => void;
  getAddressFromCoordinates: (
    viewRef: React.ElementRef<any>,
    coordinate: Coordinate
  ) => void;
  pointForCoordinate: (
    viewRef: React.ElementRef<any>,
    coordinate: Coordinate
  ) => Promise<Point>;
  coordinateForPoint: (
    viewRef: React.ElementRef<any>,
    point: Point
  ) => Promise<Coordinate>;
  getMarkersFrames: (
    viewRef: React.ElementRef<any>,
    onlyVisible: boolean
  ) => Promise<unknown>;
};
*/

class MapCommands {
  private callbacks: { [k: string]: (json: string) => void } = {};

  onCommandResponse(response: CommandResponse) {
    console.log('Got response', response);
    let callback = this.callbacks[response.commandUUID];
    if (callback) {
      try {
        callback(response.json);
        delete this.callbacks[response.commandUUID]; // delete callback
      } catch (err) {
        console.log('Failed to parse result');
      }
    }
  }

  _getResponse(commandID: string): Promise<string> {
    return new Promise((resolve: (json: string) => void) => {
      this.callbacks[commandID] = resolve;
    });
  }

  async getCamera(viewRef: React.ElementRef<any>): Promise<Camera> {
    const commandId: string = uuidv4();
    AIRMapCommands.getCamera(viewRef, commandId);
    const resp = await this._getResponse(commandId);
    return JSON.parse(resp);
  }

  setCamera(viewRef: React.ElementRef<any>, camera: Camera) {
    const commandId: string = uuidv4();
    AIRMapCommands.setCamera(viewRef, commandId, JSON.stringify(camera));
  }
  animateCamera(
    viewRef: React.ElementRef<any>,
    camera: Camera,
    duration?: number
  ) {
    const commandId: string = uuidv4();
    AIRMapCommands.animateCamera(
      viewRef,
      commandId,
      JSON.stringify(camera),
      duration
    );
  }
  animateToNavigation(
    viewRef: React.ElementRef<any>,
    location: LatLng,
    bearing: number,
    angle: number,
    duration?: number
  ) {
    const commandId: string = uuidv4();
    AIRMapCommands.animateToNavigation(
      viewRef,
      commandId,
      JSON.stringify(location),
      bearing,
      angle,
      duration
    );
  }

  animateToRegion(
    viewRef: React.ElementRef<any>,
    region: Region,
    duration?: number
  ) {
    const commandId: string = uuidv4();
    AIRMapCommands.animateToRegion(
      viewRef,
      commandId,
      JSON.stringify(region),
      duration
    );
  }
  animateToCoordinate(
    viewRef: React.ElementRef<any>,
    latLng: LatLng,
    duration?: number
  ) {
    const commandId: string = uuidv4();
    AIRMapCommands.animateToCoordinate(
      viewRef,
      commandId,
      JSON.stringify(latLng),
      duration
    );
  }
  animateToBearing(
    viewRef: React.ElementRef<any>,
    bearing: number,
    duration?: number
  ) {
    const commandId: string = uuidv4();
    AIRMapCommands.animateToBearing(viewRef, commandId, bearing, duration);
  }
  animateToViewingAngle(
    viewRef: React.ElementRef<any>,
    angle: number,
    duration?: number
  ) {
    const commandId: string = uuidv4();
    AIRMapCommands.animateToViewingAngle(viewRef, commandId, angle, duration);
  }
}

export default MapCommands;
