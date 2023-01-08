import PropTypes from 'prop-types';
import React, { Component } from 'react';
import {
  Platform,
  Animated as RNAnimated,
  NativeModules,
  LayoutChangeEvent,
  HostComponent,
  NativeMethods,
  requireNativeComponent,
} from 'react-native';
import {
  EdgeInsetsPropType,
  PointPropType,
  ColorPropType,
  ViewPropTypes,
} from 'deprecated-react-native-prop-types';
import MapMarker from './MapMarker';
import MapPolyline from './MapPolyline';
import MapPolygon from './MapPolygon';
import MapCircle from './MapCircle';
import MapCallout from './MapCallout';
import MapCalloutSubview from './MapCalloutSubview';
import MapOverlay from './MapOverlay';
import MapUrlTile from './MapUrlTile';
import MapWMSTile from './MapWMSTile';
import MapLocalTile from './MapLocalTile';
import MapHeatMap from './MapHeatmap';
import AnimatedRegion from './AnimatedRegion';
import Geojson from './Geojson';
import {
  contextTypes as childContextTypes,
  getAirMapName,
  googleMapIsInstalled,
  createNotSupportedComponent,
} from './decorateMapComponent';
import * as ProviderConstants from './ProviderConstants';
import {
  Camera,
  Coordinate,
  EdgePadding,
  LatLng,
  MapEvent,
  MapViewProps,
  Point,
  Region,
  SnapshotOptions,
} from 'react-native-maps';
import AIRGoogleMap from './NativeComponents/AIRGoogleMapNativeComponent';
import AIRMap, {
  AIRMapCommands,
  AIRMapNativeCommands,
  AIRMapProps,
  CommandResponse,
} from './NativeComponents/AIRMapNativeComponent';
import MapCommands from './MapCommands';

export const MAP_TYPES = {
  STANDARD: 'standard',
  SATELLITE: 'satellite',
  HYBRID: 'hybrid',
  TERRAIN: 'terrain',
  NONE: 'none',
  MUTEDSTANDARD: 'mutedStandard',
};

const GOOGLE_MAPS_ONLY_TYPES = [MAP_TYPES.TERRAIN, MAP_TYPES.NONE];

const viewConfig = {
  uiViewClassName: 'AIR<provider>Map',
  validAttributes: {
    region: true,
  },
};

/**
 * Defines the map camera.
 */
const CameraShape = PropTypes.shape({
  center: PropTypes.shape({
    latitude: PropTypes.number.isRequired,
    longitude: PropTypes.number.isRequired,
  }),
  pitch: PropTypes.number.isRequired,
  heading: PropTypes.number.isRequired,
  altitude: PropTypes.number.isRequired,
  zoom: PropTypes.number.isRequired,
});

