import std.stdio;

string hsep = q"EOS
--------------------------------------------------------------------------------
EOS";

int use_telnet_codes;

const string ESC = "\x1b[";
const string RESET = ESC ~ "0m";

const string T_RED = ESC ~ "31m";
const string T_GREEN = ESC ~ "32m";

const string BG_BLUE = ESC ~ "44m";

void echo_off() 
{
    if (use_telnet_codes) {
        write("\xff\xfb\x01");
    } else {
    }

}

void echo_on()
{
    if (use_telnet_codes) {
        write("\xff\xfc\x01");
    } else {
    }
}
