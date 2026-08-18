# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::ExportMailer, feature_category: :vulnerability_management do
  include EmailSpec::Matchers

  describe '#completion_email' do
    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
    let_it_be(:export) { create(:vulnerability_export) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject(:email) { described_class.completion_email(export) }

    it 'creates an email notifying of export completion', :aggregate_failures do
      expect(email).to have_subject("#{export.exportable.name} | #{s_('Vulnerabilities|Vulnerability Report export')}")
      expect(email).to have_body_text('The Vulnerability Report was successfully exported from')
      expect(email).to have_body_text(export.project.full_name)
      expect(email).to have_body_text("/#{export.project.full_path}")
      expect(email).to have_body_text(%r{api/v4/security/vulnerability_exports/\d+/download})
      expect(email).to have_body_text(format(s_('Vulnerabilities|This link will expire in %{number} days.'), number: 7))
      expect(email).to be_delivered_to([export.author.notification_email_for(export.project.group)])
    end

    context 'when dashboard_type is present in report_data' do
      let_it_be(:dashboard_export) do
        build_stubbed(:vulnerability_export, report_data: { 'dashboard_type' => 'group' })
      end

      subject(:dashboard_email) { described_class.completion_email(dashboard_export) }

      it 'creates an email with Security Dashboard Report label', :aggregate_failures do
        expect(dashboard_email)
          .to have_subject("#{dashboard_export.exportable.name} | #{s_('Vulnerabilities|Security Dashboard export')}")
        expect(dashboard_email).to have_body_text(_('The Security Dashboard was successfully exported from'))
        expect(dashboard_email).to have_body_text(dashboard_export.project.full_name)
        expect(dashboard_email).to have_body_text("/#{dashboard_export.project.full_path}")
        expect(dashboard_email).to have_body_text(%r{api/v4/security/vulnerability_exports/\d+/download})
        expect(dashboard_email)
          .to have_body_text(format(s_('Vulnerabilities|This link will expire in %{number} days.'), number: 7))
        expect(dashboard_email)
          .to be_delivered_to([dashboard_export.author.notification_email_for(dashboard_export.project.group)])
      end
    end

    context 'when exportable is a group' do
      let(:group) { build_stubbed(:group) }
      let(:user) { build_stubbed(:user) }

      let(:export) do
        build_stubbed(:vulnerability_export, :group, exportable: group, author: user)
      end

      subject(:email) { described_class.completion_email(export) }

      it 'sends email with group name and correct recipient', :aggregate_failures do
        expect(email.subject).to include("#{group.name} | #{s_('Vulnerabilities|Vulnerability Report export')}")
        expect(email).to be_delivered_to([user.notification_email_for(group)])
        expect(email).to have_body_text(format(s_('Vulnerabilities|This link will expire in %{number} days.'),
          number: 7))
      end
    end

    context 'when exportable is an instance security dashboard' do
      let(:user) { build_stubbed(:user) }

      let(:export) do
        build_stubbed(:vulnerability_export, :user, author: user)
      end

      subject(:email) { described_class.completion_email(export) }

      it 'sends a personal dashboard email and delivers it to the author', :aggregate_failures do
        expect(export.exportable).to be_an(InstanceSecurityDashboard)
        expect(email.subject).to include(
          "#{s_('Vulnerabilities|Your personal dashboard')} | #{s_('Vulnerabilities|Vulnerability Report export')}"
        )
        expect(email).to be_delivered_to([user.notification_email_for(nil)])
        expect(email).to have_body_text('The Vulnerability Report was successfully exported from')
        expect(email).to have_body_text(s_('Vulnerabilities|Your personal dashboard'))
        expect(email).to have_body_text(format(s_('Vulnerabilities|This link will expire in %{number} days.'),
          number: 7))
      end
    end

    context 'when exportable is not a supported type' do
      let(:pipeline) { build_stubbed(:ci_pipeline) }

      it 'raises a RuntimeError' do
        expect do
          build_stubbed(:vulnerability_export, exportable: pipeline)
        end.to raise_error(RuntimeError, 'Can not assign Ci::Pipeline as exportable')
      end
    end
  end
end
