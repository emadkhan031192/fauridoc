/// App-wide constants.
///
/// Google Maps API key: the map tab only renders the real GoogleMap widget
/// when this is replaced with a real key (and the same key is placed in
/// android/app/src/main/AndroidManifest.xml). Until then the Map tab shows
/// a friendly setup card. See SETUP.md.
const String googleMapsApiKey = 'YOUR_MAPS_API_KEY';

bool get mapsConfigured => googleMapsApiKey != 'YOUR_MAPS_API_KEY';

/// Support email for the Help & feedback screen.
const String supportEmail = 'support@fauridoc.app';
