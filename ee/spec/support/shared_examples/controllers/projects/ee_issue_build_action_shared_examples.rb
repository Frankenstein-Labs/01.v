# frozen_string_literal: true

RSpec.shared_examples 'EE: issue building actions' do |assigned_name: :issue|
  describe 'GET #new' do
    render_views

    before do
      project.add_developer(user)
      sign_in(user)
    end

    context 'when passing observability metrics' do
      # rubocop: disable Layout/LineLength -- fixed long string
      let(:metric_params) do
        '%7B%22fullUrl%22%3A%22http%3A%2F%2Fgdk.test%3A3443%2Fflightjs%2FFlight%2F-%2Fmetrics%2Fapp.ads.ad_requests%3Ftype%3DSum%26date_range%3Dcustom%26date_start%3D2024-08-14T16%253A02%253A49.400Z%26date_end%3D2024-08-14T17%253A02%253A49.400Z%22%2C%22name%22%3A%22app.ads.ad_requests%22%2C%22type%22%3A%22Sum%22%2C%22timeframe%22%3A%5B%22Wed%2C%2014%20Aug%202024%2016%3A02%3A49%20GMT%22%2C%22Wed%2C%2014%20Aug%202024%2017%3A02%3A49%20GMT%22%5D%7D'
      end
      # rubocop: enable Layout/LineLength

      subject(:get_new) do
        get :new, params: {
          namespace_id: project.namespace,
          project_id: project,
          observability_metric_details: metric_params
        }
      end

      context 'when read_observability is prevented' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        context 'when observability_metric_details parameters exist' do
          it 'does not populate observability_values' do
            get_new

            expect(assigns(:observability_values)).to be_nil
          end
        end

        context 'when observability_metric_details parameters do not exist' do
          let(:metric_params) { {} }

          it 'does not populate observability_values' do
            get_new

            expect(assigns(:observability_values)).to be_nil
          end
        end
      end

      context 'when read_observability is allowed' do
        before do
          stub_licensed_features(observability: true)
        end

        context 'when observability_metric_details parameters exist' do
          it 'does prefill the issue title and description' do
            get_new

            expect(assigns(assigned_name).title).to eq('Issue created from app.ads.ad_requests')
            expect(assigns(assigned_name).description).to eq(
              <<~TEXT
                [Metric details](http://gdk.test:3443/flightjs/Flight/-/metrics/app.ads.ad_requests?type=Sum&date_range=custom&date_start=2024-08-14T16%3A02%3A49.400Z&date_end=2024-08-14T17%3A02%3A49.400Z) \\
                Name: `app.ads.ad_requests` \\
                Type: `Sum` \\
                Timeframe: `Wed, 14 Aug 2024 16:02:49 GMT - Wed, 14 Aug 2024 17:02:49 GMT`
              TEXT
            )
          end
        end

        context 'when observability_metric_details parameters do not exist' do
          let(:metric_params) { {} }

          it 'does not prefill the issue title and description' do
            get_new

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end
      end
    end

    context 'when passing observability logs' do
      # rubocop: disable Layout/LineLength -- long string required
      let(:log_params) do
        '%7B"body"%3A"Consumed%20record%20with%20orderId%3A%200522613b-3a15-11ef-85dd-0242ac120016%2C%20and%20updated%20total%20count%20to%3A%201353"%2C"fingerprint"%3A"8d6c44aebc683e3c"%2C"fullUrl"%3A"http%3A%2F%2Fgdk.test%3A3443%2Fflightjs%2FFlight%2F-%2Flogs%3Fsearch%3D%26service%5B%5D%3Dfrauddetectionservice%26severityNumber%5B%5D%3D9%26traceId%5B%5D%3D72b72def-09b3-e29f-e195-7c6db5ee599f%26fingerprint%5B%5D%3D8d6c44aebc683e3c%26timestamp%3D2024-07-04T14%253A52%253A22.693752628Z%26drawerOpen%3Dtrue"%2C"service"%3A"frauddetectionservice"%2C"severityNumber"%3A9%2C"timestamp"%3A"2024-07-04T14%3A52%3A22.693752628Z"%2C"traceId"%3A"72b72def-09b3-e29f-e195-7c6db5ee599f"%7D'
      end
      # rubocop: enable Layout/LineLength

      subject do
        get :new, params: {
          namespace_id: project.namespace,
          project_id: project,
          observability_log_details: log_params
        }
      end

      context 'when read_observability is prevented' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        context 'when observability_log_details parameters exist' do
          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end

        context 'when observability_log_details parameters do not exist' do
          let(:log_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end
      end

      context 'when read_observability is allowed' do
        before do
          stub_licensed_features(observability: true)
        end

        context 'when observability_log_details parameters exist' do
          it 'does prefill the issue title and description' do
            subject

            expect(assigns(:observability_values)).to eq({
              log: {
                service: 'frauddetectionservice',
                severityNumber: 9,
                fingerprint: '8d6c44aebc683e3c',
                timestamp: '2024-07-04T14:52:22.693752628Z',
                traceId: '72b72def-09b3-e29f-e195-7c6db5ee599f'
              }
            })
            expect(assigns(assigned_name).title).to eq(
              "Issue created from log of 'frauddetectionservice' service at 2024-07-04T14:52:22.693752628Z"
            )
            expect(assigns(assigned_name).description).to eq(
              <<~TEXT
                [Log details](http://gdk.test:3443/flightjs/Flight/-/logs?search=&service[]=frauddetectionservice&severityNumber[]=9&traceId[]=72b72def-09b3-e29f-e195-7c6db5ee599f&fingerprint[]=8d6c44aebc683e3c&timestamp=2024-07-04T14%3A52%3A22.693752628Z&drawerOpen=true) \\
                Service: `frauddetectionservice` \\
                Trace ID: `72b72def-09b3-e29f-e195-7c6db5ee599f` \\
                Log Fingerprint: `8d6c44aebc683e3c` \\
                Severity Number: `9` \\
                Timestamp: `2024-07-04T14:52:22.693752628Z` \\
                Message:
                ```
                Consumed record with orderId: 0522613b-3a15-11ef-85dd-0242ac120016, and updated total count to: 1353
                ```
              TEXT
            )
          end
        end

        context 'when observability_log_details parameters do not exist' do
          let(:log_params) { {} }

          it 'does not populate observability_values' do
            subject

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            subject

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end
      end
    end

    context 'when passing observability tracing' do
      # rubocop: disable Layout/LineLength -- fixed long string
      let(:tracing_params) do
        '%7B%22fullUrl%22%3A%22http%3A%2F%2Fgdk.test%3A3443%2Fflightjs%2FFlight%2F-%2Ftracing%2Fcd4cfff9-295b-f014-595c-1be1fc145822%22%2C%22name%22%3A%22frontend-proxy%20%3A%20ingress%22%2C%22traceId%22%3A%228335ed4c-c943-aeaa-7851-2b9af6c5d3b8%22%2C%22start%22%3A%22Thu%2C%2004%20Jul%202024%2014%3A44%3A21%20GMT%22%2C%22duration%22%3A%222.27ms%22%2C%22totalSpans%22%3A3%2C%22totalErrors%22%3A0%7D'
      end
      # rubocop: enable Layout/LineLength

      subject(:get_new) do
        get :new, params: {
          namespace_id: project.namespace,
          project_id: project,
          observability_trace_details: tracing_params
        }
      end

      context 'when read_observability is prevented' do
        before do
          stub_feature_flags(observability_features: false)
          stub_licensed_features(observability: false)
        end

        context 'when observability_tracing_details parameters exist' do
          it 'does not populate observability_values' do
            get_new

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            get_new

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end

        context 'when observability_tracing_details parameters do not exist' do
          let(:tracing_params) { {} }

          it 'does not populate observability_values' do
            get_new

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            get_new

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end
      end

      context 'when read_observability is allowed' do
        before do
          stub_licensed_features(observability: true)
        end

        context 'when observability_tracing_details parameters exist' do
          it 'does prefill the issue title and description' do
            get_new

            expect(assigns(:observability_values)).to eq({
              trace: {
                traceId: '8335ed4c-c943-aeaa-7851-2b9af6c5d3b8'
              }
            })
            expect(assigns(assigned_name).title).to eq("Issue created from trace 'frontend-proxy : ingress'")
            expect(assigns(assigned_name).description).to eq(
              <<~TEXT
                [Trace details](http://gdk.test:3443/flightjs/Flight/-/tracing/cd4cfff9-295b-f014-595c-1be1fc145822) \\
                Name: `frontend-proxy : ingress` \\
                Trace ID: `8335ed4c-c943-aeaa-7851-2b9af6c5d3b8` \\
                Trace start: `Thu, 04 Jul 2024 14:44:21 GMT` \\
                Duration: `2.27ms` \\
                Total spans: `3` \\
                Total errors: `0`
              TEXT
            )
          end
        end

        context 'when observability_tracing_details parameters do not exist' do
          let(:tracing_params) { {} }

          it 'does not populate observability_values' do
            get_new

            expect(assigns(:observability_values)).to be_nil
          end

          it 'does not prefill the issue title and description' do
            get_new

            expect(assigns(assigned_name).title).to be_nil
            expect(assigns(assigned_name).description).to be_nil
          end
        end
      end
    end

    context 'on default templates' do
      let(:template) { 'Hello I am content' }
      let(:files) { { '.gitlab/issue_templates/Default.md' => '' } }

      subject { get :new, params: { namespace_id: project.namespace, project_id: project } }

      context 'when a template has been set via project settings' do
        let(:project) { create(:project, :custom_repo, namespace: namespace, issues_template: template, files: files) }

        it 'includes template' do
          subject

          expect(response.body).to include(template)
        end
      end
    end

    describe 'generate_description feature' do
      context 'when user can generate description' do
        before do
          allow(controller).to receive(:push_licensed_feature)
          allow(controller).to receive(:can?).and_call_original
          allow(controller).to receive(:can?).with(anything, :generate_description, anything).and_return(true)
        end

        context 'when generate_description is licensed' do
          before do
            stub_licensed_features(generate_description: true)
          end

          it 'pushes generate_description licensed feature' do
            get :new, params: { namespace_id: project.namespace, project_id: project }

            expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
          end
        end

        context 'when generate_description is not licensed' do
          before do
            stub_licensed_features(generate_description: false)
          end

          it 'pushes generate_description licensed feature when user has permission regardless of license status' do
            get :new, params: { namespace_id: project.namespace, project_id: project }

            expect(controller).to have_received(:push_licensed_feature).with(:generate_description, project)
          end
        end
      end

      context 'when user cannot generate description' do
        before do
          allow(controller).to receive(:can?).and_call_original
          allow(controller).to receive(:can?).with(user, :generate_description, project).and_return(false)
          stub_licensed_features(generate_description: true)
        end

        it 'does not push generate_description licensed feature' do
          get :new, params: { namespace_id: project.namespace, project_id: project }

          expect(response.body).not_to have_pushed_licensed_features(push_licensed_feature: true)
        end
      end
    end

    context 'when passing vulnerability_id' do
      let(:finding) { create(:vulnerabilities_finding, :with_pipeline) }
      let(:vulnerability) { create(:vulnerability, project: project, findings: [finding]) }

      context 'when the feature is available' do
        before do
          stub_licensed_features(security_dashboard: true)
        end

        it 'adds vulnerability details to body' do
          get :new, params: { namespace_id: project.namespace, project_id: project, vulnerability_id: vulnerability.id }

          expect(response.body).to include(vulnerability.title).and include(vulnerability.description)
        end
      end

      context 'when the feature is not available' do
        before do
          stub_licensed_features(security_dashboard: false)
        end

        it 'does not add vulnerability details to body' do
          get :new, params: { namespace_id: project.namespace, project_id: project, vulnerability_id: vulnerability.id }

          expect(response.body).not_to include(vulnerability.title)
          expect(response.body).not_to include(vulnerability.description)
        end
      end
    end

    context 'when a template has been set via project settings' do
      let(:template) { 'Hello I am content' }
      let(:files) { { '.gitlab/issue_templates/Default.md' => '' } }
      let(:project) do
        create(
          :project,
          :custom_repo,
          namespace: namespace,
          issues_template: template,
          files: files
        )
      end

      before do
        stub_licensed_features(
          issue_weights: true,
          epics: true,
          security_dashboard: true,
          issuable_default_templates: true
        )
      end

      it 'includes template' do
        get :new, params: { namespace_id: project.namespace, project_id: project }

        expect(response.body).to include(template)
      end
    end
  end
end
