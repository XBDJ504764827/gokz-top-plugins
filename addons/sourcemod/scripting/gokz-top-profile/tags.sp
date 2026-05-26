void UpdateRank(int client, int mode)
{
	if (!IsValidClient(client) || IsFakeClient(client))
	{
		return;
	}

	mode = GetDataModeForDisplay(mode);
	int dataMode = GetDataModeForDisplay(mode);
	int tagType = GetAvailableTagTypeOrDefault(client);

	if (tagType != ProfileTagType_Rank)
	{
		UpdateSpecialTags(client, mode, dataMode, tagType);
		return;
	}

	if (!gB_GokzTop || !GOKZTop_IsLeaderboardDataLoaded(client, dataMode))
	{
		if (gB_GokzTop)
		{
			GOKZTop_RefreshLeaderboardData(client, dataMode);
		}
		UpdateTags(client, -1, mode);
		SetCachedRank(client, mode, 0);
		return;
	}

	int rank = GetRankForPoints(GOKZTop_GetPoints(client, dataMode), dataMode);
	UpdateTags(client, rank, mode);
	SetCachedRank(client, mode, rank);
}

void UpdateSpecialTags(int client, int displayMode, int dataMode, int tagType)
{
	char clanTag[64];
	char chatTag[32];
	char color[32];
	strcopy(color, sizeof(color), "{default}");

	if (tagType == ProfileTagType_Admin)
	{
		FormatEx(clanTag, sizeof(clanTag), "[%s %T]", gC_ModeNamesShort[displayMode], "Tag - Admin", client);
		FormatEx(chatTag, sizeof(chatTag), "%T", "Tag - Admin", client);
		strcopy(color, sizeof(color), TAG_COLOR_ADMIN);
	}
	else if (tagType == ProfileTagType_VIP)
	{
		FormatEx(clanTag, sizeof(clanTag), "[%s %T]", gC_ModeNamesShort[displayMode], "Tag - VIP", client);
		FormatEx(chatTag, sizeof(chatTag), "%T", "Tag - VIP", client);
		strcopy(color, sizeof(color), TAG_COLOR_VIP);
	}
	else if (tagType == ProfileTagType_GlobalRank && gB_GokzTop && GOKZTop_IsLeaderboardDataLoaded(client, dataMode))
	{
		int rank = GOKZTop_GetGlobalRank(client, dataMode);
		FormatEx(clanTag, sizeof(clanTag), rank > 0 ? "[%s GL#%d]" : "[%s]", gC_ModeNamesShort[displayMode], rank);
		FormatEx(chatTag, sizeof(chatTag), rank > 0 ? "GL#%d" : "", rank);
		GetGokzTopRankColorFromRating(GOKZTop_GetRating(client, dataMode), color, sizeof(color));
	}
	else if (tagType == ProfileTagType_RegionalRank && gB_GokzTop && GOKZTop_IsLeaderboardDataLoaded(client, dataMode))
	{
		int regionalRank = GOKZTop_GetRegionalRank(client, dataMode);
		char region[8];
		GOKZTop_GetRegionCode(client, dataMode, region, sizeof(region));
		if (regionalRank > 0 && region[0] != '\0')
		{
			FormatEx(clanTag, sizeof(clanTag), "[%s %s#%d]", gC_ModeNamesShort[displayMode], region, regionalRank);
			FormatEx(chatTag, sizeof(chatTag), "%s#%d", region, regionalRank);
			GetGokzTopRankColorFromRating(GOKZTop_GetRating(client, dataMode), color, sizeof(color));
		}
		else
		{
			FormatEx(clanTag, sizeof(clanTag), "[%s]", gC_ModeNamesShort[displayMode]);
			chatTag[0] = '\0';
		}
	}
	else if (tagType == ProfileTagType_Rating && gB_GokzTop && GOKZTop_IsLeaderboardDataLoaded(client, dataMode))
	{
		float rating = GOKZTop_GetRating(client, dataMode);
		if (rating > 0.0)
		{
			FormatEx(clanTag, sizeof(clanTag), "[%s Lv.%d]", gC_ModeNamesShort[displayMode], GetSkillLevelFromRating(rating));
			FormatEx(chatTag, sizeof(chatTag), "Lv.%d", GetSkillLevelFromRating(rating));
			GetGokzTopRankColorFromRating(rating, color, sizeof(color));
		}
		else
		{
			FormatEx(clanTag, sizeof(clanTag), "[%s]", gC_ModeNamesShort[displayMode]);
			chatTag[0] = '\0';
		}
	}
	else if (tagType == ProfileTagType_SteamGroup)
	{
		if (gC_OriginalSteamGroupTag[client][0] != '\0')
		{
			FormatEx(clanTag, sizeof(clanTag), "[%s %s]", gC_ModeNamesShort[displayMode], gC_OriginalSteamGroupTag[client]);
			strcopy(chatTag, sizeof(chatTag), gC_OriginalSteamGroupTag[client]);
		}
		else
		{
			FormatEx(clanTag, sizeof(clanTag), "[%s]", gC_ModeNamesShort[displayMode]);
			chatTag[0] = '\0';
		}
	}
	else
	{
		FormatEx(clanTag, sizeof(clanTag), "[%s]", gC_ModeNamesShort[displayMode]);
		chatTag[0] = '\0';
		if (gB_GokzTop)
		{
			GOKZTop_RefreshLeaderboardData(client, dataMode);
		}
	}

	ApplyTags(client, displayMode, clanTag, chatTag, color);
}

