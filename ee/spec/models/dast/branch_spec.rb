# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dast::Branch, :dynamic_analysis,
  feature_category: :dynamic_application_security_testing do
  subject { described_class.new(dast_profile) }

  context 'when repository does not exist' do
    let_it_be_with_reload(:dast_profile) { create(:dast_profile) }

    describe '#name' do
      it 'returns nil' do
        expect(subject.name).to be_nil
      end
    end

    describe '#exists' do
      it 'returns false' do
        expect(subject.exists).to be(false)
      end
    end
  end

  context 'when repository exists' do
    let_it_be_with_reload(:dast_profile) { create(:dast_profile, branch_name: 'orphaned-branch', project: create(:project, :repository)) }

    describe '#name' do
      it 'returns profile.branch_name' do
        expect(subject.name).to eq(dast_profile.branch_name)
      end
    end

    context 'when branch exists' do
      it 'returns true' do
        expect(subject.exists).to be(true)
      end
    end

    context 'when branch does not exist' do
      before do
        dast_profile.branch_name = SecureRandom.hex
      end

      it 'returns false' do
        expect(subject.exists).to be(false)
      end
    end
  end
end
