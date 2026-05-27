// =====[ CHAT OUTPUT ]=====

void PrintPBLine(int client, int mode, int recordType, const char[] mapName, float pbTime, int pbPoints, const char[] dateOnly)
{
	char time[32];
	FormatDuration(time, sizeof(time), pbTime);

	char dateShort[32];
	FormatDateShort(dateOnly, dateShort, sizeof(dateShort));

	char prefix[16];
	GetRecordTypeDisplay(recordType, prefix, sizeof(prefix));

	GOKZ_PrintToChat(client, false,
		"{purple}%s{default} - {darkblue}%s{default} - %s{default} PB [ {lightgreen}%s{default} | {yellow}%d{default}{grey} Pts{default} | {bluegrey}%s{default} ]",
		mapName,
		gC_ModeNamesShort[mode],
		prefix,
		time,
		pbPoints,
		dateShort);
}

void PrintPBLineWithDiff(int client, int mode, int recordType, const char[] mapName, float pbTime, int pbPoints, const char[] dateOnly,
	bool hasStored, float oldTime, int oldPoints)
{
	char time[32];
	FormatDuration(time, sizeof(time), pbTime);

	char dateShort[32];
	FormatDateShort(dateOnly, dateShort, sizeof(dateShort));

	char diffInline[48];
	diffInline[0] = '\0';
	int pointDiff = 0;

	if (hasStored)
	{
		float diff = pbTime - oldTime;
		float diffAbs = FloatAbs(diff);

		char diffTime[24];
		FormatDurationDiff(diffTime, sizeof(diffTime), diffAbs);

		if (diff < 0.0)
		{
			Format(diffInline, sizeof(diffInline), " ({green}-%s{default})", diffTime);
			pointDiff = pbPoints - oldPoints;
			if (pointDiff < 0)
			{
				pointDiff = 0;
			}
		}
		else if (diff > 0.0)
		{
			Format(diffInline, sizeof(diffInline), " ({red}+%s{default})", diffTime);
		}
		else
		{
			Format(diffInline, sizeof(diffInline), " (+00.00)");
		}
	}

	char pointsText[64];
	if (pointDiff > 0)
	{
		Format(pointsText, sizeof(pointsText), "{yellow}%d{default} ({green}+%d{default}){grey} Pts{default}", pbPoints, pointDiff);
	}
	else
	{
		Format(pointsText, sizeof(pointsText), "{yellow}%d{default}{grey} Pts{default}", pbPoints);
	}

	char prefix[16];
	GetRecordTypeDisplay(recordType, prefix, sizeof(prefix));

	GOKZ_PrintToChat(client, false,
		"{purple}%s{default} - {darkblue}%s{default} - %s{default} PB [ {lightgreen}%s{default}%s | %s | {bluegrey}%s{default} ]",
		mapName,
		gC_ModeNamesShort[mode],
		prefix,
		time,
		diffInline,
		pointsText,
		dateShort);
}



// =====[ PB CACHE ]=====

void StorePB(int client, int mode, int recordType, const char[] mapName, float time, int points, const char[] dateOnly)
{
	if (time <= 0.0)
	{
		return;
	}

	char key[256];
	BuildPBKey(client, mode, recordType, mapName, key, sizeof(key));
	gSM_PBTime.SetValue(key, view_as<any>(time));
	gSM_PBPoints.SetValue(key, points);
	gSM_PBDate.SetString(key, dateOnly);
}

bool GetStoredPB(int client, int mode, int recordType, const char[] mapName, float &time, int &points, char[] dateOnly, int dateLength)
{
	char key[256];
	BuildPBKey(client, mode, recordType, mapName, key, sizeof(key));

	any value;
	if (!gSM_PBTime.GetValue(key, value))
	{
		return false;
	}

	time = view_as<float>(value);
	if (!gSM_PBPoints.GetValue(key, value))
	{
		points = 0;
	}
	else
	{
		points = value;
	}

	if (!gSM_PBDate.GetString(key, dateOnly, dateLength))
	{
		dateOnly[0] = '\0';
	}

	return true;
}

void ClearClientPBStorage(int client)
{
	// PB keys include Steam account ID, so stale entries cannot leak across clients.
	if (client <= 0)
	{
		return;
	}
}

void BuildPBKey(int client, int mode, int recordType, const char[] mapName, char[] key, int keyLength)
{
	Format(key, keyLength, "%d|%d|%d|%s", GetSteamAccountID(client), mode, recordType, mapName);
}



// =====[ FORMAT HELPERS ]=====

void FallbackTierCommand(int client)
{
	if (!IsValidClient(client))
	{
		return;
	}

	gB_TierFallbackCommand[client] = true;
	FakeClientCommand(client, "sm_tier");
}