void UpdateTags(int client, int rank, int mode)
{
	char clanTag[64];
	char chatTag[32];
	char color[32];
	if (rank >= 0)
	{
		FormatEx(clanTag, sizeof(clanTag), "[%s %s]", gC_ModeNamesShort[mode], gC_rankName[rank]);
		strcopy(chatTag, sizeof(chatTag), gC_rankName[rank]);
		strcopy(color, sizeof(color), gC_rankColor[rank]);
	}
	else
	{
		FormatEx(clanTag, sizeof(clanTag), "[%s]", gC_ModeNamesShort[mode]);
		chatTag[0] = '\0';
		strcopy(color, sizeof(color), "{default}");
	}

	ApplyTags(client, mode, clanTag, chatTag, color);
}

void ApplyTags(int client, int mode, char[] clanTag, const char[] chatTag, const char[] color)
{
	if (GOKZ_GetOption(client, gC_ProfileOptionNames[ProfileOption_ShowRankClanTag]) != ProfileOptionBool_Enabled)
	{
		FormatEx(clanTag, 64, "[%s]", gC_ModeNamesShort[mode]);
	}
	CS_SetClientClanTag(client, clanTag);

	if (!gB_Chat)
	{
		return;
	}

	if (GOKZ_GetOption(client, gC_ProfileOptionNames[ProfileOption_ShowRankChat]) == ProfileOptionBool_Enabled)
	{
		GOKZ_CH_SetChatTag(client, chatTag, color);
	}
	else
	{
		GOKZ_CH_SetChatTag(client, "", "{default}");
	}
}

void SetCachedRank(int client, int mode, int rank)
{
	if (gI_Rank[client][mode] == rank)
	{
		return;
	}

	gI_Rank[client][mode] = rank;
	Call_OnRankUpdated(client, mode, rank);
}

int GetRankForPoints(int points, int mode)
{
	int rank;
	for (rank = 1; rank < RANK_COUNT; rank++)
	{
		if (points < gI_rankThreshold[mode][rank])
		{
			break;
		}
	}

	return rank - 1;
}

void GetGokzTopRankColorFromRating(float rating, char[] color, int maxLength)
{
	int level = GetSkillLevelFromRating(rating);
	if (level < 1)
	{
		strcopy(color, maxLength, gC_GokzTopRankColor[0]);
	}
	else if (level > 10)
	{
		strcopy(color, maxLength, gC_GokzTopRankColor[10]);
	}
	else
	{
		strcopy(color, maxLength, gC_GokzTopRankColor[level]);
	}
}

bool CanUseTagType(int client, int tagType)
{
	switch (tagType)
	{
		case ProfileTagType_Rank:
		{
			return true;
		}
		case ProfileTagType_VIP:
		{
			return CheckCommandAccess(client, "gokz_flag_vip", ADMFLAG_CUSTOM1);
		}
		case ProfileTagType_Admin:
		{
			return CheckCommandAccess(client, "gokz_flag_admin", ADMFLAG_GENERIC);
		}
		case ProfileTagType_SteamGroup:
		{
			return true;
		}
		case ProfileTagType_GlobalRank:
		{
			int dataMode = GetDataModeForDisplay(GetClientDisplayMode(client));
			return gB_GokzTop && GOKZTop_IsLeaderboardDataLoaded(client, dataMode) && GOKZTop_GetGlobalRank(client, dataMode) > 0;
		}
		case ProfileTagType_RegionalRank:
		{
			int dataMode = GetDataModeForDisplay(GetClientDisplayMode(client));
			return gB_GokzTop && GOKZTop_IsLeaderboardDataLoaded(client, dataMode) && GOKZTop_HasRegionalRank(client, dataMode);
		}
		case ProfileTagType_Rating:
		{
			int dataMode = GetDataModeForDisplay(GetClientDisplayMode(client));
			return gB_GokzTop && GOKZTop_IsLeaderboardDataLoaded(client, dataMode) && GOKZTop_GetRating(client, dataMode) > 0.0;
		}
	}

	return false;
}

int GetAvailableTagTypeOrDefault(int client)
{
	int tagType = GOKZ_GetOption(client, gC_ProfileOptionNames[ProfileOption_TagType]);
	return CanUseTagType(client, tagType) ? tagType : ProfileTagType_Rank;
}

int GetNextAvailableTagType(int client)
{
	int tagType = GOKZ_GetOption(client, gC_ProfileOptionNames[ProfileOption_TagType]);
	for (int attempt = 0; attempt < PROFILETAGTYPE_COUNT; attempt++)
	{
		tagType++;
		if (tagType >= PROFILETAGTYPE_COUNT)
		{
			tagType = 0;
		}

		if (CanUseTagType(client, tagType))
		{
			return tagType;
		}
	}

	return ProfileTagType_Rank;
}
