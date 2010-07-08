#! /usr/bin/ruby

$KCODE = 'sjis'

require 'kconv'
require 'jcode'
require 'yaml'

require 'lib/excel_manipulator'


class IllegalFormatException < Exception; end
class IllegalStateException  < Exception; end

class ProductAnalysisScanner < ExcelManipulator

  DB_MASTER_FILENAME = 'excel/100707-01_well_reservoir_completion.yml'

  def initialize
    super

    @completion_data    = nil
    @is_index_checked   = false
    @gas_analysis_datas = Array.new

    open(DB_MASTER_FILENAME, 'r') do |fp|
      @db_master = YAML.load(fp)
    end
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

  HR = '-' * 80

  def out_in_str(outputs_all=false)
    strs = Array.new

    if outputs_all
      strs << @completion_data.to_s
      strs << HR
    end
    strs << "INSERT INTO well_specs; INSERT INTO completion_specs;"

    id = 1
    @gas_analysis_datas.each do |gas_data|
      if outputs_all
        strs << HR
        strs << gas_data.to_s
        strs << HR
      end
      strs << gas_data.to_sql_to_insert(id, @completion_data.completion_id)
      id += 1
    end

    return strs.join("\n")
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
        if cells.all? { |r| ExcelManipulator.blank?(r) }
          break if i >= MIN_ROW - 1
          next
        end

        rows << cells
        if @completion_data.nil? and rows.size == CompletionData::NUM_ROWS_NEEDED_TO_INITIALIZE
          @completion_data = CompletionData.new(rows)
          @completion_data.look_up_db_for_completion_id(@db_master)
          rows.clear
        elsif ! @completion_data.nil? and ! @is_index_checked and rows.size == GasAnalysisData::NUM_ROWS_NEEDED_TO_READ_INDEX
          GasAnalysisData.check_index(rows)
          @is_index_checked = true
          rows.clear
        elsif @is_index_checked and rows.size == 1
          gas_data = GasAnalysisData.instance(rows[0])
          @gas_analysis_datas << gas_data if gas_data
          rows.clear
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
      act = actual.gsub(/\s/, '').gsub(/#{'　'.tosjis}/, '')
      unless act[0, exp.length] == exp
        raise IllegalFormatException.new("No '#{exp}' found " + where)
      end
    end

  class CompletionData
    attr_reader :well_name, :date_completed, :reservoir_name, :total_depth, \
                :perforation_interval_top, :perforation_interval_bottom, \
                :completion_id

    RESERVOIR_NAME_CONVERSION_TABLE = {
      '2900mA3' => '2900mA一括',
    }

    NUM_ROWS_NEEDED_TO_INITIALIZE = 3

    def initialize(rows)
      read(rows)
    end

    RE_WELL_NAME = /\A.*[A-Z]{2,}-\d+/

    def look_up_db_for_completion_id(db_master_yaml)
      if @well_name.nil? || @reservoir_name.nil?
        raise IllegalStateException.new("Both @well_name and @reservoir_name must be set to non-null")
      end
      unless RE_WELL_NAME =~ @well_name
        raise IllegalStateException.new("Well name '#{@well_name}' is in unsupported format (not =~ #{RE_WELL_NAME})")
      end
      @well_name_to_look_up = $&
      @reservoir_name_to_look_up = RESERVOIR_NAME_CONVERSION_TABLE[reservoir_name].tosjis || reservoir_name

      hash_well      = look_up_db_record(db_master_yaml, 'well'     , 'well_zen'      => @well_name_to_look_up     .toutf8)
      hash_reservoir = look_up_db_record(db_master_yaml, 'reservoir', 'reservoir_zen' => @reservoir_name_to_look_up.toutf8)
      raise IllegalStateException.new("No well found to match '#{@well_name_to_look_up}'") unless hash_well
      raise IllegalStateException.new("No reservoir found to match '#{@reservoir_name_to_look_up}'" ) unless hash_reservoir
      hash_completion = look_up_db_record(db_master_yaml, 'completion',
                                            'well_id' => hash_well['well_id'], 'reservoir_id' => hash_reservoir['reservoir_id'])
      raise IllegalStateException.new("No completion found to match '#{@well_name_to_look_up}'(id=#{hash_well['well_id']})" \
                            + " and '#{@reservoir_name_to_look_up}'(id=#{hash_reservoir['reservoir_id']})" ) unless hash_completion
      @completion_id = hash_completion['completion_id'].to_i
    end

      def look_up_db_record(db_yaml, table_name, hash_to_look)
        db_yaml[table_name].each do |hash_row|
          found = true
          hash_to_look.each do |column_name, value|
            next if hash_row[column_name] == value
            found = false
            break
          end
          return hash_row if found
        end
        return nil
      end
      private :look_up_db_record

    def to_s
      strs = Array.new
      strs << "Well Name          = #{@well_name}"
      strs << "Date Completed     = #{@date_completed}"
      strs << "Reservoir Name     = #{@reservoir_name}"
      strs << "Total Depth        = #{@total_depth}"
      strs << "Perforation Top    = #{@perforation_interval_top}"
      strs << "Perforation Bottom = #{@perforation_interval_bottom}"
      strs << "completion_id      = #{@completion_id} (#{@well_name_to_look_up}(#{@reservoir_name_to_look_up}))"
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

  class GasAnalysisData

    # The values must be equal to id's in DB TABLE units
    MAP_UNIT_IDS = {
      'ksc' => 1,
      'mpa' => 2,
    }

    ATTR_NAMES = [
      :date_sampled, :report_no, :gas_rate, :oil_rate, :water_rate, :sample_pressure, :sample_temperature,
      :ch4, :c2h6, :c3h8, :i_c4h10, :n_c4h10, :i_c5h12, :n_c5h12, :c6plus, :co2, :n2,
      :specific_gravity_calculated, :heat_capacity_calculated_in_kcal, :c3plus, :note,
      :total_compositions, :heat_capacity_calculated_in_mj,
      :mcp, :wi, :fg, :fz_standard, :fz_normal, :date_reported, :date_analysed, :sample_point, :production_status,
      :pressure_unit_id,
    ]
    MAX_LENGTH_OF_ATTR_NAMES = ATTR_NAMES.map { |name| name.to_s.length }.max

    attr_reader *ATTR_NAMES

    COLUMN_NAMES_OF_BASE_ANALYSES = [
      :id, :completion_id, :analysis_type, :analysis_id,
      :report_no, :date_sampled, :date_analysed, :date_reported,
      :sample_point, :sample_pressure, :pressure_unit_id, :sample_temperature,
      :production_id,
      :note,
      :created_at, :updated_at,
    ]
    ANALYSIS_TYPE = 'GasAnalysis'

    COLUMN_NAMES_OF_GAS_ANALYSES = [
      :id,
      :ch4, :c2h6, :c3h8, :i_c4h10, :n_c4h10, :i_c5h12, :n_c5h12, :c6plus, :co2, :n2,
      :specific_gravity_calculated, :heat_capacity_calculated_in_kcal, :heat_capacity_calculated_in_mj,
      :c3plus_liquified_volume, :mcp, :wi, :fg, :fz_standard, :fz_normal,
    ]

    COLUMN_NAMES_OF_PRODUCTIONS = [
      :id, :completion_id,
      :date_as_of, :gas_rate, :oil_rate, :water_rate, :status,
    ]

    MAP_COLUMN_NAMES = {
      'base_analyses' => COLUMN_NAMES_OF_BASE_ANALYSES,
      'gas_analyses'  => COLUMN_NAMES_OF_GAS_ANALYSES,
      'productions'   => COLUMN_NAMES_OF_PRODUCTIONS,
    }

    @@index_leftmost = nil

    def self.instance(row)
      raise IllegalStateException.new("GasAnalysisData.check_index() has not been called") unless @@index_leftmost

      if (row - row[@@index_sample_pressure, 1]).all? { |cell| ExcelManipulator.blank?(cell) }
        set_unit_pressure(row[@@index_sample_pressure])
        return nil
      else
        return GasAnalysisData.new(row)
      end
    end

    def initialize(row)
      values = row[@@index_leftmost, ATTR_NAMES.size]
      ATTR_NAMES.zip(values) do |attr_name, value|
        instance_variable_set("@#{attr_name}", value)
      end

      @pressure_unit_id = MAP_UNIT_IDS[@@unit_pressure.downcase]
    end

    def to_sql_to_insert(id, completion_id)
      hash_attrs = Hash.new
      ATTR_NAMES.each do |attr_name|
        hash_attrs[attr_name.to_s] = instance_variable_get("@#{attr_name}")
      end
      hash_attrs['id']            = id
      hash_attrs['completion_id'] = completion_id
      hash_attrs['analysis_type'] = ANALYSIS_TYPE
      hash_attrs['analysis_id']   = id
      hash_attrs['production_id'] = id
      hash_attrs['created_at']    = Time.now
      hash_attrs['updated_at']    = hash_attrs['created_at']
      hash_attrs['date_as_of']    = @date_sampled
      hash_attrs['status']        = @production_status

      sqls = Array.new
      %w(base_analyses gas_analyses productions).each do |table_name|
        sqls << make_sql_to_insert(table_name, hash_attrs)
      end

      return sqls.join("\n")
    end

      def make_sql_to_insert(table_name, hash_attrs)
        column_names = MAP_COLUMN_NAMES[table_name]
        raise IllegalStateException.new("No entry for table name '#{table_name}' in MAP_COLUMN_NAMES") unless column_names
        column_names = column_names.map { |name| name.to_s }
        enum_column_names  = column_names.join(', ')
        enum_column_values = column_names.map { |name| quote_for_sql(hash_attrs[name]) }.join(', ')
        return "INSERT INTO #{table_name} (#{enum_column_names}) VALUES (#{enum_column_values});"
      end
      private :make_sql_to_insert

      def quote_for_sql(value)
        format = value.kind_of?(Numeric) ? "%s" : "'%s'"
        return sprintf(format, value)
      end
      private :quote_for_sql

    def to_s
      strs = Array.new
      format = "%#{MAX_LENGTH_OF_ATTR_NAMES}s = %s"

      ATTR_NAMES.each do |attr_name|
        value = instance_variable_get("@#{attr_name}")
        strs << sprintf(format, attr_name, value) + " (#{value.kind_of?(Numeric) ? 'number' : 'non-number'})"
      end

      return strs.join("\n")
    end

    NUM_ROWS_NEEDED_TO_READ_INDEX = 2

    EXPECTED_INDEX = %w(採取年月日 報告番号 ガス量 油量 水量 圧力 温度
                        CH4 C2H6 C3H8 i-C4H10 n-C4H10 i-C5H12 n-C5H12 C6+ CO2 N2
                        計算比重 計算熱量 C3以上液化量 摘要 組成合計 計算熱量
                        M.C.P. ＷＩ(MJ系) Fg Fz Fz 報告日 分析日 採取箇所 産出状況)

    def self.check_index(rows_of_two)
      row = rows_of_two[0]
      expected = EXPECTED_INDEX[0].tosjis
      @@index_leftmost = row.index(expected)
      where = "in index row"
      raise IllegalFormatException.new("No '#{expected}' at first column " + where) if @@index_leftmost.nil?
      actuals = row[@@index_leftmost + 1, EXPECTED_INDEX.length - 1]
      EXPECTED_INDEX[1 .. -1].zip(actuals).each_with_index do |expected_and_actual, i|
        expected, actual = expected_and_actual
        ProductAnalysisScanner.check_existence_of(expected, actual, " at column #{i + 1} #{where}")
      end

      @@index_sample_pressure = row.index('圧力'.tosjis)
      set_unit_pressure(rows_of_two[1][@@index_sample_pressure])
    end

    def self.set_unit_pressure(value)
      @@unit_pressure = value.gsub(/[#{'\s()' + '　（）'.tosjis}]/, '')
      unless MAP_UNIT_IDS.keys.include?(@@unit_pressure.downcase)
        raise IllegalStateException.new("No pressure unit such as '#{@@unit_pressure}'")
      end
    end
  end
end


if __FILE__ == $0
  pas = ProductAnalysisScanner.new
  pas.scan_all(%w(excel/gas_ms-29lower.xls))
  puts pas.out_in_str
end


#[EOF]

