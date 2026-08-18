# frozen_string_literal: true

require "spec_helper"

RSpec.describe Resolvers::Ai::Chat::ContextPresetsResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:current_user) { project.owner }
  let_it_be(:issue) { create(:issue, project: project) }

  describe "#resolve" do
    subject(:resolver) do
      resolve(
        described_class,
        obj: nil,
        args: args,
        ctx: { current_user: current_user },
        field_opts: { calls_gitaly: true }
      )
    end

    context "with set number of questions" do
      let(:args) { { question_count: 2 } }

      it "returns required amount of questions" do
        expect(resolver[:questions].size).to eq(2)
      end
    end

    context "with specified resource" do
      let(:args) { { resource_id: resource_id, project_id: project_id } }
      let(:resource_id) { GitlabSchema.id_from_object(issue) }

      before do
        allow(Ability).to receive(:allowed?).and_return(true)
      end

      context "with specified project id" do
        let(:project_id) { GitlabSchema.id_from_object(project) }

        it "founds AI resource and passes it to the question service" do
          expect(::Gitlab::Duo::Chat::DefaultQuestions).to receive(:new)
            .with(anything, hash_including(resource: kind_of(Ai::AiResource::Issue)))
            .and_call_original

          expect(resolver[:ai_resource_data]).to match(/id.+#{issue.id}/)
        end
      end

      context "without specified resource id" do
        let(:resource_id) { nil }
        let(:project_id) { GitlabSchema.id_from_object(project) }

        it "does not pass an AI resource" do
          expect(::Gitlab::Duo::Chat::DefaultQuestions).to receive(:new)
            .with(anything, hash_including(resource: nil))
            .and_call_original

          expect(resolver[:ai_resource_data]).to be_nil
        end
      end

      context 'when user is missing' do
        let(:project_id) { GitlabSchema.id_from_object(project) }
        let(:current_user) { nil }

        it "does not pass an AI resource" do
          expect(resolver[:ai_resource_data]).to be_nil
        end
      end

      context "with commit resource" do
        let(:project_id) { GitlabSchema.id_from_object(project) }
        let(:commit) { project.repository.commit }
        let(:resource_id) { GitlabSchema.id_from_object(commit) }

        it "founds AI resource and passes it to the question service" do
          expect(::Gitlab::Duo::Chat::DefaultQuestions).to receive(:new)
            .with(anything, hash_including(resource: kind_of(Ai::AiResource::Commit)))
            .and_call_original

          expect(resolver[:ai_resource_data]).to match(/id.+#{commit.id}/)
        end
      end

      context "with not AI resource" do
        let(:not_supported_resource) { create(:vulnerability, project: project) }
        let(:resource_id) { GitlabSchema.id_from_object(not_supported_resource) }
        let(:project_id) { GitlabSchema.id_from_object(project) }

        it "does not pass the resource" do
          expect(::Gitlab::Duo::Chat::DefaultQuestions).to receive(:new)
            .with(anything, hash_including(resource: nil))
            .and_call_original

          expect(resolver[:ai_resource_data]).to be_nil
        end
      end
    end
  end
end
