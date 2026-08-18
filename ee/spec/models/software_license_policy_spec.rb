# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicy, feature_category: :software_composition_analysis do
  subject(:software_license_policy) { build(:software_license_policy) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:custom_software_license) }
    it { is_expected.to belong_to(:scan_result_policy_read) }
    it { is_expected.to belong_to(:approval_policy_rule) }
  end

  describe 'validations' do
    it { is_expected.to include_module(Presentable) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:classification) }
    it { is_expected.to validate_length_of(:software_license_spdx_identifier).is_at_most(255) }

    context 'when not associated with custom_software_license' do
      subject do
        build(:software_license_policy, custom_software_license: nil,
          software_license_spdx_identifier: software_license_spdx_identifier)
      end

      context 'without software_license_spdx_identifier' do
        let(:software_license_spdx_identifier) { nil }

        it { is_expected.not_to be_valid }
      end

      context 'with software_license_spdx_identifier' do
        let(:software_license_spdx_identifier) { 'MIT' }

        it { is_expected.to be_valid }
      end
    end

    context 'when associated with a custom_software_license' do
      let(:software_license_spdx_identifier) { nil }
      let_it_be(:project) { create(:project) }
      let_it_be(:custom_software_license) { create(:custom_software_license) }

      subject { build(:software_license_policy, project: project, custom_software_license: custom_software_license, software_license_spdx_identifier: software_license_spdx_identifier) }

      it { is_expected.to be_valid }

      context 'when uniqueness is enforced' do
        before do
          create(:software_license_policy, project: project, custom_software_license: custom_software_license,
            software_license_spdx_identifier: software_license_spdx_identifier)
        end

        context 'with same custom_license, project, and approval_policy' do
          let(:message) { 'Custom software license has already been taken' }

          it 'disallows on create' do
            another_software_license_policy = build(:software_license_policy, project: project, custom_software_license: custom_software_license, software_license_spdx_identifier: software_license_spdx_identifier)

            expect(another_software_license_policy).not_to be_valid
            expect(another_software_license_policy.errors.full_messages).to include(message)
          end
        end
      end

      context 'with software_license_spdx_identifier' do
        let(:software_license_spdx_identifier) { 'MIT' }

        it { is_expected.to be_valid }
      end
    end
  end

  shared_examples_for 'search license by name' do
    let(:mit_license_name) { 'MIT License' }
    let!(:mit_policy) { create(:software_license_policy, :with_mit_license) }

    let(:apache_license_name) { 'Apache License 2.0' }
    let!(:apache_policy) { create(:software_license_policy, :with_apache_license) }

    context 'with an exact match' do
      let(:name) { mit_license_name }

      it { is_expected.to match_array([mit_policy]) }
    end

    context 'with a case insensitive match' do
      let(:name) { 'mIt lICENSE' }

      it { is_expected.to match_array([mit_policy]) }
    end

    context 'with multiple names' do
      let(:name) { [mit_license_name, apache_license_name] }

      it { is_expected.to match_array([mit_policy, apache_policy]) }
    end
  end

  describe ".by_spdx" do
    let_it_be(:mit_license_spdx_identifier) { 'MIT' }
    let_it_be(:mit_policy) { create(:software_license_policy, :with_mit_license) }

    let_it_be(:apache_license_spdx_identifier) { 'Apache-2.0' }
    let_it_be(:apache_policy) { create(:software_license_policy, :with_apache_license) }

    it { expect(described_class.by_spdx(mit_license_spdx_identifier)).to match_array([mit_policy]) }
    it { expect(described_class.by_spdx([mit_license_spdx_identifier, apache_license_spdx_identifier])).to match_array([mit_policy, apache_policy]) }
    it { expect(described_class.by_spdx(SecureRandom.uuid)).to be_empty }
  end

  describe '.exclusion_allowed' do
    let_it_be(:scan_result_policy_read_with_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: true) }
    let_it_be(:scan_result_policy_read_without_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: false) }
    let!(:mit_policy) { create(:software_license_policy, :with_mit_license) }
    let!(:mit_policy_with_inclusion) { create(:software_license_policy, :with_mit_license, scan_result_policy_read: scan_result_policy_read_with_inclusion) }
    let!(:mit_policy_without_inclusion) { create(:software_license_policy, :with_mit_license, scan_result_policy_read: scan_result_policy_read_without_inclusion) }

    it { expect(described_class.exclusion_allowed).to eq([mit_policy_without_inclusion]) }
  end

  describe "#name" do
    context 'when associated with a custom_software_license' do
      subject(:software_license_policy) do
        build(:software_license_policy, project: project, custom_software_license: custom_software_license,
          software_license_spdx_identifier: nil)
      end

      let_it_be(:project) { create(:project) }
      let_it_be(:custom_software_license) { create(:custom_software_license) }

      specify { expect(software_license_policy.name).to eql(software_license_policy.custom_software_license.name) }
    end

    context 'when associated with a software_license' do
      let(:mit_license_name) { 'MIT License' }

      subject(:software_license_policy) { build(:software_license_policy, :with_mit_license) }

      specify { expect(software_license_policy.name).to eql(mit_license_name) }
    end
  end

  describe "#approval_status" do
    where(:classification, :approval_status) do
      [
        %w[allowed allowed],
        %w[denied denied]
      ]
    end

    with_them do
      subject { build(:software_license_policy, classification: classification) }

      it { expect(subject.approval_status).to eql(approval_status) }
    end
  end

  describe "#spdx_identifier" do
    let(:software_license_policy) { build(:software_license_policy, custom_software_license: custom_software_license, software_license_spdx_identifier: software_license_spdx_identifier) }

    subject { software_license_policy.spdx_identifier }

    context 'when associated with a custom_software_license' do
      let(:software_license_spdx_identifier) { nil }
      let_it_be(:custom_software_license) { create(:custom_software_license) }

      it { is_expected.to be_nil }
    end

    context 'with software_license_spdx_identifier' do
      let(:custom_software_license) { nil }
      let(:software_license_spdx_identifier) { 'MIT' }

      it { is_expected.to eq(software_license_spdx_identifier) }
    end
  end
end