const propTypes = {
  ...ViewPropTypes,
  /**
   * When provider is "google", we will use GoogleMaps.
   * Any value other than "google" will default to using
   * MapKit in iOS or GoogleMaps in android as the map provider.
   */
  provider: PropTypes.oneOf(['google']),

  /**
   * Used to style and layout the `MapView`.  See `StyleSheet.js` and
   * `ViewStylePropTypes.js` for more info.
   */
  style: ViewPropTypes.style,

  /**
   * A json object that describes the style of the map. This is transformed to a string
   * and saved in mayStyleString to be sent to android and ios
   * https://developers.google.com/maps/documentation/ios-sdk/styling#use_a_string_resource
   * https://developers.google.com/maps/documentation/android-api/styling
   */
  customMapStyle: PropTypes.array,

  /**
   * A json string that describes the style of the map
   * https://developers.google.com/maps/documentation/ios-sdk/styling#use_a_string_resource
   * https://developers.google.com/maps/documentation/android-api/styling
   */
  customMapStyleString: PropTypes.string,

  /**
   * If `true` the app will ask for the user's location.
   * Default value is `false`.
   *
   * **NOTE**: You need to add NSLocationWhenInUseUsageDescription key in
   * Info.plist to enable geolocation, otherwise it is going
   * to *fail silently*! You will also need to add an explanation for why
   * you need the users location against `NSLocationWhenInUseUsageDescription` in Info.plist.
   * Otherwise Apple may reject your app submission.
   */
  showsUserLocation: PropTypes.bool,

  /**
   * The title of the annotation for current user location. This only works if
   * `showsUserLocation` is true.
   * There is a default value `My Location` set by MapView.
   *
   * @platform ios
   */
  userLocationAnnotationTitle: PropTypes.string,

  /**
   * The user interface style for the map view
   * There is a default value is the device settings.
   *
   * @platform ios
   */
  userInterfaceStyle: PropTypes.oneOf(['light', 'dark']),

  /**
   * If `false` hide the button to move map to the current user's location.
   * Default value is `true`.
   *
   * @platform android
   */
  showsMyLocationButton: PropTypes.bool,

  /**
   * If `true` the map will focus on the user's location. This only works if
   * `showsUserLocation` is true and the user has shared their location.
   * Default value is `false`.
   *
   * @platform ios
   */
  followsUserLocation: PropTypes.bool,
  /**
   * If `true` clicking user location will show the default callout for userLocation annotation
   * Default value is `false`.
   *
   * @platform ios
   */
  userLocationCalloutEnabled: PropTypes.bool,

  /**
   * If `false` points of interest won't be displayed on the map.
   * Default value is `true`.
   *
   */
  showsPointsOfInterest: PropTypes.bool,

  /**
   * If `false` compass won't be displayed on the map.
   * Default value is `true`.
   *
   * @platform ios
   */
  showsCompass: PropTypes.bool,

  /**
   * If `false` the user won't be able to pinch/zoom the map.
   * Default value is `true`.
   *
   */
  zoomEnabled: PropTypes.bool,

  /**
   * If `false` the user won't be able to double tap to zoom the map.
   * However it will greatly decrease delay of tap gesture recognition.
   * Default value is `true`.
   *
   */
  zoomTapEnabled: PropTypes.bool,

  /**
   *If `false` the user won't be able to zoom the map
   * Default value is `true`.
   *
   *@platform android
   */
  zoomControlEnabled: PropTypes.bool,

  /**
   * If `false` the user won't be able to pinch/rotate the map.
   * Default value is `true`.
   *
   */
  rotateEnabled: PropTypes.bool,

  /**
   * If `false` the map will stay centered while rotating or zooming.
   * Default value is `true`.
   *
   */
  scrollDuringRotateOrZoomEnabled: PropTypes.bool,

  /**
   * If `true` the map will be cached to an Image for performance
   * Default value is `false`.
   *
   */
  cacheEnabled: PropTypes.bool,

  /**
   * If `true` the map will be showing a loading indicator
   * Default value is `false`.
   *
   */
  loadingEnabled: PropTypes.bool,

  /**
   * Loading background color while generating map cache image or loading the map
   * Default color is light gray.
   *
   */
  loadingBackgroundColor: ColorPropType,

  /**
   * Loading indicator color while generating map cache image or loading the map
   * Default color is gray color for iOS, theme color for Android.
   *
   */
  loadingIndicatorColor: ColorPropType,

  /**
   * If `false` the user won't be able to change the map region being displayed.
   * Default value is `true`.
   *
   */
  scrollEnabled: PropTypes.bool,

  /**
   * If `false` the user won't be able to adjust the camera’s pitch angle.
   * Default value is `true`.
   *
   */
  pitchEnabled: PropTypes.bool,

  /**
   * If `false` will hide 'Navigate' and 'Open in Maps' buttons on marker press
   * Default value is `true`.
   *
   * @platform android
   */
  toolbarEnabled: PropTypes.bool,

  /**
   * A Boolean indicating whether on marker press the map will move to the pressed marker
   * Default value is `true`
   *
   * @platform android
   */
  moveOnMarkerPress: PropTypes.bool,

  /**
   * A Boolean indicating whether the map shows scale information.
   * Default value is `false`
   *
   * @platform ios
   */
  showsScale: PropTypes.bool,

  /**
   * A Boolean indicating whether the map displays extruded building information.
   * Default value is `true`.
   */
  showsBuildings: PropTypes.bool,

  /**
   * A Boolean value indicating whether the map displays traffic information.
   * Default value is `false`.
   */
  showsTraffic: PropTypes.bool,

  /**
   * A Boolean indicating whether indoor maps should be enabled.
   * Default value is `false`
   *
   * @platform android
   */
  showsIndoors: PropTypes.bool,

  /**
   * A Boolean indicating whether indoor level picker should be enabled.
   * Default value is `false`
   *
   * @platform android
   */
  showsIndoorLevelPicker: PropTypes.bool,

  /**
   * The map type to be displayed.
   *
   * - standard: standard road map (default)
   * - satellite: satellite view
   * - hybrid: satellite view with roads and points of interest overlayed
   * - terrain: topographic view
   * - none: no base map
   */
  mapType: PropTypes.oneOf(Object.values(MAP_TYPES)),

  /**
   * The region to be displayed by the map.
   *
   * The region is defined by the center coordinates and the span of
   * coordinates to display.
   */
  region: PropTypes.shape({
    /**
     * Coordinates for the center of the map.
     */
    latitude: PropTypes.number.isRequired,
    longitude: PropTypes.number.isRequired,

    /**
     * Difference between the minimun and the maximum latitude/longitude
     * to be displayed.
     */
    latitudeDelta: PropTypes.number.isRequired,
    longitudeDelta: PropTypes.number.isRequired,
  }),

  /**
   * The initial region to be displayed by the map.  Use this prop instead of `region`
   * only if you don't want to control the viewport of the map besides the initial region.
   *
   * Changing this prop after the component has mounted will not result in a region change.
   *
   * This is similar to the `initialValue` prop of a text input.
   */
  initialRegion: PropTypes.shape({
    /**
     * Coordinates for the center of the map.
     */
    latitude: PropTypes.number.isRequired,
    longitude: PropTypes.number.isRequired,

    /**
     * Difference between the minimun and the maximum latitude/longitude
     * to be displayed.
     */
    latitudeDelta: PropTypes.number.isRequired,
    longitudeDelta: PropTypes.number.isRequired,
  }),

  /**
   * The camera view the map should use.
   *
   * Use the camera system, instead of the region system, if you need control over
   * the pitch or heading.
   */
  camera: CameraShape,

  /**
   * The initial camera view the map should use.  Use this prop instead of `camera`
   * only if you don't want to control the camera of the map besides the initial view.
   *
   * Use the camera system, instead of the region system, if you need control over
   * the pitch or heading.
   *
   * Changing this prop after the component has mounted will not result in a camera change.
   *
   * This is similar to the `initialValue` prop of a text input.
   */
  initialCamera: CameraShape,

  /**
   * A Boolean indicating whether to use liteMode for android
   * Default value is `false`
   *
   * @platform android
   */
  liteMode: PropTypes.bool,

  /**
   * (Google Maps only)
   *
   * Padding that is used by the Google Map View to position
   * the camera, legal labels and buttons
   *
   */
  mapPadding: EdgeInsetsPropType,

  /**
   * (Google Maps only, iOS)
   *
   * Whether the safe area padding is added to the Google Map View padding.
   * This affects where markers, compass, Google logo etc. are placed on the view.
   *
   */
  paddingAdjustmentBehavior: PropTypes.oneOf(['always', 'automatic', 'never']),

  /**
   * Maximum size of area that can be displayed.
   *
   * @platform ios
   */
  maxDelta: PropTypes.number,

  /**
   * Minimum size of area that can be displayed.
   *
   * @platform ios
   */
  minDelta: PropTypes.number,

  /**
   * Insets for the map's legal label, originally at bottom left of the map.
   * See `EdgeInsetsPropType.js` for more information.
   */
  legalLabelInsets: EdgeInsetsPropType,

  /**
   * Callback that is called once the map is fully loaded.
   */
  onMapReady: PropTypes.func,

  /**
   * Callback that is called once all tiles have been loaded
   * (or failed permanently) and labels have been rendered.
   */
  onMapLoaded: PropTypes.func,

  /**
   * Callback that is called once the kml is fully loaded.
   */
  onKmlReady: PropTypes.func,

  /**
   * Callback that is called continuously when the user is dragging the map.
   */
  onRegionChange: PropTypes.func,

  /**
   * Callback that is called once, when the user is done moving the map.
   */
  onRegionChangeComplete: PropTypes.func,

  /**
   * Callback that is called when user taps on the map.
   */
  onPress: PropTypes.func,

  /**
   * Callback that is called when user double taps on the map.
   */
  onDoublePress: PropTypes.func,

  /**
   * Callback that is called when user makes a "long press" somewhere on the map.
   */
  onLongPress: PropTypes.func,

  /**
   * Callback that is called when the underlying map figures our users current location.
   */
  onUserLocationChange: PropTypes.func,

  /**
   * Callback that is called when user makes a "drag" somewhere on the map
   */
  onPanDrag: PropTypes.func,

  /**
   * Callback that is called when user click on a POI
   */
  onPoiClick: PropTypes.func,

  /**
   * Callback that is called when a marker on the map is tapped by the user.
   */
  onMarkerPress: PropTypes.func,

  /**
   * Callback that is called when a marker on the map becomes selected. This will be called when
   * the callout for that marker is about to be shown.
   *
   * @platform ios
   */
  onMarkerSelect: PropTypes.func,

  /**
   * Callback that is called when a marker on the map becomes deselected. This will be called when
   * the callout for that marker is about to be hidden.
   *
   * @platform ios
   */
  onMarkerDeselect: PropTypes.func,

  /**
   * Callback that is called when a callout is tapped by the user.
   */
  onCalloutPress: PropTypes.func,

  /**
   * Callback that is called when the user initiates a drag on a marker (if it is draggable)
   */
  onMarkerDragStart: PropTypes.func,

  /**
   * Callback called continuously as a marker is dragged
   */
  onMarkerDrag: PropTypes.func,

  /**
   * Callback that is called when a drag on a marker finishes. This is usually the point you
   * will want to setState on the marker's coordinate again
   */
  onMarkerDragEnd: PropTypes.func,

  /**
   * Minimum zoom value for the map, must be between 0 and 20
   */
  minZoomLevel: PropTypes.number,

  /**
   * Maximum zoom value for the map, must be between 0 and 20
   */
  maxZoomLevel: PropTypes.number,

  /**
   * Url KML Source
   */
  kmlSrc: PropTypes.string,

  /**
   * Offset Point x y for compass location.
   *
   * @platform ios
   */
  compassOffset: PointPropType,

  /**
   * Callback that is called when a level is activated on a indoor building.
   */
  onIndoorLevelActivated: PropTypes.func,

  /**
   * Callback that is called when a Building is focused.
   */
  onIndoorBuildingFocused: PropTypes.func,

  /**
   * Sets the tint color of the map. (Changes the color of the position indicator) Defaults to system blue.
   *
   * @platform ios
   */
  tintColor: ColorPropType,
};

