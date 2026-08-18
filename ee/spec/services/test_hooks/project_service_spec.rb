# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TestHooks::ProjectService, feature_category: :code_testing do
  include AfterNextHelpers

  let(:current_user) { create(:user) }

  describe '#execute' do
    let_it_be(:project) { create(:project) }

    let(:hook) { create(:project_hook, project: project) }
    let(:trigger) { 'not_implemented_events' }
    let(:service) { described_class.new(hook, current_user, trigger) }
    let(:success_result) { { status: :success, http_status: 200, message: 'ok' } }

    context 'for vulnerability_events' do
      let(:trigger) { 'vulnerability_events' }
      let(:trigger_key) { :vulnerability_hooks }

      context 'when there is no Vulnerability data' do
        it 'returns an error' do
          error_result = { status: :error, message: 'Ensure the project has vulnerabilities.' }

          expect(service.execute).to have_attributes(error_result)
        end
      end

      context 'when there is Vulnerability data' do
        it 'builds and returns serialized Vulnerability data' do
          freeze_time do
            vulnerability = create(:vulnerability, project: project)

            expected_data = {
              object_kind: "vulnerability",
              object_attributes: {
                url: ::Gitlab::Routing.url_helpers.project_security_vulnerability_url(project, vulnerability),
                title: vulnerability.title,
                state: 'detected',
                project_id: project.id,
                location: nil,
                cvss: [
                  {
                    'vector' => 'CVSS:3.1/AV:N/AC:L/PR:H/UI:N/S:U/C:L/I:L/A:N',
                    'vendor' => 'GitLab'
                  }
                ],
                severity: 'high',
                severity_overridden: false,
                identifiers: [],
                issues: [],
                report_type: "sast",
                scanner_external_id: nil,
                confirmed_at: nil,
                confirmed_by_id: nil,
                dismissed_at: nil,
                dismissed_by_id: nil,
                resolved_on_default_branch: false,
                created_at: vulnerability.created_at,
                updated_at: vulnerability.updated_at,
                resolved_at: nil,
                resolved_by_id: nil,
                auto_resolved: false
              }
            }

            expect(hook).to receive(:execute).with(expected_data, trigger_key, force: true).and_return(success_result)
            expect(service.execute).to include(success_result)
          end
        end
      end
    end
  end
end
