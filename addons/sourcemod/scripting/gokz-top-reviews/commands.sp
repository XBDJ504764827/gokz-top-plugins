void RegisterCommands()
{
	RegConsoleCmd("sm_rate", Command_Rate, "Usage: !rate [<1-5>|<1-5> <1-5> <1-5>|<aspect> <1-5>] [comment]");
	RegConsoleCmd("sm_review", Command_Rate, "Alias for !rate.");
	RegConsoleCmd("sm_comments", Command_Comments, "Show recent gokz-top comments for the current map.");
}

public Action Command_Rate(int client, int args)
{
	if (!IsValidClientForReview(client))
	{
		ReplyToCommand(client, "[GOKZ.TOP] This command can only be used in-game.");
		return Plugin_Handled;
	}

	if (args == 0)
	{
		ReviewLog("event=command_rate client=%d mode=menu", client);
		gB_MenuPending[client] = true;
		gB_MyReviewFetched[client] = false;
		if (!gB_CurrentMapInfoFetched && !gB_CurrentMapInfoInFlight)
		{
			FetchCurrentMapInfo();
		}
		FetchMyReview(client, true);
		return Plugin_Handled;
	}

	char arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));

	if (IsNumeric(arg1))
	{
		int overallRating = StringToInt(arg1);
		if (!IsValidReviewRating(overallRating))
		{
			GOKZ_PlayErrorSound(client);
			ReviewPrintToChat(client, "%t", "Reviews Error - RatingRange");
			return Plugin_Handled;
		}

		if (args >= 3)
		{
			char arg2[16];
			char arg3[16];
			GetCmdArg(2, arg2, sizeof(arg2));
			GetCmdArg(3, arg3, sizeof(arg3));

			if (IsNumeric(arg2) && IsNumeric(arg3))
			{
				int gameplayRating = StringToInt(arg2);
				int visualsRating = StringToInt(arg3);
				if (!IsValidReviewRating(gameplayRating) || !IsValidReviewRating(visualsRating))
				{
					GOKZ_PlayErrorSound(client);
					ReviewPrintToChat(client, "%t", "Reviews Error - RatingRange");
					return Plugin_Handled;
				}

				char comment[256];
				ExtractTailComment(args, 3, comment, sizeof(comment));
				ReviewLog(
					"event=command_rate client=%d mode=triple overall=%d gameplay=%d visuals=%d has_comment=%d",
					client,
					overallRating,
					gameplayRating,
					visualsRating,
					comment[0] != '\0'
				);
				PrepareDraftFromCurrentReview(client);
				gI_DraftRating[client][ReviewAspect_Overall] = overallRating;
				gI_DraftRating[client][ReviewAspect_Gameplay] = gameplayRating;
				gI_DraftRating[client][ReviewAspect_Visuals] = visualsRating;
				gB_DraftDirtyRating[client][ReviewAspect_Overall] = true;
				gB_DraftDirtyRating[client][ReviewAspect_Gameplay] = true;
				gB_DraftDirtyRating[client][ReviewAspect_Visuals] = true;
				if (comment[0] != '\0')
				{
					strcopy(gC_DraftComment[client], sizeof(gC_DraftComment[]), comment);
					gB_DraftDirtyComment[client] = true;
				}
				SubmitDraftReview(client);
				return Plugin_Handled;
			}
		}

		char comment[256];
		ExtractTailComment(args, 1, comment, sizeof(comment));
		ReviewLog("event=command_rate client=%d mode=quick_overall rating=%d has_comment=%d", client, overallRating, comment[0] != '\0');
		PrepareDraftFromCurrentReview(client);
		gI_DraftRating[client][ReviewAspect_Overall] = overallRating;
		gB_DraftDirtyRating[client][ReviewAspect_Overall] = true;
		if (comment[0] != '\0')
		{
			strcopy(gC_DraftComment[client], sizeof(gC_DraftComment[]), comment);
			gB_DraftDirtyComment[client] = true;
		}
		SubmitDraftReview(client);
		return Plugin_Handled;
	}

	if (args < 2)
	{
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Command - Usage");
		return Plugin_Handled;
	}

	int aspect = ParseAspect(arg1);
	if (aspect == -1)
	{
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - UnknownAspect");
		return Plugin_Handled;
	}

	char arg2[16];
	GetCmdArg(2, arg2, sizeof(arg2));
	if (!IsNumeric(arg2))
	{
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Command - AspectUsage");
		return Plugin_Handled;
	}

	int rating = StringToInt(arg2);
	if (!IsValidReviewRating(rating))
	{
		GOKZ_PlayErrorSound(client);
		ReviewPrintToChat(client, "%t", "Reviews Error - RatingRange");
		return Plugin_Handled;
	}

	char comment[256];
	ExtractTailComment(args, 2, comment, sizeof(comment));
	ReviewLog("event=command_rate client=%d mode=aspect aspect=%d rating=%d has_comment=%d", client, aspect, rating, comment[0] != '\0');
	PrepareDraftFromCurrentReview(client);
	gI_DraftRating[client][aspect] = rating;
	gB_DraftDirtyRating[client][aspect] = true;
	if (comment[0] != '\0')
	{
		strcopy(gC_DraftComment[client], sizeof(gC_DraftComment[]), comment);
		gB_DraftDirtyComment[client] = true;
	}
	SubmitDraftReview(client);
	return Plugin_Handled;
}

