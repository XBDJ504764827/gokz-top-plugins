void ShowRateMenuMain(int client)
{
	Menu menu = new Menu(MenuHandler_RateMain);

	char overallLine[96];
	char gameplayLine[96];
	char visualsLine[96];
	BuildMenuSummaryLine("Overall", gF_CurrentMapOverallAvg, gI_CurrentMapReviewsCount, overallLine, sizeof(overallLine), true);
	BuildMenuSummaryLine("Gameplay", gF_CurrentMapGameplayAvg, gI_CurrentMapGameplayCount, gameplayLine, sizeof(gameplayLine));
	BuildMenuSummaryLine("Visuals", gF_CurrentMapVisualsAvg, gI_CurrentMapVisualsCount, visualsLine, sizeof(visualsLine));

	char title[384];
	Format(
		title,
		sizeof(title),
		"GOKZ.TOP - Rate %s\n%s\n%s\n%s\nComments: %d",
		gC_CurrentMapName,
		overallLine,
		gameplayLine,
		visualsLine,
		gI_CurrentMapCommentsCount < 0 ? 0 : gI_CurrentMapCommentsCount
	);

	menu.SetTitle(title);
	menu.ExitButton = true;
	menu.Pagination = 6;

	char line[64];
	char label[24];

	GetAspectLabel(client, ReviewAspect_Overall, label, sizeof(label));
	BuildAspectLine(client, ReviewAspect_Overall, label, line, sizeof(line));
	menu.AddItem("aspect_overall", line);

	GetAspectLabel(client, ReviewAspect_Gameplay, label, sizeof(label));
	BuildAspectLine(client, ReviewAspect_Gameplay, label, line, sizeof(line));
	menu.AddItem("aspect_gameplay", line);

	GetAspectLabel(client, ReviewAspect_Visuals, label, sizeof(label));
	BuildAspectLine(client, ReviewAspect_Visuals, label, line, sizeof(line));
	menu.AddItem("aspect_visuals", line);

	char commentText[128];
	FormatEx(commentText, sizeof(commentText), "%T", "Reviews Menu - Comment", client);
	menu.AddItem("comment", commentText);

	char commentsText[128];
	FormatEx(commentsText, sizeof(commentsText), "%T", "Reviews Menu - ViewComments", client);
	if (gI_CurrentMapCommentsCount >= 0)
	{
		Format(commentsText, sizeof(commentsText), "%s (%d)", commentsText, gI_CurrentMapCommentsCount);
	}

	int commentsItemState = gI_CurrentMapCommentsCount == 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT;
	menu.AddItem("view_comments", commentsText, commentsItemState);

	char submitText[128];
	FormatEx(submitText, sizeof(submitText), "%T", "Reviews Menu - Submit", client);
	menu.AddItem("submit_review", submitText);

	menu.Display(client, 0);
}

public int MenuHandler_RateMain(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_Exit)
		{
			SubmitDraftReview(client);
		}
		return 0;
	}

	if (action != MenuAction_Select)
	{
		return 0;
	}

	char info[32];
	menu.GetItem(item, info, sizeof(info));

	if (StrEqual(info, "aspect_overall"))
	{
		gI_ActiveAspectMenu[client] = ReviewAspect_Overall;
		ShowRateMenuAspect(client, ReviewAspect_Overall);
	}
	else if (StrEqual(info, "aspect_gameplay"))
	{
		gI_ActiveAspectMenu[client] = ReviewAspect_Gameplay;
		ShowRateMenuAspect(client, ReviewAspect_Gameplay);
	}
	else if (StrEqual(info, "aspect_visuals"))
	{
		gI_ActiveAspectMenu[client] = ReviewAspect_Visuals;
		ShowRateMenuAspect(client, ReviewAspect_Visuals);
	}
	else if (StrEqual(info, "comment"))
	{
		gB_CaptureComment[client] = true;
		ReviewPrintToChat(client, "%t", "Reviews Comment - Prompt");
		ReviewPrintToChat(client, "%t", "Reviews Comment - CancelHint");
	}
	else if (StrEqual(info, "view_comments"))
	{
		FetchComments(client);
	}
	else if (StrEqual(info, "submit_review"))
	{
		SubmitDraftReview(client);
		if (!gB_SubmitInFlight[client] && !gB_SubmitPendingAfterMapInfo[client])
		{
			ShowRateMenuMain(client);
		}
	}

	return 0;
}

