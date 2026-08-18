# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::Integrations::GitGuardianProjectUrlHeader, feature_category: :source_code_management do
  let_it_be(:project) { build(:project, namespace: build(:namespace, name: 'foo'), path: 'bar') }
  let(:expected_project_url) { 'localhost/foo/bar' }

  describe '.build' do
    it 'returns the correct URL format' do
      url = described_class.build(project)

      expect(url).to eq(expected_project_url)
    end
  end
end
