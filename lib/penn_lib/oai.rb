
module PennLib

  module OAI
    class << self

      def delete_ids_in_file(file)
        id_list = parse_ids_to_delete(file)
        puts "Deleting IDs=#{id_list}"
        delete(id_list)
      end

      def parse_ids_to_delete(file)
        doc = Nokogiri::XML(file)
        ns_map = { 'oai' => 'http://www.openarchives.org/OAI/2.0/' }
        results = doc.xpath("//oai:ListRecords/oai:record/oai:header[@status='deleted']/oai:identifier", ns_map)
        results.map { |elem| 'FRANKLIN_' + elem.text.split(':')[-1] }
      end

      def delete(ids)
        url = Rails.application.config_for(:blacklight)['url']
        puts "Solr URL: #{url}"

        solr = RSolr.connect :url => url, update_format: :xml, read_timeout: 300
        response = solr.delete_by_id(ids)

        if response['responseHeader']['status'] == 0
          puts "Solr returned success code for deletion(s)."
        else
          puts "ERROR from Solr on deletion: #{response}"
        end

        solr.commit
      end
    end
  end

end
