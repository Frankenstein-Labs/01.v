# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Projects::GroupLinks::CreateService, '#execute', feature_category: :groups_and_projects do
  include ProjectForksHelper

  let_it_be(:user) { create :user }
  let_it_be(:project) { create(:project, namespace: create(:namespace, :with_namespace_settings)) }
  let_it_be(:group) { create(:group, visibility_level: 0) }

  let(:opts) do
    {
      link_group_access: '30',
      expires_at: nil
    }
  end

  before do
    project.add_owner(user)
  end

  context 'audit events' do
    include_examples 'audit event logging' do
      let(:operation) { create_group_link(user, project, group, opts) }
      let(:fail_condition!) do
        create(:project_group_link, project: project, group: group)
      end

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: group.id,
          entity_type: 'Group',
          details: {
            add: 'project_access',
            as: 'Developer',
            author_name: user.name,
            author_class: 'User',
            custom_message: 'Added project group link',
            event_name: 'project_group_link_created',
            target_id: project.id,
            target_type: 'Project',
            target_details: project.full_path
          }
        }
      end
    end

    it 'sends the audit streaming event' do
      audit_context = {
        name: 'project_group_link_created',
        author: user,
        scope: group,
        target: project,
        target_details: project.full_path,
        message: 'Added project group link',
        additional_details: {
          add: 'project_access',
          as: 'Developer'
        }
      }
      expect(::Gitlab::Audit::Auditor).to receive(:audit).with(audit_context)

      create_group_link(user, project, group, opts)
    end
  end

  context 'when project is in sso enforced group' do
    let_it_be(:saml_provider) { create(:saml_provider, enforced_sso: true) }
    let_it_be(:root_group) { saml_provider.group }
    let_it_be(:identity) { create(:group_saml_identity, saml_provider: saml_provider) }
    let_it_be(:user) { identity.user }
    let_it_be_with_reload(:project) { create(:project, :private, group: root_group) }

    subject { described_class.new(project, group_to_invite, user, opts) }

    before do
      group_to_invite&.add_developer(user)
      stub_licensed_features(group_saml: true)
    end

    context 'when invited group is outside top group' do
      let(:group_to_invite) { create(:group) }

      it 'does not add group to project' do
        expect { subject.execute }.not_to change { project.project_group_links.count }
      end
    end

    context 'when invited group is in the top group' do
      let(:group_to_invite) { create(:group, parent: root_group) }

      it 'adds group to project' do
        expect { subject.execute }.to change { project.project_group_links.count }.from(0).to(1)
      end
    end

    context 'when project is deeper in the hierarchy and group is in the top group' do
      let(:group_to_invite) { create(:group, parent: root_group) }
      let(:nested_group) { create(:group, parent: root_group) }
      let(:nested_group_2) { create(:group, parent: nested_group_2) }
      let(:project) { create(:project, :private, group: nested_group) }

      it 'adds group to project' do
        expect { subject.execute }.to change { project.project_group_links.count }.from(0).to(1)
      end

      context 'when invited group is outside top group' do
        let(:group_to_invite) { create(:group) }

        it 'does not add group to project' do
          expect { subject.execute }.not_to change { project.project_group_links.count }
        end
      end
    end

    context 'when project is forked from group with enforced SSO' do
      let(:forked_project) { create(:project, namespace: create(:namespace, :with_namespace_settings)) }

      before do
        root_group.add_developer(user)
        forked_project.add_owner(user)

        fork_project(project, user, target_project: forked_project)
      end

      subject { described_class.new(forked_project, group_to_invite, user, opts) }

      context 'when invited group is outside top group' do
        let_it_be(:group_to_invite) { create(:group) }

        it 'does not add group to project' do
          expect { subject.execute }.not_to change { forked_project.project_group_links.count }
        end

        it 'returns error status and message' do
          result = subject.execute

          expect(result[:message]).to eq('This group cannot be invited to a project inside a group with enforced SSO')
          expect(result[:status]).to eq(:error)
        end
      end

      context 'when invited group is in the top group' do
        let(:group_to_invite) { create(:group, parent: root_group) }

        it 'adds group to project' do
          expect { subject.execute }.to change { forked_project.project_group_links.count }.from(0).to(1)

          group_link = forked_project.project_group_links.first

          expect(group_link.group_id).to eq(group_to_invite.id)
          expect(group_link.project_id).to eq(forked_project.id)
        end
      end

      context 'when group to invite is missing' do
        let(:group_to_invite) { nil }

        it 'returns error status and message' do
          result = subject.execute

          expect(result[:message]).to eq('Not Found')
          expect(result[:status]).to eq(:error)
        end
      end
    end

    context 'when project is forked to group with enforced sso' do
      let_it_be(:source_project) { create(:project) }

      before do
        source_project.add_developer(user)

        fork_project(source_project, user, target_project: project)
      end

      context 'when invited group is outside top group' do
        let(:group_to_invite) { create(:group) }

        it 'does not add group to project' do
          expect { subject.execute }.not_to change { project.project_group_links.count }
        end
      end

      context 'when invited group is in the top group' do
        let(:group_to_invite) { create(:group, parent: root_group) }

        it 'adds group to project' do
          expect { subject.execute }.to change { project.project_group_links.count }.from(0).to(1)

          group_link = project.project_group_links.first

          expect(group_link.group_id).to eq(group_to_invite.id)
          expect(group_link.project_id).to eq(project.id)
        end
      end
    end
  end

  context 'with member_role_id param', :saas do
    let_it_be(:group) { create(:group_with_plan, :private, plan: :free_plan) }

    let_it_be(:paid_group) { create(:group_with_plan, plan: :ultimate_plan) }
    let_it_be(:project) { create(:project, namespace: paid_group) }

    let(:member_role) { create(:member_role, namespace: paid_group) }
    let(:opts) { super().merge({ member_role_id: member_role.id }) }

    subject(:service) { described_class.new(project, group, user, opts) }

    before_all do
      group.add_developer(user)
    end

    before do
      stub_licensed_features(custom_roles: true)
      stub_ee_application_setting(should_check_namespace_plan: true)
    end

    shared_examples_for 'does not assign the member role' do
      specify do
        result = service.execute

        expect(result[:status]).to eq(:success)
        expect(result[:link].member_role_id).to be_nil
      end
    end

    context 'and custom roles feature is available on the project' do
      it 'assigns the member role' do
        result = service.execute

        expect(result[:status]).to eq(:success)
        expect(result[:link].member_role_id).to eq(member_role.id)
      end

      context 'and assign_custom_roles_to_project_links_saas feature flag is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_project_links_saas: false)
        end

        it_behaves_like 'does not assign the member role'
      end
    end

    context 'and custom roles feature is not available on the project' do
      before do
        stub_licensed_features(custom_roles: false)
      end

      it_behaves_like 'does not assign the member role'
    end

    describe "Authz::UserProjectMemberRole records of the invited group's members" do
      it 'enqueues an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job' do
        allow(::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker).to receive(:perform_async)

        link_id = service.execute[:link][:id]

        expect(::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker)
          .to have_received(:perform_async).with(link_id)
      end

      context 'when cache_user_project_member_roles feature flag is disabled' do
        before do
          stub_feature_flags(cache_user_project_member_roles: false)
        end

        it 'does not enqueue an ::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker job' do
          expect(::Authz::UserProjectMemberRoles::UpdateForSharedProjectWorker).not_to receive(:perform_async)

          service.execute
        end
      end
    end
  end

  context 'with the licensed feature for disable_invite_members' do
    shared_examples 'successful group link creation' do
      it 'creates a group link' do
        result = described_class.new(project, group, user, opts).execute
        expect(result[:status]).to eq(:success)
      end
    end

    shared_examples 'failed group link creation' do
      it 'does not create a group link' do
        result = described_class.new(project, group, user, opts).execute
        expect(result[:status]).to eq(:error)
      end
    end

    context 'when the user is a project maintainer' do
      before_all do
        group.add_developer(user)
      end

      context 'and the licensed feature is available' do
        before do
          stub_licensed_features(disable_invite_members: true)
        end

        context 'and the setting disable_invite_members is ON' do
          before do
            stub_application_setting(disable_invite_members: true)
          end

          it_behaves_like 'failed group link creation'
        end

        context 'and the setting disable_invite_members is OFF' do
          before do
            stub_application_setting(disable_invite_members: false)
          end

          it_behaves_like 'successful group link creation'
        end
      end

      context 'and the licensed feature is unavailable' do
        before do
          stub_licensed_features(disable_invite_members: false)
          stub_application_setting(disable_invite_members: true)
        end

        it_behaves_like 'successful group link creation'
      end
    end

    context 'when the user is an admin and the setting disable_invite_members is ON' do
      let_it_be(:user) { create(:admin) }

      before do
        stub_licensed_features(disable_invite_members: true)
        stub_application_setting(disable_invite_members: true)
      end

      context 'with admin mode enabled', :enable_admin_mode do
        it_behaves_like 'successful group link creation'
      end

      it_behaves_like 'failed group link creation'
    end
  end

  def create_group_link(user, project, group, opts)
    group.add_developer(user)
    described_class.new(project, group, user, opts).execute
  end
end
