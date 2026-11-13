/// Demo builds pass --dart-define=SCHOOLDESK_DEMO=true.
/// Production builds leave this false.
const demoEdition = bool.fromEnvironment('SCHOOLDESK_DEMO');

const localPort = demoEdition ? 8742 : 8741;
const localDataFolder = demoEdition ? 'SchoolDesk Demo' : 'SchoolDesk';
