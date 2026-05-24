void FetchMyReview(int client, bool force)
{
	float now = GetGameTime();
	if (!force && now - gF_LastMyReviewFetchAt[client] < 10.0)
	{
		ReviewLog("event=fetch_my_review_skipped client=%d reason=cache force=%d", client, force);
		if (gB_MenuPending[client])
		{
			gB_MyReviewFetched[client] = true;
			TryShowMenuWhenReady(client);
		}
		return;
	}

	gF_LastMyReviewFetchAt[client] = now;

	char steamid64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64), true))
	{
		ReviewLog("event=fetch_my_review_aborted client=%d reason=no_steamid64", client);
		gB_MyReviewFetched[client] = true;
		TryShowMenuWhenReady(client);
		return;
	}

	char mapEncoded[PLATFORM_MAX_PATH * 3];
	URLEncode(gC_CurrentMapName, mapEncoded, sizeof(mapEncoded));

	char query[512];
	Format(query, sizeof(query), "map_name=%s&steamid64=%s&limit=1&offset=0", mapEncoded, steamid64);

	char url[1024];
	if (!BuildAPIURL(url, sizeof(url), "/v1/maps/reviews", query))
	{
		ReviewLog("event=fetch_my_review_aborted client=%d reason=missing_base_url", client);
		gB_MyReviewFetched[client] = true;
		TryShowMenuWhenReady(client);
		return;
	}

	LogAuthMode();
	ReviewLog("event=fetch_my_review client=%d steamid64=%s url=%s force=%d", client, steamid64, url, force);

	Handle request = CreateAPIRequest(k_EHTTPMethodGET, url);
	if (request == INVALID_HANDLE || !DispatchRequest(request, GetClientUserId(client), ReviewRequestType_MyReview))
	{
		if (request != INVALID_HANDLE)
		{
			delete request;
		}
		gB_MyReviewFetched[client] = true;
		TryShowMenuWhenReady(client);
	}
}

void HandleMyReviewSuccess(int client, const char[] body)
{
	gI_MyRating[client][ReviewAspect_Overall] = 0;
	gI_MyRating[client][ReviewAspect_Gameplay] = 0;
	gI_MyRating[client][ReviewAspect_Visuals] = 0;
	gC_MyComment[client][0] = '\0';

	if (LooksLikeJson(body))
	{
		char row[4096];
		if (ExtractFirstObjectFromNamedArray(body, "data", row, sizeof(row)))
		{
			char content[1024];
			if (ExtractJsonObject(row, "content", content, sizeof(content)))
			{
				gI_MyRating[client][ReviewAspect_Overall] = ClampReviewRating(JsonGetOptionalInt(content, "overall"));
				gI_MyRating[client][ReviewAspect_Gameplay] = ClampReviewRating(JsonGetOptionalInt(content, "gameplay"));
				gI_MyRating[client][ReviewAspect_Visuals] = ClampReviewRating(JsonGetOptionalInt(content, "visuals"));
				JsonGetCommentTextFromContent(content, gC_MyComment[client], sizeof(gC_MyComment[]));
			}

			char mapRef[256];
			if (ExtractJsonObject(row, "map", mapRef, sizeof(mapRef)))
			{
				int mapId = JsonGetOptionalInt(mapRef, "id");
				if (mapId > 0)
				{
					gI_CurrentMapID = mapId;
				}
			}
		}
	}

	gB_MyReviewFetched[client] = true;
	ReviewLog(
		"event=my_review_success client=%d overall=%d gameplay=%d visuals=%d has_comment=%d map_id=%d",
		client,
		gI_MyRating[client][ReviewAspect_Overall],
		gI_MyRating[client][ReviewAspect_Gameplay],
		gI_MyRating[client][ReviewAspect_Visuals],
		gC_MyComment[client][0] != '\0',
		gI_CurrentMapID
	);
	TryShowMenuWhenReady(client);

	if (gB_RatePromptPending[client] && !gB_RateReminderSent[client])
	{
		if (GetGameTime() - gF_RatePromptRequestedAt[client] <= 30.0 && !HasAnyCachedReview(client))
		{
			gB_RateReminderSent[client] = true;
			ReviewPrintToChat(client, "%t", "Reviews Prompt");
		}

		gB_RatePromptPending[client] = false;
		gF_RatePromptRequestedAt[client] = 0.0;
	}
}

