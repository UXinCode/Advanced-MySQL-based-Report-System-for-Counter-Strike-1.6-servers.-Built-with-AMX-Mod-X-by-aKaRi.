#include <amxmodx>
#include <amxmisc>
#include <sqlx>

#define PLUGIN  "Report System"
#define VERSION "1.3"
#define AUTHOR  "aKaRi"

#define REPORT_MAX_LEN 80
#define TASK_TUTOR     55220
#define TASK_SQLERR    55221
#define PLAYERS_PER_PAGE 8

// ======================== KONFIGURACJA SQL ========================
new const DEFAULT_SQL_HOST[] = "YourHost";
new const DEFAULT_SQL_USER[] = "ID USER";
new const DEFAULT_SQL_PASS[] = "YourPassSQL";
new const DEFAULT_SQL_DB[]   = "DateBase";

#define ADMIN_FLAG_REPORTS ADMIN_BAN

// Kolor akcentu MOTD (ramka + etykiety)
new const MOTD_ACCENT[] = "#78f305";

// Symbol strzalki (SYMBOL_DR_ARROW z BaseBuilder) - UTF-8 »
new const SYMBOL_DR_ARROW[] = "^xc2^xbb";

// Tutor kolory
enum TutorColor { TUTOR_RED = 1, TUTOR_BLUE, TUTOR_YELLOW, TUTOR_GREEN };

new const gTutorPrecache[][] = {
	"gfx/career/icon_!.tga",
	"gfx/career/icon_!-bigger.tga",
	"gfx/career/icon_i.tga",
	"gfx/career/icon_i-bigger.tga",
	"gfx/career/icon_skulls.tga",
	"gfx/career/round_corner_ne.tga",
	"gfx/career/round_corner_nw.tga",
	"gfx/career/round_corner_se.tga",
	"gfx/career/round_corner_sw.tga",
	"resource/TutorScheme.res",
	"resource/UI/TutorTextWindow.res"
};

// ======================== ZMIENNE ========================
new Handle:g_SqlTuple;
new Handle:g_SqlConnection;
new bool:g_SqlConnected;

new userReportPlayer[33][REPORT_MAX_LEN];
new userReportIdea[33][REPORT_MAX_LEN];
new userReportTarget[33][32];
new userReportPage[33];
new userSelectList[33][33];

new pcvar_sql_host, pcvar_sql_user, pcvar_sql_pass, pcvar_sql_db;
new g_msgSayText;

// ======================== PLUGIN ========================
public plugin_precache()
{
	for(new i = 0; i < sizeof(gTutorPrecache); i++)
		precache_generic(gTutorPrecache[i]);
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /raport",       "cmdReport");
	register_clcmd("say_team /raport",  "cmdReport");
	register_clcmd("say /raporty",      "cmdReportAdmin");
	register_clcmd("say_team /raporty", "cmdReportAdmin");
	
	register_clcmd("Raport_Gracz",  "reportReadPlayer");
	register_clcmd("Raport_Pomysl", "reportReadIdea");
	
	register_menucmd(register_menuid("ReportMenu"), 1023, "reportMenuHandler");
	register_menucmd(register_menuid("ReportSelectPlayer"), 1023, "reportSelectPlayerHandler");
	
	pcvar_sql_host = register_cvar("report_sql_host", DEFAULT_SQL_HOST);
	pcvar_sql_user = register_cvar("report_sql_user", DEFAULT_SQL_USER);
	pcvar_sql_pass = register_cvar("report_sql_pass", DEFAULT_SQL_PASS);
	pcvar_sql_db   = register_cvar("report_sql_db",   DEFAULT_SQL_DB);
	
	g_msgSayText = get_user_msgid("SayText");
	
	set_task(1.0, "sqlInit");
	set_task(1.0, "sqlErrorLoop", TASK_SQLERR, _, _, "b");
}

public plugin_end()
{
	if(g_SqlConnection != Empty_Handle)
		SQL_FreeHandle(g_SqlConnection);
	if(g_SqlTuple != Empty_Handle)
		SQL_FreeHandle(g_SqlTuple);
}

public client_disconnected(id)
{
	userReportPlayer[id][0] = 0;
	userReportIdea[id][0] = 0;
	userReportTarget[id][0] = 0;
	userReportPage[id] = 0;
	remove_task(id + TASK_TUTOR);
}

