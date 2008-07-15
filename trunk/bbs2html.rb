#author: arch.jslin (archilifelin@yahoo.com.tw) in June 2008
#This program is licensed under GNU GPL, for details please goto http://gnu.org

#The purpose of this program is to convert the legacy files from bbs.ttsh.tp.edu.tw,
#it will not work stand-alone. This program must be invoked with authorized user in /bbs/ folder,
#and a valid user@bbs.ttsh.tp.edu.tw id must be provided as the first command line argument.

#known issue(s)
#(and which are known as not-solvable unless extensive use of javascript):
# * no blink
# * no multi-color characters (you still can get most of it if using firefox2 [maybe ff3 as well])

#Usage: ruby bbs2html.rb boardname[or userid] package_name [u] [-test]
# * package_name should be random generated.
# * specify "u" at last if you want to package for a user
#   otherwise package for a specific board
# * specify "-test" if you are testing, after specifying this,
#   it will not clean up temp folder after packaging is done.

require 'fileutils'

HTML_REAR = 
"\n    </body>
</html>
"
#read file chunk size
CHUNK_SIZE = 8192

#these are the spec for .DIR files.
DIR_ENTRY_SIZE = 128
FILE_ID_SIZE = 34

#combine \033 "ESC" character with Tag 8859_1 table, for convenience.
TAG8859_1 = {27=>"", 60=>"&lt;", 62=>"&gt;", 38=>"&amp;", 34=>"&quot;"} 
TMPDIR = "backup/"+ARGV[0]+ARGV[1]

def log(str) 
    $log.syswrite(str+"\n")
end

def find_file_in_upper_dir(path, fname)
    path += "/"
    goback = "../"
    while (FileTest.file?("#{path+goback}#{fname}") == false and 
           goback.split("/").size < path.split("/").size)
        goback += "../"
    end
    result = goback + fname
    result
end

def html_header(path = nil) 
    result = "<html>\n    <head><meta http-equiv='Content-Type' content='text/html; charset=big5-hkscs'>\n"
    result += "    <link rel='stylesheet' href='#{path != nil ? find_file_in_upper_dir(path, "bbs2html.css") : "bbs2html.css"}'>\n"
    result += "    <body>\n"
    result
end

def create_path_and_copy(src, dest)
    FileUtils.mkdir_p(dest) unless FileTest.directory?(dest)
    FileUtils.cp_r(src, dest+"/../")
end

def create_working_dir(bp, pp, gp)
    FileUtils.rm_rf("#{TMPDIR}/") #make sure temp folder is clean
    FileUtils.mkdir_p("#{TMPDIR}/") #recreate the temp folder.
    create_path_and_copy(bp, "#{TMPDIR}/#{bp}") if FileTest.directory?(bp)
    create_path_and_copy(pp, "#{TMPDIR}/#{pp}") if pp != nil and FileTest.directory?(pp)
    create_path_and_copy(gp, "#{TMPDIR}/#{gp}") if FileTest.directory?(gp)
    FileUtils.cp("bbs2html.css", "#{TMPDIR}/bbs2html.css")
end

def copy_to_public_html(bp, pp, gp, finaldest)
    dir1 = "#{TMPDIR}/#{bp}"
    dir2 = "#{TMPDIR}/#{pp}" if pp != nil 
    dir3 = "#{TMPDIR}/#{gp}"
    dir1 = "" unless FileTest.directory?(bp) #do not pack unless that path is valid all along.
    dir2 = "" unless pp != nil and FileTest.directory?(pp)
    dir3 = "" unless FileTest.directory?(gp)
    #test zip archive for download, not available on win32
    system("/usr/local/bin/zip -u -r -q #{TMPDIR}/#{finaldest}.zip #{TMPDIR}/index.html #{TMPDIR}/bbs2html.css #{dir1} #{dir2} #{dir3}")
    system("scp #{TMPDIR}/#{finaldest}.zip bbs@203.72.57.3:./download/#{finaldest}.zip")
    if ARGV[3] == "-test" or ARGV[2] == "-test"
        if FileTest.file?("#{TMPDIR}/#{finaldest}.zip")
            FileUtils.cp("#{TMPDIR}/#{finaldest}.zip", "../#{finaldest}.zip") #only do this when -test is specified
        end
    else
        FileUtils.rm_rf("#{TMPDIR}/")
    end
end

