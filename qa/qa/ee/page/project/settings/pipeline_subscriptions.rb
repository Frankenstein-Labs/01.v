# frozen_string_literal: true

module QA
  module EE
    module Page
      module Project
        module Settings
          class PipelineSubscriptions < QA::Page::Base
            view 'ee/app/assets/javascripts/ci/pipeline_subscriptions/components/pipeline_subscriptions_table.vue' do
              element 'add-new-subscription-button'
            end

            view 'ee/app/assets/javascripts/ci/pipeline_subscriptions/components/pipeline_subscriptions_form.vue' do
              element 'upstream-project-path-field'
              element 'subscribe-button'
            end

            def subscribe(project_path)
              click_element('add-new-subscription-button')
              fill_element('upstream-project-path-field', project_path)
              click_element('subscribe-button')
            end
          end
        end
      end
    end
  end
end
