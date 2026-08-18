# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ProjectSettingChangesAuditor, feature_category: :groups_and_projects do
  using RSpec::Parameterized::TableSyntax
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:destination) { create(:audit_events_group_external_streaming_destination, group: group) }
    let_it_be(:project) { create(:project, group: group) }
    let_it_be(:auditor, freeze: false) { described_class.new(user, project.project_setting, project) }

    before do
      stub_licensed_features(extended_audit_events: true, external_audit_events: true)
    end

    shared_examples 'audited setting' do |attribute, event_name|
      before do
        project.project_setting.update!(attribute => prev_value)
      end

      it 'creates an audit event' do
        project.project_setting.update!(attribute => new_value)

        expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
        expect(AuditEventReader.last.details).to include({
          change: attribute.to_s,
          from: prev_value,
          to: new_value
        })
      end

      it 'streams correct audit event stream' do
        project.project_setting.update!(attribute => new_value)

        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
          event_name, anything, anything)

        auditor.execute
      end

      context 'when attribute is not changed' do
        it 'does not create an audit event' do
          project.project_setting.update!(attribute => prev_value)

          expect { auditor.execute }.not_to change { AuditEventReader.count }
        end
      end
    end

    context 'when project setting is updated' do
      options = ProjectSetting.squash_options.keys
      options.each do |prev_value|
        options.each do |new_value|
          context 'when squash option is changed' do
            before do
              project.project_setting.update!(squash_option: prev_value)
            end

            if new_value != prev_value
              it 'creates an audit event' do
                project.project_setting.update!(squash_option: new_value)

                expect { auditor.execute }.to change { AuditEventReader.count }.by(1)
                expect(AuditEventReader.last.details).to include(
                  {
                    custom_message: "Changed squash option to #{project.project_setting.human_squash_option}"
                  })
              end

              it 'streams correct audit event stream' do
                project.project_setting.update!(squash_option: new_value)

                expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(
                  'squash_option_updated', anything, anything)

                auditor.execute
              end

            else
              it 'does not create audit event' do
                project.project_setting.update!(squash_option: new_value)
                expect { auditor.execute }.to not_change { AuditEventReader.count }
              end
            end
          end
        end
      end
    end

    context 'for string changes' do
      where(:prev_value, :new_value) do
        'old' | 'new'
      end

      with_them do
        it_behaves_like 'audited setting', :merge_commit_template, 'merge_commit_template_updated'
        it_behaves_like 'audited setting', :squash_commit_template, 'squash_commit_template_updated'
      end
    end

    context 'for boolean changes' do
      where(:prev_value, :new_value) do
        true | false
        false | true
      end

      with_them do
        context 'when ai-related settings are changed', :saas do
          it_behaves_like 'audited setting', :duo_features_enabled, 'duo_features_enabled_updated'
          it_behaves_like 'audited setting', :duo_sast_vr_workflow_enabled, 'duo_sast_vr_workflow_enabled_updated'
          it_behaves_like 'audited setting', :duo_sast_fp_detection_enabled, 'duo_sast_fp_detection_enabled_updated'
          it_behaves_like 'audited setting', :duo_secret_detection_fp_enabled,
            'duo_secret_detection_fp_detection_enabled_updated'
          it_behaves_like 'audited setting', :allow_merge_on_skipped_pipeline, 'allow_merge_on_skipped_pipeline_updated'
        end

        context 'when `selective_code_owner_removals` is updated' do
          it_behaves_like 'audited setting', :selective_code_owner_removals, 'selective_code_owner_removals_updated'
        end

        context 'when `ai_audit_events_storage_enabled` is updated' do
          it_behaves_like 'audited setting', :ai_audit_events_storage_enabled, 'ai_audit_events_storage_enabled_updated'
        end

        context 'when `only_allow_merge_if_all_status_checks_passed` is updated' do
          it_behaves_like 'audited setting',
            :only_allow_merge_if_all_status_checks_passed,
            'project_only_allow_merge_if_all_status_checks_passed_updated'
        end
      end
    end
  end
end
