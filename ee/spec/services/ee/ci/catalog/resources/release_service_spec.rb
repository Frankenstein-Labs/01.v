# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::Catalog::Resources::ReleaseService, feature_category: :pipeline_composition do
  let(:project) { create(:project, :catalog_resource_with_components) }
  let(:user) { project.first_owner }

  describe '#execute' do
    let(:metadata) { nil }
    let(:release) do
      create(:release, project: project, sha: project.repository.root_ref_sha, author: user)
    end

    subject(:execute) { described_class.new(release, user, metadata).execute }

    context 'with ci_cd_catalog_projects_allowlist application setting' do
      let!(:catalog_resource) { create(:ci_catalog_resource, project: project) }

      before do
        stub_licensed_features(ci_cd_catalog_publish_restriction: true)
      end

      shared_examples 'allowing publishing from project' do
        it 'allows publishing from any project' do
          response = execute

          expect(response).to be_success
        end
      end

      shared_examples 'not allowing publishing from project' do
        it 'returns an error' do
          response = execute

          expect(response).to be_error
          expect(response.message).to include('The project is not authorized to publish to the CI/CD catalog')
        end

        it 'tracks the blocked event' do
          expect { execute }
            .to trigger_internal_events('ci_catalog_publish_blocked_by_allowlist')
            .with(user: user, project: project, namespace: project.namespace)
        end
      end

      shared_examples 'not tracking the blocked event' do
        it 'does not track the blocked event' do
          expect { execute }.not_to trigger_internal_events('ci_catalog_publish_blocked_by_allowlist')
        end
      end

      context 'when allowlist is empty' do
        before do
          stub_application_setting(ci_cd_catalog_projects_allowlist: [])
        end

        it_behaves_like 'allowing publishing from project'
        it_behaves_like 'not tracking the blocked event'
      end

      context 'when allowlist contains the project path' do
        before do
          stub_application_setting(ci_cd_catalog_projects_allowlist: [project.full_path])
        end

        it_behaves_like 'allowing publishing from project'
        it_behaves_like 'not tracking the blocked event'
      end

      context 'when allowlist contains a matching regex pattern' do
        before do
          stub_application_setting(ci_cd_catalog_projects_allowlist: ["#{project.namespace.full_path}/.*"])
        end

        it_behaves_like 'allowing publishing from project'
        it_behaves_like 'not tracking the blocked event'
      end

      context 'when allowlist does not contain the project' do
        before do
          stub_application_setting(ci_cd_catalog_projects_allowlist: ['other/project'])
        end

        it_behaves_like 'not allowing publishing from project'
      end

      context 'when allowlist contains an invalid regex pattern' do
        before do
          stub_application_setting(ci_cd_catalog_projects_allowlist: ['[invalid-regex'])
        end

        it_behaves_like 'not allowing publishing from project'
      end

      context 'when license does not support the feature' do
        before do
          stub_licensed_features(ci_cd_catalog_publish_restriction: false)
          stub_application_setting(ci_cd_catalog_projects_allowlist: ['other/project'])
        end

        it 'allows publishing (allowlist is ignored without license)' do
          response = execute

          expect(response).to be_success
        end

        it_behaves_like 'not tracking the blocked event'
      end
    end
  end
end
