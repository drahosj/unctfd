import std.stdio;
import std.conv;
import std.string;
import std.functional;
import core.exception;

import dpq2;

import menu;
import db;
import root;
import team;
import art;
import util;

private Menu m_submit;
private Menu m_unsolved;
private Menu m_solved;
private Menu m_description;
private Menu m_flag_info;

private Menu m_submenu;

private int[] last_ids = [];
private bool[] last_metas = [];

static this()
{
    m_submit = Menu("Submit a flag", &submit);
    m_solved = Menu("List solved flags", [&m_description, &m_submenu], &solved);
    m_description = Menu("Show flag description...", &description);
    m_flag_info = Menu("Show solve info of flags", &info);

    m_unsolved = Menu("List unsolved flags", 
            [&m_description, &m_submenu], &unsolved);

    m_submenu = Menu("Flags " ~ T_GREEN ~ "->" ~ RESET, [
            &m_unsolved, 
            &m_solved,
            &m_submit,
            &m_flag_info,
            &m_root
    ], (&entry).toDelegate);

    menus["submit"] = &m_submit;
    menus["flags"] = &m_submenu;
}

private int entry()
{
    show_recent();

    return true;
}

private long getScore()
{
    if (logged_in) {
        QueryParams p;
        p.sqlCommand = "SELECT * FROM v_scoreboard WHERE name=$1";
        p.argsVariadic(team_name);
        auto res = conn.execParams(p);
        scope(exit) destroy(res);

        if (res.length > 0) {
            return res[0]["score"].as!PGbigint;
        } else {
            return 0;
        }
    } else {
        return -1;
    }
}

private int submit()
{
    if (logged_in) {
        writef("Enter Submission: %s", T_GREEN);
        string flag = readln().chomp();
        writefln("%s", RESET);
        
        long pre_score = getScore();
        QueryParams p;
        p.sqlCommand = "SELECT * FROM SUBMIT($1, $2)";
        p.argsVariadic(team_id, flag);
        auto r = conn.execParams(p);
        scope (exit) destroy(r);
        auto row = r[0];

        if (row["flag_name"].isNull()) {
            writefln("The submission was %sINCORRECT%s!", T_RED, RESET);
            return false;
        }

        auto flag_name = row["flag_name"].as!PGtext;
        auto flag_points = row["points"].as!PGinteger;

        if (row["nsubs"].as!PGinteger > 1) {
            writefln("%sCORRECT%s but already submitted!", T_GREEN, RESET);
            writefln("\tFlag name: %s", flag_name);
            return false;
        } 
        if (row["bonus"].as!PGboolean) {
            writefln("%sBONUS FLAG%s %s (%d points)",
                    T_GREEN, RESET, flag_name, flag_points);
            return false;
        }
        writefln("The submission was %sCORRECT%s!", T_GREEN, RESET);
        writefln("\tFlag name: %s (%d points)", flag_name, flag_points);

        if (!row["parent"].isNull()) {
            p.sqlCommand = q"END_SQL
                SELECT name, points 
                FROM unsolved_meta($1)
                WHERE id=$2
END_SQL";
            p.argsVariadic(team_id, row["parent"].as!PGinteger);
            auto r2 = conn.execParams(p);
            scope (exit) destroy(r);
            auto row2 = r2[0];
            writefln("\t%s%d%s points remain in the %s%s%s meta-flag.",
                    T_GREEN, row2["points"].as!PGinteger, RESET,
                    T_GREEN, row2["name"].as!PGtext, RESET);
        } 
    } else {
        writeln("Not logged in");
    }
    return false;
}

