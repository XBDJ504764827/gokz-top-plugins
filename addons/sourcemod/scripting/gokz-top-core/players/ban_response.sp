void HandleConnectResponse(const char[] responseBody)
{
	char sessionID[GOKZ_TOP_SESSION_ID_LENGTH];
	if (!ExtractJsonString(responseBody, "id", sessionID, sizeof(sessionID)))
	{
		return;
	}

	bool required;
	if (!GOKZTopPlayers_ExtractJsonBool(responseBody, "required", required) || !required)
	{
		return;
	}

	char banType[64];
	if (!ExtractJsonString(responseBody, "ban_type", banType, sizeof(banType)) || banType[0] == '\0')
	{
		LogError("[gokz-top-core] Refusing to kick: ban enforcement response missing ban_type");
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
		FormatFallbackKickMessage(responseBody, banType, kickMessage, sizeof(kickMessage));
	}

	LogMessage("[gokz-top-core] Kicking banned player client=%d steamid64=%s session_id=%s client_language=%s",
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

void FormatFallbackKickMessage(const char[] responseBody, const char[] banType, char[] kickMessage, int maxLength)
{
	char detailURL[256];
	ExtractJsonString(responseBody, "detail_url", detailURL, sizeof(detailURL));

	if (detailURL[0] == '\0')
	{
		strcopy(kickMessage, maxLength, "Active GOKZ.TOP ban.");
		return;
	}

	Format(kickMessage, maxLength, "Active GOKZ.TOP ban (%s). Details: %s", banType, detailURL);
}
