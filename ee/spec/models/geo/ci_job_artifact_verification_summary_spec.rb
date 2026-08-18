# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::CiJobArtifactVerificationSummary, :geo, feature_category: :geo_replication do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:bucket_number) }

    it 'validates bucket_number is an integer between 0 and 99999' do
      is_expected.to validate_numericality_of(:bucket_number)
        .only_integer.is_greater_than_or_equal_to(0).is_less_than(100_000)
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:state).with_values(clean: 0, dirty: 1, calculating: 2) }
  end

  describe 'scopes' do
    let_it_be(:clean_summary, freeze: true) { create(:geo_ci_job_artifact_verification_summary, state: :clean) }
    let_it_be(:dirty_summary_old, freeze: true) do
      create(:geo_ci_job_artifact_verification_summary, :dirty, state_changed_at: 2.hours.ago)
    end

    let_it_be(:dirty_summary_new, freeze: true) do
      create(:geo_ci_job_artifact_verification_summary, :dirty, state_changed_at: 1.hour.ago)
    end

    let_it_be(:calculating_summary, freeze: true) { create(:geo_ci_job_artifact_verification_summary, :calculating) }

    describe '.dirty' do
      it 'returns only dirty summaries' do
        expect(described_class.dirty).to contain_exactly(dirty_summary_old, dirty_summary_new)
      end
    end

    describe '.calculating' do
      it 'returns only calculating summaries' do
        expect(described_class.calculating).to contain_exactly(calculating_summary)
      end
    end

    describe '.state_changed_asc' do
      it 'returns summaries ordered by state_changed_at ascending' do
        expect(described_class.dirty.state_changed_asc).to eq([dirty_summary_old, dirty_summary_new])
      end
    end
  end
end