private int unsolved()
{
    string fmt = "%-4s|%-66s|%s%-7s%s|";
    writefln(fmt, "", "Challenge Name", "", "Points", "");
    write(hsep);

    if (logged_in) {
        QueryParams p;
        p.sqlCommand = q"END_SQL
            SELECT flag_id AS id, flag_name AS name, points, false AS meta 
            FROM unsolved($1)
            UNION SELECT id, name, points, true AS meta
            FROM unsolved_meta($1)
            WHERE points > 0
END_SQL";
        p.argsVariadic(team_id);

        auto r = conn.execParams(p);
        scope(exit) destroy(r);

        last_ids = [];
        last_metas = [];
        int i = 0;
        foreach(row; rangify(r)) {
            i++;
            last_ids ~= [row["id"].as!PGinteger];
            last_metas ~= [row["meta"].as!PGboolean];
            writefln(fmt,
                    i.to!string,
                    row["name"].as!PGtext,
                    row["meta"].as!PGboolean ? T_RED : T_GREEN,
                    row["points"].as!PGinteger.to!string,
                    RESET
                    );
        }
    } else {
        writeln("Not logged in!");
    }
    return true;
}

private int solved()
{
    string fmt = "%-4s|%-40s|%-26s|%-6s|";
    writefln(fmt, "", "Challenge Name", "Solve timestamp", "Points");
    write(hsep);

    if (logged_in) {
        QueryParams p;
        p.sqlCommand = q"END_SQL
            SELECT * FROM solved($1);
END_SQL";
        p.argsVariadic(team_id);

        auto r = conn.execParams(p);
        scope(exit) destroy(r);

        last_ids = [];
        last_metas = [];
        int i = 0;
        foreach(row; rangify(r)) {
            i++;
            last_ids ~= [row["flag_id"].as!PGinteger];
            last_metas ~= [false];
            writefln(fmt,
                    i.to!string,
                    row["flag_name"].as!PGtext,
                    row["time"].as!PGtext,
                    row["points"].as!PGinteger.to!string
                    );
        }
    } else {
        writeln("Not logged in!");
    }
    return true;
}

private int info()
{
    string fmt = "|%-67s|%-10s|";
    writefln(fmt, "Challenge Name", "Solves");
    write(hsep);

    QueryParams p;
    p.sqlCommand = "SELECT name, solves FROM v_flag_info";
    auto r = conn.execParams(p);
    scope(exit) destroy(r);

    foreach(row; rangify(r)) {
        writefln(fmt,
                row["name"].as!PGtext,
                row["solves"].as!PGinteger.to!string
                );
    }
    return false;
}
private int description()
{
    if (last_ids.length == 0) {
        writeln("No flags listed...");
        return false;
    }

    write("Select flag by number above: ");
    try {
        int flag = readln().chomp().to!int;

        QueryParams p;
        p.sqlCommand = last_metas[flag - 1] ? 
                "SELECT name, description, points FROM metaflags WHERE id=$1" :
                "SELECT name, description, points FROM flags WHERE id=$1";
        p.argsVariadic(last_ids[flag - 1]);
        auto r = conn.execParams(p);
        scope (exit) destroy(r);
        auto row = r[0];

        writeln();
        writefln(" == %s%s%s ==\n", T_GREEN, row["name"].as!PGtext, RESET);
        writeln(row["description"].as!PGtext);
        writeln();

        QueryParams p2;
        p2.sqlCommand = last_metas[flag - 1] ? q"END_SQL
            SELECT attachments.name, uri FROM attachments 
            WHERE metaflag_id = $1
END_SQL" : q"END_SQL
            SELECT attachments.name, uri FROM attachments
            WHERE flag_id = $1
END_SQL";
        p2.argsVariadic(last_ids[flag - 1]);
        auto r2 = conn.execParams(p2).rangify();
        if (!r2.empty()) {
            writefln("%sAttachments: %s\n", T_GREEN, RESET);
            foreach(row2; r2) {
                writefln("%s%s%s: %s", T_RED, row2["name"].as!PGtext, RESET,
                        row2["uri"].as!PGtext);
            }
        }
        write(hsep);
    } catch (ConvException) {
        writeln("Invalid choice.");
    } catch (RangeError) {
        writeln("Invalid choice.");
    }
    return false;
}
