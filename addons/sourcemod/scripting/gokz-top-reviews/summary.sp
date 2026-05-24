void FetchCurrentMapInfo()
{
	if (gB_CurrentMapInfoInFlight)
	{
		ReviewLog("event=fetch_map_info_skipped reason=in_flight map=%s", gC_CurrentMapName);
		return;
	}

	char encodedMapName[PLATFORM_MAX_PATH * 3];
	URLEncode(gC_CurrentMapName, encodedMapName, sizeof(encodedMapName));

	char query[512];
	Format(query, sizeof(query), "name=%s&limit=1", encodedMapName);

	char url[1024];
	if (!BuildAPIURL(url, sizeof(url), "/v1/maps", query))
	{
		ReviewLog("event=fetch_map_info_aborted reason=missing_base_url map=%s", gC_CurrentMapName);
		return;
	}

	LogAuthMode();
	ReviewLog("event=fetch_map_info map=%s url=%s", gC_CurrentMapName, url);

	Handle request = CreateAPIRequest(k_EHTTPMethodGET, url);
	if (request == INVALID_HANDLE || !DispatchRequest(request, 0, ReviewRequestType_MapInfo))
	{
		if (request != INVALID_HANDLE)
		{
			delete request;
		}
		return;
	}

	gB_CurrentMapInfoInFlight = true;
}

public Action Timer_PrintSummary(Handle timer, any userId)
{
	int client = GetClientOfUserId(userId);
	if (!IsValidClientForReview(client))
	{
		return Plugin_Stop;
	}

	if (!gB_CurrentMapInfoFetched)
	{
		if (!gB_CurrentMapInfoInFlight)
		{
			FetchCurrentMapInfo();
		}

		if (gI_SummaryPrintAttempts[client] < 3)
		{
			gI_SummaryPrintAttempts[client]++;
			CreateTimer(2.0, Timer_PrintSummary, userId);
		}
		return Plugin_Stop;
	}

	PrintCurrentMapSummary(client);
	return Plugin_Stop;
}

void HandleCurrentMapInfoSuccess(const char[] body)
{
	gB_CurrentMapInfoInFlight = false;
	gB_CurrentMapInfoFetched = true;
	gI_CurrentMapID = 0;
	gF_CurrentMapOverallAvg = -1.0;
	gF_CurrentMapGameplayAvg = -1.0;
	gF_CurrentMapVisualsAvg = -1.0;
	gI_CurrentMapReviewsCount = 0;
	gI_CurrentMapGameplayCount = 0;
	gI_CurrentMapVisualsCount = 0;
	gI_CurrentMapCommentsCount = 0;

	if (!LooksLikeJson(body))
	{
		ResumePendingSubmissionsAfterMapInfo();
		return;
	}

	char mapRow[4096];
	if (!ExtractFirstObjectFromRootArray(body, mapRow, sizeof(mapRow)))
	{
		ResumePendingSubmissionsAfterMapInfo();
		return;
	}

	gI_CurrentMapID = JsonGetOptionalInt(mapRow, "id");

	char reviewSummary[512];
	if (ExtractJsonObject(mapRow, "review_summary", reviewSummary, sizeof(reviewSummary)))
	{
		gF_CurrentMapOverallAvg = JsonGetOptionalFloat(reviewSummary, "overall_avg");
		gF_CurrentMapGameplayAvg = JsonGetOptionalFloat(reviewSummary, "gameplay_avg");
		gF_CurrentMapVisualsAvg = JsonGetOptionalFloat(reviewSummary, "visuals_avg");
		gI_CurrentMapReviewsCount = JsonGetOptionalInt(reviewSummary, "reviews_count");
		gI_CurrentMapGameplayCount = JsonGetOptionalInt(reviewSummary, "gameplay_count");
		gI_CurrentMapVisualsCount = JsonGetOptionalInt(reviewSummary, "visuals_count");
		gI_CurrentMapCommentsCount = JsonGetOptionalInt(reviewSummary, "comments_count");
	}

	ReviewLog(
		"event=map_info_success map=%s map_id=%d overall_avg=%.2f gameplay_avg=%.2f gameplay_count=%d visuals_avg=%.2f visuals_count=%d reviews=%d comments=%d",
		gC_CurrentMapName,
		gI_CurrentMapID,
		gF_CurrentMapOverallAvg,
		gF_CurrentMapGameplayAvg,
		gI_CurrentMapGameplayCount,
		gF_CurrentMapVisualsAvg,
		gI_CurrentMapVisualsCount,
		gI_CurrentMapReviewsCount,
		gI_CurrentMapCommentsCount
	);
	ResumePendingSubmissionsAfterMapInfo();
}

void PrintCurrentMapSummary(int client)
{
	if (!IsValidClientForReview(client) || gI_CurrentMapID <= 0)
	{
		return;
	}

	if (gI_CurrentMapReviewsCount <= 0 || gF_CurrentMapOverallAvg < 0.0)
	{
		ReviewPrintToChat(client, "%t", "Reviews Summary - None", gC_CurrentMapName);
		return;
	}

	ReviewPrintToChat(client, "%t", "Reviews Summary - Header", gC_CurrentMapName);
	PrintMapSummaryRatingLine(client, "Overall", gF_CurrentMapOverallAvg, gI_CurrentMapReviewsCount, true);
	PrintMapSummaryRatingLine(client, "Gameplay", gF_CurrentMapGameplayAvg, gI_CurrentMapGameplayCount, false);
	PrintMapSummaryRatingLine(client, "Visuals", gF_CurrentMapVisualsAvg, gI_CurrentMapVisualsCount, false);
	ReviewPrintToChat(client, "%t", "Reviews Summary - Comments", gI_CurrentMapCommentsCount);
}

void PrintMapSummaryRatingLine(int client, const char[] label, float rating, int ratingCount, bool includeCount)
{
	char stars[32];
	char ratingText[16];

	if (rating < 0.0 || ratingCount <= 0)
	{
		BuildStarsInt(0, stars, sizeof(stars));
		if (includeCount)
		{
			ReviewPrintToChat(client, "{grey}%s: {default}%s{grey} ({default}%d{grey} reviews)", label, stars, gI_CurrentMapReviewsCount);
		}
		else
		{
			ReviewPrintToChat(client, "{grey}%s: {default}%s", label, stars);
		}
		return;
	}

	BuildStarsFloat(rating, stars, sizeof(stars));
	Format(ratingText, sizeof(ratingText), "%.1f", rating);
	if (includeCount)
	{
		ReviewPrintToChat(
			client,
			"{grey}%s: {default}%s{grey} {default}%s{grey} ({default}%d{grey} reviews)",
			label,
			ratingText,
			stars,
			gI_CurrentMapReviewsCount
		);
	}
	else
	{
		ReviewPrintToChat(client, "{grey}%s: {default}%s{grey} {default}%s", label, ratingText, stars);
	}
}

public Action Timer_PromptRateIfNeeded(Handle timer, any userId)
{
	int client = GetClientOfUserId(userId);
	if (!IsValidClientForReview(client) || HasAnyCachedReview(client))
	{
		return Plugin_Stop;
	}

	gB_RatePromptPending[client] = true;
	gF_RatePromptRequestedAt[client] = GetGameTime();
	FetchMyReview(client, true);
	return Plugin_Stop;
}
