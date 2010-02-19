#! /usr/bin/env ruby


# Get an angle b/w short and long arms of a clock
class ClockAngle
  RE_INPUT = /^\s*(\d+):(\d+\.?\d*)\s*$/;

  def parse(str)
    unless RE_INPUT =~ str
      return nil
    end
    hour = Regexp.last_match(1).to_i
    min  = Regexp.last_match(2).to_f
    get_angle_offset(hour, min)
  end

  private

  def get_angle_offset(hour, min)
    angle_short = ShortArm.get_angle(hour, min)
    angle_long  = LongArm .get_angle(min)
    get_smaller_angle_offset(angle_short, angle_long)
  end

  # angle is relative angle in degree from 12 o'clock position

  def get_smaller_angle_offset(angle0, angle1)
    offset = (angle1 - angle0).abs
    offset = 360 - offset if offset > 180
    offset
  end

  class ShortArm
    def self.get_angle(hour, min)
      hour %= 12
      360 / 12 * (hour + min / 60.0)
    end
  end

  class LongArm
    def self.get_angle(min)
      360 / 60 * min
    end
  end
end


if __FILE__ == $0
  ca = ClockAngle.new
  while gets
    input = $_.chomp
    result = ca.parse(input)
    result = '(cannot parse)' if result == nil
    print "#{input} => #{result}\n"
  end
end

#[EOF]
