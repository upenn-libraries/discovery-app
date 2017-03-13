#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'pathname'

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

def parse_options
  options = {
    oai2marc: false,
    chunk_size: nil,
    fix_oai: false,
    fix_marc: false,
    format: false,
    resume: false,
    num_processes: nil
  }
  opt_parser = OptionParser.new do |opts|
    opts.banner = 'Usage: index_preprocess.rb [options] FILE_OR_GLOB_OR_DIR'

    opts.separator ''
    opts.separator 'This utility preprocesses Alma export XML files to prepare them'
    opts.separator 'for indexing. This is basically a simple pipeline that can perform'
    opts.separator 'the following sequence of transformations, in this exact order:'
    opts.separator ''
    opts.separator '- convert from OAI to pure MARC XML'
    opts.separator '- split MARC XML files into smaller ones'
    opts.separator '- fix either MARC XML or OAI XML'
    opts.separator '- format XML'
    opts.separator ''
    opts.separator 'Note that you MUST opt in to EACH step. See options. If you'
    opts.separator 'don\'t specify any options, this program just makes a copy'
    opts.separator 'of the input files.'
    opts.separator ''
    opts.separator 'Globs should be quoted when invoking through a shell.'
    opts.separator ''

    opts.on('-o', '--oai2marc', 'Convert from OAI to MARC XML') do |v|
      options[:oai2marc] = true
    end
    opts.on('-c', '--chunk-size SIZE', 'Split MARC XML records into files of SIZE records') do |v|
      options[:chunk_size] = v.to_i
    end
    opts.on('-a', '--fix-oai', 'Fix OAI XML') do |v|
      options[:fix_oai] = true
    end
    opts.on('-b', '--fix-marc-xml', 'Fix MARC XML') do |v|
      options[:fix_marc] = true
    end
    opts.on('-f', '--format', 'Format XML using xmllint') do |v|
      options[:format] = true
    end
    opts.on('-r', '--resume', 'Resume mode (skip already processed files)') do |v|
      options[:resume] = true
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

def rm_if_not_original(filename, original_filename)
  if filename != original_filename
    File.delete(filename)
  end
end

def final_filename(filename)
  "part#{filename.scan(/\d+/)[-1]}.xml"
end

def options_to_arg_string(options)
  args = []
  if options[:oai2marc]
    args << '--oai2marc'
  end
  if options[:chunk_size]
    args << "--chunk-size #{options[:chunk_size]}"
  end
  if options[:fix_oai]
    args << '--fix-oai'
  end
  if options[:fix_marc]
    args << '--fix-marc'
  end
  if options[:format]
    args << '--format'
  end
  if options[:resume]
    args << '--resume'
  end
  args.join(' ')
end

def main
  argv_original = ARGV.dup

  options, opt_parser = parse_options

  if ARGV.length == 0
    puts opt_parser.help
    exit
  end

  if options[:num_processes]
    paths = args_to_paths(ARGV).map { |p| p.gsub(' ', '\ ') }.join(' ')
    cmd = "ls #{paths} | sort | xargs -P #{options[:num_processes]} --verbose -I FILENAME ./index_preprocess.rb #{options_to_arg_string(options)} FILENAME"
    exec cmd
    exit
  end

  script_dir = File.expand_path(File.dirname(__FILE__))
  xsl_dir = "#{script_dir}/xsl"

  # as the Hash moves through this pipeline, 'file' is always the
  # result of the most recent transformation.

  ARGV.lazy.map { |path|
    {
      original_file: File.basename(File.expand_path(path)),
      file: File.basename(File.expand_path(path)),
      dir: File.dirname(File.expand_path(path))
    }
  }.select { |struct|
    !options[:resume] || !File.exist?(final_filename(struct[:file]))
  }.map { |struct|
    if options[:oai2marc]
      Dir.chdir(struct[:dir])
      marc_file = struct[:file].gsub('.xml', '_marc.xml')
      run(%Q!JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{struct[:file]} -xsl:#{xsl_dir}/oai2marc.xsl -o:#{marc_file}!)
      struct[:file] = marc_file
    end
    struct
  }.flat_map { |struct|
    if !options[:chunk_size].nil?
      Dir.chdir(struct[:dir])
      run("#{script_dir}/split.sh #{struct[:file]} #{options[:chunk_size]}")
      rm_if_not_original(struct[:file], struct[:original_file])
      Dir.glob("#{struct[:file]}_*.xml").map do |path|
        { file: path, original_file: struct[:original_file], dir: struct[:dir] }
      end
    else
      [ struct ]
    end
  }.map { |struct|
    if options[:fix_oai] || options[:fix_marc]
      if options[:fix_oai]
        xsl_file = 'fix_oai_marc_records.xsl'
      else
        xsl_file = 'fix_alma_prod_marc_records.xsl'
      end
      fixed_file = Pathname.new(struct[:file]).basename('.xml').to_s + '_fixed.xml'
      Dir.chdir(struct[:dir])
      run(%Q!JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{struct[:file]} -xsl:#{xsl_dir}/#{xsl_file} -o:#{fixed_file}!)
      check_file_exists(fixed_file)
      rm_if_not_original(struct[:file], struct[:original_file])
      struct[:file] = fixed_file
    end
    struct
  }.map { |struct|
    file = struct[:file]
    part_file = final_filename(struct[:file])
    if options[:format]
      run("xmllint --format #{file} > #{part_file}")
      check_file_exists(part_file)
      rm_if_not_original(file, struct[:original_file])
    else
      Dir.chdir(struct[:dir])
      FileUtils.cp(file, part_file)
      check_file_exists(part_file)
      rm_if_not_original(file, struct[:original_file])
    end
    struct[:file] = part_file
    struct
  }.each { |struct|
    puts "created #{struct[:file]}"
  }

end

main

exit 0
