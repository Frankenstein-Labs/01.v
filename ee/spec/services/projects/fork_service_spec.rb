# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::ForkService, feature_category: :source_code_management do
  describe 'fork by user' do
    subject(:response) { described_class.new(project, user, params).execute }

    let(:params) { { namespace: namespace } }
    let(:namespace) { user.namespace }

    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, namespace: group) }
    let_it_be(:event_type) { "project_fork_operation" }

    let(:fork_of_project) { response[:project] }

    before do
      project.add_member(user, :developer)
      create(:audit_events_group_external_streaming_destination, group: group)
    end

    it 'calls auditor with correct context' do
      expect(::Gitlab::Audit::Auditor).to receive(:audit)
                                            .with(hash_including(name: Projects::CreateService::AUDIT_EVENT_TYPE))
                                            .and_call_original

      audit_context = {
        name: event_type,
        stream_only: true,
        author: user,
        scope: project,
        target: project,
        message: "Forked project to #{user.namespace.path}/#{project.path}"
      }
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(hash_including(audit_context))

      subject
    end

    context "with license feature external_audit_events" do
      before do
        stub_licensed_features(external_audit_events: true)
      end

      it 'sends correct event type in audit event stream' do
        expect(AuditEvents::AuditEventStreamingWorker).to receive(:perform_async).with(event_type, nil, anything)

        subject
      end
    end

    context "without license feature external_audit_events" do
      before do
        stub_licensed_features(external_audit_events: false)
      end

      it 'not sends audit event stream' do
        expect(AuditEvents::AuditEventStreamingWorker).not_to receive(:perform_async)

        subject
      end
    end

    describe '#allowed_fork?' do
      before do
        allow_next_instance_of(::Users::Abuse::ProjectsDownloadBanCheckService, project, user) do |service|
          allow(service).to receive(:execute).and_return(service_response)
        end
      end

      context 'when user is banned from forking the project' do
        let(:service_response) { ServiceResponse.error(message: 'User has been banned') }

        it 'does not fork the project' do
          is_expected.to be_error

          expect(response.errors).to eq(['Forked from project is forbidden'])
        end
      end

      context 'when user is allowed to fork the project' do
        let(:service_response) { ServiceResponse.success }

        it 'forks the project' do
          is_expected.to be_success

          expect(fork_of_project.saved?).to be(true)
          expect(fork_of_project.import_in_progress?).to be(true)
        end
      end
    end

    describe '#link_existing_project' do
      let_it_be(:outside_user) { create(:user) }
      let_it_be(:outside_project) { create(:project, namespace: outside_user.namespace) }

      let_it_be(:protected_group) do
        create(:group).tap do |g|
          g.namespace_settings.update!(prevent_forking_outside_group: true)
        end
      end

      let_it_be(:protected_project) { create(:project, namespace: protected_group) }

      before do
        stub_licensed_features(group_forking_protection: true)
      end

      context "when the target project’s root group forbids forks from outside the group" do
        before_all do
          protected_group.add_maintainer(outside_user)
          protected_project.add_owner(outside_user)
        end

        it 'blocks linking an external upstream' do
          response = described_class.new(outside_project, outside_user).execute(protected_project)

          expect(response).to be_error
          expect(response.reason).to eq(:outside_group)
        end

        it 'still allows a fork link within the same protected group' do
          inside_project = create(:project, namespace: protected_group)

          response = described_class.new(inside_project, outside_user).execute(protected_project)

          expect(response).to be_success
          expect(protected_project.reload.forked_from_project).to eq(inside_project)
        end
      end
    end

    context 'for duo_features_enabled setting of the forked project' do
      let(:namespace) { create(:group) }

      before do
        namespace.add_owner(user)
      end

      context 'when project is forked into a group with duo_features_enabled set to false' do
        before do
          namespace.namespace_settings.update!(duo_features_enabled: false)
        end

        it 'sets the project duo_features_enabled to false' do
          is_expected.to be_success

          expect(fork_of_project.errors).to be_empty
          expect(fork_of_project.import_state.last_error).to be_nil
          expect(fork_of_project.project_setting.duo_features_enabled).to be(false)
        end
      end

      context 'when project is forked into a group with duo_features_enabled set to true' do
        before do
          namespace.namespace_settings.update!(duo_features_enabled: true)
        end

        it 'sets the project duo_features_enabled to true' do
          is_expected.to be_success

          expect(fork_of_project.errors).to be_empty
          expect(fork_of_project.import_state.last_error).to be_nil
          expect(fork_of_project.project_setting.duo_features_enabled).to be(true)
        end
      end

      context 'when project is forked into a group with duo_features_enabled set to nil' do
        before do
          namespace.namespace_settings.update!(duo_features_enabled: nil)
          ::Gitlab::CurrentSettings.current_application_settings.update!(duo_features_enabled: false)
        end

        it 'sets the project duo_features_enabled to the group inherited value from application settings' do
          is_expected.to be_success

          expect(fork_of_project.errors).to be_empty
          expect(fork_of_project.import_state.last_error).to be_nil
          expect(fork_of_project.project_setting.duo_features_enabled).to be(false)
        end
      end

      context 'when project is forked into a group with duo_features_enabled locked by ancestor' do
        before do
          namespace.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: true)
        end

        it 'sets the project duo_features_enabled to the group inherited value from application settings' do
          is_expected.to be_success

          expect(fork_of_project.errors).to be_empty
          expect(fork_of_project.import_state.last_error).to be_nil
          expect(fork_of_project.project_setting.duo_features_enabled).to be(false)
        end
      end

      context 'when project is forked into a group in an instance with duo_features_enabled ' \
        'locked by application_settings' do
        before do
          namespace.namespace_settings.update!(duo_features_enabled: false, lock_duo_features_enabled: false)
          ::Gitlab::CurrentSettings.current_application_settings.update!(duo_features_enabled: false,
            lock_duo_features_enabled: true)
        end

        it 'sets the project duo_features_enabled to the group inherited value from the inheritance chain' do
          is_expected.to be_success

          expect(fork_of_project.errors).to be_empty
          expect(fork_of_project.import_state.last_error).to be_nil
          expect(fork_of_project.project_setting.duo_features_enabled).to be(false)
        end
      end
    end
  end
end
