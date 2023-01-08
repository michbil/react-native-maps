// @ts-ignore
import codegenNativeCommands from 'react-native/Libraries/Utilities/codegenNativeCommands';
import { requireNativeComponent } from 'react-native';
import { MapViewProps, Region } from 'react-native-maps';

const AIRGoogleMap = requireNativeComponent<MapViewProps>('AIRGoogleMap');

interface NativeCommands {
  moveToRegion: (region: Region, duration: number) => void;
}

export const Commands: NativeCommands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['moveToRegion'],
});

export default AIRGoogleMap;
