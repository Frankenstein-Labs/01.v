# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::ItemPolicy, :with_current_organization, feature_category: :workflow_catalog do
  subject(:policy) { described_class.new(current_user, item) }

  let_it_be(:organization_owner) { create(:organization_user, :owner, organization: current_organization).user }
  let_it_be(:developer) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:reporter) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:admin) { create(:admin) }
  let_it_be_with_reload(:project) do
    create(:project, :private, :in_group, guests: guest, reporters: reporter, developers: developer,
      maintainers: maintainer)
  end

  let_it_be_with_reload(:private_item) { create(:ai_catalog_item, project: project) }
  let_it_be_with_reload(:public_item) { create(:ai_catalog_item, :public, project: project) }

  let_it_be_with_reload(:flow_item) do
    create(:ai_catalog_flow, :public, project: project)
  end

  let_it_be_with_reload(:third_party_flow_item) do
    create(:ai_catalog_third_party_flow, :public, project: project)
  end

  let(:ai_catalog_available) { true }
  let(:flows_available) { true }
  let(:third_party_flows_available) { true }
  let(:duo_features_enabled) { true }

  before do
    Current.organization = current_organization
    allow(::Gitlab::Llm::StageCheck)
      .to receive(:available?)
      .with(project, :ai_catalog).and_return(ai_catalog_available)
    allow(::Gitlab::Llm::StageCheck)
      .to receive(:available?)
      .with(project, :ai_catalog_flows).and_return(flows_available)
    allow(::Gitlab::Llm::StageCheck)
      .to receive(:available?)
      .with(project, :ai_catalog_third_party_flows).and_return(third_party_flows_available)
    project.update!(duo_features_enabled: duo_features_enabled)
  end

  shared_examples 'report_ai_catalog_item permission' do |allowed:|
    context 'when abuse_notification_email is present' do
      before do
        stub_application_setting(abuse_notification_email: 'abuse@example.com')
      end

      it { expect(policy.allowed?(:report_ai_catalog_item)).to eq(allowed) }
    end

    context 'when abuse_notification_email is not present' do
      before do
        stub_application_setting(abuse_notification_email: nil)
      end

      it { is_expected.to be_disallowed(:report_ai_catalog_item) }
    end
  end

  shared_examples 'no permissions' do
    it 'disallows all permissions' do
      is_expected.to be_disallowed(:admin_ai_catalog_item)
      is_expected.to be_disallowed(:delete_ai_catalog_item)
      is_expected.to be_disallowed(:read_ai_catalog_item)
      is_expected.to be_disallowed(:restore_ai_catalog_item)
    end

    it_behaves_like 'report_ai_catalog_item permission', allowed: false

    include_examples 'admin permissions when can admin organization'
  end

  shared_examples 'read-only permissions' do
    it 'disallows admin and delete permissions but allows read' do
      is_expected.to be_disallowed(:admin_ai_catalog_item)
      is_expected.to be_disallowed(:delete_ai_catalog_item)
      is_expected.to be_disallowed(:restore_ai_catalog_item)
      is_expected.to be_allowed(:read_ai_catalog_item)
    end

    include_examples 'admin permissions when can admin organization'

    it_behaves_like 'no permissions when StageCheck :ai_catalog is false, unless item is public'
    it_behaves_like 'no permissions when project Duo features disabled, unless item is public'
    it_behaves_like 'read-only permissions with deleted item'
  end

  shared_examples 'read-write permissions' do
    it 'allows admin and delete permissions' do
      is_expected.to be_allowed(:admin_ai_catalog_item)
      is_expected.to be_allowed(:delete_ai_catalog_item)
      is_expected.to be_allowed(:restore_ai_catalog_item)
      is_expected.to be_allowed(:read_ai_catalog_item)
    end

    include_examples 'admin permissions when can admin organization'

    it_behaves_like 'no permissions when StageCheck :ai_catalog is false, unless item is public'
    it_behaves_like 'no permissions when project Duo features disabled, unless item is public'
    it_behaves_like 'read-only permissions with deleted item'
  end

  shared_examples 'admin permissions when can admin organization' do
    context 'when admin', :enable_admin_mode do
      let(:current_user) { admin }

      it 'allows all permissions' do
        is_expected.to be_allowed(:admin_ai_catalog_item)
        is_expected.to be_allowed(:delete_ai_catalog_item)
        is_expected.to be_allowed(:restore_ai_catalog_item)
        is_expected.to be_allowed(:read_ai_catalog_item)
      end
    end

    context 'when organization owner' do
      let(:current_user) { organization_owner }

      it 'allows admin, delete, and read' do
        is_expected.to be_allowed(:admin_ai_catalog_item)
        is_expected.to be_allowed(:delete_ai_catalog_item)
        is_expected.to be_allowed(:restore_ai_catalog_item)
        is_expected.to be_allowed(:read_ai_catalog_item)
      end
    end
  end

  shared_examples 'read-only permissions with deleted item' do
    before do
      item.deleted_at = 1.day.ago
    end

    it 'disallows admin and delete permissions but allows read' do
      is_expected.to be_disallowed(:admin_ai_catalog_item)
      is_expected.to be_disallowed(:delete_ai_catalog_item)
      is_expected.to be_disallowed(:restore_ai_catalog_item)
      is_expected.to be_allowed(:read_ai_catalog_item)
    end

    include_examples 'admin permissions when can admin organization'
  end

  shared_examples 'no permissions when StageCheck :ai_catalog is false, unless item is public' do
    let(:ai_catalog_available) { false }

    it 'disallows admin and delete permissions' do
      is_expected.to be_disallowed(:admin_ai_catalog_item)
      is_expected.to be_disallowed(:delete_ai_catalog_item)
      is_expected.to be_disallowed(:restore_ai_catalog_item)
    end

    it 'is expected not to allow read_ai_catalog_item, unless item is public' do
      allowed = item.visibility_public?

      expect(policy.allowed?(:read_ai_catalog_item)).to eq(allowed)
    end

    include_examples 'admin permissions when can admin organization'
  end

  shared_examples 'no permissions when project Duo features disabled, unless item is public' do
    let(:duo_features_enabled) { false }

    it 'disallows admin and delete permissions' do
      is_expected.to be_disallowed(:admin_ai_catalog_item)
      is_expected.to be_disallowed(:delete_ai_catalog_item)
      is_expected.to be_disallowed(:restore_ai_catalog_item)
    end

    it 'is expected not to allow read_ai_catalog_item, unless item is public' do
      allowed = item.visibility_public?

      expect(policy.allowed?(:read_ai_catalog_item)).to eq(allowed)
    end

    include_examples 'admin permissions when can admin organization'
  end

  context 'when user is not a member' do
    let(:current_user) { create(:user) }

    context 'when project is public' do
      let(:project) { create(:project, :public) }

      context 'with private item' do
        let(:item) { create(:ai_catalog_item, project: project) }

        it_behaves_like 'no permissions'
      end
    end
  end

  context 'when maintainer' do
    let(:current_user) { maintainer }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'read-write permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-write permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  describe 'group-based access control' do
    let(:current_user) { maintainer }
    let(:item) { public_item }

    let_it_be(:membership_rule) do
      create(
        :ai_instance_accessible_entity_rules,
        :duo_agent_platform
      )
    end

    context 'when catalog is available for user' do
      before do
        membership_rule.through_namespace.add_guest(current_user)
      end

      it 'enables the catalog permissions' do
        is_expected.to be_allowed(:admin_ai_catalog_item)
        is_expected.to be_allowed(:delete_ai_catalog_item)
        is_expected.to be_allowed(:restore_ai_catalog_item)
        is_expected.to be_allowed(:read_ai_catalog_item)
      end

      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'when catalog is not available for user' do
      it 'disables the catalog permissions' do
        is_expected.to be_disallowed(:admin_ai_catalog_item)
        is_expected.to be_disallowed(:delete_ai_catalog_item)
        is_expected.to be_disallowed(:restore_ai_catalog_item)
        is_expected.to be_disallowed(:read_ai_catalog_item)
      end

      it_behaves_like 'report_ai_catalog_item permission', allowed: false
    end
  end

  describe 'restricted item visibility' do
    let_it_be_with_reload(:item) { create(:ai_catalog_item, :restricted, project: project) }
    let_it_be(:sibling_project) { create(:project, group: project.group) }
    let_it_be(:insider) { create(:user, developer_of: sibling_project) }
    let_it_be(:outsider) { create(:user) }

    context 'when the user is a member elsewhere in the item TLG hierarchy' do
      let(:current_user) { insider }

      it { is_expected.to be_allowed(:read_ai_catalog_item) }
      it { is_expected.to be_disallowed(:admin_ai_catalog_item) }
      it { is_expected.to be_disallowed(:delete_ai_catalog_item) }
      it { is_expected.to be_disallowed(:restore_ai_catalog_item) }

      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'when the user is a member of the owning project' do
      let(:current_user) { developer }

      it { is_expected.to be_allowed(:read_ai_catalog_item) }
    end

    context 'when the user has no membership in the item TLG hierarchy' do
      let(:current_user) { outsider }

      it { is_expected.to be_disallowed(:read_ai_catalog_item) }

      it_behaves_like 'report_ai_catalog_item permission', allowed: false
    end

    context 'when the user is anonymous' do
      let(:current_user) { nil }

      it { is_expected.to be_disallowed(:read_ai_catalog_item) }
    end

    context 'when ai_catalog_internal_visibility is disabled' do
      before do
        stub_feature_flags(ai_catalog_internal_visibility: false)
      end

      context 'when the user is a member elsewhere in the item TLG hierarchy' do
        let(:current_user) { insider }

        it 'treats the restricted item like a private item' do
          is_expected.to be_disallowed(:read_ai_catalog_item)
        end
      end

      context 'when the user is a member elsewhere in the TLG hierarchy but not the owning project' do
        let(:current_user) { outsider }

        it 'treats the restricted item like a private item' do
          is_expected.to be_disallowed(:read_ai_catalog_item)
        end
      end

      context 'when the user is a member of the owning project' do
        let(:current_user) { developer }

        it { is_expected.to be_allowed(:read_ai_catalog_item) }
      end
    end
  end

  context 'when flow' do
    let(:current_user) { maintainer }
    let(:item) { flow_item }

    it_behaves_like 'read-write permissions'
    it_behaves_like 'report_ai_catalog_item permission', allowed: true

    context 'with ai_catalog_flows is not available' do
      let(:flows_available) { false }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'when duo_custom_flows_enabled is false' do
      before do
        flow_item.project.root_ancestor.namespace_settings.update!(duo_custom_flows_enabled: false)
      end

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  context 'when agent' do
    let(:current_user) { maintainer }
    let(:item) { public_item }

    it_behaves_like 'read-write permissions'

    context 'when duo_custom_agents_enabled is false' do
      before do
        item.project.root_ancestor.namespace_settings.update!(duo_custom_agents_enabled: false)
      end

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  context 'when not flow' do
    let(:current_user) { maintainer }
    let(:item) { public_item }

    it_behaves_like 'read-write permissions'
    it_behaves_like 'report_ai_catalog_item permission', allowed: true
  end

  context 'when third_party_flow' do
    let(:current_user) { maintainer }
    let(:item) { third_party_flow_item }

    it_behaves_like 'read-write permissions'
    it_behaves_like 'report_ai_catalog_item permission', allowed: true

    context 'with ai_catalog_third_party_flow is disabled' do
      before do
        stub_feature_flags(ai_catalog_third_party_flows: false)
      end

      it_behaves_like 'no permissions'
    end

    context 'with ai_catalog_third_party_flows is not available' do
      let(:third_party_flows_available) { false }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'when duo_external_agents_enabled is false' do
      before do
        allow(third_party_flow_item.project.root_ancestor).to receive(:duo_external_agents_enabled).and_return(false)
      end

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  context 'when not third_party_flow' do
    let(:current_user) { maintainer }
    let(:item) { public_item }

    it_behaves_like 'read-write permissions'
    it_behaves_like 'report_ai_catalog_item permission', allowed: true

    context 'with ai_catalog_third_party_flows is disabled' do
      before do
        stub_feature_flags(ai_catalog_third_party_flows: false)
      end

      it_behaves_like 'read-write permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'with ai_catalog_third_party_flows is not available' do
      let(:third_party_flows_available) { false }

      it_behaves_like 'read-write permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  context 'when developer' do
    let(:current_user) { developer }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  context 'when guest' do
    let(:current_user) { guest }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: true
    end
  end

  context 'when anonymous' do
    let(:current_user) { nil }

    context 'with private item' do
      let(:item) { private_item }

      it_behaves_like 'no permissions'
    end

    context 'with public item' do
      let(:item) { public_item }

      it_behaves_like 'read-only permissions'
      it_behaves_like 'report_ai_catalog_item permission', allowed: false
    end
  end
end
