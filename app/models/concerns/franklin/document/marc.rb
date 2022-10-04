module Franklin
  module Document
    module Marc
      include Blacklight::Solr::Document::Marc

      # Finds appropriate publication field. Prioritizes information in the 264 field over
      # information in the 260 field.
      #
      # @return [nil] if no pub field was found
      # @return [Marc::DataField] if pub field was found
      def pub_field(record)
        # Check for 264 field first. If multiple fields, prioritizing based on indicator2 field.
        ['1', '3', '2', '0'].each do |indicator2|
          field = record.find { |f| f.tag == '264' && f.indicator2 == indicator2 }
          return field unless field.nil?
        end

        # If no valid 264 fields present, return 260 field.
        record.find { |f| f.tag == '260' }
      end

      # Overriding Blacklight::Solr::Document::MarcExport.setup_pub_data to use custom logic for pub field.
      def setup_pub_date(record)
        if (pub_field = pub_field(record))
          if (pub_date = pub_field.find { |s| s.code == 'c' })
            date_value = pub_date.value.gsub(/[^0-9|n\.d\.]/, "")[0,4] unless pub_date.value.gsub(/[^0-9|n\.d\.]/, "")[0,4].blank?
          end
          return nil if date_value.nil?
        end
        clean_end_punctuation(date_value) if date_value
      end

      # Overriding Blacklight::Solr::Document::MarcExport.setup_pub_info to use custom logic for pub field.
      def setup_pub_info(record)
        text = ''
        if (pub_info_field = pub_field(record))
          a_pub_info = pub_info_field.find { |s| s.code == 'a' }
          b_pub_info = pub_info_field.find{ |s| s.code == 'b' }
          a_pub_info = clean_end_punctuation(a_pub_info.value.strip) unless a_pub_info.nil?
          b_pub_info = b_pub_info.value.strip unless b_pub_info.nil?
          text += a_pub_info.strip unless a_pub_info.nil?
          if !a_pub_info.nil? and !b_pub_info.nil?
            text += ": "
          end
          text += b_pub_info.strip unless b_pub_info.nil?
        end
        return nil if text.strip.blank?
        clean_end_punctuation(text.strip)
      end

      # Overriding Blacklight::Solr::Document::MarcExport.chicago_citation to use custom logic for pub field.
      def chicago_citation(marc)
        authors = get_all_authors(marc)
        author_text = ""
        unless authors[:primary_authors].blank?
          if authors[:primary_authors].length > 10
            authors[:primary_authors].each_with_index do |author,index|
              if index < 7
                if index == 0
                  author_text << "#{author}"
                  if author.ends_with?(",")
                    author_text << " "
                  else
                    author_text << ", "
                  end
                else
                  author_text << "#{name_reverse(author)}, "
                end
              end
            end
            author_text << " et al."
          elsif authors[:primary_authors].length > 1
            authors[:primary_authors].each_with_index do |author,index|
              if index == 0
                author_text << "#{author}"
                if author.ends_with?(",")
                  author_text << " "
                else
                  author_text << ", "
                end
              elsif index + 1 == authors[:primary_authors].length
                author_text << "and #{name_reverse(author)}."
              else
                author_text << "#{name_reverse(author)}, "
              end
            end
          else
            author_text << authors[:primary_authors].first
          end
        else
          temp_authors = []
          authors[:translators].each do |translator|
            temp_authors << [translator, "trans."]
          end
          authors[:editors].each do |editor|
            temp_authors << [editor, "ed."]
          end
          authors[:compilers].each do |compiler|
            temp_authors << [compiler, "comp."]
          end

          unless temp_authors.blank?
            if temp_authors.length > 10
              temp_authors.each_with_index do |author,index|
                if index < 7
                  author_text << "#{author.first} #{author.last} "
                end
              end
              author_text << " et al."
            elsif temp_authors.length > 1
              temp_authors.each_with_index do |author,index|
                if index == 0
                  author_text << "#{author.first} #{author.last}, "
                elsif index + 1 == temp_authors.length
                  author_text << "and #{name_reverse(author.first)} #{author.last}"
                else
                  author_text << "#{name_reverse(author.first)} #{author.last}, "
                end
              end
            else
              author_text << "#{temp_authors.first.first} #{temp_authors.first.last}"
            end
          end
        end
        title = ""
        additional_title = ""
        section_title = ""
        if marc["245"] and (marc["245"]["a"] or marc["245"]["b"])
          title << citation_title(clean_end_punctuation(marc["245"]["a"]).strip) if marc["245"]["a"]
          title << ": #{citation_title(clean_end_punctuation(marc["245"]["b"]).strip)}" if marc["245"]["b"]
        end
        if marc["245"] and (marc["245"]["n"] or marc["245"]["p"])
          section_title << citation_title(clean_end_punctuation(marc["245"]["n"])) if marc["245"]["n"]
          if marc["245"]["p"]
            section_title << ", <i>#{citation_title(clean_end_punctuation(marc["245"]["p"]))}.</i>"
          elsif marc["245"]["n"]
            section_title << "."
          end
        end

        if !authors[:primary_authors].blank? and (!authors[:translators].blank? or !authors[:editors].blank? or !authors[:compilers].blank?)
          additional_title << "Translated by #{authors[:translators].collect{|name| name_reverse(name)}.join(" and ")}. " unless authors[:translators].blank?
          additional_title << "Edited by #{authors[:editors].collect{|name| name_reverse(name)}.join(" and ")}. " unless authors[:editors].blank?
          additional_title << "Compiled by #{authors[:compilers].collect{|name| name_reverse(name)}.join(" and ")}. " unless authors[:compilers].blank?
        end

        edition = ""
        edition << setup_edition(marc) unless setup_edition(marc).nil?

        pub_info = ""

        if (pub_field = pub_field(marc))
          pub_info << clean_end_punctuation(pub_field["a"]).strip if pub_field["a"]
          pub_info << ": #{clean_end_punctuation(pub_field["b"]).strip}" if pub_field["b"]
          pub_info << ", #{setup_pub_date(marc)}" if pub_field["c"]
        elsif marc["502"] and marc["502"]["a"] # MARC 502 is the Dissertation Note.  This holds the correct pub info for these types of records.
          pub_info << marc["502"]["a"]
        elsif marc["502"] and (marc["502"]["b"] or marc["502"]["c"] or marc["502"]["d"]) #sometimes the dissertation note is encoded in pieces in the $b $c and $d sub fields instead of lumped into the $a
          pub_info << "#{marc["502"]["b"]}, #{marc["502"]["c"]}, #{clean_end_punctuation(marc["502"]["d"])}"
        end

        citation = ""
        citation << "#{author_text} " unless author_text.blank?
        citation << "<i>#{title}.</i> " unless title.blank?
        citation << "#{section_title} " unless section_title.blank?
        citation << "#{additional_title} " unless additional_title.blank?
        citation << "#{edition} " unless edition.blank?
        citation << "#{pub_info}." unless pub_info.blank?
        citation
      end
    end
  end
end