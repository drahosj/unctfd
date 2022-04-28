import std.stdio;
import std.string;
import std.conv;

import team;
import art;
import db;

import dpq2;

void show_recent()
{
    string fmt = "\t\t"~T_GREEN~"%-50s%-6s"~RESET;
    if (logged_in) {
        QueryParams p; 
        p.sqlCommand = q"END_SQL
            SELECT flag_name, points, time
            FROM v_valid_submissions
            WHERE team_id=$1
            ORDER BY time DESC
            LIMIT 4
END_SQL";
        p.argsVariadic(team_id);
        
        auto r = conn.execParams(p);
        scope(exit) destroy(r);
        if (r.length) {
            writeln("\tRecent Solves:\n");
        }
        
        foreach(row; rangify(r)) {
            writefln(fmt,
                    row["flag_name"].as!PGtext,
                    row["points"].as!PGinteger.to!string
                    );
        }
    } else {
        writeln("Not logged in!");
    }
}
