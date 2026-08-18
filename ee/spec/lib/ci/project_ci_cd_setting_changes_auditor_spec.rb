# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::ProjectCiCdSettingChangesAuditor, feature_category: :continuous_integration do
  using RSpec::Parameterized::TableSyntax
  describe '#execute' do
    let_it_be(:user, freeze: false) { create(:user) }
    let_it_be(:group, freeze: false) { create(:group) }
    let_it_be(:project, freeze: false) do
      create(
        :project,
        group: group
      )
    end

    let_it_be(:ci_cd_settings, freeze: false) { project.ci_cd_settings }
    let_it_be(:project_ci_cd_setting_changes_auditor, freeze: false) do
      described_class.new(user, ci_cd_settings, project)
    end

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    context 'when auditable boolean column is changed' do
      columns = %w[merge_trains_enabled merge_pipelines_enabled]
      columns.each do |column|
        context 'when column changes from boolean' do
          where(:prev_value, :new_value) do
            true  | false
            false | true
          end

          before do
            project.ci_cd_settings.update_attribute(column, prev_value)
            project.ci_cd_settings.update_attribute(column, new_value)
          end

          with_them do
            it 'creates an audit event' do
              expect { project_ci_cd_setting_changes_auditor.execute }.to change { AuditEventReader.count }.by(1)
              expect(AuditEventReader.last.details).to include({
                change: column,
                from: prev_value,
                to: new_value
              })
            end

            it 'streams correct audit event', :aggregate_failures do
              event_name = "project_cicd_#{column}_updated"
              expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async)
                .with(event_name, anything, anything)
              project_ci_cd_setting_changes_auditor.execute
            end
          end
        end

        context 'when column changes to false from nil' do
          before do
            project.ci_cd_settings.update_attribute(column, nil)
          end

          it 'does not create an audit event' do
            project.ci_cd_settings.update_attribute(column, false)

            expect { project_ci_cd_setting_changes_auditor.execute }.not_to change { AuditEventReader.count }
          end
        end
      end
    end
  end
end
