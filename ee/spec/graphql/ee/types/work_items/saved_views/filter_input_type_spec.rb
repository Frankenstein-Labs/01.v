# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Types::WorkItems::SavedViews::FilterInputType, feature_category: :planning_views do
  describe 'prepare lambdas' do
    it 'prepares iteration_cadence_id by extracting model_ids from GlobalIDs' do
      cadences = create_list(:iterations_cadence, 3)
      global_ids = cadences.map(&:to_gid)

      argument = described_class.arguments['iterationCadenceId']

      prepared_value = argument.prepare.call(global_ids, nil)

      expect(prepared_value).to match_array(cadences.map { |c| c.id.to_s })
    end

    it 'returns nil when iteration_cadence_id is empty array' do
      argument = described_class.arguments['iterationCadenceId']

      prepared_value = argument.prepare.call([], nil)

      expect(prepared_value).to be_nil
    end

    it 'returns nil when iteration_cadence_id is nil' do
      argument = described_class.arguments['iterationCadenceId']

      prepared_value = argument.prepare.call(nil, nil)

      expect(prepared_value).to be_nil
    end
  end
end