public Action Command_Comments(int client, int args)
{
	if (!IsValidClientForReview(client))
	{
		return Plugin_Handled;
	}

	ReviewLog("event=command_comments client=%d", client);
	FetchComments(client);
	return Plugin_Handled;
}

public Action Command_Say(int client, const char[] command, int argc)
{
	if (!IsValidClientForReview(client) || !gB_CaptureComment[client])
	{
		return Plugin_Continue;
	}

	char message[256];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);

	if (message[0] == '\0')
	{
		return Plugin_Handled;
	}

	if (StrEqual(message, "!cancel", false) || StrEqual(message, "/cancel", false))
	{
		gB_CaptureComment[client] = false;
		ReviewPrintToChat(client, "%t", "Reviews Comment - Cancelled");
		ShowRateMenuMain(client);
		return Plugin_Handled;
	}

	char firstChar = message[0];
	if (firstChar == '!' || firstChar == '/' || firstChar == '.')
	{
		return Plugin_Continue;
	}

	if (strlen(message) >= 3
		&& (message[0] == 'r' || message[0] == 'R')
		&& (message[1] == 't' || message[1] == 'T')
		&& (message[2] == 'v' || message[2] == 'V'))
	{
		return Plugin_Continue;
	}

	gB_CaptureComment[client] = false;
	strcopy(gC_DraftComment[client], sizeof(gC_DraftComment[]), message);
	gB_DraftDirtyComment[client] = true;
	SubmitDraftReview(client);

	if (gB_SubmitInFlight[client] || gB_SubmitPendingAfterMapInfo[client])
	{
		gB_ReopenMenuAfterSubmit[client] = true;
	}
	else
	{
		ShowRateMenuMain(client);
	}

	return Plugin_Handled;
}

bool IsNumeric(const char[] value)
{
	if (value[0] == '\0')
	{
		return false;
	}

	for (int i = 0; value[i] != '\0'; i++)
	{
		if (value[i] < '0' || value[i] > '9')
		{
			return false;
		}
	}

	return true;
}

int ParseAspect(const char[] value)
{
	if (StrEqual(value, "overall", false))
	{
		return ReviewAspect_Overall;
	}
	if (StrEqual(value, "gameplay", false))
	{
		return ReviewAspect_Gameplay;
	}
	if (StrEqual(value, "visuals", false))
	{
		return ReviewAspect_Visuals;
	}

	return -1;
}

void ExtractTailComment(int argc, int skipArgs, char[] out, int maxlen)
{
	out[0] = '\0';
	if (argc <= skipArgs)
	{
		return;
	}

	char full[512];
	GetCmdArgString(full, sizeof(full));
	TrimString(full);

	int tokensToSkip = skipArgs;
	int pos = 0;
	bool inToken = false;
	while (full[pos] != '\0' && tokensToSkip > 0)
	{
		if (full[pos] != ' ' && !inToken)
		{
			inToken = true;
		}
		else if (full[pos] == ' ' && inToken)
		{
			inToken = false;
			tokensToSkip--;
		}
		pos++;
	}

	while (full[pos] == ' ')
	{
		pos++;
	}

	strcopy(out, maxlen, full[pos]);
	TrimString(out);
}
