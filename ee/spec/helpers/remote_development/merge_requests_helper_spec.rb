# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RemoteDevelopment::MergeRequestsHelper, feature_category: :workspaces do
  let(:project_path) { 'group/project' }
  let(:ref) { 'main' }

  describe '#new_workspace_path' do
    context 'when project_path and ref are provided' do
      it 'returns the correct path with escaped parameters' do
        # noinspection SpellCheckingInspection
        expected_path = "/-/remote_development/workspaces/new?project=group%2Fproject&gitRef=main"

        expect(helper.workspace_path_with_params(project_path: project_path, ref: ref)).to eq(expected_path)
      end
    end

    describe 'parameter validation' do
      using RSpec::Parameterized::TableSyntax

      where(:case_name, :project_path, :ref) do
        'when project_path is nil'  | nil    | 'main'
        'when ref is nil'           | 'a/b'  | nil
        'when both are nil'         | nil    | nil
      end

      with_them do
        it 'raises RuntimeError' do
          expect do
            helper.workspace_path_with_params(project_path: project_path, ref: ref)
          end.to raise_error(RuntimeError)
        end
      end
    end
  end
end
