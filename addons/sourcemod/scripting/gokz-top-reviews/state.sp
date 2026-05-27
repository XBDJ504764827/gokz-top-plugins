void ResetMapReviewState()
{
	gI_CurrentMapID = 0;
	gB_CurrentMapInfoFetched = false;
	gB_CurrentMapInfoInFlight = false;
	gF_CurrentMapOverallAvg = -1.0;
	gF_CurrentMapGameplayAvg = -1.0;
	gF_CurrentMapVisualsAvg = -1.0;
	gI_CurrentMapReviewsCount = -1;
	gI_CurrentMapGameplayCount = 0;
	gI_CurrentMapVisualsCount = 0;
	gI_CurrentMapCommentsCount = -1;

	for (int client = 1; client <= MaxClients; client++)
	{
		ResetClientReviewState(client);
	}
}

void ResetClientReviewState(int client)
{
	gB_RateReminderSent[client] = false;
	gB_RatePromptPending[client] = false;
	gF_RatePromptRequestedAt[client] = 0.0;
	gI_ActiveAspectMenu[client] = ReviewAspect_Overall;
	gB_CaptureComment[client] = false;
	gB_MenuPending[client] = false;
	gB_SubmitInFlight[client] = false;
	gI_SubmitPendingFlags[client] = 0;
	gB_ReopenMenuAfterSubmit[client] = false;
	gI_SummaryPrintAttempts[client] = 0;
	gB_SubmitPendingAfterMapInfo[client] = false;

	gB_MyReviewFetched[client] = false;
	gF_LastMyReviewFetchAt[client] = 0.0;

	for (int aspect = 0; aspect < REVIEW_ASPECT_COUNT; aspect++)
	{
		gI_MyRating[client][aspect] = 0;
		gI_DraftRating[client][aspect] = 0;
		gB_DraftDirtyRating[client][aspect] = false;
	}

	gC_MyComment[client][0] = '\0';
	gC_DraftComment[client][0] = '\0';
	gB_DraftDirtyComment[client] = false;
}

void PrepareDraftFromCurrentReview(int client)
{
	for (int aspect = 0; aspect < REVIEW_ASPECT_COUNT; aspect++)
	{
		gI_DraftRating[client][aspect] = gI_MyRating[client][aspect];
		gB_DraftDirtyRating[client][aspect] = false;
	}

	strcopy(gC_DraftComment[client], sizeof(gC_DraftComment[]), gC_MyComment[client]);
	gB_DraftDirtyComment[client] = false;
}

bool HasAnyCachedReview(int client)
{
	return gI_MyRating[client][ReviewAspect_Overall] > 0
		|| gI_MyRating[client][ReviewAspect_Gameplay] > 0
		|| gI_MyRating[client][ReviewAspect_Visuals] > 0
		|| gC_MyComment[client][0] != '\0';
}

bool HasAnyDirtyDraftField(int client)
{
	return gB_DraftDirtyRating[client][ReviewAspect_Overall]
		|| gB_DraftDirtyRating[client][ReviewAspect_Gameplay]
		|| gB_DraftDirtyRating[client][ReviewAspect_Visuals]
		|| gB_DraftDirtyComment[client];
}

bool IsValidReviewRating(int rating)
{
	return rating >= 1 && rating <= 5;
}

bool IsValidClientForReview(int client)
{
	return IsValidClient(client) && !IsFakeClient(client);
}

void ReviewPrintToChat(int client, const char[] fmt, any ...)
{
	char message[256];
	VFormat(message, sizeof(message), fmt, 3);
	GOKZ_PrintToChat(client, false, "%s%s", GOKZ_TOP_CHAT_PREFIX, message);
}
