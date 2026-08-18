# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::VAC, feature_category: :vulnerability_management do
  let_it_be(:project) { create(:project) }
  let_it_be(:other_project) { create(:project) }
  let_it_be(:user) { create(:user) }

  describe '.enabled?' do
    subject(:enabled?) { described_class.enabled?(actor) }

    context 'when actor is a Project' do
      let(:actor) { project }

      context 'when not on a Dedicated instance' do
        before do
          stub_application_setting(gitlab_dedicated_instance: false)
        end

        context 'when the feature flag is enabled for the root namespace' do
          before do
            stub_feature_flags(vulnerabilities_across_contexts: project.root_namespace)
          end

          it { is_expected.to be(true) }
        end

        context 'when the feature flag is enabled only for the project' do
          before do
            stub_feature_flags(vulnerabilities_across_contexts: project)
          end

          it 'checks the flag against the root namespace, not the project' do
            is_expected.to be(false)
          end
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(vulnerabilities_across_contexts: false)
          end

          it { is_expected.to be(false) }

          context 'when the project id is in vac_project_ids' do
            before do
              stub_application_setting(vac_project_ids: [project.id])
            end

            it 'ignores vac_project_ids outside of Dedicated' do
              is_expected.to be(false)
            end
          end
        end
      end

      context 'when on a Dedicated instance' do
        before do
          stub_application_setting(gitlab_dedicated_instance: true)
        end

        context 'when the feature flag is enabled for the root namespace' do
          before do
            stub_feature_flags(vulnerabilities_across_contexts: project.root_namespace)
          end

          it { is_expected.to be(true) }
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(vulnerabilities_across_contexts: false)
          end

          context 'when the project id is in vac_project_ids' do
            before do
              stub_application_setting(vac_project_ids: [project.id])
            end

            it { is_expected.to be(true) }
          end

          context 'when the project id is not in vac_project_ids' do
            before do
              stub_application_setting(vac_project_ids: [other_project.id])
            end

            it { is_expected.to be(false) }
          end

          context 'when vac_project_ids is empty' do
            before do
              stub_application_setting(vac_project_ids: [])
            end

            it { is_expected.to be(false) }
          end
        end
      end
    end

    context 'when actor is not a Project' do
      let(:actor) { user }

      before do
        stub_application_setting(gitlab_dedicated_instance: true)
        stub_application_setting(vac_project_ids: [project.id])
      end

      context 'when the feature flag is enabled for the actor' do
        before do
          stub_feature_flags(vulnerabilities_across_contexts: user)
        end

        it { is_expected.to be(true) }
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(vulnerabilities_across_contexts: false)
        end

        it 'does not consult vac_project_ids for non-Project actors' do
          is_expected.to be(false)
        end
      end
    end
  end

  describe '.disabled?' do
    subject(:disabled?) { described_class.disabled?(project) }

    before do
      stub_application_setting(gitlab_dedicated_instance: false)
    end

    context 'when enabled? returns true' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: project.root_namespace)
      end

      it { is_expected.to be(false) }
    end

    context 'when enabled? returns false' do
      before do
        stub_feature_flags(vulnerabilities_across_contexts: false)
      end

      it { is_expected.to be(true) }
    end
  end
end
