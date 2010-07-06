
require 'lib/excel_manipulator'


class ProductAnalysisScanner < ExcelManipulator

  def scan_all(filenames)
    begin
      filenames.each do |filename|
        scan(filename)
      end
    ensure
      close_excel
    end
  end

  MIN_ROW = 10
  MAX_ROW = 50

  def scan(filename)
    begin
      book = open_book(filename)
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
end

class CompletionData
end


if __FILE__ == $0
  pas = ProductAnalysisScanner.new
  pas.scan_all(%w(excel/gas_ms-29lower.xls))
end


#[EOF]

