bool IsClientReadyForSession(int client)
{
	return client > 0
		&& client <= MaxClients
		&& IsClientInGame(client)
		&& !IsFakeClient(client)
		&& IsClientAuthorized(client);
}

void GOKZTopPlayers_GetClientIPv4(int client, char[] buffer, int maxLength)
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

void GOKZTopPlayers_GetClientLanguageCode(int client, char[] buffer, int maxLength)
{
	int language = GetClientLanguage(client);
	if (language < 0)
	{
		GOKZTopPlayers_GetServerLanguageCode(buffer, maxLength);
		return;
	}

	GetLanguageInfo(language, buffer, maxLength);
	GOKZTopPlayers_NormalizeClientLanguage(buffer, buffer, maxLength);
	if (buffer[0] == '\0')
	{
		GOKZTopPlayers_GetServerLanguageCode(buffer, maxLength);
	}
}

void GOKZTopPlayers_GetServerLanguageCode(char[] buffer, int maxLength)
{
	int language = GetServerLanguage();
	if (language < 0)
	{
		strcopy(buffer, maxLength, "en");
		return;
	}

	GetLanguageInfo(language, buffer, maxLength);
	GOKZTopPlayers_NormalizeClientLanguage(buffer, buffer, maxLength);
	if (buffer[0] == '\0')
	{
		strcopy(buffer, maxLength, "en");
	}
}

void GOKZTopPlayers_NormalizeClientLanguage(const char[] input, char[] buffer, int maxLength)
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

void GOKZTopPlayers_FormatLocalISOTime(char[] buffer, int maxLength)
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

void GOKZTopPlayers_EscapeJSONString(const char[] input, char[] output, int maxLength)
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

bool GOKZTopPlayers_ExtractJsonBool(const char[] json, const char[] key, bool &value)
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
