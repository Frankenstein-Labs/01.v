# frozen_string_literal: true

FactoryBot.modify do
  factory :project do
    trait :with_default_tracked_context do
      after(:create) do |project|
        project.security_project_tracked_contexts = create_list(
          :security_project_tracked_context, 1, :default, project: project
        )
      end
    end

    trait :import_hard_failed do
      import_status { :failed }

      after(:create) do |project, evaluator|
        project.import_state.update!(
          retry_count: Gitlab::Mirror::MAX_RETRY + 1,
          last_update_at: Time.now - 1.minute
        )
      end
    end

    trait :mirror do
      mirror { true }
      import_url { generate(:url) }
      mirror_user_id { creator_id }
    end

    trait :random_last_repository_updated_at do
      last_repository_updated_at { rand(1.year).seconds.ago }
    end

    trait :github_imported do
      import_type { 'github' }
    end

    trait :with_vulnerability do
      after(:create) do |project|
        create(:vulnerability, :detected, project: project)
        project.project_setting.update!(has_vulnerabilities: true)
      end
    end

    trait :with_vulnerabilities do
      after(:create) do |project|
        create_list(:vulnerability, 2, :with_finding, :detected, project: project)
        project.project_setting.update!(has_vulnerabilities: true)
      end
    end

    trait :with_vulnerability_statistic do
      after(:create) do |project|
        create(:vulnerability_statistic, project: project)
      end
    end

    trait :with_security_scans do
      after(:create) do |project|
        create_list(:security_scan, 2, project: project)
      end
    end

    trait :with_analyzer_statuses do
      after(:create) do |project|
        create(:analyzer_project_status, status: :success, analyzer_type: :sast, project: project)
        create(:analyzer_project_status, status: :failed, analyzer_type: :dast, project: project)
      end
    end

    trait :with_cvs do
      after(:create) do |project|
        project.security_setting.update!(continuous_vulnerability_scans_enabled: true)
      end
    end

    trait :container_scanning_for_registry_enabled do
      after(:create) do |project|
        project.security_setting.update!(container_scanning_for_registry_enabled: true)
      end
    end

    trait :with_compliance_framework do
      after(:build) do |project|
        project.compliance_framework_settings = create_list(:compliance_framework_project_setting, 1, project: project)
      end
    end

    trait :with_sox_compliance_framework do
      after(:build) do |project|
        project.compliance_framework_settings = create_list(:compliance_framework_project_setting, 1, :sox,
          project: project)
      end
    end

    trait :with_multiple_compliance_frameworks do
      after(:build) do |project|
        create(:compliance_framework_project_setting, project: project)
        create(:compliance_framework_project_setting, :sox, project: project)
      end
    end

    trait :with_cve_request do
      transient do
        cve_request_enabled { true }
      end
      after(:create) do |project, evaluator|
        project.project_setting.cve_id_request_enabled = evaluator.cve_request_enabled
        project.project_setting.save!
      end
    end

    trait :with_security_orchestration_policy_configuration do
      association :security_orchestration_policy_configuration, factory: :security_orchestration_policy_configuration
    end

    trait :with_ci_minutes do
      transient do
        amount_used { 0 }
        shared_runners_duration { 0 }
      end

      after(:create) do |project, evaluator|
        if evaluator.amount_used || evaluator.shared_runners_duration
          create(
            :ci_project_monthly_usage,
            project: project, amount_used: evaluator.amount_used,
            shared_runners_duration: evaluator.shared_runners_duration
          )
        end
      end
    end

    trait :with_product_analytics_dashboard do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/dashboard_example_1/dashboard_example_1.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_1.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )

        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/cube_line_chart.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/cube_line_chart.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )

        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/cube_bar_chart.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/cube_bar_chart.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_dashboard_with_inline_visualization do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/dashboard_example_inline_vis/dashboard_example_inline_vis.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_inline_vis.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_dashboard_with_invalid_datatable_fields do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/dashboard_invalid_datatable_fields/dashboard_invalid_datatable_fields.yaml',
          File.open(
            Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_invalid_datatable_fields.yaml')
          ).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_dashboard_with_inline_visualization_no_slug do
      repository

      after(:create) do |project|
        dashboard = 'dashboard_example_inline_vis_no_slug'
        project.repository.create_file(
          project.creator,
          ".gitlab/analytics/dashboards/#{dashboard}/#{dashboard}.yaml",
          File.open(Rails.root.join("ee/spec/fixtures/product_analytics/#{dashboard}.yaml")).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_dashboard_with_invalid_panel_tooltip do
      repository

      after(:create) do |project|
        dashboard = 'dashboard_example_invalid_panel_tooltip'
        project.repository.create_file(
          project.creator,
          ".gitlab/analytics/dashboards/#{dashboard}/#{dashboard}.yaml",
          File.open(Rails.root.join("ee/spec/fixtures/product_analytics/#{dashboard}.yaml")).read,
          message: 'test',
          branch_name: 'master'
        )

        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/cube_line_chart.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/cube_line_chart.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_dashboard_with_invalid_panel_views do
      repository

      after(:create) do |project|
        dashboard = 'dashboard_example_invalid_panel_views'
        project.repository.create_file(
          project.creator,
          ".gitlab/analytics/dashboards/#{dashboard}/#{dashboard}.yaml",
          File.open(Rails.root.join("ee/spec/fixtures/product_analytics/#{dashboard}.yaml")).read,
          message: 'test',
          branch_name: 'master'
        )

        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/cube_line_chart.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/cube_line_chart.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_custom_visualization do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/example_custom_visualization.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/example_custom_visualization.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_invalid_custom_visualization do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/dashboard_example_invalid_vis/dashboard_example_invalid_vis.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dashboard_example_invalid_vis.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )

        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/example_invalid_custom_visualization.yaml',
          File.open(
            Rails.root.join('ee/spec/fixtures/product_analytics/example_invalid_custom_visualization.yaml')
          ).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_dashboard_attempting_path_traversal do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/dangerous_dashboard/dangerous_dashboard.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/dangerous_dashboard.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )

        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/dashboards/visualizations/cube_line_chart.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/cube_line_chart.yaml')).read,
          message: 'test',
          branch_name: 'master'
        )
      end
    end

    trait :with_product_analytics_funnel do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/funnels/funnel_example_1.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_1.yaml')).read,
          message: 'Add funnel definition',
          branch_name: 'master'
        )
      end
    end

    trait :with_invalid_seconds_product_analytics_funnel do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/funnels/funnel_example_invalid_seconds.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_seconds.yaml')).read,
          message: 'Add invalid seconds funnel definition',
          branch_name: 'master'
        )
      end
    end

    trait :with_invalid_step_name_product_analytics_funnel do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/funnels/funnel_example_invalid_step_name.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_step_name.yaml')).read,
          message: 'Add invalid step name funnel definition',
          branch_name: 'master'
        )
      end
    end

    trait :with_invalid_step_target_product_analytics_funnel do
      repository

      after(:create) do |project|
        project.repository.create_file(
          project.creator,
          '.gitlab/analytics/funnels/funnel_example_invalid_step_target.yaml',
          File.open(Rails.root.join('ee/spec/fixtures/product_analytics/funnel_example_invalid_step_target.yaml')).read,
          message: 'Add invalid step target funnel definition',
          branch_name: 'master'
        )
      end
    end

    trait(:allow_pipeline_trigger_approve_deployment) { allow_pipeline_trigger_approve_deployment { true } }

    trait :verification_succeeded do
      repository
      verification_checksum { 'abc' }
      verification_state { Project.verification_state_value(:verification_succeeded) }
    end

    trait :verification_failed do
      repository
      verification_failure { 'Could not calculate the checksum' }
      verification_state { Project.verification_state_value(:verification_failed) }
    end

    trait :with_duo_features_enabled do
      after(:create) do |project|
        project.project_setting.update!(duo_features_enabled: true)
      end
    end

    trait :with_duo_features_disabled do
      after(:create) do |project|
        project.project_setting.update!(duo_features_enabled: false)
      end
    end

    trait :with_code_review_automated_rules do
      repository

      transient do
        automated_rules { nil }
      end

      after(:build, :stub) do |project, evaluator|
        stub_method(project.repository, :code_review_automated_rules_for) do |*_args|
          evaluator.automated_rules
        end
      end
    end
  end
end