export const enableLatestRenderer = () => {
  if (Platform.OS !== 'android') {
    return;
  }
  return NativeModules.AirMapModule.enableLatestRenderer();
};

export const ProviderPropType = PropTypes.oneOf(
  Object.values(ProviderConstants)
);

type State = {
  isReady: boolean;
  region?: Region;
  initialRegion?: Region;
};

class MapView extends React.Component<MapViewProps, State> {
  map: (Component<unknown, {}, any> & Readonly<NativeMethods>) | null = null;
  __lastRegion?: Region;
  __layoutCalled: boolean = false;

  static propTypes = propTypes;
  static viewConfig = viewConfig;
  static childContextTypes = childContextTypes;
  static MAP_TYPES = MAP_TYPES;

  static Marker = MapMarker;
  static Polyline = MapPolyline;
  static Polygon = MapPolygon;
  static Circle = MapCircle;
  static UrlTile = MapUrlTile;
  static MapWMSTile = MapWMSTile;
  static LocalTile = MapLocalTile;
  static Heatmap = MapHeatMap;
  static Overlay = MapOverlay;
  static Callout = MapCallout;
  static CalloutSubview = MapCalloutSubview;
  static ProviderPropType = ProviderPropType;

  static PROVIDER_GOOGLE = ProviderConstants.PROVIDER_GOOGLE;
  static PROVIDER_DEFAULT = ProviderConstants.PROVIDER_DEFAULT;

