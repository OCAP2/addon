#include "script_component.hpp"

PREP(init);

PREP(updateTime);

PREP(startRecording);
PREP(stopRecording);
PREP(autoRestartMonitor);
PREP(getAutoStartPlayerCount);
PREP(captureLoop);
PREP(isKindOfApc);
PREP(getClass);
PREP(getUnitType);

PREP(addEventMission);
PREP(handleCustomEvent);
PREP(handleMarkers);
PREP(addUnitEventHandlers);

PREP(eh_connected);
PREP(eh_disconnected);
PREP(recordPlayerConnectionEvent);
PREP(flushPlayerConnectionEvents);
PREP(eh_onUserAdminStateChanged);
PREP(eh_onUserSelectedPlayer);
PREP(adminUIcontrol);

PREP(eh_firedMan);
PREP(eh_fired_server);
PREP(eh_fired_client);
PREP(eh_fired_clientBullet);
PREP(eh_fired_clientProjectile);
PREP(eh_killed);
PREP(getInstigator);
PREP(getEventWeaponText);
PREP(getWeaponDisplayData);
PREP(getConfigDisplayName);

PREP(entityMonitors);
PREP(telemetryLoop);

PREP(aceExplosives);
PREP(recordExplosion);
PREP(trackTrenches);
PREP(trackServicing);
PREP(trackConstructions);
PREP(submitStaticWeapon);

PREP(addEventIntegrations);
PREP(getStaticObjects);
PREP(trackSectors);
PREP(handleChatMessage);
PREP(radioEvent);

PREP(installPlayerTrackingClients);
PREP(submitPlayerSnapshot);
PREP(diffSnapshotPayload);
PREP(encodeJSON);
PREP(ensureZeusEntity);
PREP(trackZeus);
PREP(submitZeusCamera);
PREP(submitZeusPing);
PREP(submitZeusModule);
PREP(recordRadioPropagation);
PREP(recordWeather);

PREP(exportData);

PREP(setFocusStart);
PREP(setFocusEnd);
