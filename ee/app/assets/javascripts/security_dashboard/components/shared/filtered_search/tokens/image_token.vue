<script>
import { GlFilteredSearchToken, GlLoadingIcon } from '@gitlab/ui';
import { getSelectedOptionsText } from '~/lib/utils/listbox_helpers';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import agentImagesQuery from 'ee/security_dashboard/graphql/queries/agent_images.query.graphql';
import projectImagesQuery from 'ee/security_dashboard/graphql/queries/project_images.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import SearchSuggestion from '../components/search_suggestion.vue';
import { ALL_ID as ALL_IMAGES_VALUE } from '../constants';

export default {
  components: {
    GlFilteredSearchToken,
    GlLoadingIcon,
    SearchSuggestion,
  },
  mixins: [glListenersMixin],
  inject: {
    agentName: { default: '' },
    fullPath: { default: '' },
    projectFullPath: { default: '' },
  },
  props: {
    config: {
      type: Object,
      required: true,
    },
    // contains the token, with the selected operand (e.g.: '=') and the data (comma separated, e.g.: 'MIT, GNU')
    value: {
      type: Object,
      required: true,
    },
    active: {
      type: Boolean,
      required: true,
    },
  },
  apollo: {
    images: {
      query() {
        return this.isAgentDashboard ? agentImagesQuery : projectImagesQuery;
      },
      variables() {
        return {
          agentName: this.agentName,
          projectPath: this.projectFullPath || this.fullPath,
        };
      },
      update(data) {
        const vulnerabilityImages = this.isAgentDashboard
          ? data.project?.clusterAgent?.vulnerabilityImages
          : data.project?.vulnerabilityImages;

        return vulnerabilityImages.nodes.map(({ name }) => ({ text: name, value: name, id: name }));
      },
      error() {
        createAlert({ message: this.$options.i18n.loadingError });
      },
    },
  },
  data() {
    return {
      selectedImages: this.value.data || [ALL_IMAGES_VALUE],
      images: [],
    };
  },
  computed: {
    tokenValue() {
      return {
        ...this.value,
        // when the token is active (dropdown is open), we set the value to null to prevent an UX issue
        // in which only the last selected item is being displayed.
        // more information: https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/issues/2467
        data: this.active ? null : this.selectedImages,
      };
    },
    items() {
      return [{ value: ALL_IMAGES_VALUE, text: s__('SecurityReports|All images') }, ...this.images];
    },
    toggleText() {
      return getSelectedOptionsText({
        options: this.items,
        selected: this.selectedImages,
        maxOptionsShown: 2,
      });
    },
    isAgentDashboard() {
      return Boolean(this.agentName);
    },
    isLoading() {
      return this.$apollo.queries.images.loading;
    },
  },
  methods: {
    resetSelected() {
      this.selectedImages = [ALL_IMAGES_VALUE];
    },
    toggleSelected(selectedValue) {
      const allImagesSelected = selectedValue === ALL_IMAGES_VALUE;

      if (this.selectedImages.includes(selectedValue)) {
        this.selectedImages = this.selectedImages.filter((s) => s !== selectedValue);
      } else {
        this.selectedImages = this.selectedImages.filter((s) => s !== ALL_IMAGES_VALUE);
        this.selectedImages.push(selectedValue);
      }

      if (!this.selectedImages.length || allImagesSelected) {
        this.selectedImages = [ALL_IMAGES_VALUE];
      }
    },
    isImageSelected(name) {
      return this.selectedImages.includes(name);
    },
  },
  i18n: {
    label: s__('SecurityReports|Image'),
    loadingError: s__('SecurityOrchestration|Failed to load images.'),
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="config"
    v-bind="{ ...$props, ...$attrs }"
    :multi-select-values="selectedImages"
    :value="tokenValue"
    v-on="glListeners()"
    @select="toggleSelected"
    @destroy="resetSelected"
  >
    <template #view>
      {{ toggleText }}
    </template>
    <template #suggestions>
      <gl-loading-icon v-if="isLoading" size="sm" />
      <search-suggestion
        v-for="image in items"
        v-else
        :key="image.value"
        :value="image.value"
        :text="image.text"
        :selected="isImageSelected(image.value)"
        :data-testid="`suggestion-${image.value}`"
        truncate
      />
    </template>
  </gl-filtered-search-token>
</template>