  static AnimatedRegion = AnimatedRegion;

  static Geojson = Geojson;
  static Animated: RNAnimated.AnimatedComponent<typeof MapView>;

  _commands = new MapCommands();

  constructor(props: MapViewProps) {
    super(props);

    this.state = {
      isReady: Platform.OS === 'ios',
    };

    this._onMapReady = this._onMapReady.bind(this);
    this._onMarkerPress = this._onMarkerPress.bind(this);
    this._onChange = this._onChange.bind(this);
    this._onLayout = this._onLayout.bind(this);
  }

  getChildContext() {
    return { provider: this.props.provider };
  }

  // TODO figure out if this is enough???
  UNSAFE_componentWillReceiveProps(props: MapViewProps) {
    const lastRegion = this.__lastRegion;
    const newRegion = props.region;
    if (!lastRegion || !newRegion) {
      return;
    }
    if (
      lastRegion.latitude !== newRegion.latitude ||
      lastRegion.longitude !== newRegion.longitude ||
      lastRegion.latitudeDelta !== newRegion.latitudeDelta ||
      lastRegion.longitudeDelta !== newRegion.longitudeDelta
    ) {
      // TODO ??????
      this.setState({ region: newRegion });
    }
  }

  _onMapReady() {
    const { region, initialRegion, onMapReady } = this.props;
    if (region) {
      this.setState({ region });
    } else if (initialRegion) {
      this.setState({ initialRegion });
    }

    this.setState({ isReady: true }, () => {
      if (onMapReady) {
        onMapReady();
      }
    });
  }

