<script>
import { GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import ConfirmDangerModal from '~/vue_shared/components/confirm_danger/confirm_danger_modal.vue';
import { REPOSITORIES_LIST_ROUTE_NAME } from '../../constants';
import deleteRepositoryMutation from '../../graphql/mutations/delete_repository.mutation.graphql';
import { evictDeletedRepository } from '../../graphql/utils/cache_update';

const MODAL_ID = 'artifact-registry-delete-repository-modal';

export default {
  name: 'ArtifactRegistryDeleteRepositoryModal',
  i18n: {
    title: s__('ArtifactRegistry|Delete repository?'),
    // The phrase to type is interpolated where `%{phrase}` sits.
    phraseLabel: s__('ArtifactRegistry|Type the repository name below to confirm: %{phrase}'),
    deleteSuccess: s__('ArtifactRegistry|Repository was successfully deleted.'),
    genericError: __('Something went wrong. Please try again.'),
  },
  components: {
    ConfirmDangerModal,
  },
  mixins: [GlToastMixin],
  // `ConfirmDangerModal` takes its button and consequence copy by injection rather
  // than by prop, so this component provides them for the child it renders. Both are
  // constant for a hosted repository; the per-kind copy remote and virtual need
  // arrives with those kinds.
  provide: {
    confirmButtonText: s__('ArtifactRegistry|Delete repository'),
    additionalInformation: s__(
      'ArtifactRegistry|This action permanently deletes the repository and all of its artifacts. If this repository is connected to a virtual repository, the virtual repository loses access to this repository and its artifacts.',
    ),
  },
  inject: ['organizationGid'],
  model: {
    prop: 'visible',
    event: 'change',
  },
  props: {
    repository: {
      type: Object,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
  data() {
    return {
      deleting: false,
    };
  },
  methods: {
    async confirm() {
      this.deleting = true;

      try {
        const errors = await this.deleteRepository();

        if (errors.length) {
          createAlert({ message: errors.join(' ') });
          return;
        }

        this.$toast.show(this.$options.i18n.deleteSuccess);
        this.$router.push({ name: REPOSITORIES_LIST_ROUTE_NAME });
      } catch (error) {
        // A failure the modal cannot act on is page-level rather than field-level, so
        // it surfaces as a dismissible alert and is reported.
        createAlert({ message: this.$options.i18n.genericError, error, captureError: true });
      } finally {
        // Flipping this back is also what closes the modal: the shared component
        // watches `confirmLoading` and hides itself when a run finishes.
        this.deleting = false;
      }
    },
    async deleteRepository() {
      const { name } = this.repository;

      const { data } = await this.$apollo.mutate({
        mutation: deleteRepositoryMutation,
        variables: { input: { name } },
        update: evictDeletedRepository(this.organizationGid, name),
      });

      return data.deleteRepository.errors;
    },
  },
  modalId: MODAL_ID,
};
</script>

<template>
  <confirm-danger-modal
    :visible="visible"
    :modal-id="$options.modalId"
    :modal-title="$options.i18n.title"
    :phrase="repository.name"
    :phrase-label="$options.i18n.phraseLabel"
    :confirm-loading="deleting"
    @confirm="confirm"
    @change="$emit('change', $event)"
  />
</template>
