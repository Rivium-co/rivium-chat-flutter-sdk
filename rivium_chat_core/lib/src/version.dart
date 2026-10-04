/// Name this SDK reports to the Rivium backend.
const String riviumChatSdkName = 'flutter';

/// Version of the rivium_chat package.
///
/// Must match `version` in pubspec.yaml (enforced by a unit test).
const String riviumChatSdkVersion = '0.1.5';

/// Header that tells the API which SDK and version made a request.
const String riviumChatSdkHeader = 'X-Rivium-SDK';

/// Its value: `flutter/<version>`.
const String riviumChatSdkHeaderValue = '$riviumChatSdkName/$riviumChatSdkVersion';
