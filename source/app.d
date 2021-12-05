import std.stdio;

import dpq2;

import std.getopt;
import std.format;

import std.conv;

import std.string;
import std.functional;

import menu;

Connection conn;

string hsep = q"EOS
-------------------------------------------------------------------------------
EOS";

int do_register_team() 
{
    write("Enter team name: ");
    auto name = readln().chomp();

    write("Enter password: ");
    auto pass = readln().chomp();

    write("Confirm password: ");
    auto pass2 = readln().chomp();

    try {
        if (pass != pass2) {
            writeln("Passwords do not match.");
            return false;
        } else {
            if (register(name, pass)) {
                writeln("Registered!");
                return false;
            }
        }
    } catch (ResponseException) {
    }
    writeln("Error registering team. Is the name already taken?");
    return false;
}

int logged_in;
int team_id;
string team_name;

int do_login()
{
    write("Enter team name: ");
    auto name = readln().chomp();

    write("Enter password: ");
    auto pass = readln().chomp();

    QueryParams p;
    p.sqlCommand = "SELECT * FROM teams WHERE name=$1 AND " ~
        "hash=crypt($2::text, hash)";

    p.argsVariadic(name, pass);
    auto r = conn.execParams(p);
    scope(exit) destroy(r);

    if (r.length == 0) {
        writeln("Invalid login");
        return false;
    } else {
        logged_in = true;
        team_id=r[0]["id"].as!PGinteger;
        team_name=r[0]["name"].as!PGtext;

        writefln("Signed in as %s", team_name);
        return false;
    }
}

int root_entry()
{
    if (logged_in) {
        writefln("You are currently logged in as %s", team_name);
    }
    return true;
}

void main(string[] args)
{
    string conn_string = "dbname=ctf";

    getopt(args, "conn|c", &conn_string);

    conn = new Connection(conn_string);

    Menu root = Menu("Home", [], &root_entry);

    Menu m1 = Menu("Menu 1", [&root]);
    Menu m2 = Menu("Menu 2", [&root]);
    Menu m3 = Menu("Menu 3", [&root]);
    Menu m4 = Menu("Menu 4", [&root]);

    Menu s1 = Menu("Submenu 1", [&m2, &root]);
    Menu s2 = Menu("Submenu 2", [&m2, &root]);
    Menu s3 = Menu("Submenu 3", [&m2, &root]);

    Menu login_menu = Menu("Login existing team", [], &do_login);
    Menu reg_menu = Menu("Register a team", [], &do_register_team);
    Menu scoreboard_menu = Menu("Show scoreboard", [], &scoreboard);

    root.options ~= [&m1, &m2, &m3, &m4, &scoreboard_menu, 
        &reg_menu, &login_menu];

    m2.options = [&s1, &s2, &s3] ~ m2.options;

    menu_loop(&root);
}

int register(string name, string pass)
{
    if (name.length > 60) {
        writeln("Maximum name length is 60 characters.");
        return false;
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
    return true;
}

int scoreboard()
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
