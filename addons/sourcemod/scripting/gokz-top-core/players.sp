#define GOKZ_TOP_HEARTBEAT_INTERVAL 15.0
#define GOKZ_TOP_SESSION_ID_LENGTH UUID_STRING_LENGTH
#define GOKZ_TOP_TIMESTAMP_LENGTH 32
#define GOKZ_TOP_STEAMID64_LENGTH 32
#define GOKZ_TOP_IP_LENGTH 64
#define GOKZ_TOP_LANGUAGE_CODE_LENGTH 16
#define GOKZ_TOP_SESSION_BODY_LENGTH 1024
#define GOKZ_TOP_KICK_MESSAGE_LENGTH 512
#define GOKZ_TOP_LANGUAGE_QUERY_FALLBACK 1.0

bool gB_PlayersLateLoaded;
bool gB_SessionActive[MAXPLAYERS + 1];
bool gB_ConnectSent[MAXPLAYERS + 1];
char gC_SessionID[MAXPLAYERS + 1][GOKZ_TOP_SESSION_ID_LENGTH];
char gC_PlayerSteamID64[MAXPLAYERS + 1][GOKZ_TOP_STEAMID64_LENGTH];
char gC_PlayerIP[MAXPLAYERS + 1][GOKZ_TOP_IP_LENGTH];
char gC_ConnectedAt[MAXPLAYERS + 1][GOKZ_TOP_TIMESTAMP_LENGTH];
char gC_ClientLanguage[MAXPLAYERS + 1][GOKZ_TOP_LANGUAGE_CODE_LENGTH];
char gC_MapName[PLATFORM_MAX_PATH];
Handle gH_HeartbeatTimer;

#include "gokz-top-core/players/session.sp"
#include "gokz-top-core/players/ban_response.sp"
#include "gokz-top-core/players/helpers.sp"

void GOKZTopPlayers_AskPluginLoad2(bool late)
{
	gB_PlayersLateLoaded = late;
}

void GOKZTopPlayers_OnPluginStart()
{
	GetCurrentMap(gC_MapName, sizeof(gC_MapName));
	gH_HeartbeatTimer = CreateTimer(GOKZ_TOP_HEARTBEAT_INTERVAL, Timer_SendHeartbeats, _, TIMER_REPEAT);
}

void GOKZTopPlayers_OnAllPluginsLoaded()
{
	if (!gB_PlayersLateLoaded)
	{
		return;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientReadyForSession(client))
		{
			StartSession(client);
		}
	}
}

void GOKZTopPlayers_OnPluginEnd()
{
	if (gH_HeartbeatTimer != null)
	{
		delete gH_HeartbeatTimer;
		gH_HeartbeatTimer = null;
	}

	for (int client = 1; client <= MaxClients; client++)
	{
		if (gB_SessionActive[client])
		{
			EndSession(client);
		}
	}
}

void GOKZTopPlayers_OnMapStart()
{
	GetCurrentMap(gC_MapName, sizeof(gC_MapName));
}

void GOKZTopPlayers_OnMapEnd()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gB_SessionActive[client])
		{
			EndSession(client);
		}
	}
}

void GOKZTopPlayers_OnClientPostAdminCheck(int client)
{
	if (!IsClientReadyForSession(client))
	{
		return;
	}

	StartSession(client);
}

void GOKZTopPlayers_OnClientPutInServer(int client)
{
	if (!IsClientReadyForSession(client))
	{
		return;
	}

	StartSession(client);
}

void GOKZTopPlayers_OnClientDisconnect(int client)
{
	if (!gB_SessionActive[client])
	{
		return;
	}

	EndSession(client);
}

void GOKZTopPlayers_OnSessionEventPosted(const char[] event, const char[] responseBody)
{
	if (!StrEqual(event, "connect"))
	{
		return;
	}

	HandleConnectResponse(responseBody);
}
