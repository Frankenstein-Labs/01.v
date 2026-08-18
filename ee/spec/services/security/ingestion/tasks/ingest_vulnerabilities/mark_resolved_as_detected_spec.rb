# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::Ingestion::Tasks::IngestVulnerabilities::MarkResolvedAsDetected, :elastic, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:pipeline) { create(:ci_pipeline, user: user) }
  let_it_be(:identifier) { create(:vulnerabilities_identifier) }

  let_it_be(:existing_vulnerability) do
    create(:vulnerability,
      :detected,
      :with_finding,
      resolved_on_default_branch: true,
      present_on_default_branch: false,
      project: pipeline.project
    )
  end

  let_it_be(:resolved_vulnerability) do
    create(:vulnerability,
      :resolved,
      :with_finding,
      :with_read,
      resolved_on_default_branch: true,
      present_on_default_branch: false,
      resolved_by_id: user.id,
      dismissed_at: 1.day.ago,
      dismissed_by_id: user.id,
      confirmed_at: 2.days.ago,
      confirmed_by_id: user.id,
      auto_resolved: true,
      project: pipeline.project
    )
  end

  let(:existing_detected_finding_map) { create(:finding_map, pipeline: pipeline) }
  let(:existing_resolved_finding_map) { create(:finding_map, pipeline: pipeline) }
  let(:new_finding_map) { create(:finding_map, pipeline: pipeline) }

  let(:finding_maps) { [existing_detected_finding_map, existing_resolved_finding_map, new_finding_map] }

  subject(:mark_resolved_as_detected) { described_class.new(pipeline, finding_maps).execute }

  before do
    existing_detected_finding_map.vulnerability_id = existing_vulnerability.id
    existing_resolved_finding_map.vulnerability_id = resolved_vulnerability.id
    existing_resolved_finding_map.finding_id = resolved_vulnerability.finding_id
  end

  it_behaves_like 'sync vulnerabilities changes to ES' do
    let(:expected_vulnerabilities) { resolved_vulnerability.vulnerability_read }
  end

  it 'changes state of resolved Vulnerabilities back to detected' do
    expect { mark_resolved_as_detected }.to change { resolved_vulnerability.reload.state }
      .from("resolved")
      .to("detected")
      .and not_change { existing_vulnerability.reload.state }
      .from("detected")
  end

  it 'resets all stale state attributes' do
    mark_resolved_as_detected

    expect(resolved_vulnerability.reload).to have_attributes(
      resolved_at: nil,
      resolved_by_id: nil,
      dismissed_at: nil,
      dismissed_by_id: nil,
      confirmed_at: nil,
      confirmed_by_id: nil,
      auto_resolved: false
    )
  end

  it 'touches the updated_at timestamp', :freeze_time do
    expect { mark_resolved_as_detected }.to change { resolved_vulnerability.reload.updated_at }.to(Time.current)
  end

  it 'creates state transition entry for each vulnerability' do
    expect { mark_resolved_as_detected }.to change { ::Vulnerabilities::StateTransition.count }
      .from(0)
      .to(1)

    state_transition = ::Vulnerabilities::StateTransition.last
    expect(state_transition).to be_valid
    expect(state_transition.vulnerability_id).to eq(resolved_vulnerability.id)
    expect(state_transition.vulnerability_occurrence_id).to eq(resolved_vulnerability.finding_id)
  end

  it 'creates a detection transition with detected: true', :aggregate_failures do
    finding_ids = resolved_vulnerability.findings.pluck(:id)

    expect { mark_resolved_as_detected }.to change {
      Vulnerabilities::DetectionTransition.where(vulnerability_occurrence_id: finding_ids).count
    }.by(1)

    transition = Vulnerabilities::DetectionTransition.find_by(vulnerability_occurrence_id: finding_ids)
    expect(transition.detected).to be(true)
  end

  it 'marks the findings as transitioned_to_detected' do
    expect { mark_resolved_as_detected }.to change { existing_resolved_finding_map.transitioned_to_detected }.to(true)
                                        .and not_change { existing_detected_finding_map.transitioned_to_detected }
                                        .and not_change { new_finding_map.transitioned_to_detected }
  end

  describe 'after sec transaction is committed' do
    before do
      # Create finding_maps outside of transaction
      finding_maps
    end

    subject(:post_commit) { SecApplicationRecord.transaction { mark_resolved_as_detected } }

    it 'publishes the bulk dismissed event', :freeze_time do
      expect { post_commit }.to publish_event(Vulnerabilities::BulkRedetectedEvent).with(
        {
          vulnerabilities: [{
            vulnerability_id: resolved_vulnerability.id,
            pipeline_id: pipeline.id,
            timestamp: Time.zone.now.iso8601
          }]
        }
      )
    end
  end
end
