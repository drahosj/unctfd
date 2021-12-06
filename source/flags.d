import std.stdio;
import std.conv;
import std.string;
import core.exception;

import dpq2;

import menu;
import db;
import root;
import team;
import art;

private Menu m_submit;
private Menu m_unsolved;
private Menu m_solved;
private Menu m_description;

private Menu m_submenu;

static this()
{
    m_submit = Menu("Submit a flag", &submit);
    m_solved = Menu("Show solved flags", &solved);
    m_description = Menu("Show flag description", &description);

    m_unsolved = Menu("Show unsolved flags", 
            [&m_description, &m_submenu, &m_root], &unsolved);

    m_submenu = Menu("Flags ->", [
            &m_description, 
            &m_unsolved, 
            &m_solved,
            &m_submit,
            &m_root
    ]);

    menus["submit"] = &m_submit;
    menus["flags"] = &m_submenu;
}

private int submit()
{
    if (logged_in) {
        string flag = readln().chomp();
        
        QueryParams p;
        p.sqlCommand = "CALL SUBMIT($1, $2)";
        p.argsVariadic(team_name, flag);
        conn.execParams(p);
    } else {
        writeln("Not logged in");
    }
    return false;
}

private int unsolved()
{
    string fmt = "|%-70s|%7s|";
    writefln(fmt, "Challenge Name", "Points");
    write(hsep);

    if (logged_in) {
        QueryParams p;
        p.sqlCommand = "SELECT * FROM UNSOLVED($1)";
        p.argsVariadic(team_name);

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
        p.sqlCommand = "SELECT * FROM SOLVED($1)";
        p.argsVariadic(team_name);

        auto r = conn.execParams(p);
        scope(exit) destroy(r);

        foreach(row; rangify(r)) {
            writefln(fmt,
                    row["name"].as!PGtext,
                    row["solved_time"].as!PGtext,
                    row["points"].as!PGinteger.to!string
                    );
        }
    } else {
        writeln("Not logged in!");
    }
    return false;
}

private int description()
{
    string fmt = "|%-6s|%-60s|%-10s|";
    writefln(fmt, "", "Challenge Name", "Points");
    write(hsep);

    QueryParams p;
    p.sqlCommand = "SELECT name, points, description FROM FLAGS WHERE visible";

    auto r = conn.execParams(p);
    scope(exit) destroy(r);

    string[] descriptions = [];
    int i = 1;
    foreach(row; rangify(r)) {
        writefln(fmt, (i++).to!string,
                row["name"].as!PGtext,
                row["points"].as!PGinteger.to!string
                );
        descriptions ~= [row["description"].as!PGtext.idup];
    }

    write("Select flag: ");
    try {
        int flag = readln().chomp().to!int;

        writeln();
        writeln(descriptions[flag - 1]);
        writeln();
    } catch (ConvException) {
        writeln("Invalid choice.");
    } catch (RangeError) {
        writeln("Invalid choice.");
    }
    return false;
}
