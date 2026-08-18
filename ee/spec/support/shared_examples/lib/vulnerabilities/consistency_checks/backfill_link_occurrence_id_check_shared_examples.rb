# frozen_string_literal: true

RSpec.shared_examples 'backfill link occurrence id check' do |log_message:|
  let_it_be(:project, freeze: false) { create(:project) }
  let_it_be(:vulnerability, freeze: false) { create(:vulnerability, project: project) }

  let(:finding_id) { vulnerability.finding_id }
  let(:check) { described_class.new(project) }

  describe '#consistent?' do
    context 'when VAC feature flag is enabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: project.root_namespace)
      end

      it 'returns true regardless of NULL values' do
        create_link(vulnerability_occurrence_id: nil)

        expect(check.consistent?).to be(true)
      end
    end

    context 'when VAC feature flag is disabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      context 'when no NULL vulnerability_occurrence_id values exist' do
        it 'returns true' do
          create_link(vulnerability_occurrence_id: finding_id)

          expect(check.consistent?).to be(true)
        end
      end

      context 'when NULL vulnerability_occurrence_id values exist' do
        it 'returns false' do
          create_link(vulnerability_occurrence_id: nil)

          expect(check.consistent?).to be(false)
        end
      end
    end
  end

  describe '#fix!' do
    subject(:fix!) { check.fix! }

    context 'when VAC feature flag is enabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: project.root_namespace)
      end

      it 'does not update any records' do
        link = create_link(vulnerability_occurrence_id: nil)

        expect { fix! }.not_to change { link.reload.vulnerability_occurrence_id }
      end
    end

    context 'when VAC feature flag is disabled' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      it 'backfills NULL vulnerability_occurrence_id from vulnerabilities.finding_id' do
        link = create_link(vulnerability_occurrence_id: nil)

        expect { fix! }.to change { link.reload.vulnerability_occurrence_id }.from(nil).to(finding_id)
      end

      it 'does not overwrite existing vulnerability_occurrence_id values' do
        other_finding = create(:vulnerabilities_finding, project: project)
        link = create_link(vulnerability_occurrence_id: other_finding.id)

        expect { fix! }.not_to change { link.reload.vulnerability_occurrence_id }
      end

      it 'only updates links for the given project' do
        other_project = create(:project)
        other_vulnerability = create(:vulnerability, project: other_project)
        other_link = create_link_for_other_project(other_vulnerability, other_project)

        fix!

        expect(other_link.reload.vulnerability_occurrence_id).to be_nil
      end

      it 'logs the count of backfilled records' do
        create_link(vulnerability_occurrence_id: nil)

        expect(check).to receive(:log).with(log_message, count: 1)

        fix!
      end

      it 'does not log when no records are updated' do
        expect(check).not_to receive(:log)

        fix!
      end
    end
  end

  describe '#execute' do
    before do
      stub_feature_flags(vulnerabilities_across_contexts: false)
    end

    context 'when check is consistent' do
      it 'does not call fix!' do
        create_link(vulnerability_occurrence_id: finding_id)

        expect(check).not_to receive(:fix!)

        check.execute
      end
    end

    context 'when check is inconsistent' do
      it 'calls fix!' do
        create_link(vulnerability_occurrence_id: nil)

        expect(check).to receive(:fix!).and_call_original

        check.execute
      end
    end
  end
end
