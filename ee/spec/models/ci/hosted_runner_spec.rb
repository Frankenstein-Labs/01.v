# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::HostedRunner, feature_category: :hosted_runners do
  let_it_be(:runner) { create(:ci_runner) }

  describe 'associations' do
    it { is_expected.to belong_to(:runner).class_name('Ci::Runner') }
  end

  describe 'validations' do
    subject(:hosted_runner) { build(:ci_hosted_runner) }

    it { is_expected.to validate_presence_of(:runner) }
    it { is_expected.to validate_uniqueness_of(:runner_id) }

    describe 'runner type validation' do
      context 'when runner is instance type' do
        let(:runner) { create(:ci_runner, :instance) }

        it 'is valid' do
          hosted_runner.runner = runner
          expect(hosted_runner).to be_valid
        end
      end

      context 'when runner is not instance type' do
        let(:runner) { create(:ci_runner, :project, projects: [create(:project)]) }

        it 'is not valid' do
          hosted_runner.runner = runner
          expect(hosted_runner).not_to be_valid
          expect(hosted_runner.errors[:runner]).to include("is not an instance runner")
        end
      end
    end
  end
end
