# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::BaseUsageEventsFinder, feature_category: :value_stream_management do
  let_it_be(:group, freeze: false) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user, freeze: false) { create(:user, namespace: group) }
  let_it_be(:project_namespace) { project.project_namespace.reload }

  let(:from) { Time.zone.today - 20.days }
  let(:to) { Time.zone.today }
  let(:events) { nil }
  let(:users) { nil }

  let(:finder_params) do
    { from: from, to: to, namespace: group, events: events, users: users }
  end

  subject(:finder) { described_class.new(user, **finder_params) }

  describe '#execute' do
    it 'raises NotImplementedError' do
      expect { finder.execute }.to raise_error(NotImplementedError, 'Subclasses must implement #execute')
    end
  end
end
