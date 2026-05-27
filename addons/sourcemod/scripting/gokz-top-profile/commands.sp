void RegisterCommands()
{
	RegConsoleCmd("sm_profile", CommandProfile, "[KZ] Show the profile of a player. Usage: !profile <player>");
	RegConsoleCmd("sm_p", CommandProfile, "[KZ] Show the profile of a player. Usage: !p <player>");
	RegConsoleCmd("sm_profileoptions", CommandProfileOptions, "[KZ] Show the profile options.");
	RegConsoleCmd("sm_pfo", CommandProfileOptions, "[KZ] Show the profile options.");
	RegConsoleCmd("sm_ranks", CommandRanks, "[KZ] Show all the available ranks.");
	RegConsoleCmd("sm_rating", CommandRating, "[KZ] Show your gokz-top rating.");
}

public Action CommandProfile(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	if (args == 0)
	{
		ShowProfile(client, client);
		return Plugin_Handled;
	}

	char playerName[64];
	GetCmdArgString(playerName, sizeof(playerName));
	int target = FindTarget(client, playerName, true, false);
	if (target != -1)
	{
		ShowProfile(client, target);
	}

	return Plugin_Handled;
}

public Action CommandProfileOptions(int client, int args)
{
	if (IsValidClient(client))
	{
		DisplayProfileOptionsMenu(client);
	}

	return Plugin_Handled;
}

public Action CommandRanks(int client, int args)
{
	if (!IsValidClient(client))
	{
		return Plugin_Handled;
	}

	int mode = GetClientDisplayMode(client);
	char rankBuffer[256];
	char buffer[256];
	Format(buffer, sizeof(buffer), "%s: ", gC_ModeNamesShort[mode]);

	for (int i = 0; i < RANK_COUNT; i++)
	{
		Format(rankBuffer, sizeof(rankBuffer), "%s%s (%d) ", gC_rankColor[i], gC_rankName[i], gI_rankThreshold[mode][i]);
		StrCat(buffer, sizeof(buffer), rankBuffer);

		if (i > 0 && i % 3 == 0)
		{
			GOKZ_PrintToChat(client, true, buffer);
			Format(buffer, sizeof(buffer), "%s: ", gC_ModeNamesShort[mode]);
		}
	}

	GOKZ_PrintToChat(client, true, buffer);
	return Plugin_Handled;
}

public Action CommandRating(int client, int args)
{
	if (!IsValidClient(client) || IsFakeClient(client))
	{
		return Plugin_Handled;
	}

	if (!gB_GokzTop)
	{
		GOKZ_PrintToChat(client, false, "%s{default}Leaderboard system not available.", GOKZ_TOP_CHAT_PREFIX);
		return Plugin_Handled;
	}

	int mode = GetClientDisplayMode(client);
	int dataMode = GetDataModeForDisplay(mode);
	if (!GOKZTop_IsLeaderboardDataLoaded(client, dataMode))
	{
		GOKZTop_RefreshLeaderboardData(client, dataMode);
		GOKZ_PrintToChat(client, false, "%s{default}Your skill level data is not loaded yet, please wait...", GOKZ_TOP_CHAT_PREFIX);
		return Plugin_Handled;
	}

	float rating = GOKZTop_GetRating(client, dataMode);
	int rank = GOKZTop_GetGlobalRank(client, dataMode);
	int level = GetSkillLevelFromRating(rating);

	if (rank > 0)
	{
		GOKZ_PrintToChat(client, false, "%s{default}Your Rating: {green}%.2f{default} {grey}| Rank: {green}#%d{default} {grey}| Level {green}%d",
			GOKZ_TOP_CHAT_PREFIX,
			rating,
			rank,
			level);
	}
	else
	{
		GOKZ_PrintToChat(client, false, "%s{default}Your Rating: {green}%.2f{default} {grey}| Level {green}%d{default} {grey}(Not ranked)",
			GOKZ_TOP_CHAT_PREFIX,
			rating,
			level);
	}

	return Plugin_Handled;
}
