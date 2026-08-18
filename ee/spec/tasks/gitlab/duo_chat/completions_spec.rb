# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:duo_chat:completions', feature_category: :duo_chat do
  before do
    Rake.application.rake_require('tasks/gitlab/duo_chat/completions')
  end

  describe 'gitlab:duo_chat:completions task' do
    context 'when AIEF_DATASET variable is not defined' do
      it 'raises an error for missing' do
        expected_error_message = "Environment variable AIEF_DATASET not set"

        expect { run_rake_task('gitlab:duo_chat:completions', ['duochat', 1]) }
          .to raise_error(RuntimeError)
                .with_message(a_string_including(expected_error_message))
      end
    end

    context 'when AIEF_OUTPUT variable is not defined' do
      before do
        stub_env('AIEF_DATASET' => 'path')
      end

      it 'raises an error for missing' do
        expected_error_message = "Environment variable AIEF_OUTPUT not set"

        expect { run_rake_task('gitlab:duo_chat:completions', ['duochat', 1]) }
          .to raise_error(RuntimeError)
                .with_message(a_string_including(expected_error_message))
      end
    end

    context 'when envs are defined' do
      before do
        stub_env('AIEF_DATASET' => 'path_in')
        stub_env('AIEF_OUTPUT' => 'path_out')
      end

      context 'when group is not provided' do
        it 'raises an error' do
          expect do
            run_rake_task('gitlab:duo_chat:completions')
          end.to raise_error(RuntimeError, /Group not provided/)
        end
      end

      context 'when user is not provided' do
        it 'raises an error' do
          expect do
            run_rake_task('gitlab:duo_chat:completions', ['duochat', nil])
          end.to raise_error(RuntimeError, /User not provided/)
        end
      end

      context 'when environment is not local' do
        before do
          allow(::Gitlab).to receive(:dev_or_test_env?).and_return(false)
        end

        it 'raises an error' do
          expect do
            run_rake_task('gitlab:duo_chat:completions', ['duochat', nil])
          end.to raise_error(RuntimeError, /can be only ran locally/)
        end
      end

      context 'when user and group are defined' do
        let(:request) { instance_double(::Gitlab::Duo::Chat::Request) }
        let(:dataset_reader) { instance_double(::Gitlab::Duo::Chat::DatasetReader) }
        let(:dataset_writer) { instance_double(::Gitlab::Duo::Chat::DatasetWriter) }
        let(:progress_bar) { double }

        it 'calls proper classes' do
          expect(::Gitlab::Duo::Chat::Request).to receive(:new).with({ root_group_path: 'duochat', user_id: '1' })
                                                               .and_return(request)
          expect(::Gitlab::Duo::Chat::DatasetReader).to receive(:new).with('path_in')
                                                                     .and_return(dataset_reader)
          expect(::Gitlab::Duo::Chat::DatasetWriter).to receive(:new).with('path_out')
                                                                     .and_return(dataset_writer)
          expect(dataset_reader).to receive(:total_rows).and_return(1)
          expect(ProgressBar).to receive(:create).with(title: 'Getting completions', total: 1, format: '%t: |%B| %c/%C')
                                                 .and_return(progress_bar)

          expect(dataset_reader).to receive(:read).and_yield('something')
          expect(request).to receive(:completion).with('something').and_return({ 'completion' => 'completion' })
          expect(dataset_writer).to receive(:write).with({ 'completion' => 'completion' })
          expect(progress_bar).to receive(:increment)

          expect(dataset_writer).to receive(:close)
          expect(progress_bar).to receive(:finish)

          run_rake_task('gitlab:duo_chat:completions', ['duochat', 1])
        end

        it 'retries in case of error' do
          expect(::Gitlab::Duo::Chat::Request).to receive(:new).with({ root_group_path: 'duochat', user_id: '1' })
                                                               .and_return(request)
          expect(::Gitlab::Duo::Chat::DatasetReader).to receive(:new).with('path_in')
                                                                     .and_return(dataset_reader)
          expect(::Gitlab::Duo::Chat::DatasetWriter).to receive(:new).with('path_out')
                                                                     .and_return(dataset_writer)
          expect(dataset_reader).to receive(:total_rows).and_return(1)
          expect(ProgressBar).to receive(:create).with(title: 'Getting completions', total: 1, format: '%t: |%B| %c/%C')
                                                 .and_return(progress_bar)

          expect(dataset_reader).to receive(:read).and_yield('something')
          expect(request).to receive(:completion).with('something').and_raise(StandardError).once
          expect(request).to receive(:completion).with('something').and_return({ 'completion' => 'completion' }).once
          expect(dataset_writer).to receive(:write).with({ 'completion' => 'completion' })
          expect(progress_bar).to receive(:increment)

          expect(dataset_writer).to receive(:close)
          expect(progress_bar).to receive(:finish)

          run_rake_task('gitlab:duo_chat:completions', ['duochat', 1])
        end

        context 'when error limit set' do
          before do
            stub_env('ERROR_LIMIT' => 0)
          end

          it 'does not retry in case of error' do
            expect(::Gitlab::Duo::Chat::Request).to receive(:new).with({ root_group_path: 'duochat', user_id: '1' })
                                                                 .and_return(request)
            expect(::Gitlab::Duo::Chat::DatasetReader).to receive(:new).with('path_in')
                                                                       .and_return(dataset_reader)
            expect(::Gitlab::Duo::Chat::DatasetWriter).to receive(:new).with('path_out')
                                                                       .and_return(dataset_writer)
            expect(dataset_reader).to receive(:total_rows).and_return(1)
            expect(ProgressBar).to receive(:create)
              .with(title: 'Getting completions', total: 1, format: '%t: |%B| %c/%C')
              .and_return(progress_bar)
            expect(dataset_reader).to receive(:read).and_yield('something')
            expect(request).to receive(:completion).with('something').and_raise(StandardError).once

            expect(progress_bar).not_to receive(:increment)
            expect(dataset_writer).not_to receive(:write)

            expect(dataset_writer).to receive(:close)
            expect(progress_bar).to receive(:finish)

            run_rake_task('gitlab:duo_chat:completions', ['duochat', 1])
          end
        end

        context 'with real file' do
          let(:output_path) { '/tmp/dataset' }

          before do
            stub_env('AIEF_DATASET' => Rails.root.join('ee/spec/fixtures/duo_chat_fixtures'))
            stub_env('AIEF_OUTPUT' => output_path)
          end

          after do
            FileUtils.rm_rf(output_path)
          end

          it 'produces output file' do
            expect(::Gitlab::Duo::Chat::Request).to receive(:new).with({ root_group_path: 'duochat', user_id: '1' })
                                                                 .and_return(request)
            expect(request).to receive(:completion).and_return({ 'completion' => 'completion' }).twice
            allow(SecureRandom).to receive(:hex).and_return('abc123')

            run_rake_task('gitlab:duo_chat:completions', ['duochat', 1])

            expect(Dir["#{output_path}/*.jsonl"].first).to eq("#{output_path}/abc123.jsonl")
          end
        end
      end
    end
  end
end
