# frozen_string_literal: true

module Analytics
  module CustomDashboards
    class SystemDashboardsLoader
      include SchemaValidator

      PATH = Rails.root.join('ee/lib/gitlab/analytics/dashboards/system')
      SCHEMA_PATH = 'ee/app/validators/json_schemas/analytics_dashboard.json'

      def self.all
        @all ||= new.all
      end

      def self.find_by_slug(slug)
        by_slug[slug]
      end

      def self.by_slug
        @by_slug ||= all.index_by(&:slug)
      end

      def all
        Dir.glob(PATH.join('*.yaml')).filter_map do |file|
          load_dashboard(file)
        end
      end

      private

      def load_dashboard(file)
        config = load_yaml(file)
        return unless config

        SystemDashboard.new(slug: File.basename(file, '.yaml'), config: config)
      end

      def load_yaml(file)
        config = Gitlab::Config::Loader::Yaml.new(File.read(file)).load_raw!

        errors = schema_errors_for(config)
        raise StandardError, "Invalid system dashboard YAML: #{errors.join(', ')}" if errors.present?

        config
      rescue StandardError => e
        Gitlab::ErrorTracking.track_exception(e)
        nil
      end
    end
  end
end
