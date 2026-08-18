<script>
import { GlLink, GlModal, GlSprintf } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { s__, __ } from '~/locale';
import { MODAL_ID } from '../constants';

export default {
  name: 'DeleteCarModalConfirmation',
  components: {
    GlLink,
    GlModal,
    GlSprintf,
  },
  props: {
    mergeRequestTitle: {
      type: String,
      required: true,
    },
  },
  emits: ['remove-car-confirmed'],
  docsLink: helpPagePath('ci/pipelines/merge_trains', {
    anchor: 'remove-a-merge-request-from-a-merge-train',
  }),
  warningMessage: s__(
    'Pipelines|Removing the merge request from the merge train will restart the pipelines for all merge requests queued after it. For more information, see the %{linkStart}documentation.%{linkEnd}',
  ),
  confirmationMessage: s__(
    'Pipelines|Are you sure you want to remove the merge request %{title} from the merge train?',
  ),
  actionPrimary: {
    text: s__('Pipelines|Remove from merge train'),
    attributes: {
      variant: 'danger',
    },
  },
  actionCancel: {
    text: __('Cancel'),
  },
  MODAL_ID,
};
</script>

<template>
  <gl-modal
    :modal-id="$options.MODAL_ID"
    :title="s__('Pipelines|Remove from merge train')"
    :action-primary="$options.actionPrimary"
    :action-cancel="$options.actionCancel"
    @primary="$emit('remove-car-confirmed')"
  >
    <p>
      <gl-sprintf :message="$options.warningMessage">
        <template #link="{ content }">
          <gl-link :href="$options.docsLink">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </p>
    <p>
      <gl-sprintf :message="$options.confirmationMessage">
        <template #title>
          <code>{{ mergeRequestTitle }}</code>
        </template>
      </gl-sprintf>
    </p>
  </gl-modal>
</template>