// ======================== SQL ========================
public sqlInit()
{
	new host[64], user[64], pass[64], db[64], error[128], errorNum;
	new pHost, pUser, pPass, pDb;
	
	// Baza BaseBuildera (bb_sql_*) ma pierwszenstwo, potem cvary wtyczki
	pHost = get_cvar_pointer("bb_sql_host");
	pUser = get_cvar_pointer("bb_sql_user");
	pPass = get_cvar_pointer("bb_sql_pass");
	pDb   = get_cvar_pointer("bb_sql_db");
	
	if(pHost) get_pcvar_string(pHost, host, charsmax(host));
	else get_pcvar_string(pcvar_sql_host, host, charsmax(host));
	if(pUser) get_pcvar_string(pUser, user, charsmax(user));
	else get_pcvar_string(pcvar_sql_user, user, charsmax(user));
	if(pPass) get_pcvar_string(pPass, pass, charsmax(pass));
	else get_pcvar_string(pcvar_sql_pass, pass, charsmax(pass));
	if(pDb) get_pcvar_string(pDb, db, charsmax(db));
	else get_pcvar_string(pcvar_sql_db, db, charsmax(db));
	
	if(!host[0]) copy(host, charsmax(host), DEFAULT_SQL_HOST);
	if(!user[0]) copy(user, charsmax(user), DEFAULT_SQL_USER);
	if(!pass[0]) copy(pass, charsmax(pass), DEFAULT_SQL_PASS);
	if(!db[0]) copy(db, charsmax(db), DEFAULT_SQL_DB);
	
	g_SqlTuple = SQL_MakeDbTuple(host, user, pass, db);
	g_SqlConnection = SQL_Connect(g_SqlTuple, errorNum, error, charsmax(error));
	
	if(errorNum)
	{
		log_amx("[ReportSystem] Blad polaczenia z baza [%d]: %s", errorNum, error);
		g_SqlConnected = false;
		g_SqlTuple = Empty_Handle;
		sqlErrorLoop();
		set_task(10.0, "sqlInit");
		return;
	}
	
	log_amx("[ReportSystem] Polaczono z baza danych (%s / %s)", host, db);
	
	new queryData[512];
	formatex(queryData, charsmax(queryData),
		"CREATE TABLE IF NOT EXISTS `reports` ( \
			`id` INT NOT NULL AUTO_INCREMENT, \
			`name` varchar(33) NOT NULL, \
			`date` varchar(12) NOT NULL, \
			`time` varchar(8) NOT NULL, \
			`map` varchar(32) NOT NULL, \
			`bug` varchar(80) NOT NULL DEFAULT '', \
			`player` varchar(80) NOT NULL DEFAULT '', \
			`idea` varchar(80) NOT NULL DEFAULT '', \
			`created` DATETIME DEFAULT NOW(), \
			PRIMARY KEY (`id`), \
			INDEX (`name`) \
		) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_general_ci;"
	);
	
	new Handle:query = SQL_PrepareQuery(g_SqlConnection, queryData);
	if(!SQL_Execute(query))
	{
		new err[128];
		SQL_QueryError(query, err, charsmax(err));
		log_amx("[ReportSystem] Blad tworzenia tabeli: %s", err);
	}
	SQL_FreeHandle(query);
	
	g_SqlConnected = true;
	remove_task(TASK_SQLERR);
	sqlClearFade();
}

stock bool:isSqlReady()
{
	return (g_SqlConnected && g_SqlTuple != Empty_Handle);
}

stock reportSqlErrorHud(id)
{
	sqlErrorShow(id);
}

public sqlErrorLoop()
{
	if(g_SqlConnected)
	{
		remove_task(TASK_SQLERR);
		sqlClearFade();
		return;
	}
	
	new players[32], num, i, pid;
	get_players(players, num, "ch");
	for(i = 0; i < num; i++)
	{
		pid = players[i];
		sqlErrorShow(pid);
	}
}

stock sqlErrorShow(id)
{
	if(!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, id);
	write_short(1<<12);
	write_short(1<<12);
	write_short(1 | 4);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(200);
	message_end();
	
	set_hudmessage(215, 15, 15, -1.0, 0.35, 0, 0.0, 1.2, 0.0, 0.0, -1);
	show_hudmessage(id, "Wystapil blad przy probie nawiazania polaczenia z baza danych!");
	
	set_hudmessage(15, 215, 15, -1.0, 0.40, 0, 0.0, 1.2, 0.0, 0.0, -1);
	show_hudmessage(id, "Napisz do aKaRi jesli to widzisz!");
	
	set_hudmessage(215, 215, 15, -1.0, 0.45, 0, 0.0, 1.2, 0.0, 0.0, -1);
	show_hudmessage(id, "Teraz nic sie nie zapisuje w systemie raportow!");
}