  _onLayout(e: LayoutChangeEvent) {
    const { layout } = e.nativeEvent;
    if (!layout.width || !layout.height) {
      return;
    }
    if (this.state.isReady && !this.__layoutCalled) {
      const { region, initialRegion } = this.props;
      if (region) {
        this.__layoutCalled = true;
        this.setState({ region });
      } else if (initialRegion) {
        this.__layoutCalled = true;
        this.setState({ initialRegion });
      }
    }
    if (this.props.onLayout) {
      this.props.onLayout(e);
    }
  }

  _onMarkerPress(event: MapEvent<{ action: 'marker-press'; id: string }>) {
    if (this.props.onMarkerPress) {
      // TODO: figure out this mess
      // @ts-ignore
      this.props.onMarkerPress(event.nativeEvent);
    }
  }

  _onChange({
    nativeEvent,
  }: {
    nativeEvent: { region: Region; isGesture: boolean; continuous: boolean };
  }) {
    this.__lastRegion = nativeEvent.region;
    const isGesture = nativeEvent.isGesture;
    const details = { isGesture };

    if (nativeEvent.continuous) {
      if (this.props.onRegionChange) {
        this.props.onRegionChange(nativeEvent.region, details);
      }
    } else if (this.props.onRegionChangeComplete) {
      this.props.onRegionChangeComplete(nativeEvent.region, details);
    }
  }

  getCamera() {
    if (Platform.OS === 'android') {
      return NativeModules.AirMapModule.getCamera(this._getHandle());
    } else if (Platform.OS === 'ios') {
      return this._getCommands().getCamera(this.map);
    }
    return Promise.reject('getCamera not supported on this platform');
  }

  setCamera(camera: Camera) {
    this._getCommands().setCamera(this.map, camera);
  }

  animateCamera(camera: Camera, opts?: { duration?: number }) {
    this._getCommands().animateCamera(
      this.map,
      camera,
      opts ? opts.duration : 500
    );
  }

  animateToNavigation(
    location: LatLng,
    bearing: number,
    angle: number,
    duration?: number
  ) {
    console.warn(
      'animateToNavigation() is deprecated, use animateCamera() instead'
    );
    this._getCommands().animateToNavigation(
      this.map,
      location,
      bearing,
      angle,
      duration || 500
    );
  }

  animateToRegion(region: Region, duration?: number) {
    this._getCommands().animateToRegion(this.map, region, duration || 500);
  }

