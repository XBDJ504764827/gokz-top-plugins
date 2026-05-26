TopMenu gTM_Options;
TopMenuObject gTMO_CatProfile = INVALID_TOPMENUOBJECT;
TopMenuObject gTMO_ItemsProfile[PROFILEOPTION_COUNT];

void OnOptionsMenuReady_Options()
{
	RegisterOptions();
}

void RegisterOptions()
{
	for (ProfileOption option; option < PROFILEOPTION_COUNT; option++)
	{
		if (GOKZ_GetOptionProp(gC_ProfileOptionNames[option], OptionProp_Type) != -1)
		{
			if (option == ProfileOption_TagType)
			{
				GOKZ_SetOptionProp(gC_ProfileOptionNames[option], OptionProp_MaxValue, PROFILETAGTYPE_COUNT - 1);
			}
			continue;
		}

		GOKZ_RegisterOption(
			gC_ProfileOptionNames[option],
			gC_ProfileOptionDescriptions[option],
			OptionType_Int,
			gI_ProfileOptionDefaults[option],
			0,
			gI_ProfileOptionCounts[option] - 1);
	}
}

bool IsProfileOption(const char[] option)
{
	for (ProfileOption i; i < PROFILEOPTION_COUNT; i++)
	{
		if (StrEqual(option, gC_ProfileOptionNames[i], true))
		{
			return true;
		}
	}

	return false;
}

void OnOptionsMenuCreated_OptionsMenu(TopMenu topMenu)
{
	if (gTM_Options == topMenu && gTMO_CatProfile != INVALID_TOPMENUOBJECT)
	{
		return;
	}

	gTMO_CatProfile = topMenu.AddCategory(PROFILE_OPTION_CATEGORY, TopMenuHandler_Categories);
}

void OnOptionsMenuReady_OptionsMenu(TopMenu topMenu)
{
	if (gTMO_CatProfile == INVALID_TOPMENUOBJECT)
	{
		GOKZ_OnOptionsMenuCreated(topMenu);
	}

	if (gTM_Options == topMenu)
	{
		return;
	}

	gTM_Options = topMenu;
	for (int option = 0; option < view_as<int>(PROFILEOPTION_COUNT); option++)
	{
		gTMO_ItemsProfile[option] = gTM_Options.AddItem(gC_ProfileOptionNames[option], TopMenuHandler_Profile, gTMO_CatProfile);
	}
}

void DisplayProfileOptionsMenu(int client)
{
	if (gTM_Options != null && gTMO_CatProfile != INVALID_TOPMENUOBJECT)
	{
		gTM_Options.DisplayCategory(gTMO_CatProfile, client);
	}
}

public void TopMenuHandler_Categories(TopMenu topMenu, TopMenuAction action, TopMenuObject topObjectID, int client, char[] buffer, int maxLength)
{
	if ((action == TopMenuAction_DisplayOption || action == TopMenuAction_DisplayTitle)
		&& topObjectID == gTMO_CatProfile)
	{
		Format(buffer, maxLength, "%T", "Options Menu - Profile", client);
	}
}

public void TopMenuHandler_Profile(TopMenu topMenu, TopMenuAction action, TopMenuObject topObjectID, int client, char[] buffer, int maxLength)
{
	ProfileOption option = PROFILEOPTION_INVALID;
	for (int i = 0; i < view_as<int>(PROFILEOPTION_COUNT); i++)
	{
		if (topObjectID == gTMO_ItemsProfile[i])
		{
			option = view_as<ProfileOption>(i);
			break;
		}
	}

	if (option == PROFILEOPTION_INVALID)
	{
		return;
	}

	if (action == TopMenuAction_DisplayOption)
	{
		if (option == ProfileOption_TagType)
		{
			int tagType = GOKZ_GetOption(client, gC_ProfileOptionNames[option]);
			char tagTypeName[64];
			if (tagType >= 0 && tagType < PROFILETAGTYPE_COUNT)
			{
				FormatEx(tagTypeName, sizeof(tagTypeName), "%T", gC_ProfileTagTypePhrases[tagType], client);
			}
			else
			{
				strcopy(tagTypeName, sizeof(tagTypeName), "Unknown");
			}

			FormatEx(buffer, maxLength, "%T - %s", gC_ProfileOptionPhrases[option], client, tagTypeName);
		}
		else
		{
			FormatEx(buffer, maxLength, "%T - %T",
				gC_ProfileOptionPhrases[option], client,
				gC_ProfileBoolPhrases[GOKZ_GetOption(client, gC_ProfileOptionNames[option])], client);
		}
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (option == ProfileOption_TagType)
		{
			GOKZ_SetOption(client, gC_ProfileOptionNames[option], GetNextAvailableTagType(client));
		}
		else
		{
			GOKZ_CycleOption(client, gC_ProfileOptionNames[option]);
		}

		gTM_Options.Display(client, TopMenuPosition_LastCategory);
	}
}
