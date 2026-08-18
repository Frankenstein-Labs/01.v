# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Users::DestroyService, feature_category: :user_management do
  let_it_be(:current_user) { create(:admin) }

  subject(:service) { described_class.new(current_user) }

  shared_examples 'auditable' do |audit_name:|
    before do
      stub_licensed_features(extended_audit_events: true)
    end

    it "creates #{audit_name} audit event record", :aggregate_failures do
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including({
        name: audit_name
      })).and_call_original

      expect { operation }.to change { AuditEventReader.count }.by(1)

      audit_event = AuditEventReader.last
      details = expected_audit_attributes.delete(:details) || {}
      expected_audit_attributes.each do |method, value|
        expect(audit_event.public_send(method)).to eq(value)
      end
      expect(audit_event.details).to include(details)
    end
  end

  describe '#execute' do
    let!(:user) { create(:user) }

    subject(:operation) { service.execute(user) }

    context 'when admin mode is disabled' do
      it 'raises access denied' do
        expect { operation }.to raise_error(::Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when admin mode is enabled', :enable_admin_mode do
      context 'for audit event' do
        it_behaves_like 'auditable', audit_name: 'user_destroyed' do
          let(:author) { current_user }

          let(:expected_audit_attributes) do
            {
              author_id: author.id,
              entity: user,
              details: {
                author_class: author.class.to_s,
                author_name: author.name,
                custom_message: "User #{user.username} scheduled for deletion",
                target_details: user.full_path,
                target_id: user.id,
                target_type: user.class.to_s
              }
            }
          end
        end

        context 'when current_user is nil' do
          let_it_be(:current_user) { nil }

          subject(:operation) { service.execute(user, { skip_authorization: true }) }

          it_behaves_like 'auditable', audit_name: 'user_destroyed' do
            let(:author) { ::Gitlab::Audit::UnauthenticatedAuthor.new(name: '(System)') }

            let(:expected_audit_attributes) do
              {
                author_id: author.id,
                details: {
                  author_class: author.class.to_s,
                  author_name: author.name
                }
              }
            end
          end
        end

        context 'when reason_for_deletion is provided' do
          let(:reason_for_deletion) { 'Reason for deletion!' }

          subject(:operation) { service.execute(user, { reason_for_deletion: reason_for_deletion }) }

          it_behaves_like 'auditable', audit_name: 'user_destroyed' do
            let(:expected_audit_attributes) do
              {
                details: {
                  custom_message: "User #{user.username} scheduled for deletion. Reason: #{reason_for_deletion}"
                }
              }
            end
          end
        end

        context 'when user is a project_bot' do
          let(:user) { create(:user, :project_bot) }

          context 'when project_bot belongs to resource' do
            let!(:resource) { create(:group, maintainers: user) }

            it_behaves_like 'auditable', audit_name: 'user_destroyed' do
              let(:author) { current_user }

              let(:expected_audit_attributes) do
                {
                  author_id: author.id,
                  entity: resource,
                  details: {
                    author_class: author.class.to_s,
                    author_name: author.name,
                    custom_message: "User #{user.username} scheduled for deletion",
                    target_details: user.full_path,
                    target_id: user.id,
                    target_type: user.class.to_s
                  }
                }
              end
            end
          end

          context 'when project_bot is orphaned record' do
            it_behaves_like 'auditable', audit_name: 'user_destroyed' do
              let(:author) { current_user }

              let(:expected_audit_attributes) do
                {
                  author_id: author.id,
                  entity: user,
                  details: {
                    author_class: author.class.to_s,
                    author_name: author.name,
                    custom_message: "User #{user.username} scheduled for deletion",
                    target_details: user.full_path,
                    target_id: user.id,
                    target_type: user.class.to_s
                  }
                }
              end
            end
          end
        end

        context 'when user is provisioned by a group' do
          let(:group) { create(:group) }
          let(:user) { create(:user, provisioned_by_group: group) }

          it_behaves_like 'auditable', audit_name: 'user_destroyed' do
            let(:author) { current_user }

            let(:expected_audit_attributes) do
              {
                author_id: author.id,
                entity: group,
                details: {
                  author_class: author.class.to_s,
                  author_name: author.name,
                  custom_message: "User #{user.username} scheduled for deletion",
                  target_details: user.full_path,
                  target_id: user.id,
                  target_type: user.class.to_s
                }
              }
            end
          end
        end
      end

      context 'when project is a mirror' do
        let(:project) { create(:project, :mirror, mirror_user_id: user.id) }

        it 'disables mirror and does not assign a new mirror_user' do
          expect(::Gitlab::ErrorTracking).to receive(:track_exception)

          allow_next_instance_of(::NotificationService) do |notification|
            expect(notification).to receive(:mirror_was_disabled)
              .with(project, user.name)
              .and_call_original
          end

          expect { operation }.to change { project.reload.mirror_user }.from(user).to(nil)
            .and change { project.reload.mirror }.from(true).to(false)
        end
      end

      context 'when user has oncall rotations' do
        let(:schedule) { create(:incident_management_oncall_schedule, project: project) }
        let(:rotation) { create(:incident_management_oncall_rotation, schedule: schedule) }
        let!(:participant) { create(:incident_management_oncall_participant, rotation: rotation, user: user) }
        let!(:other_participant) { create(:incident_management_oncall_participant, rotation: rotation) }

        context 'in their own project' do
          let(:project) { create(:project, namespace: user.namespace) }

          it 'deletes the project and the schedule' do
            operation

            expect { project.reload }.to raise_error(ActiveRecord::RecordNotFound)
            expect { schedule.reload }.to raise_error(ActiveRecord::RecordNotFound)
          end
        end

        context 'in a group project' do
          let(:group) { create(:group) }
          let(:project) { create(:project, namespace: group) }

          before do
            project.add_developer(user)
          end

          it 'calls IncidentManagement::OncallRotations::RemoveParticipantsService' do
            expect_next_instance_of(IncidentManagement::OncallRotations::RemoveParticipantsService) do |service|
              expect(service).to receive(:execute).once
            end

            operation
          end

          it 'sends an email about the user being removed from the rotation' do
            expect { operation }.to change { ActionMailer::Base.deliveries.size }.by(1)
          end
        end
      end

      context 'when user has escalation rules' do
        let(:project) { create(:project) }
        let(:user) { project.first_owner }
        let(:project_policy) { create(:incident_management_escalation_policy, project: project) }
        let!(:project_rule) { create(:incident_management_escalation_rule, :with_user, policy: project_policy, user: user) }

        let(:group) { create(:group) }
        let(:group_project) { create(:project, group: group) }
        let(:group_policy) { create(:incident_management_escalation_policy, project: group_project) }
        let!(:group_rule) { create(:incident_management_escalation_rule, :with_user, policy: group_policy, user: user) }
        let!(:group_owner) { create(:user) }

        before do
          group.add_developer(user)
          group.add_owner(group_owner)
        end

        it 'deletes the escalation rules and notifies owners of group projects' do
          expect { operation }.to change { ActionMailer::Base.deliveries.size }.by(1)

          expect { project.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { project_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
          expect { group_rule.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end
  end
end
