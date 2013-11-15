module auscoin.currency;

import std.typecons;

enum Currency
{
	XBT,
	LTC,
	AUD,
	NZD,

	NumCurrencies,
	NumMarkets = (NumCurrencies-1)*(NumCurrencies) / 2	// (1 + 2 + 3 + ... + n)
}

alias CurrencyPair = Tuple!(Currency, Currency);