stock sqlClearFade()
{
	new players[32], num, i, pid;
	get_players(players, num, "ch");
	for(i = 0; i < num; i++)
	{
		pid = players[i];
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenFade"), _, pid);
		write_short(1<<10);
		write_short(0);
		write_short(0);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		write_byte(0);
		message_end();
	}
}

// ======================== CZAT KOLOROWY ========================
stock chat_print(id, const msg[], any:...)
{
	new text[192];
	vformat(text, charsmax(text), msg, 3);
	
	new out[192];
	formatex(out, charsmax(out), "^x04[aKaRi_Plugins]^x01 %s", text);
	
	if(id)
	{
		message_begin(MSG_ONE, g_msgSayText, _, id);
		write_byte(id);
		write_string(out);
		message_end();
	}
	else
	{
		new players[32], num, i, pid;
		get_players(players, num, "ch");
		for(i = 0; i < num; i++)
		{
			pid = players[i];
			message_begin(MSG_ONE, g_msgSayText, _, pid);
			write_byte(pid);
			write_string(out);
			message_end();
		}
	}
}

// ======================== TUTOR ========================
stock tutorMake(id, TutorColor:ColorSelect, Float:fTime = 0.0, const szText[], any:...)
{
	if(!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	
	static szMessage[192];
	vformat(szMessage, charsmax(szMessage), szText, 5);
	
	static msgTutorText;
	if(!msgTutorText) msgTutorText = get_user_msgid("TutorText");
	
	message_begin(MSG_ONE_UNRELIABLE, msgTutorText, .player = id);
	write_string(szMessage);
	write_byte(0);
	write_short(0);
	write_short(0);
	write_short(1 << _:ColorSelect);
	message_end();
	
	if(fTime != 0.0)
	{
		remove_task(id + TASK_TUTOR);
		set_task(fTime, "tutorClose", id + TASK_TUTOR);
	}
}

public tutorClose(taskid)
{
	new id = taskid - TASK_TUTOR;
	
	if(!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return;
	
	static msgTutorClose;
	if(!msgTutorClose) msgTutorClose = get_user_msgid("TutorClose");
	
	message_begin(MSG_ONE_UNRELIABLE, msgTutorClose, .player = id);
	message_end();
}

// ======================== POMOCNICZE ========================
stock reportCut(const src[], dest[], len)
{
	if(!src[0])
	{
		copy(dest, len, "-");
		return;
	}
	if(strlen(src) <= 8)
	{
		copy(dest, len, src);
		return;
	}
	copy(dest, 8, src);
	add(dest, len, "...");
}

stock escape_string(sz[], len)
{
	replace_all(sz, len, "\\", "\\\\");
	replace_all(sz, len, "'", "''");
}

stock bool:isUserAdmin(id)
{
	return bool:(get_user_flags(id) & (ADMIN_KICK|ADMIN_BAN|ADMIN_IMMUNITY|ADMIN_RCON|ADMIN_CFG|ADMIN_LEVEL_A));
}

// ======================== MENU GRACZA ========================
public cmdReport(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	if(!isSqlReady())
	{
		reportSqlErrorHud(id);
		return PLUGIN_HANDLED;
	}
	
	showReportMenu(id);
	return PLUGIN_HANDLED;
}

stock showReportMenu(id)
{
	new gText[512], iLen;
	new szDate[12], szTime[8];
	new szPlayer[24], szIdea[16];
	new szName[32];
	
	get_user_name(id, szName, charsmax(szName));
	get_time("%d-%m-%y", szDate, charsmax(szDate));
	get_time("%H:%M", szTime, charsmax(szTime));
	
	if(userReportTarget[id][0] && userReportPlayer[id][0])
	{
		new tmp[48];
		formatex(tmp, charsmax(tmp), "%s: %s", userReportTarget[id], userReportPlayer[id]);
		reportCut(tmp, szPlayer, charsmax(szPlayer));
	}
	else if(userReportTarget[id][0])
	{
		reportCut(userReportTarget[id], szPlayer, charsmax(szPlayer));
	}
	else
	{
		reportCut(userReportPlayer[id], szPlayer, charsmax(szPlayer));
	}
	
	reportCut(userReportIdea[id], szIdea, charsmax(szIdea));
	
	iLen  = formatex(gText, charsmax(gText), "\yaKaRi_Plugins \y|\w Menu Raportow^n");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\y%s^t\dBezpodstawne zgloszania graczy nie beda sprawdzane!^n", SYMBOL_DR_ARROW);
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\y%s^t\dRaportujacy:\r %s^n", SYMBOL_DR_ARROW, szName);
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\y%s^t\dData:\r %s \d| godz:\r %s^n^n", SYMBOL_DR_ARROW, szDate, szTime);
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r1.\w Zglaszam Gracza \d[\r%s\d]^n", szPlayer);
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r2.\w Mam Propozycje \d[\r%s\d]^n^n", szIdea);
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r3.\w Zatwierdz i wyslij Raport^n^n");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r0.\w Wyjscie");
	
	show_menu(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0, gText, -1, "ReportMenu");
}

public reportMenuHandler(id, key)
{
	switch(key)
	{
		case 0:
		{
			userReportPage[id] = 0;
			showSelectPlayerMenu(id);
		}
		case 1:
		{
			client_cmd(id, "messagemode Raport_Pomysl");
		}
		case 2:
		{
			reportSend(id);
		}
		case 9: return PLUGIN_HANDLED;
	}
	return PLUGIN_HANDLED;
}

// ======================== MENU WYBORU GRACZA ========================
stock showSelectPlayerMenu(id)
{
	new players[32], num, i, pid;
	get_players(players, num, "ch");
	
	new list[32], listNum;
	for(i = 0; i < num; i++)
	{
		pid = players[i];
		if(pid == id) continue;
		list[listNum++] = pid;
	}
	
	if(!listNum)
	{
		chat_print(id, "Brak innych graczy na serwerze!");
		showReportMenu(id);
		return;
	}
	
	new maxPage = (listNum - 1) / PLAYERS_PER_PAGE;
	if(userReportPage[id] > maxPage)
		userReportPage[id] = 0;
	
	new start = userReportPage[id] * PLAYERS_PER_PAGE;
	new end = start + PLAYERS_PER_PAGE;
	if(end > listNum) end = listNum;
	
	new gText[512], iLen, keys;
	new szName[32], slot;
	
	iLen  = formatex(gText, charsmax(gText), "\yaKaRi_Plugins |\w Wybierz gracza^n");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\y%s^t\dBezpodstawne zgloszania graczy nie beda sprawdzane!^n^n", SYMBOL_DR_ARROW);
	
	for(i = 0; i < 33; i++)
		userSelectList[id][i] = 0;
	
	slot = 0;
	for(i = start; i < end; i++)
	{
		pid = list[i];
		get_user_name(pid, szName, charsmax(szName));
		
		userSelectList[id][slot] = pid;
		
		if(isUserAdmin(pid))
			iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r%d.\w %s \d[\r Admin\d ]^n", slot + 1, szName);
		else
			iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r%d.\w %s^n", slot + 1, szName);
		
		keys |= (1 << slot);
		slot++;
	}
	
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "^n");
	
	if(userReportPage[id] < maxPage)
	{
		iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r9.\w Dalej^n");
		keys |= MENU_KEY_9;
	}
	
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "\r0.\w Wyjdz");
	keys |= MENU_KEY_0;
	
	show_menu(id, keys, gText, -1, "ReportSelectPlayer");
}

