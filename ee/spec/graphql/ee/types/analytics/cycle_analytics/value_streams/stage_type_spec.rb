# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::Analytics::CycleAnalytics::ValueStreams::StageType, feature_category: :value_stream_management do
  let(:fields) do
    %i[start_event_label end_event_label]
  end

  specify { expect(described_class).to have_graphql_fields(fields).at_least }
end
