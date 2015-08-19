#!/usr/bin/env ruby

require 'json'
require 'markaby'

unless ARGV.size == 3
  warn "Usage: build-spec-docs.rb <input.json> <output.html>"
  exit 1
end

json = JSON.parse(File.read(ARGV[0], encoding: 'utf-8'))

def format_name(name)
  if name =~ /Spec$/
    name.gsub(/Spec$/, '').gsub(/([a-z])([A-Z])/) { "#{$1} #{$2.downcase}" }
  else
    name
  end
end

def collapse_single_child(result)
  if result["passed"].nil? && (result["children"] || []).size == 1
    child = result["children"].first
    result["name"] += ", " + child["name"]
    %w(file line passed).each do |key|
      result[key] = child[key]
    end
    result["children"] = nil
  end
end

def link_to_callsite(result)
  unless result["file"] =~ %r{[Ss]iesta/Tests/(.*\.swift)$}
    warn "Unable to determine spech path from #{result["file"].inspect}"
    return nil
  end
  specpath = $1

  "#{ARGV[2]}/Tests/#{specpath}#L#{result["line"]}"
end

PASSED_CLASSES = { true => "passed", false => "failed" }.freeze

def dump_results(results)
  return unless results

  ul do
    results.each do |result|
      collapse_single_child(result)

      li(class: PASSED_CLASSES[result["passed"]]) do
        a(name: result["name"].gsub(' ', '_')) { }
        name = format_name(result["name"])
        if result["file"]
          a name, href: link_to_callsite(result)
        else
          text name
        end
        dump_results(result["children"])
      end
    end
  end
end

mab = Markaby::Builder.new
mab.html do
  enable_html5!

  head do
    title "Siesta Specs"
    style(type: 'text/css') do
      "
        body {
          font-family: 'Helvetica Neue', Helvetica, 'Segoe UI', Arial, freesans, sans-serif;
          padding: 1em 2em;
        }
        ul {
          list-style: none;
          padding: 0;
          margin: 0;
          margin-left: 1.2em;
        }
        li {
          margin: 0.4ex;
          font-weight: normal;
        }
        body > ul {
          margin-left: 0;
        }
        body > ul > li {
          margin-top: 2em;
          font-weight: bold;
        }
        .passed:before,
        .failed:before {
          display: inline-block;
          padding: 0.1em 0.3em;
          margin-right: 1ex;
          color: white;
          font-size: 80%;
          border-radius: 1.2em;
        }
        .passed:before {
          content: '✓';
          background: #8C8;
        }
        .failed:before {
          content: '☠';
          background: #C43;
        }
        .passed, .passed a, .passed a:visited {
          color: #030;
        }
        .failed, .failed a, .failed a:visited {
          color: #800;
        }
        a {
          text-decoration: none;
        }
        a:hover {
          text-decoration: underline;
        }
        .note {
          color: #444;
          font-size: 92%;
        }
      "
    end
  end
  body do
    h1 "Siesta Specs"

    p.note "Report generated from regression tests. Click a spec to see the code on Github."

    p.note
      text "See also: "
      strong { a "Siesta Overview", href: "http://bustoutsolutions.github.io/siesta/.md" }
      text " | "
      strong { a "User Guide", href: "http://bustoutsolutions.github.io/siesta/guide/" }
      text " | "
      strong { a "API Docs", href: "https://bustoutsolutions.github.io/siesta/api/" }

    dump_results json["results"]
  end
end

File.open(ARGV[1], 'w') do |f|
  f.puts mab
end
