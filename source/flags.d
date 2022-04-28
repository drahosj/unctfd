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

static this()
{
    m_submit = Menu("Submit a flag", &submit);
    m_solved = Menu("List solved flags", &solved);
    m_description = Menu("Show flag description...", &description);
    m_flag_info = Menu("Show solve info of flags", &info);

    m_unsolved = Menu("List unsolved flags", 
            [&m_description, &m_submenu, &m_root], &unsolved);

    m_submenu = Menu("Flags " ~ T_GREEN ~ "->" ~ RESET, [
            &m_description, 
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
            // TODO: Calculate remaining value of parent
            writefln("This is part of a meta-flag.");
            writefln("More info is a TODO");
        } 
    } else {
        writeln("Not logged in");
    }
    return false;
}

private int unsolved()
{
    string fmt = "|%-70s|%-7s|";
    writefln(fmt, "Challenge Name", "Points");
    write(hsep);

    if (logged_in) {
        QueryParams p;
        p.sqlCommand = "SELECT * FROM unsolved($1)";
        p.argsVariadic(team_id);

        auto r = conn.execParams(p);
        scope(exit) destroy(r);

        foreach(row; rangify(r)) {
            writefln(fmt,
                    row["flag_name"].as!PGtext,
                    row["points"].as!PGinteger.to!string
                    );
        }
    } else {
        writeln("Not logged in!");
    }
    return false;
}

private int solved()
{
    string fmt = "|%-40s|%-30s|%-6s|";
    writefln(fmt, "Challenge Name", "Solve timestamp", "Points");
    write(hsep);

    if (logged_in) {
        QueryParams p;
        p.sqlCommand = q"END_SQL
            SELECT * FROM solved($1);
END_SQL";
        p.argsVariadic(team_id);

        auto r = conn.execParams(p);
        scope(exit) destroy(r);

        foreach(row; rangify(r)) {
            writefln(fmt,
                    row["flag_name"].as!PGtext,
                    row["time"].as!PGtext,
                    row["points"].as!PGinteger.to!string
                    );
        }
    } else {
        writeln("Not logged in!");
    }
    return false;
}

private int info()
{
    string fmt = "|%-67s|%-10s|";
    writefln(fmt, "Challenge Name", "Solves");
    write(hsep);

    QueryParams p;
    p.sqlCommand = q"END_SQL
        SELECT f.name, fi.solves::int
        FROM v_flag_info fi
        LEFT JOIN flags f ON f.id=fi.id
        WHERE f.visible
        ORDER BY solves DESC
END_SQL";
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
    string fmt = "|%-6s|%-60s|%-10s|";
    writefln(fmt, "", "Challenge Name", "Points");
    write(hsep);

    QueryParams p;
    p.sqlCommand = q"END_SQL
        SELECT name, points, description, id FROM FLAGS WHERE visible
END_SQL";

    auto r = conn.execParams(p);
    scope(exit) destroy(r);

    string[] descriptions = [];
    int[] ids = [];
    string[] names = [];
    int i = 1;
    foreach(row; rangify(r)) {
        writefln(fmt, (i++).to!string,
                row["name"].as!PGtext,
                row["points"].as!PGinteger.to!string
                );
        descriptions ~= [row["description"].as!PGtext.idup];
        ids ~= row["id"].as!PGinteger;
        names ~= row["name"].as!PGtext;
    }

    write("Select flag: ");
    try {
        int flag = readln().chomp().to!int;

        writeln();
        writefln(" == %s%s%s ==\n", T_GREEN, names[flag - 1], RESET);
        writeln(descriptions[flag - 1]);
        writeln();

        QueryParams p2;
        p2.sqlCommand = q"END_SQL
            SELECT attachments.name, uri FROM attachments 
            LEFT JOIN flags ON flag_id = flags.id 
            WHERE flags.id = $1
END_SQL";
        p2.argsVariadic(ids[flag - 1]);
        auto r2 = conn.execParams(p2).rangify();
        if (!r2.empty()) {
            writefln("%sAttachments: %s\n", T_GREEN, RESET);
            foreach(row; r2) {
                writefln("%s%s%s: %s", T_RED, row["name"].as!PGtext, RESET,
                        row["uri"].as!PGtext);
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