def parse_DIR(str)
    thread_map = {} #setup thread mapping to filename(s) here
    filename_map = {} #setup filename mapping to title
    result = "\n<table width='960' cellpadding='0' cellspacing='0' border='0'>\n"
    result += "    <tr><td width='7%'> </td><td width='8%'> </td><td width='15%'> </td><td width='70%'> </td></tr>\n"
    idx = 0; entry = fname = titlekey = ""; entry_array = []
    while str.size > 0
        idx += 1;
        entry = str[0...DIR_ENTRY_SIZE]
        fname = entry[0...FILE_ID_SIZE].squeeze!("\0").split("\0")[0]
        entry = entry[FILE_ID_SIZE..-1]
        entry_array = entry.squeeze!("\0").split("\0")
        #entry_array is ["userid", "mm/dd", "title"]
        titlekey = entry_array[2].sub("Re: ","") #make sure the title have no "Re: " in the beginning.
        thread_map[titlekey] == nil ? thread_map[titlekey] = [fname] : thread_map[titlekey].push(fname)
        filename_map[fname] = titlekey
        entry_array[2].gsub!(" ", "&nbsp;")
        result += "<tr><td><tt>No.#{idx.to_s}</tt></td>" +
                  "<td><tt>#{entry_array[1]}</tt></td>" +
                  "<td><tt>#{entry_array[0]}</tt></td>" +
                  "<td><tt><a href='#{fname}.html'>#{entry_array[2]}</a></tt></td></tr>\n"
        str = str[DIR_ENTRY_SIZE..-1]
    end
    result += "\n</table>"
    return result, thread_map, filename_map
end

def fill_entry(title, author, time, path, num, filelist)
    title.gsub!(" ", "&nbsp;");
    fname = ""
    if( path[0..1] == "D." ) # ask if it's a directory
        fname = path + "/index.html"
    else 
        filelist.push(path) # we want raw data filename here, not htmls.
        fname = path + ".html"
    end
    result = "<tr><td><tt>No.#{num}</tt></td>" +
             "<td><tt><a href='#{fname}'>#{title}</a></tt></td>" +
             "<td><tt>#{author}</tt></td>" + 
             "<td><tt>#{time}</tt></td></tr>\n"
    result
end

def parse_Names(str)
    filelist = [] #setup a filelist which is in order with the record in .Names (doesn't contain directory entry here)
    result = "\n<table width='960' cellpadding='0' cellspacing='0' border='0'>"
    head = str.slice(/\n*.*\n*/)
    result += "<tr><td>#{head}</td></tr></table>\n"
    result += "<table width='960' cellpadding='0' cellspacing='0' border='0'>\n"
    result += "    <tr><td width='8%'> </td><td width='70%'> </td><td width='12%'> </td><td width='10%'> </td></tr>\n"
    str = str[head.size..-1] if head[0..6] == "# Title"
    idx = 1; entry_array = []
    index = str.split(/^Name=/)
    index.delete(""); index.delete("\n");
    index.each { |entry|
        entry_array = entry.split("\n")
        entry_array[1..-1] = entry_array[1..-1].map{|i| i=i[5..-1]}
        #e.g "Name=blahblahblah" <- omit the first 5 characters.
        if entry_array.size == 3 #entry_array is ["title", "author", "path"]
            result += fill_entry(entry_array[0], entry_array[1], entry_array[2], entry_array[2], idx.to_s, filelist)
        elsif entry_array.size == 5 #entry_array is ["title","author","mm/dd/yy","path","number"]
            result += fill_entry(entry_array[0], entry_array[1], entry_array[2], entry_array[3], entry_array[4], filelist)
        end
        idx += 1
    }
    result += "\n</table>"
    return result, filelist
end

def ansi_color_to_html_color(attr, state)
    old_state = Array.new(state) #make a state copy
    result = "</font><font class='c"
    attr.delete!("\033[")
    if attr == "0" or attr == "" #end of a colored sequence
        state[0] = "0"; state[1] = "37"; state[2] = "40";
        result += "#{state.join}'>"
    else
        attr.split(";").each { |c|
            c.delete!(";")
            if c == "0" or c == "1" #high-light part
                state[0] = c
            elsif c[0..0] == "3"    #foreground part
                state[1] = c
            elsif c[0..0] == "4"    #background part
                state[2] = c
            end
        }
        old_state != state ? result += "#{state.join}'>" : result = ""
    end
    result
end

