#if defined __LEFT4FRAMEWORK_INCLUDED
	#endinput
#endif
#define __LEFT4FRAMEWORK_INCLUDED

// This include is needed to support the compile of plugins on both left4downtown and left4dhooks

#define LEFT4DHOOKS 1
#define LEFT4DOWNTOWN 2

#define FRAMEWORK_VERSION LEFT4DHOOKS

#if FRAMEWORK_VERSION == LEFT4DHOOKS
	#if !defined LEFT4FRAMEWORK_GAMEDATA_ONLY
		#include <left4dhooks>
	#endif

	#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"
	#define LEFT4DIRECT_GAMEDATA LEFT4FRAMEWORK_GAMEDATA
#else
	#if !defined LEFT4FRAMEWORK_GAMEDATA_ONLY
		#if defined LEFT4FRAMEWORK_INCLUDE
			#include <left4downtown>
		#endif

		#if defined L4D2_DIRECT_INCLUDE
			#include <l4d2_direct>
		#endif
	#endif

	#define LEFT4FRAMEWORK_GAMEDATA "left4downtown.l4d2"
	#define LEFT4DIRECT_GAMEDATA "l4d2_direct"
#endif
