module auscoin.helper;

import vibe.d;
import std.traits;
import auscoin.account;

class AusCoinException : Exception
{
	this(string err)
	{
		super("AusCoin error: " ~ err);
		error = err;
	}

	string error;
}

template AllAreAA(T...)
{
	static if(T.length == 0)
		enum AllAreAA = true;
	else
		enum AllAreAA = is(T[0] == string[string]) && AllAreAA!(T[1..$]);
}

template hasAttribute(alias T, alias A)
{
	template impl(alias A, T...)
	{
		static if(T.length == 0)
			enum impl = false;
		else
			enum impl = is(T[0] == A) || impl!(A, T[1..$]);
	}

	enum hasAttribute = impl!(A, __traits(getAttributes, T));
}

void loadFrom(alias s, string name, A...)(A args) if(AllAreAA!A && is(typeof(s) == struct))
{
	alias T = typeof(s);
	foreach(m; __traits(allMembers, T))
	{
		static if(!isSomeFunction!(__traits(getMember, s, m)))
		{
			bool bFound;
			foreach(aa; args)
			{
				if(m in aa)
				{
					__traits(getMember, s, m) = to!(typeof(__traits(getMember, s, m)))(aa[m]);
					bFound = true;
					break;
				}
			}

			if(!hasAttribute!(__traits(getMember, s, m), optional) && !bFound)
				throw new AusCoinException("missing arguments");
		}
	}
}

void loadFrom(alias m, string name, A...)(A args) if(AllAreAA!A && !is(typeof(m) == struct))
{
	bool bFound;
	foreach(aa; args)
	{
		if(name in aa)
		{
			m = to!(typeof(m))(aa[name]);
			bFound = true;
			break;
		}
	}

	if(!hasAttribute!(m, optional) && !bFound)
		throw new AusCoinException("missing arguments");
}


auto createSession(HTTPServerResponse res, Account user, string password)
{
	string sessionKey = std.digest.digest.toHexString(std.digest.sha.sha1Of(password ~ to!string(user.lastSeen))).idup;

	auto session = res.startSession();
	session["sessionKey"] = sessionKey;
	accountBySession[sessionKey] = user;

	return session;
}

Account activeUser(HTTPServerRequest req)
{
	Account user = null;
	if(req.session !is null && req.session.isKeySet("sessionKey") && req.session["sessionKey"] in accountBySession)
		user = accountBySession[req.session["sessionKey"]];
	return user;
}
