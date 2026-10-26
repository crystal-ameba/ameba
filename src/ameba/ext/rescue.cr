# Extensions to `Crystal::Rescue`
module Ameba::Ext::Rescue
  # Returns the location of the variable name in case of a named `rescue`
  # (i.e. `ex` in `rescue ex`), or `nil` otherwise.
  def name_location : Crystal::Location?
    return unless name

    location.try(&.adjust(column_number: {{ "rescue ".size }}))
  end

  # Returns the end location of the `rescue` clause header, being the end
  # of the exception types (`rescue ex : Exception`), the variable name
  # (`rescue ex`), or the keyword itself (`rescue`), instead of the end of
  # the clause body.
  def end_location : Crystal::Location?
    if type = types.try(&.last?)
      return type.end_location
    end

    return unless location = self.location

    if name = self.name
      name_location.try(&.adjust(column_number: name.size - 1))
    else
      location.adjust(column_number: {{ "rescue".size - 1 }})
    end
  end
end

class Crystal::Rescue
  include Ameba::Ext::Rescue
end
