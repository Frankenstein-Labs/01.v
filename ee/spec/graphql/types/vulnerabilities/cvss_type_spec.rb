# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['CvssType'], feature_category: :vulnerability_management do
  let(:expected_fields) { %i[vector vendor version base_score overall_score severity] }

  subject { described_class }

  it { is_expected.to have_graphql_fields(expected_fields) }

  describe '#base_score' do
    it 'falls back to overall_score for CVSS v4.0 vectors' do
      object = { 'vector' => 'CVSS:4.0/AV:N/AC:L/AT:N/PR:N/UI:N/VC:H/VI:H/VA:H/SC:N/SI:N/SA:N' }
      type_instance = described_class.send(:new, object, {})

      expect(type_instance.base_score).to eq(type_instance.overall_score)
    end
  end
end
