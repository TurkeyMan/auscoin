module auscoin.app;

import vibe.d;
import vibe.data.json;

import auscoin.account;
import auscoin.pages;
import auscoin.api;


Timer timer;

// cron jobs
void cron()
{
	SysTime now = Clock.currTime;

	accountCron(now);
}


// setup router on startup
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

	// public pages
	router.get("/", loggedInTemplate!"index.dt");
	router.any("/login", &login);
	router.get("/logout", &logout);
	router.any("/register", &register);

	// public api
	router.any("/api/market", &marketApi);
	router.any("/api/login", &loginApi);
	router.any("/api/logout", &logoutApi);

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

	router.any("/api/placeorder", &placeOrderApi);
	router.any("/api/orders", &ordersApi);

//	router.any("/api/users/:user", &apiHandler!getUser);

	listenHTTP(settings, router);
}
