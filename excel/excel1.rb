
require 'win32ole'


def get_absolute_path(filename)
  fso = WIN32OLE.new('Scripting.FileSystemObject')
  return fso.GetAbsolutePathName(filename)
end

filename = get_absolute_path("excel/gas_ms-29lower.xls")

xls = WIN32OLE.new('Excel.Application')

book = xls.Workbooks.open(filename)

MIN_ROW = 10
MAX_ROW = 50

begin
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
  xls.Quit
end