int GetClientMode(int client)
{
	int mode = GOKZ_GetCoreOption(client, Option_Mode);
	if (mode >= 0 && mode < MODE_COUNT)
	{
		return mode;
	}

	return Mode_KZTimer;
}

bool IsSupportedRecordsMode(int mode)
{
	return mode >= Mode_Vanilla && mode < MODE_COUNT;
}

void GetCurrentDisplayMap(char[] mapName, int maxLength)
{
	GetCurrentMap(mapName, maxLength);
	GetMapDisplayName(mapName, mapName, maxLength);
}

void GetRecordTypeName(int recordType, char[] buffer, int maxLength)
{
	if (recordType == GOKZ_TOP_RECORD_TYPE_PRO)
	{
		strcopy(buffer, maxLength, "PRO");
	}
	else
	{
		strcopy(buffer, maxLength, "NUB");
	}
}

void GetRecordTypeDisplay(int recordType, char[] buffer, int maxLength)
{
	if (recordType == GOKZ_TOP_RECORD_TYPE_PRO)
	{
		strcopy(buffer, maxLength, "{blue}PRO");
	}
	else
	{
		strcopy(buffer, maxLength, "{gold}NUB");
	}
}

void ISODateOnly(const char[] value, char[] out, int maxLength)
{
	strcopy(out, maxLength, value);
	int tpos = FindCharInString(out, 'T');
	if (tpos > 0)
	{
		out[tpos] = '\0';
	}
}

void FormatDateShort(const char[] ymd, char[] out, int maxLength)
{
	if (strlen(ymd) < 10)
	{
		strcopy(out, maxLength, ymd);
		return;
	}

	char parts[3][5];
	int count = ExplodeString(ymd, "-", parts, 3, sizeof(parts[]));
	if (count != 3)
	{
		strcopy(out, maxLength, ymd);
		return;
	}

	int month = StringToInt(parts[1]);
	char monthName[4];
	switch (month)
	{
		case 1: strcopy(monthName, sizeof(monthName), "Jan");
		case 2: strcopy(monthName, sizeof(monthName), "Feb");
		case 3: strcopy(monthName, sizeof(monthName), "Mar");
		case 4: strcopy(monthName, sizeof(monthName), "Apr");
		case 5: strcopy(monthName, sizeof(monthName), "May");
		case 6: strcopy(monthName, sizeof(monthName), "Jun");
		case 7: strcopy(monthName, sizeof(monthName), "Jul");
		case 8: strcopy(monthName, sizeof(monthName), "Aug");
		case 9: strcopy(monthName, sizeof(monthName), "Sep");
		case 10: strcopy(monthName, sizeof(monthName), "Oct");
		case 11: strcopy(monthName, sizeof(monthName), "Nov");
		case 12: strcopy(monthName, sizeof(monthName), "Dec");
		default: strcopy(monthName, sizeof(monthName), parts[1]);
	}

	Format(out, maxLength, "%s. %s %s", parts[2], monthName, parts[0]);
}

int FormatDuration(char[] buffer, int maxLength, float duration)
{
	int hours = RoundToFloor(duration / 3600.0);
	duration -= hours * 3600.0;
	int minutes = RoundToFloor(duration / 60.0);
	duration -= minutes * 60.0;
	int seconds = RoundToFloor(duration);
	duration -= seconds;
	int centiseconds = RoundToFloor(duration * 100.0);

	if (hours > 0)
	{
		return Format(buffer, maxLength, "%02d:%02d:%02d.%02d", hours, minutes, seconds, centiseconds);
	}
	if (minutes > 0)
	{
		return Format(buffer, maxLength, "%02d:%02d.%02d", minutes, seconds, centiseconds);
	}
	return Format(buffer, maxLength, "%02d.%02d", seconds, centiseconds);
}

int FormatDurationDiff(char[] buffer, int maxLength, float duration)
{
	return FormatDuration(buffer, maxLength, duration);
}

void URLEncode(const char[] input, char[] output, int maxLength)
{
	static char hex[] = "0123456789ABCDEF";
	int written = 0;
	for (int i = 0; input[i] != '\0' && written < maxLength - 1; i++)
	{
		int c = input[i];
		if ((c >= 'a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c >= '0' && c <= '9')
			|| c == '-' || c == '_' || c == '.' || c == '~')
		{
			output[written++] = c;
		}
		else if (written < maxLength - 3)
		{
			output[written++] = '%';
			output[written++] = hex[(c >> 4) & 0xF];
			output[written++] = hex[c & 0xF];
		}
	}
	output[written] = '\0';
}
