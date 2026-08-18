# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::Security::VulnerabilitiesController, feature_category: :vulnerability_management do
  let(:user) { create(:user) }
  let(:group) { create(:group) }

  before do
    sign_in(user)
  end

  describe 'GET index' do
    subject(:show_vulnerability_dashboard) { get :index, params: { group_id: group.to_param } }

    context 'when security dashboard feature is enabled' do
      before do
        stub_licensed_features(security_dashboard: true)
      end

      context 'and user is allowed to access group security vulnerabilities' do
        before do
          group.add_developer(user)
        end

        it { is_expected.to have_gitlab_http_status(:ok) }

        it_behaves_like 'tracks govern usage event', 'security_vulnerabilities' do
          let(:request) { show_vulnerability_dashboard }
        end

        it 'records correct events and metrics', :clean_gitlab_redis_shared_state do
          expect { show_vulnerability_dashboard }
              .to trigger_internal_events('visit_vulnerability_report')
              .with(user: user, namespace: group)
              .with(user: user, namespace: group)
              .and increment_usage_metrics(
                'counts.count_total_visit_vulnerability_report',
                'counts.count_total_visit_vulnerability_report_monthly',
                'counts.count_total_visit_vulnerability_report_weekly',
                'redis_hll_counters.count_distinct_user_id_from_visit_vulnerability_report_monthly',
                'redis_hll_counters.count_distinct_namespace_id_from_visit_vulnerability_report_monthly',
                'redis_hll_counters.count_distinct_user_id_from_visit_vulnerability_report_weekly',
                'redis_hll_counters.count_distinct_namespace_id_from_visit_vulnerability_report_weekly'
              ).and not_increment_usage_metrics(
                'redis_hll_counters.count_distinct_project_id_from_visit_vulnerability_report_monthly',
                'redis_hll_counters.count_distinct_project_id_from_visit_vulnerability_report_weekly'
              )
        end

        shared_examples 'resolveVulnerabilityWithAi ability' do |allowed|
          before do
            allow(Ability).to receive(:allowed?).and_call_original
            allow(Ability).to receive(:allowed?).with(user, :resolve_vulnerability_with_ai, group).and_return(allowed)
            show_vulnerability_dashboard
          end

          render_views

          it "sets the frontend ability to #{allowed}" do
            expect(response.body).to have_pushed_frontend_ability(resolveVulnerabilityWithAi: allowed)
          end
        end

        context "when resolveVulnerabilityWithAi ability is allowed" do
          it_behaves_like 'resolveVulnerabilityWithAi ability', true
        end

        context "when resolveVulnerabilityWithAi ability is not allowed" do
          it_behaves_like 'resolveVulnerabilityWithAi ability', false
        end
      end

      context 'when user is not allowed to access group security vulnerabilities' do
        it { is_expected.to have_gitlab_http_status(:not_found) }

        it_behaves_like "doesn't track govern usage event", 'security_vulnerabilities' do
          let(:request) { show_vulnerability_dashboard }
        end

        it 'does not record events or metrics' do
          expect { show_vulnerability_dashboard }.not_to trigger_internal_events('visit_vulnerability_report')
        end
      end
    end

    context 'when security dashboard feature is disabled' do
      it { is_expected.to have_gitlab_http_status(:not_found) }

      it_behaves_like "doesn't track govern usage event", 'security_vulnerabilities' do
        let(:request) { show_vulnerability_dashboard }
      end

      it 'does not record events or metrics' do
        expect { show_vulnerability_dashboard }.not_to trigger_internal_events('visit_vulnerability_report')
      end
    end
  end
end
