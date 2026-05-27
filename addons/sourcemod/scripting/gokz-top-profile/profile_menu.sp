#define PROFILE_ITEM_MODE "mode"
#define PROFILE_ITEM_RANK "rank"

int gI_ProfileTarget[MAXPLAYERS + 1];
int gI_ProfileMode[MAXPLAYERS + 1];
bool gB_ProfileWaitingForUpdate[MAXPLAYERS + 1];

void ShowProfile(int client, int player = 0)
{
	if (player != 0)
	{
		gI_ProfileTarget[client] = player;
		gI_ProfileMode[client] = GetClientDisplayMode(player);
	}

	int target = gI_ProfileTarget[client];
	int dataMode = GetProfileDataScope(gI_ProfileMode[client]);
	if (!IsValidClient(target))
	{
		return;
	}

	if (!gB_GokzTop)
	{
		GOKZ_PrintToChat(client, false, "%s{default}Leaderboard system not available.", GOKZ_TOP_CHAT_PREFIX);
		return;
	}

	if (!GOKZTop_IsLeaderboardDataLoaded(target, dataMode))
	{
		if (!gB_ProfileWaitingForUpdate[client])
		{
			GOKZTop_RefreshLeaderboardData(target, dataMode);
			gB_ProfileWaitingForUpdate[client] = true;
			GOKZ_PrintToChat(client, false, "%s{default}Profile data is loading...", GOKZ_TOP_CHAT_PREFIX);
		}
		return;
	}

	gB_ProfileWaitingForUpdate[client] = false;

	Menu menu = new Menu(MenuHandler_Profile);
	char title[256];
	char region[8];
	GOKZTop_GetRegionCode(target, dataMode, region, sizeof(region));
	int points = GOKZTop_GetPoints(target, dataMode);
	float rating = GOKZTop_GetRating(target, dataMode);
	int rank = GetRankForRating(rating);
	char formattedPoints[16];
	FormatIntWithCommas(points, formattedPoints, sizeof(formattedPoints));
	if (gI_ProfileMode[client] < MODE_COUNT)
	{
		SetCachedRank(target, gI_ProfileMode[client], rank);
	}

	Format(title, sizeof(title),
		"Profile - %N\nRating: %.2f\nGlobal Rank: #%d\nRegional Rank: -\nPoints: %s",
		target,
		rating,
		GOKZTop_GetGlobalRank(target, dataMode),
		formattedPoints);

	if (GOKZTop_HasRegionalRank(target, dataMode) && region[0] != '\0')
	{
		Format(title, sizeof(title),
			"Profile - %N\nRating: %.2f\nGlobal Rank: #%d\nRegional Rank: %s#%d\nPoints: %s",
			target,
			rating,
			GOKZTop_GetGlobalRank(target, dataMode),
			region,
			GOKZTop_GetRegionalRank(target, dataMode),
			formattedPoints);
	}

	menu.SetTitle(title);
	menu.ExitButton = true;

	char display[64];
	char scopeLabel[8];
	GetProfileScopeLabel(gI_ProfileMode[client], scopeLabel, sizeof(scopeLabel));
	Format(display, sizeof(display), "Scope: %s", scopeLabel);
	menu.AddItem(PROFILE_ITEM_MODE, display);

	Format(display, sizeof(display), "%T: %s", "Profile Menu - Rank", client, gC_GokzTopRankName[rank]);
	menu.AddItem(PROFILE_ITEM_RANK, display);

	menu.Display(client, MENU_TIME_FOREVER);
}

int GetProfileDataScope(int scope)
{
	if (scope >= 0 && scope < GOKZTOP_MODE_COUNT)
	{
		return scope;
	}

	return GOKZTOP_MODE_KZT;
}

void GetProfileScopeLabel(int scope, char[] buffer, int maxLength)
{
	switch (scope)
	{
		case GOKZTOP_MODE_VNL:
		{
			strcopy(buffer, maxLength, "VNL");
		}
		case GOKZTOP_MODE_SKZ:
		{
			strcopy(buffer, maxLength, "SKZ");
		}
		case GOKZTOP_MODE_OVR:
		{
			strcopy(buffer, maxLength, "OVR");
		}
		default:
		{
			strcopy(buffer, maxLength, "KZT");
		}
	}
}

