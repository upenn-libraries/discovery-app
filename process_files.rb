#!/usr/bin/env ruby
#
# File processing script using FilePipeline to define steps for
# preprocessing Alma export files, and for indexing into Solr.

load 'file_pipeline.rb'

pipeline = FilePipeline.define do

  option_parser do |parser, options|
    parser.on('-x', '--xsl-dir XSL_DIR', 'Directory where .xsl files are stored') do |v|
      options[:xsl_dir] = File.expand_path(v)
    end
    parser.on('-l', '--log-dir LOG_DIR', 'Directory where log files should be written') do |v|
      options[:log_dir] = File.expand_path(v)
    end
  end

  step :fix_namespace
  desc 'Add MARC21 XML ns to collection element in files'
  run do |stage|
    # this modifies the file in-place
    run_command(%(sed -i 's/<collection>/<collection xmlns=\\"http:\\/\\/www.loc.gov\\/MARC21\\/slim\\">/' #{stage.filename}))
  end

  step :create_bound_withs
  desc 'Create boundwiths_*.xml files'
  run do |stage|
    boundwiths_file = "boundwiths_#{stage.filename.scan(/\d+/)[-1]}.xml"
    run_command(%(JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{stage.filename} -xsl:#{options[:xsl_dir]}/boundwith_holdings.xsl -o:#{boundwiths_file}))
  end

  step :merge_bound_withs
  desc 'Merge holdings from boundwiths_*.xml files into MARC records'
  chdir :script_dir
  run do |stage|
    merged_file = Pathname.new(stage.dir).join("merged_#{stage.filename.scan(/\d+/)[-1]}.xml").to_s
    run_command(%(bundle exec rake pennlib:marc:merge_boundwiths BOUND_WITHS_DB_FILENAME=bound_withs.sqlite3 BOUND_WITHS_INPUT_FILE=#{stage.complete_path} BOUND_WITHS_OUTPUT_FILE=#{merged_file}))
    { output_file: merged_file }
  end

  step :convert_oai_to_marc
  desc 'Convert output from OAI endpoint into standard MARC files'
  run do |stage|
    marc_file = Pathname.new(stage.filename).basename('.xml').to_s + '_marc.xml'
    run_command(%(JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{stage.filename} -xsl:#{options[:xsl_dir]}/oai2marc.xsl -o:#{marc_file}))
    { output_file: marc_file }
  end

  step :fix_marc
  desc 'Fix bad or corrupt values that make MARC readers choke'
  run do |stage|
    fixed_file = Pathname.new(stage.filename).basename('.xml').to_s + '_fixed.xml'
    run_command(%(JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{stage.filename} -xsl:#{options[:xsl_dir]}/fix_alma_prod_marc_records.xsl -o:#{fixed_file}))
    { output_file: fixed_file }
  end

  step :format
  desc 'Run XML through xmllint --format'
  run do |stage|
    formatted_file = Pathname.new(stage.filename).basename('.xml').to_s + '_formatted.xml'
    run_command("xmllint --format #{stage.filename} > #{formatted_file}")
    { output_file: formatted_file }
  end

  step :rename_to_final_filename
  desc 'Rename file to part*.xml'
  run do |stage|
    part_file = "part#{stage.filename.scan(/\d+/)[-1]}.xml"
    File.rename(stage.filename, part_file)
  end

  step :index_into_solr
  desc 'Index into Solr'
  chdir :script_dir
  run do |stage|
    base = Pathname.new(stage.filename).basename('.xml')
    log_filename = Pathname.new(options[:log_dir]).join(base).to_s + '.log'
    run_command("bundle exec rake pennlib:marc:index MARC_FILE=#{stage.complete_path} >> #{log_filename} 2>> #{log_filename}")
  end

  step :delete_from_solr
  desc 'Delete from Solr'
  chdir :script_dir
  run do |stage|
    run_command("bundle exec rake pennlib:oai:delete_ids OAI_FILE=#{stage.complete_path}")
  end

end

pipeline.execute
