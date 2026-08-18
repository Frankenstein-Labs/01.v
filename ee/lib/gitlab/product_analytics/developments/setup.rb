# frozen_string_literal: true

# rubocop:disable Gitlab/DocumentationLinks/HardcodedUrl -- Development purpose
module Gitlab
  module ProductAnalytics
    module Developments
      class Setup
        attr_reader :args

        def initialize(args)
          @args = args
        end

        def execute
          validates!

          group = find_group

          ensure_feature_flags
          ensure_application_settings
          ensure_license_activated(group)

          print_output(group)
        end

        def validates!
          puts "Validating settings...."

          unless ::Gitlab.dev_or_test_env?
            raise <<~MSG
              Setup can only be performed in development or test environment, however, the current environment is #{ENV['RAILS_ENV']}.
            MSG
          end

          unless ::Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS']) # rubocop:disable Style/GuardClause -- Align guard clauses
            raise <<~MSG
              Make sure 'GITLAB_SIMULATE_SAAS' environment variable is truthy.
              See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance for more information.
            MSG
          end
        end

        def find_group
          puts "Checking the specified group exists...."

          raise "You must specify :root_group_path" unless args[:root_group_path].present?
          raise "Sub group cannot be specified" if args[:root_group_path].include?('/')

          group = Group.find_by_full_path(args[:root_group_path])

          raise "Could not find group: #{args[:root_group_path]}" unless group

          group
        end

        def ensure_feature_flags
          puts "Enabling feature flags...."

          flag_groups = ['group::product analytics', 'group::platform insights']

          feature_flag_names = Feature::Definition.definitions.filter_map do |k, v|
            k if flag_groups.include?(v.group)
          end

          feature_flag_names.flatten.each do |ff|
            puts "- #{ff}"
            Feature.enable(ff.to_sym)
          end
        end

        def ensure_application_settings
          puts "Enabling application settings...."

          Gitlab::CurrentSettings.current_application_settings.update!(
            check_namespace_plan: true,
            allow_local_requests_from_web_hooks_and_services: true
          )
        end

        # rubocop:disable CodeReuse/ActiveRecord -- Development purpose
        def ensure_license_activated(group)
          puts "Activating an Ultimate license to the group...."

          plan = Plan.find_or_create_by(name: "ultimate", title: "Ultimate")

          subscription = GitlabSubscription.find_or_create_by(namespace: group)
          subscription.update!(hosted_plan_id: plan.id) unless subscription.hosted_plan == plan
        end

        # rubocop:enable CodeReuse/ActiveRecord
        def application_configured?
          Gitlab::CurrentSettings.product_analytics_data_collector_host.present?
        end

        def print_output(group)
          puts <<~MSG
            ----------------------------------------
            Setup Complete!
            ----------------------------------------
          MSG

          if application_configured?
            puts <<~MSG
              Product Analytics is now enabled and configured.

              You can access Product Analytics on any project in "#{group.name}" by selecting Analyze > Analytics dashboards in the left sidebar.
            MSG
          else
            puts <<~MSG
              Product Analytics is now enabled but not yet configured! To do so:

              1. Setup and connect the Product Analytics Devkit to your GDK, see https://gitlab.com/gitlab-org/analytics-section/product-analytics/devkit.

              2. Access Product Analytics on any project in "#{group.name}" by selecting Analyze > Analytics dashboards in the left sidebar.
            MSG
          end
        end
      end
    end
  end
end
# rubocop:enable Gitlab/DocumentationLinks/HardcodedUrl
