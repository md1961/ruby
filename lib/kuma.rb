
module Kuma

  class StrUtil

    # 引数がすべて、空文字列でない String であるかを評価する
    # args: 可変長引数
    # 返り値: 引数がすべて、空文字列でない String であれば true、
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
    def self.displaying_length(str)
      return 0 unless str
      unless str.kind_of?(String)
        raise ArgumentError.new("Argument must be a String ('#{str.class}' given)")
      end

      return str.length unless $KCODE == UTF8
      return (str.split(//).length + str.length) / 2
    end
  end
end

