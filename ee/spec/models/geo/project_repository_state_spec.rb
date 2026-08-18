# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Geo::ProjectRepositoryState, feature_category: :geo_replication do
  include EE::GeoHelpers
  include NonExistingRecordsHelpers

  let_it_be(:project, freeze: true) { create(:project_with_repo) }
  let_it_be(:project_repository, freeze: true) { project.project_repository }

  before do
    stub_current_geo_node(create(:geo_node, :primary))
  end

  describe 'associations' do
    it { is_expected.to belong_to(:project_repository).inverse_of(:project_repository_state) }
    it { is_expected.to belong_to(:project) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:verification_state) }
    it { is_expected.to validate_presence_of(:project_repository) }

    context 'with project_repository' do
      subject { described_class.new(project: project, project_repository: project_repository) }

      it { is_expected.to validate_uniqueness_of(:project_repository) }
    end
  end

  describe 'verification state behavior' do
    let(:state) { create(:geo_project_repository_state, project_repository: project_repository) }

    it 'inherits verification state methods from VerificationStateDefinition' do
      expect(state).to respond_to(:verification_pending!)
      expect(state).to respond_to(:verification_succeeded!)
      expect(state).to respond_to(:verification_failed!)
    end

    it 'can transition between verification states' do
      expect(state.verification_pending?).to be_truthy

      # Use the proper method with checksum for succeeded state
      state.update!(verification_checksum: 'abc123')
      state.verification_started!
      state.verification_succeeded!
      expect(state.verification_succeeded?).to be_truthy

      state.verification_started!
      state.before_verification_failed
      state.update!(verification_failure: "Verification failed")
      state.verification_failed!
      expect(state.verification_failed?).to be_truthy
    end

    it 'includes VerificationStateDefinition module' do
      expect(described_class.included_modules).to include(Geo::VerificationStateDefinition)
    end
  end
end
