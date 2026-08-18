# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ExportMailer, feature_category: :dependency_management do
  include EmailSpec::Matchers

  describe '#completion_email' do
    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
    let_it_be(:author) { create(:user) }
    let_it_be(:project) { create(:project) }
    let_it_be(:export) { create(:dependency_list_export, project: project, author: author) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject(:email) { described_class.completion_email(export) }

    it 'creates an email notifying of export completion', :aggregate_failures do
      expect(email).to have_subject("#{export.exportable.name} | #{s_('Dependencies|Dependency List export')}")
      expect(email).to have_body_text('The Dependency List was successfully exported from')
      expect(email).to have_body_text(export.project.full_name)
      expect(email).to have_body_text("/#{export.project.full_path}")
      expect(email).to have_body_text(%r{api/v4/dependency_list_exports/\d+/download})
      expect(email).to have_body_text(format(s_('Dependencies|This link will expire in %{number} days.'), number: 7))
      expect(email).to be_delivered_to([export.author.notification_email_for(export.project.group)])
    end

    context 'when exportable is a project' do
      it 'prefixes project name to subject' do
        expect(email).to have_subject("#{project.name} | #{s_('Dependencies|Dependency List export')}")
      end
    end

    context 'when exportable is a group' do
      # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
      let_it_be(:group) { create(:group) }
      let_it_be(:export) { create(:dependency_list_export, group: group, project: nil, author: author) }
      # rubocop:enable RSpec/FactoryBot/AvoidCreate

      it 'prefixes group name to subject' do
        expect(email).to have_subject("#{group.name} | #{s_('Dependencies|Dependency List export')}")
      end
    end

    context 'when exportable is a pipeline' do
      # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
      let_it_be(:pipeline) { create(:ci_pipeline, project: project) }
      let_it_be(:export) { create(:dependency_list_export, pipeline: pipeline, project: project, author: author) }
      # rubocop:enable RSpec/FactoryBot/AvoidCreate

      it 'prefixes project name to subject' do
        expect(email).to have_subject("#{project.name} | #{s_('Dependencies|Dependency List export')}")
      end
    end
  end
end
