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
#define GOKZ_TOP_LANGUAGE_CODE_LENGTH 16
#define GOKZ_TOP_SESSION_BODY_LENGTH 1024
#define GOKZ_TOP_KICK_MESSAGE_LENGTH 512
#define GOKZ_TOP_LANGUAGE_QUERY_FALLBACK 1.0

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
bool gB_ConnectSent[MAXPLAYERS + 1];
char gC_SessionID[MAXPLAYERS + 1][GOKZ_TOP_SESSION_ID_LENGTH];
char gC_PlayerSteamID64[MAXPLAYERS + 1][GOKZ_TOP_STEAMID64_LENGTH];
char gC_PlayerIP[MAXPLAYERS + 1][GOKZ_TOP_IP_LENGTH];
char gC_ConnectedAt[MAXPLAYERS + 1][GOKZ_TOP_TIMESTAMP_LENGTH];
char gC_ClientLanguage[MAXPLAYERS + 1][GOKZ_TOP_LANGUAGE_CODE_LENGTH];
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

public void OnClientPutInServer(int client)
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
	GetClientLanguageCode(client, gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));

	gB_SessionActive[client] = true;
	gB_ConnectSent[client] = false;

	if (QueryClientConVar(client, "cl_language", OnClientLanguageQueried) == QUERYCOOKIE_FAILED)
	{
		SendConnectEventOnce(client);
		return;
	}

	CreateTimer(GOKZ_TOP_LANGUAGE_QUERY_FALLBACK, Timer_SendConnectFallback, GetClientUserId(client));
}

void EndSession(int client)
{
	if (gB_ConnectSent[client])
	{
		char disconnectAt[GOKZ_TOP_TIMESTAMP_LENGTH];
		FormatLocalISOTime(disconnectAt, sizeof(disconnectAt));

		SendDisconnectEvent(client, disconnectAt);
	}

	ClearSession(client);
}

void ClearSession(int client)
{
	gB_SessionActive[client] = false;
	gB_ConnectSent[client] = false;
	gC_SessionID[client][0] = '\0';
	gC_PlayerSteamID64[client][0] = '\0';
	gC_PlayerIP[client][0] = '\0';
	gC_ConnectedAt[client][0] = '\0';
	gC_ClientLanguage[client][0] = '\0';
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

public void OnClientLanguageQueried(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	if (!gB_SessionActive[client] || gB_ConnectSent[client])
	{
		return;
	}

	if (result == ConVarQuery_Okay)
	{
		NormalizeClientLanguage(cvarValue, gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));
	}

	SendConnectEventOnce(client);
}

public Action Timer_SendConnectFallback(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client != 0 && gB_SessionActive[client] && !gB_ConnectSent[client])
	{
		SendConnectEventOnce(client);
	}

	return Plugin_Stop;
}



// =====[ SESSION EVENTS ]=====

void SendConnectEventOnce(int client)
{
	if (!gB_SessionActive[client] || gB_ConnectSent[client])
	{
		return;
	}

	gB_ConnectSent[client] = true;
	SendConnectEvent(client);
}

void SendConnectEvent(int client)
{
	char mapName[PLATFORM_MAX_PATH * 2];
	EscapeJSONString(gC_MapName, mapName, sizeof(mapName));

	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"player_steamid64\":\"%s\",\"connected_at\":\"%s\",\"ip_address\":\"%s\",\"map_name\":\"%s\",\"client_language\":\"%s\"}",
		gC_SessionID[client],
		gC_PlayerSteamID64[client],
		gC_ConnectedAt[client],
		gC_PlayerIP[client],
		mapName,
		gC_ClientLanguage[client]);

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


// =====[ CORE CALLBACKS ]=====

public void GOKZTop_OnSessionEventPosted(const char[] event, const char[] responseBody)
{
	if (!StrEqual(event, "connect"))
	{
		return;
	}

	HandleConnectResponse(responseBody);
}

void HandleConnectResponse(const char[] responseBody)
{
	char sessionID[GOKZ_TOP_SESSION_ID_LENGTH];
	if (!ExtractJsonString(responseBody, "id", sessionID, sizeof(sessionID)))
	{
		return;
	}

	bool required;
	if (!ExtractJsonBool(responseBody, "required", required) || !required)
	{
		return;
	}

	int client = FindClientBySessionID(sessionID);
	if (client == 0 || !IsClientInGame(client))
	{
		return;
	}

	char kickMessage[GOKZ_TOP_KICK_MESSAGE_LENGTH];
	if (!ExtractJsonString(responseBody, "kick_message", kickMessage, sizeof(kickMessage)))
	{
		FormatFallbackKickMessage(responseBody, kickMessage, sizeof(kickMessage));
	}

	LogMessage("[gokz-top-players] Kicking banned player client=%d steamid64=%s session_id=%s client_language=%s",
		client,
		gC_PlayerSteamID64[client],
		gC_SessionID[client],
		gC_ClientLanguage[client]);
	ClearSession(client);
	KickClient(client, "%s", kickMessage);
}

