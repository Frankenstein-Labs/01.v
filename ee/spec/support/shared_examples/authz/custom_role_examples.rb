# frozen_string_literal: true

RSpec.shared_examples 'permission is allowed/disallowed with feature enabled' do
  with_them do
    context 'when feature is enabled' do
      before do
        stub_licensed_features(license => true)
      end

      it { is_expected.to be_disallowed(permission) }

      context 'when admin mode enabled', :enable_admin_mode do
        let(:current_user) { admin }

        it { is_expected.to be_allowed(permission) }
      end

      context 'when admin mode disabled' do
        let(:current_user) { admin }

        it { is_expected.to be_disallowed(permission) }
      end
    end

    context 'when feature is disabled' do
      let(:current_user) { admin }

      before do
        stub_licensed_features(license => false)
      end

      context 'when admin mode enabled', :enable_admin_mode do
        it { is_expected.to be_disallowed(permission) }
      end
    end
  end
end

RSpec.shared_examples 'custom role create service returns error' do
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }
  let(:audit_entity_id) { nil } # instance-scoped events are not tied to an entity record

  it 'is not successful' do
    expect(create_role).to be_error
  end

  it 'returns the correct error messages' do
    expect(create_role.message).to include(error_message)
  end

  it 'does not create the role' do
    expect { create_role }.not_to change { role_class.count }
  end

  it 'does not log an audit event' do
    expect { create_role }.not_to change { AuditEventReader.count }
  end
end

RSpec.shared_examples 'custom role creation' do
  let(:audit_entity_id) { nil } # instance-scoped events are not tied to an entity record
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }
  let(:audit_event_message) { 'Member role was created' }
  let(:audit_event_type) { 'member_role_created' }

  context 'with valid params' do
    it 'is successful' do
      expect(create_role).to be_success
    end

    it 'returns the object with assigned attributes' do
      expect(create_role.payload.name).to eq(role_name)
    end

    it 'creates the role correctly' do
      expect { create_role }.to change { role_class.count }.by(1)

      role = role_class.last
      expect(role.name).to eq(role_name)
      expect(role.organization).to eq(expected_organization)
      expect(role.permissions.select { |_k, v| v }.symbolize_keys).to eq(abilities)
    end

    include_examples 'audit event logging' do
      let(:licensed_features_to_stub) { { custom_roles: true } }
      let(:operation) { create_role.payload }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: audit_entity_id,
          entity_type: audit_entity_type,
          details: {
            author_name: user.name,
            event_name: audit_event_type,
            target_id: operation.id,
            target_type: operation.class.name,
            target_details: {
              name: operation.name,
              description: operation.description,
              abilities: abilities.keys.join(', ')
            }.to_s,
            custom_message: audit_event_message,
            author_class: user.class.name
          }
        }
      end
    end
  end
end

RSpec.shared_examples 'custom role update' do
  let(:audit_event_message) { 'Member role was updated' }
  let(:audit_event_type) { 'member_role_updated' }
  let(:audit_entity_id) { nil } # instance-scoped events are not tied to an entity record
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

  context 'with valid params' do
    it 'is successful' do
      expect(result).to be_success
    end

    it 'updates the provided (permitted) attributes' do
      expect { result }
        .to change { role.reload.name }.to(role_name)
        .and change { role.reload.permissions[existing_abilities.each_key.first.to_s] }.to(nil)
    end

    it 'does not update unpermitted attributes' do
      if role.respond_to?(:base_access_level)
        expect { result }.not_to change {
          role.reload.base_access_level
        }
      end
    end

    include_examples 'audit event logging' do
      let(:licensed_features_to_stub) { { custom_roles: true } }
      let(:operation) { result }
      let(:fail_condition!) { allow(role).to receive(:save).and_return(false) }

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: audit_entity_id,
          entity_type: audit_entity_type,
          details: {
            author_name: user.name,
            event_name: audit_event_type,
            target_id: role.id,
            target_type: role.class.name,
            target_details: {
              name: role_name,
              description: role_description,
              abilities: updated_abilities.filter { |_, v| v }.keys.sort.join(', ')
            }.to_s,
            custom_message: audit_event_message,
            author_class: user.class.name
          }
        }
      end
    end
  end

  context 'when member role can not be updated' do
    before do
      error_messages = double

      allow(role).to receive_messages(save: false, errors: error_messages)
      allow(error_messages).to receive(:full_messages).and_return(['this is wrong'])
    end

    it 'is not successful' do
      expect(result).to be_error
    end

    it 'includes the object errors' do
      expect(result.message).to eq('this is wrong')
    end

    it 'does not log an audit event' do
      expect { result }.not_to change { AuditEventReader.count }
    end
  end
end

