#!/usr/bin/env ruby
#
# Script to run Ruby processes in parallel for indexing into Solr
#
# This should be kept pure Ruby so it doesn't need to be run through
# bundler.

require 'optparse'
require 'pathname'

def parse_options
  options = {
    num_processes: 1,
    log_dir: 'log/indexing'
  }
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: index_solr.rb [options] FILE_OR_GLOB_OR_DIR [FILE_OR_GLOB_OR_DIR ...]'

    opts.separator ""
    opts.separator "This indexes XML files into Solr."
    opts.separator ""
    opts.separator "Globs should be quoted when invoking through a shell."
    opts.separator ""

    opts.on('-l', '--log-dir LOG_DIR', 'Log directory') do |v|
      options[:log_dir] = v
    end
    opts.on('-p', '--processes PROCESSES', 'Number of parallel processes') do |v|
      options[:num_processes] = v
    end
    opts.on_tail('-h', '--help', 'Show this message') do
      puts opts
      exit
    end
  end
  opt_parser.parse!
  [ options, opt_parser ]
end

# takes a list of args (from ARGV, usually)
# and returns a list of paths that can be passed as args to 'ls'.
# if arg is a directory, '*.xml' is appended to it.
# deliberately does NOT expand globs because we'll eventually pass this to
# ls in a shell, and a large number of expanded paths will cause problems.
def args_to_paths(args)
  args.map do |arg|
    path = Pathname.new(arg)
    if path.exist?
      realpath = path.realpath
      if realpath.directory?
        realpath.join('*.xml').to_s
      elsif realpath.file?
        realpath.to_s
      end
    elsif Dir.glob(arg).size > 0
      arg
    else
      abort "ERROR: Argument '#{arg}' doesn't seem to exist, can't continue."
    end
  end
end

def main
  options, opt_parser = parse_options

  if ARGV.length == 0
    puts opt_parser.help
    exit
  end

  # escape spaces
  paths = args_to_paths(ARGV).map { |p| p.gsub(' ', '\ ') }.join(' ')

  # this should expand and also trim the trailing slash if it exists
  log_dir = Pathname.new(options[:log_dir])
  log_dir.mkdir unless log_dir.exist?
  log_dir = log_dir.realpath.to_s

  # this is a bit nuts, be careful when editing this!
  cmd = "ls #{paths} | sort | xargs -P #{options[:num_processes]} --verbose -I FILENAME bash -c \"bundle exec rake solr:marc:index MARC_FILE=FILENAME >> #{log_dir}/\\$(basename FILENAME .xml).log 2>> #{log_dir}/\\$(basename FILENAME .xml).log\""

  exec cmd
end

main

