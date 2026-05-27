// =====[ RESPONSE PARSING ]=====

bool ParseMapTiersResponse(const char[] body, int &kztTier, int &skzTier, int &vnlTier)
{
	kztTier = 0;
	skzTier = 0;
	vnlTier = 0;

	return ExtractJSONInt(body, "KZT", kztTier)
		&& ExtractJSONInt(body, "SKZ", skzTier)
		&& ExtractJSONInt(body, "VNL", vnlTier);
}

bool ParseWRResponse(const char[] body, float &wrTime)
{
	wrTime = -1.0;

	return ExtractJSONFloat(body, "time", wrTime);
}

bool ParsePBResponse(const char[] body, float &pbTime, int &pbPoints, char[] createdOn, int createdOnLength)
{
	pbTime = -1.0;
	pbPoints = 0;
	createdOn[0] = '\0';

	return ExtractJSONFloat(body, "time", pbTime)
		&& ExtractJSONInt(body, "points", pbPoints)
		&& ExtractJSONString(body, "created_on", createdOn, createdOnLength);
}

bool ExtractJSONInt(const char[] body, const char[] key, int &value)
{
	char token[64];
	if (!ExtractJSONRawValue(body, key, token, sizeof(token)))
	{
		return false;
	}

	value = StringToInt(token);
	return true;
}

bool ExtractJSONFloat(const char[] body, const char[] key, float &value)
{
	char token[64];
	if (!ExtractJSONRawValue(body, key, token, sizeof(token)))
	{
		return false;
	}

	value = StringToFloat(token);
	return true;
}

bool ExtractJSONString(const char[] body, const char[] key, char[] value, int valueLength)
{
	int pos = FindJSONValueStart(body, key);
	if (pos == -1 || body[pos] != '"')
	{
		return false;
	}

	pos++;
	int out = 0;
	int bodyLength = strlen(body);
	while (pos < bodyLength && body[pos] != '"' && out < valueLength - 1)
	{
		if (body[pos] == '\\' && pos + 1 < bodyLength)
		{
			pos++;
		}

		value[out++] = body[pos++];
	}

	value[out] = '\0';
	return out > 0;
}

bool ExtractJSONRawValue(const char[] body, const char[] key, char[] value, int valueLength)
{
	int pos = FindJSONValueStart(body, key);
	if (pos == -1)
	{
		return false;
	}

	int out = 0;
	int bodyLength = strlen(body);
	while (pos < bodyLength && out < valueLength - 1)
	{
		char c = body[pos];
		if (c == ',' || c == '}' || c == ']' || IsRecordJSONSpace(c))
		{
			break;
		}

		value[out++] = c;
		pos++;
	}

	value[out] = '\0';
	return out > 0;
}

int FindJSONValueStart(const char[] body, const char[] key)
{
	char pattern[64];
	Format(pattern, sizeof(pattern), "\"%s\"", key);

	int pos = StrContains(body, pattern, false);
	if (pos == -1)
	{
		return -1;
	}

	pos += strlen(pattern);
	int bodyLength = strlen(body);
	while (pos < bodyLength && IsRecordJSONSpace(body[pos]))
	{
		pos++;
	}

	if (pos >= bodyLength || body[pos] != ':')
	{
		return -1;
	}

	pos++;
	while (pos < bodyLength && IsRecordJSONSpace(body[pos]))
	{
		pos++;
	}

	if (pos >= bodyLength)
	{
		return -1;
	}

	return pos;
}

bool IsRecordJSONSpace(char c)
{
	return c == ' ' || c == '\t' || c == '\r' || c == '\n';
}
