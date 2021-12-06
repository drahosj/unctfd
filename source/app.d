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

    getopt(args, 
            "conn|c", &conn_string,
            "preauth|p", &preauthenticate_as);
    setbuf(stdout, null);

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
        p.sqlCommand = "SELECT id FROM teams WHERE name=$1";
        p.argsVariadic(preauthenticate_as);

        auto results = conn.execParams(p);
        scope(exit) destroy(results);

        if (results.length < 1) {
            writeln("Invalid team specified for preauthentication");
            return -1;
        } else {
            team_name = preauthenticate_as;
            team_id = results[0]["id"].as!PGinteger;
            logged_in = true;

            m["root"].options = [
                m["scoreboard"],
                m["submit"],
                m["flags"]
            ];
        }

    }

    menu_loop(menus["root"]);

    return 0;
}


