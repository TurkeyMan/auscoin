module auscoin.currency;

import std.typecons;

enum Currency
{
	Unknown = -1,

	XBT,
//	LTC,
	AUD,
//	NZD,
}

enum size_t NumCurrencies = Currency.max + 1;
enum NumMarkets = (NumCurrencies-1)*(NumCurrencies) / 2; // (1 + 2 + 3 + ... + n)

struct CurrencyDesc
{
	Currency id;
	string code;
	string name;
	string symbol;
	bool suffix;
	int fix;
	int shift;
}

immutable CurrencyDesc[NumCurrencies] currencies =
[
	{ Currency.XBT, "BTC", "Bitcoin", " BTC", true, 0, 0 },
	{ Currency.AUD, "AUD", "AU Dollars", "$", false, 2, 0 },
];

alias CurrencyPair = Tuple!(Currency, Currency);


Currency findCurrency(string currency)
{
	foreach(i, c; currencies)
	{
		if(currency[] == c.code[])
			return cast(Currency)i;
	}
	return Currency.Unknown;
}

string formatCurrency(Currency currency, double value)
{
	value *= 10^^currencies[currency].shift;
	string v = currencies[currency].fix ? std.string.format("%.*f", currencies[currency].fix, value) : std.conv.to!string(value);
	if(currencies[currency].suffix)
		return v ~ currencies[currency].symbol;
	else
		return currencies[currency].symbol ~ v;
}
