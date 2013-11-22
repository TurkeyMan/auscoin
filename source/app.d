module auscoin.app;

import vibe.d;
import vibe.data.json;
import vibe.utils.validation;

import std.traits;
import std.algorithm;

import auscoin.currency;
import auscoin.orderbook;
import auscoin.account;
import auscoin.helper;

Timer timer;

struct CreateAccount
{
	string user;
	string pass;
	string verify;
	string email;
}

struct LoginPass
{
	string user;
	string pass;
}

Json JsonSuccess()
{
	Json j = Json.emptyObject;
	j.status = "success";
	return j;
}

// cron jobs
void cron()
{
	SysTime now = Clock.currTime;

	// logout inactive users
	foreach(k, acc; accountBySession)
	{
/*
		if(now - acc.lastSeen > dur!"minutes"(5))
		{
			// logout user...
			accountBySession[k] = null;
		}
*/
	}
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

// api handlers

void configureParams(HTTPServerRequest req, HTTPServerResponse res)
{
//	req.params["path"] = req.path;
}

void login(HTTPServerRequest req, HTTPServerResponse res)
{
	if("email" in req.form && req.form["email"] in accountsByEmail && "password" in req.form)
	{
		string email = req.form["email"];
		string password = req.form["password"];

		Account user = accountsByEmail[email];

		if(user.validatePassword(password))
		{
			debug
				std.stdio.writeln("Login: #", user.accountId, " - ", user.name);

			user.lastSeen = Clock.currTime;
			auto session = createSession(res, user, password);
			res.redirect("/account");
			return;
		}
	}

	Account user = null;
	res.render!("login.dt", req, user);
}

void logout(HTTPServerRequest req, HTTPServerResponse res)
{
	debug
	{
		Account user = activeUser(req);
		std.stdio.writeln("Logout: ", user.name);
	}

	res.terminateSession();
	res.redirect("/");
}

void register(HTTPServerRequest req, HTTPServerResponse res)
{
	if("email" in req.form
		&& "password" in req.form
		&& "confirm" in req.form
		&& "firstname" in req.form
		&& "lastname" in req.form
		&& req.form["email"] !in accountsByEmail
		&& req.form["password"] == req.form["confirm"])
	{
		string email = req.form["email"];
		string password = req.form["password"];
		string first = req.form["firstname"];
		string last = req.form["lastname"];

		Account user = Account.create(email, password, first, last);

		debug
			std.stdio.writeln("Create Account: #", user.accountId, " - ", user.name);

		// TODO: email confirmation, but just login for now...
		auto session = createSession(res, user, password);
		res.redirect("/account");
		return;
	}

	Account user = null;
	res.render!("register.dt", req, user);
}

void checkLogin(HTTPServerRequest req, HTTPServerResponse res)
{
	// redirect to /login for unauthenticated users
	if(req.session is null)
	{
		res.redirect("/login");
	}
	else if(!req.session.isKeySet("sessionKey") || req.session["sessionKey"] !in accountBySession)
	{
		// the session is invalid, or has timed out
		res.terminateSession();
		res.redirect("/login");
	}
}

void deposit(HTTPServerRequest req, HTTPServerResponse res)
{
	Currency c = Currency.Unknown;
	double amount;

	if("BTC" in req.form)
	{
		c = Currency.XBT;
		amount = to!double(req.form["BTC"]);
	}
	else if("AUD" in req.form)
	{
		c = Currency.AUD;
		amount = to!double(req.form["AUD"]);
	}

	if(c != Currency.Unknown)
	{
		Account user = activeUser(req);
		user.deposit(c, amount);

		debug
			std.stdio.writeln(user.name, " -> Deposit: ", formatCurrency(c, amount));

		res.redirect("/account/summary");
		return;
	}

	loggedInTemplate!"deposit.dt"()(req, res);
}

void trade(HTTPServerRequest req, HTTPServerResponse res)
{
	Account user = activeUser(req);
	Market market = Market(CurrencyPair(Currency.XBT, Currency.AUD));

	if("buyamount" in req.form && "buyprice" in req.form)
	{
		double amount = to!double(req.form["buyamount"]);
		double price = to!double(req.form["buyprice"]);

		exchange.placeBuyOrder(user, market, amount, price, false);

		debug
			std.stdio.writeln(user.name, " -> Buy: ", formatCurrency(Currency.XBT, amount), " for: ", formatCurrency(Currency.AUD, price), "/ea (", formatCurrency(Currency.AUD, amount*price), ")");
	}
	else if("sellamount" in req.form && "sellprice" in req.form)
	{
		double amount = to!double(req.form["sellamount"]);
		double price = to!double(req.form["sellprice"]);

		exchange.placeSellOrder(user, market, amount, price, false);

		debug
			std.stdio.writeln(user.name, " -> Sell: ", formatCurrency(Currency.XBT, amount), " for: ", formatCurrency(Currency.AUD, price), "/ea (", formatCurrency(Currency.AUD, amount*price), ")");
	}

	res.render!("trade.dt", req, user);
}

@property HTTPServerRequestDelegate loggedInTemplate(string template_file)()
{
	return (HTTPServerRequest req, HTTPServerResponse res)
	{
		Account user = activeUser(req);

		debug
			std.stdio.writeln(user ? user.name : "Unauthenticated", " -> ", req.path);

		res.render!(template_file, req, user);
	};
}

void errorPage(HTTPServerRequest req, HTTPServerResponse res, HTTPServerErrorInfo error)
{
	Account user = activeUser(req);

	debug
		std.stdio.writeln(user ? user.name : "Unauthenticated", ": Error ", error.code, " - ", error.message);

	res.render!("error.dt", req, user, error);
}

shared static this()
{
	timer = setTimer(dur!"minutes"(2), toDelegate(&cron), true);

	auto settings = new HTTPServerSettings;
	settings.errorPageHandler = toDelegate(&errorPage);
	settings.port = 8888;
	settings.options = HTTPServerOption.parseURL | HTTPServerOption.parseFormBody | HTTPServerOption.parseQueryString | HTTPServerOption.parseCookies;
	settings.sessionStore = new MemorySessionStore;

	auto router = new URLRouter;

	// static files
	router.get("*", serveStaticFiles("./www/"));

	// setup variables...?
	router.any("*", &configureParams);

	// public pages
	router.get("/", loggedInTemplate!"index.dt");
	router.any("/login", &login);
	router.get("/logout", &logout);
	router.any("/register", &register);

	// private pages
	router.any("*", &checkLogin);
	router.any("/profile", loggedInTemplate!"profile.dt");

	router.any("/account", staticRedirect("/account/summary"));
	router.any("/account/summary", loggedInTemplate!"summary.dt");
	router.any("/account/deposit", &deposit);//loggedInTemplate!"deposit.dt");
	router.any("/account/withdraw", loggedInTemplate!"withdraw.dt");

	router.any("/trade", &trade);

	router.any("/market", staticRedirect("/market/orders"));
	router.any("/market/orders", loggedInTemplate!"orders.dt");
	router.any("/market/trades", loggedInTemplate!"trades.dt");
	//	router.any("/api/users/:user", &apiHandler!getUser);

	listenHTTP(settings, router);
}
 