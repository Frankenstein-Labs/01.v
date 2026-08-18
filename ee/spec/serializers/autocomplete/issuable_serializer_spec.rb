# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Autocomplete::IssuableSerializer, feature_category: :groups_and_projects do
  let_it_be(:user) { build(:user) }
  let_it_be(:group) { build(:group) }
  let_it_be(:project) { build(:project, group: group) }
  let_it_be(:issue) { build(:issue, project: project, title: 'Test Issue') }
  let_it_be(:epic) { build(:epic, group: group, title: 'Test Epic') }

  let(:serializer) { described_class.new }

  describe '#represent' do
    it 'serializes an epic correctly' do
      result = serializer.represent(epic)

      expect(result.as_json).to include(
        'iid' => epic.iid,
        'title' => epic.title,
        'reference' => epic.to_reference
      )
    end

    it 'uses parent context for references when provided' do
      result = serializer.represent(epic, parent: group.id)

      expect(result.as_json['reference']).to eq(epic.to_reference(group.id))
    end

    it 'serializes multiple issuables correctly' do
      results = serializer.represent([issue, epic])

      expect(results).to be_an(Array)
      expect(results.size).to eq(2)

      # Access the values through as_json
      expect(results.first.as_json['iid']).to eq(issue.iid)
      expect(results.second.as_json['iid']).to eq(epic.iid)
    end
  end
end
