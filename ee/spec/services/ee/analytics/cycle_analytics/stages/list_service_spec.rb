# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Analytics::CycleAnalytics::Stages::ListService, feature_category: :value_stream_management do
  let_it_be_with_refind(:group) { create(:group) }
  let_it_be_with_refind(:value_stream) { create(:cycle_analytics_value_stream, namespace: group) }
  let_it_be(:user) { create(:user, reporter_of: group) }

  let(:stages) { subject.payload[:stages] }

  subject { described_class.new(parent: group, current_user: user, params: { value_stream: value_stream }).execute }

  before do
    stub_licensed_features(cycle_analytics_for_groups: true)
  end

  describe 'permission check' do
    context 'when user has no access' do
      before do
        group.add_member(user, :guest)
      end

      it { expect(subject).to be_error }
      it { expect(subject.http_status).to eq(:forbidden) }
    end

    context 'when license is missing' do
      before do
        stub_licensed_features(cycle_analytics_for_groups: false)
      end

      it { expect(subject).to be_error }
      it { expect(subject.http_status).to eq(:forbidden) }
    end
  end

  it 'returns empty array' do
    expect(stages.size).to eq(0)
  end

  it 'provides the default stages as non-persisted objects' do
    expect(stages.map(&:id)).to all(be_nil)
  end

  it 'does not persist the value stream record' do
    expect { subject }.not_to change { Analytics::CycleAnalytics::ValueStream.count }
  end

  context 'when there are persisted stages' do
    let_it_be(:stage1) { create(:cycle_analytics_stage, namespace: group, relative_position: 2, value_stream: value_stream) }
    let_it_be(:stage2) { create(:cycle_analytics_stage, namespace: group, relative_position: 3, value_stream: value_stream) }
    let_it_be(:stage3) { create(:cycle_analytics_stage, namespace: group, relative_position: 1, value_stream: value_stream) }

    it 'returns the persisted stages in order' do
      expect(stages).to eq([stage3, stage1, stage2])
    end
  end

  context 'when value_stream_ids parameter is present' do
    let_it_be_with_refind(:value_stream_2) { create(:cycle_analytics_value_stream, namespace: group) }
    let_it_be(:stage1) { create(:cycle_analytics_stage, namespace: group, relative_position: 1, value_stream: value_stream) }
    let_it_be(:stage2) { create(:cycle_analytics_stage, namespace: group, relative_position: 1, value_stream: value_stream_2) }

    subject { described_class.new(parent: group, current_user: user, params: { value_stream_ids: [value_stream.id, value_stream_2.id] }).execute }

    it 'returns stages filtered by value streams' do
      expect(stages).to match_array([stage1, stage2])
    end

    context 'when filtering stage ids' do
      let(:stage_ids) { [stage1.id] }

      subject { described_class.new(parent: group, current_user: user, params: { value_stream_ids: [value_stream.id], stage_ids: [stage1.id] }).execute.payload[:stages] }

      it { is_expected.to eq([stage1]) }

      context 'when stage id does not belong to the value stream' do
        let(:stage_ids) { [stage1.id, stage2.id] }

        it { is_expected.to eq([stage1]) }
      end
    end
  end
end
