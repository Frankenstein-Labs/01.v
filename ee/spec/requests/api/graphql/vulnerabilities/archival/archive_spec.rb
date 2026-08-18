# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Initiating the archival of vulnerabilities', feature_category: :vulnerability_management do
  include GraphqlHelpers

  let_it_be(:project) { create(:project) }
  let_it_be(:current_user) { create(:user) }
  let_it_be(:date) { Time.zone.today }

  let(:mutation) do
    graphql_mutation(
      :vulnerabilities_archive,
      project_id: project.to_global_id.to_s,
      date: date.to_s)
  end

  before do
    stub_licensed_features(security_dashboard: true)

    allow(Vulnerabilities::Archival::ArchiveWorker).to receive(:perform_async)
  end

  context 'when the user does not have permission' do
    it_behaves_like 'a mutation that returns a top-level access error'

    it 'does not schedule the archive worker' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(Vulnerabilities::Archival::ArchiveWorker).not_to have_received(:perform_async)
    end
  end

  context 'when the user has permission' do
    before_all do
      project.add_maintainer(current_user)
    end

    it 'schedules the archive worker' do
      post_graphql_mutation(mutation, current_user: current_user)

      expect(Vulnerabilities::Archival::ArchiveWorker).to have_received(:perform_async).with(project.id, date)
    end

    it_behaves_like 'authorizing granular token permissions for GraphQL', :archive_vulnerability do
      let(:user) { current_user }
      let(:boundary_object) { project }
      let(:authz_mutation) do
        graphql_mutation(
          :vulnerabilities_archive,
          { project_id: project.to_global_id.to_s, date: date.to_s },
          'errors'
        )
      end

      let(:request) { post_graphql_mutation(authz_mutation, token: { personal_access_token: pat }) }
    end

    context 'when the `vulnerability_archival` feature flag is disabled' do
      before do
        stub_feature_flags(vulnerability_archival: false)
      end

      it_behaves_like 'a mutation that returns a top-level access error'

      it 'does not schedule the archive worker' do
        post_graphql_mutation(mutation, current_user: current_user)

        expect(Vulnerabilities::Archival::ArchiveWorker).not_to have_received(:perform_async)
      end
    end
  end
end
