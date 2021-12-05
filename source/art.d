import std.stdio;

string hsep = q"EOS
-------------------------------------------------------------------------------
EOS";

int use_telnet_codes;

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
