#!/usr/bin/env ruby

require 'optparse'

def parse_options
  options = {
      chunk_size: nil,
      format: false,
  }
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: index_preprocess.rb [options] FILE'

    opts.separator ""
    opts.separator "This utility preprocesses Alma MARC XML exports so they're ready"
    opts.separator "for indexing. This includes splitting up files, fixing namespace"
    opts.separator "and data problems in the MARC XML, and formatting for readability."
    opts.separator ""

    opts.on('-c', '--chunk-size SIZE', 'Number of records per chunk file') do |v|
      options[:chunk_size] = v.to_i
    end
    opts.on('-f', '--format', 'Format (prettify) XML using xmllint (defaults to false)') do |v|
      options[:format] = true
    end
    opts.on_tail('-h', '--help', 'Show this message') do
      puts opts
      exit
    end
  end
  opt_parser.parse!
  [ options, opt_parser ]
end

def run(command)
  result = system(command)
  if !result
    puts "error occurred running this command: #{command}"
    puts 'stopping.'
    exit 1
  end
end

def check_file_exists(path)
  if !File.exist?(path)
    puts "Error: expected file #{path} to exist. Stopping."
    exit 1
  end
end

def main
  options, opt_parser = parse_options

  if ARGV.length == 0
    puts opt_parser.help
    exit
  end

  export_path = ARGV[0]
  export_file = File.basename(File.expand_path(export_path))
  export_file_dir = File.dirname(File.expand_path(export_path))

  script_dir = File.expand_path(File.dirname(__FILE__))
  xsl_dir = "#{script_dir}/xsl"

  Dir.chdir(export_file_dir)

  run("#{script_dir}/split.sh #{export_file} #{options[:chunk_size]}")

  Dir.glob('chunk*.xml').each do |file|
    # fix various problems in Alma's MARC XML
    fixed_file = file.gsub('chunk', 'fixed')
    run(%Q!JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{file} -xsl:#{xsl_dir}/fix_alma_prod_marc_records.xsl -o:#{fixed_file}!)
    check_file_exists(fixed_file)

    part_file = file.gsub('chunk', 'part')
    if options[:format]
      run("xmllint --format #{fixed_file} > #{part_file}")
      check_file_exists(part_file)
      File.delete(fixed_file)
    else
      File.rename(fixed_file, part_file)
      check_file_exists(part_file)
    end

    File.delete(file)
  end
end

main

exit 0
