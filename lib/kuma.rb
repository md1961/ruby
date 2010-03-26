
module Kuma

  class StrUtil

    UTF8 = 'UTF8'

    def self.displaying_length(str)
      unless $KCODE == UTF8
        return str.length
      end
      return (str.split(//).length + str.length) / 2
    end
  end
end

