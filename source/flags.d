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

    m_submenu = Menu("Flags " ~ T_GREEN ~ "->" ~ RESET, [
            &m_description, 
            &m_unsolved, 
            &m_solved,
            &m_submit,
            &m_root
    ]);

    menus["submit"] = &m_submit;
    menus["flags"] = &m_submenu;
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
        p.sqlCommand = "CALL SUBMIT($1, $2)";
        p.argsVariadic(team_name, flag);
        conn.execParams(p);

        if (getScore() > pre_score) {
            writefln("The submission was %sCORRECT%s!", T_GREEN, RESET);
        } else {
            writefln("The submission was %sINCORRECT%s!", T_RED, RESET);
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
        p.sqlCommand = q"END_SQL
            SELECT 
                f.name as flag_name, 
                points - COALESCE(child_points, 0) as points
            FROM flags f
            LEFT JOIN (
                    SELECT flag_id, submissions FROM v_solves
                    WHERE team_id=$1 ) as vs
                ON vs.flag_id=f.id
            LEFT JOIN (
                    SELECT SUM(points)::INT as child_points, parent
                    FROM v_solves
                    LEFT JOIN flags ON v_solves.flag_id=flags.id
                    WHERE team_id=$1 AND parent IS NOT NULL
                    GROUP BY parent
                    ) as sc
                ON sc.parent=f.id
            WHERE 
                submissions IS NULL
                AND f.visible
                AND f.enabled
                AND f.points - COALESCE(child_points, 0) > 0
END_SQL";
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
            SELECT flag_name, points, time
            FROM v_solves s
            LEFT JOIN v_valid_submissions vs 
                ON s.submissions[1]=vs.submission_id
            LEFT JOIN flags f ON f.id=s.flag_id
            WHERE s.team_id=$1
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
    int i = 1;
    foreach(row; rangify(r)) {
        writefln(fmt, (i++).to!string,
                row["name"].as!PGtext,
                row["points"].as!PGinteger.to!string
                );
        descriptions ~= [row["description"].as!PGtext.idup];
        ids ~= row["id"].as!PGinteger;
    }

    write("Select flag: ");
    try {
        int flag = readln().chomp().to!int;

        writeln();
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
            writeln("Attachments: ");
            foreach(row; r2) {
                writefln("%s: %s", row["name"].as!PGtext, row["uri"].as!PGtext);
            }
        }
    } catch (ConvException) {
        writeln("Invalid choice.");
    } catch (RangeError) {
        writeln("Invalid choice.");
    }
    return false;
}
