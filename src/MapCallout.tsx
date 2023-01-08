import PropTypes from 'prop-types';
import React from 'react';
import { StyleSheet } from 'react-native';
import { ViewPropTypes } from 'deprecated-react-native-prop-types';
import decorateMapComponent, {
  DecoratedComponent,
  SUPPORTED,
  USES_DEFAULT_IMPLEMENTATION,
} from './decorateMapComponent';

const propTypes = {
  ...ViewPropTypes,
  tooltip: PropTypes.bool,
  onPress: PropTypes.func,
  alphaHitTest: PropTypes.bool,
};

const defaultProps = {
  tooltip: false,
  alphaHitTest: false,
};

class MapCallout extends DecoratedComponent {
  static propTypes = propTypes;
  static defaultProps = defaultProps;
  render() {
    const AIRMapCallout = this.getAirComponent();
    return (
      <AIRMapCallout
        {...this.props}
        style={[styles.callout, this.props.style]}
      />
    );
  }
}

const styles = StyleSheet.create({
  callout: {
    position: 'absolute',
  },
});

export default decorateMapComponent(MapCallout, {
  componentType: 'Callout',
  providers: {
    google: {
      ios: SUPPORTED,
      android: USES_DEFAULT_IMPLEMENTATION,
    },
  },
});
