# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::ProjectSecret, feature_category: :secrets_management do
  let_it_be_with_reload(:project) { create(:project) }

  subject(:secret) do
    described_class.new(
      name: 'TEST_SECRET',
      project: project,
      branch: 'main',
      environment: 'production',
      create_started_at: Time.now.iso8601.to_s,
      create_completed_at: Time.now.iso8601.to_s
    )
  end

  it_behaves_like 'a secret model'

  describe 'validations' do
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:branch) }
    it { is_expected.to validate_presence_of(:environment) }
  end

  describe 'attributes' do
    it 'has expected attributes specific to project secrets' do
      expect(secret).to have_attributes(
        branch: 'main',
        environment: 'production',
        project: project
      )
    end
  end

  describe 'dirty tracking' do
    it 'tracks changes to branch' do
      expect(secret.branch_changed?).to be_falsey

      secret.branch = 'feature'
      expect(secret.branch_changed?).to be_truthy
      expect(secret.branch_was).to eq('main')
    end
  end
end