void SubmitDraftReview(int client)
{
	if (!IsValidClientForReview(client) || gB_SubmitInFlight[client])
	{
		ReviewLog("event=submit_draft_skipped client=%d valid=%d in_flight=%d", client, IsValidClientForReview(client), gB_SubmitInFlight[client]);
		return;
	}

	if (!HasAnyDirtyDraftField(client))
	{
		ReviewLog("event=submit_draft_skipped client=%d reason=no_dirty_fields", client);
		return;
	}

	if (!HasServerGroupKey())
	{
		ReviewLog("event=submit_draft_blocked client=%d reason=missing_server_group_key", client);
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - MissingServerGroupKey");
		return;
	}

	if (gI_CurrentMapID <= 0)
	{
		ReviewLog("event=submit_draft_deferred client=%d reason=missing_map_id", client);
		gB_SubmitPendingAfterMapInfo[client] = true;
		if (!gB_CurrentMapInfoInFlight)
		{
			FetchCurrentMapInfo();
		}
		return;
	}

	int flags = 0;
	char body[1536];
	BuildDraftReviewRequestBody(client, body, sizeof(body), flags);
	if (body[0] == '\0')
	{
		ReviewLog("event=submit_draft_blocked client=%d reason=empty_body flags=%d", client, flags);
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - OverallRequired");
		return;
	}

	char url[1024];
	if (!BuildAPIURL(url, sizeof(url), "/v1/maps/reviews"))
	{
		ReviewLog("event=submit_draft_aborted client=%d reason=missing_base_url", client);
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - BaseUrlMissing");
		return;
	}

	LogAuthMode();
	ReviewLog("event=submit_draft client=%d map_id=%d flags=%d body=%s url=%s", client, gI_CurrentMapID, flags, body, url);

	Handle request = CreateAPIRequest(k_EHTTPMethodPUT, url, body);
	if (request == INVALID_HANDLE || !DispatchRequest(request, GetClientUserId(client), ReviewRequestType_SubmitReview, flags))
	{
		if (request != INVALID_HANDLE)
		{
			delete request;
		}
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - RequestCreate");
		return;
	}

	gB_SubmitPendingAfterMapInfo[client] = false;
	gB_SubmitInFlight[client] = true;
	gI_SubmitPendingFlags[client] = flags;
}

void BuildDraftReviewRequestBody(int client, char[] out, int maxlen, int &flags)
{
	flags = 0;
	out[0] = '\0';

	int overall = gI_DraftRating[client][ReviewAspect_Overall];
	if (!IsValidReviewRating(overall))
	{
		return;
	}

	const int FLAG_OVERALL = (1 << 0);
	const int FLAG_GAMEPLAY = (1 << 1);
	const int FLAG_VISUALS = (1 << 2);
	const int FLAG_COMMENT = (1 << 3);

	flags |= gB_DraftDirtyRating[client][ReviewAspect_Overall] ? FLAG_OVERALL : 0;
	flags |= gB_DraftDirtyRating[client][ReviewAspect_Gameplay] ? FLAG_GAMEPLAY : 0;
	flags |= gB_DraftDirtyRating[client][ReviewAspect_Visuals] ? FLAG_VISUALS : 0;
	flags |= gB_DraftDirtyComment[client] ? FLAG_COMMENT : 0;

	if (flags == 0)
	{
		return;
	}

	char steamid64[32];
	if (!GetClientAuthId(client, AuthId_SteamID64, steamid64, sizeof(steamid64), true))
	{
		flags = 0;
		return;
	}

	char content[768];
	Format(content, sizeof(content), "\"overall\":%d", overall);

	int gameplay = gI_DraftRating[client][ReviewAspect_Gameplay];
	if (IsValidReviewRating(gameplay))
	{
		Format(content, sizeof(content), "%s,\"gameplay\":%d", content, gameplay);
	}

	int visuals = gI_DraftRating[client][ReviewAspect_Visuals];
	if (IsValidReviewRating(visuals))
	{
		Format(content, sizeof(content), "%s,\"visuals\":%d", content, visuals);
	}

	if (gC_DraftComment[client][0] != '\0')
	{
		char escapedComment[512];
		EscapeJSONString(gC_DraftComment[client], escapedComment, sizeof(escapedComment));
		Format(content, sizeof(content), "%s,\"comment\":{\"text\":\"%s\"}", content, escapedComment);
	}

	Format(out, maxlen, "{\"map_id\":%d,\"steamid64\":%s,\"content\":{%s}}", gI_CurrentMapID, steamid64, content);
}

