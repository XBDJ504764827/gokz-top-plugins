void FindSharedConVars()
{
	gCV_APIBaseURL = FindConVar("gokz_top_api_base_url");
	gCV_APIKey = FindConVar("gokz_top_api_key");
	gCV_ServerGroupKey = FindConVar("gokz_top_server_group_key");
	gCV_RequestTimeout = FindConVar("gokz_top_request_timeout");
}

void ReviewLog(const char[] fmt, any ...)
{
	char buffer[512];
	VFormat(buffer, sizeof(buffer), fmt, 2);
	PrintToServer("[gokz-top-reviews] %s", buffer);
	LogMessage("[gokz-top-reviews] %s", buffer);
}

void BuildLogSnippet(const char[] input, char[] out, int maxlen)
{
	out[0] = '\0';

	int outPos = 0;
	for (int i = 0; input[i] != '\0' && outPos + 1 < maxlen; i++)
	{
		char c = input[i];
		if (c == '\r' || c == '\n' || c == '\t')
		{
			if (outPos + 1 < maxlen)
			{
				out[outPos++] = ' ';
			}
			continue;
		}

		out[outPos++] = c;
	}

	out[outPos] = '\0';
}

void GetReviewRequestTypeLabel(int type, char[] out, int maxlen)
{
	switch (type)
	{
		case ReviewRequestType_MapInfo:
		{
			strcopy(out, maxlen, "map_info");
			return;
		}
		case ReviewRequestType_MyReview:
		{
			strcopy(out, maxlen, "my_review");
			return;
		}
		case ReviewRequestType_SubmitReview:
		{
			strcopy(out, maxlen, "submit_review");
			return;
		}
		case ReviewRequestType_Comments:
		{
			strcopy(out, maxlen, "comments");
			return;
		}
	}

	strcopy(out, maxlen, "unknown");
}

bool BuildAPIURL(char[] out, int maxlen, const char[] path, const char[] query = "")
{
	out[0] = '\0';

	if (gCV_APIBaseURL == null)
	{
		return false;
	}

	char base[256];
	gCV_APIBaseURL.GetString(base, sizeof(base));
	TrimString(base);
	TrimTrailingSlash(base);
	if (base[0] == '\0')
	{
		return false;
	}

	bool baseHasV1 = EndsWithIgnoreCase(base, "/v1");
	bool baseHasApiV1 = EndsWithIgnoreCase(base, "/api/v1");

	char suffix[256];
	strcopy(suffix, sizeof(suffix), path);
	if ((baseHasV1 || baseHasApiV1) && StrContains(path, "/v1/", false) == 0)
	{
		strcopy(suffix, sizeof(suffix), path[3]);
	}

	if (query[0] != '\0')
	{
		Format(out, maxlen, "%s%s?%s", base, suffix, query);
	}
	else
	{
		Format(out, maxlen, "%s%s", base, suffix);
	}

	return true;
}

Handle CreateAPIRequest(EHTTPMethod method, const char[] url, const char[] jsonBody = "")
{
	Handle request = SteamWorks_CreateHTTPRequest(method, url);
	if (request == INVALID_HANDLE)
	{
		ReviewLog("event=create_request_failed url=%s", url);
		return INVALID_HANDLE;
	}

	SteamWorks_SetHTTPRequestHeaderValue(request, "Accept", "application/json");
	SteamWorks_SetHTTPRequestHeaderValue(request, "User-Agent", "gokz-top-reviews/" ... GOKZ_VERSION);
	SteamWorks_SetHTTPRequestUserAgentInfo(request, "gokz-top-reviews/" ... GOKZ_VERSION);
	SteamWorks_SetHTTPRequestHeaderValue(request, "X-Request-Origin", "gokz-top-reviews/" ... GOKZ_VERSION);
	SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, GetRequestTimeoutMS());
	ApplyAuthHeaders(request);

	if (jsonBody[0] != '\0')
	{
		SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");
		if (!SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", jsonBody, strlen(jsonBody)))
		{
			ReviewLog("event=set_post_body_failed url=%s", url);
			delete request;
			return INVALID_HANDLE;
		}
	}

	return request;
}

