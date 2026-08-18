<script>
import { GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import {
  REPOSITORIES_LIST_ROUTE_NAME,
  REPOSITORY_FORMAT_OPTIONS,
  REPOSITORY_HOSTED_DESCRIPTION,
  REPOSITORY_KIND_HOSTED,
  REPOSITORY_NEW_TITLE,
  REPOSITORY_VISIBILITY_PRIVATE,
} from '../../constants';
import createRepositoryMutation from '../../graphql/mutations/create_repository.mutation.graphql';
import { evictRepositoriesList } from '../../graphql/utils/cache_update';
import RepositoryForm from '../components/repository_form.vue';

export default {
  name: 'ArtifactRegistryRepositoriesCreateForm',
  i18n: {
    heading: REPOSITORY_NEW_TITLE,
    description: REPOSITORY_HOSTED_DESCRIPTION,
    submit: s__('ArtifactRegistry|Create repository'),
    createSuccess: s__('ArtifactRegistry|Repository was successfully created.'),
    genericError: __('Something went wrong. Please try again.'),
  },
  components: {
    PageHeading,
    RepositoryForm,
  },
  mixins: [GlToastMixin],
  inject: ['organizationGid'],
  data() {
    return {
      errorMessages: [],
      submitting: false,
    };
  },
  methods: {
    async submit(values) {
      this.submitting = true;
      // A retry starts clean, so errors the last attempt raised cannot linger beside
      // whatever this one produces.
      this.errorMessages = [];

      let created = null;

      // Only the mutation is guarded: what follows a successful write is not part of the
      // write, and a navigation vue-router rejects is not a reason to say it failed.
      try {
        created = await this.createRepository(values);
      } catch (error) {
        // A failure the form cannot act on is page-level rather than field-level, so it
        // surfaces as a dismissible alert and is reported, not as a form error.
        createAlert({ message: this.$options.i18n.genericError, error, captureError: true });
      } finally {
        this.submitting = false;
      }

      if (!created) return;

      this.$toast.show(this.$options.i18n.createSuccess);
      this.$router.push({ name: REPOSITORIES_LIST_ROUTE_NAME });
    },
    async createRepository(values) {
      const { data } = await this.$apollo.mutate({
        mutation: createRepositoryMutation,
        variables: {
          input: {
            kind: REPOSITORY_KIND_HOSTED,
            ...values,
          },
        },
        update: evictRepositoriesList(this.organizationGid),
      });

      const { repository, errors } = data.createRepository;

      if (errors.length) {
        this.errorMessages = errors;
        return null;
      }

      return repository;
    },
  },
  newRepository: {
    format: REPOSITORY_FORMAT_OPTIONS[0].value,
    name: '',
    description: '',
    visibility: REPOSITORY_VISIBILITY_PRIVATE,
  },
};
</script>

<template>
  <div>
    <page-heading :heading="$options.i18n.heading">
      <template #description>{{ $options.i18n.description }}</template>
    </page-heading>

    <repository-form
      :repository="$options.newRepository"
      :submit-text="$options.i18n.submit"
      :submitting="submitting"
      :error-messages="errorMessages"
      @submit="submit"
      @dismiss-errors="errorMessages = []"
    />
  </div>
</template>
