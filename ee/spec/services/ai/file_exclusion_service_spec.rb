# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::FileExclusionService, feature_category: :ai_abstraction_layer do
  let_it_be(:project) { create(:project) }

  let(:service) { described_class.new(project) }
  let(:file_paths) { ['app/models/user.rb'] }
  let(:exclusion_rules) { nil }

  before do
    if exclusion_rules.present?
      project.create_project_setting if project.project_setting.nil?
      project.project_setting.update!(duo_context_exclusion_settings: { exclusion_rules: exclusion_rules })
    end
  end

  describe '#execute' do
    subject(:execute_service) { service.execute(file_paths) }

    context 'with rules using exclamation point for includes' do
      let(:file_paths) { ['app/models/user.rb'] }

      context 'when using both include and exclude rules with exclamation point syntax' do
        let(:exclusion_rules) do
          [
            'app/*', # exclude everything in app/
            '!app/models/*.rb' # but include models
          ]
        end

        it 'returns success with excluded=false (include rule wins)' do
          expect(execute_service).to be_success
          expect(execute_service.payload[0][:excluded]).to be false
          expect(execute_service.payload[0][:path]).to eq(file_paths[0])
        end
      end
    end

    context 'when file path is nil' do
      let(:file_paths) { nil }

      it 'returns an error' do
        expect(execute_service).to be_error
        expect(execute_service.reason).to eq(:no_path_provided)
        expect(execute_service.message).to eq('File paths must be provided')
      end
    end

    context 'when file path is empty' do
      let(:file_paths) { [] }

      it 'returns an error' do
        expect(execute_service).to be_error
        expect(execute_service.reason).to eq(:no_path_provided)
        expect(execute_service.message).to eq('File paths must be provided')
      end
    end

    context 'with a valid file path' do
      context 'when no exclusion rules are defined' do
        it 'returns success with excluded=false' do
          expect(execute_service).to be_success
          expect(execute_service.payload[0][:excluded]).to be false
          expect(execute_service.payload[0][:path]).to eq(file_paths[0])
        end
      end

      context 'when exclusion rules are defined' do
        context 'with a single exclude rule that matches' do
          let(:exclusion_rules) do
            [
              'app/models/*.rb'
            ]
          end

          it 'returns success with excluded=true' do
            expect(execute_service).to be_success
            expect(execute_service.payload[0][:excluded]).to be true
            expect(execute_service.payload[0][:path]).to eq(file_paths[0])
          end
        end

        context 'with a single exclude rule that matches directory wildcard' do
          let(:exclusion_rules) do
            [
              'app/**/*.rb'
            ]
          end

          it 'returns success with excluded=true' do
            expect(execute_service).to be_success
            expect(execute_service.payload[0][:excluded]).to be true
            expect(execute_service.payload[0][:path]).to eq(file_paths[0])
          end
        end

        context 'with a single exclude rule that does not match' do
          let(:exclusion_rules) do
            [
              'app/controllers/*.rb'
            ]
          end

          it 'returns success with excluded=false' do
            expect(execute_service).to be_success
            expect(execute_service.payload[0][:excluded]).to be false
            expect(execute_service.payload[0][:path]).to eq(file_paths[0])
          end
        end

        context 'with multiple conflicting rules' do
          context 'when exclude rule comes after include rule' do
            let(:exclusion_rules) do
              [
                '!app/*',
                'app/models/*.rb'
              ]
            end

            it 'returns success with excluded=true (last rule wins)' do
              expect(execute_service).to be_success
              expect(execute_service.payload[0][:excluded]).to be true
              expect(execute_service.payload[0][:path]).to eq(file_paths[0])
            end
          end

          context 'when include rule comes after exclude rule' do
            let(:exclusion_rules) do
              [
                'app/models/*.rb',
                '!app/*'
              ]
            end

            it 'returns success with excluded=false (last rule wins)' do
              expect(execute_service).to be_success
              expect(execute_service.payload[0][:excluded]).to be false
              expect(execute_service.payload[0][:path]).to eq(file_paths[0])
            end
          end
        end

        context 'with various path patterns' do
          let(:exclusion_rules) do
            [
              'config/*.yml',
              'app/models/user.rb',
              'app/models/project.rb',
              'public/*'
            ]
          end

          context 'with an exactly matching path' do
            let(:file_paths) { ['app/models/user.rb'] }

            it 'returns success with excluded=true' do
              expect(execute_service).to be_success
              expect(execute_service.payload[0][:excluded]).to be true
            end
          end

          context 'with a path matching a wildcard' do
            let(:file_paths) { ['config/database.yml'] }

            it 'returns success with excluded=true' do
              expect(execute_service).to be_success
              expect(execute_service.payload[0][:excluded]).to be true
            end
          end

          context 'with a non-matching path' do
            let(:file_paths) { ['app/controllers/users_controller.rb'] }

            it 'returns success with excluded=false' do
              expect(execute_service).to be_success
              expect(execute_service.payload[0][:excluded]).to be false
            end
          end
        end
      end
    end

    context 'when path has a leading slash' do
      let(:file_paths) { ['/app/models/user.rb'] }
      let(:exclusion_rules) do
        [
          'app/models/*.rb'
        ]
      end

      it 'keeps the original path and returns success with excluded=true' do
        expect(execute_service).to be_success
        expect(execute_service.payload[0][:excluded]).to be true
        expect(execute_service.payload[0][:path]).to eq('/app/models/user.rb')
      end
    end

    context 'when file path contains invalid sequences' do
      let(:exclusion_rules) { ['*'] }

      context 'when path contains ../' do
        let(:file_paths) { ['../../../config/secrets.yml'] }

        it 'returns the original path as allowed' do
          expect(execute_service).to be_success
          expect(execute_service.payload[0][:excluded]).to be false
          expect(execute_service.payload[0][:path]).to eq('../../../config/secrets.yml')
        end
      end

      context 'when path contains backslashes' do
        let(:file_paths) { ['app\models\user.rb'] }

        it 'returns the original path as allowed' do
          expect(execute_service).to be_success
          expect(execute_service.payload[0][:excluded]).to be false
          expect(execute_service.payload[0][:path]).to eq('app\models\user.rb')
        end
      end

      context 'when path contains only whitespace' do
        let(:file_paths) { ['   ', "\t\n"] }

        it 'returns the original paths as allowed' do
          expect(execute_service).to be_success
          expect(execute_service.payload).to contain_exactly(
            { path: '   ', excluded: false },
            { path: "\t\n", excluded: false }
          )
        end
      end

      context 'when path contains control characters' do
        let(:file_paths) { ['app/models/user\u0000.rb', 'app/\u001Fmodels/user.rb'] }

        it 'returns the original paths as allowed' do
          expect(execute_service).to be_success
          expect(execute_service.payload).to contain_exactly(
            { path: 'app/models/user\u0000.rb', excluded: false },
            { path: 'app/\u001Fmodels/user.rb', excluded: false }
          )
        end
      end

      context 'when some paths are valid and some contain invalid characters' do
        let(:file_paths) { ['app/models/user.rb', 'app/models/user\u0000.rb', 'app\models\project.rb'] }
        let(:exclusion_rules) { ['app/models/*.rb'] }

        it 'returns results for all paths' do
          expect(execute_service).to be_success
          expect(execute_service.payload).to contain_exactly(
            { path: 'app/models/user.rb', excluded: true },
            { path: 'app/models/user\u0000.rb', excluded: false },
            { path: 'app\models\project.rb', excluded: false }
          )
        end
      end
    end

    context 'with multiple file paths' do
      let(:file_paths) { ['app/models/user.rb', 'app/controllers/users_controller.rb'] }
      let(:exclusion_rules) do
        [
          'app/models/*.rb'
        ]
      end

      it 'returns success with results for each path' do
        expect(execute_service).to be_success
        expect(execute_service.payload).to contain_exactly(
          { path: 'app/models/user.rb', excluded: true },
          { path: 'app/controllers/users_controller.rb', excluded: false }
        )
      end

      context 'when one path is invalid' do
        let(:file_paths) { ['app/models/user.rb', '../invalid/path.rb'] }
        let(:exclusion_rules) { ['app/models/*.rb'] }

        it 'returns success with results for all paths' do
          expect(execute_service).to be_success
          expect(execute_service.payload).to contain_exactly(
            { path: 'app/models/user.rb', excluded: true },
            { path: '../invalid/path.rb', excluded: false }
          )
        end
      end

      context 'when all paths contain invalid sequences' do
        let(:file_paths) { ['../invalid/path1.rb', '../invalid/path2.rb'] }

        it 'returns success with results for all paths' do
          expect(execute_service).to be_success
          expect(execute_service.payload).to contain_exactly(
            { path: '../invalid/path1.rb', excluded: false },
            { path: '../invalid/path2.rb', excluded: false }
          )
        end
      end
    end
  end
end
