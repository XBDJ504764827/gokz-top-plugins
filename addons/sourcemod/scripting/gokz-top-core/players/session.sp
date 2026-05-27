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
	GOKZTopPlayers_GetClientIPv4(client, gC_PlayerIP[client], sizeof(gC_PlayerIP[]));
	GOKZTopPlayers_FormatLocalISOTime(gC_ConnectedAt[client], sizeof(gC_ConnectedAt[]));
	GOKZTopPlayers_GetClientLanguageCode(client, gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));

	gB_SessionActive[client] = true;
	gB_ConnectSent[client] = false;

	if (QueryClientConVar(client, "cl_language", OnClientLanguageQueried) == QUERYCOOKIE_FAILED)
	{
		GOKZTopPlayers_GetServerLanguageCode(gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));
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
		GOKZTopPlayers_FormatLocalISOTime(disconnectAt, sizeof(disconnectAt));

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
		GOKZTopPlayers_NormalizeClientLanguage(cvarValue, gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));
		if (gC_ClientLanguage[client][0] == '\0')
		{
			GOKZTopPlayers_GetServerLanguageCode(gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));
		}
	}
	else
	{
		GOKZTopPlayers_GetServerLanguageCode(gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));
	}

	SendConnectEventOnce(client);
}

public Action Timer_SendConnectFallback(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (client != 0 && gB_SessionActive[client] && !gB_ConnectSent[client])
	{
		GOKZTopPlayers_GetServerLanguageCode(gC_ClientLanguage[client], sizeof(gC_ClientLanguage[]));
		SendConnectEventOnce(client);
	}

	return Plugin_Stop;
}

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
	GOKZTopPlayers_EscapeJSONString(gC_MapName, mapName, sizeof(mapName));

	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"player_steamid64\":\"%s\",\"connected_at\":\"%s\",\"ip_address\":\"%s\",\"map_name\":\"%s\",\"client_language\":\"%s\"}",
		gC_SessionID[client],
		gC_PlayerSteamID64[client],
		gC_ConnectedAt[client],
		gC_PlayerIP[client],
		mapName,
		gC_ClientLanguage[client]);

	PostSessionEvent("connect", payload);
}

void SendHeartbeatEvent(int client)
{
	char heartbeatAt[GOKZ_TOP_TIMESTAMP_LENGTH];
	GOKZTopPlayers_FormatLocalISOTime(heartbeatAt, sizeof(heartbeatAt));

	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"heartbeat_at\":\"%s\"}",
		gC_SessionID[client],
		heartbeatAt);

	PostSessionEvent("heartbeat", payload);
}

void SendDisconnectEvent(int client, const char[] disconnectAt)
{
	char payload[GOKZ_TOP_SESSION_BODY_LENGTH];
	Format(payload, sizeof(payload),
		"{\"session_id\":\"%s\",\"disconnect_at\":\"%s\"}",
		gC_SessionID[client],
		disconnectAt);

	PostSessionEvent("disconnect", payload);
}