public reportSelectPlayerHandler(id, key)
{
	if(key == 9)
	{
		showReportMenu(id);
		return PLUGIN_HANDLED;
	}
	
	if(key == 8)
	{
		userReportPage[id]++;
		showSelectPlayerMenu(id);
		return PLUGIN_HANDLED;
	}
	
	new target = userSelectList[id][key];
	if(!target || !is_user_connected(target))
	{
		chat_print(id, "Ten gracz juz nie jest na serwerze!");
		showSelectPlayerMenu(id);
		return PLUGIN_HANDLED;
	}
	
	get_user_name(target, userReportTarget[id], charsmax(userReportTarget[]));
	userReportPlayer[id][0] = 0;
	
	chat_print(id, "Wybrano gracza: %s. Teraz wpisz powod zgloszenia.", userReportTarget[id]);
	client_cmd(id, "messagemode Raport_Gracz");
	
	return PLUGIN_HANDLED;
}

// ======================== ODCZYT TRESCI ========================
stock reportRead(id, dest[], len)
{
	new szArg[REPORT_MAX_LEN];
	read_args(szArg, charsmax(szArg));
	remove_quotes(szArg);
	trim(szArg);
	
	replace_all(szArg, charsmax(szArg), "|", "/");
	
	if(strlen(szArg) < 3)
	{
		chat_print(id, "Raport jest za krotki! (min. 3 znaki)");
		showReportMenu(id);
		return;
	}
	
	copy(dest, len, szArg);
	showReportMenu(id);
}

