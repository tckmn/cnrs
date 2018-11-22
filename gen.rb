#!/usr/bin/ruby

$VERSION = 0
$data = Dir['data/blocks/*/*'].map{|x| [x.split(?/)[-1], File.read(x)]}.to_h
$spec = File.readlines('data/spec').map{|x| x.split(nil, 2)}.to_h.transform_values{|v|
    if v[0] == ?@
        # bold is inverted here because most colored things should also be bolded
        v[1..-1].split.map{|x| [x[0], [x[1], x[2,2], !x[4]]]}.to_h
            .merge({'<' => ['<', '', false]})  # awful hack
    else
        v.split.map{|x| w, d = x.scan(/^\d+|.+/); [w.to_i, d]}
    end
}
$colorschemes = Dir['data/colors/*'].map{|x|
    tbl = File.readlines(x).map(&:split).to_h
    [x.split(?/)[-1], "
        body { background-color: #{tbl['BACKGROUND']}; color: #{tbl['NO_COLOR']}; }
        .bk, .C                         { color: #{tbl['BLACK']}; }
        .re, .DRA                       { color: #{tbl['RED']}; }
        .gr, .VEG, .E                   { color: #{tbl['GREEN']}; }
        .br, .FLE, .LTH, .WOO           { color: #{tbl['BROWN']}; }
        .bl                             { color: #{tbl['BLUE']}; }
        .ma, .S                         { color: #{tbl['MAGENTA']}; }
        .cy, .IRN, .MTH, .MET           { color: #{tbl['CYAN']}; }
        .gy, .N, .SLV, .MIN, .B         { color: #{tbl['GRAY']}; }
        .no                             { color: #{tbl['NO_COLOR']}; }
        .or                             { color: #{tbl['ORANGE']}; }
        .bg, .M, .GM                    { color: #{tbl['BRIGHT_GREEN']}; }
        .ye, .CPR, .GLD                 { color: #{tbl['YELLOW']}; }
        .bb, a                          { color: #{tbl['BRIGHT_BLUE']}; }
        .bm, .CLO, .PLS, .GEM, .MAT     { color: #{tbl['BRIGHT_MAGENTA']}; }
        .bc, .GLA                       { color: #{tbl['BRIGHT_CYAN']}; }
        .wh, .L, .WAX, .PAP, .BON, .PLT { color: #{tbl['WHITE']}; }
    "]
}.to_h

def tr a, c=true
    transposed = ([nil]*a.map(&:size).max).zip(*a)
    c ? transposed.map(&:compact) : transposed.map{|x| x[1..-1]}
end

@colors = $colorschemes.values[0].scan(/\.(\w+)/).map &:first
def html str, clr, bold=false
    str = (str || '').gsub('&', '&amp;').gsub('<', '&lt;')
    classes = []
    classes.push clr if @colors.include? clr
    classes.push 'fb' if bold
    if classes.empty?
        str
    else
        q = classes.size == 1 ? '' : ?'
        "<b class=#{q}#{classes * ' '}#{q}>#{str}</b>"
    end
end

def render sec
    rows = [html("##### #{sec} #####".center(80), 'bb'), ' ' * 80]
    sp = $spec[sec]
    $data[sec].each_line.with_index do |line, nl|
        sp = $spec["#{sec}#{nl}"] || sp
        line.chomp!
        len = 0
        if sp.is_a? Hash
            rows.push line.gsub(/[#{sp.keys*''}]/) {|x| html(*sp[x]) }
            len = line.size
        elsif line[0] == ?=
            rows.push html(line, 'bg')
            len = line.size
        else
            rows.push ''
            eol = line.slice!(80..-1) || ''
            idx = 0
            sp.each do |w, d|
                bold = false
                clr = d.clone
                # handle bold
                if clr && clr[0] == ?&
                    clr.slice! 0
                    bold = true
                end
                # handle suppression of space
                if clr && clr[0] == ?<
                    clr.slice! 0
                    idx -= 1
                elsif idx > 0
                    rows[-1] += ' '
                    len += 1
                end
                # handle special rules
                clr = case clr
                    when /^\$(\d*)$/ then eol[$1.to_i,2]
                    when ?^ then (line[idx,w] || '').strip
                    else clr
                    end
                while clr && clr[-3] =~ /[^A-Za-z0-9$^]/
                    clr = eol.include?(clr[-3]) ? clr[-2,2] : clr[0...-3]
                end
                rows[-1] += html(line[idx,w], clr, bold)
                len += (line[idx,w]||'').size
                idx += w + 1
            end
        end
        rows[-1] += ' ' * (80 - len)
    end
    rows
end

def go layout, font, bg
    variant = "html-#{layout}-#{font}-#{bg}-v#{$VERSION}"
    lyt = tr File.read("data/layout/#{layout}").lines.map(&:split)
    File.open("out/cnrs-#{variant}.html", ?w) do |f|
        f.puts <<~X
        <!DOCTYPE html>
        <html lang='en'>
            <head>
                <title>cnrs</title>
                <style>
                body { font: #{font}px monospace; }
                #{$colorschemes[bg]}
                b { font-weight: normal; }
                b.fb { font-weight: bold; }
                </style>
            </head>
            <body>
                <pre>
        X

        header = ['  ' \
            "#{html 'comprehensive nethack reference sheet', 'or', true} | " \
            "<a href='https://github.com/KeyboardFire/cnrs'>https://github.com/KeyboardFire/cnrs</a> | " \
            "#{html 'andy@keyboardfire.com', 'wh', true} | " \
            "#{html variant, 'bk'}",
            '']

        sep = 'SEP'
        cols = lyt.map do |col|
            col.map do |sec|
                case sec
                when /^\d+$/ then [' '*80] * (sec.to_i-1) + [sep]
                when ?- then nil
                else render sec
                end
            end.compact.reduce{|a,x| a + [' '*80] + x }
        end

        f.puts header + tr(cols, false).map{|x|
            x[0] == sep ?
                html('~' * (82*x.size - 2), 'bc') :
                x.map{|y| y || ' '*80 } * '  '
        }

        f.puts <<~X
                </pre>
            </body>
        </html>
        X
    end
end

go '3a', '10', 'dark'
