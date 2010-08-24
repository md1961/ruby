
#= CUI 上に表を表示するクラス
# 列見出しを表示するか否かはメソッド shows_indexes で指定する（デフォルトは表示）。
# 列見出し自体は set_data() の引数 data の最初の要素として与えるか、あるいは同メソッドの
# 引数 first_is_indexes を false とした場合は、コンストラクタの引数 index_names で与えた
# 列名がそのまま用いられる
#
# 使用例）
#   indexes = %w(id name salary)
#   table_items = [{'id'=>1, 'name'=>'太郎', 'salary'=>1000}, {'id'=>2, 'name'=>'花子', 'salary'=>2000}]
#   table = TableOnCUI.new(indexes, lambda { |x| Kuma::StrUtil.displaying_length(x.to_s) })
#   table.set_data(table_items)
#   puts table.to_table
#
class TableOnCUI

  class NoSuchIndexException     < Exception; end
  class NoDataSpecifiedException < Exception; end

  attr_writer :num_padding, :nil_display

  # 表示文字数を求める、デフォルトの関数
  DEFAULT_FUNC_LENGTH = lambda { |x| x ? x.to_s.length : 0 }

  # 表示項目の左右に置く半角スペースの個数のデフォルト値
  DEFAULT_NUM_PADDING = 1

  # 列見出しを表示するか否かのデフォルト値
  DEFAULT_SHOWS_INDEXES = true

  # nil 値表示のデフォルト値
  DEFAULT_NIL_DISPLAY = "nil"

  # コンストラクタ
  # <em>index_names</em> :: 表示順（左から右）に整列された列名の Array
  # <em>func_length</em> :: 表示文字数を求める、１引数を取り整数値を返すラムダ関数
  def initialize(index_names, func_length=DEFAULT_FUNC_LENGTH)
    @index_names = index_names
    @func_length = func_length

    @map_indexes  = []
    @ary_map_data = []
    @map_max_lengths = {}

    @index_names_to_hide = []

    @num_padding   = DEFAULT_NUM_PADDING
    @shows_indexes = DEFAULT_SHOWS_INDEXES
    @nil_display   = DEFAULT_NIL_DISPLAY
  end

  # 表の表示幅を半角文字単位で返す。
  # メソッド set_data() によりデータを設定する前に呼び出すと NoDataSpecifiedException を投げる
  def width
    return hr.length
  end

  # 列見出しを表示するか否かを設定する
  # <em>value</em> :: 表示とするとは true、非表示とするときは false
  def shows_indexes=(value)
    @shows_indexes = value
    @map_max_lengths = make_map_max_lengths
  end

  # 列を表示とすることを、new 時に渡した列名の列挙で設定する。
  # 引数に :all のみを指定するとすべての列を表示とする
  # <em>index_names</em> :: 列名の列挙。すべての列は :all で指定
  def show(*index_names)
    if index_names == [:all]
      @index_names_to_hide = []
      return
    end

    @index_names_to_hide.uniq
    index_names.each do |index|
      raise NoSuchIndexException.new("No such index as '#{index}'") unless @index_names.include?(index)
      @index_names_to_hide.delete(index)
    end
  end

  # 列を非表示とすることを、new 時に渡した列名の列挙で設定する。
  # 引数に :all のみを指定するとすべての列を非表示とする
  # <em>index_names</em> :: 列名の列挙。すべての列は :all で指定
  def hide(*index_names)
    if index_names == [:all]
      @index_names_to_hide = @index_names.dup
      return
    end

    index_names.each do |index|
      raise NoSuchIndexException.new("No such index as '#{index}'") unless @index_names.include?(index)
      @index_names_to_hide << index
    end
    @index_names_to_hide.uniq
  end

  # 表中に表示される水平線を文字列で返す。
  # メソッド set_data() によりデータを設定する前に呼び出すと NoDataSpecifiedException を投げる
  def hr
    raise NoDataSpecifiedException.new("Must specify data (set_data()) first") if @ary_map_data.empty?
    npad = @num_padding
    hr_items = index_names_to_display.map { |index| '-' * (npad + @map_max_lengths[index] + npad) }
    return "+#{hr_items.join('+')}+"
  end

  # 表に表示するデータを設定する
  # <em>data</em> :: 表示順（上から下）に整列された、列名をキー、表示文字列を値とした Hash の Array
  # <em>first_is_indexes</em> :: 引数 data の最初の要素が列見出しであれは true。デフォルトは false
  def set_data(data, first_is_indexes=false)
    data_given = data.dup
    @map_indexes = first_is_indexes ? data_given.shift \
                                    : Hash.new { |hash, key| hash[key] = key } # return the key as a value
    @ary_map_data = data_given
    @map_max_lengths = make_map_max_lengths
  end

  # 表形式に変換して文字列で返す
  # 返り値 :: 文字列型に変換された表
  def to_table
    hr = self.hr

    strs = Array.new

    strs << hr  # Top border of the table

    is_index = @shows_indexes
    ary_map_whole_table.each do |map_items|
      s = '|'
      index_names_to_display.each do |index|
        is_right_align = false
        item = map_items[index]
        if item.nil?
          item = @nil_display
        elsif item.kind_of?(Fixnum)
          is_right_align = true
          item = item.to_s
        end
        width = @map_max_lengths[index]
        length = @func_length.call(item)
        blanks = ' ' * (width - length)
        item_display = is_right_align ? (blanks + item) : (item + blanks)
        s += ' ' + item_display + ' |'
      end
      strs << s
      strs << hr if is_index
      is_index = false
    end

    strs << hr  # Bottom border of the table

    return strs.join("\n")
  end

  private
    
    def index_names_to_display
      return @index_names - @index_names_to_hide
    end

    # 列見出しを含む全データの Hash の Array を返す
    def ary_map_whole_table(includes_index=@shows_indexes)
      return (includes_index ? [@map_indexes] : []) + @ary_map_data
    end

    def make_map_max_lengths
      map_max_lengths = Hash.new { |h, k| h[k] = 0 }

      ary_map_whole_table.each do |map_items|
        @index_names.each do |index|
          length = @func_length.call(map_items[index])
          map_max_lengths[index] = length if length > map_max_lengths[index]
        end
      end

      return map_max_lengths
    end
end