public reportReadPlayer(id)
{
	if(!userReportTarget[id][0])
	{
		chat_print(id, "Najpierw wybierz gracza z listy!");
		userReportPage[id] = 0;
		showSelectPlayerMenu(id);
		return;
	}
	reportRead(id, userReportPlayer[id], charsmax(userReportPlayer[]));
}

public reportReadIdea(id)
{
	reportRead(id, userReportIdea[id], charsmax(userReportIdea[]));
}

// ======================== WYSYLANIE ========================
public reportSend(id)
{
	if(!isSqlReady())
	{
		reportSqlErrorHud(id);
		return;
	}
	
	new bool:hasPlayer = bool:(userReportTarget[id][0] && userReportPlayer[id][0]);
	new bool:hasIdea   = bool:(userReportIdea[id][0]);
	
	if(!hasPlayer && !hasIdea)
	{
		chat_print(id, "Najpierw wpisz tresc raportu!");
		showReportMenu(id);
		return;
	}
	
	if(userReportTarget[id][0] && !userReportPlayer[id][0])
	{
		chat_print(id, "Wpisz powod zgloszenia gracza!");
		client_cmd(id, "messagemode Raport_Gracz");
		return;
	}
	
	new szName[32], szDate[12], szTime[8], szMap[32];
	get_user_name(id, szName, charsmax(szName));
	get_time("%d-%m-%y", szDate, charsmax(szDate));
	get_time("%H:%M", szTime, charsmax(szTime));
	get_mapname(szMap, charsmax(szMap));
	
	new szPlayerField[REPORT_MAX_LEN];
	if(hasPlayer)
		formatex(szPlayerField, charsmax(szPlayerField), "%s: %s", userReportTarget[id], userReportPlayer[id]);
	else
		szPlayerField[0] = 0;
	
	new szIdea[REPORT_MAX_LEN];
	copy(szIdea, charsmax(szIdea), userReportIdea[id]);
	
	new szNameEsc[33];
	copy(szNameEsc, charsmax(szNameEsc), szName);
	escape_string(szNameEsc, charsmax(szNameEsc));
	escape_string(szPlayerField, charsmax(szPlayerField));
	escape_string(szIdea, charsmax(szIdea));
	
	new queryData[512];
	formatex(queryData, charsmax(queryData),
		"INSERT INTO `reports` (`name`,`date`,`time`,`map`,`bug`,`player`,`idea`) \
		VALUES ('%s','%s','%s','%s','','%s','%s')",
		szNameEsc, szDate, szTime, szMap, szPlayerField, szIdea
	);
	
	new data[1];
	data[0] = id;
	SQL_ThreadQuery(g_SqlTuple, "reportSaveHandler", queryData, data, sizeof(data));
	
	userReportPlayer[id][0] = 0;
	userReportIdea[id][0] = 0;
	userReportTarget[id][0] = 0;
	
	chat_print(id, "Raport zostal wyslany do administracji serwera!");
	
	new players[32], num, i, admin;
	get_players(players, num, "ch");
	
	for(i = 0; i < num; i++)
	{
		admin = players[i];
		if(access(admin, ADMIN_FLAG_REPORTS))
		{
			chat_print(admin, "Nowy raport od %s. Wpisz /raporty", szName);
			tutorMake(admin, TUTOR_RED, 5.0, "Otrzymales nowy raport!");
			client_cmd(admin, "spk buttons/bell1.wav");
		}
	}
}

public reportSaveHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	if(failState)
	{
		log_amx("[ReportSystem] Blad zapisu raportu: %s (%d)", error, errorNum);
		
		new id = data[0];
		if(is_user_connected(id))
			reportSqlErrorHud(id);
		return;
	}
	
	log_amx("[ReportSystem] Raport zapisany poprawnie.");
}

