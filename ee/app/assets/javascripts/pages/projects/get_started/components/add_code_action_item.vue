<script>
import { GlIcon, GlLink, GlButton, GlModalDirective } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import Tracking, { InternalEvents } from '~/tracking';
import UploadBlobModal from '~/repository/components/upload_blob_modal.vue';
import CommandLineModal from './command_line_modal.vue';

export default {
  name: 'AddCodeActionItem',
  components: {
    GlIcon,
    GlLink,
    GlButton,
    CommandLineModal,
    UploadBlobModal,
  },
  directives: {
    GlModal: GlModalDirective,
  },
  mixins: [InternalEvents.mixin(), Tracking.mixin({ category: 'projects:learn_gitlab:show' })],
  inject: ['projectName', 'defaultBranch', 'canPushCode', 'canPushToBranch', 'uploadPath'],
  props: {
    action: {
      type: Object,
      required: true,
    },
  },
  computed: {
    uploadBlobModalId() {
      return uniqueId('modal-upload-blob');
    },
    commandLineModalId() {
      return uniqueId('command-line-modal');
    },
    canCommitFiles() {
      return this.canPushCode && this.canPushToBranch;
    },
  },
  methods: {
    trackCommandLineClick() {
      this.trackEvent('click_command_line_instructions_in_get_started');
    },
    trackUploadFilesClick() {
      this.trackEvent('click_upload_files_in_get_started');
    },
    handleWebIdeClick() {
      this.track('click_link', { label: this.action.trackLabel });
    },
  },
};
</script>
<template>
  <li class="gl-flex gl-flex-col gl-gap-3">
    <div class="gl-flex gl-items-center gl-gap-3">
      <span class="gl-display-inline-block">
        {{ action.title }}
      </span>
    </div>

    <ul class="gl-flex gl-list-none gl-flex-col gl-gap-3 gl-pl-0">
      <li>
        <gl-button
          v-gl-modal="commandLineModalId"
          variant="link"
          data-testid="command-line-button"
          @click="trackCommandLineClick"
        >
          {{ s__('LearnGitLab|Use the command line') }}
        </gl-button>
      </li>
      <li v-if="canCommitFiles">
        <gl-button
          v-gl-modal="uploadBlobModalId"
          variant="link"
          data-testid="upload-files-button"
          @click="trackUploadFilesClick"
        >
          {{ s__('LearnGitLab|Upload files') }}
        </gl-button>
      </li>
      <li v-if="canCommitFiles">
        <gl-link :href="action.url" target="_blank" @click="handleWebIdeClick">
          {{ s__('LearnGitLab|Open the WebIDE') }}
          <gl-icon name="external-link" />
        </gl-link>
      </li>
    </ul>

    <command-line-modal :modal-id="commandLineModalId" :default-branch="defaultBranch" />

    <upload-blob-modal
      v-if="canCommitFiles"
      :modal-id="uploadBlobModalId"
      :commit-message="__('Upload New File')"
      :target-branch="defaultBranch"
      :original-branch="defaultBranch"
      :can-push-code="canPushCode"
      :can-push-to-branch="canPushToBranch"
      :path="uploadPath"
      :upload-path="uploadPath"
    />
  </li>
</template>
