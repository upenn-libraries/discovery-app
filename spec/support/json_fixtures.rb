# helpful methods for reading JSON files
module JsonFixtures
  # Return the path to the JSON fixtures directory
  def json_dir
    File.join File.dirname(__FILE__), '../fixtures/json'
  end

  # Return a filename for a JSON fixture
  def json_file(filename)
    File.join json_dir, filename
  end

  # Return the contents of a JSON fixture as a String
  def json_string(filename)
    File.read json_file(filename)
  end
end
