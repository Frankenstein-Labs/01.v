# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::ImportNamespaceCreateService, :aggregate_failures, feature_category: :onboarding do
  using RSpec::Parameterized::TableSyntax

  describe '#execute' do
    let_it_be_with_reload(:user) { create(:user, onboarding_in_progress: true) }
    let_it_be(:group, freeze: false) { create(:group, owners: user) }
    let_it_be(:organization) { create(:organization) }
    let(:group_params) do
      {
        name: 'Group name',
        path: 'group-path',
        visibility_level: Gitlab::VisibilityLevel::PRIVATE.to_s,
        organization_id: organization.id
      }
    end

    before_all do
      organization.users << user
    end

    subject(:execute) { described_class.new(user, group_params: group_params).execute }

    context 'when group can be created' do
      it 'creates a group' do
        expect do
          expect(execute).to be_success
        end.to change { Group.count }.by(1).and change { ::Onboarding::Progress.count }.by(1)
      end

      it 'marks the group for Duo Code Review auto enable' do
        group = execute.payload[:group]

        expect(group.namespace_settings.enable_duo_code_review_by_default).to eq('pending')
      end

      it 'passes group_params with setup_for_company to the Groups::CreateService' do
        expect(Groups::CreateService)
          .to receive(:new).with(user,
            group_params.merge(setup_for_company: user.onboarding_status_setup_for_company)).and_call_original

        expect(execute).to be_success
      end

      it 'enqueues a create event worker' do
        expect(Groups::CreateEventWorker).to receive(:perform_async).with(anything, user.id, 'created')

        execute
      end

      it 'tracks group creation events' do
        expect(execute).to be_success

        expect_snowplow_event(
          category: described_class.name,
          action: 'create_group_import',
          namespace: an_instance_of(Group),
          user: user
        )
      end

      it 'does not attempt to create a trial' do
        expect(GitlabSubscriptions::Trials::ApplyTrialWorker).not_to receive(:perform_async)

        expect(execute).to be_success
      end

      context 'with onboarding_status concerns' do
        before do
          user.update!(onboarding_status_registration_type: 'trial')
          stub_saas_features(onboarding: true)
        end

        it 'does not change the registration_type' do
          expect { expect(execute).to be_success }.not_to change { user.reload.onboarding_status_registration_type }
        end
      end
    end

    context 'when the group cannot be created' do
      let(:group_params) { { name: '', path: '' } }

      it 'does not mark any group for Duo code review auto enable' do
        expect { execute }
          .not_to change { NamespaceSetting.enable_duo_code_review_by_default_pending.count }
      end

      it 'does not create a group' do
        expect { expect(execute).to be_error }
          .to not_change { Group.count }
          .and not_change { ::Onboarding::Progress.count }
        expect(execute.payload[:group].errors).not_to be_blank
      end

      it 'does not track events for group creation' do
        expect(execute).to be_error

        expect_no_snowplow_event(category: described_class.name, action: 'create_group_import')
      end

      it 'the project is not disregarded completely' do
        expect(execute).to be_error

        expect(execute.payload[:project].namespace).to be_present
      end

      it 'does not enqueue a create event worker' do
        expect(Groups::CreateEventWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'with applying for a trial' do
      let(:glm_content) { 'content' }
      let(:glm_source) { 'about.gitlab.com' }
      let(:extra_information) { { glm_content: glm_content, glm_source: glm_source } }
      let(:trial_user_information) do
        {
          namespace_id: group.id,
          gitlab_com_trial: true,
          sync_to_gl: true,
          namespace: group.slice(:id, :name, :path, :kind, :trial_ends_on)
        }.merge(extra_information)
      end

      before do
        allow_next_instance_of(::Groups::CreateService) do |service|
          allow(service).to receive(:execute).and_return(ServiceResponse.success(payload: { group: group }))
        end

        stub_saas_features(onboarding: true)
        user.update!(
          onboarding_status_registration_type: 'trial',
          onboarding_status_glm_source: glm_source,
          onboarding_status_glm_content: glm_content
        )
      end

      it 'applies a trial' do
        expect(GitlabSubscriptions::Trials::ApplyTrialWorker)
          .to receive(:perform_async).with(user.id, trial_user_information.stringify_keys).and_call_original

        expect(execute).to be_success
      end

      context 'when glm params are nil' do
        let(:glm_content) { nil }
        let(:glm_source) { nil }
        let(:extra_information) { {} }

        it 'does not pass the glm parameters to the worker' do
          expect(GitlabSubscriptions::Trials::ApplyTrialWorker)
            .to receive(:perform_async).with(user.id, trial_user_information.stringify_keys).and_call_original

          expect(execute).to be_success
        end
      end
    end
  end
end
