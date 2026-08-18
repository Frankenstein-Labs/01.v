<script>
import { GlDisclosureDropdownItem, GlModal, GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { sprintf, __ } from '~/locale';
import projectInfoQuery from 'ee_else_ce/repository/queries/project_info.query.graphql';
import lockPathMutation from '~/repository/mutations/lock_path.mutation.graphql';

export default {
  name: 'LockFileDropdownItem',
  i18n: {
    lock: __('Lock'),
    unlock: __('Unlock'),
    modalTitle: __('Lock file?'),
    actionCancel: __('Cancel'),
    mutationError: __('An error occurred while editing lock information, please try again.'),
  },
  components: {
    GlDisclosureDropdownItem,
    GlModal,
  },
  mixins: [GlToastMixin],
  props: {
    name: {
      type: String,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
    canCreateLock: {
      type: Boolean,
      required: true,
    },
    canDestroyLock: {
      type: Boolean,
      required: true,
    },
    isLocked: {
      type: Boolean,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      isUpdating: false,
      isModalVisible: false,
    };
  },
  computed: {
    lockButtonTitle() {
      return this.isLocked ? this.$options.i18n.unlock : this.$options.i18n.lock;
    },
    lockConfirmText() {
      return sprintf(__('Are you sure you want to %{action} %{name}?'), {
        action: this.lockButtonTitle.toLowerCase(),
        name: this.name,
      });
    },
    lockFileItem() {
      return {
        text: this.lockButtonTitle,
        extraAttrs: {
          'data-testid': 'lock-file-dropdown-item',
          disabled:
            !this.canCreateLock ||
            (this.isLocked && !this.canDestroyLock) ||
            this.isLoading ||
            this.isUpdating,
        },
      };
    },
    modalActions() {
      return {
        primary: {
          text: this.lockButtonTitle,
          attributes: { variant: 'confirm', 'data-testid': 'confirm-ok-button' },
        },
        cancel: {
          text: this.$options.i18n.actionCancel,
        },
      };
    },
  },
  methods: {
    hideModal() {
      this.isModalVisible = false;
    },
    showModal() {
      if (this.canCreateLock) {
        this.isModalVisible = true;
      }
    },
    toggleLock() {
      const locked = !this.isLocked;
      this.isUpdating = true;
      this.$apollo
        .mutate({
          mutation: lockPathMutation,
          variables: {
            filePath: this.path,
            projectPath: this.projectPath,
            lock: locked,
          },
          refetchQueries: [
            { query: projectInfoQuery, variables: { projectPath: this.projectPath } },
          ],
          awaitRefetchQueries: true,
        })
        .then(() => {
          this.$toast.show(locked ? __('The file is locked.') : __('The file is unlocked.'));
        })
        .catch((error) => {
          createAlert({ message: this.$options.i18n.mutationError, captureError: true, error });
        })
        .finally(() => {
          this.isUpdating = false;
        });
    },
  },
};
</script>

<template>
  <div>
    <gl-disclosure-dropdown-item :item="lockFileItem" @action="showModal" />
    <gl-modal
      modal-id="lock-file-modal"
      :visible="isModalVisible"
      :title="$options.i18n.modalTitle"
      :action-primary="modalActions.primary"
      :action-cancel="modalActions.cancel"
      @primary="toggleLock"
      @hide="hideModal"
    >
      <p>
        {{ lockConfirmText }}
      </p>
    </gl-modal>
  </div>
</template>