bool DispatchRequest(Handle request, int userId, int type, int flags = 0)
{
	if (request == INVALID_HANDLE)
	{
		return false;
	}

	SteamWorks_SetHTTPRequestContextValue(request, userId, (view_as<int>(type) & 0xFF) | ((flags & 0xFF) << 8));
	SteamWorks_SetHTTPCallbacks(request, OnHTTPCompleted);
	bool sent = SteamWorks_SendHTTPRequest(request);
	char typeLabel[32];
	GetReviewRequestTypeLabel(type, typeLabel, sizeof(typeLabel));
	ReviewLog(
		"event=dispatch type=%s userid=%d flags=%d sent=%d",
		typeLabel,
		userId,
		flags,
		sent
	);
	return sent;
}

void ApplyAuthHeaders(Handle request)
{
	if (request == INVALID_HANDLE)
	{
		return;
	}

	char serverGroupKey[256];
	serverGroupKey[0] = '\0';
	if (gCV_ServerGroupKey != null)
	{
		gCV_ServerGroupKey.GetString(serverGroupKey, sizeof(serverGroupKey));
	}

	if (serverGroupKey[0] != '\0')
	{
		SteamWorks_SetHTTPRequestHeaderValue(request, "X-Server-Group-Key", serverGroupKey);
	}
}

int GetRequestTimeoutMS()
{
	if (gCV_RequestTimeout == null)
	{
		return 10000;
	}

	return gCV_RequestTimeout.IntValue * 1000;
}

bool HasServerGroupKey()
{
	if (gCV_ServerGroupKey == null)
	{
		return false;
	}

	char serverGroupKey[4];
	gCV_ServerGroupKey.GetString(serverGroupKey, sizeof(serverGroupKey));
	return serverGroupKey[0] != '\0';
}

void LogAuthMode()
{
	char base[256];
	base[0] = '\0';
	if (gCV_APIBaseURL != null)
	{
		gCV_APIBaseURL.GetString(base, sizeof(base));
	}

	bool hasServerGroupKey = HasServerGroupKey();
	bool hasAPIKey = false;
	if (gCV_APIKey != null)
	{
		char apiKey[4];
		gCV_APIKey.GetString(apiKey, sizeof(apiKey));
		hasAPIKey = apiKey[0] != '\0';
	}

	ReviewLog(
		"event=auth_mode base_url=%s server_group_key=%d api_key=%d authorization_header=0",
		base,
		hasServerGroupKey,
		hasAPIKey
	);
}

bool ReadResponseBody(Handle request, char[] out, int maxlen)
{
	out[0] = '\0';
	if (request == INVALID_HANDLE)
	{
		return false;
	}

	int size = 0;
	if (!SteamWorks_GetHTTPResponseBodySize(request, size) || size <= 0)
	{
		return false;
	}

	if (size >= maxlen)
	{
		size = maxlen - 1;
	}

	bool ok = SteamWorks_GetHTTPResponseBodyData(request, out, size);
	out[size] = '\0';
	return ok;
}

bool LooksLikeJson(const char[] body)
{
	int i = 0;
	while (body[i] == ' ' || body[i] == '\t' || body[i] == '\r' || body[i] == '\n')
	{
		i++;
	}

	return body[i] == '{' || body[i] == '[';
}

void URLEncode(const char[] input, char[] output, int maxlen)
{
	output[0] = '\0';

	int outLen = 0;
	for (int i = 0; input[i] != '\0' && outLen + 1 < maxlen; i++)
	{
		int c = input[i] & 0xFF;
		bool safe = (c >= 'a' && c <= 'z')
			|| (c >= 'A' && c <= 'Z')
			|| (c >= '0' && c <= '9')
			|| c == '-'
			|| c == '_'
			|| c == '.'
			|| c == '~';

		if (safe)
		{
			output[outLen++] = view_as<char>(c);
			output[outLen] = '\0';
			continue;
		}

		if (outLen + 3 >= maxlen)
		{
			break;
		}

		static const char hex[] = "0123456789ABCDEF";
		output[outLen++] = '%';
		output[outLen++] = hex[(c >> 4) & 0xF];
		output[outLen++] = hex[c & 0xF];
		output[outLen] = '\0';
	}
}

