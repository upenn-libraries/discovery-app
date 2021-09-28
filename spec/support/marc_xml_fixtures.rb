# helpful methods for reading JSON files
module MarcXmlFixtures
  # Return the path to the MARC XML fixtures directory
  def marcxml_dir
    File.join File.dirname(__FILE__), '../fixtures/marcxml'
  end

  # Return a filename for a MARC XML fixture
  def marcxml_file(filename)
    File.join marcxml_dir, filename
  end

  # @param [String] filename
  # @return [MARC::Record, nil]
  def marcxml_record_from(filename)
    MARC::XMLReader.new(marcxml_file(filename)).first
  end
end
