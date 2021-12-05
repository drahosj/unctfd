import std.stdio;
import std.conv;

import dpq2;

import menu;
import team;
import art;
import db;

Menu m_root; 

private Menu m_scoreboard;

static this()
{
    m_root = Menu("Main menu", &root_entry);
    m_scoreboard = Menu("Scoreboard", &scoreboard);
    menus["root"] = &m_root;
    menus["scoreboard"] = &m_scoreboard;
}

private int root_entry()
{
    if (logged_in) {
        writeln();
        writefln("You are currently logged in as %s", team_name);
    }
    return true;
}

private int scoreboard()
{
    string fmt = "|%-8s|%-60s|%-8s|";

    writefln(fmt, "Place", "Team Name", "Score");
    write(hsep);

    QueryParams p;
    p.sqlCommand = "SELECT * FROM v_scoreboard";

    auto results = conn.execParams(p);
    scope(exit) destroy(results);

    foreach(row; rangify(results)) {
        writefln(fmt, 
                row["place"].as!PGbigint.to!string,
                row["name"].as!PGtext,
                row["score"].as!PGbigint.to!string
                );
    }
    return false;
}

