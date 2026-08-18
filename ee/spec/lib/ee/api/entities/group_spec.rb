# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Entities::Group, feature_category: :groups_and_projects do
  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:group) { project.group }

  let(:options) { {} }

  subject(:json) { described_class.new(group, options).as_json }

  it 'returns expected data' do
    expect(json.keys).to include(
      :ldap_cn,
      :ldap_access,
      :wiki_access_level
    )
    expect(json.keys).not_to include(
      :ldap_group_links,
      :saml_group_links,
      :repository_storage,
      :file_template_project_id,
      :duo_core_features_enabled,
      :duo_features_enabled,
      :lock_duo_features_enabled,
      :web_based_commit_signing_enabled,
      :allow_personal_snippets
    )
  end

  context 'and there are LDAP group links' do
    let!(:ldap_group_link) { create(:ldap_group_link, group: group) }

    it 'returns expected data' do
      expect(json.keys).to include(:ldap_group_links)
    end
  end

  context 'and there are SAML group links' do
    let!(:saml_group_link) { create(:saml_group_link, group: group) }

    it 'returns expected data' do
      expect(json.keys).to include(:saml_group_links)
    end
  end

  context 'when there is a user' do
    let(:options) { { current_user: user } }

    context 'and the user is an admin', :enable_admin_mode do
      let(:user) { create(:admin) }

      context 'and the group_wikis feature is available' do
        before do
          stub_licensed_features(group_wikis: true)
        end

        it 'returns expected data' do
          expect(json.keys).to include(:repository_storage)
        end
      end
    end

    context 'and the custom_file_templates_for_namespace feature is available' do
      before do
        stub_licensed_features(custom_file_templates_for_namespace: true)
      end

      context 'and there is a checked file template project available' do
        let(:user) { create(:user, developer_of: project) }

        before do
          group.file_template_project = project
        end

        it 'returns expected data' do
          expect(json.keys).to include(:file_template_project_id)
        end
      end
    end

    context 'and user is a group admin' do
      let(:user) { create(:user, owner_of: group) }

      context 'and the licensed_duo_core_features are available' do
        before do
          stub_licensed_features(code_suggestions: true)
        end

        it 'returns expected data' do
          expect(json.keys).to include(:duo_core_features_enabled)
        end
      end

      context 'and the licensed_ai_features are available' do
        before do
          stub_licensed_features(ai_features: true)
        end

        it 'returns expected data' do
          expect(json.keys).to include(
            :duo_features_enabled,
            :lock_duo_features_enabled
          )
        end
      end

      context 'and the repositories_web_based_commit_signing feature is available' do
        before do
          stub_saas_features(repositories_web_based_commit_signing: true)
        end

        it 'returns expected data' do
          expect(json.keys).to include(
            :web_based_commit_signing_enabled
          )
        end
      end
    end
  end

  context 'when the group is an enterprise group', :saas do
    let(:user) { create(:user, enterprise_group: group, owner_of: group) }
    let(:options) { { current_user: user } }

    context 'and the allow_personal_snippets feature is available' do
      before do
        stub_licensed_features(domain_verification: true, allow_personal_snippets: true)
        stub_saas_features(allow_personal_snippets: true)
      end

      it 'returns expected data' do
        expect(json.keys).to include(
          :allow_personal_snippets
        )
      end
    end
  end
end
