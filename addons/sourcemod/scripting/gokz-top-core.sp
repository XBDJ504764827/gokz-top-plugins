#include <sourcemod>
#include <SteamWorks>

#include <gokz/top>

#pragma newdecls required
#pragma semicolon 1

#define GOKZ_TOP_VERSION "0.1.0"
#define GOKZ_TOP_DEFAULT_API_BASE_URL "https://staging-api.kzcharm.com"
#define GOKZ_TOP_MAX_URL_LENGTH 512
#define GOKZ_TOP_MAX_BODY_LENGTH 2048
#define GOKZ_TOP_MAX_PATH_LENGTH 128

public Plugin myinfo =
{
	name = "GOKZ Top Core",
	author = "OpenAI",
	description = "API wrapper and shared HTTP utilities for gokz-top plugins",
	version = GOKZ_TOP_VERSION,
	url = "https://gokz.top"
};

ConVar gCV_APIBaseURL;
ConVar gCV_APIKey;
ConVar gCV_ServerGroupKey;
ConVar gCV_RequestTimeout;
ConVar gCV_RetryCount;
ConVar gCV_RetryDelay;
ConVar gCV_Debug;



// =====[ PLUGIN EVENTS ]=====

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int errMax)
{
	CreateNative("GOKZTop_PostJSON", Native_PostJSON);
	CreateNative("GOKZTop_PostSessionEvent", Native_PostSessionEvent);
	RegPluginLibrary("gokz-top-core");

	return APLRes_Success;
}

public void OnPluginStart()
{
	gCV_APIBaseURL = CreateConVar("gokz_top_api_base_url", GOKZ_TOP_DEFAULT_API_BASE_URL,
		"Base URL for the gokz-top API, without a trailing slash.");
	gCV_APIKey = CreateConVar("gokz_top_api_key", "",
		"Optional bearer API key for future authenticated gokz-top endpoints.", FCVAR_PROTECTED);
	gCV_ServerGroupKey = CreateConVar("gokz_top_server_group_key", "",
		"Server group API key sent as X-Server-Group-Key for server/player session endpoints.", FCVAR_PROTECTED);
	gCV_RequestTimeout = CreateConVar("gokz_top_request_timeout", "10",
		"HTTP request timeout in seconds.", _, true, 1.0, true, 60.0);
	gCV_RetryCount = CreateConVar("gokz_top_retry_count", "2",
		"Number of retry attempts after the initial HTTP request fails.", _, true, 0.0, true, 5.0);
	gCV_RetryDelay = CreateConVar("gokz_top_retry_delay", "5.0",
		"Delay in seconds before retrying a failed HTTP request.", _, true, 1.0, true, 30.0);
	gCV_Debug = CreateConVar("gokz_top_debug", "0",
		"Log gokz-top HTTP request attempts and failures.", _, true, 0.0, true, 1.0);

	AutoExecConfig(true, "gokz-top-core");
}



// =====[ NATIVES ]=====

public int Native_PostJSON(Handle plugin, int numParams)
{
	char path[GOKZ_TOP_MAX_PATH_LENGTH];
	GetNativeString(1, path, sizeof(path));

	int bodyLength;
	GetNativeStringLength(2, bodyLength);
	if (bodyLength >= GOKZ_TOP_MAX_BODY_LENGTH)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "JSON body exceeds %d bytes", GOKZ_TOP_MAX_BODY_LENGTH - 1);
		return false;
	}

	char body[GOKZ_TOP_MAX_BODY_LENGTH];
	GetNativeString(2, body, sizeof(body));

	return PostJSON(path, body);
}

public int Native_PostSessionEvent(Handle plugin, int numParams)
{
	char event[GOKZ_TOP_MAX_PATH_LENGTH];
	GetNativeString(1, event, sizeof(event));

	int bodyLength;
	GetNativeStringLength(2, bodyLength);
	if (bodyLength >= GOKZ_TOP_MAX_BODY_LENGTH)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "JSON body exceeds %d bytes", GOKZ_TOP_MAX_BODY_LENGTH - 1);
		return false;
	}

	char body[GOKZ_TOP_MAX_BODY_LENGTH];
	GetNativeString(2, body, sizeof(body));

	return PostSessionEvent(event, body);
}



