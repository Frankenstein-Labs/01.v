# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::BackgroundOperationMailer, feature_category: :security_asset_inventories do
  let_it_be(:user) { build_stubbed(:user) }
  let(:root_url) { Gitlab::Routing.url_helpers.root_url.chomp('/') }

  let(:operation) do
    {
      id: 'op_123',
      operation_type: 'attribute_update',
      total_items: 100,
      successful_items: 95,
      failed_items: 5
    }
  end

  let(:failed_items) do
    [
      {
        'entity_id' => 1,
        'entity_type' => 'Project',
        'entity_name' => 'My Project',
        'entity_full_path' => 'my-group/my-project',
        'error_message' => 'Permission denied'
      },
      {
        'entity_id' => 2,
        'entity_type' => 'Project',
        'entity_name' => 'Another Project',
        'entity_full_path' => 'my-group/another-project',
        'error_message' => 'Feature not enabled'
      }
    ]
  end

  describe '#failure_notification' do
    subject(:mail) do
      described_class.failure_notification(
        user: user,
        operation: operation,
        failed_items: failed_items
      )
    end

    it 'sends email to user' do
      expect(mail.to).to eq([user.email])
    end

    it 'includes operation type in subject' do
      expect(mail.subject).to include('Attribute update')
    end

    context 'with unknown operation type' do
      let(:operation) do
        {
          id: 'op_123',
          operation_type: 'unknown_operation',
          total_items: 100,
          successful_items: 95,
          failed_items: 5
        }
      end

      it 'humanizes unknown operation type in subject' do
        expect(mail.subject).to include('Unknown operation')
      end
    end

    it 'includes summary in body' do
      expect(mail.body.encoded).to include('100')
      expect(mail.body.encoded).to include('95')
      expect(mail.body.encoded).to include('5')
    end

    it 'includes failed items with entity names in body' do
      expect(mail.body.encoded).to include('My Project')
      expect(mail.body.encoded).to include('Another Project')
      expect(mail.body.encoded).to include('Permission denied')
      expect(mail.body.encoded).to include('Feature not enabled')
    end

    context 'when error_message is an array with project references' do
      let(:failed_items) do
        [
          {
            'entity_id' => 22,
            'entity_type' => 'Group',
            'entity_name' => 'Toolbox',
            'entity_full_path' => 'toolbox',
            'error_message' => [
              "Project 'Security Reports 2' (toolbox/security-reports-2) has reached the maximum limit",
              "Project 'Security Reports' (toolbox/subgroup-2/security-reports) has reached the maximum limit"
            ]
          }
        ]
      end

      it 'includes all error messages in body' do
        expect(mail.body.encoded).to include('Toolbox')
        expect(mail.body.encoded).to include('Security Reports 2')
        expect(mail.body.encoded).to include('Security Reports')
      end

      it 'converts project references to clickable links' do
        body = mail.body.encoded

        expect(body).to include(%(href="#{root_url}/toolbox/security-reports-2"))
        expect(body).to include(%(href="#{root_url}/toolbox/subgroup-2/security-reports"))
        expect(body).to match(%r{<a [^>]*>Security Reports 2</a>})
        expect(body).to match(%r{<a [^>]*>Security Reports</a>})
      end
    end
  end

  describe '#entity_link_for' do
    subject(:mailer) { described_class.new }

    context 'when entity_full_path is present' do
      it 'returns a clickable link with entity name' do
        item = {
          'entity_id' => 1,
          'entity_type' => 'Project',
          'entity_name' => 'My Project',
          'entity_full_path' => 'my-group/my-project'
        }

        result = mailer.entity_link_for(item)

        expect(result).to include(%(href="#{root_url}/my-group/my-project"))
        expect(result).to match(%r{<a [^>]*>My Project</a>})
      end

      it 'uses entity_full_path as link text when entity_name is missing' do
        item = {
          'entity_id' => 1,
          'entity_type' => 'Project',
          'entity_full_path' => 'my-group/my-project'
        }

        result = mailer.entity_link_for(item)

        expect(result).to match(%r{<a [^>]*>my-group/my-project</a>})
      end
    end

    context 'when entity_full_path is not present' do
      it 'returns fallback text with entity type and ID' do
        item = {
          'entity_id' => 42,
          'entity_type' => 'Group'
        }

        result = mailer.entity_link_for(item)

        expect(result).to eq('Group ID 42')
      end

      it 'defaults to Project when entity_type is missing' do
        item = { 'entity_id' => 42 }

        result = mailer.entity_link_for(item)

        expect(result).to eq('Project ID 42')
      end
    end
  end

  describe '#render_error_messages' do
    subject(:mailer) { described_class.new }

    context 'with a single error message' do
      it 'renders inline with a dash prefix' do
        result = mailer.render_error_messages('Permission denied')

        expect(result).to eq('- Permission denied')
      end

      it 'linkifies project references in the message' do
        message = "Project 'My Project' (group/my-project) has an error"

        result = mailer.render_error_messages(message)

        expect(result).to include(%(href="#{root_url}/group/my-project"))
        expect(result).to match(%r{<a [^>]*>My Project</a>})
      end
    end

    context 'with multiple error messages' do
      it 'renders as an unordered list' do
        messages = ['Error 1', 'Error 2', 'Error 3']

        result = mailer.render_error_messages(messages)

        expect(result).to include('<ul')
        expect(result).to include('<li')
        expect(result).to include('Error 1')
        expect(result).to include('Error 2')
        expect(result).to include('Error 3')
      end

      it 'linkifies project references in each message' do
        messages = [
          "Project 'Proj A' (group/proj-a) failed",
          "Project 'Proj B' (group/proj-b) failed"
        ]

        result = mailer.render_error_messages(messages)

        expect(result).to include(%(href="#{root_url}/group/proj-a"))
        expect(result).to include(%(href="#{root_url}/group/proj-b"))
      end
    end

    context 'with nil error message' do
      it 'handles nil gracefully by returning empty string' do
        result = mailer.render_error_messages(nil)

        expect(result).to eq('')
      end
    end

    context 'with empty array' do
      it 'handles empty array gracefully by returning empty string' do
        result = mailer.render_error_messages([])

        expect(result).to eq('')
      end
    end
  end

  describe '#linkify_project_references' do
    subject(:mailer) { described_class.new }

    it 'converts project references to links' do
      message = "Project 'My Project' (group/my-project) has reached the maximum limit"

      result = mailer.linkify_project_references(message)

      expect(result).to include(%(href="#{root_url}/group/my-project"))
      expect(result).to match(%r{<a [^>]*>My Project</a>})
      expect(result).to include('has reached the maximum limit')
    end

    it 'handles multiple project references in one message' do
      message = "Project 'Proj A' (group/proj-a) and Project 'Proj B' (group/proj-b) failed."

      result = mailer.linkify_project_references(message)

      expect(result).to include(%(href="#{root_url}/group/proj-a"))
      expect(result).to include(%(href="#{root_url}/group/proj-b"))
      expect(result).to match(%r{<a [^>]*>Proj A</a>})
      expect(result).to match(%r{<a [^>]*>Proj B</a>})
    end

    it 'returns original message when no project references found' do
      message = "Permission denied for this operation."

      result = mailer.linkify_project_references(message)

      expect(result).to eq(message)
    end

    it 'handles project names with special characters' do
      message = "Project 'My Project (v2.0)' (group/my-project-v2) has an error."

      result = mailer.linkify_project_references(message)

      expect(result).to include(%(href="#{root_url}/group/my-project-v2"))
      expect(result).to match(%r{<a [^>]*>My Project \(v2\.0\)</a>})
    end

    it 'returns nil for nil input' do
      expect(mailer.linkify_project_references(nil)).to be_nil
    end

    it 'returns empty string for blank input' do
      expect(mailer.linkify_project_references('')).to eq('')
    end

    it 'escapes HTML in non-project-reference text' do
      message = "<script>alert('xss')</script> and Project 'Safe' (group/safe) is ok"

      result = mailer.linkify_project_references(message)

      expect(result).to include('&lt;script&gt;')
      expect(result).not_to include('<script>')
      expect(result).to include(%(href="#{root_url}/group/safe"))
    end

    it 'handles project reference at the start of the message' do
      message = "Project 'First' (group/first) is the first project mentioned"

      result = mailer.linkify_project_references(message)

      expect(result).to include(%(href="#{root_url}/group/first"))
      expect(result).to match(%r{<a [^>]*>First</a>})
      expect(result).to include('is the first project mentioned')
    end

    it 'handles project reference at the end of the message' do
      message = "The last project is Project 'Last' (group/last)"

      result = mailer.linkify_project_references(message)

      expect(result).to include('The last project is')
      expect(result).to include(%(href="#{root_url}/group/last"))
      expect(result).to match(%r{<a [^>]*>Last</a>})
    end

    it 'handles message with only a project reference' do
      message = "Project 'Only' (group/only)"

      result = mailer.linkify_project_references(message)

      expect(result).to include(%(href="#{root_url}/group/only"))
      expect(result).to match(%r{<a [^>]*>Only</a>})
    end
  end
end
