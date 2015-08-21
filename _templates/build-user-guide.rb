#!/usr/bin/env ruby

require 'fileutils'

siesta_dir = ENV['siesta_dir']
docs_dir=File.dirname(File.dirname(__FILE__))

unless siesta_dir && File.directory?(siesta_dir)
  warn "\$siesta_dir does not exist or is not executable"
  exit 1
end


puts "Building user guide in $docs_dir ..."

Dir["#{siesta_dir}/{README,Docs/*}.md"].each do |src|
  dst = src.
    gsub(/^#{siesta_dir}\/?/, '').
    gsub(/\.md$/, '').
    gsub('README', 'index').
    gsub('Docs/', 'guide/').
    gsub(/index$/, '')

  dst = File.join(docs_dir, dst)

  print "  #{src} → #{dst} "

  content = File.read(src)

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
    f.puts content.gsub(/\]\(([^\]]+)\.md\)/, '](\1)')
  end

  FileUtils.cp_r File.join(siesta_dir, 'Docs/images'), File.join(docs_dir, "/guide/")
end
