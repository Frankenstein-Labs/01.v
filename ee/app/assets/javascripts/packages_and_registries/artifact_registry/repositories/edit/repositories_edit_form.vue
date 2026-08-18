<script>
import { GlAlert, GlSkeletonLoader, GlToastMixin } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __, s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import NotFound from '../../components/not_found.vue';
import {
  REPOSITORIES_LIST_ROUTE_NAME,
  REPOSITORY_DETAIL_ROUTE_NAME,
  REPOSITORY_EDIT_TITLE,
  REPOSITORY_FORMAT_LOGO_SIZE_HEADING,
} from '../../constants';
import updateRepositoryMutation from '../../graphql/mutations/update_repository.mutation.graphql';
import getRepositoryQuery from '../../graphql/queries/get_repository.query.graphql';
import FormatLogo from '../components/format_logo.vue';
import RepositoryForm from '../components/repository_form.vue';

export default {
  name: 'ArtifactRegistryRepositoriesEditForm',
  i18n: {
    heading: REPOSITORY_EDIT_TITLE,
    submit: __('Save changes'),
    updateSuccess: s__('ArtifactRegistry|Repository was successfully updated.'),
    unavailable: s__('ArtifactRegistry|The Artifact Registry service is unavailable.'),
    genericError: __('Something went wrong. Please try again.'),
  },
  components: {
    FormatLogo,
    GlAlert,
    GlSkeletonLoader,
    NotFound,
    PageHeading,
    RepositoryForm,
  },
  mixins: [GlToastMixin],
  inject: ['organizationGid'],
  data() {
    return {
      repository: undefined,
      hasError: false,
      errorMessages: [],
      submitting: false,
    };
  },
  apollo: {
    repository: {
      query: getRepositoryQuery,
      variables() {
        return { organizationId: this.organizationGid, name: this.repositoryName };
      },
      update: ({ organization }) => organization?.artifactRegistryRepository ?? null,
      error() {
        this.hasError = true;
      },
    },
  },
  computed: {
    repositoryName() {
      return this.$route.params.id;
    },
    isLoading() {
      return this.$apollo.queries.repository.loading;
    },
    hasResult() {
      return !this.isLoading && !this.hasError;
    },
    isUnavailable() {
      return !this.isLoading && this.hasError;
    },
    // A repository the viewer cannot see and one that does not exist resolve the same
    // way, so the view renders the not-found state alone rather than confirming which.
    isNotFound() {
      return this.hasResult && this.repository === null;
    },
    // The heading renders before the query answers, so it carries a logo only once the
    // repository names a format to render one for.
    format() {
      return this.repository?.format;
    },
    // An edit is reached from the repository it edits, so abandoning one returns there
    // rather than to the list the viewer has already left. The name comes from the
    // repository the read returned, not from the route: a successful save moves the
    // route off this view while the form is still mounted, and a named route whose `id`
    // has gone with it cannot resolve.
    cancelRoute() {
      return { name: REPOSITORY_DETAIL_ROUTE_NAME, params: { id: this.repository?.name } };
    },
  },
  methods: {
    async submit(values) {
      this.submitting = true;
      // A retry starts clean, so errors the last attempt raised cannot linger beside
      // whatever this one produces.
      this.errorMessages = [];

      let updated = null;

      // Only the mutation is guarded: what follows a successful write is not part of the
      // write, and a navigation vue-router rejects is not a reason to say it failed.
      try {
        updated = await this.updateRepository(values);
      } catch (error) {
        // A failure the form cannot act on is page-level rather than field-level, so it
        // surfaces as a dismissible alert and is reported, not as a form error.
        createAlert({ message: this.$options.i18n.genericError, error, captureError: true });
      } finally {
        this.submitting = false;
      }

      if (!updated) return;

      this.$toast.show(this.$options.i18n.updateSuccess);
      this.$router.push({ name: REPOSITORIES_LIST_ROUTE_NAME });
    },
    async updateRepository({ description, visibility }) {
      const { data } = await this.$apollo.mutate({
        mutation: updateRepositoryMutation,
        variables: {
          input: {
            name: this.repositoryName,
            description,
            visibility,
          },
        },
      });

      const { repository, errors } = data.updateRepository;

      if (errors.length) {
        this.errorMessages = errors;
        return null;
      }

      return repository;
    },
  },
  logoSize: REPOSITORY_FORMAT_LOGO_SIZE_HEADING,
};
</script>

<template>
  <not-found v-if="isNotFound" />

  <div v-else>
    <page-heading>
      <template #heading>
        <span class="gl-flex gl-items-center gl-gap-4">
          <format-logo
            v-if="format"
            :format="format"
            :size="$options.logoSize"
            data-testid="repository-format-logo"
          />
          {{ $options.i18n.heading }}
        </span>
      </template>
    </page-heading>

    <gl-alert v-if="isUnavailable" variant="danger" :dismissible="false">
      {{ $options.i18n.unavailable }}
    </gl-alert>

    <gl-skeleton-loader v-else-if="isLoading" :lines="4" />

    <repository-form
      v-else
      :repository="repository"
      :submit-text="$options.i18n.submit"
      :submitting="submitting"
      :error-messages="errorMessages"
      name-readonly
      :show-format="false"
      :cancel-route="cancelRoute"
      @submit="submit"
      @dismiss-errors="errorMessages = []"
    />
  </div>
</template>
