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

  # Return the contents of a MARC XML fixture as a String
  def marcxml_string(filename)
    File.read marcxml_file(filename)
  end
end
