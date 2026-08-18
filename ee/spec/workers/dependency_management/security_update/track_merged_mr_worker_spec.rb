# frozen_string_literal: true

require 'spec_helper'

RSpec.describe DependencyManagement::SecurityUpdate::TrackMergedMrWorker,
  feature_category: :dependency_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:dep_mgmt_sa) do
    create(:user, :service_account,
      name: DependencyManagement::ProvisionServiceAccountService::SERVICE_ACCOUNT_NAME)
  end

  let_it_be(:component) { create(:sbom_component, :bundler) }
  let_it_be(:sbom_occurrence) { create(:sbom_occurrence, project: project, component: component) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_finding, project: project) }
  let_it_be(:merge_request) do
    create(:merge_request,
      source_project: project,
      target_project: project,
      author: dep_mgmt_sa,
      source_branch: 'dependency-management/rack-3.x')
  end

  let(:event) { MergeRequests::MergedEvent.new(data: { merge_request_id: merge_request.id }) }

  subject(:handle_event) { described_class.new.handle_event(event) }

  before_all do
    create(:sbom_occurrences_vulnerability, occurrence: sbom_occurrence, vulnerability: vulnerability)
    create(:vulnerabilities_merge_request_link, merge_request: merge_request, vulnerability: vulnerability)
  end

  it_behaves_like 'subscribes to event'

  describe '#handle_event' do
    context 'when the merge_request has a linked vulnerability with an sbom_occurrence' do
      it 'tracks the merge event with purl_type and merge_request_id' do
        expect { handle_event }
          .to trigger_internal_events('merge_dependency_management_auto_remediation_mr')
          .with(
            project: project,
            additional_properties: {
              purl_type: 'gem',
              merge_request_id: merge_request.id
            }
          )
      end
    end

    context 'when the linked vulnerability has no sbom_occurrences' do
      let_it_be(:other_vulnerability) { create(:vulnerability, :with_finding, project: project) }
      let_it_be(:other_mr) do
        create(:merge_request,
          source_project: project,
          target_project: project,
          author: dep_mgmt_sa,
          source_branch: 'dependency-management/foo-1.x')
      end

      let(:event) { MergeRequests::MergedEvent.new(data: { merge_request_id: other_mr.id }) }

      before_all do
        create(:vulnerabilities_merge_request_link,
          merge_request: other_mr, vulnerability: other_vulnerability)
      end

      it 'tracks the merge event with a nil purl_type' do
        expect { handle_event }
          .to trigger_internal_events('merge_dependency_management_auto_remediation_mr')
          .with(
            project: project,
            additional_properties: {
              purl_type: nil,
              merge_request_id: other_mr.id
            }
          )
      end
    end

    context 'when the merge_request does not exist' do
      let(:event) { MergeRequests::MergedEvent.new(data: { merge_request_id: non_existing_record_id }) }

      it 'does not track the merge event' do
        expect { handle_event }
          .not_to trigger_internal_events('merge_dependency_management_auto_remediation_mr')
      end
    end
  end
end
