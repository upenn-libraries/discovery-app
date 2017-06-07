
require 'nokogiri'
require 'pathname'
require 'sqlite3'

require 'penn_lib/marc'

module PennLib

  # Build an index for bound with records and provide a way to merge them in.
  module BoundWithIndex
    NS_MARC = 'http://www.loc.gov/MARC21/slim'

    class << self

      # xml_dir = directory containing the boundwiths_*.xml files to index
      def create(db_filename, xml_dir)
        db = SQLite3::Database.new(db_filename)

        db.execute 'CREATE TABLE IF NOT EXISTS bound_withs (id varchar(100), bound_with_id varchar(100), holdings_xml text, PRIMARY KEY (id, bound_with_id));'

        # wrap in a single transaction for speediness
        db.execute 'begin'

        subfield_code = PennLib::EnrichedMarc::SUB_BOUND_WITH_ID

        glob = Pathname.new(xml_dir).join("boundwiths_*.xml.gz").to_s
        Dir.glob(glob).each do |file|
          io = Zlib::GzipReader.new(File.open(file), :external_encoding => 'UTF-8')
          doc = Nokogiri::XML(io)
          doc.xpath("/bound_withs/record").each do |record|
            id = record.xpath("id").text
            boundwith_id = record.xpath("boundwith_id").text
            holdings = record.xpath("holdings").first

            # only add boundwith ID for physical holdings
            holdings.children.select { |datafield| datafield['tag'] == PennLib::EnrichedMarc::TAG_HOLDING }.each do |datafield|
              if datafield.children.find { |sf| sf['code'] == subfield_code }
                puts "WARNING: subfield '#{subfield_code}' found in MARC XML that we're trying to add a subfield #{subfield_code} to! id=#{id} boundwith=#{boundwith_id}"
              end
              datafield << '<!-- added by preprocessing -->'
              datafield << "<subfield code=\"#{subfield_code}\">#{boundwith_id}</subfield>"
            end

            db.execute "REPLACE INTO bound_withs VALUES ( ?, ?, ? )", [id, boundwith_id, holdings.to_s]
          end
        end

        db.execute 'end'
        db.close
      end

      def merge(db_filename, input_file, output_file)
        db = SQLite3::Database.new(db_filename)

        # Ugh, Nokogiri::XML::Reader is slooow...
        reader = Nokogiri::XML::Reader(input_file)

        record = nil

        output_file.write(%Q{<?xml version="1.0" encoding="UTF-8"?><collection xmlns="#{NS_MARC}" xmlns:marc="#{NS_MARC}">})

        reader.each do |node|
          # node is an instance of Nokogiri::XML::Reader

          if node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT &&
            node.namespace_uri == NS_MARC &&
            node.name == 'record'
            record = Nokogiri::XML(node.outer_xml)
          elsif node.node_type == Nokogiri::XML::Reader::TYPE_END_ELEMENT &&
            node.namespace_uri == NS_MARC &&
            node.name == 'record'
            output_file.write(record.root.to_s)
            record = nil
          elsif node.node_type == Nokogiri::XML::Reader::TYPE_ELEMENT &&
            node.namespace_uri == NS_MARC &&
            node.name == 'controlfield' &&
            node.attribute('tag') == '001'

            id = node.inner_xml

            db.execute('select holdings_xml from bound_withs where id = ?', [id]) do |row|
              holdings_doc = Nokogiri::XML(row[0])
              record.root << '<!-- Holdings copied from boundwith record -->'
              holdings_doc.root.children.each do |holding_datafield|
                record.root << holding_datafield
              end
            end
          end

        end

        output_file.write('</collection>')

      end

    end

  end

end
