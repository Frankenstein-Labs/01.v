<script>
import { GlModal, GlButton, GlLink, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { MT_RESTART_TRAIN } from '~/vue_merge_request_widget/constants';

export default {
  name: 'MergeTrainRestartTrainConfirmationDialog',
  components: {
    GlModal,
    GlButton,
    GlLink,
    GlSprintf,
  },
  props: {
    visible: {
      type: Boolean,
      required: true,
    },
    mergeTrainType: {
      type: String,
      required: true,
    },
  },
  emits: ['cancel', 'process-merge-train-merge'],
  computed: {
    title() {
      return this.mergeTrainType === MT_RESTART_TRAIN
        ? this.$options.i18n.restartTitle
        : this.$options.i18n.skipTitle;
    },
    info() {
      return this.mergeTrainType === MT_RESTART_TRAIN
        ? this.$options.i18n.restartInfo
        : this.$options.i18n.skipInfo;
    },
  },
  methods: {
    hide() {
      this.$refs.modal.hide();
    },
    cancel() {
      this.hide();
      this.$emit('cancel');
    },
    focusCancelButton() {
      this.$refs.cancelButton.$el.focus();
    },
    processMergeTrainMerge() {
      this.$emit('process-merge-train-merge');
      this.hide();
    },
  },
  i18n: {
    restartTitle: __('Merge now and restart train'),
    skipTitle: __(`Merge now and don't restart train`),
    cancel: __('Cancel'),
    restartInfo: s__(
      `mrWidget|Merging immediately is not recommended because your changes won't be validated by the merge train, and any running merge train pipelines will be restarted. %{linkStart}What are the risks?%{linkEnd}`,
    ),
    skipInfo: s__(
      'mrWidget|Merging immediately is not recommended. The merged changes could cause pipeline failures on the target branch, and the changes will not be validated against the commits being added by the merge requests currently in the merge train. Read the %{linkStart}documentation%{linkEnd} for more information.',
    ),
    confirmation: __('Are you sure you want to continue?'),
  },
  helpPath: helpPagePath('ci/pipelines/merge_trains', {
    anchor: 'skip-the-merge-train-and-merge-immediately',
  }),
};
</script>
<template>
  <gl-modal
    ref="modal"
    modal-id="merge-train-restart-train-confirmation-dialog"
    size="sm"
    :title="title"
    :visible="visible"
    @shown="focusCancelButton"
    @hide="$emit('cancel')"
  >
    <p>
      <gl-sprintf :message="info">
        <template #link="{ content }">
          <gl-link :href="$options.helpPath" target="_blank">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </p>
    <template #modal-footer>
      <gl-button ref="cancelButton" @click="cancel">{{ $options.i18n.cancel }}</gl-button>
      <gl-button variant="danger" data-testid="process-merge-train" @click="processMergeTrainMerge">
        {{ title }}
      </gl-button>
    </template>
  </gl-modal>
</template>
