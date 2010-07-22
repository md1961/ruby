
require 'win32ole'


class ExcelManipulator

  def initialize
    @excel = WIN32OLE.new('Excel.Application')
  end

  def close_excel
    @excel.Quit
  end

  def open_book(filename, readonly=true)
    abs_filename = get_absolute_path(filename)
    return @excel.Workbooks.open('Filename' => abs_filename, 'ReadOnly' => readonly)
  end

  def self.blank?(value)
    return value.nil? || value == ''
  end

    def get_absolute_path(filename)
      fso = WIN32OLE.new('Scripting.FileSystemObject')
      return fso.GetAbsolutePathName(filename)
    end
    private :get_absolute_path
end