  animateToCoordinate(latLng: LatLng, duration?: number) {
    console.warn(
      'animateToCoordinate() is deprecated, use animateCamera() instead'
    );
    this._getCommands().animateToCoordinate(this.map, latLng, duration || 500);
  }

  animateToBearing(bearing: number, duration?: number) {
    console.warn(
      'animateToBearing() is deprecated, use animateCamera() instead'
    );
    this._getCommands().animateToBearing(this.map, bearing, duration || 500);
  }

  animateToViewingAngle(angle: number, duration?: number) {
    console.warn(
      'animateToViewingAngle() is deprecated, use animateCamera() instead'
    );
    this._getCommands().animateToViewingAngle(this.map, angle, duration || 500);
  }

  fitToElements(
    options: {
      edgePadding?: EdgePadding;
      animated?: boolean;
    } = {}
  ) {
    const {
      edgePadding = { top: 0, right: 0, bottom: 0, left: 0 },
      animated = true,
    } = options;

    this._getCommands().fitToElements(this.map, edgePadding, animated);
  }

  fitToSuppliedMarkers(
    markers: string[],
    options: { edgePadding?: EdgePadding; animated?: boolean }
  ) {
    const {
      edgePadding = { top: 0, right: 0, bottom: 0, left: 0 },
      animated = true,
    } = options;

    this._getCommands().fitToSuppliedMarkers(
      this.map,
      markers,
      edgePadding,
      animated
    );
  }

  fitToCoordinates(
    coordinates: Coordinate[] = [],
    options: { edgePadding?: EdgePadding; animated?: boolean }
  ) {
    const {
      edgePadding = { top: 0, right: 0, bottom: 0, left: 0 },
      animated = true,
    } = options;

    this._getCommands().fitToCoordinates(
      this.map,
      coordinates,
      edgePadding,
      animated
    );
  }

  /**s
   * Get visible boudaries
   *
   * @return Promise Promise with the bounding box ({ northEast: <LatLng>, southWest: <LatLng> })
   */
  async getMapBoundaries() {
    if (Platform.OS === 'android') {
      return await NativeModules.AirMapModule.getMapBoundaries(
        this._getHandle()
      );
    } else if (Platform.OS === 'ios') {
      return await this._getCommands().getMapBoundaries(this.map);
    }
    return Promise.reject('getMapBoundaries not supported on this platform');
  }

  setMapBoundaries(northEast: Coordinate, southWest: Coordinate) {
    this._getCommands().setMapBoundaries(this.map, northEast, southWest);
  }

  setIndoorActiveLevelIndex(activeLevelIndex: number) {
    this._getCommands().setIndoorActiveLevelIndex(this.map, activeLevelIndex);
  }

  /**
   * Takes a snapshot of the map and saves it to a picture
   * file or returns the image as a base64 encoded string.
   *
   * @param config Configuration options
   * @param [config.width] Width of the rendered map-view (when omitted actual view width is used).
   * @param [config.height] Height of the rendered map-view (when omitted actual height is used).
   * @param [config.region] Region to render (Only supported on iOS).
   * @param [config.format] Encoding format ('png', 'jpg') (default: 'png').
   * @param [config.quality] Compression quality (only used for jpg) (default: 1.0).
   * @param [config.result] Result format ('file', 'base64') (default: 'file').
   *
   * @return Promise Promise with either the file-uri or base64 encoded string
   */
  takeSnapshot(args: SnapshotOptions) {
    // For the time being we support the legacy API on iOS.
    // This will be removed in a future release and only the
    // new Promise style API shall be supported.
    if (Platform.OS === 'ios' && arguments.length === 4) {
      console.warn(
        'Old takeSnapshot API has been deprecated; will be removed in the near future'
      );
      const width = arguments[0];
      const height = arguments[1];
      const region = arguments[2];
      const callback = arguments[3];
      this._getCommands().takeSnapshot(
        this.map,
        width || 0,
        height || 0,
        region || {},
        'png',
        1,
        'legacy',
        callback
      );
      return undefined;
    }

    // Sanitize inputs
    const config = {
      width: args.width || 0,
      height: args.height || 0,
      region: args.region || {},
      format: args.format || 'png',
      quality: args.quality || 1.0,
      result: args.result || 'file',
    };
    if (config.format !== 'png' && config.format !== 'jpg') {
      throw new Error('Invalid format specified');
    }
    if (config.result !== 'file' && config.result !== 'base64') {
      throw new Error('Invalid result specified');
    }

    // Call native function
    if (Platform.OS === 'android') {
      return NativeModules.AirMapModule.takeSnapshot(this._getHandle(), config);
    } else if (Platform.OS === 'ios') {
      return new Promise((resolve, reject) => {
        this._getCommands().takeSnapshot(
          this.map,
          config.width,
          config.height,
          config.region,
          config.format,
          config.quality,
          config.result,
          (err: any, snapshot: string) => {
            if (err) {
              reject(err);
            } else {
              resolve(snapshot);
            }
          }
        );
      });
    }
    return Promise.reject('takeSnapshot not supported on this platform');
  }

