<script>
import { uniqueId } from 'lodash-es';
import { GlModal } from '@gitlab/ui';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'DisconnectWarningModal',
  components: {
    GlModal,
  },
  mixins: [glListenersMixin],
  model: {
    prop: 'visible',
    event: 'change',
  },
  emits: ['submit'],
  data() {
    return {
      modalId: uniqueId('amazon-q-disconnect-warning-modal-'),
    };
  },
  I18N_TITLE: s__(
    'AmazonQ|Are you sure? Removing the ARN will disconnect Amazon Q from GitLab and all related features will stop working.',
  ),
  ACTION_PRIMARY: {
    text: s__("AmazonQ|Remove IAM role's ARN"),
    attributes: {
      variant: 'danger',
    },
  },
  ACTION_CANCEL: {
    text: s__('AmazonQ|Cancel'),
  },
};
</script>
<template>
  <gl-modal
    :modal-id="modalId"
    :title="$options.I18N_TITLE"
    :action-primary="$options.ACTION_PRIMARY"
    :action-cancel="$options.ACTION_CANCEL"
    v-bind="$attrs"
    v-on="glListeners()"
    @primary="$emit('submit')"
  >
    <p>
      {{
        s__(
          "AmazonQ|If this is what you want, remove the IAM role's ARN. To completely remove GitLab Duo with Amazon Q, update the following in AWS:",
        )
      }}
    </p>
    <ol>
      <li>{{ s__('AmazonQ|Delete the IAM role.') }}</li>
      <li>{{ s__('AmazonQ|Delete the IAM identity provider created for AI gateway.') }}</li>
    </ol>
  </gl-modal>
</template>
