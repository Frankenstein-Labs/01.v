<script>
import { GlAlert, GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  ACTION_CANCEL: { text: __('Cancel') },
  ACTION_PRIMARY: {
    text: s__('SecurityOrchestration|Change group'),
    attributes: { variant: 'danger' },
  },
  LINK: helpPagePath(
    'user/application_security/policies/enforcement/compliance_and_security_policy_groups.md',
    { anchor: 'policy-synchronization' },
  ),
  name: 'ConfirmationModal',
  components: {
    GlAlert,
    GlLink,
    GlModal,
    GlSprintf,
  },
  emits: ['change'],
  methods: {
    hideModalWindow() {
      this.$refs.modal.hide();
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by parent via $refs to open modal
    showModalWindow() {
      this.$refs.modal.show();
    },
  },
};
</script>

<template>
  <gl-modal
    ref="modal"
    modal-id="change-group-confirmation-modal"
    :title="s__('SecurityOrchestration|Change group')"
    :action-cancel="$options.ACTION_CANCEL"
    :action-primary="$options.ACTION_PRIMARY"
    @cancel="hideModalWindow"
    @primary="$emit('change')"
  >
    <span class="gl-block">
      {{
        s__(
          'SecurityOrchestration|This will disconnect your top-level compliance and security policy group, and all the frameworks it shares, from all other top-level groups.',
        )
      }}
    </span>
    <gl-alert
      class="gl-mt-3"
      variant="warning"
      :dismissible="false"
      :title="s__('SecurityOrchestration|This change starts a synchronization process that:')"
    >
      <ul>
        <li>
          <gl-sprintf
            :message="
              s__('SecurityOrchestration|May %{linkStart}impact system performance%{linkEnd}.')
            "
          >
            <template #link="{ content }">
              <gl-link target="_blank" :href="$options.LINK">
                {{ content }}
              </gl-link>
            </template></gl-sprintf
          >
        </li>
        <li>
          {{
            s__(
              'SecurityOrchestration|May take significant time to complete, depending on your instance size, including the number of groups, projects, and merge requests.',
            )
          }}
        </li>
        <li>
          {{
            s__(
              'SecurityOrchestration|Applies policy evaluations to all projects in this instance.',
            )
          }}
        </li>
        <li>
          {{
            s__(
              'SecurityOrchestration|This setting will be locked for 10 minutes after making changes to prevent further performance issues.',
            )
          }}
        </li>
      </ul>
    </gl-alert>

    <strong class="gl-block gl-pt-5">
      {{
        s__(
          'SecurityOrchestration|Are you sure you want to change the compliance and security policy group?',
        )
      }}
    </strong>
  </gl-modal>
</template>
