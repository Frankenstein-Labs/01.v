# frozen_string_literal: true

module EE
  module Projects
    module UpdateStatisticsService
      extend ::Gitlab::Utils::Override

      private

      override :after_execute_hook
      def after_execute_hook
        super

        record_onboarding_progress
      end

      def record_onboarding_progress
        return unless repository.commit_count > 1 ||
          repository.branch_count > 1 ||
          !initialized_repository_with_no_or_only_readme_file?

        ::Onboarding::ProgressService.new(project.namespace).execute(action: :code_added)
      end

      def initialized_repository_with_no_or_only_readme_file?
        return true if repository.empty?

        !repository.ls_files(project.default_branch).reject do |file|
          file == ::Projects::CreateService::README_FILE
        end.any?
      end
    end
  end
end
