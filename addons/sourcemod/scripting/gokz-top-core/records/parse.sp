// =====[ RESPONSE PARSING ]=====

bool ParseMapTiersResponse(const char[] body, int &kztTier, int &skzTier, int &vnlTier)
{
	kztTier = 0;
	skzTier = 0;
	vnlTier = 0;

	JSON_Object root = json_decode(body);
	if (root == null || !root.IsArray || root.Length <= 0)
	{
		delete root;
		return false;
	}

	JSON_Object map = root.GetObjectIndexed(0);
	if (map == null)
	{
		root.Cleanup();
		delete root;
		return false;
	}

	JSON_Object tiers = map.GetObject("tiers");
	if (tiers == null)
	{
		root.Cleanup();
		delete root;
		return false;
	}

	kztTier = tiers.GetInt("KZT");
	skzTier = tiers.GetInt("SKZ");
	vnlTier = tiers.GetInt("VNL");

	root.Cleanup();
	delete root;
	return true;
}

bool ParseWRResponse(const char[] body, float &wrTime)
{
	wrTime = -1.0;

	JSON_Object root = json_decode(body);
	if (root == null || !root.IsArray || root.Length <= 0)
	{
		delete root;
		return false;
	}

	JSON_Object record = root.GetObjectIndexed(0);
	if (record == null)
	{
		root.Cleanup();
		delete root;
		return false;
	}

	wrTime = record.GetFloat("time");

	root.Cleanup();
	delete root;
	return true;
}

bool ParsePBResponse(const char[] body, float &pbTime, int &pbPoints, char[] createdOn, int createdOnLength)
{
	pbTime = -1.0;
	pbPoints = 0;
	createdOn[0] = '\0';

	JSON_Object root = json_decode(body);
	if (root == null || !root.IsArray || root.Length <= 0)
	{
		delete root;
		return false;
	}

	JSON_Object record = root.GetObjectIndexed(0);
	if (record == null)
	{
		root.Cleanup();
		delete root;
		return false;
	}

	pbTime = record.GetFloat("time");
	pbPoints = record.GetInt("points");
	record.GetString("created_on", createdOn, createdOnLength);

	root.Cleanup();
	delete root;
	return true;
}
