// The current version of OCAP.
// HEMTT overrides these from git tags during release builds.
#ifndef OCAP_SCRIPT_VERSION_HPP
#define OCAP_SCRIPT_VERSION_HPP

#ifndef MAJOR
#define MAJOR 0
#define MINOR 0
#define PATCH 0
#endif

#define VERSION MAJOR.MINOR
#define VERSION_STR MAJOR.MINOR.PATCH
#define VERSION_AR MAJOR,MINOR,PATCH

#endif
