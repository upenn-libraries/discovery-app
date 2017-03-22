
require 'nokogiri'
require 'sqlite3'

module PennLib

  # Build an index for bound with records and provide a way to merge them in.
  module BoundWithIndex

    class << self

      def create(db_filename, glob)
        db = SQLite3::Database.new(db_filename)

        db.execute 'CREATE TABLE IF NOT EXISTS bound_withs (id varchar(100) PRIMARY KEY, holdings_xml text);'

        # wrap in a single transaction for speediness
        db.execute 'begin'

        Dir.glob(glob).each do |file|
          doc = Nokogiri::XML(File.open(file))
          doc.xpath("/bound_withs/record").each do |record|
            id = record.xpath("id").text
            holdings = record.xpath("holdings").first.to_s
            db.execute "REPLACE INTO bound_withs VALUES ( ?, ? )", [id, holdings]
          end
        end

        db.execute 'end'
        db.close
      end

      def merge(db_filename, input_file, output_file)
        ns_map = { 'marc' => 'http://www.loc.gov/MARC21/slim' }

        db = SQLite3::Database.new(db_filename)
        doc = Nokogiri::XML(File.open(input_file))
        doc.xpath('.//marc:record', ns_map).each do |record|
          record.xpath("./marc:controlfield[@tag='001']", ns_map).each do |element001|
            id = element001.text
            db.execute('select holdings_xml from bound_withs where id = ?', [id]) do |row|
              holdings_doc = Nokogiri::XML(row[0])
              record << '<!-- Holdings copied from boundwith record -->'
              holdings_doc.root.children.each do |holding_datafield|
                record << holding_datafield
              end
            end
          end
        end
        File.write(output_file, doc.to_xml)
      end

    end

  end

end
