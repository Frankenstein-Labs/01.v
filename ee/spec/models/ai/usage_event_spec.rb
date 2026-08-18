# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::UsageEvent, feature_category: :value_stream_management do
  subject(:event) { described_class.new(attributes) }

  let(:attributes) { { event: 'troubleshoot_job' } }
  let_it_be_with_reload(:namespace) { create(:namespace) }
  let_it_be_with_reload(:user) { create(:user, namespace: namespace) }

  it { is_expected.to belong_to(:user) }

  describe 'validations' do
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:timestamp) }

    it 'validates presence of organization_id' do
      stub_const('Organizations::Organization::DEFAULT_ORGANIZATION_ID', nil)

      is_expected.to validate_presence_of(:organization_id)
    end

    it 'allows 3 month old data at the most' do
      is_expected.not_to allow_value(5.months.ago).for(:timestamp).with_message(_('must be 3 months old at the most'))
    end

    it 'does not allow new deprecated events' do
      is_expected.not_to allow_value('code_suggestions_requested').for(:event).with_message(_('is read-only'))
    end

    it 'does not allow invalid namespace_id' do
      model = described_class.new(namespace_id: non_existing_record_id)
      model.valid?

      expect(model.errors[:namespace]).to include("can't be blank")
    end
  end

  describe '.sort_by_timestamp_id' do
    let_it_be(:old_event) do
      create(:ai_usage_event, user: user, namespace: namespace, timestamp: 2.days.ago)
    end

    let_it_be(:new_event) { create(:ai_usage_event, user: user, namespace: namespace, timestamp: 1.day.ago) }

    it 'returns the usage events in default desc order' do
      result = described_class.sort_by_timestamp_id.to_a

      expect(result).to eq([new_event, old_event])
    end

    it 'the order can be changed' do
      result = described_class.sort_by_timestamp_id(dir: :asc).to_a

      expect(result).to eq([old_event, new_event])
    end
  end

  describe '.in_timeframe' do
    let_it_be(:old_event) do
      create(:ai_usage_event, user: user, namespace: namespace, timestamp: 20.days.ago)
    end

    let_it_be(:event) { create(:ai_usage_event, user: user, namespace: namespace, timestamp: 10.days.ago) }
    let_it_be(:lower_bound_event) { create(:ai_usage_event, user: user, namespace: namespace, timestamp: 15.days.ago) }
    let_it_be(:upper_bound_event) { create(:ai_usage_event, user: user, namespace: namespace, timestamp: 5.days.ago) }
    let_it_be(:too_new_event) { create(:ai_usage_event, user: user, namespace: namespace, timestamp: 1.day.ago) }

    it 'returns events matching provided time range' do
      expect(described_class.in_timeframe(lower_bound_event.timestamp..upper_bound_event.timestamp).to_a)
        .to match_array([lower_bound_event, event, upper_bound_event])
    end
  end

  describe '.with_events' do
    let_it_be(:shown_event) { create(:ai_usage_event, event: 'code_suggestion_shown_in_ide') }
    let_it_be(:accepted_event) { create(:ai_usage_event, event: 'code_suggestion_accepted_in_ide') }
    let_it_be(:rejected_event) { create(:ai_usage_event, event: 'code_suggestion_rejected_in_ide') }

    it 'returns events matching provided event names' do
      expect(described_class.with_events(%w[code_suggestion_shown_in_ide code_suggestion_accepted_in_ide]).to_a)
        .to match_array([shown_event, accepted_event])
    end
  end

  describe '.with_users' do
    let_it_be(:event1) { create(:ai_usage_event, user: user) }
    let_it_be(:event2) { create(:ai_usage_event, user: user) }
    let_it_be(:event3) { create(:ai_usage_event) }

    it 'returns events matching provided users' do
      expect(described_class.with_users(user)).to match_array([event1, event2])
    end
  end

  describe '.for_namespace_hierarchy' do
    let_it_be(:group) { create(:group) }
    let_it_be(:subgroup) { create(:group, parent: group) }
    let_it_be(:project) { create(:project, namespace: subgroup) }

    let_it_be(:group_event) { create(:ai_usage_event, user: user, namespace: group) }
    let_it_be(:subgroup_event) { create(:ai_usage_event, user: user, namespace: subgroup) }
    let_it_be(:project_event) { create(:ai_usage_event, user: user, namespace: project.project_namespace) }
    let_it_be(:unrelated_event) { create(:ai_usage_event, user: user) }

    it 'returns all events matched to namespace subtree ordered by timestamp desc' do
      expect(described_class.for_namespace_hierarchy(group)).to match([project_event, subgroup_event,
        group_event])
      expect(described_class.for_namespace_hierarchy(subgroup)).to match([project_event, subgroup_event])
      expect(described_class.for_namespace_hierarchy(project.project_namespace)).to match([project_event])
    end

    it 'respects ordering if set' do
      expect(described_class.order(timestamp: :asc, id: :asc).for_namespace_hierarchy(group))
        .to match([group_event, subgroup_event, project_event])
    end
  end

  describe '#organization_id' do
    subject(:event) { described_class.new(user: user) }

    it { is_expected.to populate_sharding_key(:organization_id).with(namespace.organization.id) }
  end

  describe '#timestamp', :freeze_time do
    it 'defaults to current time' do
      expect(event.timestamp).to eq(DateTime.current)
    end

    it 'properly converts from string' do
      expect(described_class.new(timestamp: DateTime.current.to_s).timestamp).to eq(DateTime.current)
    end
  end

  describe '#before_validation' do
    it 'floors timestamp to 3 digits' do
      event = described_class.new(timestamp: '2021-01-01 01:02:03.123456789'.to_datetime)
      expect do
        event.validate
      end.to change { event.timestamp }.to('2021-01-01 01:02:03.123'.to_datetime)
    end
  end

  describe '#store_to_pg', :freeze_time do
    context 'when the model is invalid' do
      it 'does not add anything to write buffer' do
        expect(described_class.write_buffer).not_to receive(:add)

        event.store_to_pg
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(namespace: namespace, user: user, timestamp: 1.day.ago)
      end

      it 'adds model attributes to write buffer' do
        expect(described_class.write_buffer).to receive(:add)
                                               .with({
                                                 event: described_class.events['troubleshoot_job'],
                                                 timestamp: 1.day.ago,
                                                 user_id: user.id,
                                                 organization_id: user.organization.id,
                                                 namespace_id: namespace.id,
                                                 extras: {}
                                               }.with_indifferent_access)

        event.store_to_pg
      end
    end
  end

  describe '#store_to_clickhouse', :freeze_time do
    context 'when the model is invalid' do
      it 'does not add anything to write buffer' do
        expect(ClickHouse::WriteBuffer).not_to receive(:add)

        event.store_to_clickhouse
      end
    end

    context 'when the model is valid' do
      let(:attributes) do
        super().merge(user: user, namespace: namespace, timestamp: 1.day.ago, extras: { foo: 'bar' })
      end

      it 'adds model attributes to write buffer' do
        expect(ClickHouse::WriteBuffer).to receive(:add)
                                             .with('ai_usage_events', {
                                               event: described_class.events['troubleshoot_job'],
                                               timestamp: 1.day.ago.to_f,
                                               user_id: user.id,
                                               namespace_path: namespace.traversal_path(with_organization: false),
                                               extras: { foo: 'bar' }.to_json
                                             })

        event.store_to_clickhouse
      end
    end
  end
end
