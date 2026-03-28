#
# These are a series of monkey-patches designed to make type-unsafe
# equality comparisons (via `==` and `===`) more apparent via warnings, enabled
# by the `-Dtype_safe_equality_check` flag. Typically, you are allowed to compare
# anything to anything in Crystal, which can lead to cases like:
#
# ```
# some_string[idx]? == "j"
# ```
#
# Where everything compiles and runs fine, but this equality always evaluates to false
# as `String#[]?` returns `Char?`. This is a serious footgun with Crystal that I have
# run into a lot while developing, and has lead to several hidden bugs in my code.
#
# This implements a stricter equality, where deprecation warnings are given when
# comparing objects of different types, ignoring unions that only include a type and `Nil`.
#
# For example, this is valid:
#
# ```
# def receive(msg : String?)
#   msg == "hello" || msg == nil
# end
# ```
#
# And this is not:
#
# ```
# def receive(msg : String?)
#   msg == :hello
#     # ^^ warning: This equality is type-unsafe and may always evaluate to false. \
#                   Use `#type_unsafe_equals?` if this is intentional.
# end
# ```
#
# As a fallback, the method `#type_unsafe_equals?(other)` can be used to bypass this restriction.
# Unfortunately, there is not such a fallback for `case` statements at this time, so
# these may give warnings that are more difficult to work around.
#
# This only has an impact on code logic when the flag `-Dtype_safe_equality_check` is enabled, and it's
# recommend to only enable it for checks, not normal compilation.
#
# When using this, it is recommended to ignore all warnings coming from this file, stdlib, and the `lib/` folder.
# Codegen is also not required. On Linux / MacOS in a Makefile, this can be accomplished with the command:
# ```sh
# type_safe_equality_check:
# 	crystal build path/to/main/file.cr \
# 	  -Dtype_safe_equality_check \
# 	  --no-codegen --no-debug \
# 	  --error-on-warnings \
# 	  --exclude-warnings=lib \
# 	  --exclude-warnings=path/to/type_safe_equality.cr \
# 	  --exclude-warnings="$(shell crystal env CRYSTAL_PATH | cut -d':' -f2)"
# ```
#

private macro type_safe_eq
  {% if flag?(:type_safe_equality_check) %}
    def ==(other : self?)
      return false if other.nil?
      self == other
    end

    @[Deprecated("This equality is type-unsafe and may always evaluate to false. Use `#type_unsafe_equals?` if this is intentional.")]
    def ==(other)
      false
    end
  {% end %}

  # NOTE(margret): Small helper method to swallow the deprecation warning,
  # as warnings in this file is ignored by `make type_safe_equality_check`
  def type_unsafe_equals?(other) : Bool
    self == other
  end
end

struct Value
  type_safe_eq
end

struct ReferenceStorage(T)
  type_safe_eq
end

# NOTE(margret): Throws an exception if included about `setup_from_env` missing
# class Log::Metadata
#   type_safe_eq
# end

abstract struct Enum
  type_safe_eq
end

class Array(T)
  type_safe_eq
end

struct StaticArray(T, N)
  type_safe_eq
end

struct Complex
  type_safe_eq
end

class Reference
  type_safe_eq
end

struct Tuple
  type_safe_eq
end

{% if flag?(:type_safe_equality_check) %}
  struct Struct
    def ==(other : self | Nil) : Bool
      if other.is_a?(self)
        \{% for ivar in @type.instance_vars %}
          # NOTE(margret): These could potentially be type-unsafe, but hard to debug
          # them given the warning is added to here instead of the caller of `==`.
          # These are swallowed by ignoring this file (for now)
          return false unless @\{{ivar.id}} == other.@\{{ivar.id}}
        \{% end %}
      end
      !other.nil?
    end

    @[Deprecated("This equality is type-unsafe and may always evaluate to false. Use `#type_unsafe_equals?` if this is intentional.")]
    def ==(other)
      false
    end
  end

  class Object
    def ===(other : self?)
      return false if other.nil?
      self == other
    end

    # NOTE(margret): This doesn't have a `.type_unsafe_equals?` fallback, so disabling for now.
    # Enable to check type-safe equality in `case` statements
    # @[Deprecated("This equality is type-unsafe and may always evaluate to false")]
    # def ===(other)
    #   self == other
    # end
  end

  struct Nil
    def ===(other)
      false
    end

    def ==(other)
      false
    end
  end

  class Regex
    # NOTE(margret): Monkey-patches to allow nillable comparisons,
    # otherwise will fall back on `Object#==(other)`
    def ===(other : String?) : Bool
      return false if other.nil?
      self === other
    end
  end

  class String
    # NOTE(margret): Monkey-patches to allow nillable comparisons,
    # otherwise will fall back on `Object#==(other)`
    def ===(other : String?) : Bool
      return false if other.nil?
      self === other
    end
  end

  # https://github.com/crystal-lang/crystal/pull/8893#issuecomment-2646349090
  class Hash(K, V)
    @[Deprecated("This index is type-unsafe and may always evaluate to false.")]
    def []?(key) : V?
      previous_def
    end

    def []?(key : K?) : V?
      self.[key]?
    end

    @[Deprecated("This index is type-unsafe and may always evaluate to false.")]
    def [](key) : V
      previous_def
    end

    def [](key : K?) : V
      self.[key]
    end

    @[Deprecated("This index is type-unsafe and may always evaluate to false.")]
    def has_key?(key) : Bool
      previous_def
    end

    def has_key?(key : K?) : Bool
      has_key?(key)
    end
  end

  module Enumerable(T)
    @[Deprecated("This method call is type-unsafe and may always evaluate to false.")]
    def count(item) : Int32
      previous_def
    end

    def count(item : T?) : Int32
      count(item)
    end

    @[Deprecated("This method call is type-unsafe and may always evaluate to false.")]
    def includes?(obj) : Bool
      previous_def
    end

    def includes?(obj : T?) : Bool
      includes?(obj)
    end

    @[Deprecated("This method call is type-unsafe and may always evaluate to false.")]
    def index(obj) : Int32?
      previous_def
    end

    def index(obj : T?) : Int32?
      index(obj)
    end

    @[Deprecated("This method call is type-unsafe and may always evaluate to false.")]
    def index!(obj) : Int32
      previous_def
    end

    def index!(obj : T?) : Int32
      index!(obj)
    end
  end
{% end %}
