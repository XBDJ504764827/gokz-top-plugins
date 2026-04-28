#if defined _gokz_top_included_
#endinput
#endif
#define _gokz_top_included_

/**
 * Posts a raw JSON payload to a gokz-top API path.
 *
 * @param path		API path beginning with '/', for example "/v1/player-sessions/connect".
 * @param body		JSON request body.
 * @return			True if the request was accepted by the local HTTP layer.
 */
native bool GOKZTop_PostJSON(const char[] path, const char[] body);

/**
 * Posts a player-session event to the gokz-top API.
 *
 * @param event		Session event name: "connect", "heartbeat", or "disconnect".
 * @param body		JSON request body for the event.
 * @return			True if the request was accepted by the local HTTP layer.
 */
native bool GOKZTop_PostSessionEvent(const char[] event, const char[] body);

public SharedPlugin __pl_gokz_top_core =
{
	name = "gokz-top-core",
	file = "gokz-top-core.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_gokz_top_core_SetNTVOptional()
{
	MarkNativeAsOptional("GOKZTop_PostJSON");
	MarkNativeAsOptional("GOKZTop_PostSessionEvent");
}
#endif
