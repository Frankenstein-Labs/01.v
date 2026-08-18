# frozen_string_literal: true

require 'spec_helper'

# The presenter is using finders so we must persist records.
# rubocop:disable RSpec/FactoryBot/AvoidCreate
RSpec.describe ApprovalRulePresenter, feature_category: :compliance_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:public_group) { create(:group) }
  let_it_be(:private_group) { create(:group, :private) }

  let(:groups) { [public_group, private_group] }

  subject(:presenter) { described_class.new(rule, current_user: user) }

  describe '#approvers' do
    let_it_be(:private_member) { create(:group_member, group: private_group) }
    let_it_be(:public_member) { create(:group_member, group: public_group) }

    let(:mr_rule) { create(:approval_merge_request_rule, groups: groups) }
    let(:project_rule) { create(:approval_project_rule, groups: groups) }
    let(:group_rule) { create(:approval_group_rule, groups: groups) }
    let(:merge_request) { create(:merge_request) }
    let(:v2_mr_rule) do
      create(:merge_requests_approval_rule,
        :from_merge_request,
        merge_request: merge_request,
        project_id: merge_request.project.id,
        approver_groups: groups
      )
    end

    subject { presenter.approvers }

    shared_examples 'hiding approvers when a group is not visible' do
      context 'when user cannot see one of the groups' do
        it { is_expected.to be_empty }
      end

      context 'when user can see all groups' do
        before_all do
          private_group.add_guest(user)
        end

        it { is_expected.to contain_exactly(user, private_member.user, public_member.user) }
      end
    end

    describe 'hides approvers when a group is not visible' do
      context 'with a group level rule' do
        let(:rule) { group_rule }

        it_behaves_like 'hiding approvers when a group is not visible'
      end

      context 'when the rule is associated with a project' do
        using RSpec::Parameterized::TableSyntax

        where(:rule, :project) do
          ref(:mr_rule)      | lazy { mr_rule.project }
          ref(:project_rule) | lazy { project_rule.project }
          ref(:v2_mr_rule)   | lazy { v2_mr_rule.merge_request.project }
        end

        with_them do
          it_behaves_like 'hiding approvers when a group is not visible'

          context 'when user is a member of the project' do
            before do
              project.add_developer(user)
            end

            it { is_expected.to contain_exactly(private_member.user, public_member.user) }
          end
        end
      end
    end
  end

  describe '#groups' do
    shared_examples 'filtering private group' do
      context 'when user has no access to private group' do
        it 'excludes private group' do
          expect(subject.groups).to contain_exactly(public_group)
        end
      end

      context 'when user has access to private group' do
        it 'includes private group' do
          private_group.add_owner(user)

          expect(subject.groups).to contain_exactly(*groups)
        end
      end
    end

    context 'with project rule' do
      let(:rule) { create(:approval_project_rule, groups: groups) }

      it_behaves_like 'filtering private group'
    end

    context 'with wrapped approval rule' do
      let(:rule) do
        mr_rule = create(:approval_merge_request_rule, groups: groups)
        ApprovalWrappedRule.new(mr_rule.merge_request, mr_rule)
      end

      it_behaves_like 'filtering private group'
    end

    context 'with any_approver rule' do
      let(:rule) { create(:any_approver_rule) }

      it 'contains no groups without raising an error' do
        expect(subject.groups).to be_empty
      end
    end
  end

  describe '#contains_hidden_groups?' do
    shared_examples 'detecting hidden group' do
      context 'when user has no access to private group' do
        it 'excludes private group' do
          expect(subject.contains_hidden_groups?).to be(true)
        end
      end

      context 'when user has access to private group' do
        it 'includes private group' do
          private_group.add_owner(user)

          expect(subject.contains_hidden_groups?).to be(false)
        end
      end
    end

    context 'with project rule' do
      let(:rule) { create(:approval_project_rule, groups: groups) }

      it_behaves_like 'detecting hidden group'
    end

    context 'with wrapped approval rule' do
      let(:rule) do
        mr_rule = create(:approval_merge_request_rule, groups: groups)
        ApprovalWrappedRule.new(mr_rule.merge_request, mr_rule)
      end

      it_behaves_like 'detecting hidden group'
    end

    context 'with any_approver rule' do
      let(:rule) { create(:any_approver_rule) }

      it 'contains no groups without raising an error' do
        expect(subject.contains_hidden_groups?).to be(false)
      end
    end
  end
end
# rubocop:enable RSpec/FactoryBot/AvoidCreate
