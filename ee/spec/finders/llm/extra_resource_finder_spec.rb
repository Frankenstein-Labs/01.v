# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::ExtraResourceFinder, :saas, feature_category: :duo_chat do
  let_it_be(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let(:current_user) { developer }
  let(:blob_url) { Gitlab::Routing.url_helpers.project_blob_url(project, project.default_branch) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:other_project) { create(:project, :repository) }
  let_it_be(:developer) { create(:user, developer_of: project) }
  let_it_be(:other_developer) { create(:user, developer_of: other_project) }
  let_it_be(:guest) { create(:user, guest_of: project) }
  let_it_be(:issue) { create(:issue, project: project) }

  include_context 'with duo features enabled and ai chat available for group on SaaS'

  describe '.execute' do
    subject(:execute) { described_class.new(current_user, referer_url).execute }

    context 'with an invalid or non-resource referer_url' do
      where(:referer_url) do
        [
          [nil],
          [''],
          ['foo'],
          [Gitlab.config.gitlab.base_url],
          [lazy { "#{blob_url}/?" }]
        ]
      end

      with_them do
        it 'returns an empty hash' do
          expect(execute).to be_empty
        end
      end
    end

    context 'when referer_url references a resource other than Blob' do
      let(:referer_url) { ::Gitlab::Routing.url_helpers.project_issue_url(project, issue.id) }

      it 'returns an empty hash' do
        expect(execute).to be_empty
      end
    end

    context 'when referer_url references a Blob' do
      let(:referer_url) { "#{blob_url}/#{path}" }

      context 'when referer_url references a valid blob' do
        let(:path) { 'files/ruby/popen.rb' }

        context 'when the blob is a readable text' do
          let(:expected_blob) { project.repository.blob_at(project.default_branch, path) }

          it 'returns the blob' do
            expect(expected_blob).not_to be_nil
            expect(execute[:blob].id).to eq(expected_blob.id)
          end

          context "when user is not authorized to read code for the blob's project" do
            context 'when user is a guest' do
              let(:current_user) { guest }

              it 'returns an empty hash' do
                expect(execute).to be_empty
              end
            end

            context 'when user does not have any access' do
              let(:current_user) { other_developer }

              it 'returns an empty hash' do
                expect(execute).to be_empty
              end
            end
          end

          context 'when project is in group that does not allow experiment features' do
            include_context 'with experiment features disabled for group'
            let(:expected_blob) { project.repository.blob_at(project.default_branch, path) }

            it 'returns the blob' do
              expect(expected_blob).not_to be_nil
              expect(execute[:blob].id).to eq(expected_blob.id)
            end

            context 'with duo features disabled for project' do
              before do
                project.update!(duo_features_enabled: false)
              end

              it 'returns an empty hash' do
                expect(execute).to be_empty
              end
            end
          end
        end

        context 'when the blob is not a readable text' do
          let(:non_readable_blob) { project.repository.blob_at(project.default_branch, path) }
          let(:path) { 'Gemfile.zip' }

          it 'returns an empty hash' do
            expect(non_readable_blob).not_to be_nil
            expect(execute).to be_empty
          end
        end

        context 'when the blob is truncated' do
          let(:path) { 'files/ruby/popen.rb' }

          before do
            allow_next_instance_of(Blob) do |blob|
              allow(blob).to receive(:truncated?).and_return(true)
            end
          end

          it 'returns an empty hash' do
            expect(execute).to be_empty
          end
        end
      end

      context 'when referer_url references a non-existing blob' do
        let(:path) { 'foobar.rb' }

        it 'returns an empty hash' do
          expect(execute).to be_empty
        end
      end
    end
  end
end
