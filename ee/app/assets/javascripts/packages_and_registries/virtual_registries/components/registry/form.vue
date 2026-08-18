<script>
import { GlForm, GlFormFields, GlFormTextarea, GlButton } from '@gitlab/ui';
import { formValidators } from '@gitlab/ui/src/utils';
import { produce } from 'immer';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { __, s__, sprintf } from '~/locale';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { captureException } from 'ee/packages_and_registries/virtual_registries/sentry_utils';
import DeleteModal from './delete_modal.vue';

export default {
  name: 'RegistryForm',
  components: {
    GlForm,
    GlFormFields,
    GlFormTextarea,
    GlButton,
    ErrorsAlert,
    DeleteModal,
  },
  inject: [
    'fullPath',
    'createRegistryMutation',
    'updateRegistryMutation',
    'getRegistryQuery',
    'routes',
  ],
  props: {
    initialRegistry: {
      type: Object,
      required: false,
      default: () => ({
        name: '',
        description: '',
      }),
    },
    registryId: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      submitting: false,
      errorMessages: [],
      registry: this.initialRegistry,
      showDeleteModal: false,
    };
  },
  methods: {
    submit() {
      this.submitting = true;

      (this.registryId ? this.updateRegistry() : this.createRegistry())
        .then((registry) => {
          if (registry) {
            this.$router.push({
              name: this.routes.showRegistryRouteName,
              params: { id: getIdFromGraphQLId(registry.id) },
            });
          }
        })
        .catch((error) => {
          this.errorMessages = [__('Something went wrong. Please try again.')];

          captureException({ error, component: this.$options.name });
        })
        .finally(() => {
          this.submitting = false;
        });
    },
    async createRegistry() {
      const { data } = await this.$apollo.mutate({
        mutation: this.createRegistryMutation,
        variables: {
          input: {
            groupPath: this.fullPath,
            ...this.registry,
          },
        },
        update: (store, { data: { createRegistry } }) => {
          const { errors, ...result } = createRegistry;

          if (errors.length) {
            this.errorMessages = errors;
          } else {
            createAlert({
              message: sprintf(s__('VirtualRegistry|Registry %{name} was successfully created.'), {
                name: result.registry.name,
              }),
              variant: 'success',
            });

            store.evict({
              id: 'ROOT_QUERY',
              fieldName: 'group',
              args: { fullPath: this.fullPath },
            });
          }
        },
      });

      return data.createRegistry.registry;
    },
    async updateRegistry() {
      const { data } = await this.$apollo.mutate({
        mutation: this.updateRegistryMutation,
        variables: {
          input: {
            id: this.registryId,
            ...this.registry,
          },
        },
        update: (store, { data: { updateRegistry } }) => {
          const { errors, ...result } = updateRegistry;

          if (errors.length) {
            this.errorMessages = errors;
          } else {
            const { registry } = result;

            this.updateCache(store, registry);

            createAlert({
              message: sprintf(s__('VirtualRegistry|Registry %{name} was successfully updated.'), {
                name: registry.name,
              }),
              variant: 'success',
            });
          }
        },
      });

      return data.updateRegistry.registry;
    },
    updateCache(store, registry) {
      const query = {
        query: this.getRegistryQuery,
        variables: { id: this.registryId },
      };
      const data = store.readQuery(query);

      if (!data) return;

      store.writeQuery({
        ...query,
        data: produce(data, (draftState) => {
          Object.assign(draftState.registry, { ...registry });
        }),
      });
    },
  },
  fields: {
    name: {
      label: s__('VirtualRegistry|Name'),
      validators: [
        formValidators.required(s__('VirtualRegistry|Name is required.')),
        formValidators.factory(
          sprintf(s__('VirtualRegistry|Name cannot be longer than %{length} characters.'), {
            length: 255,
          }),
          (val) => val.length <= 255,
        ),
      ],
    },
    description: {
      label: s__('VirtualRegistry|Description (optional)'),
    },
  },
};
</script>
<template>
  <gl-form id="registry-form" class="@md/panel:gl-w-9/12">
    <errors-alert :errors="errorMessages" @dismiss="errorMessages = []" />
    <gl-form-fields
      v-model="registry"
      :fields="$options.fields"
      form-id="registry-form"
      data-testid="registry-form"
      @submit="submit"
    >
      <template #input(description)="{ id, input, value }">
        <gl-form-textarea :id="id" :value="value" @input="input" />
      </template>
    </gl-form-fields>
    <div class="gl-flex gl-gap-3">
      <gl-button class="js-no-auto-disable" variant="confirm" type="submit" :loading="submitting">
        {{
          registryId ? s__('VirtualRegistry|Save registry') : s__('VirtualRegistry|Create registry')
        }}
      </gl-button>
      <gl-button :to="{ path: '/' }">
        {{ __('Cancel') }}
      </gl-button>
      <gl-button
        v-if="registryId"
        variant="danger"
        category="secondary"
        class="gl-ml-auto"
        @click="showDeleteModal = true"
      >
        {{ s__('VirtualRegistry|Delete registry') }}
      </gl-button>

      <delete-modal
        v-if="registryId && showDeleteModal"
        :registry="initialRegistry"
        @hidden="showDeleteModal = false"
      />
    </div>
  </gl-form>
</template>