// ======================== MENU ADMINA ========================
public cmdReportAdmin(id)
{
	if(!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	if(!access(id, ADMIN_FLAG_REPORTS))
	{
		chat_print(id, "Brak uprawnien! (wymagana flaga admina)");
		return PLUGIN_HANDLED;
	}
	
	if(!isSqlReady())
	{
		reportSqlErrorHud(id);
		return PLUGIN_HANDLED;
	}
	
	new queryData[192];
	formatex(queryData, charsmax(queryData),
		"SELECT `name`, COUNT(*) AS cnt FROM `reports` GROUP BY `name` ORDER BY cnt DESC LIMIT 32"
	);
	
	new data[1];
	data[0] = id;
	SQL_ThreadQuery(g_SqlTuple, "reportAdminListHandler", queryData, data, sizeof(data));
	
	return PLUGIN_HANDLED;
}

public reportAdminListHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	new id = data[0];
	if(!is_user_connected(id))
		return;
	
	if(failState)
	{
		log_amx("[ReportSystem] Blad listy raportow: %s (%d)", error, errorNum);
		reportSqlErrorHud(id);
		return;
	}
	
	new total = 0;
	new Handle:countQ = SQL_PrepareQuery(g_SqlConnection, "SELECT COUNT(*) FROM `reports`");
	if(SQL_Execute(countQ) && SQL_MoreResults(countQ))
		total = SQL_ReadResult(countQ, 0);
	SQL_FreeHandle(countQ);
	
	new title[128];
	formatex(title, charsmax(title), "\yaKaRi_Plugins |\w Lista raportow^n\y%s^t\dOtrzymano\y %d \draportow od graczy!", SYMBOL_DR_ARROW, total);
	
	new menu = menu_create(title, "reportAdminMenuHandler");
	
	new szName[33], cnt, itemText[48];
	new bool:hasItems = false;
	
	while(SQL_MoreResults(query))
	{
		SQL_ReadResult(query, 0, szName, charsmax(szName));
		cnt = SQL_ReadResult(query, 1);
		
		formatex(itemText, charsmax(itemText), "%s \d[\r%d\d]", szName, cnt);
		menu_additem(menu, itemText, szName);
		hasItems = true;
		
		SQL_NextRow(query);
	}
	
	if(!hasItems)
		menu_additem(menu, "\dBrak raportow", "");
	
	menu_setprop(menu, MPROP_EXITNAME, "Wyjscie");
	menu_display(id, menu, 0);
}

public reportAdminMenuHandler(id, menu, item)
{
	if(item == MENU_EXIT)
	{
		menu_destroy(menu);
		return PLUGIN_HANDLED;
	}
	
	new info[33], access, callback;
	menu_item_getinfo(menu, item, access, info, charsmax(info), _, _, callback);
	menu_destroy(menu);
	
	if(!info[0])
		return PLUGIN_HANDLED;
	
	showPlayerReports(id, info);
	return PLUGIN_HANDLED;
}

// ======================== MOTD ========================
stock showPlayerReports(id, const name[])
{
	if(!isSqlReady())
	{
		reportSqlErrorHud(id);
		return;
	}
	
	new szName[33];
	copy(szName, charsmax(szName), name);
	escape_string(szName, charsmax(szName));
	
	new queryData[256];
	formatex(queryData, charsmax(queryData),
		"SELECT `id`,`date`,`time`,`map`,`bug`,`player`,`idea` FROM `reports` \
		WHERE `name`='%s' ORDER BY `id` DESC LIMIT 10",
		szName
	);
	
	new data[34];
	data[0] = id;
	copy(data[1], 32, name);
	
	SQL_ThreadQuery(g_SqlTuple, "reportMotdHandler", queryData, data, sizeof(data));
}

