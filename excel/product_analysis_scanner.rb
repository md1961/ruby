#! /usr/bin/ruby


require 'kconv'
require 'lib/excel_manipulator'


class IllegalFormatException < Exception; end

class ProductAnalysisScanner < ExcelManipulator

  def initialize
    super
    @completion_data = nil

  end

  def scan_all(filenames)
    begin
      filenames.each do |filename|
        scan(filename)
      end
    ensure
      close_excel
    end
  end

  def write
    puts "Well Name = " + @completion_data.well_name
  end

  TARGET_SHEETNAME = 'SK-1'

  MIN_ROW = 10
  MAX_ROW = 50

  def scan(filename)
    begin
      book = open_book(filename)
      sheet = book.Worksheets.Item(TARGET_SHEETNAME)

      rows = Array.new
      i = 0
      sheet.UsedRange.Rows.each do |row|
        cells = Array.new
        row.Columns.each do |cell|
          cells << cell.Value
        end
        break if cells.all? { |r| ExcelManipulator.blank?(r) } and i >= MIN_ROW - 1

        #puts cells.join(', ')
        rows << cells
        if @completion_data.nil? and rows.size == CompletionData::NUM_ROWS_NEEDED_TO_INITIALIZE
          @completion_data = CompletionData.new(rows)
        end

        i += 1
        break if i >= MAX_ROW
      end
    ensure
      book.Close
    end
  end

  class CompletionData
    attr_reader :well_name

    NUM_ROWS_NEEDED_TO_INITIALIZE = 3

    def initialize(rows)
      read(rows)
    end

      def read(rows)
        rows_no_blank = Array.new
        rows.each do |row|
          rows_no_blank << row.select { |cell| ! ExcelManipulator.blank?(cell) }
        end

        row = rows_no_blank[0]
        @well_name = row[0]
        unless row[1][0, 10] == '成功年月日'.tosjis
          raise IllegalFormatException.new("No '#{"成功年月日".tosjis}' in first row")
        end

      end
      private :read
  end
end


if __FILE__ == $0
  pas = ProductAnalysisScanner.new
  pas.scan_all(%w(excel/gas_ms-29lower.xls))
  pas.write
end


#[EOF]

