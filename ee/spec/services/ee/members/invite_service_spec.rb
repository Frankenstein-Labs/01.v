# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Members::InviteService, :aggregate_failures, feature_category: :groups_and_projects do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:root_ancestor) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, group: root_ancestor) }
  let_it_be(:subgroup) { create(:group, parent: root_ancestor) }
  let_it_be(:subgroup_project) { create(:project, group: subgroup) }

  let(:base_params) { { access_level: Gitlab::Access::GUEST, source: project, invite_source: '_invite_source_' } }
  let(:params) { { email: %w[email@example.org email2@example.org] } }

  subject(:result) { described_class.new(user, base_params.merge(params)).execute }

  before_all do
    project.add_maintainer(user)

    create(:project_member, :invited, project: subgroup_project, created_at: 2.days.ago)
    create(:project_member, :invited, project: subgroup_project)
    create(:group_member, :invited, group: subgroup, created_at: 2.days.ago)
    create(:group_member, :invited, group: subgroup)
  end

  describe '#execute' do
    context 'on saas', :saas do
      context 'with onboarding progress', :sidekiq_inline do
        it_behaves_like 'records an onboarding progress action', :user_added do
          let(:namespace) { project.namespace }
        end

        it_behaves_like 'does not record an onboarding progress action' do
          let(:params) { { email: '_bogus_' } }
        end
      end

      context 'with group plan observing quota limits' do
        let(:plan) { create(:premium_plan) }
        let!(:plan_limits) { create(:plan_limits, plan: plan, daily_invites: daily_invites) }
        let!(:subscription) do
          create(
            :gitlab_subscription,
            namespace: root_ancestor,
            hosted_plan: plan
          )
        end

        shared_examples 'quota limit exceeded' do |limit|
          it 'limits the number of daily invites allowed' do
            expect { result }.not_to change { ProjectMember.count }
            expect(result[:status]).to eq(:error)
            expect(result[:message]).to eq("Invite limit of #{limit} per day exceeded.")
          end
        end

        context 'already exceeded invite quota limit' do
          let(:daily_invites) { 2 }

          it_behaves_like 'quota limit exceeded', 2
        end

        context 'will exceed invite quota limit' do
          let(:daily_invites) { 3 }

          it_behaves_like 'quota limit exceeded', 3
        end

        context 'within invite quota limit' do
          let(:daily_invites) { 5 }

          it 'successfully creates members' do
            expect { result }.to change { ProjectMember.count }.by(2)
            expect(result[:status]).to eq(:success)
          end
        end

        context 'infinite invite quota limit' do
          let(:daily_invites) { 0 }

          it 'successfully creates members' do
            expect { result }.to change { ProjectMember.count }.by(2)
            expect(result[:status]).to eq(:success)
          end
        end
      end

      context 'when block seat overages is enabled', :saas do
        let_it_be(:subscription) { create(:gitlab_subscription, :premium, namespace: root_ancestor, seats: 1) }

        before do
          stub_saas_features(gitlab_com_subscriptions: true)
          root_ancestor.namespace_settings.update!(seat_control: :block_overages)
        end

        context 'with an email invite that begins with the id of a user in the group' do
          let(:params) { { email: ["#{user.id}_abc@example.com"] } }

          it 'rejects adding the member' do
            expect { result }.not_to change { ProjectMember.count }
            expect(result).to eq({
              status: :error,
              message: 'There are not enough available seats to invite this many users. ' \
                       'Ask a user with the Owner role to purchase more seats.',
              reason: :seat_limit_exceeded_error
            })
          end
        end
      end

      context 'without a plan' do
        let(:plan) { nil }

        it 'successfully creates members' do
          expect { result }.to change { ProjectMember.count }.by(2)
          expect(result[:status]).to eq(:success)
        end
      end

      context 'with Audit Event logging' do
        context 'when there are valid members created' do
          it 'creates audit events' do
            expect { result }.to change { AuditEventReader.count }.by(2)
          end
        end

        context 'when there are some invalid members' do
          let(:params) { { email: %w[_bogus_ email2@example.org] } }

          it 'only creates audit events for valid members' do
            expect { result }.to change { AuditEventReader.count }.by(1)
          end
        end
      end
    end

    context 'with billable promotion management' do
      let_it_be(:license) { create(:license, plan: License::ULTIMATE_PLAN) }
      let_it_be(:project_users) { create_list(:user, 2) }

      let(:emails) { project_users.map(&:email) }
      let(:params) do
        {
          email: emails,
          access_level: Gitlab::Access::DEVELOPER,
          invite_source: '_invite_source_'
        }
      end

      before do
        stub_application_setting(enable_member_promotion_management: true)
        allow(License).to receive(:current).and_return(license)
      end

      context 'queues members for admin approval' do
        it { expect { result }.not_to change { project.members.count } }

        it { expect { result }.to change { ::GitlabSubscriptions::MemberManagement::MemberApproval.count }.by(2) }

        it 'returns queued_users in the response' do
          params[:email] = project_users[0].email
          params[:user_id] = project_users[1].id.to_s

          expect(result).to eq({
            status: :success,
            queued_users: {
              project_users[0].email => 'Request queued for administrator approval.',
              project_users[1].username => 'Request queued for administrator approval.'
            }
          })
        end
      end
    end
  end
end