void EscapeJSONString(const char[] input, char[] output, int maxlen)
{
	output[0] = '\0';

	int outLen = 0;
	for (int i = 0; input[i] != '\0' && outLen + 1 < maxlen; i++)
	{
		char c = input[i];
		if (c == '"' || c == '\\')
		{
			if (outLen + 2 >= maxlen)
			{
				break;
			}
			output[outLen++] = '\\';
			output[outLen++] = c;
		}
		else if (c == '\n')
		{
			if (outLen + 2 >= maxlen)
			{
				break;
			}
			output[outLen++] = '\\';
			output[outLen++] = 'n';
		}
		else if (c == '\r')
		{
			if (outLen + 2 >= maxlen)
			{
				break;
			}
			output[outLen++] = '\\';
			output[outLen++] = 'r';
		}
		else if (c == '\t')
		{
			if (outLen + 2 >= maxlen)
			{
				break;
			}
			output[outLen++] = '\\';
			output[outLen++] = 't';
		}
		else
		{
			output[outLen++] = c;
		}
	}

	output[outLen] = '\0';
}

void TrimTrailingSlash(char[] value)
{
	int len = strlen(value);
	while (len > 0 && value[len - 1] == '/')
	{
		value[--len] = '\0';
	}
}

bool EndsWithIgnoreCase(const char[] value, const char[] suffix)
{
	int valueLen = strlen(value);
	int suffixLen = strlen(suffix);
	if (suffixLen > valueLen)
	{
		return false;
	}

	return StrEqual(value[valueLen - suffixLen], suffix, false);
}

int JsonGetOptionalInt(const char[] json, const char[] key)
{
	int value = 0;
	return ExtractJsonInt(json, key, value) ? value : 0;
}

float JsonGetOptionalFloat(const char[] json, const char[] key, float defaultValue = -1.0)
{
	float value = defaultValue;
	return ExtractJsonFloat(json, key, value) ? value : defaultValue;
}

void JsonGetOptionalString(const char[] json, const char[] key, char[] out, int maxlen)
{
	out[0] = '\0';
	ExtractJsonString(json, key, out, maxlen);
}

void ExtractErrorDetail(const char[] body, char[] out, int maxlen)
{
	out[0] = '\0';
	if (body[0] == '\0' || !LooksLikeJson(body))
	{
		return;
	}

	ExtractJsonString(body, "detail", out, maxlen);
}

public void OnHTTPCompleted(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, any data1, any data2)
{
	int userId = data1;
	int requestType = data2 & 0xFF;
	int requestFlags = (data2 >> 8) & 0xFF;
	int client = GetClientOfUserId(userId);
	int status = view_as<int>(statusCode);

	char body[4096];
	ReadResponseBody(request, body, sizeof(body));

	char snippet[512];
	BuildLogSnippet(body, snippet, sizeof(snippet));
	char typeLabel[32];
	GetReviewRequestTypeLabel(requestType, typeLabel, sizeof(typeLabel));
	ReviewLog(
		"event=http_complete type=%s userid=%d status=%d failure=%d request_successful=%d body=%s",
		typeLabel,
		userId,
		status,
		failure,
		requestSuccessful,
		snippet
	);

	if (request != INVALID_HANDLE)
	{
		delete request;
	}

	bool ok = !failure && requestSuccessful && status >= 200 && status < 300;
	if (!ok)
	{
		HandleRequestFailure(requestType, client, status, body);
		return;
	}

	switch (requestType)
	{
		case ReviewRequestType_MapInfo:
		{
			HandleCurrentMapInfoSuccess(body);
		}
		case ReviewRequestType_MyReview:
		{
			if (IsValidClientForReview(client))
			{
				HandleMyReviewSuccess(client, body);
			}
		}
		case ReviewRequestType_SubmitReview:
		{
			if (IsValidClientForReview(client))
			{
				HandleSubmitReviewSuccess(client, requestFlags);
			}
		}
		case ReviewRequestType_Comments:
		{
			if (IsValidClientForReview(client))
			{
				HandleCommentsSuccess(client, body);
			}
		}
	}
}