RSpec.shared_examples 'deleting a role' do
  let(:audit_event_message) { 'Member role was deleted' }
  let(:audit_event_type) { 'member_role_deleted' }
  let(:audit_event_abilities) { 'read_code' }
  let(:audit_entity_id) { nil } # instance-scoped events are not tied to an entity record
  let(:audit_entity_type) { 'Gitlab::Audit::InstanceScope' }

  it 'is successful' do
    expect(result).to be_success
  end

  it 'deletes the role' do
    result

    expect(role).to be_destroyed
  end

  context 'when failing to delete the role' do
    before do
      errors = ActiveModel::Errors.new(role).tap { |e| e.add(:base, 'error message') }
      allow(role).to receive_messages(destroy: false, errors: errors)
    end

    it 'returns an error message' do
      expect(result).to be_error
      expect(result.message).to eq('error message')
    end

    it 'does not log an audit event' do
      expect { result }.not_to change { AuditEventReader.count }
    end
  end

  include_examples 'audit event logging' do
    let(:licensed_features_to_stub) { { custom_roles: true } }
    let(:event_type) { audit_event_type }
    let(:operation) { result }
    let(:fail_condition!) { allow(role).to receive(:destroy).and_return(false) }

    let(:attributes) do
      {
        author_id: user.id,
        entity_id: audit_entity_id,
        entity_type: audit_entity_type,
        details: {
          author_name: user.name,
          target_id: role.id,
          target_type: role.class.name,
          event_name: audit_event_type,
          target_details: {
            name: role.name,
            description: role.description,
            abilities: audit_event_abilities
          }.to_s,
          custom_message: audit_event_message,
          author_class: user.class.name
        }
      }
    end
  end
end

RSpec.shared_examples 'tracking custom role action' do |action|
  it 'tracks internal event and increments the metrics', :clean_gitlab_redis_shared_state do
    event_name = "#{action}_custom_role"

    expect { subject }.to trigger_internal_events(event_name).with(
      user: user,
      namespace: namespace,
      project: nil
    ).and increment_usage_metrics(
      "redis_hll_counters.count_distinct_user_id_from_#{event_name}_monthly",
      "redis_hll_counters.count_distinct_user_id_from_#{event_name}_weekly",
      "counts.count_total_#{event_name}_monthly",
      "counts.count_total_#{event_name}_weekly",
      "counts.count_total_#{event_name}"
    )
  end
end

RSpec.shared_examples 'does not call custom role query' do |roles|
  before do
    stub_licensed_features(custom_roles: true)

    if defined?(licensed_features)
      stub_licensed_features(licensed_features)
    end
  end

  where(role: roles)

  with_them do
    let(:current_user) { create(:user, "#{role}_of": resource_parent) }

    let(:allowed_ability) do
      if defined?(member_role_abilities)
        member_role_abilities.keys.last
      else
        ability
      end
    end

    subject(:allowed) { Ability.allowed?(current_user, allowed_ability, resource, cache: {}) }

    it 'detects zero queries to the projects & groups preloader', :use_sql_query_cache do
      recorder = ActiveRecord::QueryRecorder.new(skip_cached: false) { allowed }

      project_preloader_invocations = recorder.find_query(/.*user_member_roles_in_projects_preloader.rb.*/, 0)
      group_preloader_invocations = recorder.find_query(/.*user_member_roles_in_groups_preloader.rb.*/, 0)

      expect(project_preloader_invocations).to be_empty
      expect(group_preloader_invocations).to be_empty
    end
  end
end

