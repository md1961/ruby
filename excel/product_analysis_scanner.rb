#! /usr/bin/ruby

$KCODE = 'sjis'

require 'kconv'
require 'jcode'
require 'yaml'

require 'lib/excel_manipulator'


class IllegalFormatException  < Exception; end
class IllegalStateException   < Exception; end
class InfrastructureException < Exception; end

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

  FILE_PATTERN_TO_PROCESS = '*.xls'

  def scan_all(root_dirname)
    begin
      Dir.glob("#{root_dirname}/**/#{FILE_PATTERN_TO_PROCESS}").each do |filename|
        scan(filename)
      end
    ensure
      close_excel
    end
  end

  HR = '-' * 80

  def out_in_str(sql_only=true)
    strs = Array.new

    unless sql_only
      strs << @completion_data.to_s
      strs << HR
    end
    strs.concat(make_sqls_to_insert_well_and_completion_specs)

    id = 1
    @gas_analysis_datas.each do |gas_data|
      unless sql_only
        strs << HR
        strs << gas_data.to_s
      end
      strs << (sql_only ? "" : HR)
      strs << gas_data.to_sql_to_insert(id, @completion_data.completion_id)
      id += 1
    end

    return strs.join("\n")
  end

    def make_sqls_to_insert_well_and_completion_specs
      sqls = Array.new
      sqls << ProductAnalysisScanner.make_sql_to_insert('well_specs',
                                 'id' => 0, 'well_id' => @completion_data.well_id, 'total_depth' => @completion_data.total_depth)
      sqls << ProductAnalysisScanner.make_sql_to_insert('completion_specs',
                                 'id' => 0, 'completion_id'    => @completion_data.completion_id,
                                 'perforation_interval_top'    => @completion_data.perforation_interval_top,
                                 'perforation_interval_bottom' => @completion_data.perforation_interval_bottom)
      return sqls
    end
    private :make_sqls_to_insert_well_and_completion_specs

  TARGET_SHEETNAME = 'SK-1'

  MIN_ROW = 10
  MAX_ROW = 50

  def scan(filename)
    begin
      book = open_book(filename.tosjis)
      raise "Cannot open '#{filename}'" unless book
      sheet = book.Worksheets.Item(TARGET_SHEETNAME)

      rows = Array.new
      i = 0
      sheet.UsedRange.Rows.each do |row|
        cells = Array.new
        row.Columns.each do |cell|
          value = cell.Value
          value = value.toutf8 if value.kind_of?(String)
          cells << value
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
    rescue => evar
      raise InfrastructureException.new(evar.message + " while processing '#{filename}'")
    ensure
      book.Close if book
    end
  end

    def self.zenkaku2hankaku(str)
      return str.tosjis.tr('０-９ａ-ｚＡ-Ｚ'.tosjis, '0-9a-zA-Z').toutf8
    end

    def self.check_existence_of(expected, actual, where)
      act = actual.tosjis.gsub(/[\s#{'　'.tosjis}]/, '').toutf8
      unless act[0, expected.length] == expected
        raise IllegalFormatException.new("No '#{expected}' found " + where)
      end
    end

  private

    COLUMN_NAMES_OF_WELL_SPECS = [
      :id, :well_id, :total_depth,
    ]

    COLUMN_NAMES_OF_COMPLETION_SPECS = [
      :id, :completion_id, :perforation_interval_top, :perforation_interval_bottom,
    ]

    COLUMN_NAMES_OF_BASE_ANALYSES = [
      :id, :completion_id, :analysis_type, :analysis_id,
      :report_no, :date_sampled, :date_analysed, :date_reported,
      :sample_point, :sample_pressure, :pressure_unit_id, :sample_temperature,
      :production_id,
      :note,
      :created_at, :updated_at,
    ]

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

    COLUMN_NAMES_IN_STRING_TYPE = [
      :analysis_type, :report_no, :sample_point, :note, :status, :created_at, :updated_at
    ]
    COLUMN_NAMES_IN_DATE_TYPE = [
      :date_sampled, :date_analysed, :date_reported, :date_as_of
    ]

    def self.make_sql_to_insert(table_name, hash_attrs)
      column_names = get_column_names(table_name)
      enum_column_names  = column_names.join(', ')
      enum_column_values = column_names.map { |column_name| quote_for_sql(hash_attrs, column_name) }.join(', ')
      return "INSERT INTO #{table_name} (#{enum_column_names}) VALUES (#{enum_column_values});"
    end

    def self.get_column_names(table_name)
      const_name_of_column_names = "column_names_of_#{table_name}".upcase
      begin
        column_names = eval(const_name_of_column_names)
      rescue NameError
        raise IllegalStateException.new("Cannot find constant #{const_name_of_column_names}")
      end
      return column_names.map { |name| name.to_s }
    end

    TRACE_NUMBER = 0.0000999

    def self.quote_for_sql(hash_attrs, column_name)
      value = hash_attrs[column_name]

      if value.nil?
        value = 'null'
      elsif COLUMN_NAMES_IN_DATE_TYPE.include?(column_name.to_sym)
        if value.kind_of?(String)
          value = value.split(' ')[0]
          if /\A(\d+)\/(\d+)\/(\d+)(\D.*)?\z/ =~ value
            value = "#{$1}-#{$2}-#{$3}#{$4}"
          end
        elsif value.kind_of?(Time)
          value = value.strftime('%Y-%m-%d')
        else
          raise IllegalStateException.new("Cannot treat as date '#{value}' (:#{value.class})")
        end
      elsif COLUMN_NAMES_IN_STRING_TYPE.include?(column_name.to_sym)  # Numeric
        value = value.to_s unless value.kind_of?(String)
        value.gsub!(/'/, "\\\\'")
      else  # Numeric
        if value.kind_of?(String) && ! mysql_var_name?(value)
          value = /\Atr\.?\z/ =~ value ? TRACE_NUMBER : 'null'
        end
      end

      format = value.kind_of?(Numeric) \
            || (value.kind_of?(String) && (value == 'null' || mysql_var_name?(value))) ? "%s" : "'%s'"

      return sprintf(format, value)
    end

    def self.mysql_var_name?(value)
      return value.kind_of?(String) && value[0, 1] == '@'
    end

  class CompletionData
    attr_reader :well_name, :date_completed, :reservoir_name, :total_depth, \
                :perforation_interval_top, :perforation_interval_bottom, \
                :completion_id, :well_id, :reservoir_id

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
      unless RE_WELL_NAME =~ @well_name.tosjis
        raise IllegalStateException.new("Well name '#{@well_name}' is in unsupported format (not =~ #{RE_WELL_NAME})")
      end
      @well_name_to_look_up = $&.toutf8
      @reservoir_name_to_look_up = RESERVOIR_NAME_CONVERSION_TABLE[reservoir_name] || reservoir_name

      hash_well      = look_up_db_record(db_master_yaml, 'well'     , 'well_zen'      => @well_name_to_look_up     )
      hash_reservoir = look_up_db_record(db_master_yaml, 'reservoir', 'reservoir_zen' => @reservoir_name_to_look_up)
      raise IllegalStateException.new("No well found to match '#{@well_name_to_look_up}'") unless hash_well
      raise IllegalStateException.new("No reservoir found to match '#{@reservoir_name_to_look_up}'" ) unless hash_reservoir
      @well_id      = hash_well['well_id']
      @reservoir_id = hash_reservoir['reservoir_id']
      hash_completion = look_up_db_record(db_master_yaml, 'completion', 'well_id' => @well_id, 'reservoir_id' => @reservoir_id)
      raise IllegalStateException.new("No completion found to match '#{@well_name_to_look_up}'(id=#{@well_id})" \
                                      + " and '#{@reservoir_name_to_look_up}'(id=#{@reservoir_id})" ) unless hash_completion
      @completion_id = hash_completion['completion_id']
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
      :specific_gravity_calculated, :heat_capacity_calculated_in_kcal, :c3plus_liquified_volume, :note,
      :total_compositions, :heat_capacity_calculated_in_mj,
      :mcp, :wi, :fg, :fz_standard, :fz_normal, :date_reported, :date_analysed, :sample_point, :production_status,
      :pressure_unit_id,
    ]
    MAX_LENGTH_OF_ATTR_NAMES = ATTR_NAMES.map { |name| name.to_s.length }.max

    attr_reader *ATTR_NAMES

    ANALYSIS_TYPE = 'GasAnalysis'

    @@index_leftmost = nil

    def self.instance(row)
      raise IllegalStateException.new("GasAnalysisData.check_index() has not been called") unless @@index_leftmost

      if just_pressure_unit_changing?(row)
        set_unit_pressure(row[@@index_sample_pressure])
        return nil
      else
        return GasAnalysisData.new(row)
      end
    end

      def self.just_pressure_unit_changing?(row)
        first_non_blank_cell = row.find { |cell| ! ExcelManipulator.blank?(cell) }
        cells_to_be_blank = row - [first_non_blank_cell] - row[@@index_sample_pressure, 1]
        return cells_to_be_blank.all? { |cell| ExcelManipulator.blank?(cell) }
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
      hash_attrs['id']            = 0  # auto_increment
      hash_attrs['completion_id'] = completion_id
      hash_attrs['analysis_type'] = ANALYSIS_TYPE
      hash_attrs['analysis_id']   = '@analysis_id'
      hash_attrs['production_id'] = '@production_id'
      hash_attrs['created_at']    = Time.now.strftime('%Y-%m-%d %H:%M:%S')
      hash_attrs['updated_at']    = hash_attrs['created_at']
      hash_attrs['date_as_of']    = @date_sampled
      hash_attrs['status']        = @production_status

      sqls = Array.new
      %w(gas_analyses productions base_analyses).each do |table_name|
        sqls << ProductAnalysisScanner.make_sql_to_insert(table_name, hash_attrs)
        if %w(gas_analyses productions).include?(table_name)
          var_name = table_name == 'gas_analyses' ? '@analysis_id' : '@production_id'
          sqls << "SET #{var_name} = last_insert_id();"
        end
      end

      return sqls.join("\n")
    end

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
      expected = EXPECTED_INDEX[0]
      @@index_leftmost = row.index(expected)
      where = "in index row"
      raise IllegalFormatException.new("No '#{expected}' at first column " + where) if @@index_leftmost.nil?
      actuals = row[@@index_leftmost + 1, EXPECTED_INDEX.length - 1]
      EXPECTED_INDEX[1 .. -1].zip(actuals).each_with_index do |expected_and_actual, i|
        expected, actual = expected_and_actual
        ProductAnalysisScanner.check_existence_of(expected, actual, " at column #{i + 1} #{where}")
      end

      @@index_sample_pressure = row.index('圧力')
      set_unit_pressure(rows_of_two[1][@@index_sample_pressure])
    end

    def self.set_unit_pressure(value)
      @@unit_pressure = value.tosjis.gsub(/[\s()#{'　（）'.tosjis}]/, '').toutf8
      unless MAP_UNIT_IDS.keys.include?(@@unit_pressure.downcase)
        raise IllegalStateException.new("No pressure unit such as '#{@@unit_pressure}'")
      end
    end
  end
end


if __FILE__ == $0
  pas = ProductAnalysisScanner.new
  pas.scan_all('../data/prod_anal/gas')
  #pas.scan_all(%w(excel/gas_ms-29lower.xls))
  puts pas.out_in_str
end


#[EOF]

