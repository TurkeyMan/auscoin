module auscoin.account;

import auscoin.currency;

import std.datetime;

import vibe.data.json;

__gshared uint numAccounts = 0;

void saveAccountDb()
{
	Json js = serializeToJson(accountsByEmail);
	std.file.write("users.json", js.toString());
}

shared static this()
{
	try
	{
		auto bytes = cast(string)std.file.read("users.json");
		if(bytes)
		{
			Json js = parseJsonString(bytes);
			deserializeJson(accountsByEmail, js);
			foreach(acc; accountsByEmail)
			{
				accountsById[acc.accountId] = acc;
				numAccounts = std.algorithm.max(numAccounts, acc.accountId + 1);
			}
		}
	}
	catch
	{
		// file missing?
	}
}

class Account
{
	static Account create(string email, string password, string firstName, string lastName)
	{
		Account acc = new Account();

		acc.accountId = numAccounts++;

		acc.email = email;
		acc.passwordHash = hashPassword(password);

		acc.registered = Clock.currTime;
		acc.lastSeen = acc.registered;

		acc.firstName = firstName;
		acc.lastName = lastName;

		accountsById[acc.accountId] = acc;
		accountsByEmail[email] = acc;

		saveAccountDb();

		return acc;
	}

	private static string hashPassword(string password)
	{
		return std.digest.digest.toHexString(std.digest.sha.sha1Of("s@lty " ~ password ~ " of p0w3r!")).idup;
	}

	bool validatePassword(string password)
	{
		string hash = hashPassword(password);
		return passwordHash[] == hash[];
	}

	void deposit(Currency currency, double amount)
	{
		accounts(currency) += amount;

		activity ~= Activity(Activity.Action.Deposit, Clock.currTime, 0, Currency.Unknown, amount, currency);

		saveAccountDb();
	}

	void withdraw(Currency currency, double amount)
	{
		accounts(currency) -= amount;

		activity ~= Activity(Activity.Action.Deposit, Clock.currTime, amount, currency, 0, Currency.Unknown);

		saveAccountDb();
	}

	void trade(Currency buy, double buyAmount, Currency sell, double sellAmount)
	{
		accounts(buy) += buyAmount;
		accounts(sell) -= sellAmount;

		activity ~= Activity(Activity.Action.Trade, Clock.currTime, sellAmount, sell, buyAmount, buy);

		saveAccountDb();
	}

	uint accountId;

	string email;
	string passwordHash;

	SysTime registered;
	@ignore SysTime lastSeen;

	// profile details...
	string firstName;
	string lastName;
	@property string name() { return firstName ~ " " ~ lastName; }

	// HACK: serialiser doesn't handle static arrays >_<
//	double[Currency.NumCurrencies] accounts;
	double XBT = 0;
	double AUD = 0;

	@property ref double accounts(Currency currency)
	{
		switch(currency)
		{
			case Currency.XBT:
				return XBT;
			case Currency.AUD:
				return AUD;
			default:
				assert(0);
		}
	}

	string[] bitcoinDepositAddresses;

	struct Activity
	{
		enum Action
		{
			Deposit,
			Withdraw,
			Trade
		}

		Action action;
		SysTime timestamp;
		@optional double debit = 0;
		@optional Currency debitCurrency = Currency.Unknown;
		@optional double credit = 0;
		@optional Currency creditCurrency = Currency.Unknown;
	}

	Activity[] activity;
}

Account findUser(uint accountId)
{
	return accountsById[accountId];
}

Account findUser(string email)
{
	return accountsByEmail[email];
}

__gshared Account[uint] accountsById;
__gshared Account[string] accountsByEmail;
__gshared Account[string] accountBySession;
