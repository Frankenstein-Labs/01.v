# frozen_string_literal: true

module QA
  module EE
    module Page
      module Alert
        class StorageLimit < QA::Page::Base
          view 'ee/app/components/namespaces/storage/namespace_limit/alert_component.html.haml' do
            element 'storage-limit-alert-content'
          end

          def storage_limit_message
            find_element('storage-limit-alert-content').text
          end
        end
      end
    end
  end
end