void ShowRateMenuAspect(int client, int aspect)
{
	Menu menu = new Menu(MenuHandler_RateAspect);
	menu.ExitButton = true;
	menu.ExitBackButton = true;

	char label[24];
	GetAspectLabel(client, aspect, label, sizeof(label));

	char title[64];
	FormatEx(title, sizeof(title), "%T", "Reviews Menu - AspectTitle", client, label);
	menu.SetTitle(title);

	for (int rating = 1; rating <= 5; rating++)
	{
		char info[8];
		char stars[32];
		IntToString(rating, info, sizeof(info));
		BuildStarsInt(rating, stars, sizeof(stars));
		menu.AddItem(info, stars);
	}

	menu.Display(client, 0);
}

public int MenuHandler_RateAspect(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
		return 0;
	}

	if (action == MenuAction_Cancel)
	{
		if (item == MenuCancel_ExitBack)
		{
			ShowRateMenuMain(client);
		}
		else if (item == MenuCancel_Exit)
		{
			SubmitDraftReview(client);
		}
		return 0;
	}

	if (action != MenuAction_Select)
	{
		return 0;
	}

	char info[8];
	menu.GetItem(item, info, sizeof(info));

	int rating = StringToInt(info);
	int aspect = view_as<int>(gI_ActiveAspectMenu[client]);
	if (aspect < 0 || aspect >= REVIEW_ASPECT_COUNT)
	{
		aspect = ReviewAspect_Overall;
	}

	gI_DraftRating[client][aspect] = rating;
	gB_DraftDirtyRating[client][aspect] = true;
	ShowRateMenuMain(client);
	return 0;
}

void FetchComments(int client)
{
	char mapEncoded[PLATFORM_MAX_PATH * 3];
	URLEncode(gC_CurrentMapName, mapEncoded, sizeof(mapEncoded));

	char query[512];
	Format(query, sizeof(query), "map_name=%s&with_comments_only=true&limit=10&offset=0", mapEncoded);

	char url[1024];
	if (!BuildAPIURL(url, sizeof(url), "/v1/maps/reviews", query))
	{
		ReviewLog("event=fetch_comments_aborted client=%d reason=missing_base_url", client);
		ReviewPrintToChat(client, "%t", "Reviews Error - BaseUrlMissing");
		return;
	}

	LogAuthMode();
	ReviewLog("event=fetch_comments client=%d url=%s", client, url);

	Handle request = CreateAPIRequest(k_EHTTPMethodGET, url);
	if (request == INVALID_HANDLE || !DispatchRequest(request, GetClientUserId(client), ReviewRequestType_Comments))
	{
		if (request != INVALID_HANDLE)
		{
			delete request;
		}
		ReviewPrintToChat(client, "%t", "Reviews Error - RequestCreate");
	}
}

