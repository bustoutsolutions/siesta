#!/usr/bin/env ruby

require 'fileutils'
require 'ostruct'

siesta_dir = ENV['siesta_dir']
docs_dir=File.dirname(File.dirname(__FILE__))

unless siesta_dir && File.directory?(siesta_dir)
  warn "\$siesta_dir does not exist or is not executable"
  exit 1
end


puts "Building user guide in $docs_dir ..."

toc = Hash[
  File.read(File.join(siesta_dir, 'Docs/index.md')).
    scan(/^- \[(.*)\]\((.*)\)/).
    map do |title, file|
      file = File.expand_path("#{siesta_dir}/Docs/#{file}")
      warn "Nonexistent file in toc: #{file}" unless File.exists?(file)
      [file, OpenStruct.new(title: title, file: file)]
    end
]

prev_info = nil
toc.each do |file, info|
  prev_info.next = info if prev_info
  prev_info = info
end

dst_path_for = lambda do |parent_dir, srcfile|
  File.expand_path(srcfile).
    gsub(/^#{File.expand_path(parent_dir)}\/?/, '').
    gsub(/\.md$/, '').
    gsub('README', 'index').
    gsub('Docs/', 'guide/').
    gsub(/index$/, '')
end

Dir["#{siesta_dir}/{README,Docs/*}.md"].each do |src|
  dst = dst_path_for.call(siesta_dir, src)

  dst = File.join(docs_dir, dst)

  print "  #{src} → #{dst} "

  content = File.read(src, encoding: 'utf-8')

  unless content =~ /^# (.*)/
      puts
      warn "No title!"
      exit 1
  end

  title = $1.gsub(/^Siesta$/, 'Overview')
  puts " (#{title}) ..."

  FileUtils.mkdir_p(dst)

  File.open("#{dst}/index.md", 'w') do |f|
    f.puts "---"
    f.puts "title: '#{title}'"
    f.puts "layout: default"
    f.puts "---"
    f.puts
    f.puts(
      content.gsub(/\]\(([^\)]+)\.md\)/) do
        path = dst_path_for.call(
          siesta_dir,
          File.expand_path(File.join(File.dirname(src), $1)))
        "](/siesta/#{path})"
      end)

    toc_info = toc[File.expand_path(src)]
    if toc_info
      if toc_info.title != title
        warn "    Mismatched title in TOC: #{toc_info.title} != #{title}"
      end
      if toc_info.next
        next_file = '../' + dst_path_for.call("#{siesta_dir}/Docs/", toc_info.next.file)
        f.puts
        f.puts "Next: **[#{toc_info.next.title}](#{next_file})**"
        f.puts '{: .guide-next}'
      end
    end
  end

  FileUtils.cp_r File.join(siesta_dir, 'Docs/images'), File.join(docs_dir, "/guide/")
end
