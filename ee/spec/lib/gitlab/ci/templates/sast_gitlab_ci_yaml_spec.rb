# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SAST.gitlab-ci.yml', feature_category: :static_application_security_testing do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('SAST') }

  describe 'the created pipeline' do
    let_it_be(:default_branch) { 'master' }
    let_it_be(:feature_branch) { 'patch-1' }

    let(:pipeline) { service.execute(:push).payload }

    before do
      stub_ci_pipeline_yaml_file(template.content)
    end

    context 'when project has no license' do
      using RSpec::Parameterized::TableSyntax

      where(:case_name, :files, :variables, :jobs) do
        # rubocop:disable Layout/LineLength -- TableSyntax
        'Apex'                 | ['app.cls']                           | {}                                               | %w[pmd-apex-sast]
        'C'                    | ['app.c']                             | {}                                               | %w[semgrep-sast]
        'C++'                  | ['app.cpp']                           | {}                                               | %w[semgrep-sast]
        'C'                    | ['app.c']                             | { 'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'true' } | %w[semgrep-sast]
        'C++'                  | ['app.cpp']                           | { 'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'true' } | %w[semgrep-sast]
        'C#'                   | ['app.cs']                            | {}                                               | %w[semgrep-sast]
        'Elixir'               | ['mix.exs']                           | {}                                               | %w[sobelow-sast]
        'Elixir, nested'       | ['a/b/mix.exs']                       | {}                                               | %w[sobelow-sast]
        'Golang'               | ['main.go']                           | {}                                               | %w[semgrep-sast]
        'Groovy'               | ['app.groovy']                        | {}                                               | %w[spotbugs-sast]
        'Java'                 | ['app.java']                          | {}                                               | %w[semgrep-sast]
        'Java properties'      | ['app.properties']                    | {}                                               | %w[semgrep-sast]
        'Javascript'           | ['app.js']                            | {}                                               | %w[semgrep-sast]
        'JSP'                  | ['app.jsp']                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }     | []
        'JSX'                  | ['app.jsx']                           | {}                                               | %w[semgrep-sast]
        'Kotlin'               | ['app.kt']                            | {}                                               | %w[semgrep-sast]
        'Kubernetes Manifests' | ['Chart.yaml']                        | { 'SCAN_KUBERNETES_MANIFESTS' => 'true' }        | %w[kubesec-sast]
        'Multiple languages'   | ['app.java', 'app.js']                | {}                                               | %w[semgrep-sast]
        'Objective C'          | ['app.m']                             | {}                                               | %w[semgrep-sast]
        'PHP'                  | ['app.php']                           | {}                                               | %w[semgrep-sast]
        'Python'               | ['app.py']                            | {}                                               | %w[semgrep-sast]
        'Ruby'                 | ['config/routes.rb']                  | {}                                               | %w[semgrep-sast]
        'Scala'                | ['app.scala']                         | {}                                               | %w[semgrep-sast]
        'Scala'                | ['app.sc']                            | {}                                               | %w[semgrep-sast]
        'Swift'                | ['app.swift']                         | {}                                               | %w[semgrep-sast]
        'Typescript'           | ['app.ts']                            | {}                                               | %w[semgrep-sast]
        'Typescript JSX'       | ['app.tsx']                           | {}                                               | %w[semgrep-sast]
        # rubocop:enable Layout/LineLength
      end

      with_them do
        include_context 'when project has files', params[:files]
        include_context 'with CI variables', params[:variables]

        context 'as a branch pipeline on the default branch' do
          include_context 'with default branch pipeline setup'

          include_examples 'has expected jobs', params[:jobs]
        end

        context 'as a branch pipeline on a feature branch' do
          include_context 'with feature branch pipeline setup'

          include_examples 'has expected jobs', params[:jobs]
        end

        context 'as an MR pipeline' do
          include_context 'with MR pipeline setup'

          include_examples 'has expected jobs', []

          context 'when AST_ENABLE_MR_PIPELINES=true' do
            include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'true' }

            include_examples 'has expected jobs', params[:jobs]
          end
        end
      end
    end

    context 'when project has Ultimate license' do
      let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      describe "SAST_EXCLUDED_ANALYZERS" do
        using RSpec::Parameterized::TableSyntax
        # Add necessary files and CI variables to enable all analyzers jobs
        include_context 'when project has files', %w[app.groovy mix.exs app.c app.cls app.go]
        include_context 'with CI variables', {
          'SCAN_KUBERNETES_MANIFESTS' => 'true',
          'GITLAB_ADVANCED_SAST_ENABLED' => 'true',
          'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'true'
        }
        include_context 'with default branch pipeline setup'

        where(:case_name, :excluded_analyzers, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'default'                  | []                         | %w[spotbugs-sast sobelow-sast semgrep-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          'spotbugs'                 | 'spotbugs'                 | %w[sobelow-sast semgrep-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          'sobelow'                  | 'sobelow'                  | %w[spotbugs-sast semgrep-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          'semgrep'                  | 'semgrep'                  | %w[spotbugs-sast sobelow-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          'pmd-apex'                 | 'pmd-apex'                 | %w[spotbugs-sast sobelow-sast semgrep-sast kubesec-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          'kubesec'                  | 'kubesec'                  | %w[spotbugs-sast sobelow-sast semgrep-sast pmd-apex-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          'gitlab-advanced-sast'     | 'gitlab-advanced-sast'     | %w[spotbugs-sast sobelow-sast semgrep-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast-cpp]
          'gitlab-advanced-sast-cpp' | 'gitlab-advanced-sast-cpp' | %w[spotbugs-sast sobelow-sast semgrep-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast]
          'multiple analyzers'       | 'spotbugs, semgrep'        | %w[sobelow-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast gitlab-advanced-sast-cpp]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          include_context 'with CI variables', { 'SAST_EXCLUDED_ANALYZERS' => params[:excluded_analyzers] }

          include_examples 'has expected jobs', params[:jobs]
        end
      end

      describe "SAST_DISABLED" do
        # Add necessary files and CI variables to enable all analyzers jobs
        include_context 'when project has files', %w[app.groovy mix.exs app.c app.cls app.go]
        include_context 'with CI variables', {
          'SCAN_KUBERNETES_MANIFESTS' => 'true',
          'GITLAB_ADVANCED_SAST_ENABLED' => 'true',
          'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'true'
        }
        include_context 'with default branch pipeline setup'

        include_examples 'has jobs that can be disabled', 'SAST_DISABLED', %w[true 1],
          %w[spotbugs-sast sobelow-sast semgrep-sast pmd-apex-sast kubesec-sast gitlab-advanced-sast
            gitlab-advanced-sast-cpp]
      end

      context "with project type" do
        using RSpec::Parameterized::TableSyntax

        where(:case_name, :files, :variables, :jobs) do
          # rubocop:disable Layout/LineLength -- TableSyntax
          'Python with advanced SAST'                      | ['app.py']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Golang with advanced SAST'                      | ['main.go']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Java with advanced SAST'                        | ['app.java']                   | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'JSP with advanced SAST'                         | ['app.jsp']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Javascript with advanced SAST'                  | ['app.js']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'JSX with advanced SAST'                         | ['app.jsx']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Typescript with advanced SAST'                  | ['app.ts']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Typescript JSX with advanced SAST'              | ['app.tsx']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'CommonJavascript with advanced SAST'            | ['app.cjs']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'ECMAScript Modules with advanced SAST'          | ['app.mjs']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'C# with advanced SAST'                          | ['app.cs']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Ruby with advanced SAST'                        | ['config/routes.rb']           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'PHP with advanced SAST'                         | ['app.php']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'C with advanced SAST'                           | ['app.c']                      | { 'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'true' }  | %w[semgrep-sast gitlab-advanced-sast-cpp]
          'C++ with advanced SAST'                         | ['app.cpp']                    | { 'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'true' }  | %w[semgrep-sast gitlab-advanced-sast-cpp]
          'Python and Ruby with advanced SAST'             | ['app.py', 'config/routes.rb'] | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast]
          'Python and Objective C with advanced SAST'      | ['app.py', 'app.m']            | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }      | %w[gitlab-advanced-sast gitlab-advanced-sast-ext semgrep-sast]
          'Python without advanced SAST'                   | ['app.py']                     | {}                                                | %w[semgrep-sast]
          'Python with disabled advanced SAST'             | ['app.py']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'Golang with disabled advanced SAST'             | ['main.go']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'Java with disabled advanced SAST'               | ['app.java']                   | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'JSP with disabled advanced SAST'                | ['app.jsp']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | []
          'Javascript with disabled advanced SAST'         | ['app.js']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'JSX with disabled advanced SAST'                | ['app.jsx']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'Typescript with disabled advanced SAST'         | ['app.ts']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'Typescript JSX with disabled advanced SAST'     | ['app.tsx']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'CommonJavascript with disabled advanced SAST'   | ['app.cjs']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'ECMAScript Modules with disabled advanced SAST' | ['app.mjs']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'C# with disabled advanced SAST'                 | ['app.cs']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'Ruby with disabled advanced SAST'               | ['config/routes.rb']           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'PHP with disabled advanced SAST'                | ['app.php']                    | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }     | %w[semgrep-sast]
          'C with disabled advanced SAST'                  | ['app.c']                      | { 'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'false' } | %w[semgrep-sast]
          'C++ with disabled advanced SAST'                | ['app.cpp']                    | { 'GITLAB_ADVANCED_SAST_CPP_ENABLED' => 'false' } | %w[semgrep-sast]
          'Swift with advanced SAST ext'                   | ['app.swift']                  | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }  | %w[semgrep-sast gitlab-advanced-sast-ext]
          'Objective C with advanced SAST ext'             | ['app.m']                      | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }  | %w[semgrep-sast gitlab-advanced-sast-ext]
          'Objective-C++ with advanced SAST ext'           | ['app.mm']                     | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }  | %w[gitlab-advanced-sast-ext]
          'Swift with disabled advanced SAST ext'          | ['app.swift']                  | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' } | %w[semgrep-sast]
          # rubocop:enable Layout/LineLength
        end

        with_them do
          include_context 'when project has files', params[:files]
          include_context 'with CI variables', params[:variables]

          context 'as a branch pipeline on the default branch' do
            include_context 'with default branch pipeline setup'

            include_examples 'has expected jobs', params[:jobs]

            context 'when both gitlab-advanced-sast and semgrep-sast run',
              if: params[:jobs].include?('gitlab-advanced-sast') && params[:jobs].include?('semgrep-sast') do
              it 'excludes already-covered extensions' do
                gitlab_advanced_sast_extensions = %w[.py .go .java .js .jsx .ts .tsx .cjs .mjs .cs]

                # expect the variable SAST_EXCLUDED_PATHS of semgrep-sast to contain the list
                # of extensions supported by gitlab-advanced-sast
                variables = pipeline.builds.find_by(name: 'semgrep-sast').variables
                sast_excluded_paths = variables.find { |v| v.key == 'SAST_EXCLUDED_PATHS' }.value
                gitlab_advanced_sast_extensions.each do |ext|
                  expect(sast_excluded_paths).to include("**/*#{ext}")
                end
              end
            end
          end

          context 'as a branch pipeline on a feature branch' do
            include_context 'with feature branch pipeline setup'

            include_examples 'has expected jobs', params[:jobs]
          end

          context 'as an MR pipeline' do
            include_context 'with MR pipeline setup'

            include_examples 'has expected jobs', []

            context 'when AST_ENABLE_MR_PIPELINES=true' do
              include_context 'with CI variables', { 'AST_ENABLE_MR_PIPELINES' => 'true' }

              include_examples 'has expected jobs', params[:jobs]
            end
          end
        end
      end
    end
  end
end
