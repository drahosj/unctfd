import std.stdio;
import std.string;

import dpq2;

import menu;
import db;
import art;

int logged_in;
int team_id;
string team_name;

private Menu m_register;
private Menu m_login;

static this()
{
    m_register = Menu("Register new team", &do_register);
    m_login = Menu("Login existing team", &do_login);

    menus["register"] = &m_register;
    menus["login"] = &m_login;
}

private int do_register() 
{
    write("Enter team name: ");
    auto name = readln().chomp();

    string pass;
    string pass2;
    {
        echo_off();
        scope(exit) echo_on();

        write("Enter password: ");
        pass = readln().chomp();

        write("Confirm password: ");
        pass2 = readln().chomp();
    }

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

private int do_login()
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

        Menu * log = menus["login"];
        Menu * reg = menus["register"];

        Menu *[] opt = [];

        foreach(Menu * m; menus["root"].options) {
            if (!(m == log || m == reg)) {
                opt ~= [m];
            }
        }

        opt ~= [menus["submit"]];
        opt ~= [menus["flags"]];

        menus["root"].options = opt;


        writeln();
        writefln("Logged in as %s", team_name);
        writeln();
        return false;
    }
}

private int register(string name, string pass)
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

