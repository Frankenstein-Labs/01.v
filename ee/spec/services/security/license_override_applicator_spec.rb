# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::LicenseOverrideApplicator, feature_category: :security_policy_management do
  let_it_be(:project) { create(:project) }

  let(:overrides) do
    [
      { 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' },
      { 'purl' => 'pkg:gem/rails', 'license' => 'Apache-2.0', 'mode' => 'overwrite' }
    ]
  end

  subject(:applicator) { described_class.new_with_overrides(overrides) }

  describe '#overrides?' do
    it 'returns true when overrides exist' do
      expect(applicator.overrides?).to be true
    end

    context 'when no overrides exist' do
      let(:overrides) { [] }

      it 'returns false' do
        expect(applicator.overrides?).to be false
      end
    end
  end

  describe '#overrides? via project' do
    subject(:applicator) { described_class.new(project) }

    before do
      allow(applicator).to receive(:experiment_enabled_for_project?).and_return(true)
    end

    context 'when experiment is not enabled' do
      before do
        allow(applicator).to receive(:experiment_enabled_for_project?).and_return(false)
      end

      it 'returns false' do
        expect(applicator.overrides?).to be false
      end
    end

    context 'when no approval policy rules exist for the project' do
      it 'returns false' do
        expect(applicator.overrides?).to be false
      end
    end

    context 'when approval policy rules with license_overrides exist' do
      let(:policy) { create(:security_policy) }
      let!(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding_with_allowed_licenses,
          security_policy: policy,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: %w[newly_detected],
            licenses: { allowed: [{ name: 'MIT License' }] },
            license_overrides: [
              { 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT License', 'mode' => 'patch' }
            ]
          })
      end

      let!(:project_link) do
        create(:approval_policy_rule_project_link,
          approval_policy_rule: approval_policy_rule,
          project: project)
      end

      it 'returns true' do
        expect(applicator.overrides?).to be true
      end
    end

    context 'when approval policy rules without license_overrides exist' do
      let(:policy) { create(:security_policy) }
      let!(:approval_policy_rule) do
        create(:approval_policy_rule, :license_finding_with_allowed_licenses,
          security_policy: policy,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: %w[newly_detected],
            licenses: { allowed: [{ name: 'MIT License' }] }
          })
      end

      let!(:project_link) do
        create(:approval_policy_rule_project_link,
          approval_policy_rule: approval_policy_rule,
          project: project)
      end

      it 'returns false' do
        expect(applicator.overrides?).to be false
      end
    end
  end

  describe '#apply' do
    context 'when purl is nil' do
      it 'returns licenses unchanged' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        expect(applicator.apply(licenses, purl: nil)).to eq(licenses)
      end
    end

    context 'when no override matches' do
      it 'returns licenses unchanged' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        expect(applicator.apply(licenses, purl: 'pkg:npm/lodash@4.0.0')).to eq(licenses)
      end
    end

    context 'with patch mode and unknown license' do
      it 'replaces unknown with the override license using resolved SPDX identity' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')

        expect(result).to eq([
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end

    context 'with patch mode and known license' do
      it 'does not apply the override' do
        licenses = [{ 'spdx_identifier' => 'GPL-3.0', 'name' => 'GPL-3.0', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')

        expect(result).to eq(licenses)
      end
    end

    context 'with overwrite mode' do
      it 'replaces any license with the override using resolved SPDX identity' do
        licenses = [{ 'spdx_identifier' => 'GPL-3.0', 'name' => 'GPL-3.0', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:gem/rails@8.0.0')

        expect(result).to eq([
          { 'spdx_identifier' => 'Apache-2.0', 'name' => 'Apache License 2.0', 'url' => 'https://spdx.org/licenses/Apache-2.0.html' }
        ])
      end
    end

    context 'with mixed known and unknown licenses (dual-licensed)' do
      it 'replaces only the unknown license in patch mode' do
        licenses = [
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT', 'url' => nil },
          { 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }
        ]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')

        expect(result).to contain_exactly(
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT', 'url' => nil },
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        )
      end
    end

    context 'with blank spdx_identifier treated as unknown' do
      it 'replaces it in patch mode' do
        licenses = [{ 'spdx_identifier' => '', 'name' => 'some-lib', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@1.0')

        expect(result).to eq([
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end
  end

  describe '#apply — purl boundary matching' do
    context 'when override purl is a prefix of a different package name' do
      it 'does not match pkg:pypi/urllib3-extra against override for pkg:pypi/urllib3' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3-extra@1.0.0')

        expect(result).to eq(licenses)
      end
    end

    context 'when override purl matches with version separator (@)' do
      it 'matches pkg:pypi/urllib3@2.0.0 against override for pkg:pypi/urllib3' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')

        expect(result).to eq([
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end

    context 'when override purl matches exactly (no version)' do
      it 'matches exact purl' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3')

        expect(result).to eq([
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end

    context 'when dependency purl has qualifiers (? separator)' do
      it 'matches against override for pkg:pypi/urllib3' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3?vcs_url=git%2Bhttps://github.com/urllib3/urllib3')

        expect(result).to eq([
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end

    context 'when dependency purl has a subpath (# separator)' do
      it 'matches against override for pkg:pypi/urllib3' do
        licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3#src/urllib3')

        expect(result).to eq([
          { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end

    context 'when override purl has a version' do
      let(:overrides) do
        [{ 'purl' => 'pkg:pypi/urllib3@2.0.0', 'license' => 'MIT License', 'mode' => 'patch' }]
      end

      context 'when dependency version matches the override version' do
        it 'applies the override' do
          licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

          result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')

          expect(result).to eq([
            { 'spdx_identifier' => 'MIT', 'name' => 'MIT License', 'url' => 'https://spdx.org/licenses/MIT.html' }
          ])
        end
      end

      context 'when dependency version differs from the override version' do
        it 'does not apply the override' do
          licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

          result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@3.0.0')

          expect(result).to eq(licenses)
        end
      end

      context 'when dependency has no version' do
        it 'does not apply the override' do
          licenses = [{ 'spdx_identifier' => 'unknown', 'name' => 'unknown', 'url' => nil }]

          result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3')

          expect(result).to eq(licenses)
        end
      end
    end
  end

  describe '.new_for_group' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_project) { create(:project, group: group) }

    context 'when group is nil' do
      it 'returns NullApplicator' do
        result = described_class.new_for_group(nil)

        expect(result.overrides?).to be false
        expect(result.apply([{ 'name' => 'test' }], purl: 'pkg:pypi/foo')).to eq([{ 'name' => 'test' }])
      end
    end

    context 'when experiment is not enabled for the group' do
      before do
        allow(described_class).to receive(:experiment_enabled_for_group?).with(group).and_return(false)
      end

      it 'returns NullApplicator' do
        result = described_class.new_for_group(group)

        expect(result.overrides?).to be false
      end
    end

    context 'when group has projects with overrides' do
      let(:policy) { create(:security_policy) }
      let!(:rule) do
        create(:approval_policy_rule, :license_finding_with_allowed_licenses,
          security_policy: policy,
          content: {
            type: 'license_finding',
            branches: [],
            license_states: %w[newly_detected],
            licenses: { allowed: [{ name: 'MIT License' }] },
            license_overrides: [
              { 'purl' => 'pkg:pypi/urllib3', 'license' => 'MIT', 'mode' => 'patch' }
            ]
          })
      end

      let!(:project_link) do
        create(:approval_policy_rule_project_link,
          approval_policy_rule: rule,
          project: group_project)
      end

      before do
        allow(described_class).to receive(:experiment_enabled_for_group?).with(group).and_return(true)
      end

      it 'returns an applicator with overrides from the group projects' do
        result = described_class.new_for_group(group)

        expect(result.overrides?).to be true
      end
    end

    context 'when group has no projects with overrides' do
      before do
        allow(described_class).to receive(:experiment_enabled_for_group?).with(group).and_return(true)
      end

      it 'returns an applicator with no overrides' do
        result = described_class.new_for_group(group)

        expect(result.overrides?).to be false
      end
    end
  end

  describe '.new_with_overrides' do
    it 'creates an applicator that uses preloaded overrides' do
      result = described_class.new_with_overrides(overrides)

      expect(result.overrides?).to be true
    end

    it 'does not query the database' do
      result = described_class.new_with_overrides(overrides)

      expect { result.overrides? }.not_to exceed_query_limit(0)
    end

    context 'with empty overrides' do
      it 'returns an applicator with no overrides' do
        result = described_class.new_with_overrides([])

        expect(result.overrides?).to be false
      end
    end
  end

  describe 'NullApplicator' do
    subject(:null_applicator) { described_class::NULL_APPLICATOR }

    it 'returns false for overrides?' do
      expect(null_applicator.overrides?).to be false
    end

    it 'returns string-keyed input unchanged' do
      licenses = [{ 'spdx_identifier' => 'MIT', 'name' => 'MIT License' }]

      expect(null_applicator.apply(licenses, purl: 'pkg:pypi/foo@1.0')).to equal(licenses)
    end

    it 'returns symbol-keyed input unchanged' do
      licenses = [{ spdx_identifier: 'MIT', name: 'MIT License' }]

      expect(null_applicator.apply(licenses, purl: 'pkg:pypi/foo@1.0')).to equal(licenses)
    end
  end

  describe '#apply — with symbol keys (pipeline export format)' do
    context 'when purl is nil' do
      it 'returns licenses unchanged' do
        licenses = [{ spdx_identifier: 'unknown', name: 'unknown', url: nil }]

        expect(applicator.apply(licenses, purl: nil)).to eq(licenses)
      end
    end

    context 'when no override matches' do
      it 'returns licenses unchanged' do
        licenses = [{ spdx_identifier: 'unknown', name: 'unknown', url: nil }]

        expect(applicator.apply(licenses, purl: 'pkg:npm/lodash@4.0.0')).to eq(licenses)
      end
    end

    context 'with patch mode and unknown license' do
      it 'replaces unknown with override and returns symbol-keyed hash' do
        licenses = [{ spdx_identifier: 'unknown', name: 'unknown', url: nil }]

        result = applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')

        expect(result).to eq([
          { spdx_identifier: 'MIT', name: 'MIT License', url: 'https://spdx.org/licenses/MIT.html' }
        ])
      end
    end

    context 'with patch mode and known license' do
      it 'does not apply the override' do
        licenses = [{ spdx_identifier: 'GPL-3.0', name: 'GPL-3.0', url: nil }]

        expect(applicator.apply(licenses, purl: 'pkg:pypi/urllib3@2.0.0')).to eq(licenses)
      end
    end

    context 'with overwrite mode' do
      it 'replaces any license and returns symbol-keyed hash' do
        licenses = [{ spdx_identifier: 'BSD-3-Clause', name: 'BSD-3-Clause', url: nil }]

        result = applicator.apply(licenses, purl: 'pkg:gem/rails@8.0.0')

        expect(result).to eq([
          { spdx_identifier: 'Apache-2.0', name: 'Apache License 2.0', url: 'https://spdx.org/licenses/Apache-2.0.html' }
        ])
      end
    end

    context 'with nil licenses' do
      it 'handles nil gracefully' do
        expect(applicator.apply(nil, purl: 'pkg:pypi/urllib3@2.0.0')).to be_nil
      end
    end
  end
end
