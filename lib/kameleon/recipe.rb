# Manage kameleon recipes
require 'kameleon/utils'
require 'kameleon/macrostep'

module Kameleon
  class Recipe
    attr_accessor :sections

    # define section constant
    class Section < Utils::OrderedHash
      BOOTSTRAP="bootstrap"
      SETUP="setup"
      EXPORT="export"
      def self.sections()
        [
          BOOTSTRAP,
          SETUP,
          EXPORT,
        ]
      end
    end

    attr_accessor :global, :sections, :check_cmds

    def initialize(path)
      @path = Pathname.new(path)
      @name = (@path.basename ".yaml").to_s
      @check_cmds = []
      @sections = Section.new
      @global = { "distrib" => nil,
                  "workdir" => File.join(Kameleon.env.build_dir, @name),
                  "rootfs" => "$$workdir/chroot",
                  "exec_cmd" => "fakechroot $$rootfs" }
      load!
    end

    def load!
      # Find recipe path
      Kameleon.ui.info "Loading #{@path}"
      yaml_recipe = YAML.load File.open @path
      fail RecipeError, "Invalid yaml error" unless yaml_recipe.kind_of? Hash
      fail RecipeError, "Recipe misses 'global' section" unless yaml_recipe.key? "global"

      #Load Global variables
      @global.merge!(yaml_recipe.fetch("global"))
      @global.each do |key, value|
        fail RecipeError, "Recipe misses required variable: #{key}" if value.nil?
      end

      #Find and load steps
      Section.sections.each do |section_name|
        @sections[section_name]= []
        yaml_recipe.fetch(section_name).each do |macrostep_yaml|
          macrostep_instance = load_macrostep(macrostep_yaml, section_name)
          # save the macrostep in the section
          @sections[section_name].push(macrostep_instance)
        end
      end
    end

    def load_macrostep(raw_macrostep, section_name)
      #check if it's a string or a dict
      if raw_macrostep.kind_of? String
        name = raw_macrostep
      elsif raw_macrostep.kind_of? Hash
        name = raw_macrostep.keys[0]
        args = raw_macrostep.values[0]
      else
        fail RecipeError, "Malformed yaml recipe in section: "+ section_name
      end
      # find the path of the macrostep
      steps_dir = File.join(File.dirname(@path), 'steps')
      [@global['distrib'], 'default', ''].each do |search_dir|
        path = File.join(steps_dir, section_name, search_dir, name + '.yaml')
        if File.file?(path)
          Kameleon.ui.info "> Loading #{name} : #{path}"
          return Macrostep.new(path, args)
        end
        Kameleon.ui.debug "Step #{name} not found in this path: #{path}"
      end
      fail RecipeError, "Step #{name} not found" unless File.file?(path)
    end
  end
end
