# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OrganizationPushRule, feature_category: :source_code_management do
  subject(:organization_push_rule) { create(:organization_push_rule) }

  it_behaves_like 'a push ruleable model'

  describe 'associations' do
    it { is_expected.to belong_to(:organization).required }
  end

  describe 'validations' do
    subject { build(:organization_push_rule) }

    it { is_expected.to be_valid }
  end

  describe '#commit_signature_allowed?' do
    let!(:premium_license) { create(:license, plan: License::PREMIUM_PLAN) }
    let(:signed_commit) { instance_double(Commit, has_signature?: true) }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false) }

    context 'when feature is not licensed and it is enabled' do
      before do
        stub_licensed_features(reject_unsigned_commits: false)
        organization_push_rule.update_attribute(:reject_unsigned_commits, true)
      end

      it 'accepts unsigned commits' do
        expect(organization_push_rule.commit_signature_allowed?(unsigned_commit)).to be(true)
      end
    end

    context 'when enabled at an organization level' do
      before do
        organization_push_rule.update_attribute(:reject_unsigned_commits, true)
      end

      it 'returns false if commit is not signed' do
        expect(organization_push_rule.commit_signature_allowed?(unsigned_commit)).to be(false)
      end

      it 'returns true if commit is signed' do
        expect(organization_push_rule.commit_signature_allowed?(signed_commit)).to be(true)
      end
    end

    context 'when disabled at an organization level' do
      before do
        organization_push_rule.update_attribute(:reject_unsigned_commits, false)
      end

      it 'returns true if commit is not signed' do
        expect(organization_push_rule.commit_signature_allowed?(unsigned_commit)).to be(true)
      end
    end
  end

  describe '#available?' do
    context 'with an organization push rule' do
      context 'with a EE starter license' do
        let!(:license) { create(:license, plan: License::STARTER_PLAN) }

        it 'is not available' do
          expect(organization_push_rule.available?(:reject_unsigned_commits)).to be(false)
        end
      end

      context 'with a EE premium license' do
        let!(:license) { create(:license, plan: License::PREMIUM_PLAN) }

        it 'is available' do
          expect(organization_push_rule.available?(:reject_unsigned_commits)).to be(true)
        end
      end
    end
  end
end
