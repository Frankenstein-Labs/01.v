# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AuditEvents::Streaming::Group::Streamer, feature_category: :audit_events do
  context 'when group is not present' do
    let_it_be(:audit_event) { create(:audit_event) }
    let(:event_type) { 'event_type' }
    let(:streamer) { described_class.new(event_type, audit_event) }

    describe '#streamable?' do
      subject(:check_streamable) { streamer.streamable? }

      it { is_expected.to be_falsey }
    end

    describe '#destinations' do
      subject(:get_streamer_destinations) { streamer.destinations }

      it { is_expected.to be_empty }
    end
  end

  it_behaves_like 'streamer streaming audit events', :group
end
