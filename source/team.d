import std.stdio;
import std.string;
import std.regex;

import dpq2;

import menu;
import db;
import art;

int logged_in;
int team_id;
string team_name;

private Menu m_register;
private Menu m_login;
private Menu m_ssh_key;

static this()
{
    m_register = Menu("Register new team", &do_register);
    m_login = Menu("Login existing team", &do_login);
    m_ssh_key = Menu("Add SSH key", &do_ssh_key);

    menus["register"] = &m_register;
    menus["login"] = &m_login;
    menus["ssh"] = &m_ssh_key;
}

private bool add_ssh_key()
{
    write("Paste key here: ");
    string sshkey = readln().chomp();
    auto m = sshkey.matchFirst(r"^ssh-rsa ([A-Za-z0-9+/]+).*$");
    if (m.empty) {
        writeln("Invalid SSH key.");
        return false;
    } else {
        QueryParams p;
        p.sqlCommand = q"END_SQL
            INSERT INTO ssh_keys (team_id, key) 
            VALUES ($1::int, $2::text)
END_SQL";
        p.argsVariadic(team_id, m[1]);
        conn.execParams(p);
        writeln("Key accepted!");
        write("Keys are added in a batch process, so it");
        writeln("may take up to one minute to take effect.");
    }
    return true;
}

private int do_ssh_key()
{
    add_ssh_key();
    return false;
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
                auto ssh = "";
                do {
                    do {
                        write("Add SSH key? (y/n): ");
                        ssh = readln().chomp().toLower();
                    } while (ssh != "y" && ssh != "n");
                    if (ssh == "y")  {
                        add_ssh_key();
                    }
                } while (ssh != "n");
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
        opt ~= [menus["ssh"]];

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
            ) RETURNING id
END_SQL";


    p.argsVariadic(name, pass);

    auto r = conn.execParams(p);

    scope(exit) destroy(r);
    team_id = r[0]["id"].as!PGinteger;
    team_name = name;
    return true;
}