void FormatIntWithCommas(int value, char[] buffer, int maxLength)
{
	char raw[16];
	IntToString(value, raw, sizeof(raw));

	int rawLength = strlen(raw);
	int firstGroupLength = rawLength % 3;
	if (firstGroupLength == 0)
	{
		firstGroupLength = 3;
	}

	int outPos;
	for (int i = 0; i < rawLength && outPos < maxLength - 1; i++)
	{
		if (i > 0 && (i - firstGroupLength) % 3 == 0 && outPos < maxLength - 1)
		{
			buffer[outPos++] = ',';
		}

		buffer[outPos++] = raw[i];
	}

	buffer[outPos] = '\0';
}

void Profile_OnClientConnected(int client)
{
	gI_ProfileTarget[client] = 0;
	gI_ProfileMode[client] = Mode_KZTimer;
	gB_ProfileWaitingForUpdate[client] = false;
}

void Profile_OnClientDisconnect(int client)
{
	gI_ProfileTarget[client] = 0;
	gB_ProfileWaitingForUpdate[client] = false;
}

void Profile_OnLeaderboardDataFetched(int player, int mode)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (gB_ProfileWaitingForUpdate[client]
			&& gI_ProfileTarget[client] == player
			&& GetProfileDataScope(gI_ProfileMode[client]) == mode)
		{
			ShowProfile(client);
		}
	}
}

public int MenuHandler_Profile(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action != MenuAction_Select)
	{
		return 0;
	}

	char info[16];
	menu.GetItem(item, info, sizeof(info));

	if (StrEqual(info, PROFILE_ITEM_MODE, false))
	{
		gI_ProfileMode[client]++;
		if (gI_ProfileMode[client] >= GOKZTOP_MODE_COUNT)
		{
			gI_ProfileMode[client] = 0;
		}
	}
	else if (StrEqual(info, PROFILE_ITEM_RANK, false))
	{
		ShowRankInfo(client);
		return 0;
	}

	ShowProfile(client);
	return 0;
}

void ShowRankInfo(int client)
{
	int target = gI_ProfileTarget[client];
	int mode = gI_ProfileMode[client];
	int dataScope = GetProfileDataScope(mode);
	float rating = gB_GokzTop ? GOKZTop_GetRating(target, dataScope) : 0.0;
	int rank = GetRankForRating(rating);
	if (mode < MODE_COUNT)
	{
		SetCachedRank(target, mode, rank);
	}

	Menu menu = new Menu(MenuHandler_RankInfo);
	char title[64];
	Format(title, sizeof(title), "%T - %N", "Rank Info Menu - Title", client, target);
	menu.SetTitle(title);
	menu.ExitBackButton = true;

	char display[96];
	Format(display, sizeof(display), "%T: %s", "Rank Info Menu - Current Rank", client, gC_GokzTopRankName[rank]);
	menu.AddItem("", display, ITEMDRAW_DISABLED);

	int nextRank = rank + 1;
	if (nextRank > GOKZ_TOP_RANK_COUNT)
	{
		Format(display, sizeof(display), "%T: -", "Rank Info Menu - Next Rank", client);
		menu.AddItem("", display, ITEMDRAW_DISABLED);
		Format(display, sizeof(display), "%T: 0.00", "Rank Info Menu - Points needed", client);
		menu.AddItem("", display, ITEMDRAW_DISABLED);
	}
	else
	{
		Format(display, sizeof(display), "%T: %s", "Rank Info Menu - Next Rank", client, gC_GokzTopRankName[nextRank]);
		menu.AddItem("", display, ITEMDRAW_DISABLED);
		Format(display, sizeof(display), "%T: %.2f", "Rank Info Menu - Points needed", client, float(nextRank) - rating);
		menu.AddItem("", display, ITEMDRAW_DISABLED);
	}

	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_RankInfo(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Cancel)
	{
		ShowProfile(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}
