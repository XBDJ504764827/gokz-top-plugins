int gI_SkillLevel[MAXPLAYERS + 1][MODE_COUNT];
int gI_PersonaDataPublicLevel = -1;

void OnPluginStart_Scoreboard()
{
	gI_PersonaDataPublicLevel = FindSendPropInfo("CCSPlayerResource", "m_nPersonaDataPublicLevel");
}

void OnMapStart_Scoreboard()
{
	char path[PLATFORM_MAX_PATH];
	for (int i = 0; i < 11; i++)
	{
		Format(path, sizeof(path), "materials/panorama/images/icons/xp/level%i.png", 5001 + i);
		AddFileToDownloadsTable(path);
	}

	int ent = GetPlayerResourceEntity();
	if (ent != -1)
	{
		SDKHook(ent, SDKHook_ThinkPost, Hook_OnThinkPost);
	}
}

void UpdateSkillLevel(int client)
{
	if (!IsValidClient(client) || IsFakeClient(client) || !gB_GokzTop)
	{
		return;
	}

	int mode = GetClientDisplayMode(client);
	int dataMode = GetDataModeForDisplay(mode);
	if (GOKZTop_IsLeaderboardDataLoaded(client, dataMode))
	{
		gI_SkillLevel[client][mode] = GetSkillLevelFromRating(GOKZTop_GetRating(client, dataMode));
	}
	else
	{
		gI_SkillLevel[client][mode] = 0;
		GOKZTop_RefreshLeaderboardData(client, dataMode);
	}

	UpdateScoreboardIcon(client);
}

int GetSkillLevelFromRating(float rating)
{
	if (rating >= 10.5)
	{
		return 11;
	}

	int level = RoundToFloor(rating);
	if (level > 10)
	{
		return 10;
	}
	if (level < 1)
	{
		return 0;
	}

	return level;
}

void UpdateScoreboardIcon(int client)
{
	if (gI_PersonaDataPublicLevel < 0)
	{
		return;
	}

	int ent = GetPlayerResourceEntity();
	if (ent == -1)
	{
		return;
	}

	int mode = GetClientDisplayMode(client);
	int level = gI_SkillLevel[client][mode];
	if (level <= 0)
	{
		level = 1;
	}

	SetEntData(ent, gI_PersonaDataPublicLevel + client * 4, 5000 + level, 4, true);
}

public void Hook_OnThinkPost(int ent)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			UpdateScoreboardIcon(client);
		}
	}
}