void HandleRequestFailure(int requestType, int client, int status, const char[] body)
{
	char snippet[512];
	BuildLogSnippet(body, snippet, sizeof(snippet));
	char typeLabel[32];
	GetReviewRequestTypeLabel(requestType, typeLabel, sizeof(typeLabel));
	ReviewLog(
		"event=request_failure type=%s client=%d status=%d body=%s",
		typeLabel,
		client,
		status,
		snippet
	);

	if (requestType == ReviewRequestType_MapInfo)
	{
		gB_CurrentMapInfoInFlight = false;
		FailPendingSubmissionsAfterMapInfo();
		return;
	}

	if (!IsValidClientForReview(client))
	{
		return;
	}

	if (requestType == ReviewRequestType_MyReview)
	{
		gB_MyReviewFetched[client] = true;
		gB_RatePromptPending[client] = false;
		gF_RatePromptRequestedAt[client] = 0.0;
		TryShowMenuWhenReady(client);
	}
	else if (requestType == ReviewRequestType_SubmitReview)
	{
		gB_SubmitInFlight[client] = false;
		gB_SubmitPendingAfterMapInfo[client] = false;
	}

	char detail[256];
	ExtractErrorDetail(body, detail, sizeof(detail));
	if (detail[0] != '\0')
	{
		ReviewPrintToChat(client, "{red}%s", detail);
		return;
	}

	if (body[0] != '\0' && !LooksLikeJson(body))
	{
		ReviewPrintToChat(client, "%t", "Reviews Error - NonJson", status);
		return;
	}

	ReviewPrintToChat(client, "%t", "Reviews Error - HttpGeneric", status);
}

bool ExtractFirstObjectFromRootArray(const char[] json, char[] out, int maxlen)
{
	int pos = 0;
	if (!FindNextChar(json, pos, '[', pos))
	{
		return false;
	}

	return ExtractNextObjectFromArray(json, pos, out, maxlen);
}

bool ExtractFirstObjectFromNamedArray(const char[] json, const char[] key, char[] out, int maxlen)
{
	int pos;
	if (!FindJsonValueStart(json, key, pos) || json[pos] != '[')
	{
		return false;
	}

	return ExtractNextObjectFromArray(json, pos, out, maxlen);
}

bool ExtractNextObjectFromArray(const char[] json, int &cursor, char[] out, int maxlen)
{
	int length = strlen(json);
	int pos = cursor;
	while (pos < length && json[pos] != '{')
	{
		pos++;
	}

	if (pos >= length)
	{
		return false;
	}

	bool ok = ExtractBalancedSlice(json, pos, '{', '}', out, maxlen, cursor);
	return ok;
}

bool ExtractJsonObject(const char[] json, const char[] key, char[] out, int maxlen)
{
	int pos;
	if (!FindJsonValueStart(json, key, pos) || json[pos] != '{')
	{
		return false;
	}

	int nextPos;
	return ExtractBalancedSlice(json, pos, '{', '}', out, maxlen, nextPos);
}

bool ExtractJsonArray(const char[] json, const char[] key, char[] out, int maxlen)
{
	int pos;
	if (!FindJsonValueStart(json, key, pos) || json[pos] != '[')
	{
		return false;
	}

	int nextPos;
	return ExtractBalancedSlice(json, pos, '[', ']', out, maxlen, nextPos);
}

