import { Animated } from 'react-native';
import { Region } from 'react-native-maps';

const AnimatedWithChildren = Object.getPrototypeOf(Animated.ValueXY);
if (__DEV__) {
  if (AnimatedWithChildren.name !== 'AnimatedWithChildren') {
    console.error(
      'AnimatedRegion could not obtain AnimatedWithChildren base class'
    );
  }
}

const configTypes = [
  'latitude',
  'longitude',
  'latitudeDelta',
  'longitudeDelta',
];

const defaultValues = {
  // probably want to come up with better defaults
  latitude: 0,
  longitude: 0,
  latitudeDelta: 0,
  longitudeDelta: 0,
};

let _uniqueId = 1;

const getAnimatedValue = (
  valueIn: Animated.Value | number,
  fallback: number
) => {
  if (valueIn instanceof Animated.Value) {
    return valueIn;
  } else if (typeof valueIn === 'number') {
    return new Animated.Value(valueIn);
  }
  return new Animated.Value(fallback);
};

export default class AnimatedMapRegion extends AnimatedWithChildren {
  latitude: Animated.Value;
  longitude: Animated.Value;
  latitudeDelta: Animated.Value;
  longitudeDelta: Animated.Value;

  // @ts-ignore
  constructor(valueIn: Region = {}) {
    super();
    this.latitude = getAnimatedValue(valueIn.latitude, defaultValues.latitude);
    this.longitude = getAnimatedValue(
      valueIn.longitude,
      defaultValues.longitude
    );
    this.latitudeDelta = getAnimatedValue(
      valueIn.latitudeDelta,
      defaultValues.latitudeDelta
    );
    this.longitudeDelta = getAnimatedValue(
      valueIn.longitudeDelta,
      defaultValues.longitudeDelta
    );
    this._regionListeners = {};
  }

  setValue(value: number) {
    // @ts-ignore
    this.latitude._value = value.latitude;
    // @ts-ignore
    this.longitude._value = value.longitude;
    // @ts-ignore
    this.latitudeDelta._value = value.latitudeDelta;
    // @ts-ignore
    this.longitudeDelta._value = value.longitudeDelta;
  }

  setOffset(offset: Region) {
    this.latitude.setOffset(offset.latitude);
    this.longitude.setOffset(offset.longitude);
    this.latitudeDelta.setOffset(offset.latitudeDelta);
    this.longitudeDelta.setOffset(offset.longitudeDelta);
  }

  flattenOffset() {
    this.latitude.flattenOffset();
    this.longitude.flattenOffset();
    this.latitudeDelta.flattenOffset();
    this.longitudeDelta.flattenOffset();
  }

  __getValue() {
    return {
      // @ts-ignore
      latitude: this.latitude.__getValue(),
      // @ts-ignore
      longitude: this.longitude.__getValue(),
      // @ts-ignore
      latitudeDelta: this.latitudeDelta.__getValue(),
      // @ts-ignore
      longitudeDelta: this.longitudeDelta.__getValue(),
    };
  }

  __attach() {
    // @ts-ignore
    this.latitude.__addChild(this);
    // @ts-ignore
    this.longitude.__addChild(this);
    // @ts-ignore
    this.latitudeDelta.__addChild(this);
    // @ts-ignore
    this.longitudeDelta.__addChild(this);
  }

  __detach() {
    // @ts-ignore
    this.latitude.__removeChild(this);
    // @ts-ignore
    this.longitude.__removeChild(this);
    // @ts-ignore
    this.latitudeDelta.__removeChild(this);
    // @ts-ignore
    this.longitudeDelta.__removeChild(this);
  }

  stopAnimation(callback: () => void) {
    this.latitude.stopAnimation();
    this.longitude.stopAnimation();
    this.latitudeDelta.stopAnimation();
    this.longitudeDelta.stopAnimation();
    // @ts-ignore
    callback && callback(this.__getValue());
  }

  addListener(callback: () => void) {
    const id = String(_uniqueId++);
    // @ts-ignore
    const jointCallback = () => /*{value}*/ callback(this.__getValue());
    this._regionListeners[id] = {
      latitude: this.latitude.addListener(jointCallback),
      longitude: this.longitude.addListener(jointCallback),
      latitudeDelta: this.latitudeDelta.addListener(jointCallback),
      longitudeDelta: this.longitudeDelta.addListener(jointCallback),
    };
    return id;
  }

  removeListener(id: string) {
    this.latitude.removeListener(this._regionListeners[id].latitude);
    this.longitude.removeListener(this._regionListeners[id].longitude);
    this.latitudeDelta.removeListener(this._regionListeners[id].latitudeDelta);
    this.longitudeDelta.removeListener(
      this._regionListeners[id].longitudeDelta
    );
    delete this._regionListeners[id];
  }

  spring(config: Animated.TimingAnimationConfig) {
    const animations = [];
    for (const type of configTypes) {
      if (config.hasOwnProperty(type)) {
        animations.push(
          Animated.spring(this[type], {
            ...config,
            // @ts-ignore
            toValue: config[type],
            // may help to eliminate some dev warnings and perf issues
            useNativeDriver: !!config?.useNativeDriver,
          })
        );
      }
    }
    return Animated.parallel(animations);
  }

  timing(config: Animated.TimingAnimationConfig) {
    const animations = [];
    for (const type of configTypes) {
      if (config.hasOwnProperty(type)) {
        animations.push(
          Animated.timing(this[type], {
            ...config,
            // @ts-ignore
            toValue: config[type],
            // may help to eliminate some dev warnings and perf issues
            useNativeDriver: !!config?.useNativeDriver,
          })
        );
      }
    }
    return Animated.parallel(animations);
  }
}