// =====[ API WRAPPER ]=====

bool PostSessionEvent(const char[] event, const char[] body)
{
	if (!IsValidSessionEvent(event))
	{
		LogError("[gokz-top-core] Invalid player-session event: %s", event);
		return false;
	}

	if (!HasServerGroupKey())
	{
		LogError("[gokz-top-core] Cannot post player-session event '%s': gokz_top_server_group_key is empty", event);
		return false;
	}

	char path[GOKZ_TOP_MAX_PATH_LENGTH];
	Format(path, sizeof(path), "/v1/player-sessions/%s", event);

	return PostJSON(path, body);
}

bool PostJSON(const char[] path, const char[] body)
{
	if (path[0] != '/')
	{
		LogError("[gokz-top-core] API path must begin with '/': %s", path);
		return false;
	}

	DataPack pack = CreateRequestPack(path, body, gCV_RetryCount.IntValue);
	return SendRequestFromPack(pack);
}

bool IsValidSessionEvent(const char[] event)
{
	return StrEqual(event, "connect")
		|| StrEqual(event, "heartbeat")
		|| StrEqual(event, "disconnect");
}

bool HasServerGroupKey()
{
	char serverGroupKey[4];
	gCV_ServerGroupKey.GetString(serverGroupKey, sizeof(serverGroupKey));
	return serverGroupKey[0] != '\0';
}



// =====[ HTTP ]=====

DataPack CreateRequestPack(const char[] path, const char[] body, int retriesRemaining)
{
	DataPack pack = new DataPack();
	pack.WriteString(path);
	pack.WriteString(body);
	pack.WriteCell(retriesRemaining);
	return pack;
}

bool SendRequestFromPack(DataPack pack)
{
	char path[GOKZ_TOP_MAX_PATH_LENGTH];
	char body[GOKZ_TOP_MAX_BODY_LENGTH];
	int retriesRemaining;
	ReadRequestPack(pack, path, sizeof(path), body, sizeof(body), retriesRemaining);

	char url[GOKZ_TOP_MAX_URL_LENGTH];
	if (!BuildAPIURL(path, url, sizeof(url)))
	{
		delete pack;
		return false;
	}

	Handle request = SteamWorks_CreateHTTPRequest(k_EHTTPMethodPOST, url);
	if (request == null)
	{
		LogError("[gokz-top-core] Failed to create HTTP request for %s", path);
		RetryOrDelete(path, body, retriesRemaining, "create-request");
		delete pack;
		return false;
	}

	SteamWorks_SetHTTPRequestContextValue(request, pack);
	SteamWorks_SetHTTPCallbacks(request, OnHTTPComplete);
	SteamWorks_SetHTTPRequestHeaderValue(request, "Accept", "application/json");
	SteamWorks_SetHTTPRequestHeaderValue(request, "Content-Type", "application/json");
	SteamWorks_SetHTTPRequestHeaderValue(request, "X-Request-Origin", "gokz-top-core/" ... GOKZ_TOP_VERSION);
	SteamWorks_SetHTTPRequestRawPostBody(request, "application/json", body, strlen(body));
	SteamWorks_SetHTTPRequestAbsoluteTimeoutMS(request, gCV_RequestTimeout.IntValue * 1000);
	ApplyAuthHeaders(request);

	if (gCV_Debug.BoolValue)
	{
		LogMessage("[gokz-top-core] POST %s retries_remaining=%d", path, retriesRemaining);
	}

	if (!SteamWorks_SendHTTPRequest(request))
	{
		LogError("[gokz-top-core] Failed to send HTTP request for %s", path);
		RetryOrDelete(path, body, retriesRemaining, "send-request");
		delete pack;
		delete request;
		return false;
	}

	return true;
}

public void OnHTTPComplete(Handle request, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, DataPack pack)
{
	char path[GOKZ_TOP_MAX_PATH_LENGTH];
	char body[GOKZ_TOP_MAX_BODY_LENGTH];
	int retriesRemaining;
	ReadRequestPack(pack, path, sizeof(path), body, sizeof(body), retriesRemaining);

	if (IsHTTPResponseOK(failure, requestSuccessful, statusCode))
	{
		if (gCV_Debug.BoolValue)
		{
			LogMessage("[gokz-top-core] POST %s completed status=%d", path, statusCode);
		}

		delete pack;
		delete request;
		return;
	}

	LogHTTPFailure(request, path, failure, requestSuccessful, statusCode, retriesRemaining);
	if (ShouldRetryHTTPFailure(failure, requestSuccessful, statusCode))
	{
		RetryOrDelete(path, body, retriesRemaining, "http-complete");
	}
	else
	{
		LogError("[gokz-top-core] Dropping non-retryable request path=%s status=%d", path, statusCode);
	}

	delete pack;
	delete request;
}

