<script>
import { GlModal, GlSprintf } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, __ } from '~/locale';

export default {
  name: 'DeleteRegistryModal',
  components: {
    GlModal,
    GlSprintf,
  },
  inject: ['fullPath', 'deleteRegistryMutation', 'routes'],
  props: {
    registry: {
      type: Object,
      required: true,
    },
  },
  emits: ['hidden'],
  data() {
    return {
      destroying: false,
    };
  },
  computed: {
    modalPrimaryAction() {
      return {
        text: __('Delete'),
        attributes: {
          disabled: this.destroying,
          variant: 'danger',
          category: 'primary',
        },
      };
    },
  },
  methods: {
    async deleteRegistry() {
      this.destroying = true;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: this.deleteRegistryMutation,
          variables: {
            id: this.registry.id,
          },
          update: (store, res) => {
            if (!res.data.delete.errors.length) {
              store.evict({
                id: 'ROOT_QUERY',
                fieldName: 'group',
                args: { fullPath: this.fullPath },
              });

              this.$router.push({ name: this.routes.listRegistryRouteName });
            }
          },
        });

        if (data.delete.errors.length > 0) {
          throw new Error(data.delete.errors.join(', '));
        }

        createAlert({
          message: s__('VirtualRegistry|Virtual registry deleted successfully.'),
          variant: 'success',
        });
      } catch (error) {
        createAlert({
          message: s__('VirtualRegistry|Failed to delete registry. Please try again.'),
          error,
          captureError: true,
        });

        this.$emit('hidden');
      } finally {
        this.destroying = false;
      }
    },
  },
  modal: {
    cancelAction: {
      text: __('Cancel'),
    },
  },
};
</script>
<template>
  <gl-modal
    visible
    modal-id="destroy-registry-modal"
    size="sm"
    modal-class="gl-break-words"
    :action-primary="modalPrimaryAction"
    :action-cancel="$options.modal.cancelAction"
    :title="s__('VirtualRegistry|Delete registry')"
    @primary="deleteRegistry"
    @hidden="$emit('hidden')"
  >
    <template v-if="registry">
      <gl-sprintf :message="s__('VirtualRegistry|Are you sure you want to delete %{name}?')">
        <template #name
          ><strong>{{ registry.name }}</strong></template
        >
      </gl-sprintf>
    </template>
  </gl-modal>
</template>
