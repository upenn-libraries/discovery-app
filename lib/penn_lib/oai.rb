
module PennLib

  module OAI
    class << self

      def delete_ids_in_file(filepath)
        id_list = parse_ids_to_delete(filepath)
        puts "Deleting IDs=#{id_list}"
        delete(id_list)
      end

      def parse_ids_to_delete(filepath)
        doc = File.open(filepath) { |f| Nokogiri::XML(f) }
        ns_map = { 'oai' => 'http://www.openarchives.org/OAI/2.0/' }
        results = doc.xpath("//oai:ListRecords/oai:record/oai:header[@status='deleted']/oai:identifier", ns_map)
        results.map { |elem| 'FRANKLIN_' + elem.text.split(':')[-1] }
      end

      def delete(ids)
        url = Rails.application.config_for(:blacklight)['url']

        solr = RSolr.connect :url => url, update_format: :xml, read_timeout: 300
        solr.delete_by_id(ids)
        solr.commit
      end
    end
  end

end
