#!/usr/bin/env ruby

require 'fileutils'
require 'net/http'

class DocChecker
  def initialize(file)
    @file = file
    @apply_fixes = ARGV.include?('--fix')
  end

  def check!(fixed, unfixed)
    @fixed, @unfixed = fixed, unfixed

    modified = false
    lines = File.read(@file, encoding: 'utf-8').lines

    lines.each.with_index do |line, line_num|
      @location = "#{@file}:#{line_num + 1}: "

      orig_line = line.dup
      check_links(line)
      modified ||= (line != orig_line)
    end

    if modified
      puts "Writing changes to #{@file}"
      File.write(@file, lines.join, encoding: 'utf-8')
    end
  end

private

  DOC_LINK_PAT = %r{
    (https?:)
    (//bustoutsolutions.github.io/)
    (  [A-Za-z0-9\-\._~:/@%]* )       # path
    (\#[A-Za-z0-9\-\._~:/@%\(\)]+ )?  # anchor
  }x

  def check_links(line)
    line.gsub!(DOC_LINK_PAT) do
      url, schema, base, path, anchor = Regexp.last_match.to_a

      unless schema == "https:"
        issue "doc link does not use https" do
          schema = "https:"
        end
      end

      response = Net::HTTP.get_response(URI("http://localhost:4000/#{path}"))

      if response.code.to_i != 200
        issue "broken link [#{response.code}]: #{url}"
      elsif anchor
        id = anchor.gsub(/^#|\)[\.:]?$/, '')
        available_ids =
          response.body
            .scan(/(?:name|id)=(?:"([^"]+)"|'(^'+)')/)
            .map { |v0, v1| v0 || v1 }
        
        unless id_index = available_ids.index(id)
          issue "broken anchor: #{url}"
          puts "available anchors:"
          available_ids.sort.each { |id| puts "    #{id}" }
          puts
        end

        if id_index && id =~ %r{^/s:}
          issue "USR anchor: #{anchor}" do
            next_id = available_ids[id_index + 1]
            if next_id =~ %r{^//apple_ref}
              anchor = '#' + next_id
            end
          end
        end
      end
      
      [schema, base, path, anchor].join
    end
  end

  def issue(description)
    description = @location + description
    if @apply_fixes && block_given?
      print "FIXING: "
      yield
      @fixed << description
    else
      @unfixed << description
    end
    puts description
  end
end




siesta_dir = ENV['siesta_dir']
docs_dir=File.dirname(File.dirname(__FILE__))

fixed = []
unfixed = []

Dir[
  "#{siesta_dir}/{README,Docs/*}.md",
  "#{siesta_dir}/{Source,Tests}/**/*.{md,swift}"
].each do |file|
  DocChecker.new(file).check!(fixed, unfixed)
end
