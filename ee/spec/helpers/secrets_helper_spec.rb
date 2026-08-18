# frozen_string_literal: true

require "spec_helper"

RSpec.describe SecretsHelper, feature_category: :secrets_management do
  let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need persisted object
  let_it_be(:sub_group) { create(:group, parent: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need persisted object
  let_it_be(:project) { create(:project, group: group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need persisted object
  let_it_be(:owner) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need persisted object
  let_it_be(:maintainer) { create(:user) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need persisted object

  describe '#project_secrets_app_data' do
    subject(:data) { helper.project_secrets_app_data(project) }

    it 'returns expected data' do
      expect(data).to include({
        project_path: project.full_path,
        base_path: project_secrets_path(project)
      })
    end

    it 'returns secrets manager permissions settings path' do
      expect(data[:manage_permissions_path]).to eq(
        edit_project_path(project, anchor: 'js-shared-permissions')
      )
    end

    context 'when on SaaS', :saas do
      it 'includes enrollment_settings_path pointing to the root group settings' do
        expect(data[:enrollment_settings_path]).to eq(
          edit_group_path(project.root_ancestor, anchor: 'js-permissions-settings')
        )
      end
    end

    context 'when on self-managed with instance enrollment allowed' do
      before do
        allow(helper).to receive(:allow_secrets_manager_instance_enrollment?).and_return(true)
      end

      it 'includes enrollment_settings_path pointing to admin settings' do
        expect(data[:enrollment_settings_path]).to eq(
          general_admin_application_settings_path(anchor: 'js-secrets-manager-instance-enrollment-settings')
        )
      end
    end

    context 'when project belongs to a group' do
      it 'returns the top-level group full path' do
        expect(data[:top_level_group_full_path]).to eq(group.full_path)
      end
    end

    context 'when project belongs to a personal namespace' do
      let_it_be(:user_project) { create(:project) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- need persisted object

      it 'returns an empty string for top_level_group_full_path' do
        expect(helper.project_secrets_app_data(user_project)[:top_level_group_full_path]).to eq('')
      end
    end
  end

  describe '#group_secrets_app_data' do
    subject(:data) { helper.group_secrets_app_data(group) }

    it 'returns expected data' do
      expect(data).to include({
        group_path: group.full_path,
        base_path: group_secrets_path(group),
        top_level_group_full_path: group.full_path
      })
    end

    it 'returns secrets manager permissions settings path' do
      expect(data[:manage_permissions_path]).to eq(
        edit_group_path(group, anchor: 'js-permissions-settings')
      )
    end

    context 'when group is already top-level' do
      subject(:group_data) { helper.group_secrets_app_data(group) }

      it 'returns the group full path' do
        expect(group_data[:top_level_group_full_path]).to eq(group.full_path)
      end
    end

    context 'when group is a sub-group' do
      subject(:sub_group_data) { helper.group_secrets_app_data(sub_group) }

      it 'returns the top-level group full path' do
        expect(sub_group_data[:top_level_group_full_path]).to eq(group.full_path)
      end
    end

    context 'when on SaaS', :saas do
      it 'includes enrollment_settings_path pointing to the root group settings' do
        expect(data[:enrollment_settings_path]).to eq(
          edit_group_path(group, anchor: 'js-permissions-settings')
        )
      end

      context 'when group is a sub-group' do
        subject(:sub_group_data) { helper.group_secrets_app_data(sub_group) }

        it 'includes enrollment_settings_path pointing to the root group settings' do
          expect(sub_group_data[:enrollment_settings_path]).to eq(
            edit_group_path(group, anchor: 'js-permissions-settings')
          )
        end
      end
    end

    context 'when on self-managed with instance enrollment allowed' do
      before do
        allow(helper).to receive(:allow_secrets_manager_instance_enrollment?).and_return(true)
      end

      it 'includes enrollment_settings_path pointing to admin application settings' do
        expect(data[:enrollment_settings_path]).to eq(
          general_admin_application_settings_path(anchor: 'js-secrets-manager-instance-enrollment-settings')
        )
      end
    end
  end

  describe '#instance_secrets_manager_enrollment_data' do
    subject(:data) { helper.instance_secrets_manager_enrollment_data }

    it 'returns the path of any root group' do
      expect(data[:top_level_group_full_path]).to eq(group.path)
    end

    context 'when no root group exists' do
      before do
        allow(Group).to receive(:where).and_call_original
        allow(Group).to receive(:where).with(parent_id: nil).and_return(Group.none)
      end

      it 'returns an empty string' do
        expect(data[:top_level_group_full_path]).to eq('')
      end
    end
  end

  describe '#namespace_enrollment_data' do
    before_all do
      group.add_owner(owner)
      group.add_maintainer(maintainer)
    end

    subject(:group_enrollment) { helper.namespace_enrollment_data(group, owner) }

    it 'returns expected data' do
      expect(group_enrollment).to include({
        full_path: group.full_path,
        group_path_regex: JsRegex.new(Gitlab::PathRegex::FULL_NAMESPACE_FORMAT_REGEX).source,
        is_namespace_enrollable: 'false',
        top_level_group_full_path: group.full_path
      })
    end

    context 'when user is a maintainer of the group', :saas do
      subject(:group_enrollment_with_maintainer) { helper.namespace_enrollment_data(group, maintainer) }

      it 'sets correct permissions' do
        expect(group_enrollment_with_maintainer).to include({
          can_manage_secrets_manager: 'false',
          can_enroll_namespace: 'false'
        })
      end
    end

    context 'when user is the owner' do
      using RSpec::Parameterized::TableSyntax

      # only enrollable when SaaS + top-level group
      where(:is_saas, :namespace, :expected_enrollable) do
        true  | ref(:group)     | 'true'
        true  | ref(:sub_group) | 'false'
        false | ref(:group)     | 'false'
        false | ref(:sub_group) | 'false'
      end

      with_them do
        before do
          allow(Gitlab).to receive(:com?).and_return(is_saas) # -- testing Gitlab.com? behavior directly
        end

        subject(:group_enrollment_with_owner) { helper.namespace_enrollment_data(namespace, owner) }

        it 'returns correct is_namespace_enrollable' do
          expect(group_enrollment_with_owner).to include(is_namespace_enrollable: expected_enrollable)
        end

        it 'returns top_level_group_full_path pointing to root ancestor' do
          expect(group_enrollment_with_owner).to include(
            top_level_group_full_path: group.full_path
          )
        end
      end
    end
  end
end