def convert_header_to_html(header_array)
    line1_array = header_array[0].split(/看板:|站內:/)
    boardname = nil
    boardname = line1_array[-1] if line1_array.size > 1 # make sure it is really splitted by "看板:"
    username  = line1_array[0].split(/作者:|發信人:/)[1]
    title     = header_array[1].split(/標題:|標  題:/)[1]
    time      = header_array[2].split(/時間:|發信站:/)[1]
    result = "<tr><td class='c13447' width='10%'>作者</td>" +
             "<td class='c03744' width='60%'>#{username}</td>"
    if boardname != nil
        result +="<td class='c13447' width='10%'>看板</td>\n" +
                 "<td class='c03744' width='20%'>#{boardname}</td></tr>\n"
    else
        result +="<td class='c03744' width='10%'> </td>\n" +
                 "<td class='c03744' width='20%'> </td></tr>\n"
    end
    result +="<tr><td class='c13447'>標題</td><td class='c03744' colspan=3>#{title}</td></tr>\n" +
             "<tr><td class='c13447'>時間</td><td class='c03744' colspan=3>#{time}</td></tr>\n"
end

def parse_article(str)
    state = ["0","37","40"]    
    result = ""
    ansi_attr = ""
    ansi_flag = false
    istart = iend = idx = 0
    str.gsub!(/(^\241\260.*)/){ |i| i = "\033[32m#{i}\033[0m"}# for "※" in the beginning of a line
    str.gsub!(/(^(:|>).*)/){ |i| i = "\033[36m#{i}\033[0m"}   # for ":" or ">" in the beginning of a line
    str.each_byte { |byte| 
        if ansi_flag == true
            if byte == 109 # ascii code for "m" : end of ansi color attr
                iend = idx
                ansi_attr = str[istart...iend]
                result += ansi_color_to_html_color(ansi_attr, state)
                ansi_attr = "" #need to clean this up when it's converted, for re-use.
                ansi_flag = false
                istart = idx+1
            end            
        else
            tag = TAG8859_1[byte]
            if tag != nil
                iend = idx
                result += str[istart...iend].gsub(/((http|https|telnet|ftp):\/\/\S+)/) { |i| i = "<a href='#{i}'>#{i}</a>"}
                result += tag
                ansi_flag = true if byte == 27 # check for ESC character
                istart = idx+1
            end
        end
        idx += 1
    }
    result += str[istart...idx] # copy the remaining texts
    result
end

def get_last_next_file_by_idx(filelist, idx)
    lastfile = (idx-1>=0) ? filelist[idx-1] : nil # get last file name
    nextfile = filelist[idx+1] # get next file name
    return lastfile, nextfile
end

def get_last_next_file_in_thread(thread_map, filename_map, fname)
    lastfile_thread = nextfile_thread = nil
    if thread_map != nil and filename_map != nil
        onlyname = fname.split("/")[-1] #get the list of filenames in this thread
        a_thread = thread_map[filename_map[onlyname]] #map filename to title as key for thread_map
        if a_thread != nil and a_thread.size > 1
            idx_in_thread = a_thread.index(onlyname) 
            lastfile_thread = (idx_in_thread-1>=0) ? a_thread[idx_in_thread-1] : nil 
            nextfile_thread = a_thread[idx_in_thread+1]
        end
    end
    return lastfile_thread, nextfile_thread
end

def generate_file_links(idx, size, lastfile, nextfile, l_in_thread, n_in_thread)
    links = "<table><tr>"
    links += "<td><a href='index.html'>回上層</a></td>"
    links += "<td>#{idx+1} / #{size}</td>"
    links += "<td><a href='#{lastfile.split("/")[-1]}.html'>上一頁</a></td>" if lastfile != nil
    links += "<td><a href='#{nextfile.split("/")[-1]}.html'>下一頁</a></td>" if nextfile != nil
    links += "<td><a href='#{l_in_thread.split("/")[-1]}.html'>同主題上一篇</a></td>" if l_in_thread != nil
    links += "<td><a href='#{n_in_thread.split("/")[-1]}.html'>同主題下一篇</a></td>" if n_in_thread != nil
    links += "</tr></table>\n"
    links
end

def readlines_n(file, nline)
    a = Array.new
    nline.times{ |i| 
        break if file.eof?
        a.push(file.readline) 
    }
    a
end

