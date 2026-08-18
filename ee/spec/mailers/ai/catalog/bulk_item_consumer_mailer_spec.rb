# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Catalog::BulkItemConsumerMailer, feature_category: :workflow_catalog do
  include EmailSpec::Matchers

  let(:user) { build_stubbed(:user) }
  let(:item) { build_stubbed(:ai_catalog_agent, name: 'Code Review Agent') }

  # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Records are loaded in the mailer
  let_it_be(:project_a) { create(:project, name: 'Project A') }
  let_it_be(:project_b) { create(:project, name: 'Project B') }
  let_it_be(:project_c) { create(:project, name: 'Project C') }
  # rubocop:enable RSpec/FactoryBot/AvoidCreate

  let(:item_url) { "#{Settings.gitlab['url']}/explore/ai-catalog/agents/#{item.id}" }
  let(:successful_count) { 0 }

  describe '#bulk_create_result_email' do
    subject(:email) do
      described_class.bulk_create_result_email(
        user: user, item: item, successful_count: successful_count, failures: failures
      )
    end

    context 'when all projects succeed' do
      let(:successful_count) { 3 }
      let(:failures) { [] }

      it 'sends a success email with correct content', :aggregate_failures do
        expect(email).to deliver_to(user.notification_email_or_default)
        expect(email).to have_subject('Bulk enablement completed for Code Review Agent')
        expect(email).to have_body_text('completed successfully')
        expect(email).to have_body_text('Total projects: 3')
        expect(email).to have_body_text('Successful: 3')
        expect(email).not_to have_body_text('Failed projects:')
        expect(email.body.encoded).to include(item_url)
      end
    end

    context 'when some projects fail' do
      let(:successful_count) { 1 }
      let(:failures) do
        [
          { project_id: project_b.id, error_message: 'Permission denied' },
          { project_id: project_c.id, error_message: 'Feature not available' }
        ]
      end

      it 'sends a failure email with correct content', :aggregate_failures do
        expect(email).to deliver_to(user.notification_email_or_default)
        expect(email).to have_subject('Bulk enablement completed with errors for Code Review Agent')
        expect(email).to have_body_text('completed with errors')

        expect(email).to have_body_text('Total projects: 3')
        expect(email).to have_body_text('Successful: 1')
        expect(email).to have_body_text('Failed: 2')
        expect(email).to have_body_text('Failed projects:')

        expect(email).to have_body_text('Project B')
        expect(email).to have_body_text('Permission denied')

        expect(email).to have_body_text('Project C')
        expect(email).to have_body_text('Feature not available')

        expect(email).not_to have_body_text('Project A')

        expect(email.body.encoded).to include(item_url)
      end
    end

    context 'when a failed project no longer exists' do
      let(:successful_count) { 0 }
      let(:failures) do
        [
          { project_id: project_a.id, error_message: 'Permission denied' },
          { project_id: non_existing_record_id, error_message: 'Some error' }
        ]
      end

      it 'excludes the missing project from the email', :aggregate_failures do
        expect(email).to have_body_text('Project A')
        expect(email).not_to have_body_text('Some error')
        expect(email).to have_body_text('Failed: 1')
      end
    end

    context 'when all projects fail' do
      let(:successful_count) { 0 }
      let(:failures) do
        [
          { project_id: project_a.id, error_message: 'Already exists' },
          { project_id: project_b.id, error_message: 'Permission denied' }
        ]
      end

      it 'sends a failure email with zero successes', :aggregate_failures do
        expect(email).to have_subject('Bulk enablement failed for Code Review Agent')
        expect(email).to have_body_text('did not complete successfully')
        expect(email).to have_body_text('Successful: 0')
        expect(email).to have_body_text('Failed: 2')
        expect(email).to have_body_text('Failed projects:')
      end
    end

    it 'avoids N+1 queries' do
      render_email = ->(projects) {
        failures = projects.map { |project| { project_id: project.id, error_message: 'Permission denied' } }
        described_class.bulk_create_result_email(user:, item:, successful_count:, failures:).html_part
      }

      control = ActiveRecord::QueryRecorder.new { render_email.call([project_a]) }

      expect { render_email.call([project_a, project_b, project_c]) }.not_to exceed_query_limit(control)
    end
  end
end
