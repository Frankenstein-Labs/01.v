# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillWorkspaceAgentkStates
        extend ::Gitlab::Utils::Override

        override :perform

        # rubocop:disable Metrics/MethodLength -- this is a little over the limit, I'll extract some parts to a function if this becomes larger
        # @return [Void]
        def perform
          ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspace.reset_column_information
          ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgent.reset_column_information
          ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentkState.reset_column_information
          ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentConfig.reset_column_information
          ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmAgent.reset_column_information

          # rubocop:disable Metrics/BlockLength -- this is a little over the limit, I'll extract some parts to a function if this becomes larger
          each_sub_batch do |sub_batch|
            sub_batch.each do |record|
              ::Gitlab::BackgroundMigration::RemoteDevelopment::BmCreateDesiredConfig
                .create_and_save(workspace_id: record.id)
            rescue StandardError => e
              message = "Migration failed for this workspace. This workspace will be orphaned, cluster " \
                "administrators are advised to clean up the orphan workspaces."
              ::Gitlab::BackgroundMigration::Logger.warn(
                message: message,
                workspace_id: record.id,
                error_message: e.message,
                backtrace: e.backtrace&.first(20)
              )

              workspace = ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspace.find(record.id)
              workspace.actual_state = "Terminated"
              workspace.desired_state = "Terminated"
              workspace.save!

              ::Gitlab::BackgroundMigration::RemoteDevelopment::Models::BmWorkspaceAgentkState.upsert(
                {
                  workspace_id: record.id,
                  project_id: record.project_id,
                  desired_config: [{
                    message: message,
                    error_message: e.message,
                    backtrace: e.backtrace&.first(20)
                  }]
                },
                unique_by: :workspace_id
              )
              # rubocop:enable Metrics/BlockLength
            end
            # rubocop:enable Metrics/MethodLength
          end
          nil
        end
      end
    end
  end
end
