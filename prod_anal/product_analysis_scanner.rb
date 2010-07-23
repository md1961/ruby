#! /usr/bin/ruby

# 原油、ガス、水の通常分析結果を保持する Excel ワークブックを読み込んで
# 分析結果データをデータベースに書き込む SQL を出力するスクリプト。
# 引数には Excel ワークブックが保存されている大元のディレクトリを
# 指定する。そのディレクトリ以下（サブディレクトリを含む）に
# 存在する Excel ワークブックすべてが対象となる


$KCODE = 'utf8'

require 'kconv'
require 'jcode'
require 'yaml'

require 'lib/excel_manipulator'


class CommandLineArgumentError < StandardError; end
class NotADirectoryError       < StandardError; end
class IllegalFormatError       < StandardError; end
class IllegalStateError        < StandardError; end
class InfrastructureError      < StandardError; end


class ProductAnalysisScanner < ExcelManipulator

  def initialize(argv)
    super()
    process_argv(argv)
  end

    def process_argv(argv)
      @sql_only                        = true
      @fixes_creation_time_at_midnight = false
      until argv.empty?
        case argv[0]
        when '-d'
          @sql_only = false
        when '-m'
          @fixes_creation_time_at_midnight = true
        else
          break
        end
        argv.shift
      end

      unless argv.size == 1
        raise CommandLineArgumentError.new("Specify a root directory which holds target Excel workbooks")
      end
    end
    private :process_argv

  FILE_PATTERN_TO_PROCESS = '*.xls'

  def scan_all(root_dirname)
    unless File.directory?(root_dirname)
      raise NotADirectoryError.new("'#{root_dirname}' is not a directory")
    end

    begin
      strs = Array.new

      Dir.glob("#{root_dirname}/**/#{FILE_PATTERN_TO_PROCESS}").each do |filename|
        prepare
        scan(filename)
        strs.concat(out_in_strs(@sql_only))
      end

      return strs.join("\n")
    ensure
      close_excel
    end
  end

  def prepare
    @completion_data    = nil
    @is_index_checked   = false
    @analysis_datas = Array.new
  end

  HR = '-' * 80

  def out_in_strs(sql_only=true)
    strs = Array.new

    unless sql_only
      strs << @completion_data.to_s
      strs << HR
    end
    strs.concat(make_sqls_to_insert_well_and_completion_specs)

    id = 1
    @analysis_datas.each do |analysis_data|
      unless sql_only
        strs << HR
        strs << analysis_data.to_s
      end
      strs << (sql_only ? "" : HR)
      strs << analysis_data.to_sql_to_insert(id, @completion_data.completion_id, @fixes_creation_time_at_midnight)
      id += 1
    end

    return strs
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
          rows.clear
        elsif ! @completion_data.nil? and ! @is_index_checked and rows.size == AnalysisData::NUM_ROWS_NEEDED_TO_READ_INDEX
          data_classes = [GasAnalysisData, OilAnalysisData]
          evars = Array.new
          clazz = nil
          data_classes.each do |clazz|
            begin
              clazz.check_index(rows)
              break
            rescue IllegalFormatError => evar
              evars << evar
              next
            end
          end
          if evars.size >= data_classes.size
            msgs = Array.new
            evars.zip(data_classes) do |evar, clazz|
              msgs << "#{evar.message} for #{clazz.name}"
            end
            raise InfrastructureError.new(msgs.join("\n"))
          end
          @analysis_class = clazz
          @is_index_checked = true
          rows.clear
        elsif @is_index_checked and rows.size == 1
          analysis_data = @analysis_class.instance(rows[0])
          @analysis_datas << analysis_data if analysis_data
          rows.clear
        end

        i += 1
        break if i >= MAX_ROW
      end
    rescue => evar
      puts evar.backtrace
      puts "while processing '#{filename}'..."
      raise
    ensure
      close_book(book, :no_save => true)
    end
  end

    def self.zenkaku2hankaku(str)
      return str.gsub(/－/, '-').tr('０-９ａ-ｚＡ-Ｚ', '0-9a-zA-Z')
    end

    def self.check_existence_of(expected, actual, where)
      act = actual.gsub(/[\s　]/, '')
      unless act[0, expected.length] == expected
        raise IllegalFormatError.new("No '#{expected}' found ('#{actual}' instead) " + where)
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

    COLUMN_NAMES_OF_OIL_ANALYSES = [
      :id,
      :density, :api_gravity, :absolute_viscosity, :absolute_viscosity_unit_id,
      :kinematic_viscosity_20degC, :kinematic_viscosity_30degC, :kinematic_viscosity_37_8degC,
      :kinematic_viscosity_50degC, :kinematic_viscosity_unit_id,
      :reflecting_color, :transparent_color, :water_and_mud_content, :initial_distillation_temperature,
      :pct10_distillation_temperature, :pct20_distillation_temperature, :pct30_distillation_temperature,
      :pct40_distillation_temperature, :pct50_distillation_temperature, :pct60_distillation_temperature,
      :pct70_distillation_temperature, :pct80_distillation_temperature, :pct90_distillation_temperature,
      :maximum_temperature, :total_distilled_volume, :residue_volume, :lost_volume,
      :volatile_oil_content, :kerosene_content, :diesel_content, :heavy_oil_content, :flash_point,
      :ambient_temperature, :atmospheric_pressure, :atmospheric_pressure_unit_id,
      :distilled_volume_to_267degC, :sample_volume, :analysis_times,
      :wax_content, :appearance, :uop_coefficient,
    ]

    COLUMN_NAMES_OF_PRODUCTIONS = [
      :id, :completion_id,
      :date_as_of, :gas_rate, :oil_rate, :water_rate, :status,
    ]

    COLUMN_NAMES_IN_STRING_TYPE = [
      # From GasAnalysisData
      :analysis_type, :report_no, :sample_point, :note, :status, :created_at, :updated_at,
      # From OilAnalysisData
      :reflecting_color, :transparent_color, :appearance,
    ]
    COLUMN_NAMES_IN_DATE_TYPE = [
      :date_sampled, :date_analysed, :date_reported, :date_as_of,
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
        raise IllegalStateError.new("Cannot find constant #{const_name_of_column_names}")
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
          raise IllegalStateError.new("Cannot treat as date '#{value}' (:#{value.class}) in COLUMN '#{column_name}'")
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

    DB_MASTER_FILENAME = 'prod_anal/100707-01_well_reservoir_completion.yml'

    RESERVOIR_NAME_CONVERSION_TABLE = {
      '2900mA3' => '2900mA一括',
      'ＧⅢ'     => 'GreenTuff一括',
    }

    MAP_WELL_CROWN_NAMES_WITH_SINGLE_RESERVOIR_ID = {
      'あけぼの'   =>  1,
      '北あけぼの' =>  1,
      '沼ノ端'     =>  1,
      '西沼ノ端'   =>  1,
      '南勇払'     =>  1,
      '吉井'       => 94,
      '安田'       => 94,
      '南安田'     => 94,
      '妙法寺'     => 94,
      '地蔵峠'     => 94,
    }

    NUM_ROWS_NEEDED_TO_INITIALIZE = 3

    def initialize(rows)
      read(rows)
      look_up_db_for_completion_id
    end

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
        row = rows[0]

        first_non_blank_cell = row.find { |cell| ! ExcelManipulator.blank?(cell) }
        @well_name = ProductAnalysisScanner.zenkaku2hankaku(first_non_blank_cell)

        index = CompletionData.index(rows, 0, '\A成功年月日')
        if /成功年月日(\d+\/\d+\/\d+)/ =~ row[index]
          @date_completed = $1
        else
          @date_completed = row[index + 1]
        end
        index = CompletionData.index(rows, 0, '\A層名')
        @reservoir_name = row[index + 1]
        index = CompletionData.index(rows, 0, '\A坑井深度')
        @total_depth    = row[index + 1]
        dummy = CompletionData.index(rows, 0, '\A仕上深度')

        index = CompletionData.index(rows, 1, '\A自')
        @perforation_interval_top    = rows[1][index + 1]

        index = CompletionData.index(rows, 2, '\A至')
        @perforation_interval_bottom = rows[2][index + 1]
      end
      private :read

      def self.index(rows, row_no, str_re_to_look)
        row = rows[row_no]
        cell_found = row.find { |cell| cell && /#{str_re_to_look}/ =~ cell.to_s.gsub(/[\s　]/, '') }
        unless cell_found
          raise IllegalFormatError.new("No cell found to match /#{str_re_to_look}/ in row No.#{row_no + 1}")
        end
        return row.index(cell_found)
      end

      RE_WELL_NAME = /\A(.*)[A-Z]{2,}-\s*\d+/

      def look_up_db_for_completion_id
        db_master_yaml = nil
        open(DB_MASTER_FILENAME, 'r') do |fp|
          db_master_yaml = YAML.load(fp)
        end

        if @well_name.nil? || @reservoir_name.nil?
          raise IllegalStateError.new("Both @well_name and @reservoir_name must be set to non-null")
        end
        unless RE_WELL_NAME =~ @well_name
          
          #TODO: Delete this debug-print
          puts "@well_name = #{@well_name.inspect}(#{@well_name.split(//).map { |c| c[0]}.join(', ')})"

          raise IllegalStateError.new("Well name '#{@well_name}' is in unsupported format (not =~ #{RE_WELL_NAME})")
        end
        @well_name_to_look_up = $&
        well_crown_name       = $1
        @reservoir_name_to_look_up = RESERVOIR_NAME_CONVERSION_TABLE[reservoir_name] || reservoir_name

        hash_well      = look_up_db_record(db_master_yaml, 'well'     , 'well_zen'      => @well_name_to_look_up     )
        hash_reservoir = look_up_db_record(db_master_yaml, 'reservoir', 'reservoir_zen' => @reservoir_name_to_look_up)

        raise IllegalStateError.new("No well found to match '#{@well_name_to_look_up}'") unless hash_well
        @well_id = hash_well['well_id']
        if hash_reservoir
          @reservoir_id = hash_reservoir['reservoir_id']
        else
          if MAP_WELL_CROWN_NAMES_WITH_SINGLE_RESERVOIR_ID.keys.include?(well_crown_name)
            @reservoir_id = MAP_WELL_CROWN_NAMES_WITH_SINGLE_RESERVOIR_ID[well_crown_name]
          else
            raise IllegalStateError.new("No reservoir found to match '#{@reservoir_name_to_look_up}'" )
          end
        end

        hash_completion = look_up_db_record(db_master_yaml, 'completion', 'well_id' => @well_id, 'reservoir_id' => @reservoir_id)
        raise IllegalStateError.new("No completion found to match '#{@well_name_to_look_up}'(id=#{@well_id})" \
                                        + " and '#{@reservoir_name_to_look_up}'(id=#{@reservoir_id})" ) unless hash_completion
        @completion_id = hash_completion['completion_id']
      end
      private :look_up_db_for_completion_id

      def look_up_db_record(db_yaml, table_name, hash_to_look)
        db_yaml[table_name].each do |hash_row|
          found = true
          hash_to_look.each do |column_name, value|
            next if name_equal?(hash_row[column_name], value, table_name)
            found = false
            break
          end
          return hash_row if found
        end
        return nil
      end
      private :look_up_db_record

      def name_equal?(name1, name2, table_name)
        return name_for_comparison(name1, table_name) == name_for_comparison(name2, table_name)
      end
      private :name_equal?

      def name_for_comparison(name, table_name)
        if table_name == 'well'
          return name.sub(/D\z/, '').sub(/(\w) (?=-)/, '\1')
        end
        return name
      end
      private :name_for_comparison
  end

  class AnalysisData

    @@index_leftmost = nil

    def self.instance(row, clazz)
      raise IllegalStateError.new("#{clazz.name}.check_index() has not been called") unless @@index_leftmost

      if just_unit_changing?(row)
        set_units(row)
        return nil
      else
        return clazz.new(row)
      end
    end

      def self.just_unit_changing?(row)
        first_non_blank_cell = row.find { |cell| ! ExcelManipulator.blank?(cell) }
        cells_to_be_blank = row - [first_non_blank_cell]
        @@unit_excel_columns.each do |unit_excel_column|
          cells_to_be_blank -= row[unit_excel_column.index_column, 1]
        end
        return cells_to_be_blank.all? { |cell| ExcelManipulator.blank?(cell) }
      end

    def initialize(row)
      values = row[@@index_leftmost, attr_names.size]
      attr_names.zip(values) do |attr_name, value|
        instance_variable_set("@#{attr_name}", value)
      end

      @@unit_excel_columns.each do |unit_excel_column|
        instance_variable_set("@#{unit_excel_column.instance_variable_name}", unit_excel_column.unit_id)
      end
    end

    def to_sql_to_insert(id, completion_id, fixes_creation_time_at_midnight=false)
      hash_attrs = Hash.new
      attr_names.each do |attr_name|
        hash_attrs[attr_name.to_s] = instance_variable_get("@#{attr_name}")
      end
      hash_attrs['id']            = 0  # auto_increment
      hash_attrs['completion_id'] = completion_id
      hash_attrs['analysis_type'] = analysis_type
      hash_attrs['analysis_id']   = '@analysis_id'
      hash_attrs['production_id'] = '@production_id'
      created_at = Time.now
      created_at = midnight(created_at) if fixes_creation_time_at_midnight
      hash_attrs['created_at']    = created_at.strftime('%Y-%m-%d %H:%M:%S')
      hash_attrs['updated_at']    = hash_attrs['created_at']
      hash_attrs['date_as_of']    = @date_sampled
      hash_attrs['status']        = @production_status

      sqls = Array.new
      [table_name, 'productions', 'base_analyses'].each do |name|
        sqls << ProductAnalysisScanner.make_sql_to_insert(name, hash_attrs)
        if [table_name, 'productions'].include?(name)
          var_name = name == table_name ? '@analysis_id' : '@production_id'
          sqls << "SET #{var_name} = last_insert_id();"
        end
      end

      return sqls.join("\n")
    end

      def midnight(time)
        hour = time.hour
        min  = time.min
        sec  = time.sec
        return time - (hour * 60 + min) * 60 - sec
      end
      private :midnight

    def to_s
      strs = Array.new
      format = "%#{max_length_of_attr_names}s = %s"

      attr_names.each do |attr_name|
        value = instance_variable_get("@#{attr_name}")
        strs << sprintf(format, attr_name, value) + " (#{value.kind_of?(Numeric) ? 'number' : 'non-number'})"
      end

      return strs.join("\n")
    end

    def max_length_of_attr_names
      return attr_names.map { |name| name.to_s.length }.max
    end

    NUM_ROWS_NEEDED_TO_READ_INDEX = 2

    def self.check_index(rows_of_two)
      row = rows_of_two[0]
      expected = expected_index[0]
      @@index_leftmost = row.index(expected)
      where = "in index row"
      raise IllegalFormatError.new("No '#{expected}' at first column " + where) if @@index_leftmost.nil?
      actuals = row[@@index_leftmost + 1, expected_index.length - 1]
      expected_index[1 .. -1].zip(actuals).each_with_index do |expected_and_actual, i|
        expected, actual = expected_and_actual
        actual = "" unless actual
        ProductAnalysisScanner.check_existence_of(expected, actual, " at column #{i + 1} #{where}")
      end

      row_trimmed = row.map { |cell| cell ? cell.gsub(/[\s　.]/, '') : "" }
      @@unit_excel_columns = Array.new
      unit_indexes_offsets_and_unit_id_names.each do |index_name, offset, instance_variable_name|
        @@unit_excel_columns << UnitExcelColumn.new(row_trimmed.index(index_name), offset, instance_variable_name)
      end
      set_units(rows_of_two[1])
    end

    def self.set_units(row)
      @@unit_excel_columns.each do |unit_excel_column|
        unit_excel_column.set_value(row)
      end
    end
  end # of class AnalysisData

  class GasAnalysisData < AnalysisData

    ATTR_NAMES = [
      :date_sampled, :report_no, :gas_rate, :oil_rate, :water_rate, :sample_pressure, :sample_temperature,
      :ch4, :c2h6, :c3h8, :i_c4h10, :n_c4h10, :i_c5h12, :n_c5h12, :c6plus, :co2, :n2,
      :specific_gravity_calculated, :heat_capacity_calculated_in_kcal, :c3plus_liquified_volume, :note,
      :total_compositions, :heat_capacity_calculated_in_mj,
      :mcp, :wi, :fg, :fz_standard, :fz_normal, :date_reported, :date_analysed, :sample_point, :production_status,
      :pressure_unit_id,
    ].freeze

    EXPECTED_INDEX = %w(
      採取年月日 報告番号 ガス量 油量 水量 圧力 温度
      CH4 C2H6 C3H8 i-C4H10 n-C4H10 i-C5H12 n-C5H12 C6+ CO2 N2
      計算比重 計算熱量 C3以上液化量 摘要 組成合計 計算熱量
      M.C.P. ＷＩ(MJ系) Fg Fz Fz 報告日 分析日 採取箇所 産出状況
    ).freeze

    UNIT_INDEXES_OFFSETS_AND_UNIT_ID_NAMES = [
      ['圧力', 0, :pressure_unit_id],
    ].freeze

    attr_reader *ATTR_NAMES

    ANALYSIS_TYPE = 'GasAnalysis'
    TABLE_NAME    = 'gas_analyses'

    def self.instance(row)
      return AnalysisData.instance(row, GasAnalysisData)
    end

    def self.expected_index                         ; return EXPECTED_INDEX                         ; end
    def self.unit_indexes_offsets_and_unit_id_names ; return UNIT_INDEXES_OFFSETS_AND_UNIT_ID_NAMES ; end
    def attr_names    ; return ATTR_NAMES    ; end
    def analysis_type ; return ANALYSIS_TYPE ; end
    def table_name    ; return TABLE_NAME    ; end
  end

  class OilAnalysisData < AnalysisData

    ATTR_NAMES = [
      :date_sampled, :report_no, :gas_rate, :oil_rate, :water_rate, :sample_pressure, :sample_temperature,
      :density, :api_gravity, :kinematic_viscosity_20degC, :absolute_viscosity, :kinematic_viscosity_30degC,
      :reflecting_color, :transparent_color, :water_and_mud_content, :initial_distillation_temperature,
      :pct10_distillation_temperature, :pct20_distillation_temperature, :pct30_distillation_temperature,
      :pct40_distillation_temperature, :pct50_distillation_temperature, :pct60_distillation_temperature,
      :pct70_distillation_temperature, :pct80_distillation_temperature, :pct90_distillation_temperature,
      :maximum_temperature, :total_distilled_volume, :residue_volume, :lost_volume,
      :volatile_oil_content, :kerosene_content, :diesel_content, :heavy_oil_content, :flash_point,
      :ambient_temperature, :atmospheric_pressure, :note,
      :distilled_volume_to_267degC, :sample_volume, :analysis_times, :wax_content,
      :date_reported, :date_analysed, :sample_point, :production_status,
      :appearance, :kinematic_viscosity_37_8degC, :kinematic_viscosity_50degC, :uop_coefficient,
      :pressure_unit_id,
      :absolute_viscosity_unit_id,
      :kinematic_viscosity_unit_id,
      :atmospheric_pressure_unit_id,
    ].freeze

    EXPECTED_INDEX = [
      '採取年月日', '報告番号', 'ガス量', '油量', '水量', '圧力', '温度',
      '密度', 'API度', '粘度', '', '', '色相', '', '水泥分',
      '初留', '10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%', '最高温度',
      '全留出量', '残油量', '減失量', '揮発油分', '灯油分', '軽油分', '重油分', '引火点',
      '室温', '気圧', '摘要', '267.0℃留出量', '試料量', '測定回数',  'ワックス分',
      '報告日', '分析日', '採取箇所', '産出状況', '外観特徴', '粘度', '', 'ＵＰＯ係数',
    ].freeze

    UNIT_INDEXES_OFFSETS_AND_UNIT_ID_NAMES = [
      ['圧力', 0, :pressure_unit_id],
      ['粘度', 0, :kinematic_viscosity_unit_id],
      ['粘度', 1, :absolute_viscosity_unit_id],
      ['気圧', 0, :atmospheric_pressure_unit_id],
    ].freeze

    attr_reader *ATTR_NAMES

    ANALYSIS_TYPE = 'OilAnalysis'
    TABLE_NAME    = 'oil_analyses'

    def self.instance(row)
      return AnalysisData.instance(row, OilAnalysisData)
    end

    def self.expected_index                         ; return EXPECTED_INDEX                         ; end
    def self.unit_indexes_offsets_and_unit_id_names ; return UNIT_INDEXES_OFFSETS_AND_UNIT_ID_NAMES ; end
    def attr_names    ; return ATTR_NAMES    ; end
    def analysis_type ; return ANALYSIS_TYPE ; end
    def table_name    ; return TABLE_NAME    ; end
  end

  class UnitExcelColumn
    attr_reader :index_column, :instance_variable_name, :unit_id

    # The values must be equal to id's in DB TABLE units
    MAP_UNIT_IDS = {
      'ksc'  => 1,
      'mpa'  => 2,
      'mmhg' => 3,
      'hpa'  => 4,
      'cp'   => 5,
      'mpas' => 6,
      'cst'  => 7,
      'mm2s' => 8,
    }

    def initialize(index_column, offset, instance_variable_name)
      @index_column           = index_column + offset
      @instance_variable_name = instance_variable_name.to_s
    end

    def set_value(row)
      unit = row[@index_column]
      unless unit
        raise IllegalStateError.new("Nothing found at index #{@index_column} in row (#{row.inspect})")
      end
      unit = unit.gsub(/[\s\/()\[\]　（）・薑]/, '')  # '・' は '薑' に変換されている
      degC = '℃'
      unit = unit.gsub(/\d+#{degC}/, '')
      @unit_id = MAP_UNIT_IDS[unit.downcase]
      unless @unit_id
        raise IllegalStateError.new("No unit such as '#{unit}'")
      end
    end
  end
end


if __FILE__ == $0
  begin
    pas = ProductAnalysisScanner.new(ARGV)
    puts pas.scan_all(ARGV[0])
  rescue CommandLineArgumentError, NotADirectoryError => e
    $stderr.puts e.message
  end
end


#[EOF]

