# frozen_string_literal: true

require 'spec_helper'

# Generates the fixtures consumed by the `fromHaml` adapter specs in
# ee/spec/frontend/vulnerabilities/components/vulnerability_details_enrichment/adapters.
#
# The fixture is the output of `VulnerabilitiesHelper#vulnerability_details_app_data`
# - i.e. the `data-*` payload mounted on the vulnerability details page - so the
# adapter is built against the actual output rather than a
# manual mock. When the helper or its serializers change, regenerating
# the fixtures (`rake frontend:fixtures`) reveals any impact on the adapter.
#
# The setup only populates the fields the adapter currently maps; it grows
# alongside the page (and the query) as more UI is built.
RSpec.describe VulnerabilitiesHelper, '(JavaScript fixtures)', type: :helper,
  feature_category: :vulnerability_management do
  include JavaScriptFixturesHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project, freeze: false) { create(:project, :repository, :public) }
  let_it_be(:pipeline) { create(:ci_pipeline, :success, project: project, ref: 'main') }

  # The `vulnerability` data attribute is itself a JSON string within the
  # payload; parse both levels to assert on the shape the adapter consumes.
  let(:vulnerability_payload) { Gitlab::Json.safe_parse(Gitlab::Json.safe_parse(response).fetch('vulnerability')) }

  before do
    allow(helper).to receive_messages(current_user: user, can?: true)
  end

  describe 'a vulnerability with related records (pipeline, transitions, MR links, issue links)' do
    let(:finding) { create(:vulnerabilities_finding, :identifier, project: project, severity: :high) }

    let(:vulnerability) do
      create(:vulnerability, :dismissed, severity: :high,
        title: 'Cross-site scripting in foo.js', project: project, findings: [finding])
    end

    let(:ascp_component) { create(:security_ascp_component, :with_security_context, project: project) }

    let(:response) { helper.vulnerability_details_app_data(vulnerability, pipeline, project, []).to_json }

    before do
      allow(user).to receive(:can?).and_return(true)

      create(:vulnerability_state_transition, vulnerability: vulnerability,
        from_state: :detected, to_state: :dismissed, dismissal_reason: :acceptable_risk,
        comment: 'Not exploitable in this context', author: user)
      create(:vulnerabilities_merge_request_link, vulnerability: vulnerability,
        merge_request: create(:merge_request, source_project: project))
      create(:vulnerabilities_issue_link, vulnerability: vulnerability,
        issue: create(:issue, project: project))
      create(:vulnerability_finding_ascp_component_link, project: project,
        vulnerability_finding: finding, ascp_component: ascp_component)
    end

    it 'vulnerabilities/details_with_related_records.json', :aggregate_failures do
      expect(vulnerability_payload).to include('can_admin' => true)
      expect(vulnerability_payload).to include(
        'id', 'title', 'state', 'severity', 'detected_at',
        'scanner', 'pipeline', 'state_transitions', 'merge_request_links', 'issue_links',
        'identifiers', 'links'
      )
      # These records have separate factory calls and could change, so assert
      # they carry an actual value rather than just being present as keys.
      expect(vulnerability_payload['state_transitions']).to be_present
      expect(vulnerability_payload['merge_request_links']).to be_present
      expect(vulnerability_payload['issue_links']).to be_present
      expect(vulnerability_payload['identifiers']).to be_present
      expect(vulnerability_payload['links']).to be_present
      expect(vulnerability_payload['ascp_component']).to be_present
      expect(vulnerability_payload.dig('ascp_component', 'security_context')).to be_present
    end
  end

  describe 'a vulnerability with no related records' do
    let(:finding) { create(:vulnerabilities_finding, project: project) }
    let(:vulnerability) do
      create(:vulnerability, title: 'Vulnerability without related records', project: project,
        findings: [finding])
    end

    let(:response) { helper.vulnerability_details_app_data(vulnerability, nil, project, []).to_json }

    it 'vulnerabilities/details_without_related_records.json', :aggregate_failures do
      expect(vulnerability_payload).to include('id', 'title', 'state', 'severity')
      # No pipeline is passed and no transitions/MR links are created, so the
      # related-record data is absent.
      expect(vulnerability_payload['pipeline']).to be_nil
      # Absent because this block leaves `can?` unstubbed, so the payload's
      # permission gate closes before the component is looked up. The gate and
      # the no-component branch are covered in
      # ee/spec/helpers/vulnerabilities_helper_spec.rb.
      expect(vulnerability_payload['ascp_component']).to be_nil
    end
  end
end
