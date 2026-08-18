# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::Item, feature_category: :workflow_catalog do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
    it { is_expected.to belong_to(:project).optional }
    it { is_expected.to belong_to(:latest_version).required }
    it { is_expected.to belong_to(:latest_released_version) }

    it { is_expected.to have_many(:versions) }
    it { is_expected.to have_many(:consumers) }
    it { is_expected.to have_many(:stars) }
    it { is_expected.to have_many(:dependents) }
  end

  describe 'validations' do
    it { expect(build(:ai_catalog_item)).to be_valid }

    it { is_expected.to validate_presence_of(:organization) }
    it { is_expected.to validate_presence_of(:latest_version) }
    it { is_expected.to validate_presence_of(:item_type) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:verification_level) }

    it { is_expected.to validate_length_of(:name).is_at_least(3).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(1_024) }

    describe 'project belongs to same organization' do
      let_it_be(:default_organization) { create(:organization) }
      let_it_be(:different_organization) { create(:organization) }

      let_it_be(:project_with_default_organization) { create(:project, organization: default_organization) }
      let_it_be(:project_with_different_organization) { create(:project, organization: different_organization) }

      where(:project, :expected_validity) do
        [
          [ref(:project_with_default_organization), true],
          [nil, true],
          [ref(:project_with_different_organization), false]
        ]
      end

      with_them do
        subject(:item) { build(:ai_catalog_item, organization: default_organization, project: project) }

        it 'validates the project belongs to the same organization if present' do
          expect(item.valid?).to eq(expected_validity)

          unless expected_validity
            expect(item.errors[:project]).to include("organization must match the agent or flow's organization")
          end
        end
      end
    end

    describe 'reducing visibility' do
      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:consumer_project) { create(:project, group: group) }
      let_it_be_with_refind(:public_item) { create(:ai_catalog_item, :public, project: project) }
      let_it_be_with_refind(:restricted_item) { create(:ai_catalog_item, :restricted, project: project) }
      let_it_be_with_refind(:private_item) { create(:ai_catalog_item, :private, project: project) }

      context 'when item has external consumers within the same group hierarchy' do
        before_all do
          create(:ai_catalog_item_consumer, item: public_item, project: project)
          create(:ai_catalog_item_consumer, item: public_item, project: consumer_project)

          create(:ai_catalog_item_consumer, item: restricted_item, project: project)
          create(:ai_catalog_item_consumer, item: restricted_item, project: consumer_project)

          create(:ai_catalog_item_consumer, item: private_item, project: project)
        end

        it 'is invalid when reducing public item to private', :aggregate_failures do
          public_item.visibility = :private

          expect(public_item).not_to be_valid
          expect(public_item.errors[:visibility]).to include(
            s_('AICatalog|can\'t be made private because this item is enabled outside its owning project')
          )
        end

        it 'is valid when reducing public item to restricted' do
          public_item.visibility = :restricted

          expect(public_item).to be_valid
        end

        it 'is invalid when reducing restricted item to private', :aggregate_failures do
          restricted_item.visibility = :private

          expect(restricted_item).not_to be_valid
          expect(restricted_item.errors[:visibility]).to include(
            s_('AICatalog|can\'t be made private because this item is enabled outside its owning project')
          )
        end

        it 'is valid when increasing private item to public' do
          private_item.visibility = :public

          expect(private_item).to be_valid
        end

        it 'is valid when increasing restricted item to public' do
          restricted_item.visibility = :public

          expect(restricted_item).to be_valid
        end
      end

      context 'when item has consumers outside the group hierarchy' do
        let_it_be(:outside_group) { create(:group) }
        let_it_be(:outside_project) { create(:project, group: outside_group) }

        before_all do
          create(:ai_catalog_item_consumer, item: public_item, project: project)
          create(:ai_catalog_item_consumer, item: public_item, project: outside_project)
        end

        it 'is invalid when reducing public item to restricted', :aggregate_failures do
          public_item.visibility = :restricted

          expect(public_item).not_to be_valid
          expect(public_item.errors[:visibility]).to include(
            s_('AICatalog|can\'t be made restricted because this item is enabled outside ' \
              'the top-level group hierarchy')
          )
        end

        it 'is invalid when reducing public item to private', :aggregate_failures do
          public_item.visibility = :private

          expect(public_item).not_to be_valid
          expect(public_item.errors[:visibility]).to include(
            s_('AICatalog|can\'t be made private because this item is enabled outside its owning project')
          )
        end
      end

      context 'when item has no external consumers' do
        it 'is valid when reducing public item to private' do
          public_item.visibility = :private

          expect(public_item).to be_valid
        end

        it 'is valid when reducing public item to restricted' do
          public_item.visibility = :restricted

          expect(public_item).to be_valid
        end

        it 'is valid when reducing restricted item to private' do
          restricted_item.visibility = :private

          expect(restricted_item).to be_valid
        end
      end

      context 'when item belongs to a personal namespace project' do
        let_it_be(:personal_project) { create(:project) }
        let_it_be(:other_project) { create(:project) }
        let_it_be_with_refind(:personal_public_item) do
          create(:ai_catalog_item, :public, project: personal_project)
        end

        before_all do
          create(:ai_catalog_item_consumer, item: personal_public_item, project: personal_project)
          create(:ai_catalog_item_consumer, item: personal_public_item, project: other_project)
        end

        it 'falls back to external consumer check and blocks public to restricted', :aggregate_failures do
          expect(personal_project.root_ancestor).not_to be_a(Group)

          personal_public_item.visibility = :restricted

          expect(personal_public_item).not_to be_valid
          expect(personal_public_item.errors[:visibility]).to include(
            s_('AICatalog|can\'t be made restricted because this item is enabled outside ' \
              'the top-level group hierarchy')
          )
        end
      end
    end

    describe 'item_type_must_not_be_foundational' do
      context 'when item_type is foundational_agent' do
        subject(:item) { described_class.new(item_type: :foundational_agent) }

        it 'has a validation error relating to the item type' do
          expect(item).not_to be_valid

          expect(item.errors[:item_type]).to include('Cannot store foundational item types in database')
        end
      end

      context 'when item_type is agent' do
        subject(:item) { build(:ai_catalog_item, item_type: :agent) }

        it { is_expected.to be_valid }
      end
    end

    describe 'foundational item must be public' do
      context 'when item is a foundational flow' do
        context 'when not public' do
          subject(:item) { build(:ai_catalog_item, :flow, foundational_flow_reference: 'code_review/v1') }

          it 'is invalid' do
            expect(item).not_to be_valid
            expect(item.errors[:visibility]).to include('foundational items must be public')
          end
        end

        context 'when public' do
          subject(:item) { build(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'code_review/v1') }

          it { is_expected.to be_valid }
        end
      end

      context 'when item is a foundational third-party flow' do
        context 'when not public' do
          subject(:item) { build(:ai_catalog_item, :third_party_flow, verification_level: :gitlab_maintained) }

          it 'is invalid' do
            expect(item).not_to be_valid
            expect(item.errors[:visibility]).to include('foundational items must be public')
          end
        end

        context 'when public' do
          subject(:item) do
            build(:ai_catalog_item, :third_party_flow, :public, verification_level: :gitlab_maintained)
          end

          it { is_expected.to be_valid }
        end
      end

      context 'when item is not foundational' do
        subject(:item) { build(:ai_catalog_item, :flow) }

        it 'is valid even when private' do
          expect(item).to be_valid
        end
      end
    end
  end

  describe 'enums' do
    it 'defines item_type enum' do
      is_expected.to define_enum_for(:item_type)
        .with_values(agent: 1, flow: 2, third_party_flow: 3, foundational_agent: 4)
    end

    it 'defines verification_level enum with namespace verification levels' do
      is_expected.to define_enum_for(:verification_level).with_values(
        ::Namespaces::VerifiedNamespace::VERIFICATION_LEVELS
      )
    end

    it 'defines visibility enum' do
      is_expected.to define_enum_for(:visibility)
        .with_values(private: 0, restricted: 1, public: 2)
        .with_prefix(:visibility)
    end
  end

  describe 'scopes' do
    describe '.for_verification_level' do
      ::Namespaces::VerifiedNamespace::VERIFICATION_LEVELS.each_key do |level|
        it "returns items with #{level} verification level" do
          expected_item = create(:ai_catalog_item, verification_level: level)

          expect(described_class.for_verification_level(level))
            .to contain_exactly(expected_item)
        end
      end

      it 'returns multiple items with the same verification level' do
        gitlab_maintained_items = create_list(:ai_catalog_item, 2, verification_level: :gitlab_maintained)

        expect(described_class.for_verification_level(:gitlab_maintained))
          .to match_array(gitlab_maintained_items)
      end
    end

    describe '.in_organization' do
      let_it_be(:item_1) { create(:ai_catalog_item, organization: create(:organization)) }
      let_it_be(:item_2) { create(:ai_catalog_item, organization: create(:organization)) }

      it 'returns items for the specified organization' do
        expect(described_class.in_organization(item_1.organization)).to contain_exactly(item_1)
      end
    end

    describe '.not_deleted' do
      let_it_be(:items) { create_list(:ai_catalog_item, 2) }
      let_it_be(:deleted_items) { create_list(:ai_catalog_item, 2, deleted_at: 1.day.ago) }

      it 'returns not deleted items' do
        expect(described_class.not_deleted).to match_array(items)
      end
    end

    describe '.public_only' do
      let_it_be(:public_item) { create(:ai_catalog_item, :public) }
      let_it_be(:private_item) { create(:ai_catalog_item) }

      it 'returns the public items' do
        expect(described_class.public_only).to contain_exactly(public_item)
      end
    end

    describe '.restricted_only' do
      let_it_be(:restricted_item) { create(:ai_catalog_item, :restricted) }
      let_it_be(:public_item) { create(:ai_catalog_item, :public) }
      let_it_be(:private_item) { create(:ai_catalog_item, :private) }

      it 'returns only items with restricted visibility' do
        expect(described_class.restricted_only).to contain_exactly(restricted_item)
      end
    end

    describe '.restricted_within_group_hierarchy' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: top_level_group) }
      let_it_be(:project_in_top_level_group) { create(:project, group: top_level_group) }
      let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
      let_it_be(:project_outside_hierarchy) { create(:project) }

      let_it_be(:restricted_item_in_hierarchy) do
        create(:ai_catalog_item, :restricted, project: project_in_top_level_group)
      end

      let_it_be(:restricted_item_in_subgroup) do
        create(:ai_catalog_item, :restricted, project: project_in_subgroup)
      end

      let_it_be(:restricted_item_outside_hierarchy) do
        create(:ai_catalog_item, :restricted, project: project_outside_hierarchy)
      end

      it 'returns restricted items within hierarchy' do
        expect(described_class.restricted_within_group_hierarchy(project_in_top_level_group))
          .to contain_exactly(
            restricted_item_in_hierarchy,
            restricted_item_in_subgroup
          )
      end

      it 'excludes restricted items outside the hierarchy' do
        expect(described_class.restricted_within_group_hierarchy(project_in_top_level_group))
          .not_to include(restricted_item_outside_hierarchy)
      end
    end

    describe '.without_restricted' do
      let_it_be(:public_item) { create(:ai_catalog_item, :public) }
      let_it_be(:private_item) { create(:ai_catalog_item) }
      let_it_be(:restricted_item) { create(:ai_catalog_item, :restricted) }

      it 'excludes restricted items' do
        expect(described_class.without_restricted).to contain_exactly(public_item, private_item)
      end
    end

    describe '.public_or_visible_to_user' do
      let_it_be(:user) { create(:user) }

      let_it_be(:guest_project) { create(:project, guests: user) }

      let_it_be(:public_item) { create(:ai_catalog_item, :public) }
      let_it_be(:private_item) { create(:ai_catalog_item) }

      let_it_be(:private_item_in_guest_project) do
        create(:ai_catalog_item, project: guest_project)
      end

      let_it_be(:restricted_item) { create(:ai_catalog_item, :restricted) }

      let_it_be(:restricted_item_in_guest_project) do
        create(:ai_catalog_item, :restricted, project: guest_project)
      end

      it 'returns only public items when user is nil' do
        expect(described_class.public_or_visible_to_user(nil)).to contain_exactly(
          public_item
        )
      end

      it 'returns public items and member items, excludes restricted items' do
        expect(described_class.public_or_visible_to_user(user)).to contain_exactly(
          public_item,
          private_item_in_guest_project
        )
      end

      context 'when allow_restricted is true' do
        it 'includes restricted items for project members' do
          expect(described_class.public_or_visible_to_user(user, allow_restricted: true)).to contain_exactly(
            public_item,
            private_item_in_guest_project,
            restricted_item_in_guest_project
          )
        end
      end
    end

    describe '.search' do
      let_it_be(:issue_label_agent) { create(:ai_catalog_agent, name: 'Autotriager') }
      let_it_be(:mr_review_flow) { create(:ai_catalog_flow, description: 'Merge request reviewer') }

      it 'finds items by partial name' do
        expect(described_class.search('triage')).to contain_exactly(issue_label_agent)
      end

      it 'finds items by partial description' do
        expect(described_class.search('review')).to contain_exactly(mr_review_flow)
      end
    end

    describe '.with_item_type' do
      let_it_be(:agent_type_item) { create(:ai_catalog_item, :public, item_type: :agent) }
      let_it_be(:flow_type_item) { create(:ai_catalog_item, :public, item_type: :flow) }

      it 'returns items of the specified item type' do
        result = described_class.with_item_type(described_class::AGENT_TYPE)

        expect(described_class.count).to eq(2)
        expect(result).to contain_exactly(agent_type_item)
      end
    end

    describe '.order_by_last_30_day_usage_count_desc' do
      it 'orders items by usage count descending' do
        low_usage = create(:ai_catalog_item, last_30_day_usage_count: 2)
        low_usage_newer = create(:ai_catalog_item, last_30_day_usage_count: 2)
        high_usage = create(:ai_catalog_item, last_30_day_usage_count: 10)

        expect(described_class.order_by_last_30_day_usage_count_desc).to eq([high_usage, low_usage_newer, low_usage])
      end
    end

    describe '.order_by_last_30_day_usage_count_asc' do
      it 'orders items by usage count ascending' do
        low_usage = create(:ai_catalog_item, last_30_day_usage_count: 2)
        low_usage_newer = create(:ai_catalog_item, last_30_day_usage_count: 2)
        high_usage = create(:ai_catalog_item, last_30_day_usage_count: 10)

        expect(described_class.order_by_last_30_day_usage_count_asc).to eq([low_usage, low_usage_newer, high_usage])
      end
    end

    describe '.sort_by_key' do
      let_it_be(:item_low)  { create(:ai_catalog_item, star_count: 1) }
      let_it_be(:item_high) { create(:ai_catalog_item, star_count: 10) }

      it 'orders by star count descending when key is :star_count_desc' do
        expect(described_class.sort_by_key(:star_count_desc)).to eq([item_high, item_low])
      end

      it 'orders by star count ascending when key is :star_count_asc' do
        expect(described_class.sort_by_key(:star_count_asc)).to eq([item_low, item_high])
      end

      it 'returns all records without ordering when key is unknown' do
        expect(described_class.sort_by_key(:unknown)).to match_array([item_low, item_high])
      end
    end

    describe '.foundational_chat_agent_ids' do
      it 'returns empty array when not on SaaS' do
        stub_saas_features(gitlab_duo_saas_only: false)

        expect(described_class.foundational_chat_agent_ids).to eq([])
      end

      context 'when on SaaS', :saas do
        it 'returns global_catalog_ids from foundational chat agents' do
          ids = described_class.foundational_chat_agent_ids

          expected_ids = ::Ai::FoundationalChatAgent.all.filter_map(&:global_catalog_id)
          expect(ids).to match_array(expected_ids)
          expect(ids).not_to include(nil)
        end
      end
    end

    describe '.foundational_external_agent_ids' do
      it 'returns empty array when not on SaaS' do
        stub_saas_features(gitlab_duo_saas_only: false)

        expect(described_class.foundational_external_agent_ids).to eq([])
      end

      context 'when on SaaS', :saas do
        it 'returns hardcoded external agent IDs' do
          expect(described_class.foundational_external_agent_ids).to eq(
            Ai::Catalog::Item::FOUNDATIONAL_EXTERNAL_AGENT_IDS
          )
        end
      end
    end

    describe '.visible_to_user_with_priority_ordering' do
      let_it_be(:user) { create(:user) }
      let_it_be(:guest_project) { create(:project, guests: user) }

      # Create items in random priority order to ensure ordering is from logic, not creation order
      let_it_be(:public_item) { create(:ai_catalog_item, :public) }
      let_it_be(:private_item) { create(:ai_catalog_item) }

      let_it_be(:foundational_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference, :public,
          verification_level: :gitlab_maintained)
      end

      let_it_be(:private_item_in_guest_project) do
        create(:ai_catalog_item, project: guest_project)
      end

      let_it_be(:foundational_external_agent) do
        create(:ai_catalog_agent, :public, verification_level: :gitlab_maintained)
      end

      it 'returns visible items ordered by priority' do
        result = described_class.visible_to_user_with_priority_ordering(user).to_a

        expect(result).to eq([
          foundational_external_agent,
          foundational_flow,
          private_item_in_guest_project,
          public_item
        ])
      end

      context 'when user is nil' do
        it 'returns only public items' do
          result = described_class.visible_to_user_with_priority_ordering(nil).to_a

          expect(result).to contain_exactly(
            public_item,
            foundational_flow,
            foundational_external_agent
          )
        end
      end

      context 'when on SaaS', :saas do
        let_it_be(:foundational_agent) { create(:ai_catalog_agent, :public) }
        let_it_be(:other_foundational_external_agent) do
          create(:ai_catalog_agent, :public)
        end

        before do
          allow(described_class).to receive_messages(
            foundational_chat_agent_ids: [foundational_agent.id],
            foundational_external_agent_ids: [foundational_external_agent.id, other_foundational_external_agent.id]
          )
        end

        it 'returns visible items ordered by priority' do
          result = described_class.visible_to_user_with_priority_ordering(user).to_a

          expect(result).to eq([
            foundational_agent,
            other_foundational_external_agent,
            foundational_external_agent,
            foundational_flow,
            private_item_in_guest_project,
            public_item
          ])
        end
      end

      context 'with visibility-based filtering' do
        let_it_be(:restricted_item) { create(:ai_catalog_item, :restricted) }

        it 'excludes restricted and inaccessible private items by default', :aggregate_failures do
          result = described_class.visible_to_user_with_priority_ordering(user).to_a

          expect(result).not_to include(restricted_item)
          expect(result).to include(public_item)
          expect(result).not_to include(private_item)
        end

        context 'when allow_restricted is true' do
          it 'includes restricted and public items, excludes inaccessible private items', :aggregate_failures do
            result = described_class.visible_to_user_with_priority_ordering(user, allow_restricted: true).to_a

            expect(result).to include(restricted_item)
            expect(result).to include(public_item)
            expect(result).not_to include(private_item)
          end
        end
      end
    end

    describe '.within_group_hierarchy_or_foundational' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: top_level_group) }
      let_it_be(:project_in_top_level_group) { create(:project, group: top_level_group) }
      let_it_be(:project_in_subgroup) { create(:project, group: subgroup) }
      let_it_be(:project_outside_hierarchy) { create(:project) }

      let_it_be(:item_in_top_level) { create(:ai_catalog_item, project: project_in_top_level_group) }
      let_it_be(:item_in_subgroup) { create(:ai_catalog_item, project: project_in_subgroup) }
      let_it_be(:item_outside_hierarchy) { create(:ai_catalog_item, project: project_outside_hierarchy) }
      let_it_be(:foundational_item) do
        create(:ai_catalog_item, verification_level: :gitlab_maintained)
      end

      it 'returns items owned within the hierarchy, and foundational items' do
        expect(described_class.within_group_hierarchy_or_foundational(top_level_group))
          .to contain_exactly(
            item_in_top_level,
            item_in_subgroup,
            foundational_item
          )
      end

      context 'with hardcoded foundational chat agent IDs' do
        let_it_be(:chat_agent_outside_hierarchy) do
          create(:ai_catalog_item, project: project_outside_hierarchy, verification_level: :unverified)
        end

        before do
          allow(described_class).to receive(:foundational_chat_agent_ids).and_return([chat_agent_outside_hierarchy.id])
        end

        it 'returns the chat agent regardless of verification_level' do
          expect(described_class.within_group_hierarchy_or_foundational(top_level_group))
            .to include(chat_agent_outside_hierarchy)
        end
      end

      context 'with hardcoded foundational external agent IDs' do
        let_it_be(:external_agent_outside_hierarchy) do
          create(:ai_catalog_item, project: project_outside_hierarchy, verification_level: :unverified)
        end

        before do
          allow(described_class).to receive(:foundational_external_agent_ids)
            .and_return([external_agent_outside_hierarchy.id])
        end

        it 'returns the external agent regardless of verification_level' do
          expect(described_class.within_group_hierarchy_or_foundational(top_level_group))
            .to include(external_agent_outside_hierarchy)
        end
      end

      context 'when given a non-root group' do
        it 'raises ArgumentError' do
          expect { described_class.within_group_hierarchy_or_foundational(subgroup) }
            .to raise_error(ArgumentError, 'top_level_group must be a root group')
        end
      end

      context 'when given a non-Group argument' do
        it 'raises ArgumentError' do
          expect { described_class.within_group_hierarchy_or_foundational(project_in_top_level_group) }
            .to raise_error(ArgumentError, 'top_level_group must be a root group')
        end
      end
    end

    describe '.foundational_flow_ids' do
      let_it_be(:flow1) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
      let_it_be(:flow2) { create(:ai_catalog_item, :with_foundational_flow_reference, :public) }
      let_it_be(:non_foundational) { create(:ai_catalog_item, :public) }

      it 'returns IDs of foundational flows' do
        ids = described_class.foundational_flow_ids

        expect(ids).to match_array([flow1.id, flow2.id])
      end

      it 'limits results to FOUNDATIONAL_FLOWS_LIMIT' do
        create(:ai_catalog_item, :with_foundational_flow_reference, :public) # 3rd flow

        stub_const("#{described_class}::FOUNDATIONAL_FLOWS_LIMIT", 2)

        ids = described_class.foundational_flow_ids

        expect(ids.count).to eq(2)
        expect(ids).to all(be_in([flow1.id, flow2.id]))
      end
    end

    describe '.foundational_flow_ids_for_references' do
      let_it_be(:code_review_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:sast_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'sast_fp_detection/v1')
      end

      let_it_be(:item_without_reference) { create(:ai_catalog_item) }

      it 'returns a hash mapping references to IDs' do
        result = described_class.foundational_flow_ids_for_references(['code_review/v1', 'sast_fp_detection/v1'])

        expect(result).to eq({
          'code_review/v1' => code_review_flow.id,
          'sast_fp_detection/v1' => sast_flow.id
        })
      end

      it 'returns empty hash for blank references' do
        expect(described_class.foundational_flow_ids_for_references([])).to eq({})
        expect(described_class.foundational_flow_ids_for_references(nil)).to eq({})
      end

      it 'only returns matching references' do
        result = described_class.foundational_flow_ids_for_references(['code_review/v1', 'nonexistent/v1'])

        expect(result).to eq({ 'code_review/v1' => code_review_flow.id })
      end

      it 'respects FOUNDATIONAL_FLOWS_LIMIT' do
        stub_const("#{described_class}::FOUNDATIONAL_FLOWS_LIMIT", 1)

        result = described_class.foundational_flow_ids_for_references(['code_review/v1', 'sast_fp_detection/v1'])

        expect(result.size).to eq(1)
      end
    end

    describe '.foundational_flows' do
      let_it_be(:item_with_reference) { create(:ai_catalog_item, :with_foundational_flow_reference) }
      let_it_be(:item_without_reference) { create(:ai_catalog_item) }

      it 'returns only items with foundational_flow_reference' do
        expect(described_class.foundational_flows).to contain_exactly(item_with_reference)
      end

      it 'excludes items without foundational_flow_reference' do
        expect(described_class.foundational_flows).not_to include(item_without_reference)
      end
    end

    describe '.with_foundational_flow_reference' do
      let_it_be(:code_review_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'code_review/v1')
      end

      let_it_be(:sast_flow) do
        create(:ai_catalog_item, :with_foundational_flow_reference,
          foundational_flow_reference: 'sast_fp_detection/v1')
      end

      let_it_be(:item_without_reference) { create(:ai_catalog_item) }

      it 'returns item with matching foundational_flow_reference' do
        result = described_class.with_foundational_flow_reference('code_review/v1')

        expect(result).to contain_exactly(code_review_flow)
      end

      it 'returns empty relation when no match found' do
        result = described_class.with_foundational_flow_reference('nonexistent/v1')

        expect(result).to be_empty
      end

      it 'does not return items without foundational_flow_reference' do
        result = described_class.with_foundational_flow_reference('code_review/v1')

        expect(result).not_to include(item_without_reference)
      end
    end

    describe '.include_foundational_items' do
      let_it_be(:organization) { create(:organization) }
      let_it_be(:regular_agent) { create(:ai_catalog_agent, :public, organization: organization) }
      let_it_be(:regular_flow) { create(:ai_catalog_flow, :public, organization: organization) }

      let(:synthetic_items) { results.select { |item| item.reference.present? } }
      let(:db_items) { results.reject { |item| item.reference.present? } }

      subject(:results) { described_class.include_foundational_items(organization.id) }

      it 'includes the synthetic foundational agents' do
        expect(synthetic_items).not_to be_empty
        expect(synthetic_items.size).to eq(Ai::FoundationalChatAgent.count)
      end

      it 'uses a UNION ALL query' do
        expect(results.to_sql).to include('UNION ALL')
      end

      it 'includes regular database-backed items' do
        expect(db_items).to include(regular_agent, regular_flow)
      end

      it 'assigns the provided organization_id and sets a nil ID to synthetic items' do
        synthetic_items.each do |item|
          expect(item.organization_id).to eq(organization.id)
          expect(item.id).to be_nil
        end
      end

      context 'when foundational chat agent IDs match existing DB items' do
        let_it_be(:existing_catalog_item) { create(:ai_catalog_agent) }

        before do
          allow(::Ai::FoundationalChatAgent)
            .to receive_message_chain(:all, :filter_map).and_return([existing_catalog_item.id])
        end

        context 'when on SaaS', :saas do
          it 'excludes DB items whose IDs match foundational_chat_agent_ids' do
            expect(db_items).not_to include(existing_catalog_item)
          end
        end

        context 'when not on SaaS' do
          it 'does not exclude the foundational items' do
            expect(db_items).to include(existing_catalog_item)
          end
        end
      end
    end

    describe '.without_consumers' do
      let_it_be(:project) { create(:project) }
      let_it_be(:item_with_consumers) { create(:ai_catalog_item, :public, project: project) }
      let_it_be(:item_without_consumers) { create(:ai_catalog_item, :public, project: project) }
      let_it_be(:consumer) { create(:ai_catalog_item_consumer, project: project, item: item_with_consumers) }

      it 'returns only items without any consumers' do
        expect(described_class.without_consumers).to contain_exactly(item_without_consumers)
      end

      context 'when an item has multiple consumers' do
        let_it_be(:another_consumer) do
          create(:ai_catalog_item_consumer, project: create(:project), item: item_with_consumers)
        end

        it 'still excludes the item' do
          expect(described_class.without_consumers).to contain_exactly(item_without_consumers)
        end
      end

      context 'when all items have consumers' do
        before do
          create(:ai_catalog_item_consumer, project: project, item: item_without_consumers)
        end

        it 'returns an empty collection' do
          expect(described_class.without_consumers).to be_empty
        end
      end
    end
  end

  describe 'callbacks' do
    describe '.prevent_deletion_if_consumers_exist' do
      let_it_be(:item, freeze: false) { create(:ai_catalog_item, deleted_at: 1.day.ago) }

      it 'allows deletion if no consumers exist' do
        expect(item.destroy).to be_truthy
        expect { item.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context 'when consumers exist' do
        before do
          allow(item).to receive(:consumers).and_return([build_stubbed(:ai_catalog_item_consumer, item: item)])
        end

        it 'prevents deletion' do
          expect(item.destroy).to be(false)
          expect(item.errors[:base]).to contain_exactly('Cannot delete an item that has consumers')
          expect { item.reload }.not_to raise_error
        end
      end
    end
  end

  describe '#deleted?' do
    let(:item) { build_stubbed(:ai_catalog_item, deleted_at: deleted_at) }

    context 'when deleted_at is not nil' do
      let(:deleted_at) { 1.day.ago }

      it 'returns true' do
        expect(item).to be_deleted
      end
    end

    context 'when deleted_at is nil' do
      let(:deleted_at) { nil }

      it 'returns false' do
        expect(item).not_to be_deleted
      end
    end
  end

  describe 'visibility dual-write callbacks' do
    context 'when public changes' do
      it 'syncs visibility to public when public is set to true' do
        item = create(:ai_catalog_item, public: false)

        item.update!(public: true)

        expect(item.visibility).to eq('public')
      end

      it 'syncs visibility to private when public is set to false' do
        item = create(:ai_catalog_item, public: true)

        item.update!(public: false)

        expect(item.visibility).to eq('private')
      end
    end

    context 'when visibility changes' do
      it 'syncs public to true when visibility is set to public' do
        item = create(:ai_catalog_item, :private)

        item.update!(visibility: :public)

        expect(item.public).to be(true)
      end

      it 'syncs public to false when visibility is set to private' do
        item = create(:ai_catalog_item, :public)

        item.update!(visibility: :private)

        expect(item.public).to be(false)
      end

      it 'syncs public to false when visibility is set to restricted' do
        item = create(:ai_catalog_item, :public)

        item.update!(visibility: :restricted)

        expect(item.public).to be(false)
      end
    end

    context 'when both public and visibility are set simultaneously' do
      it 'respects consistent explicit values without callback interference' do
        item = create(:ai_catalog_item, :public)

        item.update!(public: false, visibility: :restricted)

        expect(item.visibility).to eq('restricted')
        expect(item.public).to be(false)
      end
    end
  end

  describe '#soft_delete' do
    it 'updates deleted_at attribute' do
      item = create(:ai_catalog_item)

      expect { item.soft_delete }.to change { item.deleted_at }.from(nil)
    end
  end

  describe '#human_item_type' do
    it 'humanizes the item_type' do
      expect(build(:ai_catalog_agent).human_item_type).to eq('agent')
      expect(build(:ai_catalog_flow).human_item_type).to eq('flow')
      expect(build(:ai_catalog_third_party_flow).human_item_type).to eq('external agent')
    end

    it 'handles all item_types' do
      described_class.item_types.each_value do |type|
        expect(described_class.new(item_type: type).human_item_type).not_to be_nil
      end
    end
  end

  describe '#definition' do
    let(:version) { item.latest_version }

    context 'when item_type is agent' do
      let(:item) { create(:ai_catalog_agent) }

      it 'returns an AgentDefinition instance' do
        result = item.definition(version.version)

        expect(result).to be_an_instance_of(Ai::Catalog::AgentDefinition)
      end

      it 'passes the item and version to AgentDefinition' do
        expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, version)

        item.definition(version.version)
      end
    end

    context 'when item_type is flow' do
      let(:item) { create(:ai_catalog_flow) }

      it 'returns a FlowDefinition instance' do
        result = item.definition(version.version)

        expect(result).to be_an_instance_of(Ai::Catalog::FlowDefinition)
      end

      it 'passes the item and version to FlowDefinition' do
        expect(Ai::Catalog::FlowDefinition).to receive(:new).with(item, version)

        item.definition(version.version)
      end

      context 'when pinned_version_id is provided' do
        it 'raises an ArgumentError' do
          expect { item.definition(nil, item.versions.first.id) }.to raise_error(
            ArgumentError, 'pinned_version_id is not supported for flows'
          )
        end
      end
    end

    context 'when item_type is third party flow' do
      let(:item) { create(:ai_catalog_third_party_flow) }

      it 'returns the version definition' do
        expect(item.definition).to eq(version.definition)
      end
    end

    describe 'version resolution' do
      let_it_be(:item, freeze: false) { create(:ai_catalog_agent) }
      let_it_be(:v1_1, freeze: false) { create(:ai_catalog_agent_version, item: item, version: '1.1.0') }
      let_it_be(:v2) { create(:ai_catalog_agent_version, item: item, version: '2.0.0') }

      context 'when no version_prefix is pinned' do
        it 'resolves to the latest version' do
          expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, v2).once

          item.definition
        end
      end

      context 'when a version_prefix is pinned' do
        it 'resolves the correct version' do
          expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, v1_1).once

          item.definition('1.1.0')
        end
      end

      context 'when a version_id is pinned' do
        it 'returns the version by its id' do
          expect(Ai::Catalog::AgentDefinition).to receive(:new).with(item, v1_1).once

          item.definition(nil, v1_1.id)
        end
      end
    end
  end

  describe '#latest_released_version_with_fallback' do
    let(:item) { build(:ai_catalog_item) }
    let(:latest_released_version) { build(:ai_catalog_item_version, :released) }
    let(:latest_version) { build(:ai_catalog_item_version, :released) }
    let(:draft_version) { build(:ai_catalog_item_version, :draft) }

    subject(:latest_released_version_with_fallback) { item.latest_released_version_with_fallback }

    before do
      allow(item).to receive_messages(latest_released_version: latest_released_version, latest_version: latest_version)
    end

    it { is_expected.to eq(latest_released_version) }

    context 'when latest_released_version is nil' do
      let(:latest_released_version) { nil }

      it { is_expected.to eq(latest_version) }

      context 'when latest_version is a draft' do
        let(:latest_version) { draft_version }

        it { is_expected.to be_nil }
      end
    end
  end

  describe '#resolve_version' do
    let_it_be(:item, freeze: false) { create(:ai_catalog_agent) }
    let_it_be(:v1, freeze: false) { create(:ai_catalog_agent_version, item: item, version: '1.0.0') }
    let_it_be(:v1_1, freeze: false) { create(:ai_catalog_agent_version, item: item, version: '1.1.0') }
    let_it_be(:v2) { create(:ai_catalog_agent_version, item: item, version: '2.0.0') }

    context 'when no version_prefix is given' do
      it 'resolves to the latest version' do
        expect(item.resolve_version).to eq(v2)
      end
    end

    context 'when a specific version_prefix is given' do
      it 'resolves the correct version' do
        expect(item.resolve_version('1.1.0')).to eq(v1_1)
      end
    end

    context 'when the version_prefix does not match any version' do
      it 'tracks and raises a dev exception and returns nil' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).with(
          instance_of(StandardError),
          item_id: item.id, pinned_version_prefix: '9.9.9'
        )

        expect(item.resolve_version('9.9.9')).to be_nil
      end
    end
  end

  describe '#build_new_version' do
    let(:item) { described_class.new }

    it 'builds new version, and sets #latest_version' do
      item.build_new_version({ id: 1 })
      item.build_new_version({ id: 2 })

      expect(item.versions.size).to eq(2)
      expect(item.latest_version).to be_present
      expect(item.latest_version).to eq(item.versions.last)
    end
  end

  describe '#next_version_number' do
    let_it_be_with_reload(:item) { create(:ai_catalog_agent) }

    context 'when there are no released versions' do
      it 'returns the default version' do
        expect(item.next_version_number).to eq('1.0.0')
      end
    end

    context 'when there are only draft versions' do
      before do
        create(:ai_catalog_item_version, :draft, item: item)
      end

      it 'returns the default version' do
        expect(item.next_version_number).to eq('1.0.0')
      end
    end

    context 'when there are released versions' do
      before do
        create(:ai_catalog_item_version, :released, item: item, version: '1.0.0')
        create(:ai_catalog_item_version, :released, item: item, version: '1.1.0')
      end

      it 'returns a minor bump from the latest released version' do
        expect(item.next_version_number).to eq('1.2.0')
      end

      it 'supports custom bump levels', :aggregate_failures do
        expect(item.next_version_number(bump_level: :major)).to eq('2.0.0')
        expect(item.next_version_number(bump_level: :patch)).to eq('1.1.1')
      end
    end
  end

  describe '#foundational?' do
    subject(:foundational) { item.foundational? }

    let(:is_saas) { false }
    let(:item_id) { 100 }
    let(:item) { build(:ai_catalog_item, :agent, id: item_id) }

    before do
      stub_saas_features(gitlab_duo_saas_only: is_saas)
    end

    context 'when item is agent' do
      context 'when not on GitLab SaaS' do
        let(:is_saas) { false }

        it { is_expected.to be(false) }
      end

      context 'when on GitLab SaaS' do
        let(:is_saas) { true }

        context 'when item is a foundational agent' do
          let(:item_id) { 348 }

          it { is_expected.to be(true) }
        end

        context 'when item is not a foundational agent' do
          it { is_expected.to be(false) }
        end
      end
    end

    context 'when item is flow' do
      let(:item) { create(:ai_catalog_item, :flow, :public, foundational_flow_reference: foundational_flow_reference) }
      let(:foundational_flow_reference) { nil }

      context 'when item has foundational flow reference' do
        let(:foundational_flow_reference) { 'code_review/v1' }

        it { is_expected.to be(true) }
      end

      context 'when item is not a foundational flow' do
        it { is_expected.to be(false) }
      end
    end

    context 'when item is third-party flow' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow) }

      it 'returns false if foundational_third_party_flow? is false' do
        expect(item).to receive(:foundational_third_party_flow?).and_return(false)
        is_expected.to be(false)
      end

      it 'returns true if foundational_third_party_flow? is true' do
        expect(item).to receive(:foundational_third_party_flow?).and_return(true)
        is_expected.to be(true)
      end
    end

    context 'when item_type is foundational_agent' do
      let(:item) { described_class.new(item_type: :foundational_agent) }

      it { is_expected.to be(true) }
    end
  end

  describe '#blocked_by_namespace_restriction?' do
    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:other_group) { create(:group) }
    let_it_be(:item_project) { create(:project, group: top_level_group) }

    let(:item) { build(:ai_catalog_flow, :public, project: item_project) }

    subject(:blocked) { item.blocked_by_namespace_restriction?(top_level_group) }

    context 'when restriction is not enabled on the root ancestor' do
      before do
        top_level_group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: false)
      end

      it { is_expected.to be(false) }
    end

    context 'when restriction is enabled on the root ancestor' do
      before do
        top_level_group.ai_settings.update!(ai_catalog_restricted_to_group_hierarchy: true)
      end

      context 'when item has no project' do
        let(:item) { build(:ai_catalog_flow, :public, project: nil) }

        it { is_expected.to be(false) }
      end

      context 'when item is foundational' do
        let(:item) do
          build(:ai_catalog_flow, :public, project: item_project, foundational_flow_reference: 'code_review/v1')
        end

        it { is_expected.to be(false) }
      end

      context 'when item belongs to a project within the root ancestor hierarchy' do
        it { is_expected.to be(false) }
      end

      context 'when item belongs to a project outside the root ancestor hierarchy' do
        let_it_be(:external_project) { create(:project, group: other_group) }
        let(:item) { build(:ai_catalog_flow, :public, project: external_project) }

        it { is_expected.to be(true) }
      end

      context 'when a project is passed as the container instead of a root ancestor' do
        let_it_be(:sub_project) { create(:project, group: top_level_group) }
        let_it_be(:external_project) { create(:project, group: other_group) }

        subject(:blocked) { item.blocked_by_namespace_restriction?(sub_project) }

        context 'when item belongs to a project within the root ancestor hierarchy' do
          it { is_expected.to be(false) }
        end

        context 'when item belongs to a project outside the root ancestor hierarchy' do
          let(:item) { build(:ai_catalog_flow, :public, project: external_project) }

          it { is_expected.to be(true) }
        end
      end
    end
  end

  describe '#outside_restricted_hierarchy?' do
    let_it_be(:owner_group) { create(:group) }
    let_it_be(:owner_project) { create(:project, group: owner_group) }
    let_it_be(:sibling_project) { create(:project, group: owner_group) }
    let_it_be(:outside_group) { create(:group) }
    let_it_be(:outside_project) { create(:project, group: outside_group) }

    let(:item) { build(:ai_catalog_agent, :restricted, project: owner_project) }

    subject(:result) { item.outside_restricted_hierarchy?(container) }

    context 'when the container is a group within the same TLG hierarchy as the item' do
      let(:container) { owner_group }

      it { is_expected.to be(false) }
    end

    context 'when the container is a project within the same TLG hierarchy as the item' do
      let(:container) { sibling_project }

      it { is_expected.to be(false) }
    end

    context 'when the container is outside the item TLG hierarchy' do
      let(:container) { outside_project }

      it { is_expected.to be(true) }

      context 'when the item is not restricted' do
        before do
          item.visibility = :public
        end

        it { is_expected.to be(false) }
      end

      context 'when the item has no project' do
        before do
          item.project = nil
        end

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#foundational_chat_agent?' do
    subject(:foundational_chat_agent) { item.foundational_chat_agent? }

    let(:is_saas) { false }
    let(:item_id) { 42 }
    let(:item) { build(:ai_catalog_item, :agent, id: item_id) }

    before do
      stub_saas_features(gitlab_duo_saas_only: is_saas)
    end

    context 'when not on GitLab SaaS' do
      it { is_expected.to be(false) }
    end

    context 'when on GitLab SaaS' do
      let(:is_saas) { true }

      context 'when item is a foundational agent' do
        # 348 is the global_catalog_id for the duo_planner foundational agent
        # https://gitlab.com/gitlab-org/gitlab/-/blob/745f1ec2c6622fdfb14f17f8bc932ede44413adb/ee/lib/ai/foundational_chat_agents_definitions.rb#L23
        let(:item_id) { 348 }

        it { is_expected.to be(true) }
      end

      context 'when item is not a foundational agent' do
        it { is_expected.to be(false) }
      end

      context 'when item id is not present' do
        let(:item_id) { nil }

        it { is_expected.to be(false) }
      end
    end
  end

  describe '#foundational_flow?' do
    subject(:foundational_flow) { item.foundational_flow? }

    context 'when item is not a flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :agent) }

      it { is_expected.to be(false) }
    end

    context 'when item is a non-foundational flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :flow, foundational_flow_reference: nil) }

      it { is_expected.to be(false) }
    end

    context 'when item is a foundational flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'code_review/v1') }

      it { is_expected.to be(true) }
    end
  end

  describe '#foundational_third_party_flow?' do
    subject(:foundational_third_party_flow) { item.foundational_third_party_flow? }

    context 'when item is not a third party flow' do
      let(:item) { build_stubbed(:ai_catalog_agent, verification_level: 'gitlab_maintained') }

      it { is_expected.to be(false) }
    end

    context 'when third party flow is not GitLab-maintained' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow, verification_level: 'unverified') }

      it { is_expected.to be(false) }
    end

    context 'when third party flow is GitLab-maintained' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow, :public, verification_level: 'gitlab_maintained') }

      it { is_expected.to be(true) }
    end
  end

  describe '#custom_flow?' do
    subject(:custom_flow) { item.custom_flow? }

    context 'when item is not a flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :agent) }

      it { is_expected.to be(false) }
    end

    context 'when item is a foundational flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :flow, :public, foundational_flow_reference: 'code_review/v1') }

      it { is_expected.to be(false) }
    end

    context 'when item is a non-foundational flow' do
      let(:item) { build_stubbed(:ai_catalog_item, :flow, foundational_flow_reference: nil) }

      it { is_expected.to be(true) }
    end
  end

  describe '#custom_third_party_flow?' do
    subject(:custom_third_party_flow) { item.custom_third_party_flow? }

    context 'when item is not a third party flow' do
      let(:item) { build_stubbed(:ai_catalog_agent) }

      it { is_expected.to be(false) }
    end

    context 'when third party flow is GitLab-maintained (foundational)' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow, :public, verification_level: 'gitlab_maintained') }

      it { is_expected.to be(false) }
    end

    context 'when third party flow is not GitLab-maintained' do
      let(:item) { build_stubbed(:ai_catalog_third_party_flow, verification_level: 'unverified') }

      it { is_expected.to be(true) }
    end
  end

  describe '#foundational_flow' do
    subject(:foundational_flow) { item.foundational_flow }

    let(:foundational_flow_reference) { 'code_review/v1' }
    let(:item_type) { 'flow' }
    let(:item) do
      build_stubbed(
        :ai_catalog_item,
        :public,
        foundational_flow_reference: foundational_flow_reference,
        item_type: item_type
      )
    end

    context 'when item is an agent' do
      let(:item_type) { 'agent' }

      it { is_expected.to be_nil }
    end

    context 'when item does not have a foundational flow reference' do
      let(:foundational_flow_reference) { nil }

      it 'returns nil' do
        expect(foundational_flow).to be_nil
      end
    end

    context 'when item has an invalid foundational flow reference' do
      let(:foundational_flow_reference) { 'foo' }

      it 'returns nil' do
        expect(foundational_flow).to be_nil
      end
    end

    context 'when item has a valid foundational flow reference' do
      it 'returns the foundational flow associated with that reference' do
        expect(foundational_flow).to eq(::Ai::Catalog::FoundationalFlow[foundational_flow_reference])
      end
    end
  end

  describe '#foundational_agent_reference' do
    subject(:foundational_agent_reference) { item.foundational_agent_reference }

    let(:item_id) { 1 }
    let(:item) { build(:ai_catalog_item, :agent, id: item_id) }

    before do
      allow(item).to receive(:foundational_chat_agent?).and_return(is_foundational_chat_agent)
    end

    context 'when the item is not a foundational chat agent' do
      let(:is_foundational_chat_agent) { false }

      it { is_expected.to be_nil }
    end

    context 'when the item is a foundational chat agent' do
      let(:is_foundational_chat_agent) { true }

      before do
        agent_double = instance_double(::Ai::FoundationalChatAgent, reference: 'some_agent')
        allow(::Ai::FoundationalChatAgent).to receive(:find_by)
          .with(global_catalog_id: item_id).and_return(agent_double)
      end

      it 'returns the foundational chat agent reference' do
        expect(foundational_agent_reference).to eq('some_agent')
      end
    end
  end

  describe '#star' do
    let_it_be(:item, freeze: false) { create(:ai_catalog_item) }
    let_it_be(:user) { create(:user) }

    context 'when the user has not starred the item' do
      it 'creates a star and increments star_count' do
        expect { item.star(user) }
          .to change { item.stars.count }.by(1)
          .and change { item.reload.star_count }.by(1)
      end
    end

    context 'when the user has already starred the item' do
      before do
        item.star(user)
      end

      it 'is a no-op and returns the existing star' do
        existing_star = item.stars.find_by(user: user)

        expect(item.star(user)).to eq(existing_star)
        expect(item.stars.count).to eq(1)
      end
    end

    context 'when a race condition causes RecordNotUnique' do
      it 'returns the existing star without raising' do
        existing_star = create(:ai_catalog_item_star, item: item, user: user, organization: item.organization)
        allow(item.stars).to receive(:create!).and_raise(ActiveRecord::RecordNotUnique)
        allow(item.stars).to receive(:find_by).with(user: user).and_return(existing_star)

        result = item.star(user)

        expect(result).to eq(existing_star)
      end
    end
  end

  describe '#unstar' do
    let_it_be(:item, freeze: false) { create(:ai_catalog_item) }
    let_it_be(:user) { create(:user) }

    context 'when the user has starred the item' do
      before do
        item.star(user)
      end

      it 'destroys the star, decrements star_count, and returns true' do
        result = nil

        expect { result = item.unstar(user) }
          .to change { item.stars.count }.by(-1)
          .and change { item.reload.star_count }.by(-1)

        expect(result).to be(true)
      end
    end

    context 'when the user has not starred the item' do
      it 'is a no-op and returns false' do
        expect(item.unstar(user)).to be(false)
        expect(item.stars.count).to eq(0)
      end
    end
  end

  describe '#enabled_in_managed_by_project?' do
    subject(:enabled_in_managed_by_project?) { item.enabled_in_managed_by_project? }

    let_it_be(:project) { create(:project) }

    context 'when item has no managed-by project' do
      let(:item) { build_stubbed(:ai_catalog_item, :public, project: nil) }

      it { is_expected.to be(false) }
    end

    context 'when item has a managed-by project' do
      let(:item) { create(:ai_catalog_item, :public, project: project) }

      context 'when there is no enabled consumer in the managed-by project' do
        it { is_expected.to be(false) }
      end

      context 'when there is a disabled consumer in the managed-by project' do
        before do
          create(:ai_catalog_item_consumer, item: item, project: project, enabled: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when there is an enabled consumer in the managed-by project' do
        before do
          create(:ai_catalog_item_consumer, item: item, project: project, enabled: true)
        end

        it { is_expected.to be(true) }
      end

      context 'when there is an enabled consumer in a different project' do
        let_it_be(:other_project) { create(:project) }

        before do
          create(:ai_catalog_item_consumer, item: item, project: other_project, enabled: true)
        end

        it { is_expected.to be(false) }
      end
    end
  end
end
