# vi: set fileencoding=utf-8 :

module Kuma

  class StrUtil

    # 引数がすべて、空文字列でない String であるかを評価する
    # <em>args</em> :: 対象のオブジェクトを列挙した可変長引数
    # 返り値 :: 引数がすべて、空文字列でない String であれば true、
    # 引数の１つにでも、空文字列でない String でないものがあれば false
    def self.non_empty_string?(*args)
      args.each do |x|
        return false if ! x.kind_of?(String) || x.nil? || x.empty?
      end
      return true
    end

    UTF8 = 'UTF8'

    # 表示スクリーン上での（半角）文字数を返す。
    # 引数が nil のときはゼロを返す。
    # 引数が nil でも String でもないときは ArgumentError を投げる。
    # （全角文字が３バイトである UTF-8 にも対応したもの）
    # <em>x</em> :: 対象のオブジェクト
    # 返り値 :: 表示文字数の整数値
    def self.displaying_length(x)
      return 0 unless x
      str = x.to_s

      case str.encoding
      when Encoding::Shift_JIS, Encoding::EUC_JP
        return str.bytesize
      when Encoding::UTF_8
        return (str.length + str.bytesize) / 2
      end

      return str.length
    end
  end


  class ArrayUtil

    # Array を同サイズの Array に非破壊的に分割し、１つの Array に入れて返す
    # <em>array</em> :: 分割する Array
    # <em>size</em> :: 分割後の各々の Array の要素数
    # 返り値 :: 分割した二次元の Array
    def self.split(array, size)
      retArray = Array.new
      0.step(array.size - 1, size) do |index|
        retArray << array[index, size]
      end
      return retArray
    end
  end
end