def convert_filelist(filelist, thread_map = nil, filename_map = nil)
    lines = []
    lastfile = nextfile = l_in_thread = n_in_thread = nil
    filelist.each_with_index { |fname, idx|
        #log " .... Debug: converting article: #{fname}"
        if FileTest.file?(fname)
            File.open(fname, "r") { |file|
                lastfile, nextfile = get_last_next_file_by_idx(filelist, idx)
                l_in_thread, n_in_thread = get_last_next_file_in_thread(thread_map, filename_map, fname)
                result = html_header(fname.split("/")[0..-2].join("/")) + 
                         generate_file_links(idx, filelist.size, lastfile, nextfile, l_in_thread, n_in_thread) +
                         "\n<table width='960' cellpadding='4' cellspacing='0' border='0'>\n"
                lines = readlines_n(file, 4) # read header and process it
                if( lines.size >= 4 and #article can't have a header if it has less than 4 lines.
                    (lines[0][0..1] =~ /作|發/) != nil and lines[1][0..1] == "標" and
                    (lines[2][0..1] =~ /時|發/) != nil ) then #make sure it has a header
                    result += convert_header_to_html(lines[0..2])
                    lines = lines[3..-1]
                end
                result += "<tr><td colspan=4 bgcolor=#000000><pre>\n"
                result += parse_article(lines.join) 
                result += parse_article(readlines_n(file, 24).join) while file.eof? != true
                result += "\n</pre></td></tr></table>" + HTML_REAR
                File.open(fname+".html", "w") { |file| file.syswrite(result) }
            }
            File.delete(fname)
        end
    }
end

def convert_articles(pathrule, thread_map = nil, filename_map = nil)
    #make a copy of every M.123456789.A and fetch the content, then save to a html file.
    log "Debug: converting articles at: #{pathrule}"
    tmpx = tmpy = nil
    filelist = Dir.glob(pathrule).sort{ |x,y| 
        #I have to do this because "M.99.A" is bigger than "M.100.A" in lexical comparison
        #But in fact I need otherwise. (e.g "M.999999999.A" should be smaller than "M.1000000000.A")
        tmpx = x.slice(/M\.[0-9]{9,10}\.A/)
        tmpy = y.slice(/M\.[0-9]{9,10}\.A/)
        if tmpx != nil 
            x = tmpx[2...-2]; x = "0"+x if x.size < 10
        end
        if tmpy != nil 
            y = tmpy[2...-2]; y = "0"+y if y.size < 10
        end
        x <=> y
    }
    convert_filelist(filelist, thread_map, filename_map)
end

DEFAULT_ADDITIONALS = ["sig.*", "buf.*", "overrides", "plans", "write.log", "notes", "results"]

def link_to_additional_files(path)
    result = ""
    names = {"簽名檔"=>DEFAULT_ADDITIONALS[0], "暫存檔"=>DEFAULT_ADDITIONALS[1], 
             "好友名單"=>DEFAULT_ADDITIONALS[2], "個人名片"=>DEFAULT_ADDITIONALS[3], 
             "熱線記錄"=>DEFAULT_ADDITIONALS[4], "進板畫面"=>DEFAULT_ADDITIONALS[5],
             "投票紀錄"=>DEFAULT_ADDITIONALS[6]}
    names.each { |key, rule|
        result += "<tr>"
        Dir.glob("#{path}/#{rule}").sort!.each_with_index { |fname, i|
            i > 0 ? name = key+(i+1).to_s : name = key 
            result += "<td><a href='#{fname.split("/")[-1]}.html'>#{name}</a></td>"
        }
        result += "</tr>\n"
    }
    result
end

def convert_index_at(path, fname, parser_cb, additional = false)
    #interpret .DIR file and make a index.html at /path/
    log "Debug: converting #{fname} at: #{path}"
    thread_map = filename_map = nil
    if FileTest.file?("#{path}/#{fname}") #make sure an index exists.
        f = File.open("#{path}/#{fname}", "r")
        str = f.sysread( f.stat.size )
        links = "<table cellpadding='3'><tr><td><a href='#{find_file_in_upper_dir(path, "index.html")}'>回上層</a></td></tr>\n"
        links += link_to_additional_files(path) if additional == true
        links += "</table>\n"
        parsed_str, thread_map, filename_map = parser_cb.call(str)
        str = html_header(path) + links + parsed_str + HTML_REAR
        File.open("#{path}/index.html", "w") { |file| file.syswrite(str) }
        f.close
        File.delete("#{path}/#{fname}")
    end
    return thread_map, filename_map
end

