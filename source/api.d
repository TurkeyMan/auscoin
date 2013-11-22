module auscoin.api;

import vibe.d;

import auscoin.currency;
import auscoin.orderbook;
import auscoin.account;


void marketApi(HTTPServerRequest req, HTTPServerResponse res)
{
	// return market stats
}

void loginApi(HTTPServerRequest req, HTTPServerResponse res)
{
	// authenticate and return a session key
}

void logoutApi(HTTPServerRequest req, HTTPServerResponse res)
{
	// authenticate and return a session key
}

void placeOrderApi(HTTPServerRequest req, HTTPServerResponse res)
{
	// place a trade order
}

void ordersApi(HTTPServerRequest req, HTTPServerResponse res)
{
	// a users orders

	// options for open/closed?
}
