# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::MarkDroppedAsResolvedWorker, :elastic, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
  let_it_be(:dropped_identifiers) do
    create_list(:vulnerabilities_identifier, 2, external_type: 'find_sec_bugs_type', external_id: 'PREDICTABLE_RANDOM')
  end

  let_it_be(:dropped_identifier) { dropped_identifiers.first }
  let_it_be(:batch_size) { 1 }

  let_it_be(:dismissable_vulnerability) do
    finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id, primary_identifier_id: dropped_identifier.id, identifiers: [dropped_identifier]
    )

    create(:vulnerability, :detected, resolved_on_default_branch: true, project_id: pipeline.project_id).tap do |vuln|
      finding.update!(vulnerability_id: vuln.id)
    end
  end

  let_it_be(:dismissable_vulnerability_2) do
    finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id,
      primary_identifier_id: dropped_identifiers.last.id,
      identifiers: [dropped_identifiers.last]
    )

    create(:vulnerability, :detected, resolved_on_default_branch: true, project_id: pipeline.project_id).tap do |vuln|
      finding.update!(vulnerability_id: vuln.id)
    end
  end

  # `resolved_on_default_branch` is false which voids the
  # eligibility for resolving the vulnerability
  let_it_be(:non_dismissable_vulnerability) do
    finding = create(
      :vulnerabilities_finding,
      project_id: pipeline.project_id, primary_identifier_id: dropped_identifier.id, identifiers: [dropped_identifier]
    )

    create(:vulnerability, :detected, resolved_on_default_branch: false, project_id: pipeline.project_id).tap do |vuln|
      finding.update!(vulnerability_id: vuln.id)
    end
  end

  describe "#perform" do
    let(:worker) { described_class.new }

    before do
      stub_const("#{described_class}::BATCH_SIZE", batch_size)
      set_elasticsearch_migration_to :create_vulnerability_reads_index, including: true
    end

    include_examples 'an idempotent worker' do
      let(:subject) { worker.perform(pipeline.project_id, dropped_identifiers) }

      it 'changes state of dismissable vulnerabilities to resolved' do
        expect { subject }.to change { dismissable_vulnerability.reload.state }
          .from('detected')
          .to('resolved')
          .and change { dismissable_vulnerability.reload.resolved_by_id }
          .from(nil)
          .to(Users::Internal.in_organization(user.organization).security_bot.id)
      end

      it 'creates state transition entry with note for each vulnerability' do
        expect { subject }.to change { ::Vulnerabilities::StateTransition.count }
          .from(0)
          .to(2)
          .and change { Note.count }
          .by(2)

        [dismissable_vulnerability, dismissable_vulnerability_2].each do |vuln|
          transition = ::Vulnerabilities::StateTransition.where(vulnerability_id: vuln.id).last
          expect(transition.to_state).to eq("resolved")
          expect(transition.author_id).to eq(Users::Internal.in_organization(user.organization).security_bot.id)
          expect(transition.comment).to match(/automatically resolved/)
          expect(transition.vulnerability_occurrence_id).to eq(vuln.finding_id)
        end
      end

      it 'includes a link to documentation on SAST rules changes' do
        expect { subject }.to change { ::Vulnerabilities::StateTransition.count }
          .from(0)
          .to(2)
          .and change { Note.count }
          .by(2)

        [dismissable_vulnerability, dismissable_vulnerability_2].each do |vuln|
          transition = ::Vulnerabilities::StateTransition.where(vulnerability_id: vuln.id).last
          expect(transition.comment).to eq(
            "This vulnerability was automatically resolved because its vulnerability type was disabled " \
              "in this project or removed from GitLab's default ruleset. " \
              "For details about SAST rule changes, " \
              "see https://docs.gitlab.com/ee/user/application_security/sast/rules#important-rule-changes."
          )
        end
      end

      it 'retains same state of the non-dissmissable vulnerabilities' do
        expect(non_dismissable_vulnerability.reload.state).to eq("detected")
        expect(non_dismissable_vulnerability.reload.resolved_by_id).to eq(nil)
      end

      it_behaves_like 'sync vulnerabilities changes to ES' do
        let(:expected_vulnerabilities) do
          [dismissable_vulnerability, dismissable_vulnerability_2].map(&:vulnerability_read)
        end

        subject { worker.perform(pipeline.project_id, dropped_identifiers) }
      end
    end
  end
end
