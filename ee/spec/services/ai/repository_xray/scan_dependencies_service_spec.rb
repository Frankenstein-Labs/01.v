# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::RepositoryXray::ScanDependenciesService, feature_category: :code_suggestions do
  let_it_be(:valid_files) do
    {
      'a.txt' => 'foo',
      'Gemfile.lock' =>
        <<~CONTENT,
          GEM
            remote: https://rubygems.org/
            specs:
              bcrypt (3.1.20)
        CONTENT
      'dir1/dir2/go.mod' =>
        <<~CONTENT
          require abc.org/mylib v1.3.0
          require golang.org/x/mod v0.5.0
          require github.com/pmezard/go-difflib v1.0.0 // indirect
        CONTENT
    }
  end

  let(:expected_reports_array) do
    [
      {
        'project_id' => project.id,
        'lang' => 'ruby',
        'payload' => a_hash_including(
          'file_paths' => ['Gemfile.lock'],
          'libs' => [{ 'name' => 'bcrypt (3.1.20)' }])
      },
      {
        'project_id' => project.id,
        'lang' => 'go',
        'payload' => a_hash_including(
          'file_paths' => ['dir1/dir2/go.mod'],
          'libs' => contain_exactly({ 'name' => 'abc.org/mylib (1.3.0)' }, { 'name' => 'golang.org/x/mod (0.5.0)' }))
      }
    ]
  end

  subject(:execute) { described_class.new(project).execute }

  describe '#execute' do
    context 'when the repository does not contain a dependency config file' do
      let_it_be(:project) do
        create(:project, :custom_repo, files:
          {
            'a.txt' => 'foo',
            'dir1/b.rb' => 'bar'
          })
      end

      it 'returns a success response' do
        expect(execute).to be_success
        expect(execute.message).to eq('No dependency config files found')
        expect(execute.payload).to be_empty
      end
    end

    context 'when the repository contains only valid dependency config files' do
      let_it_be(:project) { create(:project, :custom_repo, files: valid_files) }

      it 'saves an X-Ray report for each valid config file' do
        expect { execute }.to change { report_count }.by(2)
        expect(reports_array).to contain_exactly(*expected_reports_array)
      end

      it 'returns a success response' do
        expect(execute).to be_success
        expect(execute.message).to eq('Found 2 dependency config files')
        expect(execute.payload).to match({
          success_messages: contain_exactly(
            'Found 1 dependencies in `Gemfile.lock` (RubyGemsLock)',
            'Found 2 dependencies in `dir1/dir2/go.mod` (GoModules)'),
          error_messages: [],
          max_dependency_count: 2
        })
      end

      context 'when there is an existing X-Ray report for a language' do
        it 'overwrites the existing X-Ray report' do
          create(:xray_report, project: project, lang: 'ruby', payload: { libs: [{ name: 'test-lib' }] })

          expect(reports_array).to contain_exactly({
            'project_id' => project.id,
            'lang' => 'ruby',
            'payload' => a_hash_including('libs' => [{ 'name' => 'test-lib' }])
          })

          expect { execute }.to change { report_count }.by(1)
          expect(reports_array).to contain_exactly(*expected_reports_array)
        end
      end

      context 'when there are multiple config file objects for the same language' do
        let_it_be(:project) do
          create(:project, :custom_repo, files:
            valid_files.merge({
              'requirements.txt' =>
                <<~CONTENT,
                  requests>=2.0,<3.0
                  numpy==1.26.4
                CONTENT
              'dir1/dev-requirements.txt' =>
                <<~CONTENT
                  python_dateutil>=2.5.3
                  fastapi-health!=0.3.0
                CONTENT
            }))
        end

        it 'merges the payloads and saves only one X-Ray report for each language' do
          expect { execute }.to change { report_count }.by(3)
          expect(reports_array).to contain_exactly(
            *expected_reports_array,
            {
              'project_id' => project.id,
              'lang' => 'python',
              'payload' => a_hash_including(
                'file_paths' => contain_exactly('requirements.txt', 'dir1/dev-requirements.txt'),
                'libs' => contain_exactly(
                  { 'name' => 'requests (>=2.0,<3.0)' },
                  { 'name' => 'numpy (==1.26.4)' },
                  { 'name' => 'python_dateutil (>=2.5.3)' },
                  { 'name' => 'fastapi-health (!=0.3.0)' }))
            })
        end

        it 'returns a success response' do
          expect(execute).to be_success
          expect(execute.message).to eq('Found 4 dependency config files')
          expect(execute.payload).to match({
            success_messages: contain_exactly(
              'Found 1 dependencies in `Gemfile.lock` (RubyGemsLock)',
              'Found 2 dependencies in `dir1/dir2/go.mod` (GoModules)',
              'Found 2 dependencies in `requirements.txt` (PythonPip)',
              'Found 2 dependencies in `dir1/dev-requirements.txt` (PythonPip)'),
            error_messages: [],
            max_dependency_count: 2
          })
        end
      end

      context 'when a dependency name contains an invalid byte sequence' do
        let_it_be(:invalid_unicode) { [0xFE, 0x00, 0x00, 0x00].pack('C*') }
        let_it_be(:project) do
          create(:project, :custom_repo, files:
            valid_files.merge({
              'requirements.txt' =>
                <<~CONTENT
                  r#{invalid_unicode}equests>=2.0,<3.0
                  numpy==1.26.4
                CONTENT
            }))
        end

        it 'saves an X-Ray report for each valid config file' do
          expect { execute }.to change { report_count }.by(3)
          expect(reports_array).to contain_exactly(
            *expected_reports_array,
            {
              'project_id' => project.id,
              'lang' => 'python',
              'payload' => a_hash_including(
                'file_paths' => contain_exactly('requirements.txt'),
                'libs' => contain_exactly(
                  { 'name' => 'requests (>=2.0,<3.0)' },
                  { 'name' => 'numpy (==1.26.4)' }))
            })
        end

        it 'returns a success response' do
          expect(execute).to be_success
          expect(execute.message).to eq('Found 3 dependency config files')
          expect(execute.payload).to match({
            success_messages: contain_exactly(
              'Found 1 dependencies in `Gemfile.lock` (RubyGemsLock)',
              'Found 2 dependencies in `dir1/dir2/go.mod` (GoModules)',
              'Found 2 dependencies in `requirements.txt` (PythonPip)'),
            error_messages: [],
            max_dependency_count: 2
          })
        end
      end
    end

    context 'when the repository contains only invalid dependency config files' do
      let_it_be(:project) { create(:project, :custom_repo, files: { 'go.mod' => 'invalid content' }) }

      it 'does not save an X-Ray report' do
        expect { execute }.not_to change { report_count }
      end

      it 'returns an error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Found 1 dependency config files, 1 had errors')
        expect(execute.payload).to match({
          success_messages: [],
          error_messages: [
            'Error while parsing file `go.mod`: unexpected format or dependencies not present (GoModules)'
          ],
          max_dependency_count: 0
        })
      end
    end

    context 'when the repository contains both valid and invalid dependency config files' do
      let_it_be(:project) { create(:project, :custom_repo, files: valid_files.merge('dir1/pom.xml' => '')) }

      it 'saves an X-Ray report for each valid config file' do
        expect { execute }.to change { report_count }.by(2)
        expect(reports_array).to contain_exactly(*expected_reports_array)
      end

      it 'returns an error response' do
        expect(execute).to be_error
        expect(execute.message).to eq('Found 3 dependency config files, 1 had errors')
        expect(execute.payload).to match({
          success_messages: contain_exactly(
            'Found 1 dependencies in `Gemfile.lock` (RubyGemsLock)',
            'Found 2 dependencies in `dir1/dir2/go.mod` (GoModules)'),
          error_messages: ['Error while parsing file `dir1/pom.xml`: file empty (JavaMaven)'],
          max_dependency_count: 2
        })
      end
    end

    context 'when another instance is running with the same lease key' do
      let(:project) { instance_double(Project, id: 123) }
      let(:lease_key) { "#{described_class.name}:project_#{project.id}" }

      it 'returns an error response and reschedules the worker', :freeze_time do
        lease = Gitlab::ExclusiveLease.new(lease_key, timeout: 1.minute).tap(&:try_obtain)

        expect(Ai::RepositoryXray::ScanDependenciesWorker).to receive(:perform_in).once
        expect(execute).to be_error
        expect(execute.message).to match(/Lease taken. Rescheduled worker/)
        expect(execute.payload).to eq({ lease_key: lease_key })
        lease.cancel
      end
    end
  end

  private

  def report_count
    Projects::XrayReport.count
  end

  def reports_array
    Projects::XrayReport.all.map do |report|
      report.slice('project_id', 'lang', 'payload')
    end
  end
end
