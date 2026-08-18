# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Authz::MemberRoleInSharedResource, feature_category: :permissions do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project) }
  let_it_be_with_reload(:invited_group) { create(:group) }

  subject(:klass) do
    Class.new(ApplicationRecord) do
      extend Authz::MemberRoleInSharedResource

      def self.member_role_in_shared_group(user, shared_group, invited_group)
        group_group_links = ::GroupGroupLink.arel_table

        query = group_group_links.join(members).on(
          group_group_links[:shared_with_group_id].eq(invited_group.id)
            .and(group_group_links[:shared_group_id].eq(shared_group.id))
            .and(group_group_links[:shared_with_group_id].eq(members[:source_id]))
            .and(members[:user_id].eq(user.id))
        )
          .project(member_role_id_in_shared_resource(::GroupGroupLink)).to_sql

        results = Member.connection.exec_query query
        results.to_a
      end

      def self.member_role_in_shared_project(user, shared_project, invited_group)
        project_group_links = ::ProjectGroupLink.arel_table

        query = project_group_links.join(members).on(
          project_group_links[:group_id].eq(invited_group.id)
            .and(project_group_links[:project_id].eq(shared_project.id))
            .and(project_group_links[:group_id].eq(members[:source_id]))
            .and(members[:user_id].eq(user.id))
        )
          .project(member_role_id_in_shared_resource(::ProjectGroupLink)).to_sql

        results = Member.connection.exec_query query
        results.to_a
      end

      def self.model_name
        ActiveModel::Name.new(self, nil, 'TestModel')
      end
    end
  end

  describe '#member_role_id_in_shared_resource' do
    let(:user_role) { create(:member_role, base_access_level: user_access, namespace: invited_group) }
    let(:group_role) { create(:member_role, base_access_level: group_access, namespace: group) }

    where(:user_access, :role_in_invited_group, :group_access, :invited_group_role, :member_role) do
      # user's access level in invited group < invited group's access_level
      # result: user's member role in invited group
      10 | nil        | 30 | nil        | nil
      10 | 'assigned' | 30 | nil        | ref(:user_role)
      10 | nil        | 30 | 'assigned' | nil
      10 | 'assigned' | 30 | 'assigned' | ref(:user_role)
      # user's access level in invited group > invited group's access_level
      # result: group's member role in shared group
      30 | nil        | 10 | nil        | nil
      30 | 'assigned' | 10 | nil        | nil
      30 | nil        | 10 | 'assigned' | ref(:group_role)
      30 | 'assigned' | 10 | 'assigned' | ref(:group_role)
      # user's access level in invited group == invited group's access_level
      # result: user's member role in invited group
      10 | nil        | 10 | nil        | nil
      10 | 'assigned' | 10 | nil        | nil
      10 | nil        | 10 | 'assigned' | nil
      10 | 'assigned' | 10 | 'assigned' | ref(:user_role)
    end

    with_them do
      before do
        attrs = { access_level: user_access, user: user, group: invited_group }
        attrs[:member_role] = user_role unless role_in_invited_group.nil?
        create(:group_member, attrs)
      end

      context 'with a shared group' do
        before do
          attrs = { group_access: group_access, shared_group: group, shared_with_group: invited_group }
          attrs[:member_role] = group_role unless invited_group_role.nil?
          create(:group_group_link, attrs)
        end

        it 'returns the correct member_role_id value' do
          result = klass.member_role_in_shared_group(user, group, invited_group)

          expect(result.first["member_role_id"]).to eq member_role&.id
        end
      end

      context 'with a shared project' do
        before do
          attrs = { group_access: group_access, project: project, group: invited_group }
          attrs[:member_role] = group_role unless invited_group_role.nil?
          create(:project_group_link, attrs)
        end

        it 'returns the correct member_role_id value' do
          result = klass.member_role_in_shared_project(user, project, invited_group)

          expect(result.first["member_role_id"]).to eq member_role&.id
        end
      end
    end
  end
end
