# frozen_string_literal: true

module ProductAnalytics
  class Funnel
    include ActiveModel::Validations

    attr_accessor :name, :project, :seconds_to_convert, :config_project, :previous_name

    FUNNELS_ROOT_LOCATION = '.gitlab/analytics/funnels'

    # This model is not used as a true ActiveRecord
    # You must run .valid? wherever this model is used for these validations to be run
    validates :name, presence: true
    validates :seconds_to_convert, numericality: { only_integer: true, greater_than: 0 }
    validate :check_steps_validity

    def self.from_diff(diff, project:, sha: nil, commit: nil)
      config_project = project.analytics_dashboards_configuration_project || project
      sha ||= config_project.repository.root_ref_sha
      config = YAML.safe_load(
        config_project.repository.blob_data_at(sha, diff.new_path)
      )

      name = ::ProductAnalytics::Funnel.name_from_file_path(diff.new_path)

      if commit
        unless diff.old_path == diff.new_path
          previous_name = ::ProductAnalytics::Funnel.name_from_file_path(diff.old_path)
        end

        new(
          name: name,
          project: project,
          config_project: config_project,
          seconds_to_convert: config['seconds_to_convert'],
          config_path: diff.new_path,
          previous_name: previous_name
        )
      else
        new(
          name: name,
          project: project,
          config_project: config_project,
          seconds_to_convert: config['seconds_to_convert'],
          config_path: diff.new_path
        )
      end
    end

    def self.names_within_project_repository(project)
      root_trees = project.repository.tree(:head, FUNNELS_ROOT_LOCATION)
      return [] unless root_trees&.entries&.any?

      root_trees.entries.filter_map do |tree|
        config = YAML.safe_load(
          project.repository.blob_data_at(project.repository.root_ref_sha, tree.path)
        )

        name = ::ProductAnalytics::Funnel.name_from_file_path(tree.path)

        next unless name && config['seconds_to_convert'] && config['steps']

        name
      end
    end

    def self.for_project(project)
      config_project = project.analytics_dashboards_configuration_project || project
      root_trees = config_project.repository.tree(:head, FUNNELS_ROOT_LOCATION)
      return [] unless root_trees&.entries&.any?

      root_trees.entries.filter_map do |tree|
        config = YAML.safe_load(
          config_project.repository.blob_data_at(config_project.repository.root_ref_sha, tree.path)
        )

        name = ::ProductAnalytics::Funnel.name_from_file_path(tree.path)

        next unless name && config['seconds_to_convert'] && config['steps']

        new(
          name: name,
          project: project,
          config_project: config_project,
          seconds_to_convert: config['seconds_to_convert'],
          config_path: tree.path
        )
      end
    end

    def self.name_from_file_path(path)
      File.basename(path, File.extname(path))
    end

    def initialize(name:, project:, seconds_to_convert:, config_path:, config_project:, previous_name: nil)
      @name = name.parameterize(separator: '_').underscore
      @project = project
      @seconds_to_convert = seconds_to_convert
      @config_path = config_path
      @config_project = config_project
      @previous_name = previous_name
    end

    def check_steps_validity
      errors.add(:base, "Invalid steps") unless steps.all?(&:valid?)
    end

    def to_h
      return unless valid?

      {
        name: name,
        schema: to_sql,
        steps: steps.map(&:step_definition)
      }
    end

    def to_json(*_)
      to_h.to_json
    end

    def steps
      config = YAML.safe_load(
        project.repository.blob_data_at(project.repository.root_ref_sha, @config_path)
      )

      config['steps'].map do |step|
        ProductAnalytics::FunnelStep.new(
          name: step['name'],
          target: step['target'],
          action: step['action'],
          funnel: self
        )
      end
    end

    def to_sql
      return unless valid?

      <<-SQL
        SELECT
          (SELECT max(derived_tstamp) FROM gitlab_project_#{project.id}.snowplow_events) as x,
          arrayJoin(range(1, #{steps.size + 1})) AS level,
          sumIf(c, user_level >= level) AS count
        FROM
          (SELECT
             level AS user_level,
             count(*) AS c
           FROM (
               SELECT
                 user_id,
                 windowFunnel(#{@seconds_to_convert}, 'strict_order')(toDateTime(derived_tstamp),
                    #{steps.filter_map(&:step_definition).join(', ')}
                 ) AS level
               FROM gitlab_project_#{project.id}.snowplow_events
               WHERE ${FILTER_PARAMS.#{@name}.date.filter('derived_tstamp')}
               GROUP BY user_id
               )
           GROUP BY level
          )
          GROUP BY level
	        ORDER BY level ASC
      SQL
    end
  end
end
