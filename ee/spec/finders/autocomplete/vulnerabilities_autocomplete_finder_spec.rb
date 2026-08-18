# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Autocomplete::VulnerabilitiesAutocompleteFinder, feature_category: :vulnerability_management do
  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be_with_refind(:group) { create(:group) }
    let_it_be_with_refind(:project) { create(:project, group: group).tap(&:mark_as_vulnerable!) }
    let_it_be(:vulnerabilities) do
      max_plus_one = described_class::DEFAULT_AUTOCOMPLETE_LIMIT + 1
      create_list(:vulnerability, max_plus_one, :with_read, project: project, group: group) do |vulnerability, i|
        # The default title provided by FactoryBot is "My title {i}"
        # We test fuzzy-finding by title in these specs. The
        # fuzzy_find module has a `use_minimum_char_limit:`, which we
        # have set to `true`. In the default title template, only the
        # word "title" is longer than the minimum, so all of the
        # vulnerabilities end up matching. Including the {i} as part
        # of a token (e.g. "title#{i}"), rather than its own token
        # (e.g. title #{i}", allows us to properly test fuzzy finding
        vulnerability.title = "Some vulnerability title#{i}"
      end.each(&:save)
    end

    let(:params) { {} }
    let(:vulnerability) { vulnerabilities.first }

    subject { described_class.new(user, vulnerable, params).execute }

    shared_examples 'feature enabled autocomplete vulnerabilities finder' do
      before do
        vulnerable.add_developer(user)
      end

      let(:expected_results) { vulnerabilities.reverse.first(described_class::DEFAULT_AUTOCOMPLETE_LIMIT) }

      it { is_expected.to match_array(expected_results) }
      it { is_expected.to be_sorted(:id, :desc) }

      context 'when search is provided in params' do
        context 'and it matches ID of vulnerability' do
          let(:params) { { search: vulnerability.id.to_s } }

          it { is_expected.to match_array([vulnerability]) }
        end

        context 'and it matches title of vulnerability' do
          let(:params) { { search: vulnerability.title } }

          it { is_expected.to match_array([vulnerability]) }
        end

        context 'and it does not match neither title or id of vulnerability' do
          let(:params) { { search: non_existing_record_id.to_s } }

          it { is_expected.to be_empty }
        end
      end
    end

    shared_examples 'handles nil or unauthorized user' do
      context 'when user does not have access to project' do
        it { is_expected.to be_empty }
      end

      context 'when the given user is nil' do
        let(:user) { nil }

        it { is_expected.to be_empty }
      end
    end

    shared_examples 'feature disabled autocomplete vulnerabilities finder' do
      before do
        vulnerable.add_developer(user)
      end

      it { is_expected.to be_empty }
    end

    context 'when security dashboards are enabled' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'when vulnerable is project' do
        let(:vulnerable) { project }

        it_behaves_like 'handles nil or unauthorized user'
        it_behaves_like 'feature enabled autocomplete vulnerabilities finder'
      end

      context 'when vulnerable is group' do
        let(:vulnerable) { group }

        it_behaves_like 'handles nil or unauthorized user'
        it_behaves_like 'feature enabled autocomplete vulnerabilities finder'
      end
    end

    context 'when security dashboards are NOT enabled' do
      before do
        stub_licensed_features(security_dashboard: false)
      end

      context 'when vulnerable is project' do
        let(:vulnerable) { project }

        it_behaves_like 'handles nil or unauthorized user'
        it_behaves_like 'feature disabled autocomplete vulnerabilities finder'
      end

      context 'when vulnerable is group' do
        let(:vulnerable) { group }

        it_behaves_like 'handles nil or unauthorized user'
        it_behaves_like 'feature disabled autocomplete vulnerabilities finder'
      end
    end
  end
end
