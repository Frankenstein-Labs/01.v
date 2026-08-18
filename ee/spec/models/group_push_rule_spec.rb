# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupPushRule, :saas, feature_category: :source_code_management do
  subject(:group_push_rule) { create(:group_push_rule) }

  let_it_be(:premium_license) { create(:license, plan: License::PREMIUM_PLAN) }

  it_behaves_like 'a push ruleable model'

  describe 'associations' do
    it { is_expected.to belong_to(:group).required }
  end

  describe 'validations' do
    it { is_expected.to be_valid }
  end

  describe '.build_from_predefined' do
    let(:group) { create(:group) }

    context 'when a predefined push rule exists' do
      let!(:global_push_rule) do
        create(:organization_push_rule,
          organization: group.organization,
          deny_delete_tag: true,
          member_check: true,
          prevent_secrets: true,
          commit_message_regex: 'Fixes \d+',
          max_file_size: 10
        )
      end

      it 'builds a new GroupPushRule with inherited attributes' do
        result = described_class.build_from_predefined(group)

        expect(result).to be_a(described_class)
        expect(result).to be_new_record
        expect(result.group).to eq(group)
        expect(result.deny_delete_tag).to be(true)
        expect(result.member_check).to be(true)
        expect(result.prevent_secrets).to be(true)
        expect(result.commit_message_regex).to eq('Fixes \d+')
        expect(result.max_file_size).to eq(10)
      end
    end

    context 'when no predefined push rule exists' do
      it 'builds a blank GroupPushRule' do
        result = described_class.build_from_predefined(group)

        expect(result).to be_a(described_class)
        expect(result).to be_new_record
        expect(result.group).to eq(group)
        expect(result.deny_delete_tag).to be_nil
        expect(result.member_check).to be(false)
        expect(result.prevent_secrets).to be(false)
      end
    end
  end

  describe '#commit_signature_allowed?' do
    subject(:commit_signatured_allowed?) { group_push_rule.commit_signature_allowed?(commit) }

    let(:group_push_rule) { create(:group_push_rule, reject_unsigned_commits: reject_unsigned_commits) }
    let(:signed_commit) { instance_double(Commit, has_signature?: true) }
    let(:unsigned_commit) { instance_double(Commit, has_signature?: false) }

    shared_examples 'allows all commits' do
      context 'with signed commit' do
        let(:commit) { signed_commit }

        it { is_expected.to be(true) }
      end

      context 'with unsigned commit' do
        let(:commit) { unsigned_commit }

        it { is_expected.to be(true) }
      end
    end

    shared_examples 'rejects unsigned commits' do
      context 'with signed commit' do
        let(:commit) { signed_commit }

        it { is_expected.to be(true) }
      end

      context 'with unsigned commit' do
        let(:commit) { unsigned_commit }

        it { is_expected.to be(false) }
      end
    end

    context 'when enabled at group level' do
      let(:reject_unsigned_commits) { true }

      context 'and feature is licensed' do
        it_behaves_like 'rejects unsigned commits'
      end

      context 'and feature is not licensed' do
        before do
          stub_licensed_features(reject_unsigned_commits: false)
        end

        it_behaves_like 'allows all commits'
      end
    end

    context 'when disabled at group level' do
      let(:reject_unsigned_commits) { false }

      it_behaves_like 'allows all commits'
    end
  end

  describe '#available?' do
    subject(:available?) { group_push_rule.available?(:reject_unsigned_commits) }

    shared_examples 'an available group push rule' do
      it { is_expected.to be(true) }
    end

    shared_examples 'an unavailable group push rule' do
      it { is_expected.to be(false) }
    end

    context 'with GL.com plans' do
      let(:plan) { :free }
      let(:group) { create(:group) }
      let!(:gitlab_subscription) { create(:gitlab_subscription, plan, namespace: group) }
      let(:group_push_rule) { create(:group_push_rule, group: group) }

      before do
        stub_application_setting(check_namespace_plan: true)
      end

      context 'with different payment plans verifications' do
        context 'with a Bronze plan' do
          let(:plan) { :bronze }

          it_behaves_like 'an unavailable group push rule'
        end

        context 'with a Premium plan' do
          let(:plan) { :premium }

          it_behaves_like 'an available group push rule'
        end

        context 'with a Ultimate plan' do
          let(:plan) { :ultimate }

          it_behaves_like 'an available group push rule'
        end
      end
    end
  end
end