void HandleSubmitReviewSuccess(int client, int flags)
{
	gB_SubmitInFlight[client] = false;
	gB_SubmitPendingAfterMapInfo[client] = false;

	gI_MyRating[client][ReviewAspect_Overall] = ClampReviewRating(gI_DraftRating[client][ReviewAspect_Overall]);
	gI_MyRating[client][ReviewAspect_Gameplay] = ClampReviewRating(gI_DraftRating[client][ReviewAspect_Gameplay]);
	gI_MyRating[client][ReviewAspect_Visuals] = ClampReviewRating(gI_DraftRating[client][ReviewAspect_Visuals]);
	strcopy(gC_MyComment[client], sizeof(gC_MyComment[]), gC_DraftComment[client]);

	for (int aspect = 0; aspect < REVIEW_ASPECT_COUNT; aspect++)
	{
		gB_DraftDirtyRating[client][aspect] = false;
	}
	gB_DraftDirtyComment[client] = false;

	ReviewLog(
		"event=submit_review_success client=%d flags=%d overall=%d gameplay=%d visuals=%d has_comment=%d",
		client,
		flags,
		gI_MyRating[client][ReviewAspect_Overall],
		gI_MyRating[client][ReviewAspect_Gameplay],
		gI_MyRating[client][ReviewAspect_Visuals],
		gC_MyComment[client][0] != '\0'
	);

	AnnounceReviewChanges(client, flags);
	FetchCurrentMapInfo();

	if (gB_ReopenMenuAfterSubmit[client])
	{
		gB_ReopenMenuAfterSubmit[client] = false;
		PrepareDraftFromCurrentReview(client);
		ShowRateMenuMain(client);
	}
}

void AnnounceReviewChanges(int client, int flags)
{
	const int FLAG_OVERALL = (1 << 0);
	const int FLAG_GAMEPLAY = (1 << 1);
	const int FLAG_VISUALS = (1 << 2);
	const int FLAG_COMMENT = (1 << 3);

	if ((flags & (FLAG_OVERALL | FLAG_GAMEPLAY | FLAG_VISUALS)) != 0)
	{
		char playerName[MAX_NAME_LENGTH];
		GetClientName(client, playerName, sizeof(playerName));

		char overallAnnouncement[64];
		BuildAspectAnnouncement("Overall", gI_DraftRating[client][ReviewAspect_Overall], overallAnnouncement, sizeof(overallAnnouncement));
		char message[256];
		Format(message, sizeof(message), "{lime}%s{default} rated: %s", playerName, overallAnnouncement);

		for (int target = 1; target <= MaxClients; target++)
		{
			if (IsValidClient(target))
			{
				GOKZ_PrintToChat(target, false, "%s%s", GOKZ_TOP_REVIEWS_PREFIX, message);
			}
		}
	}

	if ((flags & (FLAG_OVERALL | FLAG_GAMEPLAY | FLAG_VISUALS | FLAG_COMMENT)) != 0)
	{
		ReviewPrintToChat(client, "%t", "Reviews Submit - Saved");
	}
}

void BuildAspectAnnouncement(const char[] label, int rating, char[] out, int maxlen)
{
	char stars[32];
	BuildStarsInt(rating, stars, sizeof(stars));
	Format(out, maxlen, "%s: %s", label, stars);
}

void TryShowMenuWhenReady(int client)
{
	if (!gB_MenuPending[client] || !gB_MyReviewFetched[client])
	{
		return;
	}

	gB_MenuPending[client] = false;
	PrepareDraftFromCurrentReview(client);
	ShowRateMenuMain(client);
}

int ClampReviewRating(int rating)
{
	return IsValidReviewRating(rating) ? rating : 0;
}

void JsonGetCommentTextFromContent(const char[] content, char[] out, int maxlen)
{
	out[0] = '\0';

	char comment[512];
	if (!ExtractJsonObject(content, "comment", comment, sizeof(comment)))
	{
		return;
	}

	JsonGetOptionalString(comment, "text", out, maxlen);
}

void ResumePendingSubmissionsAfterMapInfo()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!gB_SubmitPendingAfterMapInfo[client] || !IsValidClientForReview(client))
		{
			continue;
		}

		if (gI_CurrentMapID <= 0)
		{
			ReviewLog("event=resume_pending_submit_failed client=%d reason=missing_map_id", client);
			gB_SubmitPendingAfterMapInfo[client] = false;
			GOKZ_PlayErrorSound(client);
			ReviewPrintToChat(client, "%t", "Reviews Error - MapUnavailable");
			continue;
		}

		ReviewLog("event=resume_pending_submit client=%d map_id=%d", client, gI_CurrentMapID);
		SubmitDraftReview(client);
	}
}

void FailPendingSubmissionsAfterMapInfo()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!gB_SubmitPendingAfterMapInfo[client] || !IsValidClientForReview(client))
		{
			continue;
		}

		ReviewLog("event=fail_pending_submit client=%d reason=map_info_failed", client);
		gB_SubmitPendingAfterMapInfo[client] = false;
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - MapUnavailable");
	}
}