# Usage:
#
# include_context 'with custom role in group'
#
# describe 'custom role with the read_vulnerability ability' do
#   let(:member_role_abilities) { { read_vulnerability: true } }
#   let(:licensed_features) { { security_dashboard: true } }
#
#   let(:allowed_abilities) { [:read_vulnerability, :read_group_security_dashboard] }
#   let(:disallowed_abilities) { [:admin_vulnerability, :read_dependency] }
#
#   it_behaves_like 'custom roles abilities'
#
#   it_behaves_like 'does not call custom role query', [:developer, :maintainer, :owner]
# end
RSpec.shared_context 'with custom role in group' do
  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:minimal_access_user, freeze: false) { create(:user) }
  let_it_be(:parent_group, freeze: false) { create(:group) }
  let_it_be(:group, freeze: false) { create(:group, parent: parent_group) }
  let_it_be(:resource, freeze: false) { parent_group }
  let_it_be(:resource_parent, freeze: false) { resource.root_ancestor }

  let_it_be(:parent_group_member_guest, freeze: false) do
    create(
      :group_member,
      user: guest,
      source: parent_group,
      access_level: Gitlab::Access::GUEST
    )
  end

  let_it_be(:group_member_guest, freeze: false) do
    create(
      :group_member,
      user: guest,
      source: group,
      access_level: Gitlab::Access::GUEST
    )
  end

  let_it_be(:parent_group_member_minimal_access, freeze: false) do
    create(:group_member, :minimal_access, user: minimal_access_user, source: parent_group)
  end

  let_it_be(:group_member_minimal_access, freeze: false) do
    create(:group_member, :minimal_access, user: minimal_access_user, source: group)
  end

  let(:member_role_abilities) { {} }
  let(:allowed_abilities) { [] }
  let(:disallowed_abilities) { [] }
  let(:licensed_features) { {} }
  let(:current_user) { guest }

  def create_member_role(member, abilities = member_role_abilities, minimal_access: false)
    trait = minimal_access ? :minimal_access : :guest
    role = create(:member_role, trait, abilities.merge(namespace: parent_group))
    member.update_columns(member_role_id: role.id)
    ::Authz::UserGroupMemberRoles::UpdateForGroupService.new(member).execute
    role
  end

  shared_examples 'custom roles abilities' do |minimal_access: false|
    let(:custom_role_user) { minimal_access ? minimal_access_user : guest }
    let(:custom_role_group_member) { minimal_access ? group_member_minimal_access : group_member_guest }
    let(:custom_role_parent_group_member) do
      minimal_access ? parent_group_member_minimal_access : parent_group_member_guest
    end

    let(:current_user) { custom_role_user }

    subject { described_class.new(current_user, group) }

    context 'without custom_roles license disabled' do
      before do
        create_member_role(custom_role_group_member, minimal_access: minimal_access)

        stub_licensed_features(licensed_features.merge(custom_roles: false))
      end

      it { expect_disallowed(*allowed_abilities) }
    end

    context 'with custom_roles license enabled' do
      before do
        stub_licensed_features(licensed_features.merge(custom_roles: true))
      end

      context 'with custom role for parent group membership' do
        context 'when a role enables the abilities' do
          before do
            create_member_role(custom_role_parent_group_member, minimal_access: minimal_access)
          end

          it { expect_allowed(*allowed_abilities) }
          it { expect_disallowed(*disallowed_abilities) }
        end

        context 'when a role does not enable the abilities' do
          it { expect_disallowed(*allowed_abilities) }
        end
      end

      context 'with custom role on group membership' do
        context 'when a role enables the abilities' do
          before do
            create_member_role(custom_role_group_member, minimal_access: minimal_access)
          end

          it { expect_allowed(*allowed_abilities) }
          it { expect_disallowed(*disallowed_abilities) }
        end

        context 'when a role does not enable the abilities' do
          it { expect_disallowed(*allowed_abilities) }
        end
      end
    end
  end
end

# Usage:
#
# include_context 'with custom role in project'
#
# describe 'custom role with the admin_terraform_state ability' do
#   let(:member_role_abilities) { { admin_terraform_state: true } }
#   let(:allowed_abilities) { [:read_terraform_state, :admin_terraform_state] }
#
#   it_behaves_like 'custom roles abilities'
#
#   it_behaves_like 'does not call custom role query', [:maintainer, :owner]
# end
RSpec.shared_context 'with custom role in project' do
  let_it_be(:guest, freeze: false) { create(:user) }
  let_it_be(:project, freeze: false) { private_project_in_group }
  let_it_be(:resource, freeze: false) { private_project_in_group }
  let_it_be(:resource_parent, freeze: false) { resource.root_ancestor }
  let_it_be(:group_member_guest, freeze: false) do
    create(
      :group_member,
      user: guest,
      source: project.group,
      access_level: Gitlab::Access::GUEST
    )
  end

  let_it_be(:project_member_guest, freeze: false) do
    create(
      :project_member,
      :guest,
      user: guest,
      project: project,
      access_level: Gitlab::Access::GUEST
    )
  end

  let(:member_role_abilities) { {} }
  let(:allowed_abilities) { [] }
  let(:disallowed_abilities) { [] }
  let(:current_user) { guest }
  let(:licensed_features) { {} }

  subject { described_class.new(current_user, project) }

  before do
    stub_licensed_features(custom_roles: true)
  end

  def create_member_role(member, abilities = member_role_abilities)
    params = abilities.merge(namespace: project.group, members: [member])
    create(:member_role, :guest, params)
  end

  shared_examples 'custom roles abilities' do
    context 'with custom_roles license disabled' do
      before do
        create_member_role(group_member_guest)

        stub_licensed_features(licensed_features.merge(custom_roles: false))
      end

      it { expect_disallowed(*allowed_abilities) }
    end

    context 'with custom_roles license enabled' do
      before do
        stub_licensed_features(licensed_features.merge(custom_roles: true))
      end

      context 'with custom role for parent group' do
        context 'when a role enables the abilities' do
          before do
            create_member_role(group_member_guest)
          end

          it { expect_allowed(*allowed_abilities) }
          it { expect_disallowed(*disallowed_abilities) }
        end

        context 'when a role does not enable the abilities' do
          it { expect_disallowed(*allowed_abilities) }
        end
      end

      context 'with custom role on project membership' do
        context 'when a role enables the abilities' do
          before do
            create_member_role(project_member_guest)
          end

          it { expect_allowed(*allowed_abilities) }
          it { expect_disallowed(*disallowed_abilities) }
        end

        context 'when a role does not enable the abilities' do
          it { expect_disallowed(*allowed_abilities) }
        end
      end
    end
  end
end
