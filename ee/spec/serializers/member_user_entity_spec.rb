# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MemberUserEntity do
  include OncallHelpers

  let_it_be_with_reload(:user) { create(:user) }

  let(:current_user) { nil }
  let(:source) { nil }
  let(:options) do
    {
      current_user: current_user,
      source: source
    }
  end

  let(:entity) { described_class.new(user, options) }
  let(:entity_hash) { entity.as_json }

  it 'matches json schema' do
    expect(entity.to_json).to match_schema('entities/member_user_default')
  end

  context 'when using on-call management' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project_1) { create(:project, group: group) }
    let_it_be(:project_2) { create(:project, group: group) }

    context 'with oncall schedules' do
      let_it_be(:oncall_schedule_1) { create_schedule_with_user(project_1, user) }
      let_it_be(:oncall_schedule_2) { create_schedule_with_user(project_2, user) }

      subject { entity_hash[:oncall_schedules] }

      context 'with no source given' do
        it { is_expected.to eq [] }
      end

      context 'source is project' do
        let(:source) { project_1 }

        it { is_expected.to contain_exactly(expected_hash(oncall_schedule_1)) }
      end

      context 'source is group' do
        let(:source) { group }

        it { is_expected.to contain_exactly(expected_hash(oncall_schedule_1), expected_hash(oncall_schedule_2)) }
      end

      private

      def get_url(schedule)
        Gitlab::Routing.url_helpers.project_incident_management_oncall_schedules_url(schedule.project)
      end

      def expected_hash(schedule)
        # for backwards compatibility
        super.merge(schedule_url: get_url(schedule))
      end
    end

    context 'with escalation policies' do
      let_it_be(:policy_1) { create(:incident_management_escalation_policy, project: project_1, rule_count: 0) }
      let_it_be(:rule_1) { create(:incident_management_escalation_rule, :with_user, policy: policy_1, user: user) }
      let_it_be(:policy_2) { create(:incident_management_escalation_policy, project: project_2, rule_count: 0) }
      let_it_be(:rule_2) { create(:incident_management_escalation_rule, :with_user, policy: policy_2, user: user) }

      subject { entity_hash[:escalation_policies] }

      context 'with no source given' do
        it { is_expected.to eq [] }
      end

      context 'source is project' do
        let(:source) { project_1 }

        it { is_expected.to contain_exactly(expected_hash(policy_1)) }
      end

      context 'source is group' do
        let(:source) { group }

        it { is_expected.to contain_exactly(expected_hash(policy_1), expected_hash(policy_2)) }
      end

      private

      def get_url(policy)
        Gitlab::Routing.url_helpers.project_incident_management_escalation_policies_url(policy.project)
      end
    end

    context 'for email' do
      let_it_be(:group) { create(:group) }
      let_it_be(:current_user) { create(:user) }

      let_it_be(:source) { group }

      shared_examples "exposes the user's email" do
        it "exposes the user's email" do
          expect(entity_hash.keys).to include(:email)
          expect(entity_hash[:email]).to eq(user.email)
        end
      end

      shared_examples "does not expose the user's email" do
        it "does not expose the user's email" do
          expect(entity_hash.keys).not_to include(:email)
        end
      end

      context 'when the current_user is a group owner' do
        before do
          create(:group_member, :owner, user: current_user, group: group)
        end

        include_examples "does not expose the user's email"
      end

      context 'when the current_user is an admin' do
        let_it_be(:current_user) { create(:user, :admin) }

        context 'when admin mode enabled', :enable_admin_mode do
          include_examples "exposes the user's email"
        end

        context 'when admin mode disabled' do
          include_examples "does not expose the user's email"
        end
      end

      context 'on SaaS', :saas do
        using RSpec::Parameterized::TableSyntax

        let_it_be(:another_group) { create(:group_member, :owner, user: current_user).group }

        where(
          :domain_verification_availabe_for_group,
          :user_is_enterprise_user_of_the_group,
          :current_user_is_group_owner,
          :shared_examples
        ) do
          false | false | false | "does not expose the user's email"
          false | false | true  | "does not expose the user's email"
          false | true  | false | "does not expose the user's email"
          false | true  | true  | "does not expose the user's email"
          true  | false | false | "does not expose the user's email"
          true  | false | true  | "does not expose the user's email"
          true  | true  | false | "does not expose the user's email"
          true  | true  | true  | "exposes the user's email"
        end

        with_them do
          before do
            stub_licensed_features(domain_verification: domain_verification_availabe_for_group)

            user.user_detail.enterprise_group_id = user_is_enterprise_user_of_the_group ? group.id : another_group.id

            if current_user_is_group_owner
              create(:group_member, :owner, user: current_user, group: group)
            else
              create(:group_member, :maintainer, user: current_user, group: group)
            end
          end

          include_examples params[:shared_examples]

          context 'when source is subgroup' do
            let_it_be(:subgroup) { create :group, parent: group }
            let_it_be(:source) { subgroup }

            include_examples params[:shared_examples]
          end

          context 'when source is project' do
            let_it_be(:project) { create(:project, group: group) }
            let_it_be(:source) { project }

            include_examples params[:shared_examples]

            context 'when project is within subgroup' do
              let_it_be(:subgroup) { create :group, parent: group }
              let_it_be(:project) { create(:project, group: subgroup) }

              include_examples params[:shared_examples]
            end
          end
        end
      end
    end

    context 'with service account' do
      context 'when the current_user is a service account' do
        it "exposes `is_service_account`" do
          allow(user).to receive(:service_account?).and_return(true)

          expect(entity_hash[:is_service_account]).to eq(true)
        end
      end

      context 'when the current_user is not a service account' do
        it "does not expose `is_service_account`" do
          allow(user).to receive(:service_account?).and_return(false)

          expect(entity_hash.keys).not_to include(:is_service_account)
        end
      end
    end

    private

    def expected_hash(oncall_object)
      {
        name: oncall_object.name,
        url: get_url(oncall_object),
        project_name: oncall_object.project.name,
        project_url: Gitlab::Routing.url_helpers.project_url(oncall_object.project)
      }
    end
  end
end