public reportMotdHandler(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	new id = data[0];
	if(!is_user_connected(id))
		return;
	
	if(failState)
	{
		log_amx("[ReportSystem] Blad MOTD raportow: %s (%d)", error, errorNum);
		reportSqlErrorHud(id);
		return;
	}
	
	new szName[33];
	copy(szName, charsmax(szName), data[1]);
	
		new gText[4096], iLen, shown;
	new szDate[12], szTime[8], szMap[32], szBug[80], szPlayer[80], szIdea[80];
	new safeName[48], who[48], mapn[40], when[24], msg[96];
	
	motdSafe(szName, safeName, charsmax(safeName));
	
	iLen = formatex(gText, charsmax(gText), "<head><link href=^"https://fonts.googleapis.com/css?family=Montserrat:400,700^" rel=^"stylesheet^"></head>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<style>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "*{font-size:15px;font-family:Montserrat,Arial;color:#FFFFFF;text-align:center;padding:0;margin:0;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "html,body{height:100%%;margin:0;background:#111111;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "body{border:1px solid #78f305;border-radius:8px;box-sizing:border-box;padding:12px;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "h1{margin:0 0 12px 0;font-size:18px;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, ".g{color:#78f305;font-weight:bold;}.w{color:#FFFFFF;font-weight:bold;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "table{width:100%%;border-collapse:separate;border-spacing:4px;table-layout:fixed;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "th,td{border:1px solid #78f305;border-radius:4px;padding:6px;background:#111111;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "th{color:#78f305;font-weight:bold;}td{color:#FFFFFF;word-wrap:break-word;}");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, ".f{margin-top:10px;color:#78f305;font-size:13px;}</style></head><body>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<h1><span class=^"g^">Raporty od Gracza:</span> <span class=^"w^">%s</span></h1>", safeName);
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<table><tr>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<th style=^"width:6%%^">#</th>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<th style=^"width:14%%^">Typ Raportu</th>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<th style=^"width:18%%^">Raportujacy</th>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<th style=^"width:16%%^">Mapa</th>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<th style=^"width:30%%^">Wiadomosc</th>");
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<th style=^"width:16%%^">Data</th></tr>");
	
	while(SQL_MoreResults(query) && shown < 10)
	{
		SQL_ReadResult(query, 1, szDate,   charsmax(szDate));
		SQL_ReadResult(query, 2, szTime,   charsmax(szTime));
		SQL_ReadResult(query, 3, szMap,    charsmax(szMap));
		SQL_ReadResult(query, 4, szBug,    charsmax(szBug));
		SQL_ReadResult(query, 5, szPlayer, charsmax(szPlayer));
		SQL_ReadResult(query, 6, szIdea,   charsmax(szIdea));
		
		motdSafe(szName, who, charsmax(who));
		motdSafe(szMap, mapn, charsmax(mapn));
		formatex(when, charsmax(when), "%s %s", szDate, szTime);
		replace_all(when, charsmax(when), "%", "%%");
		
		new added;
		if(szBug[0] && shown < 10)
		{
			shown++; added = 1;
			motdSafe(szBug, msg, charsmax(msg));
			iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<tr><td>%d</td><td>Blad</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", shown, who, mapn, msg, when);
		}
		if(szPlayer[0] && shown < 10)
		{
			shown++; added = 1;
			motdSafe(szPlayer, msg, charsmax(msg));
			iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<tr><td>%d</td><td>Gracz</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", shown, who, mapn, msg, when);
		}
		if(szIdea[0] && shown < 10)
		{
			shown++; added = 1;
			motdSafe(szIdea, msg, charsmax(msg));
			iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<tr><td>%d</td><td>Propozycja</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>", shown, who, mapn, msg, when);
		}
		if(!added && shown < 10)
		{
			shown++;
			iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<tr><td>%d</td><td>-</td><td>%s</td><td>%s</td><td>-</td><td>%s</td></tr>", shown, who, mapn, when);
		}
		
		if(iLen > 3400)
			break;
		
		SQL_NextRow(query);
	}
	
	if(!shown)
		iLen += formatex(gText[iLen], charsmax(gText)-iLen, "<tr><td colspan=6>Brak raportow od tego gracza.</td></tr>");
	
	iLen += formatex(gText[iLen], charsmax(gText)-iLen, "</table><p class=^"f^">Wyswietlono %d ostatnich raportow.</p></body>", shown);
	show_motd(id, gText, "Raporty");
}

stock motdSafe(const src[], dest[], len)
{
	new tmp[160];
	copy(tmp, charsmax(tmp), src[0] ? src : "-");
	replace_all(tmp, charsmax(tmp), "<", "(");
	replace_all(tmp, charsmax(tmp), ">", ")");
	replace_all(tmp, charsmax(tmp), "%", "%%");
	copy(dest, len, tmp);
}
