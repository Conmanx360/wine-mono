
using System;

static class Test
{
	static public int Main()
	{
		try
		{
			if (MixedModeDllImport.dllimport_0(-5) != 0)
				return 1;
		}
		catch (DllNotFoundException)
		{
			return 0;
		}
		return 2;
	}
}
