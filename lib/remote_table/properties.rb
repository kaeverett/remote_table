require 'uri'
class RemoteTable
  # Represents the properties of a RemoteTable, whether they are explicitly set by the user or inferred automatically.
  class Properties
    attr_reader :t
    attr_reader :current_options
    
    def initialize(t)
      @t = t
      @current_options = t.options.symbolize_keys
    end
    
    def update(options)
      current_options.update options
    end
        
    # The parsed URI of the file to get.
    def uri
      return @uri if @uri.is_a?(::URI)
      @uri = ::URI.parse t.url
      if @uri.host == 'spreadsheets.google.com' or @uri.host == 'docs.google.com'
        @uri.query = 'output=csv&' + @uri.query.sub(/\&?output=.*?(\&|\z)/, '\1')
      end
      @uri
    end
    
    # Whether to stream the rows without caching them. Saves memory, but you have to re-download the file every time you...
    # * call []
    # * call each
    # Defaults to false.
    def streaming
      current_options[:streaming] || false
    end

    # Defaults to true.
    def warn_on_multiple_downloads
      current_options[:warn_on_multiple_downloads] != false
    end
    
    # The headers specified by the user
    #
    # Default: :first_row
    def headers
      current_options[:headers].nil? ? :first_row : current_options[:headers]
    end
    
    def use_first_row_as_header?
      headers == :first_row
    end
    
    def output_class
      headers == false ? ::Array : ::ActiveSupport::OrderedHash
    end
    
    # The sheet specified by the user as a number or a string
    #
    # Default: 0
    def sheet
      current_options[:sheet] || 0
    end
    
    # Whether to keep blank rows
    #
    # Default: false
    def keep_blank_rows
      current_options[:keep_blank_rows] || false
    end
    
    # Form data to send in with the download request
    def form_data
      current_options[:form_data]
    end
    
    # How many rows to skip
    #
    # Default: 0
    def skip
      current_options[:skip] || 0
    end
    
    def internal_encoding
      (current_options[:encoding] || 'UTF-8').upcase
    end
    
    def external_encoding
      'UTF-8'
    end
    
    def external_encoding_iconv
      'UTF-8//TRANSLIT'
    end
    
    # The delimiter
    #
    # Default: ","
    def delimiter
      current_options[:delimiter] || ','
    end
    
    # The XPath used to find rows
    def row_xpath
      current_options[:row_xpath]
    end
    
    # The XPath used to find columns
    def column_xpath
      current_options[:column_xpath]
    end

    # The CSS selector used to find rows
    def row_css
      current_options[:row_css]
    end
    
    # The CSS selector used to find columns
    def column_css
      current_options[:column_css]
    end
    
    # The compression type.
    #
    # Default: guessed from URI.
    #
    # Can be specified as: :gz, :zip, :bz2, :exe (treated as :zip)
    def compression
      if current_options.has_key?(:compression)
        return current_options[:compression]
      end
      case ::File.extname(uri.path).downcase
      when /gz/, /gunzip/
        :gz
      when /zip/
        :zip
      when /bz2/, /bunzip2/
        :bz2
      when /exe/
        :exe
      end
    end
    
    # The packing type.
    #
    # Default: guessed from URI.
    #
    # Can be specified as: :tar
    def packing
      if current_options.has_key?(:packing)
        return current_options[:packing]
      end
      if uri.path =~ %r{\.tar(?:\.|$)}i
        :tar
      end
    end
    
    # The glob used to pick a file out of an archive.
    #
    # Example:
    #     RemoteTable.new 'http://www.fueleconomy.gov/FEG/epadata/08data.zip', :glob => '/*.csv'
    def glob
      current_options[:glob]
    end
    
    # The filename, which can be used to pick a file out of an archive.
    #
    # Example:
    #     RemoteTable.new 'http://www.fueleconomy.gov/FEG/epadata/08data.zip', :filename => '2008_FE_guide_ALL_rel_dates_-no sales-for DOE-5-1-08.csv'
    def filename
      current_options[:filename]
    end
    
    # Cut columns up to this character
    def cut
      current_options[:cut]
    end
    
    # Crop rows after this line
    def crop
      current_options[:crop]
    end
    
    # The fixed-width schema, given as an array
    #
    # Example:
    #     RemoteTable.new('http://cloud.github.com/downloads/seamusabshere/remote_table/test2.fixed_width.txt',
    #                      :format => :fixed_width,
    #                      :skip => 1,
    #                      :schema => [[ 'header4', 10, { :type => :string }  ],
    #                                  [  'spacer',  1 ],
    #                                  [  'header5', 10, { :type => :string } ],
    #                                  [  'spacer',  12 ],
    #                                  [  'header6', 10, { :type => :string } ]])
    def schema
      current_options[:schema]
    end
    
    # The name of the fixed-width schema according to FixedWidth
    def schema_name
      current_options[:schema_name]
    end
    
    # A proc to call to decide whether to return a row.
    def select
      current_options[:select]
    end
    
    # A proc to call to decide whether to return a row.
    def reject
      current_options[:reject]
    end
    
    # A hash of options to create a new Errata instance (see the Errata gem at http://github.com/seamusabshere/errata) to be used on every row.
    def errata
      return unless current_options.has_key? :errata
      @errata ||= if current_options[:errata].is_a? ::Hash
        ::Errata.new current_options[:errata]
      else
        current_options[:errata]
      end
    end
    
    # Get the format in the form of RemoteTable::Format::Excel, etc.
    #
    # Note: treats all spreadsheets.google.com URLs as Format::Delimited (i.e., CSV)
    #
    # Default: guessed from file extension (which is usually the same as the URI, but sometimes not if you pick out a specific file from an archive)
    #
    # Can be specified as: :xlsx, :xls, :delimited (aka :csv and :tsv), :ods, :fixed_width, :html
    def format
      return Format::Delimited if uri.host == 'spreadsheets.google.com' or @uri.host == 'docs.google.com'
      clue = if current_options.has_key?(:format)
        current_options[:format]
      else
        t.local_file.path
      end
      case clue.to_s.downcase
      when /xlsx/, /excelx/
        Format::Excelx
      when /xls/, /excel/
        Format::Excel
      when /csv/, /tsv/, /delimited/
        Format::Delimited
      when /ods/, /open_?office/
        Format::OpenOffice
      when /fixed_?width/
        Format::FixedWidth
      when /htm/
        Format::HTML
      when /xml/
        Format::XML
      else
        Format::Delimited
      end
    end
  end
end