public Action Timer_RetryRequest(Handle timer, DataPack pack)
{
	SendRequestFromPack(pack);
	return Plugin_Stop;
}

void ReadRequestPack(DataPack pack, char[] path, int pathMaxLength, char[] body, int bodyMaxLength, int &retriesRemaining)
{
	pack.Reset();
	pack.ReadString(path, pathMaxLength);
	pack.ReadString(body, bodyMaxLength);
	retriesRemaining = pack.ReadCell();
}

void RetryOrDelete(const char[] path, const char[] body, int retriesRemaining, const char[] reason)
{
	if (retriesRemaining <= 0)
	{
		LogError("[gokz-top-core] Dropping request path=%s reason=%s", path, reason);
		return;
	}

	DataPack retryPack = CreateRequestPack(path, body, retriesRemaining - 1);
	CreateTimer(gCV_RetryDelay.FloatValue, Timer_RetryRequest, retryPack);

	if (gCV_Debug.BoolValue)
	{
		LogMessage("[gokz-top-core] Queued retry path=%s retries_remaining=%d reason=%s",
			path, retriesRemaining - 1, reason);
	}
}

bool IsHTTPResponseOK(bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	return !failure
		&& requestSuccessful
		&& statusCode >= k_EHTTPStatusCode200OK
		&& statusCode < k_EHTTPStatusCode300MultipleChoices;
}

bool ShouldRetryHTTPFailure(bool failure, bool requestSuccessful, EHTTPStatusCode statusCode)
{
	return failure
		|| !requestSuccessful
		|| statusCode == k_EHTTPStatusCodeInvalid
		|| statusCode == k_EHTTPStatusCode408RequestTimeout
		|| statusCode == k_EHTTPStatusCode429TooManyRequests
		|| statusCode >= k_EHTTPStatusCode500InternalServerError;
}

void LogHTTPFailure(Handle request, const char[] path, bool failure, bool requestSuccessful, EHTTPStatusCode statusCode, int retriesRemaining)
{
	char response[512];
	int responseSize;
	if (SteamWorks_GetHTTPResponseBodySize(request, responseSize) && responseSize > 0)
	{
		SteamWorks_GetHTTPResponseBodyData(request, response, sizeof(response));
	}

	LogError("[gokz-top-core] POST %s failed failure=%d request_successful=%d status=%d retries_remaining=%d response=%s",
		path, failure, requestSuccessful, statusCode, retriesRemaining, response);
}

void ApplyAuthHeaders(Handle request)
{
	char serverGroupKey[256];
	gCV_ServerGroupKey.GetString(serverGroupKey, sizeof(serverGroupKey));
	if (serverGroupKey[0] != '\0')
	{
		SteamWorks_SetHTTPRequestHeaderValue(request, "X-Server-Group-Key", serverGroupKey);
	}

	char apiKey[256];
	gCV_APIKey.GetString(apiKey, sizeof(apiKey));
	if (apiKey[0] != '\0')
	{
		char bearer[288];
		Format(bearer, sizeof(bearer), "Bearer %s", apiKey);
		SteamWorks_SetHTTPRequestHeaderValue(request, "Authorization", bearer);
	}
}

bool BuildAPIURL(const char[] path, char[] url, int maxLength)
{
	char baseURL[256];
	gCV_APIBaseURL.GetString(baseURL, sizeof(baseURL));

	if (baseURL[0] == '\0')
	{
		LogError("[gokz-top-core] gokz_top_api_base_url is empty");
		return false;
	}

	int length = strlen(baseURL);
	if (length > 0 && baseURL[length - 1] == '/')
	{
		baseURL[length - 1] = '\0';
	}

	Format(url, maxLength, "%s%s", baseURL, path);
	return true;
}
