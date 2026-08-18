# frozen_string_literal: true

namespace :gitlab do
  namespace :duo do
    desc 'GitLab | Duo | Enable GitLab Duo features'
    task :setup, [:add_on] => :environment do |_, args|
      Gitlab::Duo::Developments::Setup.new(args).execute
    end

    desc 'GitLab | Duo | Enable GitLab Duo feature flags'
    task enable_feature_flags: :gitlab_environment do
      Gitlab::Duo::Developments::FeatureFlagEnabler.execute
    end

    desc 'GitLab | Duo | Seed development self-hosted models'
    task seed_self_hosted_models: :gitlab_environment do
      Gitlab::Duo::Developments::DevSelfHostedModelsManager.seed_models
    end

    desc 'GitLab | Duo | Cleans up seeded self-hosted models and configurations'
    task clean_up_duo_self_hosted: :gitlab_environment do
      Gitlab::Duo::Developments::DevSelfHostedModelsManager.clean_up_duo_self_hosted
    end

    desc 'GitLab | Duo | List self-hosted models'
    task list_self_hosted_models: :gitlab_environment do
      Gitlab::Duo::Developments::DevSelfHostedModelsManager.list_models
    end

    desc 'GitLab | Duo | Create evaluation-ready group'
    task :setup_evaluation, [:root_group_path] => :environment do |_, args|
      Gitlab::Duo::Developments::SetupGroupsForModelEvaluation.new(args).execute
    end

    desc 'GitLab | Duo | Verify self-hosted Duo setup'
    task :verify_self_hosted_setup, [:username] => :gitlab_environment do |_, args|
      Gitlab::Duo::Administration::VerifySelfHostedSetup.new(args[:username]).execute
    end

    desc 'GitLab | Duo | Seed projects and issues for SWE Bench evaluations'
    task :swe_bench_seeder, [:projects] => :environment do |_, args|
      project_filter = args[:projects]&.split(',')&.map(&:strip)&.reject(&:empty?)&.presence
      Gitlab::Duo::Developments::SweBenchSeeder.seed(project_filter: project_filter)
    end

    desc 'GitLab | Duo | Seed pipelines for fix_pipeline evaluation'
    task :fix_pipeline_seeder, [:output] => :environment do |_, args|
      output_file = args[:output] || 'fix_pipeline_evaluation_pipelines.yml'
      Gitlab::Duo::Developments::FixPipelineSeeder.seed_pipelines(output_file: output_file)
    end

    desc <<~DESC
      GitLab | Duo | Mirror the CEF fix_pipeline catalog from production into local GDK.

      Pre-step: Export the source project from gitlab.com and import it locally
      (e.g. via the GitLab UI or `glab project export`). The task aborts if the
      destination project is not already present.

      Required env vars:
        GITLAB_COM_AT     gitlab.com ACCESS TOKEN with read_api on the source project
        LANGCHAIN_API_KEY  read access to LangSmith dataset 'cef.fix_pipeline.materialized.v1'

      Usage:
        bundle exec rake "gitlab:duo:cef_fix_pipeline_mirror[my-group,my-project,out.yml]"
    DESC
    task :cef_fix_pipeline_mirror, [:group, :project, :output] => :environment do |_, args|
      next unless Rails.env.development?

      group = args[:group].presence || 'gitlab-duo'
      project = args[:project].presence || 'duofixfailingpipelinecef'
      output = args[:output].presence || 'fix_pipeline_evaluation_pipelines.yml'

      ok = Gitlab::Duo::Developments::CefFixPipelineMirror.mirror(
        group_path: group,
        project_path: project,
        output_file: output
      )
      abort 'Mirror finished with missing/incomplete rows. See verification report above.' unless ok
    end

    desc 'GitLab | Duo | Onboard Duo Agent Platform'
    task onboard_dap: :gitlab_environment do
      Gitlab::Duo::Developments::DapOnboarding.execute
    end

    desc <<~DESC
      GitLab | Duo | Verify Code Review configuration of a project.

      Checks license, instance Duo settings, namespace and project Duo settings,
      foundational flows (including service accounts and their project roles), and
      Duo Code Review availability.

      Usage:
        bundle exec rake "gitlab:duo:verify_setup[PROJECT_PATH]"

      Examples:
        bundle exec rake "gitlab:duo:verify_setup[my-group/my-project]"
        bundle exec rake "gitlab:duo:verify_setup[my-group/sub-group/my-project]"
    DESC
    task :verify_setup, [:project_path] => :gitlab_environment do |_, args|
      Gitlab::Duo::Administration::VerifySetup.new(args[:project_path]).execute
    end

    desc <<~DESC
      GitLab | Duo | Lint a Duo Code Review custom instructions file.

      Validates the structure of `.gitlab/duo/mr-review-instructions.yaml`
      (or the given path) against the schema expected by Duo Code Review.
      Exits non-zero if any errors are found.

      Usage:
        bundle exec rake "gitlab:duo:lint_review_instructions[PATH]"
    DESC
    task :lint_review_instructions, [:path] => :gitlab_environment do |_, args|
      linter = Gitlab::Duo::Administration::ReviewInstructionsLinter.new(args[:path]).run

      puts "Linting #{linter.file_path}"
      linter.issues.each { |issue| puts issue }
      puts "#{linter.errors.size} error(s), #{linter.warnings.size} warning(s), #{linter.info.size} info"

      abort unless linter.valid?
    end
  end
end
