#author: arch.jslin (archilifelin@yahoo.com.tw) in June 2008
#This program is licensed under GNU GPL, for details please goto http://gnu.org

# This is a helper program, intend to provide htmls converted by bbs2html.rb
# a pre-generated style sheet, so that the space usage by <font> tags is reduced,
# and the time processing ansi color code to html font color is lowered as well.

# Usage: ruby pre_gen_css.rb
# you don't have to run this script unless a change to those pre-defined 
# colors is needed.

COLOR = {"0"=>["000000", "aa0040", "40aa20", "bb9c10", "0000aa", "c02080", "40a0b0", "cccccc"],
         "1"=>["787878", "ff0000", "00ff00", "ffff00", "0000ff", "ff00ff", "40ffff", "ffffff"]}

def generate_font_color_classes
    result = ""
    bgcolors = COLOR["0"]
    COLOR.each { |key, val|
        val.each_with_index { |col, i|
            bgcolors.each_with_index { |bcol, j|
                result += "font.c#{key}3#{i}4#{j} {color:#{col}; background-color:#{bcol};}\n"
            }
        }
    }
    result
end

def generate_css_file
    result = "pre {font-size: 12pt; line-height: 13pt; color:#{COLOR["0"][7]}; background-color:#{COLOR["0"][0]};}
td {font-size: 12pt; line-height: 13pt;}
td.c03744 {color:#{COLOR["0"][7]}; background-color:#{COLOR["0"][4]};}
td.c13447 {color:#{COLOR["1"][4]}; background-color:#{COLOR["0"][7]}; text-align:center;}\n"
    result += generate_font_color_classes
    File.open("bbs2html.css","w") { |file|
        file.syswrite( result )
    }
end

generate_css_file
