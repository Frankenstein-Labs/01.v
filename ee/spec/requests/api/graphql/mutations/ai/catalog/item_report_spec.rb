# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'AiCatalogItemReport', feature_category: :workflow_catalog do
  include Ai::Catalog::TestHelpers
  include GraphqlHelpers

  let_it_be(:guest) { create(:user) }
  let_it_be(:project) { create(:project, :private, guests: guest) }
  let_it_be(:public_catalog_item) { create(:ai_catalog_agent, :public, project: project) }
  let_it_be(:private_catalog_item) { create(:ai_catalog_agent, project: project) }
  let_it_be(:flow_item) { create(:ai_catalog_flow, :public, project: project) }
  let_it_be(:third_party_flow_item) { create(:ai_catalog_third_party_flow, :public, project: project) }

  let(:catalog_item) { public_catalog_item }
  let(:current_user) { guest }
  let(:reason) { 'SPAM_OR_LOW_QUALITY' }
  let(:body) { 'This item contains offensive material' }
  let(:input) do
    {
      id: catalog_item.to_global_id.to_s,
      reason: reason,
      body: body
    }
  end

  let(:mutation) { graphql_mutation(:ai_catalog_item_report, input) }
  let(:mutation_response) { graphql_mutation_response(:ai_catalog_item_report) }

  subject(:resolve) { post_graphql_mutation(mutation, current_user: current_user) }

  before do
    stub_application_setting(abuse_notification_email: 'admin@example.com')
    enable_ai_catalog
  end

  shared_examples 'schedules email delivery' do
    it 'schedules the abuse report email and returns success', :aggregate_failures, :clean_gitlab_redis_rate_limiting do
      expected_reason = reason.downcase

      expect { resolve }.to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)
        .with(current_user.id, hash_including(item_id: catalog_item.id, reason: expected_reason, message: body))

      expect(response).to have_gitlab_http_status(:success)
      expect(mutation_response['errors']).to be_empty
    end
  end

  shared_examples 'denies access and does not schedule email' do
    it 'returns access error and does not schedule email delivery', :aggregate_failures do
      expect { resolve }.not_to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)

      expect_graphql_errors_to_include(/you don't have permission/i)
    end
  end

  context 'when user has report_ai_catalog_item permission' do
    context 'when user is a guest with public item' do
      let(:current_user) { guest }
      let(:catalog_item) { public_catalog_item }

      context 'with all required parameters' do
        it_behaves_like 'schedules email delivery'
      end

      context 'without optional body parameter' do
        let(:body) { nil }

        it 'schedules the abuse report email without message and returns success', :aggregate_failures do
          expected_reason = reason.downcase

          expect { resolve }.to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)
            .with(current_user.id, hash_including(item_id: catalog_item.id, reason: expected_reason, message: nil))

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to be_empty
        end
      end

      context 'with different report reasons' do
        %w[
          IMMEDIATE_SECURITY_THREAT
          POTENTIAL_SECURITY_THREAT
          EXCESSIVE_RESOURCE_USAGE
          SPAM_OR_LOW_QUALITY
          OTHER
        ].each do |report_reason|
          context "when reason is #{report_reason}" do
            let(:reason) { report_reason }

            it_behaves_like 'schedules email delivery'
          end
        end
      end

      context 'when reason is OTHER and body is empty string' do
        let(:reason) { 'OTHER' }
        let(:body) { '' }

        it 'returns validation error and does not schedule email delivery', :aggregate_failures do
          expect { resolve }.not_to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)

          expect(response).to have_gitlab_http_status(:success)
          expect(mutation_response['errors']).to contain_exactly('Additional details are required when reason is OTHER')
        end
      end

      context 'when body exceeds maximum length' do
        let(:body) { 'a' * 1001 }

        it 'returns validation error and does not schedule email delivery', :aggregate_failures do
          expect { resolve }.not_to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)

          expect(response).to have_gitlab_http_status(:success)
          expect(graphql_errors).to include(
            hash_including('message' => a_string_matching(/body is too long/i))
          )
        end
      end

      context 'when ai_catalog is not available for the project' do
        let(:current_user) { guest }
        let(:catalog_item) { public_catalog_item }

        before do
          allow(project).to receive(:ai_catalog_available?).and_return(false)
        end

        it_behaves_like 'schedules email delivery'
      end
    end

    context 'when user is a guest with private item' do
      let(:current_user) { guest }
      let(:catalog_item) { private_catalog_item }

      it_behaves_like 'schedules email delivery'
    end

    context 'with different catalog item types' do
      let(:current_user) { guest }

      context 'when item is a flow' do
        let(:catalog_item) { flow_item }

        it_behaves_like 'schedules email delivery'
      end

      context 'when item is a third_party_flow' do
        let(:catalog_item) { third_party_flow_item }

        it_behaves_like 'schedules email delivery'
      end
    end
  end

  context 'when user does not have report_ai_catalog_item permission' do
    context 'when user is anonymous with public item' do
      let(:current_user) { nil }
      let(:catalog_item) { public_catalog_item }

      it_behaves_like 'denies access and does not schedule email'
    end

    context 'when abuse_notification_email is not configured' do
      let(:current_user) { guest }
      let(:catalog_item) { public_catalog_item }

      before do
        stub_application_setting(abuse_notification_email: nil)
      end

      it_behaves_like 'denies access and does not schedule email'
    end

    context 'when catalog item does not exist' do
      let(:current_user) { guest }
      let(:input) do
        {
          id: "gid://gitlab/Ai::Catalog::Item/#{non_existing_record_id}",
          reason: reason,
          body: body
        }
      end

      it_behaves_like 'denies access and does not schedule email'
    end
  end

  describe 'rate limiting', :clean_gitlab_redis_rate_limiting do
    let(:current_user) { guest }
    let(:catalog_item) { public_catalog_item }

    context 'when rate limit is not exceeded' do
      it 'allows the report and schedules email delivery', :aggregate_failures do
        expect { resolve }.to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
      end
    end

    context 'when rate limit is exceeded', :freeze_time do
      before do
        10.times do
          Gitlab::ApplicationRateLimiter.throttled?(:ai_catalog_item_report, scope: current_user)
        end
      end

      it 'returns an error and does not schedule email delivery', :aggregate_failures do
        expect { resolve }.not_to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to contain_exactly(
          'You have reported this item too many times. Please try again later.'
        )
      end
    end

    context 'when different users report', :freeze_time do
      let_it_be(:another_user) { create(:user, guest_of: project) }

      it 'allows different users to report independently', :aggregate_failures do
        10.times do
          Gitlab::ApplicationRateLimiter.throttled?(:ai_catalog_item_report, scope: current_user)
        end

        expect do
          post_graphql_mutation(mutation, current_user: another_user)
        end.to have_enqueued_mail(Ai::CatalogItemAbuseReportMailer, :notify)

        expect(response).to have_gitlab_http_status(:success)
        expect(mutation_response['errors']).to be_empty
      end
    end
  end
end
