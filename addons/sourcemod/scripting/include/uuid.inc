#if defined _uuid_included_
#endinput
#endif
#define _uuid_included_

#define UUID_STRING_LENGTH 37

/**
 * Generates an RFC 9562 UUIDv7 string.
 *
 * SourcePawn has no native 64-bit integer cell on the target runtime, so the
 * 48-bit Unix millisecond timestamp is built byte-by-byte from GetTime().
 */
stock void UUID_GenerateV7(char[] buffer, int maxlength)
{
	int bytes[16];
	UUID_FillUnixMilliseconds(bytes);

	bytes[6] = 0x70 | GetRandomInt(0x00, 0x0F);
	bytes[7] = GetRandomInt(0x00, 0xFF);
	bytes[8] = 0x80 | GetRandomInt(0x00, 0x3F);

	for (int i = 9; i < 16; i++)
	{
		bytes[i] = GetRandomInt(0x00, 0xFF);
	}

	Format(buffer, maxlength,
		"%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x",
		bytes[0], bytes[1], bytes[2], bytes[3],
		bytes[4], bytes[5],
		bytes[6], bytes[7],
		bytes[8], bytes[9],
		bytes[10], bytes[11], bytes[12], bytes[13], bytes[14], bytes[15]);
}

stock void UUID_FillUnixMilliseconds(int bytes[16])
{
	int seconds = GetTime();
	int carry = GetRandomInt(0, 999);

	for (int i = 5; i >= 0; i--)
	{
		int part = (seconds & 0xFF) * 1000 + carry;
		bytes[i] = part & 0xFF;
		carry = part >> 8;
		seconds = seconds >> 8;
	}
}
