module Remarkable
  module DSL
    module Optionals

      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        protected

          # Creates optional handlers for matchers dynamically. The following
          # statement:
          #
          #   optional :range, :default => 0..10
          #
          # Will generate:
          #
          #   def range(value=0..10)
          #     @options ||= {}
          #     @options[:range] = value
          #     self
          #   end
          #
          # Options:
          #
          # * <tt>:default</tt> - The default value for this optional
          # * <tt>:alias</tt>  - An alias for this optional
          #
          # Examples:
          #
          #   optional :name, :title
          #   optional :range, :default => 0..10, :alias => :within
          #
          # Optionals will be included in description messages if you assign them
          # properly on your locale file. If you have a validate_uniqueness_of
          # matcher with the following on your locale file:
          #
          #   description: validate uniqueness of {{attributes}}
          #   optionals:
          #     scope:
          #       given: scoped to {{inspect}}
          #     case_sensitive:
          #       positive: case sensitive
          #       negative: case insensitive
          #
          # When invoked like below will generate the following messages:
          #
          #   validate_uniqueness_of :project_id, :scope => :company_id
          #   #=> "validate uniqueness of project_id scoped to company_id"
          #
          #   validate_uniqueness_of :project_id, :scope => :company_id, :case_sensitive => true
          #   #=> "validate uniqueness of project_id scoped to company_id and case sensitive"
          #
          #   validate_uniqueness_of :project_id, :scope => :company_id, :case_sensitive => false
          #   #=> "validate uniqueness of project_id scoped to company_id and case insensitive"
          #
          # The interpolation options available are "value" and "inspect". Where
          # the first is the optional value transformed into a string and the
          # second is the inspected value.
          #
          # Four keys are available to be used in I18n files and control how
          # optionals are appended to your description:
          #
          #   * <tt>positive</tt> - When the optional is given and it evaluates to true (everything but false and nil).
          #   * <tt>negative</tt> - When the optional is given and it evaluates to false (false or nil).
          #   * <tt>given</tt> - When the optional is given, doesn't matter the value.
          #   * <tt>not_given</tt> - When the optional is not given.
          #
          def optional(*names)
            options = names.extract_options!
            @matcher_optionals += names

            names.each do |name|
              class_eval <<-END, __FILE__, __LINE__
  def #{name}(value#{ options[:default] ? "=#{options[:default].inspect}" : "" })
    @options ||= {}
    @options[:#{name}] = value
    self
  end
  END
            end
            class_eval "alias_method(:#{options[:alias]}, :#{names.last})" if options[:alias]

            # Call unique to avoid duplicate optionals.
            @matcher_optionals.uniq!
          end

      end

      # Overwrites description to support optionals. Check <tt>optional</tt> for
      # more information.
      #
      def description(options={})
        message = super(options)

        optionals = self.class.matcher_optionals.map do |optional|
          scope = matcher_i18n_scope + ".optionals.#{optional}"

          if @options.key?(optional)
            i18n_key = @options[optional] ? :positive : :negative
            Remarkable.t i18n_key, :default => :given, :raise => true, :scope => scope, :inspect => @options[optional].inspect, :value => @options[optional].to_s
          else
            Remarkable.t :not_given, :raise => true, :scope => scope
          end rescue nil
        end.compact

        message << ' ' << array_to_sentence(optionals)
        message.strip!
        message
      end

    end
  end
end
