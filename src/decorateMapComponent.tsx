import PropTypes from 'prop-types';
import React from 'react';
import {
  requireNativeComponent,
  NativeModules,
  Platform,
  HostComponent,
} from 'react-native';
import {
  Provider,
  PROVIDER_DEFAULT,
  PROVIDER_GOOGLE,
} from './ProviderConstants';

export const SUPPORTED = 'SUPPORTED';
export const USES_DEFAULT_IMPLEMENTATION = 'USES_DEFAULT_IMPLEMENTATION';
export const NOT_SUPPORTED = 'NOT_SUPPORTED';

export function getAirMapName(provider: Provider) {
  if (Platform.OS === 'android') {
    return 'AIRMap';
  }
  if (provider === PROVIDER_GOOGLE) {
    return 'AIRGoogleMap';
  }
  return 'AIRMap';
}

function getAirComponentName(provider: Provider, component: string) {
  return `${getAirMapName(provider)}${component}`;
}

export const contextTypes = {
  provider: PropTypes.string,
};

export const createNotSupportedComponent = (
  message: string
): HostComponent<unknown> => {
  class FakeHostComponent<P> extends React.Component {
    constructor(props: P) {
      super(props);
      console.error(message);
    }
  }
  return FakeHostComponent as HostComponent<unknown>;
};

function getViewManagerConfig(viewManagerName: string) {
  const UIManager = NativeModules.UIManager;
  if (!UIManager.getViewManagerConfig) {
    // RN < 0.58
    return UIManager[viewManagerName];
  }
  // RN >= 0.58
  return UIManager.getViewManagerConfig(viewManagerName);
}

export const googleMapIsInstalled = !!getViewManagerConfig(
  getAirMapName(PROVIDER_GOOGLE)
);

type ComponentType =
  | 'Circle'
  | 'HeatMap'
  | 'Callout'
  | 'Overlay'
  | 'WMSTile'
  | 'Marker'
  | 'Polygon'
  | 'PolyLine'
  | 'LocalTitle'
  | 'CalloutSubview'
  | 'UrlTile';

export default function decorateMapComponent<T>(
  Component: React.ComponentType<T>,
  { componentType, providers }: { componentType: ComponentType; providers: any }
) {
  const components: { [key: string]: HostComponent<unknown> } = {};

  const getDefaultComponent = () =>
    requireNativeComponent(getAirComponentName('default', componentType));

  Component.contextTypes = contextTypes;

  Component.prototype.getAirComponent =
    function getAirComponent(): HostComponent<unknown> {
      const _provider = this.context.provider as Provider;
      const provider = _provider || PROVIDER_DEFAULT;
      if (components[provider]) {
        return components[provider];
      }

      if (provider === PROVIDER_DEFAULT) {
        components[PROVIDER_DEFAULT] = getDefaultComponent();
        return components[PROVIDER_DEFAULT];
      }

      const providerInfo = providers[provider];
      const platformSupport = providerInfo[Platform.OS];
      const componentName = getAirComponentName(provider, componentType);
      if (platformSupport === NOT_SUPPORTED) {
        components[provider] = createNotSupportedComponent(
          `react-native-maps: ${componentName} is not supported on ${Platform.OS}`
        ) as any;
      } else if (platformSupport === SUPPORTED) {
        if (
          provider !== PROVIDER_GOOGLE ||
          (Platform.OS === 'ios' && googleMapIsInstalled)
        ) {
          components[provider] = requireNativeComponent(componentName);
        }
      } else {
        // (platformSupport === USES_DEFAULT_IMPLEMENTATION)
        if (!components[PROVIDER_DEFAULT]) {
          components[PROVIDER_DEFAULT] = getDefaultComponent();
        }
        components[provider] = components[PROVIDER_DEFAULT];
      }

      return components[provider];
    };

  Component.prototype.getUIManagerCommand = function getUIManagerCommand(
    name: string
  ) {
    const _provider = this.context.provider as Provider;
    const componentName = getAirComponentName(_provider, componentType);
    return getViewManagerConfig(componentName).Commands[name];
  };

  Component.prototype.getMapManagerCommand = function getMapManagerCommand(
    name: string
  ) {
    const _provider = this.context.provider as Provider;
    const airComponentName = `${getAirComponentName(
      _provider,
      componentType
    )}Manager`;
    return NativeModules[airComponentName][name];
  };

  return Component;
}

export class DecoratedComponent<
  P = {},
  S = {},
  SS = any
> extends React.Component<P, S, SS> {
  getAirComponent(): HostComponent<unknown> {
    throw new Error('You have not called decorator on this component');
  }
  getUIManagerCommand(_name: string): any {
    throw new Error('You have not called decorator on this component');
  }
  getMapManagerCommand(_name: string): any {
    throw new Error('You have not called decorator on this component');
  }
}
