module auscoin.helper;

import vibe.d;
import std.traits;

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

enum optional;

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

void loadFrom(T, A...)(out T s, A args) if(AllAreAA!A)
{
    foreach(m; __traits(allMembers, T))
    {
        static if(!isSomeFunction!(__traits(getMember, T, m)))
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

            if(!hasAttribute!(__traits(getMember, T, m), optional) && !bFound)
                throw new AusCoinException("missing arguments");
        }
    }
}

void wlAssert(bool bTest, string msg)
{
    if(!bTest)
        throw new AusCoinException(msg);
}
