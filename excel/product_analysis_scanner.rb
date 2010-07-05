
require 'win32ole'


class ProductAnalysisScanner

  def initialize
    @xls = WIN32OLE.new('Excel.Application')
  end

  def scan_all(filenames)
    begin
      filenames.each do |filename|
        scan(filename)
      end
    ensure
      @xls.Quit
    end
  end

  MIN_ROW = 10
  MAX_ROW = 50

  def scan(filename)
    abs_filename = get_absolute_path(filename)
    begin
      book = @xls.Workbooks.open(abs_filename)
      sheet = book.Worksheets.Item('SK-1')
      i = 0
      sheet.UsedRange.Rows.each do |row|
        records = Array.new
        row.Columns.each do |cell|
          records << cell.Value
        end
        break if records.all? { |r| r.nil? or r == '' } and i >= MIN_ROW - 1
        puts records.join(", ")
        i += 1
        break if i >= MAX_ROW
      end
    ensure
      book.Close
    end
  end

    def get_absolute_path(filename)
      fso = WIN32OLE.new('Scripting.FileSystemObject')
      return fso.GetAbsolutePathName(filename)
    end
    private :get_absolute_path
end


if __FILE__ == $0
  pas = ProductAnalysisScanner.new
  pas.scan_all(%w(excel/gas_ms-29lower.xls))
end


#[EOF]

