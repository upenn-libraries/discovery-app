#!/usr/bin/env ruby
#
# Preprocessing of Alma export files in preparation for indexing into Solr
#
# ./do_preprocess.rb fix_namespace create_bound_withs -i "/home/jeffchiu/marc/alma_prod_sandbox/20170315_full/raw/fulltest*.xml" -p 4
# ./do_preprocess.rb fix_marc format rename_to_final_filename -i "/home/jeffchiu/marc/alma_prod_sandbox/20170315_full/raw/fulltest*.xml" -p 4 -x /home/jeffchiu/blacklight_dev/xsl

load 'pipeline.rb'

pipeline = FilePipeline.define do

  option_parser { |opts, opts_hash|
    opts.on('-x', '--xsl-dir XSL_DIR', 'Directory where .xsl files are stored') do |v|
      opts_hash[:xsl_dir] = v
    end
  }

  step :fix_namespace
  run { |stage|
    # this modifies the file in-place, so we don't delete the input file
    run_command(%Q{sed -i 's/<collection>/<collection xmlns=\\"http:\\/\\/www.loc.gov\\/MARC21\\/slim\\">/' #{stage.filename}})
  }

  step :create_bound_withs
  run { |stage|
    # bound with files are used by later stage of preprocessing; we don't delete the input file
    boundwiths_file = "boundwiths_#{stage.filename.scan(/\d+/)[-1]}.xml"
    run_command(%Q!JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{stage.filename} -xsl:#{options[:xsl_dir]}/boundwith_holdings.xsl -o:#{boundwiths_file}!)
  }

  step :convert_oai_to_marc
  delete_input_file true
  run { |stage|
    marc_file = stage.filename.gsub('.xml', '_marc.xml')
    run_command(%Q!JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{stage.filename} -xsl:#{options[:xsl_dir]}/oai2marc.xsl -o:#{marc_file}!)
    { output_file: marc_file }
  }

  step :fix_marc
  delete_input_file true
  run { |stage|
    fixed_file = Pathname.new(stage.filename).basename('.xml').to_s + '_fixed.xml'
    run_command(%Q!JAVA_OPTS="-Xms3g -Xmx3g" saxon -s:#{stage.filename} -xsl:#{options[:xsl_dir]}/fix_alma_prod_marc_records.xsl -o:#{fixed_file} bound_with_dir=#{stage.dir}!)
    { output_file: fixed_file }
  }

  step :format
  delete_input_file true
  run { |stage|
    formatted_file = Pathname.new(stage.filename).basename('.xml').to_s + '_formatted.xml'
    run_command("xmllint --format #{stage.filename} > #{formatted_file}")
    { output_file: formatted_file }
  }

  step :rename_to_final_filename
  run { |stage|
    part_file = "part#{stage.filename.scan(/\d+/)[-1]}.xml"
    File.rename(stage.filename, part_file)
  }
end

pipeline.execute
