import { ColorValue, HostComponent, ViewProps } from 'react-native';
import type {
  Float,
  Int32,
  Double,
  BubblingEventHandler,
  // @ts-ignore TODO: remove once there is a .d.ts file with definitions
} from 'react-native/Libraries/Types/CodegenTypes';
// @ts-ignore TODO: remove once there is a .d.ts file with definitions
import { ImageSource } from 'react-native/Libraries/Image/ImageSource';
// @ts-ignore TODO: remove once there is a .d.ts file with definitions
import codegenNativeCommands from 'react-native/Libraries/Utilities/codegenNativeCommands';

// @ts-ignore TODO: remove once there is a .d.ts file with definitions
import codegenNativeComponentUntyped from 'react-native/Libraries/Utilities/codegenNativeComponent';

// eslint-disable-next-line @typescript-eslint/ban-types
const codegenNativeComponent = codegenNativeComponentUntyped as <T extends {}>(
  name: string
) => HostComponent<T>;

type LatLng = Readonly<{
  latitude: Float;
  longitude: Float;
}>;

type Point = Readonly<{
  x: Float;
  y: Float;
}>;

type MapEvent = Readonly<{
  coordinate: {
    latitude: Double;
    longitude: Double;
  };
  position: {
    x: Float;
    y: Float;
  };
  action: string;
  id?: string;
}>;

interface MarkerProps extends ViewProps {
  identifier?: string;
  reuseIdentifier?: string;
  title?: string;
  description?: string;
  image?: ImageSource;
  icon?: ImageSource;
  opacity?: Float;
  pinColor?: ColorValue;
  coordinate: LatLng; //| AnimatedRegion;
  centerOffset?: Point;
  calloutOffset?: Point;
  anchor?: Point;
  calloutAnchor?: Point;
  flat?: boolean;
  draggable?: boolean;
  tappable?: boolean;
  tracksViewChanges?: boolean;
  tracksInfoWindowChanges?: boolean;
  stopPropagation?: boolean;

  rotation?: Float;
  zIndexCopy?: Int32; // avoid clash with native zIndex property
  onPress?: BubblingEventHandler<MapEvent>;
  onSelect?: BubblingEventHandler<MapEvent>;
  onDeselect?: BubblingEventHandler<MapEvent>;
  onCalloutPress?: BubblingEventHandler<MapEvent>;
  onDragStart?: BubblingEventHandler<MapEvent>;
  onDrag?: BubblingEventHandler<MapEvent>;
  onDragEnd?: BubblingEventHandler<MapEvent>;
}

export interface AIRMapNativeCommands {
  redraw: (viewRef: React.ElementRef<any>) => void;
  hideCallout: (viewRef: React.ElementRef<any>) => void;
  showCallout: (viewRef: React.ElementRef<any>) => void;
  redrawCallout: (viewRef: React.ElementRef<any>) => void;
}

export const AIRMapCommands: AIRMapNativeCommands =
  codegenNativeCommands<AIRMapNativeCommands>({
    supportedCommands: [
      'redraw',
      'showCallout',
      'hideCallout',
      'redrawCallout',
    ],
  });

export default codegenNativeComponent<MarkerProps>('AIRMapMarker');
