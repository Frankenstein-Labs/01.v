# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a DAST Site Token', feature_category: :dynamic_application_security_testing do
  include GraphqlHelpers

  let_it_be_with_reload(:project) { create(:project, :repository) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:dast_site) { create(:dast_site, project: project) }
  let_it_be(:dast_site_token) { create(:dast_site_token, project: project, url: dast_site.url) }
  let_it_be(:validation_path) { SecureRandom.hex }

  let(:mutation_name) { :dast_site_validation_create }

  let(:mutation) do
    graphql_mutation(
      mutation_name,
      full_path: full_path,
      dast_site_token_id: global_id_of(dast_site_token),
      validation_path: validation_path,
      strategy: Types::DastSiteValidationStrategyEnum.values['TEXT_FILE'].graphql_name
    )
  end

  it_behaves_like 'an on-demand scan mutation when user cannot run an on-demand scan'

  it_behaves_like 'an on-demand scan mutation when user can run an on-demand scan' do
    before do
      project.update!(ci_pipeline_variables_minimum_override_role: :developer)

      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability).to receive(:allowed?).with(current_user, :read_admin_cicd).and_return(true)
      allow(Ability).to receive(:allowed?).with(current_user, :read_runners, project).and_return(true)

      allow_next_instance_of(AppSec::Dast::SiteValidations::RunnerService) do |instance|
        allow(instance).to receive_messages(
          available_runners_exists?: true,
          tagged_runners_available?: false,
          untagged_runners_available?: true
        )
      end
    end

    it 'returns the dast_site_validation id' do
      subject

      dast_site_validation = DastSiteValidation.find_by!(url_path: validation_path)

      expect(mutation_response).to match a_graphql_entity_for(dast_site_validation)
    end

    it 'creates a new dast_site_validation' do
      expect { subject }.to change { DastSiteValidation.count }.by(1)
    end
  end
end