bool ExtractJsonString(const char[] json, const char[] key, char[] out, int maxlen)
{
	out[0] = '\0';

	int pos;
	if (!FindJsonValueStart(json, key, pos))
	{
		return false;
	}

	if (json[pos] != '"')
	{
		return false;
	}

	pos++;
	int outPos = 0;
	while (json[pos] != '\0' && outPos + 1 < maxlen)
	{
		char c = json[pos++];
		if (c == '"')
		{
			out[outPos] = '\0';
			return true;
		}
		if (c == '\\')
		{
			char escaped = json[pos++];
			switch (escaped)
			{
				case '"', '\\', '/':
				{
					out[outPos++] = escaped;
				}
				case 'n':
				{
					out[outPos++] = '\n';
				}
				case 'r':
				{
					out[outPos++] = '\r';
				}
				case 't':
				{
					out[outPos++] = '\t';
				}
				default:
				{
					out[outPos++] = escaped;
				}
			}
			continue;
		}

		out[outPos++] = c;
	}

	out[outPos] = '\0';
	return out[0] != '\0';
}

bool ExtractJsonInt(const char[] json, const char[] key, int &value)
{
	value = 0;
	int pos;
	if (!FindJsonValueStart(json, key, pos))
	{
		return false;
	}

	char number[32];
	if (!ExtractNumberToken(json, pos, number, sizeof(number)))
	{
		return false;
	}

	value = StringToInt(number);
	return true;
}

bool ExtractJsonFloat(const char[] json, const char[] key, float &value)
{
	int pos;
	if (!FindJsonValueStart(json, key, pos))
	{
		return false;
	}

	char number[32];
	if (!ExtractNumberToken(json, pos, number, sizeof(number)))
	{
		return false;
	}

	value = StringToFloat(number);
	return true;
}

bool ExtractNumberToken(const char[] json, int pos, char[] out, int maxlen)
{
	int outPos = 0;
	while (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')
	{
		pos++;
	}

	if (json[pos] == '-' && outPos + 1 < maxlen)
	{
		out[outPos++] = json[pos++];
	}

	bool hasDigit = false;
	while (json[pos] != '\0' && outPos + 1 < maxlen)
	{
		char c = json[pos];
		if ((c >= '0' && c <= '9') || c == '.')
		{
			out[outPos++] = c;
			hasDigit = true;
			pos++;
			continue;
		}
		break;
	}

	out[outPos] = '\0';
	return hasDigit;
}

bool FindJsonValueStart(const char[] json, const char[] key, int &pos)
{
	char needle[96];
	Format(needle, sizeof(needle), "\"%s\"", key);

	pos = StrContains(json, needle);
	if (pos == -1)
	{
		return false;
	}

	pos += strlen(needle);
	while (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')
	{
		pos++;
	}
	if (json[pos] != ':')
	{
		return false;
	}
	pos++;
	while (json[pos] == ' ' || json[pos] == '\t' || json[pos] == '\r' || json[pos] == '\n')
	{
		pos++;
	}
	return true;
}

bool FindNextChar(const char[] json, int start, char target, int &pos)
{
	int length = strlen(json);
	for (pos = start; pos < length; pos++)
	{
		if (json[pos] == target)
		{
			return true;
		}
	}
	return false;
}

bool ExtractBalancedSlice(const char[] json, int start, char openChar, char closeChar, char[] out, int maxlen, int &nextPos)
{
	int length = strlen(json);
	if (start < 0 || start >= length || json[start] != openChar)
	{
		return false;
	}

	bool inString = false;
	bool escaped = false;
	int depth = 0;
	int pos = start;
	for (; pos < length; pos++)
	{
		char c = json[pos];
		if (inString)
		{
			if (escaped)
			{
				escaped = false;
			}
			else if (c == '\\')
			{
				escaped = true;
			}
			else if (c == '"')
			{
				inString = false;
			}
			continue;
		}

		if (c == '"')
		{
			inString = true;
			continue;
		}
		if (c == openChar)
		{
			depth++;
		}
		else if (c == closeChar)
		{
			depth--;
			if (depth == 0)
			{
				int sliceLen = pos - start + 1;
				if (sliceLen >= maxlen)
				{
					sliceLen = maxlen - 1;
				}
				strcopy(out, maxlen, json[start]);
				out[sliceLen] = '\0';
				nextPos = pos + 1;
				return true;
			}
		}
	}

	return false;
}