  /**
   * Convert a coordinate to address by using default Geocoder
   *
   * @param coordinate Coordinate
   * @param [coordinate.latitude] Latitude
   * @param [coordinate.longitude] Longitude
   *
   * @return Promise with return type Address
   */
  addressForCoordinate(coordinate: Coordinate) {
    if (Platform.OS === 'android') {
      return NativeModules.AirMapModule.getAddressFromCoordinates(
        this._getHandle(),
        coordinate
      );
    } else if (Platform.OS === 'ios') {
      return this._getCommands().getAddressFromCoordinates(
        this.map,
        coordinate
      );
    }
    return Promise.reject('getAddress not supported on this platform');
  }

  /**
   * Convert a map coordinate to user-space point
   *
   * @param coordinate Coordinate
   * @param [coordinate.latitude] Latitude
   * @param [coordinate.longitude] Longitude
   *
   * @return Promise Promise with the point ({ x: Number, y: Number })
   */
  pointForCoordinate(coordinate: Coordinate) {
    if (Platform.OS === 'android') {
      return NativeModules.AirMapModule.pointForCoordinate(
        this._getHandle(),
        coordinate
      );
    } else if (Platform.OS === 'ios') {
      return this._getCommands().pointForCoordinate(this.map, coordinate);
    }
    return Promise.reject('pointForCoordinate not supported on this platform');
  }

  /**
   * Convert a user-space point to a map coordinate
   *
   * @param point Point
   * @param [point.x] X
   * @param [point.x] Y
   *
   * @return Promise Promise with the coordinate ({ latitude: Number, longitude: Number })
   */
  coordinateForPoint(point: Point) {
    if (Platform.OS === 'android') {
      return NativeModules.AirMapModule.coordinateForPoint(
        this._getHandle(),
        point
      );
    } else if (Platform.OS === 'ios') {
      return this._getCommands().coordinateForPoint(this.map, point);
    }
    return Promise.reject('coordinateForPoint not supported on this platform');
  }

  /**
   * Get markers' centers and frames in user-space coordinates
   *
   * @param onlyVisible boolean true to include only visible markers, false to include all
   *
   * @return Promise Promise with { <identifier>: { point: Point, frame: Frame } }
   */
  getMarkersFrames(onlyVisible = false) {
    if (Platform.OS === 'ios') {
      return this._getCommands().getMarkersFrames(this.map, onlyVisible);
    }
    return Promise.reject('getMarkersFrames not supported on this platform');
  }

  /**
   * Get bounding box from region
   *
   * @param region Region
   *
   * @return Object Object bounding box ({ northEast: <LatLng>, southWest: <LatLng> })
   */
  boundingBoxForRegion(region: Region) {
    return {
      northEast: {
        latitude: region.latitude + region.latitudeDelta / 2,
        longitude: region.longitude + region.longitudeDelta / 2,
      },
      southWest: {
        latitude: region.latitude - region.latitudeDelta / 2,
        longitude: region.longitude - region.longitudeDelta / 2,
      },
    };
  }
  _getHandle() {
    throw new Error('Needed for android, need to migrate fom this');
  }

