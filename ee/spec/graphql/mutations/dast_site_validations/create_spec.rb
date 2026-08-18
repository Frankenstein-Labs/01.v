# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::DastSiteValidations::Create, feature_category: :dynamic_application_security_testing do
  include GraphqlHelpers

  let(:project) { create(:project, :repository) }
  let(:current_user) { create(:user) }
  let(:full_path) { project.full_path }
  let(:dast_site) { create(:dast_site, project: project) }
  let(:dast_site_token) { create(:dast_site_token, project: dast_site.project, url: dast_site.url) }
  let(:dast_site_validation) { DastSiteValidation.find_by!(url_path: validation_path) }
  let(:validation_path) { SecureRandom.hex }

  subject(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }

  before do
    project.update!(ci_pipeline_variables_minimum_override_role: :developer)
    stub_licensed_features(security_on_demand_scans: true)

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

  specify { expect(described_class).to require_graphql_authorizations(:create_on_demand_dast_scan) }

  describe '#resolve' do
    subject do
      mutation.resolve(
        full_path: full_path,
        dast_site_token_id: dast_site_token.to_global_id,
        validation_path: validation_path,
        strategy: :text_file
      )
    end

    context 'when on demand scan feature is enabled' do
      context 'when the project does not exist' do
        let(:full_path) { SecureRandom.hex }

        it 'raises an exception' do
          expect { subject }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when the user can run a dast scan' do
        before do
          project.add_developer(current_user)
        end

        it 'returns the dast_site_validation id' do
          expect(subject[:id]).to eq(dast_site_validation.to_global_id)
        end

        it 'returns the dast_site_validation status' do
          expect(subject[:status]).to eq(dast_site_validation.state)
        end
      end
    end
  end
end
