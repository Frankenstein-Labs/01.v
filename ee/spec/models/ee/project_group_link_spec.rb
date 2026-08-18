# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectGroupLink, feature_category: :system_access do
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project_group_link) { create(:project_group_link, project: project, group: group) }

  describe 'scopes' do
    describe '.in_project' do
      it 'provides correct link records' do
        create(:project_group_link)

        expect(described_class.in_project(project)).to match_array([project_group_link])
      end
    end

    describe '.not_in_group' do
      it 'provides correct link records' do
        not_shared_with_group = create(:group)
        create(:project_group_link, project: project, group: not_shared_with_group)

        expect(described_class.not_in_group(not_shared_with_group)).to match_array([project_group_link])
      end
    end
  end

  describe '#destroy' do
    let_it_be(:user, freeze: false) { create(:user) }

    before_all do
      project.add_developer(user)
    end

    shared_examples_for 'deleted related access levels' do |access_level_class|
      it "removes related #{access_level_class}" do
        expect { project_group_link.destroy! }.to change { access_level_class.count }.by(-1)
        expect(access_levels.find_by_group_id(group)).to be_nil
        expect(access_levels.find_by_user_id(user)).to be_persisted
      end
    end

    context 'protected tags' do
      let_it_be(:protected_tag) do
        ProtectedTags::CreateService.new(
          project,
          project.first_owner,
          attributes_for(
            :protected_tag,
            create_access_levels_attributes: [{ group_id: group.id }, { user_id: user.id }]
          )
        ).execute
      end

      let(:access_levels) { protected_tag.create_access_levels }

      it_behaves_like 'deleted related access levels', ProtectedTag::CreateAccessLevel
    end

    context 'protected environments' do
      let_it_be(:protected_environment) do
        ProtectedEnvironments::CreateService.new(
          container: project,
          current_user: project.first_owner,
          params: attributes_for(
            :protected_environment,
            deploy_access_levels_attributes: [{ group_id: group.id }, { user_id: user.id }]
          )
        ).execute
      end

      let(:access_levels) { protected_environment.deploy_access_levels }

      it_behaves_like 'deleted related access levels', ProtectedEnvironments::DeployAccessLevel

      context 'with approval rules' do
        let(:access_levels) { protected_environment.approval_rules }

        before do
          create(:protected_environment_approval_rule, protected_environment: protected_environment, group: group)
          create(:protected_environment_approval_rule, protected_environment: protected_environment, user: user)
        end

        it_behaves_like 'deleted related access levels', ::ProtectedEnvironments::ApprovalRule
      end
    end
  end

  describe '#group_with_allowed_email_domains' do
    let(:shared_project) { create(:project, group: shared_project_group) }

    subject do
      build(:project_group_link, project: shared_project, group: shared_with_group)
    end

    shared_examples 'restricted membership by email domain' do
      context 'shared project group has membership restricted by allowed email domains' do
        before do
          create(:allowed_email_domain, group: shared_project_group.root_ancestor, domain: 'gitlab.com')
          create(:allowed_email_domain, group: shared_project_group.root_ancestor, domain: 'gitlab.cn')
        end

        context 'shared with group with a subset of allowed email domains' do
          before do
            create(:allowed_email_domain, group: shared_with_group.root_ancestor, domain: 'gitlab.com')
          end

          it { is_expected.to be_valid }
        end

        context 'shared with group containing domains outside the shared group allowed email domains' do
          before do
            create(:allowed_email_domain, group: shared_with_group.root_ancestor, domain: 'example.com')
          end

          it { is_expected.to be_invalid }
        end

        context 'shared with group does not have membership restricted by allowed domains' do
          it { is_expected.to be_invalid }
        end
      end

      context 'shared project group does not have membership restricted by allowed domains' do
        context 'shared with group has membership restricted by allowed email domains' do
          before do
            create(:allowed_email_domain, group: shared_with_group.root_ancestor, domain: 'example.com')
          end

          it { is_expected.to be_valid }
        end

        context 'shared with group does not have membership restricted by allowed domains' do
          it { is_expected.to be_valid }
        end
      end
    end

    context 'shared project group is the root ancestor' do
      let_it_be(:shared_project_group) { create(:group) }
      let_it_be(:shared_with_group) { create(:group) }

      it_behaves_like 'restricted membership by email domain'
    end

    context 'shared project group is a subgroup' do
      let_it_be(:shared_project_group) { create(:group, parent: create(:group)) }
      let_it_be(:shared_with_group) { create(:group) }

      it_behaves_like 'restricted membership by email domain'
    end

    context 'shared with group is a subgroup' do
      let_it_be(:shared_project_group) { create(:group) }
      let_it_be(:shared_with_group) { create(:group, parent: create(:group)) }

      it_behaves_like 'restricted membership by email domain'
    end

    context 'shared project group and shared with group are subgroups' do
      let_it_be(:shared_project_group) { create(:group, parent: create(:group)) }
      let_it_be(:shared_with_group) { create(:group, parent: create(:group)) }

      it_behaves_like 'restricted membership by email domain'
    end
  end

  it_behaves_like 'model with member role relation' do
    let_it_be(:link, freeze: false) { create(:project_group_link) }

    let(:expected_member_role_owner) { link.project.namespace }

    subject(:model) { link }
  end

  describe '#human_access' do
    let_it_be(:access_level) { Gitlab::Access::DEVELOPER }
    let_it_be(:member_role, freeze: false) { create(:member_role, base_access_level: access_level) }
    let_it_be(:link, freeze: false) { create(:project_group_link, group_access: access_level) }
    let(:feature_available) { true }

    subject(:result) { link.human_access }

    before do
      allow(link).to receive(:custom_role_for_project_link_enabled?)
        .and_return(feature_available)
    end

    it 'returns access level name' do
      expect(result).to eq('Developer')
    end

    context 'when member role is present' do
      let_it_be(:link, freeze: false) { create(:project_group_link, member_role: member_role) }

      it 'returns the member role\'s name' do
        expect(result).to eq(member_role.name)
      end

      context 'when feature is not available' do
        let(:feature_available) { false }

        it 'returns access level name' do
          expect(result).to eq('Developer')
        end
      end
    end
  end
end
