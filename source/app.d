import std.stdio;

import dpq2;

import std.getopt;
import std.format;

import std.conv;

import std.string;

Connection conn;

string hsep = q"EOS
-------------------------------------------------------------------------------
EOS";

void main(string[] args)
{
    string conn_string = "dbname=ctf";

    getopt(args, "conn|c", &conn_string);

    conn = new Connection(conn_string);

    while (true)
    {
        writeln("1) Scoreboard");
        writeln("2) Register an account");

        auto line = readln().chomp();

        if (line == "1") {
            scoreboard();
        }

        if (line == "2") {
            write("Enter team name: ");
            auto name = readln().chomp();

            write("Enter password: ");
            auto pass = readln().chomp();

            write("Confirm password: ");
            auto pass2 = readln().chomp();

            if (pass != pass2) {
                writeln("Passwords do not match.");
            } else {
                register(name, pass);
                writeln("Registered");
            }
        }
    }
}

void register(string name, string pass)
{
    if (name.length > 60) {
        writeln("Maximum name length is 60 characters.");
        return;
    }

    QueryParams p;
    p.sqlCommand = q"END_SQL
        INSERT INTO teams (name, hash) VALUES (
            $1::text,
            crypt($2::text, gen_salt('bf', 10))
        )
END_SQL";


    p.argsVariadic(name, pass);

    auto r = conn.execParams(p);
    scope(exit) destroy(r);
}

void scoreboard()
{
    string fmt = "|%-8s|%-60s|%-8s|";

    writefln(fmt, "Place", "Team Name", "Score");
    write(hsep);

    QueryParams p;
    p.sqlCommand = "SELECT * FROM v_scoreboard";

    auto results = conn.execParams(p);

    foreach(row; rangify(results)) {
        writefln(fmt, 
                row["place"].as!PGbigint.to!string,
                row["name"].as!PGtext,
                row["score"].as!PGbigint.to!string
                );
    }
}
