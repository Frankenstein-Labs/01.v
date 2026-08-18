# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::MergeRequestLink, feature_category: :vulnerability_management do
  describe 'associations and fields' do
    it { is_expected.to belong_to(:vulnerability) }

    it 'belongs to finding' do
      is_expected.to belong_to(:finding)
        .with_foreign_key(:vulnerability_occurrence_id)
        .class_name('Vulnerabilities::Finding')
    end

    it { is_expected.to belong_to(:merge_request) }
    it { is_expected.to have_one(:author).through(:merge_request).class_name("User") }
  end

  describe 'created_by_ai_workflow' do
    it 'defaults to false' do
      expect(described_class.new.created_by_ai_workflow).to be(false)
    end
  end

  describe '#merge_request_merged?' do
    it 'returns true when the merge request has merged' do
      link = build(:vulnerabilities_merge_request_link, merge_request: build(:merge_request, :merged))

      expect(link.merge_request_merged?).to be(true)
    end

    it 'returns false when the merge request has not merged' do
      link = build(:vulnerabilities_merge_request_link, merge_request: build(:merge_request))

      expect(link.merge_request_merged?).to be(false)
    end

    it 'returns false when the merge request is missing' do
      link = build(:vulnerabilities_merge_request_link, merge_request: nil)

      expect(link.merge_request_merged?).to be(false)
    end
  end

  describe 'validations' do
    let_it_be(:vulnerability) { create(:vulnerability) }
    let_it_be(:merge_request) { create(:merge_request) }

    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:merge_request) }

    describe 'readiness_score validations' do
      subject(:build_link) do
        build(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      context 'when readiness_score is nil' do
        it 'is valid' do
          build_link.readiness_score = nil

          expect(build_link).to be_valid
        end
      end

      context 'when readiness_score is within valid range' do
        it 'is valid for 0.0' do
          build_link.readiness_score = 0.0

          expect(build_link).to be_valid
        end

        it 'is valid for 1.0' do
          build_link.readiness_score = 1.0

          expect(build_link).to be_valid
        end

        it 'is valid for 0.5' do
          build_link.readiness_score = 0.5

          expect(build_link).to be_valid
        end
      end

      context 'when readiness_score is outside valid range' do
        it 'is invalid for negative values' do
          build_link.readiness_score = -0.1

          expect(build_link).not_to be_valid
          expect(build_link.errors[:readiness_score]).to include('is not included in the list')
        end

        it 'is invalid for values greater than 1.0' do
          build_link.readiness_score = 1.1

          expect(build_link).not_to be_valid
          expect(build_link.errors[:readiness_score]).to include('is not included in the list')
        end
      end

      context 'when readiness_score is not a number' do
        it 'is invalid for string values' do
          build_link.readiness_score = 'invalid'

          expect(build_link).not_to be_valid
          expect(build_link.errors[:readiness_score]).to include('is not a number')
        end
      end
    end
  end

  describe 'class methods' do
    let_it_be(:vulnerability) { create(:vulnerability) }
    let_it_be(:other_vulnerability) { create(:vulnerability) }

    describe '.merged_vulnerability_ids' do
      let_it_be(:read) { create(:vulnerability_read) }
      let(:candidate_vulnerability_ids) do
        Vulnerabilities::Read.where(vulnerability_id: read.vulnerability_id).select(:vulnerability_id)
      end

      subject(:merged_ids) { described_class.merged_vulnerability_ids(candidate_vulnerability_ids) }

      def create_link(merge_request:, created_by_ai_workflow: true, vulnerability: read.vulnerability)
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability,
          merge_request: merge_request, created_by_ai_workflow: created_by_ai_workflow)
      end

      context 'when a candidate vulnerability has a merged AI-created merge request' do
        before do
          create_link(merge_request: create(:merge_request, :merged))
        end

        it { is_expected.to contain_exactly(read.vulnerability_id) }
      end

      context 'when the AI-created merge request has not merged' do
        before do
          create_link(merge_request: create(:merge_request))
        end

        it { is_expected.to be_empty }
      end

      context 'when the merged merge request was not created by the AI workflow' do
        before do
          create_link(merge_request: create(:merge_request, :merged), created_by_ai_workflow: false)
        end

        it { is_expected.to be_empty }
      end

      context 'when a vulnerability has several AI-created merge requests and one has merged' do
        before do
          create_link(merge_request: create(:merge_request))
          create_link(merge_request: create(:merge_request, :merged))
        end

        it 'returns the vulnerability once' do
          is_expected.to contain_exactly(read.vulnerability_id)
        end
      end

      context 'when a vulnerability has multiple occurrences each with a merged AI-created merge request' do
        before do
          first_occurrence = create(:vulnerabilities_finding, vulnerability: read.vulnerability)
          second_occurrence = create(:vulnerabilities_finding, vulnerability: read.vulnerability)

          create(:vulnerabilities_merge_request_link, vulnerability: read.vulnerability, finding: first_occurrence,
            merge_request: create(:merge_request, :merged), created_by_ai_workflow: true)
          create(:vulnerabilities_merge_request_link, vulnerability: read.vulnerability, finding: second_occurrence,
            merge_request: create(:merge_request, :merged), created_by_ai_workflow: true)
        end

        it 'counts the vulnerability once, not once per occurrence' do
          is_expected.to contain_exactly(read.vulnerability_id)
        end
      end

      context 'when several candidate vulnerabilities each have a merged AI-created merge request' do
        let_it_be(:other_read) { create(:vulnerability_read) }
        let(:candidate_vulnerability_ids) do
          Vulnerabilities::Read
            .where(vulnerability_id: [read.vulnerability_id, other_read.vulnerability_id])
            .select(:vulnerability_id)
        end

        before do
          create_link(merge_request: create(:merge_request, :merged))
          create_link(merge_request: create(:merge_request, :merged), vulnerability: other_read.vulnerability)
        end

        it 'returns each distinct vulnerability id' do
          is_expected.to contain_exactly(read.vulnerability_id, other_read.vulnerability_id)
        end
      end

      context 'when the merged AI-created merge request is for a vulnerability outside the candidate set' do
        before do
          create_link(merge_request: create(:merge_request, :merged), vulnerability: create(:vulnerability))
        end

        it { is_expected.to be_empty }
      end

      context 'when there are no candidate vulnerability ids' do
        let(:candidate_vulnerability_ids) { Vulnerabilities::Read.none.select(:vulnerability_id) }

        before do
          create_link(merge_request: create(:merge_request, :merged))
        end

        it { is_expected.to be_empty }
      end
    end

    describe '.count_for_vulnerability' do
      before do
        create_list(:vulnerabilities_merge_request_link, 3, vulnerability: vulnerability)
        create_list(:vulnerabilities_merge_request_link, 2, vulnerability: other_vulnerability)
      end

      it 'returns the correct count for the specified vulnerability' do
        expect(described_class.count_for_vulnerability(vulnerability)).to eq(3)
        expect(described_class.count_for_vulnerability(other_vulnerability)).to eq(2)
      end

      it 'returns 0 for a vulnerability with no links' do
        new_vulnerability = create(:vulnerability)
        expect(described_class.count_for_vulnerability(new_vulnerability)).to eq(0)
      end
    end

    describe '.limit_exceeded_for_vulnerability?' do
      context 'when under the limit' do
        before do
          allow(described_class).to receive(:count_for_vulnerability)
            .with(vulnerability)
            .and_return(50)
        end

        it 'returns false' do
          expect(described_class.limit_exceeded_for_vulnerability?(vulnerability)).to be false
        end
      end

      context 'when at the limit' do
        before do
          stub_const('Vulnerabilities::MergeRequestLink::MAX_MERGE_REQUEST_LINKS_PER_VULNERABILITY', 1)
          create(:vulnerabilities_merge_request_link, vulnerability: vulnerability)
        end

        it 'returns true' do
          expect(described_class.limit_exceeded_for_vulnerability?(vulnerability)).to be true
        end
      end

      it 'returns false for a vulnerability with no links' do
        new_vulnerability = create(:vulnerability)
        expect(described_class.limit_exceeded_for_vulnerability?(new_vulnerability)).to be false
      end
    end

    describe '.find_by_vulnerability_and_merge_request' do
      let_it_be(:merge_request) { create(:merge_request) }
      let_it_be(:other_merge_request) { create(:merge_request) }
      let_it_be(:merge_request_link) do
        create(:vulnerabilities_merge_request_link, vulnerability: vulnerability, merge_request: merge_request)
      end

      it 'returns the link when both vulnerability and merge request match' do
        result = described_class.find_by_vulnerability_and_merge_request(vulnerability, merge_request)

        expect(result).to eq(merge_request_link)
        expect(result.vulnerability).to eq(vulnerability)
        expect(result.merge_request).to eq(merge_request)
      end

      it 'returns nil when vulnerability does not match' do
        result = described_class.find_by_vulnerability_and_merge_request(other_vulnerability, merge_request)

        expect(result).to be_nil
      end

      it 'returns nil when merge request does not match' do
        result = described_class.find_by_vulnerability_and_merge_request(vulnerability, other_merge_request)

        expect(result).to be_nil
      end

      it 'returns nil when both vulnerability and merge request do not match' do
        result = described_class.find_by_vulnerability_and_merge_request(other_vulnerability, other_merge_request)

        expect(result).to be_nil
      end

      it 'returns nil when no links exist' do
        new_vulnerability = create(:vulnerability)
        new_merge_request = create(:merge_request)

        result = described_class.find_by_vulnerability_and_merge_request(new_vulnerability, new_merge_request)

        expect(result).to be_nil
      end
    end
  end

  context 'with loose foreign key on vulnerability_merge_request_links.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerabilities_merge_request_link, project_id: parent.id) }
    end
  end

  context 'with loose foreign key on vulnerability_merge_request_links.merge_request_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:merge_request) }
      let_it_be(:model) { create(:vulnerabilities_merge_request_link, merge_request: parent) }
    end
  end
end
