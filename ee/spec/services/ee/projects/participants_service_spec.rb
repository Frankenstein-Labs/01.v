# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Projects::ParticipantsService, feature_category: :code_review_workflow do
  describe '#execute' do
    let_it_be(:organization) { create(:organization) }
    let_it_be(:group) { create(:group, organization: organization) }
    let_it_be_with_reload(:project) { create(:project, :public, group: group, organization: organization) }

    let_it_be_with_reload(:current_user) do
      create(:user, organization: organization, developer_of: project, username: 'current')
    end

    let_it_be(:duo_code_review_bot) do
      ::Users::Internal.in_organization(organization.id).duo_code_review_bot
    end

    let_it_be_with_reload(:non_agent_service_account) do
      create(:user, :service_account, organization: organization, developer_of: project, username: 'non-agent')
    end

    let_it_be_with_reload(:agent_service_account) do
      create(:user, :service_account, organization: organization, developer_of: project, username: 'agent',
        composite_identity_enforced: true)
    end

    let_it_be_with_reload(:merge_request) do
      create(
        :merge_request,
        source_project: project,
        target_project: project,
        author: current_user,
        assignees: [non_agent_service_account, agent_service_account]
      )
    end

    let(:usage_quota_result) { ServiceResponse.success }

    before do
      allow_next_instance_of(
        ::Ai::UsageQuotaService,
        user: current_user
      ) do |instance|
        allow(instance).to receive(:execute).and_return(usage_quota_result)
      end
    end

    subject(:participants) do
      described_class.new(project, current_user, {}).execute(merge_request)
    end

    context 'when project does not have access to Duo Code review' do
      before do
        allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
      end

      it { is_expected.not_to include(a_hash_including({ username: duo_code_review_bot.username })) }
    end

    context 'when project has access Duo Code review' do
      before do
        allow(project).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
      end

      it { is_expected.to include(a_hash_including({ username: duo_code_review_bot.username })) }
    end

    describe 'disabled fields' do
      context 'when regular user' do
        it 'returns the regular user as not disabled' do
          expect(participants).to include(
            a_hash_including(
              username: current_user.username,
              disabled: false,
              disabled_reason: ""
            )
          )
        end
      end

      context 'when non-agent service account user' do
        it 'returns the non-agent service account as not disabled' do
          expect(participants).to include(
            a_hash_including(
              username: non_agent_service_account.username,
              disabled: false,
              disabled_reason: ""
            )
          )
        end
      end

      context 'when agent service account' do
        context 'and credits are available' do
          it 'returns the agent service account as not disabled' do
            expect(participants).to include(
              a_hash_including(
                username: agent_service_account.username,
                disabled: false,
                disabled_reason: ""
              )
            )
          end
        end

        context 'and credits are expired' do
          let(:usage_quota_result) { ServiceResponse.error(message: 'no credits', reason: :usage_quota_exceeded) }

          it 'returns the agent service account as disabled' do
            expect(participants).to include(
              a_hash_including(
                username: agent_service_account.username,
                disabled: true,
                disabled_reason: "Unavailable - no credits"
              )
            )
          end
        end
      end
    end
  end
end
