module auscoin.account;

import auscoin.currency;

class Account
{
	uint accountId;

	string email;
	string passwordHash;

	// profile details...

	double[Currency.NumCurrencies] accounts;
}

Account findUser(uint accountId)
{
	return accountsById[accountId];
}

Account findUser(string email)
{
	return accountsByEmail[email];
}

private Account[uint] accountsById;
private Account[string] accountsByEmail;
