# frozen_string_literal: true

require 'spec_helper'
require 'rspec-parameterized'

RSpec.describe BlobHelper, feature_category: :source_code_management do
  include TreeHelper
  include FakeBlobHelpers

  describe '#licenses_for_select' do
    let_it_be(:group) { create(:group) }
    let_it_be(:project) { create(:project, :repository, namespace: group) }
    let_it_be(:group_category) { "Group #{group.full_name}" }

    let(:categories) { result.keys }
    let(:by_group) { result[group_category] }
    let(:by_instance) { result['Instance'] }
    let(:by_popular) { result[:Popular] }
    let(:by_other) { result[:Other] }

    subject(:result) { helper.licenses_for_select(project) }

    before do
      stub_ee_application_setting(file_template_project: project)
      set_file_template_project_id(group, project.id)
    end

    it 'returns Group licenses when enabled' do
      stub_licensed_features(custom_file_templates: false, custom_file_templates_for_namespace: true)

      expect(Gitlab::Template::CustomLicenseTemplate)
        .to receive(:all)
              .with(project)
              .and_return([OpenStruct.new(key: 'name', name: 'Name', project_id: project.id)])

      expect(categories).to contain_exactly(:Popular, :Other, group_category)
      expect(by_group).to contain_exactly({ id: 'name', name: 'Name', key: 'name', project_id: project.id })
      expect(by_popular).to be_present
      expect(by_other).to be_present
    end

    it 'returns Instance licenses when enabled' do
      stub_licensed_features(custom_file_templates: true, custom_file_templates_for_namespace: false)

      expect(Gitlab::Template::CustomLicenseTemplate)
        .to receive(:all)
        .with(project)
        .and_return([OpenStruct.new(key: 'name', name: 'Name', project_id: project.id)])

      expect(categories).to contain_exactly(:Popular, :Other, 'Instance')
      expect(by_instance).to contain_exactly({ id: 'name', name: 'Name', key: 'name', project_id: project.id })
      expect(by_popular).to be_present
      expect(by_other).to be_present
    end

    it 'returns no Group or Instance licenses when disabled' do
      stub_licensed_features(custom_file_templates: false, custom_file_templates_for_namespace: false)

      expect(categories).to contain_exactly(:Popular, :Other)
      expect(by_group).to be_nil
      expect(by_instance).to be_nil
      expect(by_popular).to be_present
      expect(by_other).to be_present
    end
  end

  describe '#vue_blob_header_app_data' do
    let(:blob) { fake_blob(path: 'file.md', size: 2.megabytes) }
    let(:project) { build_stubbed(:project) }
    let(:organization) { build_stubbed(:organization) }
    let(:ref) { 'main' }
    let(:breadcrumb_data) { { title: 'README.md', 'is-last': true } }

    it 'returns data related to blob header app' do
      Current.organization = organization
      allow(helper).to receive_messages(selected_branch: ref, current_user: nil,
        breadcrumb_data_attributes: breadcrumb_data,
        web_ide_button_data: {},
        fork_modal_options: {})

      expect(helper.vue_blob_header_app_data(project, blob, ref)).to include({
        new_workspace_path: new_remote_development_workspace_path,
        organization_id: organization.id
      })
    end
  end

  describe '#vue_blob_app_data' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:user) }
    let_it_be(:project) { create(:project) }
    let(:blob) { fake_blob(path: 'file.md', size: 2.megabytes) }
    let(:ref) { 'main' }
    let(:organization) { build_stubbed(:organization) }

    before_all do
      project.add_developer(user)
    end

    context 'with explain_code_available parameter' do
      context 'when current_user is nil' do
        before do
          Current.organization = organization
          allow(helper).to receive_messages(
            selected_branch: ref,
            current_user: nil
          )
        end

        it 'returns false for explain_code_available' do
          expect(helper.vue_blob_app_data(project, blob, ref)).to include(
            explain_code_available: 'false'
          )
        end
      end

      context 'when current_user is present' do
        before do
          Current.organization = organization
          stub_feature_flags(dap_external_trigger_usage_billing: flag_enabled)
          allow(helper).to receive_messages(
            selected_branch: ref,
            current_user: user
          )

          if flag_enabled
            allow(user).to receive(:allowed_to_use?).with(:duo_chat).and_return(has_duo_addon)
          else
            duo_chat_instance = instance_double(::Gitlab::Llm::DuoChat)
            allow(::Gitlab::Llm::DuoChat).to receive(:new)
              .with(user: user, container: project)
              .and_return(duo_chat_instance)
            allow(duo_chat_instance).to receive(:enabled_for_container?)
              .and_return(duo_chat_enabled)
          end
        end

        where(:flag_enabled, :has_duo_addon, :duo_chat_enabled, :expected_value) do
          true  | true  | nil   | 'true'
          true  | false | nil   | 'false'
          false | nil   | true  | 'true'
          false | nil   | false | 'false'
        end

        with_them do
          it 'returns correct explain_code_available value' do
            expect(helper.vue_blob_app_data(project, blob, ref)).to include(
              explain_code_available: expected_value
            )
          end
        end
      end
    end

    context 'with workspace data' do
      before do
        Current.organization = organization
        stub_feature_flags(dap_external_trigger_usage_billing: false)
        allow(helper).to receive_messages(
          selected_branch: ref,
          current_user: user
        )
        duo_chat_instance = instance_double(::Gitlab::Llm::DuoChat)
        allow(::Gitlab::Llm::DuoChat).to receive(:new)
          .with(user: user, container: project)
          .and_return(duo_chat_instance)
        allow(duo_chat_instance).to receive(:enabled_for_container?)
          .and_return(false)
      end

      it 'includes workspace-related attributes' do
        expect(helper.vue_blob_app_data(project, blob, ref)).to include(
          new_workspace_path: new_remote_development_workspace_path,
          organization_id: organization.id,
          explain_code_available: 'false'
        )
      end
    end
  end

  describe '#show_duo_workflow_action?' do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:project) { create(:project) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(project).to receive(:duo_features_enabled).and_return(true)
    end

    context 'when blob name is Jenkinsfile' do
      let(:blob) { fake_blob(path: 'Jenkinsfile') }

      before do
        blob.project.update!(duo_remote_flows_enabled: true)
      end

      it 'returns true when user is present' do
        expect(helper.show_duo_workflow_action?(blob)).to be true
      end

      it 'returns false when user is not present' do
        allow(helper).to receive(:current_user).and_return(nil)
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end

    context 'when blob name is not Jenkinsfile' do
      let(:blob) { fake_blob(path: 'not_jenkinsfile.rb') }

      before do
        blob.project.update!(duo_remote_flows_enabled: true)
      end

      it 'returns false even when user is present' do
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end

    context 'when blob.project is nil' do
      let(:blob) { fake_blob(path: 'Jenkinsfile') }

      before do
        allow(blob).to receive(:project).and_return(nil)
      end

      it 'returns false' do
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end

    context 'when duo_remote_flows_enabled settings is disabled' do
      let(:blob) { fake_blob(path: 'Jenkinsfile') }

      before do
        blob.project.update!(duo_remote_flows_enabled: false)
      end

      it 'returns false' do
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end

    context 'when duo_features_enabled settings is disabled' do
      let(:blob) { fake_blob(path: 'Jenkinsfile') }

      before do
        allow(project).to receive(:duo_features_enabled).and_return(false)
      end

      it 'returns false' do
        expect(helper.show_duo_workflow_action?(blob)).to be false
      end
    end
  end
end
