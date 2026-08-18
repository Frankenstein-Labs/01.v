# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::CreateService, '#execute', feature_category: :groups_and_projects do
  let_it_be_with_reload(:user) { create(:user) }
  let_it_be_with_reload(:organization) { create(:organization, users: [user]) }
  let(:current_user) { user }
  let(:group_params) do
    {
      name: 'GitLab',
      path: 'group_path',
      visibility_level: Gitlab::VisibilityLevel::PUBLIC,
      organization_id: organization.id
    }.merge(extra_params)
  end

  let(:extra_params) { {} }
  let(:created_group) { response[:group] }

  subject(:response) { described_class.new(current_user, group_params).execute }

  context 'for audit events' do
    include_examples 'audit event logging' do
      let_it_be(:event_type) { Groups::CreateService::AUDIT_EVENT_TYPE }
      let(:operation) { response }
      let(:fail_condition!) do
        allow(Gitlab::VisibilityLevel).to receive(:allowed_for?).and_return(false)
      end

      let(:attributes) do
        {
          author_id: user.id,
          entity_id: created_group.id,
          entity_type: 'Group',
          details: {
            author_name: user.name,
            event_name: "group_created",
            target_id: created_group.id,
            target_type: 'Group',
            target_details: created_group.full_path,
            custom_message: Groups::CreateService::AUDIT_EVENT_MESSAGE,
            author_class: user.class.name
          }
        }
      end
    end
  end

  context 'for cache invalidation', :use_clean_rails_memory_store_caching do
    it 'invalidates the free group upgrade link cache' do
      cache_key = ['users', user.id, 'free_group_upgrade_link']
      GitlabSubscriptions::FreeGroupUpgradeLinkCache.get(user.id) { 'cached_value' }

      response

      expect(Rails.cache.read(cache_key)).to be_nil
    end
  end

  context 'when created group is a sub-group' do
    let_it_be(:group) { create(:group, organization: organization, owners: user) }
    let(:extra_params) { { parent_id: group.id } }

    include_examples 'sends streaming audit event'

    describe 'handling of allow_runner_registration_token' do
      context 'when on SaaS', :saas do
        it 'uses the default value for column' do
          expect(created_group.allow_runner_registration_token).to eq true
        end
      end
    end
  end

  context 'when user has exceed the top-level group creation limit', :saas_enforce_top_level_group_limits,
    time_travel_to: User::FREE_USER_TOP_LEVEL_GROUP_LIMIT_FROM_DATE + 1.day do
    let(:user) { create(:user) }
    let(:extra_params) { { parent_id: nil } }

    before do
      organization.add_owner(user)
      create_list(:group, User::FREE_USER_TOP_LEVEL_GROUP_LIMIT, creator: user)
    end

    it 'does not create the group', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with({
        message: 'User has reached group creation limit',
        reason: 'Top-level group limit exceeded',
        class: 'Groups::CreateService',
        username: user.username
      })
      expect { response }.not_to change { Group.count }
      expect(response).to be_error
      expect(response[:group].errors[:base].first)
        .to eq(s_("CreateGroup|You have reached the limit of three top-level groups. " \
          "To create another group, reduce the number of groups you have, or upgrade to a paid tier."))
    end
  end

  context 'when user has exceed the identity verification top-level group creation limit' do
    before do
      allow(user).to receive(:requires_identity_verification_to_create_group?).and_return(true)
    end

    it 'does not create the group', :aggregate_failures do
      expect(Gitlab::AppLogger).to receive(:info).with({
        message: 'User has reached group creation limit',
        reason: 'Identity verification required',
        class: 'Groups::CreateService',
        username: user.username
      })
      expect { response }.not_to change { Group.count }
      expect(response).to be_error
      expect(response[:group].errors[:identity_verification].first)
        .to eq(s_('CreateGroup|You have reached the group limit until you verify your account.'))
    end
  end

  context 'for repository_size_limit assignment as Bytes' do
    let_it_be(:admin_user) { create(:admin) }

    context 'when the user is an admin with admin mode enabled', :enable_admin_mode do
      let(:current_user) { admin_user }

      context 'when the param is present' do
        let(:extra_params) { { repository_size_limit: '100' } }

        it 'assigns repository_size_limit as Bytes' do
          expect(created_group.repository_size_limit).to eql(100 * 1024 * 1024)
        end
      end

      context 'when the param is an empty string' do
        let(:extra_params) { { repository_size_limit: '' } }

        it 'assigns a nil value' do
          expect(created_group.repository_size_limit).to be_nil
        end
      end
    end

    context 'when the user is an admin with admin mode disabled' do
      let(:extra_params) { { repository_size_limit: '100' } }
      let(:current_user) { admin_user }

      it 'assigns a nil value' do
        expect(created_group.repository_size_limit).to be_nil
      end
    end

    context 'when the user is not an admin' do
      let(:extra_params) { { repository_size_limit: '100' } }

      it 'assigns a nil value' do
        expect(created_group.repository_size_limit).to be_nil
      end
    end
  end

  context 'when updating protected params' do
    let(:extra_params) do
      { shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 100 }
    end

    context 'as an admin' do
      let_it_be(:current_user) { create(:admin) }

      it 'updates the attributes' do
        expect(created_group.shared_runners_minutes_limit).to eq(1000)
        expect(created_group.extra_shared_runners_minutes_limit).to eq(100)
      end
    end

    context 'as a regular user' do
      it 'ignores the attributes' do
        expect(created_group.shared_runners_minutes_limit).to be_nil
        expect(created_group.extra_shared_runners_minutes_limit).to be_nil
      end
    end
  end

  context 'with push rule' do
    context 'when feature is available' do
      before do
        stub_licensed_features(push_rules: true)
      end

      context 'when there are push rules settings' do
        let_it_be(:sample) { create(:organization_push_rule, organization_id: organization.id) }

        it 'uses the configured push rules settings' do
          expect(created_group.group_push_rule).to be_nil
          expect(created_group.predefined_push_rule).to eq(sample)
        end
      end

      context 'when there are not push rules settings' do
        it 'is does not create the group push rule' do
          expect(created_group.group_push_rule).to be_nil
        end
      end
    end

    context 'when feature not is available' do
      before do
        stub_licensed_features(push_rules: false)
      end

      it 'ignores the group push rule' do
        expect(created_group.group_push_rule).to be_nil
      end
    end
  end

  describe 'seeding work item type visibility defaults' do
    let_it_be(:root) { create(:group) }
    let_it_be(:issue_type_id) { create(:work_item_system_defined_type, :issue).id }

    let(:group_params) do
      {
        name: 'Child Group',
        path: 'child-group',
        visibility_level: Gitlab::VisibilityLevel::PUBLIC,
        organization_id: root.organization_id,
        parent_id: root.id
      }
    end

    before_all do
      root.add_owner(user)
    end

    before do
      stub_saas_features(namespace_scoped_work_item_types: true)
    end

    context 'when visibility defaults are configured' do
      before do
        create(:work_item_settings, namespace: root, customizable_type_visibility: true)
        create(:work_item_type_visibility_default, namespace: root,
          work_item_type_id: issue_type_id, enabled: false)
      end

      it 'seeds visibility rows on the new group' do
        expect { response }.to change { WorkItems::TypesFramework::Visibility.count }.by(1)

        new_group = response[:group]
        row = WorkItems::TypesFramework::Visibility.find_by(namespace: new_group, work_item_type_id: issue_type_id)
        expect(row.enabled).to be false
      end
    end
  end

  describe 'handling of allow_runner_registration_token default' do
    context 'when on SaaS', :saas do
      it 'disallows runner registration tokens' do
        expect(created_group.allow_runner_registration_token?).to eq false
      end
    end
  end
end
