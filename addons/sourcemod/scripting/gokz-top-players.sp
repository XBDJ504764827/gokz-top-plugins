#include <sourcemod>
#include <sdktools>

#include <uuid>

#include <gokz/top>

#pragma newdecls required
#pragma semicolon 1

#define GOKZ_TOP_PLAYERS_VERSION "0.1.0"
#define GOKZ_TOP_HEARTBEAT_INTERVAL 15.0
#define GOKZ_TOP_SESSION_ID_LENGTH UUID_STRING_LENGTH
#define GOKZ_TOP_TIMESTAMP_LENGTH 32
#define GOKZ_TOP_STEAMID64_LENGTH 32
#define GOKZ_TOP_IP_LENGTH 64
#define GOKZ_TOP_SESSION_BODY_LENGTH 1024

public Plugin myinfo =
{
	name = "GOKZ Top Players",
	author = "OpenAI",
	description = "Player session tracking for gokz-top",
	version = GOKZ_TOP_PLAYERS_VERSION,
	url = "https://gokz.top"
};

bool gB_LateLoaded;
bool gB_SessionActive[MAXPLAYERS + 1];
char gC_SessionID[MAXPLAYERS + 1][GOKZ_TOP_SESSION_ID_LENGTH];
char gC_PlayerSteamID64[MAXPLAYERS + 1][GOKZ_TOP_STEAMID64_LENGTH];
char gC_PlayerIP[MAXPLAYERS + 1][GOKZ_TOP_IP_LENGTH];
char gC_ConnectedAt[MAXPLAYERS + 1][GOKZ_TOP_TIMESTAMP_LENGTH];
char gC_MapName[PLATFORM_MAX_PATH];
Handle gH_HeartbeatTimer;



// =====[ PLUGIN EVENTS ]=====

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	gB_LateLoaded = late;
	return APLRes_Success;
}

public void OnPluginStart()
{
	GetCurrentMap(gC_MapName, sizeof(gC_MapName));
	gH_HeartbeatTimer = CreateTimer(GOKZ_TOP_HEARTBEAT_INTERVAL, Timer_SendHeartbeats, _, TIMER_REPEAT);
}

public void OnAllPluginsLoaded()
{
	if (!gB_LateLoaded)
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

public void OnPluginEnd()
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

public void OnMapStart()
{
	GetCurrentMap(gC_MapName, sizeof(gC_MapName));
}

public void OnMapEnd()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gB_SessionActive[client])
		{
			EndSession(client);
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (!IsClientReadyForSession(client))
	{
		return;
	}

	StartSession(client);
}

public void OnClientDisconnect(int client)
{
	if (!gB_SessionActive[client])
	{
		return;
	}

	EndSession(client);
}



// =====[ SESSION LIFECYCLE ]=====

void StartSession(int client)
{
	if (gB_SessionActive[client])
	{
		return;
	}

	if (!GetClientAuthId(client, AuthId_SteamID64, gC_PlayerSteamID64[client], sizeof(gC_PlayerSteamID64[]), true))
	{
		return;
	}

	UUID_GenerateV7(gC_SessionID[client], sizeof(gC_SessionID[]));
	GetClientIPv4(client, gC_PlayerIP[client], sizeof(gC_PlayerIP[]));
	FormatLocalISOTime(gC_ConnectedAt[client], sizeof(gC_ConnectedAt[]));

	gB_SessionActive[client] = true;

	SendConnectEvent(client);
}

void EndSession(int client)
{
	char disconnectAt[GOKZ_TOP_TIMESTAMP_LENGTH];
	FormatLocalISOTime(disconnectAt, sizeof(disconnectAt));

	SendDisconnectEvent(client, disconnectAt);
	ClearSession(client);
}

void ClearSession(int client)
{
	gB_SessionActive[client] = false;
	gC_SessionID[client][0] = '\0';
	gC_PlayerSteamID64[client][0] = '\0';
	gC_PlayerIP[client][0] = '\0';
	gC_ConnectedAt[client][0] = '\0';
}

public Action Timer_SendHeartbeats(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!gB_SessionActive[client])
		{
			continue;
		}

		if (!IsClientInGame(client))
		{
			EndSession(client);
			continue;
		}

		SendHeartbeatEvent(client);
	}

	return Plugin_Continue;
}



// =====[ SESSION EVENTS ]=====

void SendConnectEvent(int client)
{
	char mapName[PLATFORM_MAX_PATH * 2];
	EscapeJSONString(gC_MapName, mapName, sizeof(mapName));

	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"player_steamid64\":\"%s\",\"connected_at\":\"%s\",\"ip_address\":\"%s\",\"map_name\":\"%s\"}",
		gC_SessionID[client],
		gC_PlayerSteamID64[client],
		gC_ConnectedAt[client],
		gC_PlayerIP[client],
		mapName);

	GOKZTop_PostSessionEvent("connect", payload);
}

void SendHeartbeatEvent(int client)
{
	char heartbeatAt[GOKZ_TOP_TIMESTAMP_LENGTH];
	FormatLocalISOTime(heartbeatAt, sizeof(heartbeatAt));

	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"heartbeat_at\":\"%s\"}",
		gC_SessionID[client],
		heartbeatAt);

	GOKZTop_PostSessionEvent("heartbeat", payload);
}

void SendDisconnectEvent(int client, const char[] disconnectAt)
{
	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"disconnect_at\":\"%s\"}",
		gC_SessionID[client],
		disconnectAt);

	GOKZTop_PostSessionEvent("disconnect", payload);
}



// =====[ HELPERS ]=====

bool IsClientReadyForSession(int client)
{
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& !IsFakeClient(client)
		&& IsClientAuthorized(client);
}

void GetClientIPv4(int client, char[] buffer, int maxLength)
{
	if (!GetClientIP(client, buffer, maxLength, true))
	{
		strcopy(buffer, maxLength, "0.0.0.0");
		return;
	}

	if (StrContains(buffer, ":") != -1)
	{
		strcopy(buffer, maxLength, "0.0.0.0");
	}
}

void FormatLocalISOTime(char[] buffer, int maxLength)
{
	char raw[GOKZ_TOP_TIMESTAMP_LENGTH];
	FormatTime(raw, sizeof(raw), "%Y-%m-%dT%H:%M:%S%z", GetTime());

	int length = strlen(raw);
	if (length >= 24 && (raw[length - 5] == '+' || raw[length - 5] == '-'))
	{
		char sign = raw[length - 5];
		char hourA = raw[length - 4];
		char hourB = raw[length - 3];
		char minuteA = raw[length - 2];
		char minuteB = raw[length - 1];
		raw[length - 5] = '\0';
		Format(buffer, maxLength, "%s%c%c%c:%c%c",
			raw,
			sign, hourA, hourB, minuteA, minuteB);
		return;
	}

	strcopy(buffer, maxLength, raw);
}

void EscapeJSONString(const char[] input, char[] output, int maxLength)
{
	int written;
	for (int i = 0; input[i] != '\0' && written < maxLength - 1; i++)
	{
		if ((input[i] == '"' || input[i] == '\\') && written < maxLength - 2)
		{
			output[written++] = '\\';
			output[written++] = input[i];
			continue;
		}

		output[written++] = input[i];
	}

	output[written] = '\0';
}
