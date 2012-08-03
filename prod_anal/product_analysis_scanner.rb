#! /usr/bin/ruby
# vi: set fileencoding=utf-8 :

# 原油、ガス、水の通常分析結果を保持する Excel ワークブックを読み込んで
# 分析結果データをデータベースに書き込む SQL を出力するスクリプト。
#
# 引数には Excel ワークブックが保存されている大元のディレクトリを指定する。
# そのディレクトリ以下（サブディレクトリを含む）に存在する Excel ワークブック
# すべてが対象となる。
# 結果は標準出力に SQL 文をテキスト形式で出力される


require 'kconv'
require 'nkf'
require 'yaml'
require 'date'
require 'optparse'

require 'lib/excel_manipulator'


class CommandLineArgumentError < StandardError; end
class NotADirectoryError       < StandardError; end
class CannotFindWorksheetError < StandardError; end
class IllegalFormatError       < StandardError; end
class IllegalStateError        < StandardError; end
class InfrastructureError      < StandardError; end


class ProductAnalysisScanner < ExcelManipulator

  COMMENT_ON_SQL = '-- '

  def initialize(argv)
    super()

    process_argv(argv)
    @root_dirname = argv[0].sub(/\/$/, '')
    @out_verbose = make_out_verbose
  end

    def process_argv(argv)
      @sql_only                        = true
      @fixes_creation_time_at_midnight = false
      @verbose                         = false

      @opt_parser = OptionParser.new
      @opt_parser.on("-d", "--data_as_well"           ) { |v| @sql_only                        = false }
      @opt_parser.on("-m", "--fix_created_at_midnight") { |v| @fixes_creation_time_at_midnight = true  }
      @opt_parser.on("-v", "--verbose"                ) { |v| @verbose                         = true  }

      @opt_parser.parse!(argv)

      unless argv.size == 1
        raise CommandLineArgumentError.new("Specify a root directory which holds target Excel workbooks")
      end
    end
    private :process_argv

    def make_out_verbose
      if @verbose
        return $stderr
      end

      null_out = Object.new
      def null_out.puts  ; end
      def null_out.print ; end
      return null_out
    end
    private :make_out_verbose

  FILE_PATTERN_TO_PROCESS = '*.xls'
  TARGET_SHEETNAME        = 'SK-1'

  FORMAT_MSG_NO_FILES = "No files to process in directory '%s'"

  def scan_all
    unless File.directory?(@root_dirname)
      raise NotADirectoryError.new("'#{@root_dirname}' is not a directory")
    end

    begin
      outs = Array.new

      filenames = Dir.glob("#{@root_dirname}/**/#{FILE_PATTERN_TO_PROCESS}")
      return sprintf(FORMAT_MSG_NO_FILES, @root_dirname) if filenames.empty?

      filenames.each do |filename|
        prepare_variables

        @out_verbose.puts "Processing '#{filename}'..." if @verbose

        scan(filename)

        commentary = "#{COMMENT_ON_SQL}#{@sample_data.identity} from #{filename}"
        lines = [commentary]
        lines.concat(out_in_strs(@sql_only))
        outs << lines.join("\n")
      end

      return outs.join("\n\n")
    ensure
      close_excel
    end
  end

  def prepare_variables
    @sample_data  = nil
    @is_index_checked = false
    @analysis_datas   = Array.new
  end

  HR = '-' * 80

  def out_in_strs(sql_only=true)
    strs = Array.new

    unless sql_only
      strs << @sample_data.to_s
      strs << HR
    end
    strs.concat(make_sqls_to_insert_well_and_completion_specs)

    id = 1
    sample_type = @sample_data.sample_type
    sample_id   = @sample_data.sample_id
    @analysis_datas.each do |analysis_data|
      unless sql_only
        strs << HR
        strs << analysis_data.to_s
      end
      strs << (sql_only ? "" : HR)
      strs << analysis_data.to_sql_to_insert(id, sample_type, sample_id, @fixes_creation_time_at_midnight)
      id += 1
    end

    return strs
  end

    def make_sqls_to_insert_well_and_completion_specs
      sqls = Array.new
      if @sample_data.well_id
        sqls << ProductAnalysisScanner.make_sql_to_insert('well_specs',
                                 'id' => 0, 'well_id' => @sample_data.well_id, 'total_depth' => @sample_data.total_depth)
      end
      if @sample_data.completion_id
        sqls << ProductAnalysisScanner.make_sql_to_insert('completion_specs',
                                 'id' => 0,
                                 'completion_id'               => @sample_data.completion_id,
                                 'perforation_interval_top'    => @sample_data.perforation_interval_top,
                                 'perforation_interval_bottom' => @sample_data.perforation_interval_bottom)
      end

      return sqls
    end
    private :make_sqls_to_insert_well_and_completion_specs

  MIN_ROW =  10
  MAX_ROW = 512

  def scan(filename)
    begin
      book = open_book(filename.tosjis)
      raise "Cannot open '#{filename}'" unless book

      sheet = get_target_worksheet(book)

      rows = Array.new
      total_row_count = 0

      @out_verbose.print "  processing row " if @verbose

      sheet.UsedRange.Rows.each do |row|

        @out_verbose.print "#{total_row_count + 1} " if @verbose

        cells = row2cells(row)
        if @sample_data && cells.all? { |r| ExcelManipulator.blank?(r) }
          break if total_row_count >= MIN_ROW - 1
        else
          rows << cells
          process_rows(rows)
        end

        total_row_count += 1
        break if total_row_count >= MAX_ROW
      end
    rescue => evar
      puts evar.backtrace
      row_display = total_row_count.nil? ? "" : "row #{total_row_count + 1} in "
      puts "while processing #{row_display}'#{filename}'..."
      raise
    ensure
      @out_verbose.puts if @verbose

      close_book(book, :no_save => true)
    end
  end

    def get_target_worksheet(book)
      begin
        return book.Worksheets.Item(TARGET_SHEETNAME)
      rescue WIN32OLERuntimeError => evar
        sheet_1 = book.Worksheets(1)
        @out_verbose.puts "  Use leftmost worksheet '#{sheet_1.name}' to retrieve data from" if @verbose
        return sheet_1
      end
    end
    private :get_target_worksheet

    def row2cells(row)
      cells = Array.new
      row.Columns.each do |cell|
        value = cell.Value
        value = value.toutf8 if value.kind_of?(String)
        cells << value
      end
      return cells
    end
    private :row2cells

    def process_rows(rows)
      if @sample_data.nil? and rows.size == SampleData::NUM_ROWS_NEEDED_TO_INITIALIZE
        @sample_data = SampleData.new(rows)
        rows.clear
      elsif ! @sample_data.nil? and ! @is_index_checked and rows.size == AnalysisData::NUM_ROWS_NEEDED_TO_READ_INDEX
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
    end
    private :process_rows

    def self.zenkaku2hankaku(str)
      return nil unless str
      return NKF::nkf('-WwZ0', str)
    end

    def self.check_existence_of(expected, actual, where)
      act = actual.remove_spaces_including_zenkaku
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
      :id, :sample_type, :sample_id, :analysis_type, :analysis_id,
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
      # From BaseAnalysis
      :sample_type, :analysis_type, :report_no, :sample_point, :note, :created_at, :updated_at,
      # From OilAnalysis
      :reflecting_color, :transparent_color, :appearance,
      # From Prodction
      :status,
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

  class SampleData
    attr_reader :sample_type, :sample_name, :date_completed, :reservoir_name, \
                :total_depth, :perforation_interval_top, :perforation_interval_bottom, \
                :completion_id, :well_id, :reservoir_id

    DB_MASTER_FILENAME                          = "prod_anal/100723_marrs_field_well_reservoir_completion.yml"
    FILENAME_OF_RESERVOIR_NAME_CONVERSION_TABLE = "prod_anal/reservoir_name_conversion_table.yml"
    FILENAME_OF_WELL_CROWN_NAMES_OF_FIELD       = "prod_anal/well_crown_names_of_field.yml"

    MAP_FIELD_NAMES_TO_SINGLE_RESERVOIR_ID = {
      '勇払' =>  1,
      '吉井' => 94,
    }

    DB_COMBINED_FLUIDS                          = "prod_anal/combined_fluids.yml"

    NUM_ROWS_NEEDED_TO_INITIALIZE = 3

    @@reservoir_name_conversion_table    = nil
    @@map_well_crown_names_to_field_name = nil

    def initialize(rows)
      read_reservoir_name_conversion_table
      prepare_map_well_crown_names_to_field_name

      is_completion = read(rows)
      look_up_db_for_sample_type(is_completion)
    end
      
      def read_reservoir_name_conversion_table
        return if @@reservoir_name_conversion_table
        open(FILENAME_OF_RESERVOIR_NAME_CONVERSION_TABLE, 'r') do |fp|
          @@reservoir_name_conversion_table = YAML.load(fp)
        end
      end
      private :read_reservoir_name_conversion_table

      def prepare_map_well_crown_names_to_field_name
        return if @@map_well_crown_names_to_field_name
        open(FILENAME_OF_WELL_CROWN_NAMES_OF_FIELD, 'r') do |fp|
          map_well_crown_names_of_field = YAML.load(fp)
          @@map_well_crown_names_to_field_name = Hash.new
          map_well_crown_names_of_field.each do |field_name, crown_names|
            crown_names.each do |crown_name|
              @@map_well_crown_names_to_field_name[crown_name] = field_name
            end
          end
        end
      end
      private :prepare_map_well_crown_names_to_field_name

    def sample_id
      return case sample_type
        when 'Completion'
          completion_id
        when 'Well'
          well_id
        when 'CombinedFluid'
          @combined_fluid_id
        else
          raise IllegalStateError.new("sample_type of '#{sample_type}' not supported")
        end
    end

    def to_s
      strs = Array.new
      strs << "Sample Name        = #{@sample_name}"
      strs << "Date Completed     = #{@date_completed}"
      strs << "Reservoir Name     = #{@reservoir_name}"
      strs << "Total Depth        = #{@total_depth}"
      strs << "Perforation Top    = #{@perforation_interval_top}"
      strs << "Perforation Bottom = #{@perforation_interval_bottom}"
      strs << "completion_id      = #{@completion_id} (#{@well_name_to_look_up}(#{@reservoir_name_to_look_up}))"
      return strs.join("\n")
    end

    def identity
      retval = @sample_name 
      retval += "(#{@reservoir_name})" if @reservoir_name && ! @reservoir_name.empty? 
      return retval
    end

    private

      # Returns whether sample_type is a Completion (true) or not (false)
      def read(rows)
        row = rows[0]

        index_of_first_non_blank = row.index { |cell| ! ExcelManipulator.blank?(cell) }
        @sample_name     = ProductAnalysisScanner.zenkaku2hankaku(row[index_of_first_non_blank]    )
        @sample_name     = @sample_name    .remove_spaces_including_zenkaku if @sample_name
        @sample_name_sub = ProductAnalysisScanner.zenkaku2hankaku(rows[1][index_of_first_non_blank])
        @sample_name_sub = @sample_name_sub.remove_spaces_including_zenkaku if @sample_name_sub

        is_success = read_completion_specs(rows)
        return is_success && ! @reservoir_name.empty?
      end

      # Returns whether successfully read or not
      def read_completion_specs(rows)
        row = rows[0]

        index = SampleData.index(row, /\A\s*成功年月日/)
        return false unless index
        if /\A\s*成功年月日.*(\d+\/\d+\/\d+)/ =~ row[index]
          @date_completed = $1
        else
          @date_completed = row[index + 1]
        end

        index = SampleData.index(row, /\A\s*層名/)
        return false unless index
        if /\A\s*層名[:：](.*[^\s　])[\s　]*\z/ =~ row[index]
          @reservoir_name = $1.to_s
        else
          @reservoir_name = row[index + 1] || ''
          @reservoir_name = Integer(@reservoir_name).to_s if @reservoir_name.kind_of?(Numeric)
          @reservoir_name = @reservoir_name.remove_spaces_including_zenkaku
        end

        index = SampleData.index(row, /\A\s*坑井深度/)
        @total_depth = row[index + 1] if index

        index = SampleData.index(row, /\A\s*仕上深度/)
        if index
          if /\A\s*仕上深度.*([\d.]+).*([\d.]+)/ =~ row[index]
            @perforation_interval_top    = $1
            @perforation_interval_bottom = $2
          else
            row = rows[1]
            index = SampleData.index(row, /\A\s*自/)
            @perforation_interval_top    = row[index + 1] if index

            row = rows[2]
            index = SampleData.index(row, /\A\s*至/)
            @perforation_interval_bottom = row[index + 1] if index
          end
        end

        return true
      end

      def self.index(row, re_to_look)
        cell_found = row.find { |cell| cell && re_to_look =~ cell.to_s.remove_spaces_including_zenkaku }
        return cell_found ? row.index(cell_found) : nil
      end

      RE_WELL_NAME = /\A(.*)[A-Z]{2,}-\s*\d+/

      def look_up_db_for_sample_type(is_completion)
        db_master_yaml = nil
        open(DB_MASTER_FILENAME, 'r') do |fp|
          db_master_yaml = YAML.load(fp)
        end
        
        evars = Array.new
        got_well = look_up_well(db_master_yaml, evars)
        if got_well
          @sample_type = is_completion ? 'Completion' : 'Well'
          if is_completion
            look_up_reservoir_and_completion(db_master_yaml)
          end
        else
          @sample_type = 'CombinedFluid'
          begin
            look_up_combined_fluid
          rescue IllegalStateError => evar
            evars.each do |e|
              $stderr.puts e.message
            end
            raise evar
          end
        end
      end

      def look_up_well(db_master_yaml, evars)
        unless @sample_name
          raise IllegalStateError.new("@sample_name must be set to non-null")
        end
        unless RE_WELL_NAME =~ @sample_name
          evars << IllegalStateError.new("Well name '#{@sample_name}' is in unsupported format (not =~ #{RE_WELL_NAME})")
          return false
        end

        @well_name_to_look_up = $&
        well_crown_name       = $1
        @field_name_to_look_up = @@map_well_crown_names_to_field_name[well_crown_name] || well_crown_name

        hash_field = look_up_db_record(db_master_yaml, 'field', 'field_zen' => @field_name_to_look_up)
        unless hash_field
          evars << IllegalStateError.new("No (oil/gas) field found to match '#{@field_name_to_look_up}'")
          return false
        end
        @field_id   = hash_field['field_id']
        @field_name = hash_field['field_zen']

        hash_well = look_up_db_record(db_master_yaml, 'well', 'well_zen' => @well_name_to_look_up, 'field_id' => @field_id)
        unless hash_well
          evars << IllegalStateError.new("No well found to match '#{@well_name_to_look_up}'")
          return false
        end

        @well_id = hash_well['well_id']
        return true
      end

      def look_up_combined_fluid
        db_yaml = nil
        open(DB_COMBINED_FLUIDS, 'r') do |fp|
          db_yaml = YAML.load(fp)
        end

        sample_names = Array.new
        sample_names << @sample_name
        if @sample_name_sub
          sample_names << @sample_name       + @sample_name_sub
          sample_names << @sample_name + ' ' + @sample_name_sub
        end
        
        hash_record = nil
        sample_names.each do |sample_name|
          hash_record = look_up_db_record(db_yaml, nil, 'name_zen' => sample_name)
          break if hash_record
        end
        unless hash_record
          sample_names_display = sample_names.map { |name| "'#{name}'" }.join(" or ")
          raise IllegalStateError.new("No combined fluid found to match #{sample_names_display}")
        end

        @combined_fluid_id = hash_record['id']
      end

      def look_up_reservoir_and_completion(db_master_yaml)
        unless @reservoir_name
          raise IllegalStateError.new("@reservoir_name must be set to non-null")
        end
        hash_reservoir_name = @@reservoir_name_conversion_table[@field_name] || {}
        reservoir_name_converted = hash_reservoir_name[reservoir_name]
        reservoir_name_converted = reservoir_name_converted[@well_name_to_look_up] if reservoir_name_converted.kind_of?(Hash)
        @reservoir_name_to_look_up = reservoir_name_converted || reservoir_name

        hash_reservoir = look_up_db_record(db_master_yaml, 'reservoir',
                                           'reservoir_zen' => @reservoir_name_to_look_up, 'field_id' => @field_id)
        if hash_reservoir
          @reservoir_id = hash_reservoir['reservoir_id']
        else
          @reservoir_id = MAP_FIELD_NAMES_TO_SINGLE_RESERVOIR_ID[@field_name]
          unless @reservoir_id
            raise IllegalStateError.new(
                    "No reservoir found to match '#{@reservoir_name_to_look_up}'(well '#{@well_name_to_look_up}')" )
          end
        end

        hash_completion = look_up_db_record(db_master_yaml, 'completion', 'well_id' => @well_id, 'reservoir_id' => @reservoir_id)
        raise IllegalStateError.new("No completion found to match '#{@well_name_to_look_up}'(id=#{@well_id})" \
                                        + " and '#{@reservoir_name_to_look_up}'(id=#{@reservoir_id})" ) unless hash_completion
        @completion_id = hash_completion['completion_id']
      end

      def look_up_db_record(db_yaml, table_name, hash_to_look)
        array_of_hash_rows = table_name.nil? ? db_yaml.values : db_yaml[table_name]
        array_of_hash_rows.each do |hash_row|
          found = true
          hash_to_look.each do |column_name, value|
            next if value_equal?(hash_row[column_name], value, table_name)
            found = false
            break
          end
          return hash_row if found
        end
        return nil
      end

      def value_equal?(value1, value2, table_name)
        return value_for_comparison(value1, table_name) == value_for_comparison(value2, table_name)
      end

      def value_for_comparison(value, table_name)
        if table_name == 'well' && value.kind_of?(String)
          return value.sub(/D\z/, '').sub(/(\w) (?=-)/, '\1')
        end
        return value
      end
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

      # Excelシートの該当行がデータではなく、単位の変更情報のみを含んでいるかどうかを判定する。
      # 判定は、self.check_index() で取得した @@unit_excel_columns の各要素 UnitExcelColumn の
      # index_column が示すセルと、一番左端のブランクでないセルを除くセルが、すべてブランクである
      # ときは単位の変更情報のみを含んでいるとする
      def self.just_unit_changing?(row)
        @@unit_excel_columns.each do |unit_excel_column|
          unit_name = row[unit_excel_column.index_column]
          unit_id = UnitExcelColumn.convert_unit_name_to_DB_id(unit_name)
          return false if unit_name && unit_id.nil?
        end

        return true
      end

    def initialize(row)
      values = row[@@index_leftmost, attr_names.size]
      attr_names.zip(values) do |attr_name, value|
        DataValidator.validate(attr_name, value)
        instance_variable_set("@#{attr_name}", value)
      end

      @@unit_excel_columns.each do |unit_excel_column|
        instance_variable_set("@#{unit_excel_column.instance_variable_name}", unit_excel_column.unit_id)
      end
    end

    def to_sql_to_insert(id, sample_type, sample_id, fixes_creation_time_at_midnight=false)
      hash_attrs = Hash.new
      attr_names.each do |attr_name|
        hash_attrs[attr_name.to_s] = instance_variable_get("@#{attr_name}")
      end
      hash_attrs['id']            = 0  # auto_increment
      hash_attrs['sample_type']   = sample_type
      hash_attrs['sample_id']     = sample_id
      hash_attrs['completion_id'] = sample_id  # for TABLE `productions`
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
      raise IllegalFormatError.new("No '#{expected}' in index row") unless @@index_leftmost

      actuals = row[@@index_leftmost + 1, expected_index.length - 1]
      expected_index[1 .. -1].zip(actuals).each_with_index do |expected_and_actual, i|
        expected, actual = expected_and_actual
        actual = "" unless actual
        ProductAnalysisScanner.check_existence_of(expected, actual, " at column #{i + 1} in index row")
      end

      row_trimmed = row.map { |cell| cell ? cell.remove_spaces_including_zenkaku : "" }
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

  class FailedValidationError < StandardError; end

  class DataValidator

    # :allows takes an Array of literal(s) and/or Regexp('s)
    PARAM_DATE       = {:type => :date   , :min => "1900-1-1", :max => "2099-12-31"}
    PARAM_PERCENTAGE = {:type => :numeric, :min => 0         , :max => 100         , :allows => [/\A\s*(Tr\.?|-0-)\s*\z/]}

    PARAMETERS = {
      :date_sampled  => PARAM_DATE,
      :date_analysed => PARAM_DATE,
      :date_reported => PARAM_DATE,
      :ch4     => PARAM_PERCENTAGE,
      :c2h6    => PARAM_PERCENTAGE,
      :c3h8    => PARAM_PERCENTAGE,
      :i_c4h10 => PARAM_PERCENTAGE,
      :n_c4h10 => PARAM_PERCENTAGE,
      :i_c5h12 => PARAM_PERCENTAGE,
      :n_c5h12 => PARAM_PERCENTAGE,
      :c6plus  => PARAM_PERCENTAGE,
      :co2     => PARAM_PERCENTAGE,
      :n2      => PARAM_PERCENTAGE,
      #:total_compositions => PARAM_PERCENTAGE,
    }

    def self.validate(name, value)
      return unless value

      name_symbol = name.kind_of?(Symbol) ? name : name.to_sym
      h_param = PARAMETERS[name_symbol]
      return unless h_param

      case h_param[:type]
      when :date
        begin
          date = Date.parse(value)
        rescue ArgumentError => evar
          raise FailedValidationError.new("Cannot parse '#{value}' as a Date")
        end

        validate_min_max(name, date, Date.parse(h_param[:min]), Date.parse(h_param[:max]))
      when :numeric
        allowed_exceptionally = allowed?(value, h_param[:allows])
        if ! value.kind_of?(Numeric) && ! allowed_exceptionally
          raise FailedValidationError.new("'#{value}' is not numeric")
        end

        validate_min_max(name, value, h_param[:min], h_param[:max]) unless allowed_exceptionally
      end
    end
    
      def self.validate_min_max(name, value, min, max)
        if min && value < min
          raise FailedValidationError.new("'#{name}' must be greater than or equal to '#{min}' ('#{value}' given)")
        end
        if max && value > max
          raise FailedValidationError.new("'#{name}' must be less than or equal to '#{max}' ('#{value}' given)")
        end
      end

      def self.allowed?(value, list_allowed)
        return true if list_allowed.include?(value)

        if value.kind_of?(String)
          list_allowed.select { |item| item.kind_of?(Regexp) }.each do |re|
            return true if re =~ value
          end
        end

        return false
      end
  end

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
      ['圧力', 0, :pressure_unit_id].freeze,
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
      ['圧力', 0, :pressure_unit_id            ].freeze,
      ['粘度', 0, :kinematic_viscosity_unit_id ].freeze,
      ['粘度', 1, :absolute_viscosity_unit_id  ].freeze,
      ['気圧', 0, :atmospheric_pressure_unit_id].freeze,
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

    # Each key/value pair must be equal to name_zen/id of a DB record in TABLE units
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
      unit_name = row[@index_column]
      return unless unit_name

      @unit_id = UnitExcelColumn.convert_unit_name_to_DB_id(unit_name)
      raise IllegalStateError.new("No unit such as '#{unit_name}'") unless @unit_id
    end

    DEG_C = '℃'

    def self.convert_unit_name_to_DB_id(unit_name)
      return nil if unit_name.nil? || unit_name.kind_of?(Numeric)

      name = unit_name.gsub(/\d+#{DEG_C}/, '')  # Remove ' \d+degC' from such as "mPa.s 25degC"
      name = name     .remove_spaces_including_zenkaku
      name = name     .gsub(/[\/()\[\]（）・薑]/, '')  # '・' は '薑' に変換されている

      return MAP_UNIT_IDS[name.downcase]
    end
  end
end


class String
  ZENKAKU_SPACE = '　'

  def remove_spaces_including_zenkaku
    self.gsub(/\s+/, '').gsub(/#{ZENKAKU_SPACE}+/, '')
  end
end


if __FILE__ == $0
  begin
    pas = ProductAnalysisScanner.new(ARGV)
    puts pas.scan_all
  rescue CommandLineArgumentError, NotADirectoryError => e
    $stderr.puts e.message
  end
end


#[EOF]