void HandleCommentsSuccess(int client, const char[] body)
{
	if (!LooksLikeJson(body))
	{
		ReviewLog("event=comments_success_invalid_json client=%d", client);
		ReviewPrintToChat(client, "%t", "Reviews Error - NonJson", 200);
		return;
	}

	char dataArray[8192];
	if (!ExtractJsonArray(body, "data", dataArray, sizeof(dataArray)))
	{
		ReviewLog("event=comments_success_empty client=%d", client);
		ReviewPrintToChat(client, "%t", "Reviews Comments - Empty");
		return;
	}

	Menu menu = new Menu(MenuHandler_Comments);
	char title[160];
	FormatEx(title, sizeof(title), "%T", "Reviews Comments - Title", client, gC_CurrentMapName);
	menu.SetTitle(title);
	menu.ExitButton = true;
	menu.Pagination = 6;

	int cursor = 0;
	int count = 0;
	char row[2048];
	while (ExtractNextObjectFromArray(dataArray, cursor, row, sizeof(row)))
	{
		char displayName[64];
		displayName[0] = '\0';
		char player[256];
		if (ExtractJsonObject(row, "player", player, sizeof(player)))
		{
			JsonGetOptionalString(player, "display_name", displayName, sizeof(displayName));
		}
		if (displayName[0] == '\0')
		{
			JsonGetOptionalString(row, "steamid64", displayName, sizeof(displayName));
		}

		char comment[128];
		comment[0] = '\0';
		int overall = 0;
		char content[1024];
		if (ExtractJsonObject(row, "content", content, sizeof(content)))
		{
			overall = ClampReviewRating(JsonGetOptionalInt(content, "overall"));
			JsonGetCommentTextFromContent(content, comment, sizeof(comment));
		}

		char stars[32];
		BuildStarsInt(overall, stars, sizeof(stars));

		char line[192];
		if (comment[0] != '\0')
		{
			Format(line, sizeof(line), "%s %s | %s", stars, displayName, comment);
		}
		else
		{
			Format(line, sizeof(line), "%s %s", stars, displayName);
		}

		menu.AddItem("row", line, ITEMDRAW_DISABLED);
		count++;
	}

	ReviewLog("event=comments_success client=%d count=%d", client, count);

	if (count == 0)
	{
		delete menu;
		ReviewPrintToChat(client, "%t", "Reviews Comments - Empty");
		return;
	}

	menu.Display(client, 0);
}

public int MenuHandler_Comments(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	return 0;
}

void GetAspectLabel(int client, int aspect, char[] out, int maxlen)
{
	switch (aspect)
	{
		case ReviewAspect_Overall:
		{
			FormatEx(out, maxlen, "%T", "Reviews Menu - Overall", client);
		}
		case ReviewAspect_Gameplay:
		{
			FormatEx(out, maxlen, "%T", "Reviews Menu - Gameplay", client);
		}
		default:
		{
			FormatEx(out, maxlen, "%T", "Reviews Menu - Visuals", client);
		}
	}
}

void BuildAspectLine(int client, int aspect, const char[] label, char[] out, int maxlen)
{
	char stars[32];
	BuildStarsInt(gI_DraftRating[client][aspect], stars, sizeof(stars));
	Format(out, maxlen, "%s  %s", label, stars);
}

void BuildStarsInt(int rating, char[] out, int maxlen)
{
	out[0] = '\0';
	rating = ClampReviewRating(rating);

	for (int i = 0; i < rating && strlen(out) + 1 < maxlen; i++)
	{
		StrCat(out, maxlen, "★");
	}

	for (int i = rating; i < 5 && strlen(out) + 1 < maxlen; i++)
	{
		StrCat(out, maxlen, "☆");
	}
}

void BuildStarsFloat(float rating, char[] out, int maxlen)
{
	BuildStarsInt(RoundToNearest(rating), out, maxlen);
}

void BuildMenuSummaryLine(const char[] label, float rating, int ratingCount, char[] out, int maxlen, bool includeCount = false)
{
	char stars[32];
	BuildStarsFloat(rating < 0.0 ? 0.0 : rating, stars, sizeof(stars));

	if (rating < 0.0 || ratingCount <= 0)
	{
		if (includeCount)
		{
			Format(out, maxlen, "%s: %s (%d)", label, stars, gI_CurrentMapReviewsCount < 0 ? 0 : gI_CurrentMapReviewsCount);
		}
		else
		{
			Format(out, maxlen, "%s: %s", label, stars);
		}
		return;
	}

	if (includeCount)
	{
		Format(out, maxlen, "%s: %.1f %s (%d)", label, rating, stars, gI_CurrentMapReviewsCount);
	}
	else
	{
		Format(out, maxlen, "%s: %.1f %s", label, rating, stars);
	}
}
