import std.stdio;
import std.conv;
import std.string;
import std.functional;

Menu *[string] menus;

struct Menu {
    int delegate() entry; 

    string title;

    Menu * [] options;

    this(string title, Menu*[] options = [], int delegate() entry = null)
    {
        this.title = title;
        this.options = options;
        this.entry = entry;
    }

    this(string title, Menu*[] options, int function() entry)
    {
        this(title, options, entry.toDelegate);
    }

    this(string title, int function() entry)
    {
        this(title, [], entry);
    }

    void print_options() 
    {
        writeln();
        foreach(i, option; options) {
            writefln("%d) %s", i + 1, option.title);
        }
        writefln("q) Exit");
    }

    int enter() 
    {
        if (entry !is null) {
            int ret = entry();
            if (ret) {
                print_options();
            }

            return ret;
        } else {
            print_options();
            return true;
        }
    }
};

int get_selection() 
{
    write("Select an option: ");
    string choice = readln().chomp();

    if (choice[0] == 'q') {
        return -1;
    } else if (choice[0] == '?') {
        return -2;
    }

    try {
        return choice.to!int;
    } catch (ConvException) {
        return 0;
    }
}

void menu_loop(Menu * m) 
{
    m.enter();

    while(true) {
        int selection = get_selection();
        writeln();

        if (selection == -1) {
            return;
        } else if (selection == -2) {
            m.print_options();
        } else if (selection - 1 < m.options.length) {
            Menu * next = m.options[selection - 1];
            if (next.enter()) {
                m = next;
            } else {
                m.print_options();
            }
        } else {
            writeln("Invalid option. '?' to display again.");
        }
    }
}
