# Extensions to Crystal::Location
module Ameba::Ext::Location
  # Returns the same location as this location but with the line and/or column number(s) changed
  # to the given value(s).
  def with(line_number = @line_number, column_number = @column_number) : self
    self.class.new(@filename, line_number, column_number)
  end

  # Returns the same location as this location but with the line and/or column number(s) adjusted
  # by the given amount(s).
  def adjust(line_number = 0, column_number = 0) : self
    self.class.new(@filename, @line_number + line_number, @column_number + column_number)
  end

  # Seeks to a given *offset* relative to `self`.
  def seek(offset : self) : self
    if offset.filename.as?(String).presence && @filename != offset.filename
      raise ArgumentError.new <<-MSG
        Mismatching filenames:
          #{@filename}
          #{offset.filename}
        MSG
    end

    if offset.line_number == 1
      self.class.new(@filename, @line_number, @column_number + offset.column_number - 1)
    else
      self.class.new(@filename, @line_number + offset.line_number - 1, offset.column_number)
    end
  end
end

class Crystal::Location
  include Ameba::Ext::Location
end
