# frozen_string_literal: true

require 'spec_helper'
require 'email_spec'

RSpec.describe Emails::CiRunnerUsageByProject, feature_category: :fleet_visibility do
  include EmailSpec::Matchers

  include_context 'gitlab email notification'

  describe '#runner_usage_by_project_csv_email', travel_to: '2023-12-24' do
    let_it_be(:user_email) { 'sam@email.com' }
    let_it_be(:current_user) { build_stubbed :user, email: user_email, name: 'UserName' }

    let(:from_date) { Date.new(2023, 11, 1) }
    let(:to_date) { Date.new(2023, 11, 30) }
    let(:content_type) { 'text/csv' }
    let(:csv_data) { 'csv,separated,things' }
    let(:export_status) { { projects_expected: 3, projects_written: 2, truncated: false } }

    let(:expected_filename) { "ci_runner_usage_report_2023-11-01_2023-11-30.csv" }

    subject(:mail) do
      Notify.runner_usage_by_project_csv_email(
        user: current_user,
        scope: scope,
        from_date: from_date,
        to_date: to_date,
        csv_data: csv_data,
        export_status: export_status
      )
    end

    shared_examples 'a runner usage email sent from GitLab' do
      it 'renders an email with attachment' do
        expect(mail.subject).to eq('Exported CI Runner usage (2023-11-01 - 2023-11-30)')
        expect(mail.to).to contain_exactly(user_email)
        expect(mail.text_part.to_s).to include(expected_plain_text)
        expect(mail.html_part.to_s.delete("\r\n=")).to include(expected_html_text)
        expect(mail.attachments.size).to eq(1)

        attachment = mail.attachments.first

        expect(attachment.content_type).to eq(content_type)
        expect(attachment.filename).to eq(expected_filename)
      end
    end

    context 'when scope is not specified' do
      let(:scope) { nil }
      let(:expected_plain_text) do
        'Your CI runner usage CSV export of the top 2 projects has been added to this email as an attachment.'
      end

      let(:expected_html_text) do
        'Your CI runner usage CSV export containing the top 2 projects has been added to this email as an attachment.'
      end

      it_behaves_like 'a runner usage email sent from GitLab'
    end

    context 'when scope is a group' do
      let_it_be(:scope) { build_stubbed(:group) }

      let(:expected_plain_text) do
        'Your CI runner usage CSV export containing the top 2 projects in the ' \
          "\"#{scope.full_path}\" group has been added to this email as an attachment."
      end

      let(:expected_html_text) do
        'Your CI runner usage CSV export containing the top 2 projects in the ' \
          "\"#{scope.full_path}\" group has been added to this email as an attachment."
      end

      it_behaves_like 'a runner usage email sent from GitLab'
    end

    context 'when scope is a project' do
      let_it_be(:scope) { build_stubbed(:project) }

      let(:expected_plain_text) do
        "Your CI runner usage CSV export for the \"#{scope.full_path}\" project " \
          'has been added to this email as an attachment.'
      end

      let(:expected_html_text) do
        "Your CI runner usage CSV export for the \"#{scope.full_path}\" project " \
          'has been added to this email as an attachment.'
      end

      it_behaves_like 'a runner usage email sent from GitLab'
    end
  end
end
