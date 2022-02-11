import std.stdio;
import std.getopt;
import std.conv;
import std.string;

import core.stdc.stdio : setbuf, stdout;

import dpq2;

import menu;
import team;
import art;
import db;

int  main(string[] args)
{
    string conn_string = "dbname=ctf";
    string preauthenticate_as;

    auto opt = getopt(args, 
            "conn|c", &conn_string,
            "preauth|p", "Preauth as team (by team ID)", &preauthenticate_as);
    setbuf(stdout, null);
    if (opt.helpWanted) {
        defaultGetoptPrinter("unctfd: ", opt.options);
        return -1;
    }

    conn = new Connection(conn_string);

    alias m = menus;

    if (preauthenticate_as is null) {
        m["root"].options = [
            m["scoreboard"],
            m["login"],
            m["register"]
        ];
    } else {
        QueryParams p;
        p.sqlCommand = "SELECT name, id FROM teams WHERE id=$1";
        p.argsVariadic(preauthenticate_as.to!int);

        auto results = conn.execParams(p);
        scope(exit) destroy(results);

        if (results.length < 1) {
            writeln("Invalid team specified for preauthentication");
            return -1;
        } else {
            team_name = results[0]["name"].as!PGtext;
            team_id = results[0]["id"].as!PGinteger;
            logged_in = true;

            m["root"].options = [
                m["scoreboard"],
                m["submit"],
                m["flags"],
            ];
        }

    }

    menu_loop(menus["root"]);

    return 0;
}


