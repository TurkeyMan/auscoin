module auscoin.app;

import vibe.d;
import vibe.data.json;
import vibe.utils.validation;

import std.traits;

import auscoin.account;
import auscoin.helper;

Timer timer;

struct CreateAccount
{
    string user;
    string pass;
    string verify;
    @optional string email;
}

struct LoginPass
{
    string user;
    string pass;
}

struct SessionID
{
    uint user;
    string key;
}

struct GetUser
{
    string user;
}

struct GetMap
{
    string map;
}

struct FriendRequest
{
    string friend;
}

struct UserID
{
    uint friend;
}

struct CreateGame
{
    string map;
    int numplayers;
}

struct GameID
{
    uint game;
}

struct PlayerConfig
{
    int race;
    int colour;
    int hero;
    bool ready;
}

struct GetGame
{
    @optional int start = 0;
    @optional int end = -1;
    @optional bool onlyactions;
}

struct Actions
{
    string actions;
}

struct Dump
{
    string password;
}


Json JsonSuccess()
{
    Json j = Json.EmptyObject;
    j.status = "success";
    return j;
}

// cron jobs
void cron()
{
    int x = 0;
    // logout inactive users
}

// http handlers
void apiHandler(alias handler)(HTTPServerRequest req, HTTPServerResponse res) if(is(typeof(handler) == function) && is(ParameterTypeTuple!handler[0] == HTTPServerResponse))
{
    try
    {
        ParameterTypeTuple!handler[1..$] args;
        foreach(ref a; args)
            a.loadFrom(req.params, req.form, req.query);
        handler(res, args);
    }
    catch(AusCoinException e)
        error(res, e.error);
}

void error(HTTPServerResponse res, string type = null)
{
    Json j = Json.EmptyObject;
    j.status = "error";
    if(type)
        j.error = type;
    res.writeBody(j.toPrettyString(), "text/plain");
}


// api handlers
void getUser(HTTPServerResponse res, GetUser get)
{
    User u = getUserByName(get.user);

    Json j = JsonSuccess;
    j.user = u.toJson();

	res.writeBody(j.toPrettyString(), "text/plain");
}

void getMap(HTTPServerResponse res, GetMap get)
{
    //...

	res.writeBody("map...", "text/plain");
}

void createAccount(HTTPServerResponse res, CreateAccount acc)
{
    try
        validateUserName(acc.user, 1, 64, "_()[]!$%^=+-", false);
    catch
        throw new AusCoinException("invalid username");
    try
        validatePassword(acc.pass, acc.verify, 6);
    catch
        throw new AusCoinException("invalid password");

    User u = createUser(acc.user, acc.pass, acc.email);
    u.newSession();

    Json j = JsonSuccess;
    j.user = u.toJson(true);

	res.writeBody(j.toPrettyString(), "text/plain");
}

void login(HTTPServerResponse res, LoginPass lp)
{
    User u = authenticate(lp.user, lp.pass);
    u.newSession();

    Json j = JsonSuccess;
    j.user = u.toJson(true);

	res.writeBody(j.toPrettyString(), "text/plain");
}

Account loggedInUser(ref SessionID session)
{
    Account u = findUser(session.user);
    wlAssert(icmp(u.sessionKey, session.key) == 0, "not logged in");
    u.lastSeen = Clock.currTime();
    return u;
}

void logout(HTTPServerResponse res, SessionID session)
{
    User u = loggedInUser(session);

    u.sessionKey = null;

    Json j = JsonSuccess;

	res.writeBody(j.toPrettyString(), "text/plain");
}

void requestFriend(HTTPServerResponse res, SessionID session, FriendRequest fr)
{
    User u = loggedInUser(session);
    User f = getUserByName(fr.friend);

    f.friendRequest(u);

    Json j = JsonSuccess;

	res.writeBody(j.toPrettyString(), "text/plain");
}

void acceptFriend(HTTPServerResponse res, SessionID session, UserID fr)
{
    User u = loggedInUser(session);
    User f = getUserById(fr.friend);

    u.acceptFriend(f);

    Json j = JsonSuccess;
    j.friend = f.toJson();

	res.writeBody(j.toPrettyString(), "text/plain");
}

