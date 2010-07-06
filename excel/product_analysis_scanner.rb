#! /usr/bin/ruby

$KCODE = 'sjis'

require 'kconv'
require 'jcode'

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

  def to_s
    return @completion_data.to_s
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

    def self.zenkaku2hankaku(str)
      return str.tr('０-９ａ-ｚＡ-Ｚ'.tosjis, '0-9a-zA-Z')
    end

    def self.check_existence_of(expected, actual, where)
      exp = expected.tosjis
      unless actual.gsub(/\s/, '')[0, exp.length] == exp
        raise IllegalFormatException.new("No '#{exp}' found " + where)
      end
    end

  class CompletionData
    attr_reader :well_name, :date_completed, :reservoir_name, :total_depth, \
                :perforation_interval_top, :perforation_interval_bottom

    NUM_ROWS_NEEDED_TO_INITIALIZE = 3

    def initialize(rows)
      read(rows)
    end

    def to_s
      strs = Array.new
      strs << "Well Name          = #{@well_name}"
      strs << "Date Completed     = #{@date_completed}"
      strs << "Reservoir Name     = #{@reservoir_name}"
      strs << "Total Depth        = #{@total_depth}"
      strs << "Perforation Top    = #{@perforation_interval_top}"
      strs << "Perforation Bottom = #{@perforation_interval_bottom}"
      return strs.join("\n")
    end

      def read(rows)
        rows_no_blank = Array.new
        rows.each do |row|
          rows_no_blank << row.select { |cell| ! ExcelManipulator.blank?(cell) }
        end

        row = rows_no_blank[0]
        @well_name = ProductAnalysisScanner.zenkaku2hankaku(row[0])
        ProductAnalysisScanner.check_existence_of('成功年月日', row[1], "in first row")
        @date_completed = row[2]
        ProductAnalysisScanner.check_existence_of('層名'      , row[3], "in first row")
        @reservoir_name = row[4]
        ProductAnalysisScanner.check_existence_of('坑井深度'  , row[5], "in first row")
        @total_depth    = row[6]
        ProductAnalysisScanner.check_existence_of('仕上深度'  , row[7], "in first row")

        row = rows_no_blank[1]
        ProductAnalysisScanner.check_existence_of('自', row[0], "in second row")
        @perforation_interval_top    = row[1]

        row = rows_no_blank[2]
        ProductAnalysisScanner.check_existence_of('至', row[0], "in third row")
        @perforation_interval_bottom = row[1]

      end
      private :read
  end
end


if __FILE__ == $0
  pas = ProductAnalysisScanner.new
  pas.scan_all(%w(excel/gas_ms-29lower.xls))
  puts pas
end


#[EOF]

