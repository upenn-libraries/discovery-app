
module PennLib

  module OAI
    class << self

      def delete_ids_in_file(file)
        id_list = parse_ids_to_delete(file)
        if id_list && id_list.size > 0
          puts 'Deleting IDs:'
          puts id_list.join("\n")
          delete(id_list)
        else
          puts 'No IDs found to delete.'
        end
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

        delete_queries = ids.map { |id| "id:#{id}"}

        response = solr.delete_by_query(delete_queries)

        if response['responseHeader']['status'] == 0
          puts "Solr returned success code for deletion(s)."
        else
          puts "ERROR from Solr on deletion: #{response}"
        end

        #solr.commit
      end
    end
  end

end
