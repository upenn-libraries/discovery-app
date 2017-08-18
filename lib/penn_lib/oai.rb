
module PennLib

  module OAI
    class << self

      def delete_ids_in_file(file, filename)
        id_list = parse_ids_to_delete(file)
        if id_list && id_list.size > 0
          puts "Deleting #{id_list.size} IDs from file #{filename}"
          delete(id_list, filename)
        else
          puts "No IDs found to delete in file #{filename}"
        end
      end

      def parse_ids_to_delete(file)
        doc = Nokogiri::XML(file)
        ns_map = { 'oai' => 'http://www.openarchives.org/OAI/2.0/' }
        results = doc.xpath("//oai:ListRecords/oai:record/oai:header/oai:identifier", ns_map)
        results.map { |elem| 'FRANKLIN_' + elem.text.split(':')[-1] }
      end

      def delete(ids, filename)
        url = Rails.application.config_for(:blacklight)['url']
        puts "Solr URL: #{url}"

        solr = RSolr.connect :url => url, update_format: :xml, read_timeout: 300

        delete_queries = ids.map { |id| "id:#{id}"}

        response = solr.delete_by_query(delete_queries)

        if response['responseHeader']['status'] == 0
          puts "Solr returned success code for deletion(s). (file=#{filename}, #{ids.size} ids)"
        else
          puts "ERROR from Solr on deletion: #{response} (file=#{filename}, #{ids.size} ids)"
        end

        #solr.commit
      end
    end
  end

end
