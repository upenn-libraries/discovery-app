
require 'date'

namespace :pennlib do
  namespace :marc do

    # This is a wrapper around the "solr:marc:index" task
    # to get around the single file limitation (JRuby has a very long
    # start-up time for each time you spawn a new indexing process
    # per file).
    #
    # With this task, the MARC_FILE env variable can be a glob,
    # such as "/data/*.xml"
    desc 'Index multiple MARC files using Traject'
    task :index  => :environment do |t, args|

      marc_file_original = ENV['MARC_FILE']

      files = Dir.glob(marc_file_original).sort!
      files.each do |file|
        puts "Started indexing #{file} at #{DateTime.now}"
        ENV['MARC_FILE'] = file

        SolrMarc.indexer =
          case ENV['MARC_SOURCE']
            when 'CRL'
              CrlIndexer.new
            when 'HATHI'
              HathiIndexer.new
            when 'DUKE'
              DukeIndexer.new
            when 'CORNELL'
              CornellIndexer.new
            when 'BROWN'
              BrownIndexer.new
            when 'COLUMBIA'
              ColumbiaIndexer.new
            when 'HARVARD'
              HarvardIndexer.new
            when 'STANFORD'
              StanfordIndexer.new
            when 'PRINCETON'
              PrincetonIndexer.new
            when 'CHICAGO'
              ChicagoIndexer.new
            else
              FranklinIndexer.new
          end

        Rake::Task['solr:marc:index:work'].execute
        puts "Finished indexing #{file} at #{DateTime.now}"
      end
    end

    desc 'Index MARC data from stdin using Traject'
    task :index_from_stdin  => :environment do |t, args|
      SolrMarc.indexer =
        case ENV['MARC_SOURCE']
          when 'CRL'
            CrlIndexer.new
          when 'HATHI'
            HathiIndexer.new
          when 'DUKE'
            DukeIndexer.new
          when 'CORNELL'
            CornellIndexer.new
          when 'BROWN'
            BrownIndexer.new
          when 'COLUMBIA'
            ColumbiaIndexer.new
          when 'HARVARD'
            HarvardIndexer.new
          when 'STANFORD'
            StanfordIndexer.new
          when 'PRINCETON'
            PrincetonIndexer.new
          when 'CHICAGO'
            ChicagoIndexer.new
          else
            FranklinIndexer.new
        end

      SolrMarc.indexer.process(STDIN)
    end

    desc 'Index MARC records using Traject, outputting Solr query to file (for debugging)'
    task :index_to_file => :environment do |t, args|

      class MyMarcIndexer < HathiIndexer
        def initialize
          super
          settings do
            store "writer_class_name", "Traject::JsonWriter"
            store 'output_file', "traject_output.json"
          end
        end
      end

      io = Zlib::GzipReader.new(File.open(ENV['MARC_FILE']), :external_encoding => 'UTF-8')
      MyMarcIndexer.new.process(io)
    end

    # this seems braindead but is actually useful: the marc reader will
    # raise an exception if it can't marshal the XML into Record objects
    desc "Just read MARC records and do nothing (for debugging)"
    task :read_marc => :environment do |t, args|
      reader = MARC::XMLReader.new(ENV['MARC_FILE'])
      last_id = nil
      begin
        reader.each do |record|
          record.fields('001').each { |field| last_id = field.value }
        end
      rescue Exception => e
        puts "last record successfully read=#{last_id}"
        raise e
      end
    end

    desc "Dump OCLC IDs from Hathi MARC to stdout (for debugging)"
    task :dump_oclc_ids => :environment do |t, args|
      code_mappings ||= PennLib::CodeMappings.new(Rails.root.join('config').join('translation_maps'))
      pennlibmarc ||= PennLib::Marc.new(code_mappings)

      Dir.glob('/home/jeffchiu/hathi-oai-marc/processed/part*.xml.gz').each do |file|
        io = Zlib::GzipReader.new(File.open(file), :external_encoding => 'UTF-8')
        reader = MARC::XMLReader.new(io)
        reader.each do |record|
          pennlibmarc.get_oclc_id_values(record).each do |oclc_id|
            puts oclc_id
          end
        end
        io.close()
      end
    end

    desc "Create boundwiths index"
    task :create_boundwiths_index => :environment do |t, args|
      PennLib::BoundWithIndex.create(
          ENV['BOUND_WITHS_DB_FILENAME'],
          ENV['BOUND_WITHS_XML_DIR']
      )
    end

    desc "Merge boundwiths into records"
    task :merge_boundwiths => :environment do |t, args|
      input_filename = ENV['BOUND_WITHS_INPUT_FILE']
      output_filename = ENV['BOUND_WITHS_OUTPUT_FILE']
      input = (input_filename && File.exist?(input_filename)) ? PennLib::Util.openfile(input_filename) : STDIN
      output = (output_filename && File.exist?(output_filename)) ? PennLib::Util.openfile(output_filename) : STDOUT
      PennLib::BoundWithIndex.merge(ENV['BOUND_WITHS_DB_FILENAME'], input, output)
    end

  end

  namespace :oai do

    desc 'Parse IDs from OAI file and delete them from Solr index'
    task :delete_ids => :environment do |t, args|
      input_filename = ENV['OAI_FILE']
      input = (input_filename && File.exist?(input_filename)) ? PennLib::Util.openfile(input_filename) : STDIN
      PennLib::OAI.delete_ids_in_file(input, input_filename)
    end

  end

  namespace :alma do

    desc 'Generate CSV for comparing location names in locations.xml vs Alma'
    task :compare_locations => :environment do |t, args|
      PennLib::LibrariesAndLocations.compare_locations
    end

  end

end