int FindClientBySessionID(const char[] sessionID)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gB_SessionActive[client] && StrEqual(gC_SessionID[client], sessionID, false))
		{
			return client;
		}
	}

	return 0;
}

void FormatFallbackKickMessage(const char[] responseBody, char[] kickMessage, int maxLength)
{
	char banType[64];
	char detailURL[256];
	ExtractJsonString(responseBody, "ban_type", banType, sizeof(banType));
	ExtractJsonString(responseBody, "detail_url", detailURL, sizeof(detailURL));

	if (banType[0] == '\0')
	{
		strcopy(banType, sizeof(banType), "active");
	}

	if (detailURL[0] == '\0')
	{
		strcopy(kickMessage, maxLength, "Active GOKZ.TOP ban.");
		return;
	}

	Format(kickMessage, maxLength, "Active GOKZ.TOP ban (%s). Details: %s", banType, detailURL);
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

void GetClientLanguageCode(int client, char[] buffer, int maxLength)
{
	int language = GetClientLanguage(client);
	if (language < 0)
	{
		strcopy(buffer, maxLength, "en");
		return;
	}

	GetLanguageInfo(language, buffer, maxLength);
	NormalizeClientLanguage(buffer, buffer, maxLength);
	if (buffer[0] == '\0')
	{
		strcopy(buffer, maxLength, "en");
	}
}

void NormalizeClientLanguage(const char[] input, char[] buffer, int maxLength)
{
	if (StrEqual(input, "chi", false)
		|| StrEqual(input, "zh", false)
		|| StrEqual(input, "zho", false)
		|| StrEqual(input, "schinese", false)
		|| StrEqual(input, "tchinese", false)
		|| StrEqual(input, "chinese", false))
	{
		strcopy(buffer, maxLength, "chi");
		return;
	}

	if (StrEqual(input, "ru", false)
		|| StrEqual(input, "rus", false)
		|| StrEqual(input, "russian", false))
	{
		strcopy(buffer, maxLength, "ru");
		return;
	}

	if (StrEqual(input, "en", false)
		|| StrEqual(input, "eng", false)
		|| StrEqual(input, "english", false))
	{
		strcopy(buffer, maxLength, "en");
		return;
	}

	strcopy(buffer, maxLength, input);
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
	int written = 0;
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

bool FindJsonValueStart(const char[] json, const char[] key, int &pos)
{
	char pattern[64];
	Format(pattern, sizeof(pattern), "\"%s\"", key);

	int keyPos = StrContains(json, pattern, false);
	if (keyPos == -1)
	{
		return false;
	}

	pos = keyPos + strlen(pattern);
	while (json[pos] != '\0' && json[pos] != ':')
	{
		pos++;
	}

	if (json[pos] != ':')
	{
		return false;
	}

	pos++;
	while (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')
	{
		pos++;
	}

	return json[pos] != '\0';
}

bool ExtractJsonBool(const char[] json, const char[] key, bool &value)
{
	value = false;

	int pos;
	if (!FindJsonValueStart(json, key, pos))
	{
		return false;
	}

	if (StrContains(json[pos], "true", false) == 0)
	{
		value = true;
		return true;
	}

	if (StrContains(json[pos], "false", false) == 0)
	{
		return true;
	}

	return false;
}

bool ExtractJsonString(const char[] json, const char[] key, char[] out, int maxLength)
{
	out[0] = '\0';

	int pos;
	if (!FindJsonValueStart(json, key, pos)
		|| json[pos] != '"')
	{
		return false;
	}

	pos++;
	int outPos = 0;
	while (json[pos] != '\0')
	{
		char c = json[pos++];
		if (c == '"')
		{
			out[outPos] = '\0';
			return true;
		}

		if (c == '\\' && json[pos] != '\0')
		{
			c = json[pos++];
			if (c == 'n')
			{
				c = '\n';
			}
			else if (c == 'r')
			{
				c = '\r';
			}
			else if (c == 't')
			{
				c = '\t';
			}
		}

		if (outPos < maxLength - 1)
		{
			out[outPos++] = c;
		}
	}

	out[outPos] = '\0';
	return false;
}