void createLobby(HTTPServerResponse res, SessionID session, CreateGame create)
{
    User u = loggedInUser(session);

    Lobby l = Lobby.create(create.map, create.numplayers, u);

    Json j = JsonSuccess;
    j.lobby = l.toJson();

	res.writeBody(j.toPrettyString(), "text/plain");
}

void joinGame(HTTPServerResponse res, SessionID session, GameID game)
{
    User u = loggedInUser(session);
    Lobby l = getLobby(game.game);

    l.addPlayer(u);

    Json j = JsonSuccess;
    j.lobby = l.toJson();

	res.writeBody(j.toPrettyString(), "text/plain");
}

void leaveGame(HTTPServerResponse res, SessionID session, GameID game)
{
    User u = loggedInUser(session);
    Lobby l = getLobby(game.game);

    l.removePlayer(u);

    Json j = JsonSuccess;

	res.writeBody(j.toPrettyString(), "text/plain");
}

void configureGame(HTTPServerResponse res, SessionID session, GameID game, PlayerConfig config)
{
    User u = loggedInUser(session);
    Lobby l = getLobby(game.game);

    Game g = l.configPlayer(u, config.race, config.colour, config.hero, config.ready);

    Json j = JsonSuccess;
    if(g)
        j.game = g.toJson();
    else
        j.lobby = l.toJson();

	res.writeBody(j.toPrettyString(), "text/plain");
}

void invite(HTTPServerResponse res, SessionID session, GameID game, UserID invite)
{
    User u = loggedInUser(session);
    Lobby l = getLobby(game.game);
    User f = getUserById(invite.friend);

    f.invite(l, u);

    Json j = JsonSuccess;

	res.writeBody(j.toPrettyString(), "text/plain");
}

void getGame(HTTPServerResponse res, SessionID session, GameID game, GetGame opts)
{
    Game g = auscoin.game.getGame(game.game);
    User u = loggedInUser(session);

    wlAssert(isPlayerInGame(g, u), "not in game");

    Json j = JsonSuccess;
    j.game = g.toJson(opts.start, opts.end, opts.onlyactions);

	res.writeBody(j.toPrettyString(), "text/plain");
}

void commit(HTTPServerResponse res, SessionID session, GameID game, Actions commit)
{
    User u = loggedInUser(session);
    Game g = auscoin.game.getGame(game.game);

    wlAssert(isPlayerInGame(g, u), "not in game");

    g.commit(commit.actions);

    Json j = JsonSuccess;

	res.writeBody(j.toPrettyString(), "text/plain");
}

void dump(HTTPServerResponse res, Dump args)
{
    Json j = Json.EmptyObject;
    if(args.password[] != "terceS")
    {
        j.status = "error";
    }
    else
    {
        j.status = "success";
        j.users = allUsers();
        j.lobbies = allLobbies();
        j.games = allGames();
    }

	res.writeBody(j.toPrettyString(), "text/plain");
}

shared static this()
{
    timer = setTimer(dur!"minutes"(1), toDelegate(&cron), true);

	auto settings = new HTTPServerSettings;
//    settings.errorPageHandler = toDelegate(&errorPage);
	settings.port = 8888;
    settings.options = HTTPServerOption.parseURL | HTTPServerOption.parseFormBody | HTTPServerOption.parseQueryString;

    auto router = new URLRouter;
    router.any("/api/dump", &apiHandler!dump);
    router.any("/api/users/:user", &apiHandler!getUser);
    router.any("/api/maps/:map", &apiHandler!getMap);
    router.any("/api/createaccount", &apiHandler!createAccount);
    router.any("/api/login", &apiHandler!login);
    router.any("/api/logout", &apiHandler!logout);
    router.any("/api/requestfriend", &apiHandler!requestFriend);
    router.any("/api/acceptfriend", &apiHandler!acceptFriend);
    router.any("/api/creategame", &apiHandler!createLobby);
    router.any("/api/joingame", &apiHandler!joinGame);
    router.any("/api/leavegame", &apiHandler!leaveGame);
    router.any("/api/configuregame", &apiHandler!configureGame);
    router.any("/api/invite", &apiHandler!invite);
    router.any("/api/games/:game", &apiHandler!getGame);
    router.any("/api/commit", &apiHandler!commit);

	listenHTTP(settings, router);
}