  _uiManagerCommand(name: string) {
    const provider = this.getProvider();
    const UIManager = NativeModules.UIManager;
    const componentName = getAirMapName(provider);

    if (!UIManager.getViewManagerConfig) {
      // RN < 0.58
      return UIManager[componentName].Commands[name];
    }

    // RN >= 0.58
    return UIManager.getViewManagerConfig(componentName).Commands[name];
  }

  _getCommands(): MapCommands {
    // TODO return proper commands according to provider
    return this._commands;
  }

  getProvider(): ProviderConstants.Provider {
    let provider: ProviderConstants.Provider | undefined;
    if (provider == null) {
      return 'default';
    } else if (provider === 'google') {
      return 'google';
    }
    return 'default';
  }

  render() {
    let props: AIRMapProps;
    let provider = this.getProvider();

    if (this.state.isReady) {
      props = {
        region: undefined,
        initialRegion: undefined,
        onMarkerPress: this._onMarkerPress,
        onChange: this._onChange,
        onMapReady: this._onMapReady,
        onLayout: this._onLayout,
        ...this.props,
      };
      if (
        Platform.OS === 'ios' &&
        props.mapType &&
        provider === ProviderConstants.PROVIDER_DEFAULT &&
        GOOGLE_MAPS_ONLY_TYPES.includes(props.mapType)
      ) {
        props.mapType = 'standard';
      }
      if (props.onPanDrag) {
        props.handlePanDrag = !!props.onPanDrag;
      }
    } else {
      props = {
        style: this.props.style,
        region: undefined,
        initialRegion: this.props.initialRegion || undefined,
        onMarkerPress: this._onMarkerPress,
        onChange: this._onChange,
        onMapReady: this._onMapReady,
        onLayout: this._onLayout,
      };
    }

    if (props.customMapStyle) {
      props.customMapStyleString = JSON.stringify(props.customMapStyle);
    }

    props.region = this.state.region;
    props.initialRegion = this.state.initialRegion;
    props.onCommandResponse = this._commands.onCommandResponse;

    if (Platform.OS === 'android' && this.props.liteMode && AIRMapLite) {
      return (
        <AIRMapLite
          ref={(ref) => {
            this.map = ref;
          }}
          {...props}
        />
      );
    }

    const AIRMapComponent = getAirMapComponent(provider);

    return (
      <AIRMapComponent
        ref={(ref) => {
          this.map = ref;
        }}
        {...props}
      />
    );
  }
}

MapView.Animated = RNAnimated.createAnimatedComponent(MapView);

export const Animated = MapView.Animated;

/**
 * TODO:
 * All of these properties on MapView are unecessary since they can be imported
 * individually with the es6 exports in index.js. Removing them is a breaking change,
 * but potentially allows for better dead code elimination since references are not
 * kept to components which are never used.
 */

// TODO: since nativeComponent is taking only one param now,
/*
  Check if these params need to bee passed in some other way
    extraConfig = nativeOnly: {
      onChange: true,
      onMapReady: true,
      onKmlReady: true,
      handlePanDrag: true,
    },
*/

const getGoogleMaps = () =>
  googleMapIsInstalled
    ? AIRGoogleMap
    : createNotSupportedComponent(
        'react-native-maps: AirGoogleMaps dir must be added to your xCode project to support GoogleMaps on iOS.'
      );

const airMapNativeComponent = AIRMap;
const airMaps = {
  default: airMapNativeComponent,
  google: Platform.OS === 'android' ? airMapNativeComponent : getGoogleMaps(),
};

const getAirMapComponent = (provider: ProviderConstants.Provider) =>
  airMaps[provider || 'default'];

let AIRMapLite: HostComponent<AIRMapProps> | undefined;
if (!NativeModules.UIManager.getViewManagerConfig) {
  // RN < 0.58
  AIRMapLite =
    NativeModules.UIManager.AIRMapLite && requireNativeComponent('AIRMapLite');
} else {
  // RN >= 0.58
  AIRMapLite =
    NativeModules.UIManager.getViewManagerConfig('AIRMapLite') && AIRMapLite;
}

export default MapView;
