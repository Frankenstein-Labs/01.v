# frozen_string_literal: true

require 'spec_helper'
require_relative './shared_examples/events_tracking'

RSpec.describe Ai::Catalog::ItemConsumers::CreateService, feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers

  let_it_be(:user) { create(:user) }

  let_it_be(:maintainer_user) { create(:user) }

  let_it_be(:group) { create(:group, owners: user, maintainers: maintainer_user, name: "Group name") }

  let_it_be(:consumer_group) { create(:group, owners: user, maintainers: maintainer_user) }
  let_it_be(:consumer_project) { create(:project, group: consumer_group) }

  let_it_be(:item_project) { create(:project, developers: user) }

  let_it_be_with_reload(:flow_item) do
    create(:ai_catalog_flow, :public, project: item_project, name: 'item_name')
  end

  let_it_be(:released_flow_version) do
    create(:ai_catalog_flow_version, :released, item: flow_item, version: '3.2.1')
  end

  let_it_be_with_reload(:agent_item) { create(:ai_catalog_agent, :public, project: item_project) }
  let_it_be(:released_agent_version) do
    create(:ai_catalog_agent_version, :released, item: agent_item, version: '3.2.1')
  end

  let_it_be_with_reload(:third_party_flow_item) do
    create(:ai_catalog_third_party_flow, :public, project: item_project)
  end

  let_it_be(:released_third_party_flow_version) do
    create(:ai_catalog_third_party_flow_version, :released, item: third_party_flow_item, version: '3.2.1')
  end

  let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: consumer_group) }
  let_it_be(:third_party_flow_service_account) do
    create(:user, :service_account, provisioned_by_group: consumer_group)
  end

  let_it_be_with_refind(:agent_parent_item_consumer) do
    create(:ai_catalog_item_consumer, pinned_version_prefix: '1.2.3', group: consumer_group, item: agent_item)
  end

  let_it_be_with_refind(:flow_parent_item_consumer) do
    create(:ai_catalog_item_consumer, pinned_version_prefix: '1.2.3', group: consumer_group, item: flow_item,
      service_account: service_account)
  end

  let_it_be_with_refind(:third_party_flow_parent_item_consumer) do
    create(:ai_catalog_item_consumer, pinned_version_prefix: '1.2.3', group: consumer_group,
      item: third_party_flow_item, service_account: third_party_flow_service_account)
  end

  let(:container) { consumer_project }
  let(:item) { flow_item }
  let(:parent_item_consumer) { flow_parent_item_consumer }
  let(:params) { { item:, parent_item_consumer: } }

  subject(:execute) { described_class.new(container: container, current_user: user, params: params).execute }

  # The parent item consumers above are pinned to '1.2.3'. Create matching
  # released versions so `ItemConsumer#pinned_version` resolves cleanly when
  # called from event tracking (via Ai::Catalog::Tracking::EventPropertiesBuilder).
  # `latest_released_version` for each item remains the '3.2.1' version
  # because we restore it explicitly: the after(:create) hook on
  # ItemVersion would otherwise overwrite it to the newly created '1.2.3'.
  before_all do
    create(:ai_catalog_flow_version, :released, item: flow_item, version: '1.2.3')
    create(:ai_catalog_agent_version, :released, item: agent_item, version: '1.2.3')
    create(:ai_catalog_third_party_flow_version, :released, item: third_party_flow_item, version: '1.2.3')
    flow_item.update!(latest_released_version: released_flow_version)
    agent_item.update!(latest_released_version: released_agent_version)
    third_party_flow_item.update!(latest_released_version: released_third_party_flow_version)
  end

  before do
    enable_ai_catalog
    allow_next_instance_of(described_class) do |instance|
      allow(instance).to receive(:foundational_flow_not_in_allowlist?).and_return(false)
    end
  end

  it_behaves_like 'ItemConsumers::EventsTracking' do
    subject { described_class.new(container: container, current_user: user, params: params) }
  end

  shared_examples 'a failure' do |message|
    it 'does not create any records' do
      expect { execute }.to not_change { Ai::FlowTrigger.count }
        .and not_change { Ai::Catalog::ItemConsumer.count }
    end

    it 'returns failure response with expected message' do
      response = execute

      expect(response).to be_error

      if message.is_a?(Array)
        expect(response.message).to match_array(message)
      else
        expect(response.message).to contain_exactly(message)
      end
    end

    it 'does not track internal event' do
      expect { execute }.not_to trigger_internal_events('create_ai_catalog_item_consumer')
    end

    it 'does not create an audit event' do
      expect { execute }.not_to change { AuditEventReader.count }
    end
  end

  shared_examples 'creates an audit event' do |entity_type:|
    it 'creates an audit event with correct attributes', :aggregate_failures do
      event_name = "enable_ai_catalog_#{item.item_type}"
      entity_id = entity_type == 'Project' ? consumer_project.id : group.id
      entity_name = entity_type == 'Project' ? 'project' : 'group'

      type_display_name = item.item_type == 'third_party_flow' ? 'external agent' : item.item_type

      expect { execute }.to change { AuditEventReader.count }.by_at_least(1)

      audit_event = AuditEventReader.all.find { |event| event.details[:event_name] == event_name }
      item_consumer = Ai::Catalog::ItemConsumer.last

      expect(audit_event).to have_attributes(
        author: user,
        entity_type: entity_type,
        entity_id: entity_id,
        target_details: "#{item.name} (ID: #{item.id})"
      )
      custom_message = "Enabled AI #{type_display_name} for #{entity_name}: " \
        "Pinned to version #{item_consumer.pinned_version_prefix}"

      expect(audit_event.details).to include(
        event_name: event_name,
        target_type: 'Ai::Catalog::Item',
        custom_message: custom_message
      )
    end
  end

  shared_context 'when container is a group' do
    let(:parent_item_consumer) { nil }
    let(:container) { group }

    let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

    before do
      stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      allow(License).to receive(:current).and_return(license)
      allow(license).to receive(:seats).and_return(User.service_account.count + 2)
    end
  end

  it 'creates a catalog item consumer with expected data' do
    execute

    expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
      project: consumer_project,
      group: nil,
      parent_item_consumer: parent_item_consumer,
      item: item,
      pinned_version_prefix: '3.2.1',
      enabled: true,
      locked: true
    )
  end

  it 'adds the service account as a member of the project' do
    expect(Members::Projects::CreatorService).to receive(:add_member).and_call_original

    expect { execute }.to change { consumer_project.members.count }.by(1)

    member = consumer_project.members.last
    expect(member.user).to eq(service_account)
    expect(member.access_level).to eq(Member::DEVELOPER)
  end

  context 'when a pinned_version is requested' do
    context 'and it resolves to a released version' do
      let(:params) { { item: item, parent_item_consumer: parent_item_consumer, pinned_version: '1.2.3' } }

      it 'pins the consumer to the requested version instead of the latest' do
        execute

        expect(Ai::Catalog::ItemConsumer.order(:id).last.pinned_version_prefix).to eq('1.2.3')
      end
    end

    context 'and it resolves to a version that is not released' do
      before_all do
        create(:ai_catalog_flow_version, :draft, item: flow_item, version: '9.9.9')
      end

      let(:params) { { item: item, parent_item_consumer: parent_item_consumer, pinned_version: '9.9.9' } }

      it_behaves_like 'a failure', 'Pinned version must resolve to a released version of the agent or flow'
    end

    context 'and it does not resolve to any version' do
      # Item#resolve_version raises a dev exception on an unknown version; here that
      # version is ordinary user input we validate, so swallow the raise in test env.
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      let(:params) { { item: item, parent_item_consumer: parent_item_consumer, pinned_version: '8.8.8' } }

      it_behaves_like 'a failure', 'Pinned version must resolve to a released version of the agent or flow'
    end
  end

  context "when enabling within the item's own managing project" do
    let_it_be(:managing_project) { create(:project, group: group) }
    let_it_be_with_reload(:managed_flow) { create(:ai_catalog_flow, :public, project: managing_project) }
    let_it_be_with_refind(:managed_parent_item_consumer) do
      create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0', group: group, item: managed_flow,
        service_account: create(:user, :service_account, provisioned_by_group: group))
    end

    let(:container) { managing_project }
    let(:item) { managed_flow }

    before_all do
      create(:ai_catalog_flow_version, :released, item: managed_flow, version: '2.0.0')
    end

    context 'and a valid pinned_version is supplied' do
      let(:params) do
        { item: managed_flow, parent_item_consumer: managed_parent_item_consumer, pinned_version: '2.0.0' }
      end

      it 'ignores the pin and tracks the latest released version' do
        result = execute

        expect(result).to be_success
        expect(result.payload[:item_consumer].pinned_version_prefix).to be_nil
      end
    end

    context 'and an unreleased pinned_version is supplied' do
      # Item#resolve_version raises a dev exception on an unknown version; here that
      # version is ordinary user input we validate, so swallow the raise in test env.
      before do
        allow(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception)
      end

      let(:params) do
        { item: managed_flow, parent_item_consumer: managed_parent_item_consumer, pinned_version: '9.9.9' }
      end

      it_behaves_like 'a failure', 'Pinned version must resolve to a released version of the agent or flow'
    end
  end

  context 'when user has a custom role with admin_ai_catalog_item_consumer' do
    let_it_be(:custom_role_user) { create(:user) }
    let_it_be(:custom_role) do
      create(:member_role, :guest, :admin_ai_catalog_item_consumer, namespace: consumer_group)
    end

    let_it_be(:custom_role_membership) do
      create(:project_member, :guest, member_role: custom_role, user: custom_role_user, project: consumer_project)
    end

    subject(:execute) do
      described_class.new(container: consumer_project, current_user: custom_role_user, params: params).execute
    end

    before do
      stub_licensed_features(custom_roles: true)
    end

    it 'adds the service account as a member of the project and records created_by' do
      expect { execute }.to change { consumer_project.members.count }.by(1)

      member = consumer_project.members.find_by(user: service_account)
      expect(member.access_level).to eq(Member::DEVELOPER)
      expect(member.created_by).to eq(custom_role_user)
    end
  end

  context 'when just the ai_catalog StageCheck passes for the container' do
    let(:flows_available) { false }

    before do
      allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(Gitlab::Llm::StageCheck).to receive(:available?).with(container, :ai_catalog).and_return(true)
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(flow_item.project, :ai_catalog_flows).and_return(true)
      allow(Gitlab::Llm::StageCheck).to receive(:available?)
        .with(container, :ai_catalog_flows).and_return(flows_available)
    end

    it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"

    context 'and the ai_catalog_flows StageCheck also passes' do
      let(:flows_available) { true }

      it 'is successful' do
        expect(execute).to be_success
      end
    end
  end

  context 'when creating the member returns a member with errors' do
    before do
      allow(Members::Projects::CreatorService).to receive(:add_member) do
        build(:project_member).tap { |member| member.errors.add(:base, 'could not create project member') }
      end
    end

    it_behaves_like 'a failure', 'could not create project member'
  end

  context 'when creating the member returns false' do
    before do
      allow(Members::Projects::CreatorService).to receive(:add_member).and_return(false)
    end

    it_behaves_like 'a failure', 'Failed to enable agent or flow'
  end

  context 'when creating the member returns nil' do
    before do
      allow(Members::Projects::CreatorService).to receive(:add_member).and_return(nil)
    end

    it_behaves_like 'a failure', 'Failed to enable agent or flow'
  end

  context 'when service account is already a member' do
    let_it_be(:existing_member) do
      create(:project_member, project: consumer_project, user: service_account, access_level: Gitlab::Access::GUEST)
    end

    it 'updates the membership with the correct permission' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }
        .and not_change { consumer_project.members.count }

      expect(existing_member.reload.access_level).to eq(Gitlab::Access::DEVELOPER)
    end
  end

  context 'when service account has higher inherited access' do
    before_all do
      consumer_group.add_maintainer(service_account)
    end

    it 'creates the consumer without adding a direct project membership', :aggregate_failures do
      response = nil

      expect(Members::Projects::CreatorService).not_to receive(:add_member)

      expect { response = execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
        .and not_change { consumer_project.members.count }

      expect(response).to be_success
      expect(consumer_project.team.max_member_access(service_account.id)).to eq(Gitlab::Access::MAINTAINER)
    end
  end

  context 'when item is an agent' do
    let(:item) { agent_item }
    let(:parent_item_consumer) { agent_parent_item_consumer }

    it 'creates the agent item consumer' do
      expect { execute }.to change { Ai::Catalog::ItemConsumer.count }
    end

    it 'does not add the service account to the project' do
      expect(Members::Projects::CreatorService).not_to receive(:add_member)

      expect { execute }.not_to change { consumer_project.members.count }
    end
  end

  it 'tracks internal event on successful creation' do
    stub_event_properties_builder

    expect { execute }.to trigger_internal_events('create_ai_catalog_item_consumer').with(
      user: user,
      project: consumer_project,
      namespace: nil,
      additional_properties: stubbed_event_properties.merge(
        label: 'true',
        property: 'true'
      )
    ).and increment_usage_metrics('counts.count_total_create_ai_catalog_item_consumer')
  end

  context 'when parent item consumer does not have a version pin' do
    let_it_be(:item) do
      create(:ai_catalog_flow, :public, project: item_project)
    end

    let_it_be(:parent_item_consumer) do
      create(:ai_catalog_item_consumer, group: consumer_group, item: item, pinned_version_prefix: nil)
    end

    it_behaves_like 'a failure', 'This agent or flow must be pinned to a version in the top-level group'
  end

  context 'when parent item consumer is not passed', :aggregate_failures do
    let_it_be(:parent_item_consumer) { nil }

    context 'when the top-level group of the project already has an item consumer for the same item' do
      it 'reuses the existing group item consumer as parent and creates only the project item consumer' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)

        expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
          project: consumer_project,
          parent_item_consumer: flow_parent_item_consumer,
          item: flow_item,
          pinned_version_prefix: flow_item.latest_released_version.version
        )
      end
    end

    context 'when the top-level group of the project does not have an item consumer for the item' do
      let_it_be_with_reload(:new_flow_item) { create(:ai_catalog_flow, :public, project: item_project) }
      let_it_be(:new_flow_version) do
        create(:ai_catalog_flow_version, :released, item: new_flow_item, version: '2.0.0')
      end

      let(:params) { { item: new_flow_item } }
      let(:license) { create(:license, plan: License::PREMIUM_PLAN) }

      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
        allow(License).to receive(:current).and_return(license)
        allow(license).to receive(:seats).and_return(User.service_account.count + 2)
      end

      it 'automatically creates both group-level and project-level item consumers with service account' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(2)
          .and change { User.count }.by(1)

        project_consumer = Ai::Catalog::ItemConsumer.where(project: consumer_project).last
        group_consumer = Ai::Catalog::ItemConsumer.where(group: consumer_group).last

        expect(project_consumer).to have_attributes(
          project: consumer_project,
          parent_item_consumer: group_consumer,
          item: new_flow_item,
          pinned_version_prefix: '2.0.0'
        )

        expect(group_consumer).to have_attributes(
          group: consumer_group,
          item: new_flow_item,
          pinned_version_prefix: '2.0.0'
        )
      end
    end

    context 'when another project in the same group already has a consumer for the item' do
      # Guards against auto_resolve picking a descendant project consumer
      # instead of the required root group consumer.
      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it 'resolves the root group consumer as parent, not the sibling project consumer' do
        shared_flow_item = create(:ai_catalog_flow, :with_released_version, :public, project: item_project)
        other_project = create(:project, group: consumer_group)
        group_parent = create(
          :ai_catalog_item_consumer, :parent_item_consumer, group: consumer_group, item: shared_flow_item,
          pinned_version_prefix: shared_flow_item.latest_released_version.version
        )
        existing_other_project_consumer = create(:ai_catalog_item_consumer, project: other_project,
          item: shared_flow_item, parent_item_consumer: group_parent)

        response = described_class.new(
          container: consumer_project, current_user: user, params: { item: shared_flow_item }
        ).execute

        expect(response).to be_success

        new_project_consumer = Ai::Catalog::ItemConsumer.where(project: consumer_project,
          item: shared_flow_item).last

        expect(new_project_consumer).not_to be_nil
        expect(new_project_consumer.id).not_to eq(existing_other_project_consumer.id)
        expect(new_project_consumer.parent_item_consumer).to eq(group_parent)
      end
    end

    context 'when the top-level group has an orphan consumer for the item' do
      # Guards against silently using an orphan group consumer (no service
      # account) as the project-level parent; auto_resolve must heal the
      # orphan first and then create a distinct project-level consumer.
      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: true)
      end

      it 'heals the group orphan and creates a distinct project-level consumer' do
        heal_item = create(:ai_catalog_flow, :public, project: item_project, name: 'heal_me')
        create(:ai_catalog_flow_version, :released, item: heal_item, version: '1.0.0')
        orphan_group_consumer = create(
          :ai_catalog_item_consumer,
          group: consumer_group,
          item: heal_item,
          pinned_version_prefix: '1.0.0'
        )
        orphan_group_consumer.update!(service_account: nil)

        expect do
          described_class.new(
            container: consumer_project, current_user: user, params: { item: heal_item }
          ).execute
        end.to change { Ai::Catalog::ItemConsumer.count }.by(1)
          .and change { User.count }.by(1)

        orphan_group_consumer.reload
        project_consumer = Ai::Catalog::ItemConsumer.where(project: consumer_project, item: heal_item).last

        expect(orphan_group_consumer.service_account_id).to be_present
        expect(project_consumer).not_to be_nil
        expect(project_consumer.id).not_to eq(orphan_group_consumer.id)
        expect(project_consumer.parent_item_consumer).to eq(orphan_group_consumer)
      end
    end

    context 'when project belongs to a user namespace' do
      let(:user_namespace_project) { create(:project, :in_user_namespace) }

      let(:container) { user_namespace_project }

      before do
        user_namespace_project.add_maintainer(user)
      end

      it_behaves_like 'a failure', 'Project must belong to a group'
    end
  end

  context 'when the item is already configured in the project' do
    before do
      create(
        :ai_catalog_item_consumer,
        project: consumer_project,
        item: item,
        parent_item_consumer: parent_item_consumer
      )
    end

    it_behaves_like 'a failure', 'Agent or flow already enabled'

    it 'returns an :already_configured reason so downstream services can react without parsing messages' do
      response = execute

      expect(response).to be_error
      expect(response.reason).to eq(:already_configured)
    end
  end

  it_behaves_like 'when container is a group' do
    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: nil,
        group: group,
        parent_item_consumer: nil,
        item: item,
        enabled: true,
        locked: true,
        pinned_version_prefix: '3.2.1'
      )
    end

    it 'does not add the service account as a member of the group' do
      expect { execute }.not_to change { group.members.count }
    end

    it 'tracks internal event with group namespace' do
      stub_event_properties_builder

      expect { execute }.to trigger_internal_events('create_ai_catalog_item_consumer').with(
        user: user,
        project: nil,
        namespace: group,
        additional_properties: stubbed_event_properties.merge(
          label: 'true',
          property: 'true'
        )
      )
    end

    context 'when just the ai_catalog StageCheck passes for the container' do
      let(:flows_available) { false }

      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(group, :ai_catalog).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(flow_item.project, :ai_catalog_flows).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(group, :ai_catalog_flows).and_return(flows_available)
      end

      it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"

      context 'and the ai_catalog_flows StageCheck also passes' do
        let(:flows_available) { true }

        it 'is successful' do
          expect(execute).to be_success
        end
      end
    end

    it_behaves_like 'creates an audit event', entity_type: 'Group'

    context 'when item is an agent' do
      let(:item) { agent_item }

      it 'creates the agent item consumer' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }
      end

      it 'does not create a service account' do
        expect { execute }.not_to change { User.count }
      end
    end

    context 'when the item is already configured in the group' do
      let_it_be(:already_configured_service_account) do
        create(:user, :service_account, provisioned_by_group: group)
      end

      before do
        create(:ai_catalog_item_consumer, group: group, item: item,
          service_account: already_configured_service_account)
      end

      it_behaves_like 'a failure', 'Agent or flow already enabled'
    end

    context 'when an orphan group-level consumer exists with service_account_id nil' do
      let_it_be_with_refind(:orphan_consumer) do
        create(
          :ai_catalog_item_consumer,
          group: group,
          item: flow_item,
          pinned_version_prefix: '3.2.1'
        ).tap do |consumer|
          consumer.update!(service_account: nil)
        end
      end

      it 'heals the orphan consumer and provisions a new service account in place' do
        expect { execute }.to change { User.count }.by(1)
          .and not_change { Ai::Catalog::ItemConsumer.count }

        orphan_consumer.reload
        new_service_account = User.last

        expect(new_service_account).to be_service_account
        expect(orphan_consumer.service_account_id).to eq(new_service_account.id)
      end

      it 'returns a success response carrying the healed consumer' do
        response = execute

        expect(response).to be_success
        expect(response.payload[:item_consumer]).to eq(orphan_consumer)
      end

      it 'tracks the internal event for the healed consumer' do
        stub_event_properties_builder

        expect { execute }.to trigger_internal_events('create_ai_catalog_item_consumer').with(
          user: user,
          project: nil,
          namespace: group,
          additional_properties: stubbed_event_properties.merge(
            label: 'true',
            property: 'true'
          )
        )
      end

      context 'when updating the orphan consumer fails' do
        before do
          allow_next_found_instance_of(Ai::Catalog::ItemConsumer) do |instance|
            allow(instance).to receive_messages(
              update: false,
              errors: instance_double(ActiveModel::Errors, full_messages: ['boom'])
            )
          end
        end

        it 'returns a failure response and rolls back the service account creation' do
          expect { execute }.to not_change { User.count }
            .and not_change { Ai::Catalog::ItemConsumer.count }
        end

        it 'surfaces the orphan consumer errors in the response' do
          response = execute

          expect(response).to be_error
          expect(response.message).to include('boom')
        end
      end

      context 'when provisioning the new service account fails during healing' do
        before do
          allow(::Namespaces::ServiceAccounts::GroupCreateService).to receive_message_chain(:new, :execute)
            .and_return(ServiceResponse.error(message: 'service account provisioning failed'))
        end

        it 'logs the error and returns a failure without healing the orphan consumer' do
          expect(Gitlab::AppLogger).to receive(:error).with(
            "Failed to create service account with name 'ai-item_name-group-name': service account provisioning failed"
          )

          response = execute

          expect(response).to be_error
          expect(response.message).to include('service account provisioning failed')
          expect(orphan_consumer.reload.service_account_id).to be_nil
        end

        it 'does not create a new user or consumer row' do
          expect { execute }.to not_change { User.count }
            .and not_change { Ai::Catalog::ItemConsumer.count }
        end
      end
    end

    it 'creates a service account and attaches it to the item consumer' do
      expect(::Namespaces::ServiceAccounts::GroupCreateService).to receive(:new).and_call_original
      expect(Ai::Avatars::LoadService).to receive(:new).with(item).and_call_original

      expect { execute }.to change { User.count }.by(1)
      service_account = User.last
      expect(service_account).to be_service_account
      expect(service_account).to have_attributes(
        name: 'item_name',
        username: "ai-item_name-group-name",
        provisioned_by_group_id: group.id,
        composite_identity_enforced: true
      )
      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(service_account:)
    end

    context 'when item is a foundational flow' do
      let_it_be_with_reload(:foundational_flow_item) do
        create(:ai_catalog_flow, :public, project: item_project, name: 'foundational_flow',
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:released_foundational_flow_version) do
        create(:ai_catalog_flow_version, :released, item: foundational_flow_item, version: '1.0.0')
      end

      let(:item) { foundational_flow_item }

      it 'creates a service account with duo prefix' do
        expect { execute }.to change { User.count }.by(1)
        service_account = User.last
        expect(service_account).to be_service_account
        expect(service_account).to have_attributes(
          name: "Duo foundational_flow",
          username: "duo-foundational_flow-group-name"
        )
      end

      context 'when foundational flow has triggers defined' do
        let_it_be_with_reload(:foundational_flow_with_triggers) do
          create(:ai_catalog_flow, :public, project: item_project, name: 'developer_flow',
            foundational_flow_reference: 'developer/v1')
        end

        let_it_be(:released_version_with_triggers) do
          create(:ai_catalog_flow_version, :released, item: foundational_flow_with_triggers, version: '1.0.0')
        end

        let(:item) { foundational_flow_with_triggers }

        it 'does not create triggers at group level' do
          expect { execute }.not_to change { Ai::FlowTrigger.count }
        end

        it 'successfully creates the item consumer' do
          expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
          expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
            group: group,
            item: foundational_flow_with_triggers
          )
        end
      end
    end

    context 'when item is a foundational flow that is not in the allow list' do
      let_it_be(:foundational_flow_item) do
        create(:ai_catalog_flow, :public, project: item_project, name: 'foundational_flow',
          foundational_flow_reference: 'code_review/v1')
      end

      let(:item) { foundational_flow_item }

      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:foundational_flow_not_in_allowlist?).and_call_original
        end
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(group, :foundational_flows).and_return(true)
        allow(group).to receive(:enabled_flow_catalog_item_ids).and_return([])
      end

      it_behaves_like 'a failure', 'Foundational flow is not allowed by the top-level group settings'
    end

    context 'when item has a very long name' do
      let_it_be_with_reload(:long_name_item) do
        create(:ai_catalog_flow, :public, project: item_project,
          name: 'a' * 100)
      end

      let_it_be(:released_long_name_version) do
        create(:ai_catalog_flow_version, :released, item: long_name_item, version: '1.0.0')
      end

      let(:item) { long_name_item }

      it 'creates a service account with a truncated name' do
        expect { execute }.to change { User.count }.by(1)
        service_account = User.last
        expect(service_account).to be_service_account
        expect(service_account.name).to eq('a' * 90)
        expect(service_account.name.length).to eq(90)
      end
    end

    context 'when group is not a top-level group' do
      let_it_be(:child_group) do
        create(:group, parent: consumer_group, owners: user, maintainers: maintainer_user)
      end

      let(:container) { child_group }

      it_behaves_like 'a failure', 'This agent or flow can only be enabled in projects or top-level groups'
    end

    context 'when instance setting disallows top-level group owners to create service accounts' do
      before do
        stub_ee_application_setting(allow_top_level_group_owners_to_create_service_accounts: false)
      end

      it 'creates a service account and attaches it to the item consumer' do
        expect(::Namespaces::ServiceAccounts::GroupCreateService).to receive(:new).and_call_original

        expect { execute }.to change { User.count }.by(1)
        service_account = User.last
        expect(service_account).to be_service_account
        expect(service_account).to have_attributes(
          username: "ai-item_name-group-name", provisioned_by_group_id: group.id
        )
        expect(Ai::Catalog::ItemConsumer.last).to have_attributes(service_account:)
      end
    end

    context 'when the user is not an owner of the group' do
      subject(:execute) do
        described_class.new(container: container, current_user: maintainer_user, params: params).execute
      end

      it 'creates a service account and attaches it to the item consumer' do
        expect(::Namespaces::ServiceAccounts::GroupCreateService).to receive(:new).and_call_original

        expect { execute }.to change { User.count }.by(1)
        service_account = User.last
        expect(service_account).to be_service_account
        expect(service_account).to have_attributes(
          username: "ai-item_name-group-name", provisioned_by_group_id: group.id
        )
        expect(Ai::Catalog::ItemConsumer.last).to have_attributes(service_account:)
      end
    end

    context 'when the service account creation returns an error' do
      let_it_be(:existing_user_with_same_name) do
        build(:user, :with_namespace, username: "ai-item_name-group-name").tap do |user|
          user.skip_ai_prefix_validation = true
          user.save!
        end
      end

      before do
        allow_next_instance_of(Gitlab::Utils::UsernameAndEmailGenerator) do |username_generator|
          allow(username_generator).to receive(:username).and_return(existing_user_with_same_name.username)
        end
      end

      it 'logs the error' do
        expect(Gitlab::AppLogger).to receive(:error).with(
          "Failed to create service account with name 'ai-item_name-group-name': Username has already been taken"
        )

        execute
      end

      it_behaves_like 'a failure', 'Username has already been taken'
    end

    context 'when a user with that username already exists' do
      context 'when the user is a service account belonging to the same group' do
        let_it_be(:existing_service_account_with_same_name) do
          build(
            :user, :service_account, :with_namespace, username: "ai-item_name-group-name", provisioned_by_group: group
          ).tap do |user|
            user.skip_ai_prefix_validation = true
            user.save!
          end
        end

        it 'uses the existing service account' do
          expect { execute }.not_to change { User.count }
          expect(execute).to be_success
          expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
            service_account: existing_service_account_with_same_name
          )
        end

        context 'when the service account is already in use by another item consumer' do
          let_it_be(:other_flow_item) do
            create(:ai_catalog_flow, :public, project: item_project, name: 'item_name')
          end

          let_it_be(:other_flow_consumer) do
            create(
              :ai_catalog_item_consumer,
              group: group,
              item: other_flow_item,
              service_account: existing_service_account_with_same_name
            )
          end

          it 'creates a new service account' do
            expect { execute }.to change { User.count }
            service_account = User.last
            expect(service_account).to be_service_account
            expect(service_account.username).to start_with("ai-item_name-group-name_")
          end
        end
      end

      context 'when the user is a regular user' do
        let_it_be(:existing_user_with_same_name) do
          build(:user, :with_namespace, username: "ai-item_name-group-name").tap do |user|
            user.skip_ai_prefix_validation = true
            user.save!
          end
        end

        it 'creates the service account with a different name' do
          expect { execute }.to change { User.count }.by(1)
          service_account = User.last
          expect(service_account).to be_service_account
          expect(service_account.username).to start_with("ai-item_name-group-name_")
        end
      end

      context 'when the user is a service account belonging to a different group' do
        let_it_be(:other_group) { create(:group) }

        let_it_be(:existing_service_account_with_same_name) do
          build(
            :service_account, :with_namespace, username: "ai-item_name-group-name", provisioned_by_group: other_group
          ).tap do |user|
            user.skip_ai_prefix_validation = true
            user.save!
          end
        end

        it 'creates the service account with a different name' do
          expect { execute }.to change { User.count }.by(1)
          service_account = User.last
          expect(service_account).to be_service_account
          expect(service_account.username).to start_with("ai-item_name-group-name_")
        end
      end
    end

    context 'when creating the service account fails' do
      before do
        allow(::Namespaces::ServiceAccounts::GroupCreateService).to receive_message_chain(:new, :execute)
          .and_return(ServiceResponse.error(message: 'service account error'))
      end

      it_behaves_like 'a failure', 'service account error'
    end

    context 'when creating the item consumer fails' do
      it 'does not create a service account' do
        allow_next_instance_of(Ai::Catalog::ItemConsumer) do |item_consumer|
          allow(item_consumer).to receive(:save).and_return(false)
        end

        expect { execute }.not_to change { User.count }
      end
    end

    context 'when the user cannot create a service account' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :create_service_account, group).and_return(false)
      end

      it 'creates a service account successfully' do
        expect { execute }.to change { User.count }.by(1)
        service_account = User.last
        expect(service_account).to be_service_account
        expect(service_account).to have_attributes(
          username: "ai-item_name-group-name", provisioned_by_group_id: group.id
        )
      end

      it 'creates the item consumer with the service account' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
        expect(Ai::Catalog::ItemConsumer.last).to have_attributes(service_account: User.last)
      end
    end

    context 'when item has no latest_released_version' do
      let_it_be_with_reload(:item) { create(:ai_catalog_flow, :public, project: item_project) }

      it_behaves_like 'a failure', 'Agent or flow has no latest released version to pin to'

      context 'and the item does have a version that is released' do
        before_all do
          create(:ai_catalog_flow_version, :released, item: item, version: '6.6.6')
          create(:ai_catalog_flow_version, :draft, item: item, version: '7.7.7')
          item.update!(latest_released_version: nil)
        end

        it 'creates a catalog item consumer pinned to the latest released version' do
          expect { execute }.to change { Ai::Catalog::ItemConsumer.count }

          expect(Ai::Catalog::ItemConsumer.last.pinned_version_prefix).to eq('6.6.6')
        end
      end
    end

    context 'when beta features are disabled' do
      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog_flows).and_return(false)
      end

      context 'when the item is a custom flow' do
        let(:item) { flow_item }

        it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
      end

      context 'when the item is a foundational flow' do
        let_it_be_with_reload(:beta_disabled_group_foundational_flow_item) do
          create(:ai_catalog_flow, :public, project: item_project, name: 'beta_disabled_group_foundational_flow',
            foundational_flow_reference: 'code_review/v1')
        end

        let_it_be(:beta_disabled_group_released_foundational_flow_version) do
          create(:ai_catalog_flow_version, :released,
            item: beta_disabled_group_foundational_flow_item, version: '1.0.0')
        end

        let(:item) { beta_disabled_group_foundational_flow_item }

        before do
          allow(Gitlab::Llm::StageCheck).to receive(:available?)
            .with(anything, :foundational_flows).and_return(true)
        end

        it 'is successful because foundational flows are GA' do
          expect(execute).to be_success
        end

        it 'creates the item consumer and service account' do
          expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
            .and change { User.count }.by(1)
        end
      end
    end

    context 'when beta features are enabled' do
      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog_flows).and_return(true)
      end

      context 'when the item is a custom flow' do
        let(:item) { flow_item }

        it 'is successful' do
          expect(execute).to be_success
        end

        it 'creates the item consumer and service account' do
          expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
            .and change { User.count }.by(1)
        end
      end
    end
  end

  context 'when user is not authorized to create a consumer item in the consumer project' do
    let(:user) do
      create(:user).tap do |user|
        consumer_project.add_developer(user)
        item_project.add_developer(user)
      end
    end

    it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
  end

  context 'when user is not authorized to read the catalog item' do
    let_it_be(:item) { create(:ai_catalog_flow, project: item_project) }

    let(:user) do
      create(:user).tap do |user|
        consumer_project.add_maintainer(user)
        # User is not a member of item_project
      end
    end

    it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
  end

  context 'when item is a foundational flow that is not in the allow list' do
    let_it_be(:foundational_flow_item) do
      create(:ai_catalog_flow, :public, project: item_project, name: 'foundational_flow',
        foundational_flow_reference: 'code_review/v1')
    end

    let_it_be(:foundational_flow_service_account) do
      create(:user, :service_account, provisioned_by_group: consumer_group)
    end

    let_it_be(:foundational_flow_parent_item_consumer) do
      create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0', group: consumer_group,
        item: foundational_flow_item, service_account: foundational_flow_service_account)
    end

    let(:item) { foundational_flow_item }
    let(:parent_item_consumer) { foundational_flow_parent_item_consumer }

    before do
      allow_next_instance_of(described_class) do |instance|
        allow(instance).to receive(:foundational_flow_not_in_allowlist?).and_call_original
      end
      allow(Gitlab::Llm::StageCheck).to receive(:available?).with(consumer_project,
        :foundational_flows).and_return(true)
      allow(consumer_project).to receive(:enabled_flow_catalog_item_ids).and_return([])
    end

    it_behaves_like 'a failure', 'Foundational flow is not allowed by the top-level group settings'
  end

  context 'when beta features are disabled' do
    before do
      allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog).and_return(true)
      allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog_flows).and_return(false)
    end

    context 'when the item is a custom flow' do
      let(:item) { flow_item }

      it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
    end

    context 'when the item is a foundational flow' do
      let_it_be_with_reload(:beta_disabled_project_foundational_flow_item) do
        create(:ai_catalog_flow, :public, project: item_project, name: 'beta_disabled_project_foundational_flow',
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:beta_disabled_project_released_foundational_flow_version) do
        create(:ai_catalog_flow_version, :released,
          item: beta_disabled_project_foundational_flow_item, version: '1.0.0')
      end

      let_it_be(:beta_disabled_project_foundational_flow_service_account) do
        create(:user, :service_account, provisioned_by_group: consumer_group)
      end

      let_it_be(:beta_disabled_project_foundational_flow_parent_item_consumer) do
        create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0', group: consumer_group,
          item: beta_disabled_project_foundational_flow_item,
          service_account: beta_disabled_project_foundational_flow_service_account)
      end

      let(:item) { beta_disabled_project_foundational_flow_item }
      let(:parent_item_consumer) { beta_disabled_project_foundational_flow_parent_item_consumer }

      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(anything, :foundational_flows).and_return(true)
      end

      it 'is successful because foundational flows are GA' do
        expect(execute).to be_success
      end

      it 'creates the item consumer' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
      end

      context 'when foundational flow has defined triggers' do
        it 'automatically creates triggers based on flow definition' do
          foundational_flow = create(:ai_catalog_flow, :public, project: item_project,
            name: 'developer_flow', foundational_flow_reference: 'developer/v1')
          create(:ai_catalog_flow_version, :released, item: foundational_flow, version: '1.0.0')

          flow_service_account = create(:user, :service_account, provisioned_by_group: consumer_group)
          parent_consumer = create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0',
            group: consumer_group, item: foundational_flow, service_account: flow_service_account)

          params = { item: foundational_flow, parent_item_consumer: parent_consumer }

          expect do
            described_class.new(container: consumer_project, current_user: user, params: params).execute
          end.to change { Ai::FlowTrigger.count }.by(1)

          expect(Ai::FlowTrigger.last).to have_attributes(
            project_id: consumer_project.id,
            event_types: [
              ::Ai::FlowTrigger::EVENT_TYPES[:assign],
              ::Ai::FlowTrigger::EVENT_TYPES[:mention],
              ::Ai::FlowTrigger::EVENT_TYPES[:merge_request]
            ]
          )
        end

        it 'sets flow_trigger_attributes with correct service account and project' do
          foundational_flow = create(:ai_catalog_flow, :public, project: item_project,
            name: 'developer_flow', foundational_flow_reference: 'developer/v1')
          create(:ai_catalog_flow_version, :released, item: foundational_flow, version: '1.0.0')

          flow_service_account = create(:user, :service_account, provisioned_by_group: consumer_group)
          parent_consumer = create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0',
            group: consumer_group, item: foundational_flow, service_account: flow_service_account)

          params = { item: foundational_flow, parent_item_consumer: parent_consumer }

          described_class.new(container: consumer_project, current_user: user, params: params).execute

          trigger = Ai::FlowTrigger.last
          expect(trigger).to have_attributes(
            project: consumer_project,
            description: "Auto-created triggers for #{foundational_flow.name}"
          )
        end
      end

      context 'when foundational flow definition is nil' do
        it 'does not create triggers and succeeds' do
          foundational_flow = create(:ai_catalog_flow, :public, project: item_project,
            name: 'unknown_flow', foundational_flow_reference: 'nonexistent/v1')
          create(:ai_catalog_flow_version, :released, item: foundational_flow, version: '1.0.0')

          flow_service_account = create(:user, :service_account, provisioned_by_group: consumer_group)
          parent_consumer = create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0',
            group: consumer_group, item: foundational_flow, service_account: flow_service_account)

          params = { item: foundational_flow, parent_item_consumer: parent_consumer }

          expect do
            described_class.new(container: consumer_project, current_user: user, params: params).execute
          end.not_to change { Ai::FlowTrigger.count }

          expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
            project: consumer_project,
            item: foundational_flow
          )
        end
      end

      context 'when foundational flow has nil triggers' do
        it 'does not create triggers and succeeds' do
          foundational_flow = create(:ai_catalog_flow, :public, project: item_project,
            name: 'code_review_flow', foundational_flow_reference: 'code_review/v1')
          create(:ai_catalog_flow_version, :released, item: foundational_flow, version: '1.0.0')

          flow_service_account = create(:user, :service_account, provisioned_by_group: consumer_group)
          parent_consumer = create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0',
            group: consumer_group, item: foundational_flow, service_account: flow_service_account)

          params = { item: foundational_flow, parent_item_consumer: parent_consumer }

          mock_flow_def = instance_double(::Ai::Catalog::FoundationalFlow, triggers: nil, flow_version: '1.0.0')
          allow(::Ai::Catalog::FoundationalFlow).to receive(:[]).with('code_review/v1').and_return(mock_flow_def)

          expect do
            described_class.new(container: consumer_project, current_user: user, params: params).execute
          end.not_to change { Ai::FlowTrigger.count }

          expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
            project: consumer_project,
            item: foundational_flow
          )
        end
      end

      context 'when foundational flow has empty triggers array' do
        it 'does not create triggers and succeeds' do
          foundational_flow = create(:ai_catalog_flow, :public, project: item_project,
            name: 'code_review_flow', foundational_flow_reference: 'code_review/v1')
          create(:ai_catalog_flow_version, :released, item: foundational_flow, version: '1.0.0')

          flow_service_account = create(:user, :service_account, provisioned_by_group: consumer_group)
          parent_consumer = create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0',
            group: consumer_group, item: foundational_flow, service_account: flow_service_account)

          params = { item: foundational_flow, parent_item_consumer: parent_consumer }

          expect do
            described_class.new(container: consumer_project, current_user: user, params: params).execute
          end.not_to change { Ai::FlowTrigger.count }

          expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
            project: consumer_project,
            item: foundational_flow
          )
        end
      end
    end
  end

  context 'when beta features are enabled' do
    before do
      allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
      allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog).and_return(true)
      allow(Gitlab::Llm::StageCheck).to receive(:available?).with(anything, :ai_catalog_flows).and_return(true)
    end

    context 'when the item is a custom flow' do
      let(:item) { flow_item }

      it 'is successful' do
        expect(execute).to be_success
      end

      it 'creates the item consumer' do
        expect { execute }.to change { Ai::Catalog::ItemConsumer.count }.by(1)
      end
    end

    context 'when the item is a foundational flow' do
      let_it_be_with_reload(:beta_enabled_project_foundational_flow_item) do
        create(:ai_catalog_flow, :public, project: item_project, name: 'beta_enabled_project_foundational_flow',
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:beta_enabled_project_released_foundational_flow_version) do
        create(:ai_catalog_flow_version, :released,
          item: beta_enabled_project_foundational_flow_item, version: '1.0.0')
      end

      let_it_be(:beta_enabled_project_foundational_flow_service_account) do
        create(:user, :service_account, provisioned_by_group: consumer_group)
      end

      let_it_be(:beta_enabled_project_foundational_flow_parent_item_consumer) do
        create(:ai_catalog_item_consumer, pinned_version_prefix: '1.0.0', group: consumer_group,
          item: beta_enabled_project_foundational_flow_item,
          service_account: beta_enabled_project_foundational_flow_service_account)
      end

      let(:item) { beta_enabled_project_foundational_flow_item }
      let(:parent_item_consumer) { beta_enabled_project_foundational_flow_parent_item_consumer }

      context 'when user lacks create_ai_foundational_flow_item_consumer permission' do
        before do
          allow(Ability).to receive(:allowed?).and_call_original
          allow(Ability).to receive(:allowed?)
            .with(user, :create_ai_foundational_flow_item_consumer, container).and_return(false)
        end

        it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
      end
    end
  end

  context 'when the item is an agent' do
    let(:item) { agent_item }
    let(:parent_item_consumer) { agent_parent_item_consumer }

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: consumer_project,
        group: nil,
        item: item,
        pinned_version_prefix: '3.2.1',
        enabled: true,
        locked: true
      )
    end

    it_behaves_like 'creates an audit event', entity_type: 'Project'

    context 'when item has no latest_released_version' do
      let_it_be_with_reload(:item) { create(:ai_catalog_agent, :public, project: item_project) }
      let_it_be_with_reload(:parent_item_consumer) do
        create(:ai_catalog_item_consumer, item: item, group: consumer_group)
      end

      it_behaves_like 'a failure', 'This agent or flow must be pinned to a version in the top-level group'

      context 'and the item does have a version that is released' do
        before_all do
          create(:ai_catalog_agent_version, :released, item: item, version: '6.6.6')
          create(:ai_catalog_agent_version, :draft, item: item, version: '7.7.7')
          parent_item_consumer.update!(pinned_version_prefix: '6.6.6')
          item.update!(latest_released_version: nil)
        end

        it 'creates a catalog item consumer pinned to the latest released version' do
          expect { execute }.to change { Ai::Catalog::ItemConsumer.count }

          expect(Ai::Catalog::ItemConsumer.last.pinned_version_prefix).to eq('6.6.6')
        end
      end
    end

    context 'when user does not have create_ai_catalog_agent_item_consumer permission' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :create_ai_catalog_agent_item_consumer,
          container).and_return(false)
      end

      it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
    end
  end

  context 'when the item is a flow' do
    it_behaves_like 'creates an audit event', entity_type: 'Project'
  end

  context 'when the item is a third_party_flow' do
    let(:item) { third_party_flow_item }
    let(:parent_item_consumer) { third_party_flow_parent_item_consumer }

    it_behaves_like 'creates an audit event', entity_type: 'Project'

    it 'is successful' do
      expect(execute).to be_success
    end

    context 'when just the ai_catalog StageCheck passes for the container' do
      let(:third_party_flows_available) { false }

      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?).and_call_original
        allow(Gitlab::Llm::StageCheck).to receive(:available?).with(container, :ai_catalog).and_return(true)
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(container, :ai_catalog_third_party_flows).and_return(third_party_flows_available)
      end

      it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"

      context 'and the third_party_flows_available StageCheck also passes' do
        let(:third_party_flows_available) { true }

        it 'is successful' do
          expect(execute).to be_success
        end
      end
    end
  end

  context 'when passing trigger_types' do
    let(:params) { super().merge(trigger_types: ['mention']) }

    it 'creates the triggers' do
      expect { execute }.to change { Ai::FlowTrigger.count }.by(1)
      expect(Ai::FlowTrigger.last).to have_attributes(
        project_id: consumer_project.id,
        event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]]
      )
    end

    it 'sets flow_trigger_attributes with correct values' do
      execute
      item_consumer = Ai::Catalog::ItemConsumer.last
      trigger = item_consumer.flow_trigger

      expect(trigger).to have_attributes(
        project: consumer_project,
        description: "Auto-created triggers for #{item.name}",
        event_types: [::Ai::FlowTrigger::EVENT_TYPES[:mention]]
      )
    end

    context 'with multiple trigger types' do
      let(:params) { super().merge(trigger_types: %w[mention assign_reviewer]) }

      it 'creates triggers with all specified event types' do
        expect { execute }.to change { Ai::FlowTrigger.count }.by(1)
        expect(Ai::FlowTrigger.last).to have_attributes(
          project_id: consumer_project.id,
          event_types: [
            ::Ai::FlowTrigger::EVENT_TYPES[:mention],
            ::Ai::FlowTrigger::EVENT_TYPES[:assign_reviewer]
          ]
        )
      end
    end

    context 'with trigger_filter' do
      let(:trigger_filter) do
        {
          'pipeline_hooks' => {
            'rules' => [
              { 'field' => 'object_attributes.status', 'operator' => 'in', 'value' => %w[success failed] }
            ]
          }
        }
      end

      let(:params) { super().merge(trigger_types: %w[pipeline_hooks], trigger_filter: trigger_filter) }

      it 'persists the filter on the created flow trigger' do
        expect { execute }.to change { Ai::FlowTrigger.count }.by(1)

        expect(Ai::FlowTrigger.last).to have_attributes(
          project_id: consumer_project.id,
          event_types: [::Ai::FlowTrigger::EVENT_TYPES[:pipeline_hooks]],
          filter: trigger_filter
        )
      end

      context 'when trigger_filter references an event type not in trigger_types' do
        let(:params) { super().merge(trigger_types: %w[mention]) }

        it_behaves_like(
          'a failure',
          ['Flow trigger filter contains filters for event types not in event_types: pipeline_hooks']
        )
      end

      it_behaves_like 'when container is a group' do
        let(:params) { super().merge(trigger_filter: trigger_filter).except(:trigger_types) }

        it_behaves_like 'a failure', 'Triggers can only be set for projects'
      end
    end

    it_behaves_like 'when container is a group' do
      it_behaves_like 'a failure', "Triggers can only be set for projects"
    end

    context 'when item is an agent' do
      let(:item) { agent_item }
      let(:parent_item_consumer) { agent_parent_item_consumer }

      it_behaves_like(
        'a failure',
        [
          "Flow trigger ai catalog item consumer must have an active service account",
          "Flow trigger ai_catalog_item_consumer is not a flow"
        ]
      )
    end

    context 'when item is a foundational flow and user provides trigger_types' do
      let_it_be(:foundational_flow_with_triggers) do
        flow = create(:ai_catalog_flow, :public, project: item_project, name: 'developer_flow',
          foundational_flow_reference: 'developer/v1')
        create(:ai_catalog_flow_version, :released, item: flow, version: '1.0.0')
        flow
      end

      let_it_be(:foundational_flow_parent_consumer) do
        service_account = create(:user, :service_account, provisioned_by_group: consumer_group)
        create(:ai_catalog_item_consumer, group: consumer_group, item: foundational_flow_with_triggers,
          service_account: service_account, pinned_version_prefix: '1.0.0')
      end

      let(:item) { foundational_flow_with_triggers }
      let(:parent_item_consumer) { foundational_flow_parent_consumer }
      let(:params) { super().merge(trigger_types: %w[mention assign_reviewer]) }

      before do
        allow(Gitlab::Llm::StageCheck).to receive(:available?)
          .with(anything, :foundational_flows).and_return(true)
      end

      it_behaves_like(
        'a failure', 'You can\'t create triggers for foundational flows'
      )
    end
  end

  context 'when the item can be seen by user but is private to another project' do
    let_it_be(:item) { create(:ai_catalog_flow, :with_released_version, project: item_project) }
    let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: consumer_group) }

    let_it_be(:parent_item_consumer) do
      # We get 'Item is private to another project' as the item should not be enabled in another group
      build(:ai_catalog_item_consumer, group: consumer_group, item: item, service_account: service_account,
        pinned_version_prefix: '4.4.4').tap { |item| item.save!(validate: false) }
    end

    it_behaves_like 'a failure', 'Item is private in another project'
  end

  context 'when the item is private to the project' do
    let_it_be(:item) { create(:ai_catalog_flow, project: consumer_project) }
    let_it_be(:service_account) { create(:user, :service_account, provisioned_by_group: consumer_group) }

    let_it_be(:parent_item_consumer) do
      create(:ai_catalog_item_consumer, group: consumer_group, item: item, service_account: service_account,
        pinned_version_prefix: '4.4.4')
    end

    it 'creates a catalog item consumer with expected data' do
      execute

      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: consumer_project,
        group: nil,
        item: item,
        enabled: true,
        locked: true,
        pinned_version_prefix: nil
      )
    end
  end

  context 'when the container is the project that owns the item' do
    let_it_be(:owner_project) { create(:project, group: consumer_group) }

    let_it_be(:owner_flow_item) do
      create(:ai_catalog_flow, :public, project: owner_project, name: 'owner_item_name').tap do |item|
        create(:ai_catalog_flow_version, :released, item: item, version: '1.2.3')
      end
    end

    let_it_be(:owner_service_account) do
      create(:user, :service_account, provisioned_by_group: consumer_group)
    end

    let_it_be(:owner_flow_parent_item_consumer) do
      create(
        :ai_catalog_item_consumer,
        pinned_version_prefix: '1.2.3',
        group: consumer_group,
        item: owner_flow_item,
        service_account: owner_service_account
      )
    end

    let(:user) { create(:user, maintainer_of: owner_project) }
    let(:params) { { item: owner_flow_item, parent_item_consumer: owner_flow_parent_item_consumer } }

    subject(:execute) do
      described_class.new(container: owner_project, current_user: user, params: params).execute
    end

    it 'creates an item consumer and pins the version prefix to nil, so it always uses the latest item version' do
      expect(execute).to be_success
      expect(Ai::Catalog::ItemConsumer.last).to have_attributes(
        project: owner_project,
        group: nil,
        item: owner_flow_item,
        enabled: true,
        locked: true,
        pinned_version_prefix: nil
      )
    end
  end

  context 'when the item is private to another project, and the user does not have permission to see the item' do
    let(:item) { create(:ai_catalog_flow) }

    it_behaves_like 'a failure', "You don't have permission to enable this agent or flow, or it doesn't exist"
  end

  context 'when save fails' do
    context 'when the model is invalid' do
      before do
        consumer = build(
          :ai_catalog_item_consumer, :child_item_consumer, group: group, project: consumer_project
        )
        consumer.validate
        allow(Ai::Catalog::ItemConsumer).to receive(:create).and_return(consumer)
      end

      it_behaves_like 'a failure', 'An agent or flow can only be enabled once per group or project'

      it 'returns an :already_configured reason for the sharding-key uniqueness violation' do
        response = execute

        expect(response).to be_error
        expect(response.reason).to eq(:already_configured)
      end
    end

    context 'when something else goes wrong' do
      before do
        allow_next_instance_of(Ai::Catalog::ItemConsumer) do |instance|
          allow(instance).to receive(:save).and_return(false)
        end
      end

      it_behaves_like 'a failure', 'Failed to enable agent or flow'

      it 'does not set a :already_configured reason on unrelated failures' do
        response = execute

        expect(response).to be_error
        expect(response.reason).not_to eq(:already_configured)
      end
    end
  end
end