def convert_boards_files(path)
    thread_map, filename_map = convert_index_at(path, ".DIR", method("parse_DIR"), true)
    convert_articles("#{path}/M.*.A", thread_map, filename_map)
    DEFAULT_ADDITIONALS.each { |rule| convert_articles("#{path}/#{rule}") }
    to_be_deleted = Dir.glob("#{path}/.DIR.*") + Dir.glob("#{path}/SR.*")
    to_be_deleted.each { |fname| 
        File.delete(fname) if FileTest.file?(fname)
    }
end

def convert_personal_files(path)
    thread_map, filename_map = convert_index_at(path, ".DIR", method("parse_DIR"), true)
    convert_articles("#{path}/M.*.A", thread_map, filename_map)
    DEFAULT_ADDITIONALS.each { |rule| convert_articles("#{path}/#{rule}") }
    to_be_deleted = ["#{path}/.DIR.old", "#{path}/.bbsrc", "#{path}/.boardrc", 
                     "#{path}/email", "#{path}/justify", "#{path}/write"]
    to_be_deleted += Dir.glob("#{path}/M.*.A.head")
    to_be_deleted.each { |fname| 
        File.delete(fname) if FileTest.file?(fname)
    }
end

def expand_gems_directory(path)
    #travel through every D.123456789.A folder and create index.html recursively.
    log "Debug: travelling directory at: #{path}"
    Dir.foreach("#{path}") { |dname|
        convert_gems_files(path + "/" + dname) if dname[0..0] == "D"
    }
end

def convert_gems_files(path)
    filelist, useless = convert_index_at(path, ".Names", method("parse_Names"))
    # the first returned item by convert_index_at was thread_map, but here served as a filelist. (dynamic type)
    if filelist != nil
        filelist.map!{|i| i = path+"/"+i }  #inject the file path here
        convert_filelist(filelist)
        expand_gems_directory(path)
    end
end

def create_main_index(bp, pp, gp)
    File.open("#{TMPDIR}/index.html", "w") { |file|
        str = html_header + "\n<table>"
        str += "<tr><td><a href='#{bp}/index.html'>#{bp.split("/")[-1]} 板文章</a></td></tr>\n" if FileTest.directory?(bp)
        str += "<tr><td><a href='#{gp}/index.html'>#{gp.split("/")[-1]} 板精華區</a></td></tr>\n" if FileTest.directory?(gp)
        str += "<tr><td><a href='#{pp}/index.html'>個人信箱</a></td></tr>\n" if pp != nil and FileTest.directory?(pp)
        str += "\n</table>" + HTML_REAR
        file.syswrite(str)
    }
end

def packing_board(boardname, dest, pers_path = nil)
    log "Debug: packing started... [#{Time.new.to_s}]"
    boards_path = "boards/#{boardname}"
    gems_path = "man/#{boardname}"
    create_working_dir(boards_path, pers_path, gems_path)
    create_main_index(boards_path, pers_path, gems_path)
    convert_boards_files("#{TMPDIR}/"+boards_path) if FileTest.directory?(boards_path)
    convert_personal_files("#{TMPDIR}/"+pers_path) if pers_path != nil and FileTest.directory?(pers_path)
    convert_gems_files("#{TMPDIR}/"+gems_path) if FileTest.directory?(gems_path)
    #convert_articles("#{TMPDIR}/#{gems_path}/.index") if FileTest.directory?(gems_path)
    copy_to_public_html(boards_path, pers_path, gems_path, dest)
    log "Debug: packing is done. [#{Time.new.to_s}]"
end

def packing_for_user(userid, dest)
    pers_path = "home/#{userid[0..0].downcase}/#{userid}"
    packing_board("P_#{userid}", dest, pers_path)
end

TEMPLOG_NAME = "backup/#{ARGV[0]+ARGV[1]}.log"

def start_logging
    FileUtils.mkdir("backup") unless FileTest.directory?("backup")
    $log = File.open(TEMPLOG_NAME,"w") #global log file.
end

def stop_logging
    $log.close
    $log = File.open(TEMPLOG_NAME,"r")
    data = $log.sysread( $log.stat.size )
    $log.close
    File.delete(TEMPLOG_NAME)
    mainlog = File.open("backup.log","a")
    mainlog.syswrite( data )
    mainlog.close
end

def main(arg, dest, u)
    start_logging
    if arg == nil
        log "no entry"
    elsif dest == nil
        log "an randomized package name should be provided"
    else
        if u == "u"
            log "packing the data for user #{arg}....."
            packing_for_user(arg, dest)
        else 
            log "packing the data of board #{arg}....."
            packing_board(arg, dest)
        end
    end
    stop_logging
end

main(ARGV[0], ARGV[1], ARGV[2])

