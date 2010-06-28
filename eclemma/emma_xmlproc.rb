#! /usr/bin/env ruby

require 'rexml/document'


class EachCoverage
  attr_reader :covered, :total

  def initialize(covered, total)
    @covered = covered.to_i
    @total   = total  .to_i
  end

  def to_s
    pct = total == 0 ? 0 : (100.0 * covered / total).round
    return "#{pct}% (#{covered}/#{total})"
  end
end


class Coverage
  attr_reader :block, :line, :method, :class

  def initialize(xml_coverages)
    xml_coverages.each do |xml_coverage|
      type  = xml_coverage.attributes['type']
      value = xml_coverage.attributes['value']

      type.sub!(/,.*/, '')
      covered = total = 0
      if /[.\d]+\s*%\s*\(\s*([.\d]+)\s*\/\s*([.\d]+)\s*\)\s*/ =~ value
        covered = $1
        total   = $2
      end

      instance_variable_set("@#{type}", EachCoverage.new(covered, total))
    end
  end

  def to_s
    strs = Array.new
    %w(block line method class).each do |type|
      coverage = instance_variable_get("@#{type}")
      strs << "#{type}: #{coverage}"
    end
    return strs.join("\n")
  end
end


class EmmaXmlproc

  ELEMNAME_DATA = '/report/data'

  def initialize(filename)
    File.open(filename) { |fp|
      @xml = REXML::Document.new(fp)
    }
  end

  def parse
    xmls = Array.new
    @xml.elements.each(ELEMNAME_DATA + '/all/coverage') { |element|
      xmls << element
    }
    @totals = Coverage.new(xmls)
  end

  def to_s
    return @totals
  end
end


if __FILE__ == $0
  emma = EmmaXmlproc.new(ARGV[0])
  emma.parse
  puts emma.to_s
end


#[EOF]

