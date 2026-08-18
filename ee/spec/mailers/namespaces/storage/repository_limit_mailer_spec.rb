# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::Storage::RepositoryLimitMailer, feature_category: :consumables_cost_management do
  include EmailSpec::Matchers

  let(:recipients) { %w[bob@example.com john@example.com] }
  let(:project) { build_stubbed(:project) }

  describe '#notify_out_of_storage' do
    it 'creates an email message for a project', :aggregate_failures do
      mail = described_class.notify_out_of_storage(project_name: project.name, recipients: recipients)

      expect(mail).to have_subject "Action required: #{project.name} is read-only"
      expect(mail).to bcc_to recipients
      expect(mail).to have_text(
        "You have consumed all available storage and you can't push " \
          "or add large files to #{project.name}"
      )

      expect(mail).to have_text(
        "To remove the read-only state, reduce git repository and git LFS storage. " \
          "For more information contact support."
      )
    end
  end

  describe '#notify_limit_warning' do
    it 'creates an email message for a project', :aggregate_failures do
      mail = described_class.notify_limit_warning(project_name: project.name, recipients: recipients)

      expect(mail).to have_subject "Action required: Unusually high storage usage on #{project.name}"
      expect(mail).to bcc_to recipients
      expect(mail).to have_text("We've noticed an unusually high storage usage on #{project.name}")

      expect(mail).to have_text(
        "To prevent your project from being placed in a read-only state, manage your storage use " \
          "or contact support immediately."
      )
    end
  end
end
