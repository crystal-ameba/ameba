class Ameba::Config
  # By default config loads `.ameba.yml` file located in a current
  # working directory.
  #
  # If it cannot be found until reaching the root directory, then it will be
  # searched for in the user’s global config locations, which consists of a
  # dotfile or a config file inside the XDG Base Directory specification.
  #
  # - `~/.ameba.yml`
  # - `$XDG_CONFIG_HOME/ameba/config.yml` (expands to `~/.config/ameba/config.yml`
  #   if `$XDG_CONFIG_HOME` is not set)
  #
  # If both files exist, the dotfile will be selected.
  #
  # As an example, if Ameba is invoked from inside `/path/to/project/lib/utils`,
  # then it will use the config as specified inside the first of the following files:
  #
  # - `/path/to/project/lib/utils/.ameba.yml`
  # - `/path/to/project/lib/.ameba.yml`
  # - `/path/to/project/.ameba.yml`
  # - `/path/to/.ameba.yml`
  # - `/path/.ameba.yml`
  # - `/.ameba.yml`
  # - `~/.ameba.yml`
  # - `~/.config/ameba/config.yml`
  module Loader
    extend self

    XDG_CONFIG_HOME = ENV.fetch("XDG_CONFIG_HOME", "~/.config")

    FILENAME      = ".ameba.yml"
    DEFAULT_PATH  = Path[Dir.current] / FILENAME
    DEFAULT_PATHS = {
      Path["~"] / FILENAME,
      Path[XDG_CONFIG_HOME] / "ameba" / "config.yml",
    }

    # Creates a new instance of `Ameba::Config` based on YAML parameters.
    #
    # `Config.load` uses this constructor to instantiate new config by YAML file.
    protected def from_yaml(config : YAML::Any, root = nil)
      config = YAML.parse("{}") if config.raw.nil?
      config.raw.is_a?(Hash) ||
        raise "Invalid config file format"

      instance =
        build_config_from_extends(config, root)

      instance.tap do
        if version = load_string_key(config, "Version")
          instance.version = version
        end
        if formatter = load_string_key(config, "Formatter", "Name")
          instance.formatter = formatter
        end

        # TODO: impl. merge strategy
        instance.globs.concat(
          load_array_section(config, "Globs", DEFAULT_GLOBS.dup)
        )
        # TODO: impl. merge strategy
        instance.excluded.concat(
          load_array_section(config, "Excluded", DEFAULT_EXCLUDED.dup)
        )
        instance.root = root if root
      end
    end

    protected def build_config_from_extends(config, root)
      rule_configs = {} of Rule::Base.class => YAML::Any
      version = formatter = nil

      globs = Set(String).new
      excluded = Set(String).new

      base = root || Dir.current

      # FIXME: figure out a good property name
      extends = load_array_section(config, "inherit_from")
      extends.each do |inherit_from|
        inherit_from =
          Path[inherit_from].expand(base, home: true)

        yaml =
          YAML.parse(Config.read_config(path: inherit_from))

        scan_rule_configs(yaml, rule_configs)

        inherited =
          Config.from_yaml(yaml, root)

        version = inherited.version || version
        formatter = inherited.@formatter || formatter

        # TODO: impl. merge strategy
        globs.concat(inherited.globs)
        excluded.concat(inherited.excluded)
      end

      scan_rule_configs(config, rule_configs)

      rules =
        rules_from_configs(rule_configs)

      new(
        rules: rules,
        version: version,
        formatter: formatter,
        globs: globs,
        excluded: excluded,
      )
    end

    protected def scan_rule_configs(config, rule_configs)
      Rule.rules.each_with_object(rule_configs) do |rule, configs|
        if rule_config = config[rule.rule_name]?
          # TODO: impl. merge strategy
          configs[rule] = rule_config
        end
      end
    end

    protected def rules_from_configs(rule_configs)
      Rule.rules.map do |rule|
        yaml =
          rule_configs[rule]?.try(&.to_yaml) || "{}"

        rule.from_yaml(yaml).as(Rule::Base)
      end
    end

    # Loads YAML configuration file by `path`.
    #
    # ```
    # config = Ameba::Config.load
    # ```
    def load(path : Path | String? = nil, root : Path? = nil, skip_reading_config : Bool = false)
      unless skip_reading_config
        content = begin
          if path
            read_config(path: path)
          else
            read_config(root: root)
          end
        end
      end
      content ||= "{}"

      from_yaml YAML.parse(content), root
    rescue ex
      raise "Unable to load config file: #{ex.message}"
    end

    protected def read_config(*, path : Path | String)
      unless File.exists?(path)
        raise "Config file #{path.to_s.inspect} does not exist"
      end
      File.read(path)
    end

    protected def read_config(*, root : Path?)
      path = root ? root / FILENAME : DEFAULT_PATH

      if config_path = find_config_path(path)
        return File.read(config_path)
      end
    end

    protected def find_config_path(path : Path)
      path.parents.reverse_each do |search_path|
        config_path =
          search_path / FILENAME
        return config_path if File.exists?(config_path)
      end

      DEFAULT_PATHS.each do |default_path|
        return default_path if File.exists?(default_path)
      end
    end

    private def load_string_key(config, *path)
      config.dig?(*path).try(&.as_s).presence
    end

    private def load_array_section(config, section_name, default = [] of String)
      case value = config[section_name]?
      when .nil?  then default
      when .as_s? then [value.as_s]
      when .as_a? then value.as_a.map(&.as_s)
      else
        raise "Incorrect `#{section_name}` section in a config files"
      end
    end
  end
end
