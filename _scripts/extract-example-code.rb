#!/usr/bin/env ruby

require 'fileutils'

class MatchData
  def range(group = 0)
    self.begin(group) ... self.end(group)
  end
end

script_dir = File.dirname(File.expand_path(__FILE__))
docs_dir = File.dirname(script_dir)
output_dir = ARGV[0] || File.join(script_dir, "SiestaExampleTest", "Examples")

unless output_dir
  STDERR.puts "No output directory specified"
  exit 1
end

unless File.directory?(output_dir)
  STDERR.puts "#{output_dir} is not a directory"
  exit 1
end

code_pat = %r{
  <pre\s+class="highlight\s+plaintext">\s*
  <code>
  (.*?)
  </code>\s*
  </pre>
  |
  ^```swift *#\n
  (.*?)
  ^```
}mux

Dir["#{docs_dir}/api/*/**/*.html", "#{docs_dir}/**/*.md"].reject { |f| f =~ /docsets/ }.each do |file|
  file_ident = file
    .sub(/^#{docs_dir}\/?/, "")
    .sub(/(\/index.md|.html)$/, "")
    .gsub(/[^[:word:]]/, '_')

  snippets = File.read(file, encoding: 'utf-8').scan(code_pat).map do |*matches|
    matches.compact.join.strip
  end

  next unless snippets.any?

  outfile = File.join(output_dir, "#{file_ident}.swift")
  examples = if File.exist?(outfile)
    File.read(outfile, encoding: "utf-8")
  else
    puts "Creating #{outfile}"
    "/*\nimport Siesta\n\nfunc #{file_ident}(service: Service, resource: Resource) {\n\n}\n*/\n\n"
  end

  snippets.uniq.each.with_index do |snippet, index|
    snippet_ident = "#{file_ident}:#{index}"

    existing = examples.match %r{
      \n?
      (\ *)
      //═+\s*#{snippet_ident}\s*═+\n
      \s*
      ((?:\ *//[^\n]+→[^\n]*\n)*)
      \s*
      (.*?)
      \s*
      //═+
      \s*\n
    }mux
    if existing
      indent = $1
      substitutions = $2
    else
      indent = "    "
      substitutions = ""
      puts "Adding #{snippet_ident}"
    end

    snippet.gsub!(/&lt;/, "<")
    snippet.gsub!(/&gt;/, ">")
    snippet.gsub!(/&amp;/, "&")

    substitutions.lines.each do |sub|
      raise "Malform substitution: #{sub}" unless sub =~ %r{//(.*)→(.*)}u
      snippet.gsub!($1.strip, $2.strip)
    end

    snippet =
      "\n//══════ #{snippet_ident} ══════\n" +
      substitutions.gsub(/^ */, "") +
      snippet +
      "\n//════════════════════════════════════\n\n"

    replace_range = existing&.range || (examples.rindex("}") ... examples.rindex("}"))
    examples[replace_range] = snippet.gsub(/^/, indent)
  end

  puts "Writing #{outfile}"
  File.write(outfile, examples, encoding: "utf-8")
end
