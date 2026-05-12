void LoadPublicIPCache()
{
	char cachePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cachePath, sizeof(cachePath), GOKZ_TOP_SERVERS_CACHE_PATH);
	if (!FileExists(cachePath))
	{
		ClearPublicIPCache();
		return;
	}

	char buffer[256];
	if (!ReadFileToString(cachePath, buffer, sizeof(buffer)))
	{
		ClearPublicIPCache();
		return;
	}

	char publicIP[GOKZ_TOP_PUBLIC_IP_LENGTH];
	publicIP[0] = '\0';
	if (!ExtractJSONStringField(buffer, "public_ip", publicIP, sizeof(publicIP)))
	{
		ClearPublicIPCache();
		return;
	}

	int lastRefresh;
	if (!ExtractJSONIntField(buffer, "last_refresh", lastRefresh))
	{
		ClearPublicIPCache();
		return;
	}

	if (!IsUsablePublicIPv4(publicIP) || lastRefresh <= 0)
	{
		ClearPublicIPCache();
		return;
	}

	if ((GetTime() - lastRefresh) >= GOKZ_TOP_PUBLIC_IP_MAX_AGE)
	{
		ClearPublicIPCache();
		return;
	}

	strcopy(gC_PublicIP, sizeof(gC_PublicIP), publicIP);
	gI_PublicIPLastRefresh = lastRefresh;
}

void PersistPublicIPCache()
{
	char cacheDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cacheDir, sizeof(cacheDir), GOKZ_TOP_SERVERS_CACHE_DIR);
	if (!DirExists(cacheDir))
	{
		CreateDirectory(cacheDir, 511);
	}

	char encoded[256];
	Format(encoded, sizeof(encoded),
		"{\"public_ip\":\"%s\",\"last_refresh\":%d}",
		gC_PublicIP,
		gI_PublicIPLastRefresh);

	char cachePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, cachePath, sizeof(cachePath), GOKZ_TOP_SERVERS_CACHE_PATH);

	File file = OpenFile(cachePath, "w");
	if (file != null)
	{
		file.WriteString(encoded, false);
		delete file;
	}

}

void SetPublicIPCache(const char[] publicIP, int refreshedAt)
{
	strcopy(gC_PublicIP, sizeof(gC_PublicIP), publicIP);
	gI_PublicIPLastRefresh = refreshedAt;
	PersistPublicIPCache();
}

void ClearPublicIPCache()
{
	gC_PublicIP[0] = '\0';
	gI_PublicIPLastRefresh = 0;
}

bool ReadFileToString(const char[] path, char[] buffer, int maxLength)
{
	File file = OpenFile(path, "r");
	if (file == null)
	{
		return false;
	}

	buffer[0] = '\0';
	char line[192];
	while (!file.EndOfFile() && file.ReadLine(line, sizeof(line)))
	{
		TrimString(line);
		StrCat(buffer, maxLength, line);
	}

	delete file;
	return buffer[0] != '\0';
}

bool ExtractJSONStringField(const char[] json, const char[] key, char[] buffer, int maxLength)
{
	char pattern[64];
	Format(pattern, sizeof(pattern), "\"%s\"", key);

	int start = StrContains(json, pattern);
	if (start == -1)
	{
		return false;
	}

	start += strlen(pattern);
	while (json[start] == ' ' || json[start] == '\t' || json[start] == '\n' || json[start] == '\r')
	{
		start++;
	}

	if (json[start] != ':')
	{
		return false;
	}
	start++;

	while (json[start] == ' ' || json[start] == '\t' || json[start] == '\n' || json[start] == '\r')
	{
		start++;
	}

	if (json[start] != '"')
	{
		return false;
	}
	start++;

	int written = 0;
	while (json[start] != '\0' && json[start] != '"' && written < maxLength - 1)
	{
		buffer[written++] = json[start++];
	}
	buffer[written] = '\0';

	return json[start] == '"';
}

bool ExtractJSONIntField(const char[] json, const char[] key, int &value)
{
	char pattern[64];
	Format(pattern, sizeof(pattern), "\"%s\"", key);

	int start = StrContains(json, pattern);
	if (start == -1)
	{
		return false;
	}

	start += strlen(pattern);
	while (json[start] == ' ' || json[start] == '\t' || json[start] == '\n' || json[start] == '\r')
	{
		start++;
	}

	if (json[start] != ':')
	{
		return false;
	}
	start++;

	while (json[start] == ' ' || json[start] == '\t' || json[start] == '\n' || json[start] == '\r')
	{
		start++;
	}

	char number[32];
	int written = 0;
	while (json[start] != '\0'
		&& json[start] != ','
		&& json[start] != '}'
		&& written < sizeof(number) - 1)
	{
		number[written++] = json[start++];
	}
	number[written] = '\0';
	TrimString(number);

	if (number[0] == '\0')
	{
		return false;
	}

	value = StringToInt(number);
	return true;
}
